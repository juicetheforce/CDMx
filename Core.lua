--[[
    CDMx - Core.lua
    Handles addon initialization, namespace setup, and saved variables
    
    Author: Juicetheforce (with Claude assistance)
    Target: WoW 12.0.x (Midnight)
]]--

local ADDON_NAME, CDM = ...

-- Version info
CDM.version = "1.0.6"
CDM.debug = false
CDM.verbose = false

--============================================================================
-- DEFAULT SETTINGS
--============================================================================

-- Default profile: contains ALL settings. Each named profile is a copy of this.
local profileDefaults = {
    enabled = true,
    showHotkeys = true,
    debug = false,
    
    -- Hotkey display settings
    hotkeyFontSize = 16,      -- Essential cooldowns (large icons)
    utilityFontSize = 12,     -- Utility cooldowns (small icons)
    hotkeyFont = "Fonts\\FRIZQT__.TTF",
    hotkeyOffsetX = 2,
    hotkeyOffsetY = -2,
    hotkeyAnchor = "TOPLEFT",
    hotkeyOutline = "OUTLINE",
    procGlow = true,
    
    -- Cooldown Manager styling (Blizzard Essential/Utility bars)
    cooldownManager = {
        squareIcons = false,
        showBorder = true,
    },
    
    -- Trinket bar settings
    trinketBar = {
        enabled = true,
        locked = false,
        horizontal = true,
        centered = true,
        iconSize = 40,
        padding = 5,
        position = { point = "CENTER", x = 0, y = 0 },
        squareIcons = true,
        showBorder = true,
        hotkeyFontSize = 12,
        visibility = "always",
    },
    
    -- Custom bars (user-created)
    customBars = {},
    
    -- Global style for custom bars
    customBarsStyle = {
        squareIcons = true,
        showBorder = true,
    },
}

--============================================================================
-- UTILITY FUNCTIONS
--============================================================================

-- Debug print (only when debug mode is on)
function CDM:Print(...)
    if self.debug then
        print("|cff33ff99CDMx:|r", ...)
    end
end

-- Always print (for user-facing messages regardless of debug)
function CDM:Msg(...)
    print("|cff33ff99CDMx:|r", ...)
end

--[[
    Deep merge defaults into saved variables.
    Preserves existing user values, adds missing defaults,
    and recurses into nested tables.
]]--
local function DeepMerge(saved, default)
    for k, v in pairs(default) do
        if saved[k] == nil then
            -- Missing key, add the default
            if type(v) == "table" then
                saved[k] = CopyTable(v)
            else
                saved[k] = v
            end
        elseif type(v) == "table" and type(saved[k]) == "table" then
            -- Both are tables, recurse (but skip customBars - user data)
            if k ~= "customBars" then
                DeepMerge(saved[k], v)
            end
        end
    end
end

--============================================================================
-- PROFILE SYSTEM
--============================================================================

-- Get "CharName - RealmName" identifier for the current character
function CDM:GetCharKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Unknown"
    return name .. " - " .. realm
end

--[[
    Get the active profile name for the current character.
    Falls back to "Default" if the assigned profile doesn't exist.
]]--
function CDM:GetActiveProfileName()
    local charKey = self:GetCharKey()
    local profileName = CDMxDB.charMap[charKey] or "Default"
    
    -- Safety: if assigned profile was deleted, fall back to Default
    if not CDMxDB.profiles[profileName] then
        profileName = "Default"
        CDMxDB.charMap[charKey] = "Default"
    end
    
    return profileName
end

--[[
    Set the active profile for the current character.
    Returns true on success.
]]--
function CDM:SetProfile(profileName)
    if not CDMxDB.profiles[profileName] then
        self:Msg("Profile '" .. profileName .. "' does not exist")
        return false
    end
    
    local charKey = self:GetCharKey()
    CDMxDB.charMap[charKey] = profileName
    self.db = CDMxDB.profiles[profileName]
    self.debug = self.db.debug or false
    self.activeProfile = profileName
    self:Msg("Switched to profile: " .. profileName .. " - /reload to apply fully")
    return true
end

--[[
    Create a new profile with default settings.
    Returns true on success.
]]--
function CDM:CreateProfile(profileName)
    if not profileName or profileName == "" then
        self:Msg("Profile name cannot be empty")
        return false
    end
    if CDMxDB.profiles[profileName] then
        self:Msg("Profile '" .. profileName .. "' already exists")
        return false
    end
    
    CDMxDB.profiles[profileName] = CopyTable(profileDefaults)
    self:Msg("Created profile: " .. profileName)
    return true
end

--[[
    Copy one profile's settings into another (overwriting the target).
    Creates the target if it doesn't exist.
]]--
function CDM:CopyProfile(sourceName, targetName)
    if not CDMxDB.profiles[sourceName] then
        self:Msg("Source profile '" .. sourceName .. "' does not exist")
        return false
    end
    if not targetName or targetName == "" then
        self:Msg("Target profile name cannot be empty")
        return false
    end
    
    CDMxDB.profiles[targetName] = CopyTable(CDMxDB.profiles[sourceName])
    self:Msg("Copied '" .. sourceName .. "' to '" .. targetName .. "'")
    return true
end

--[[
    Delete a profile. Cannot delete the currently active profile
    or the last remaining profile.
]]--
function CDM:DeleteProfile(profileName)
    if not CDMxDB.profiles[profileName] then
        self:Msg("Profile '" .. profileName .. "' does not exist")
        return false
    end
    
    -- Don't delete the active profile
    if profileName == self.activeProfile then
        self:Msg("Cannot delete the active profile. Switch to another first.")
        return false
    end
    
    -- Don't delete the last profile
    local count = 0
    for _ in pairs(CDMxDB.profiles) do count = count + 1 end
    if count <= 1 then
        self:Msg("Cannot delete the last profile")
        return false
    end
    
    -- Reassign any characters using this profile to "Default"
    for charKey, pName in pairs(CDMxDB.charMap) do
        if pName == profileName then
            CDMxDB.charMap[charKey] = "Default"
        end
    end
    
    CDMxDB.profiles[profileName] = nil
    self:Msg("Deleted profile: " .. profileName)
    return true
end

--[[
    Rename a profile. Updates all character assignments.
]]--
function CDM:RenameProfile(oldName, newName)
    if not CDMxDB.profiles[oldName] then
        self:Msg("Profile '" .. oldName .. "' does not exist")
        return false
    end
    if not newName or newName == "" then
        self:Msg("New name cannot be empty")
        return false
    end
    if CDMxDB.profiles[newName] then
        self:Msg("Profile '" .. newName .. "' already exists")
        return false
    end
    
    CDMxDB.profiles[newName] = CDMxDB.profiles[oldName]
    CDMxDB.profiles[oldName] = nil
    
    -- Update all character assignments
    for charKey, pName in pairs(CDMxDB.charMap) do
        if pName == oldName then
            CDMxDB.charMap[charKey] = newName
        end
    end
    
    if self.activeProfile == oldName then
        self.activeProfile = newName
    end
    
    self:Msg("Renamed profile '" .. oldName .. "' to '" .. newName .. "'")
    return true
end

--[[
    Reset the current profile back to defaults.
]]--
function CDM:ResetProfile()
    local profileName = self.activeProfile
    CDMxDB.profiles[profileName] = CopyTable(profileDefaults)
    self.db = CDMxDB.profiles[profileName]
    self:Msg("Reset profile '" .. profileName .. "' to defaults - /reload to apply")
end

--[[
    Get a sorted list of all profile names.
]]--
function CDM:GetProfileList()
    local list = {}
    for name in pairs(CDMxDB.profiles) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

--============================================================================
-- INITIALIZATION
--============================================================================

function CDM:Initialize()
    -- MIGRATION: If CDMxDB exists but has no profiles table,
    -- this is a pre-profile install. Wrap all existing settings
    -- into a "Default" profile.
    if CDMxDB and not CDMxDB.profiles then
        local oldSettings = CDMxDB
        CDMxDB = {
            profiles = {
                ["Default"] = oldSettings,
            },
            charMap = {},
        }
        -- Fill in any missing defaults
        DeepMerge(CDMxDB.profiles["Default"], profileDefaults)
        self:Msg("Profile system: Migrated existing settings to 'Default' profile")
    end
    
    -- First-time install: create fresh DB
    if not CDMxDB then
        CDMxDB = {
            profiles = {
                ["Default"] = CopyTable(profileDefaults),
            },
            charMap = {},
        }
    end
    
    -- Ensure Default profile always exists
    if not CDMxDB.profiles["Default"] then
        CDMxDB.profiles["Default"] = CopyTable(profileDefaults)
    end
    
    -- Ensure charMap exists
    if not CDMxDB.charMap then
        CDMxDB.charMap = {}
    end
    
    -- Assign current character to Default if no assignment exists
    local charKey = self:GetCharKey()
    if not CDMxDB.charMap[charKey] then
        CDMxDB.charMap[charKey] = "Default"
    end
    
    -- Resolve active profile
    self.activeProfile = self:GetActiveProfileName()
    
    -- Merge any new defaults into the active profile
    DeepMerge(CDMxDB.profiles[self.activeProfile], profileDefaults)
    
    -- CDM.db points directly to the active profile table.
    -- All existing code (CDM.db.trinketBar, CDM.db.customBars, etc.)
    -- works unchanged — it just reads/writes the active profile now.
    self.db = CDMxDB.profiles[self.activeProfile]
    self.debug = self.db.debug or false
    
    -- Clean up legacy per-character DB if it exists from proxy approach
    if CDMxCharDB then
        CDMxCharDB = nil
    end
    
    -- Initialize shared UI module
    if self.UI then
        self.UI:InitMasque()
    end
    
    self:Print("Version", self.version, "| Profile:", self.activeProfile)
end

-- Event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        CDM:Initialize()
    elseif event == "PLAYER_LOGIN" then
        CDM:Print("Player logged in - ready to track cooldowns!")
        if EditModeManagerFrame then
            CDM:Print("Edit Mode detected")
        end
    end
end)

--============================================================================
-- SLASH COMMANDS
--============================================================================

SLASH_CDMX1 = "/cdmx"
SLASH_CDMX2 = "/cdm"

SlashCmdList["CDMX"] = function(msg)
    -- Parse args preserving case for bar names
    local args = {}
    for word in msg:gmatch("%S+") do
        table.insert(args, word)
    end
    local cmd = string.lower(args[1] or "")
    
    if cmd == "" or cmd == "help" then
        print("|cff33ff99CDMx Commands:|r")
        print("  /cdmx config - Open settings panel")
        print("  /cdmx toggle - Enable/disable addon")
        print("  /cdmx debug - Toggle debug output")
        print("  /cdmx verbose - Toggle verbose debug")
        print("  /cdmx version - Show version info")
        print("  /cdmx status - Show current status")
        print("  /cdmx reload - Reload UI")
        print("|cff33ff99Profiles:|r")
        print("  /cdmx profile - Show current profile")
        print("  /cdmx profile list - List all profiles")
        print("  /cdmx profile use <name> - Switch to profile")
        print("  /cdmx profile create <name> - New profile")
        print("  /cdmx profile copy <src> <dest> - Copy profile")
        print("  /cdmx profile delete <name> - Delete profile")
        print("  /cdmx profile rename <old> <new> - Rename")
        print("  /cdmx profile reset - Reset current to defaults")
        print("|cff33ff99Hotkeys:|r")
        print("  /cdmx fontsize <8-32> - Essential font size")
        print("  /cdmx position <anchor> - Hotkey position")
        print("  /cdmx offset <x> <y> - Fine-tune position")
        print("  /cdmx outline <type> - OUTLINE, THICKOUTLINE, NONE")
        print("  /cdmx procglow - Toggle proc glow")
        print("|cff33ff99Cooldown Manager:|r")
        print("  /cdmx cdmsquare - Toggle square icons")
        print("  /cdmx cdmborder - Toggle borders")
        print("|cff33ff99Trinket Bar:|r")
        print("  /cdmx trinkets - Toggle trinket bar")
        print("  /cdmx trinketsize <20-80> - Icon size")
        print("  /cdmx trinketpadding <0-20> - Spacing")
        print("  /cdmx trinketlayout - Toggle H/V")
        print("|cff33ff99Custom Bars:|r")
        print("  /cdmx bar create <name>")
        print("  /cdmx bar list")
        print("  /cdmx bar <name> [enable|disable|layout|delete]")
        print("  /cdmx bar <name> [slots|size|font] <value>")
        
    elseif cmd == "profile" then
        CDM:HandleProfileCommand(args)
        
    elseif cmd == "bar" then
        CDM:HandleBarCommand(args)
        
    elseif cmd == "nukebars" then
        CDM.db.customBars = {}
        CDM:Msg("Deleted ALL custom bars - /reload to apply")
        
    elseif cmd == "config" then
        if CDM.Config and CDM.Config.Open then
            CDM.Config:Open()
        elseif SettingsPanel then
            SettingsPanel:Open()
            CDM:Msg("Look for 'CDMx' under AddOns")
        end
        
    elseif cmd == "toggle" then
        CDM.db.enabled = not CDM.db.enabled
        CDM:Msg("Addon", CDM.db.enabled and "enabled" or "disabled")
        
    elseif cmd == "debug" then
        CDM.db.debug = not CDM.db.debug
        CDM.debug = CDM.db.debug
        CDM:Msg("Debug mode", CDM.debug and "enabled" or "disabled")
        
    elseif cmd == "verbose" then
        CDM.verbose = not CDM.verbose
        CDM:Msg("Verbose mode", CDM.verbose and "enabled" or "disabled")
        
    elseif cmd == "version" then
        CDM:Msg("Version:", CDM.version)
        
    elseif cmd == "status" then
        CDM:Msg("Status:")
        CDM:Msg("  Profile:", CDM.activeProfile)
        CDM:Msg("  Enabled:", CDM.db.enabled)
        CDM:Msg("  Debug:", CDM.debug)
        CDM:Msg("  Hotkeys:", CDM.db.showHotkeys)
        CDM:Msg("  Font Size:", CDM.db.hotkeyFontSize)
        CDM:Msg("  Anchor:", CDM.db.hotkeyAnchor)
        
    elseif cmd == "fontsize" then
        local size = tonumber(args[2])
        if size and size >= 8 and size <= 32 then
            CDM.db.hotkeyFontSize = size
            CDM:Msg("Font size set to:", size, "- /reload to apply")
        else
            CDM:Msg("Usage: /cdmx fontsize <8-32>")
        end
        
    elseif cmd == "position" then
        local pos = args[2] and string.upper(args[2])
        local valid = { TOPRIGHT=1, TOPLEFT=1, TOP=1, BOTTOMRIGHT=1,
                        BOTTOMLEFT=1, BOTTOM=1, CENTER=1, LEFT=1, RIGHT=1 }
        if pos and valid[pos] then
            CDM.db.hotkeyAnchor = pos
            CDM:Msg("Position set to:", pos, "- /reload to apply")
        else
            CDM:Msg("Usage: /cdmx position <TOPRIGHT|TOPLEFT|CENTER|...>")
        end
        
    elseif cmd == "outline" then
        local outline = args[2] and string.upper(args[2])
        local valid = { OUTLINE=1, THICKOUTLINE=1, NONE=1 }
        if outline and valid[outline] then
            CDM.db.hotkeyOutline = outline == "NONE" and "" or outline
            CDM:Msg("Outline set to:", outline, "- /reload to apply")
        else
            CDM:Msg("Usage: /cdmx outline <OUTLINE|THICKOUTLINE|NONE>")
        end
        
    elseif cmd == "offset" then
        local x, y = tonumber(args[2]), tonumber(args[3])
        if x and y then
            CDM.db.hotkeyOffsetX = x
            CDM.db.hotkeyOffsetY = y
            CDM:Msg(string.format("Offset: X=%d, Y=%d - /reload to apply", x, y))
        else
            CDM:Msg("Usage: /cdmx offset <x> <y>")
        end
        
    elseif cmd == "reload" then
        ReloadUI()
        
    elseif cmd == "trinkets" then
        CDM.db.trinketBar.enabled = not CDM.db.trinketBar.enabled
        CDM:Msg("Trinket bar", CDM.db.trinketBar.enabled and "enabled" or "disabled")
        if CDM.TrinketBar then CDM.TrinketBar:Update() end
        
    elseif cmd == "lock" then
        self:Msg("Use Edit Mode to reposition bars (ESC > Edit Mode)")
        
    elseif cmd == "trinketsize" then
        local size = tonumber(args[2])
        if size and size >= 20 and size <= 80 then
            CDM.db.trinketBar.iconSize = size
            CDM:Msg("Trinket icon size:", size)
            if CDM.TrinketBar then CDM.TrinketBar:Update() end
        else
            CDM:Msg("Usage: /cdmx trinketsize <20-80>")
        end
        
    elseif cmd == "trinketpadding" then
        local p = tonumber(args[2])
        if p and p >= 0 and p <= 20 then
            CDM.db.trinketBar.padding = p
            CDM:Msg("Trinket padding:", p)
            if CDM.TrinketBar then CDM.TrinketBar:Update() end
        else
            CDM:Msg("Usage: /cdmx trinketpadding <0-20>")
        end
        
    elseif cmd == "trinketlayout" then
        CDM.db.trinketBar.horizontal = not CDM.db.trinketBar.horizontal
        CDM:Msg("Trinket layout:", CDM.db.trinketBar.horizontal and "horizontal" or "vertical")
        if CDM.TrinketBar then CDM.TrinketBar:Update() end
        
    elseif cmd == "trinketsquare" then
        CDM.db.trinketBar.squareIcons = not CDM.db.trinketBar.squareIcons
        CDM:Msg("Square icons:", CDM.db.trinketBar.squareIcons and "on" or "off", "- /reload to apply")
        
    elseif cmd == "trinketborder" then
        CDM.db.trinketBar.showBorder = not CDM.db.trinketBar.showBorder
        CDM:Msg("Borders:", CDM.db.trinketBar.showBorder and "on" or "off", "- /reload to apply")
        
    elseif cmd == "procglow" then
        CDM.db.procGlow = not CDM.db.procGlow
        CDM:Msg("Proc glow", CDM.db.procGlow and "enabled" or "disabled")
        
    elseif cmd == "cdmsquare" then
        CDM.db.cooldownManager.squareIcons = not CDM.db.cooldownManager.squareIcons
        CDM:Msg("CM square icons:", CDM.db.cooldownManager.squareIcons and "on" or "off", "- /reload to apply")
        
    elseif cmd == "cdmborder" then
        CDM.db.cooldownManager.showBorder = not CDM.db.cooldownManager.showBorder
        CDM:Msg("CM borders:", CDM.db.cooldownManager.showBorder and "on" or "off", "- /reload to apply")
        
    else
        CDM:Msg("Unknown command. Type /cdmx help")
    end
end

--============================================================================
-- CUSTOM BAR SLASH COMMAND HANDLER
--============================================================================

function CDM:HandleBarCommand(args)
    local barName = args[2]
    local subCmd = string.lower(args[3] or "")
    
    if not barName or barName == "" then
        self:Msg("Usage: /cdmx bar <name> <command>")
        return
    end
    
    -- Create new bar
    if barName == "create" then
        local name = args[3]
        if not name or name == "" then
            self:Msg("Usage: /cdmx bar create <name>")
            return
        end
        if self.db.customBars[name] then
            self:Msg("Bar '" .. name .. "' already exists!")
            return
        end
        self.db.customBars[name] = {
            enabled = true,
            locked = false,
            horizontal = true,
            centered = true,
            iconSize = 40,
            padding = 5,
            position = { point = "CENTER", x = 0, y = 0 },
            squareIcons = self.db.customBarsStyle.squareIcons,
            showBorder = self.db.customBarsStyle.showBorder,
            hotkeyFontSize = 12,
            visibility = "always",
            items = {},
            numSlots = 5,
        }
        self:Msg("Created bar:", name, "- /reload to see it")
        return
    end
    
    -- List bars
    if barName == "list" then
        self:Msg("Custom bars:")
        for name, _ in pairs(self.db.customBars or {}) do
            print("  - '" .. name .. "'")
        end
        return
    end
    
    -- Commands that target an existing bar
    if not self.db.customBars[barName] then
        self:Msg("Bar '" .. barName .. "' not found. Use '/cdmx bar list'")
        return
    end
    
    local settings = self.db.customBars[barName]
    
    if subCmd == "enable" then
        settings.enabled = true
        self:Msg("Bar '" .. barName .. "' enabled")
        if CDM.CustomBars then CDM.CustomBars:UpdateBar(barName) end
    elseif subCmd == "disable" then
        settings.enabled = false
        self:Msg("Bar '" .. barName .. "' disabled")
        if CDM.CustomBars then CDM.CustomBars:UpdateBar(barName) end
    elseif subCmd == "lock" or subCmd == "unlock" then
        self:Msg("Use Edit Mode to reposition bars (ESC > Edit Mode)")
    elseif subCmd == "layout" then
        settings.horizontal = not settings.horizontal
        self:Msg("Bar '" .. barName .. "':", settings.horizontal and "horizontal" or "vertical")
        if CDM.CustomBars then
            CDM.CustomBars:UpdateLayout(barName)
            CDM.CustomBars:UpdateBar(barName)
        end
    elseif subCmd == "delete" then
        self.db.customBars[barName] = nil
        self:Msg("Deleted '" .. barName .. "' - /reload to remove")
    elseif subCmd == "size" then
        local v = tonumber(args[4])
        if v and v >= 20 and v <= 80 then
            settings.iconSize = v
            self:Msg("Bar '" .. barName .. "' icon size:", v)
            if CDM.CustomBars then
                CDM.CustomBars:UpdateLayout(barName)
                CDM.CustomBars:UpdateBar(barName)
            end
        else
            self:Msg("Invalid size. Use 20-80")
        end
    elseif subCmd == "font" then
        local v = tonumber(args[4])
        if v and v >= 8 and v <= 24 then
            settings.hotkeyFontSize = v
            self:Msg("Bar '" .. barName .. "' font size:", v)
            if CDM.CustomBars then CDM.CustomBars:UpdateBar(barName) end
        else
            self:Msg("Invalid font size. Use 8-24")
        end
    elseif subCmd == "slots" then
        local v = tonumber(args[4])
        if v and v >= 1 and v <= 12 then
            settings.numSlots = v
            self:Msg("Bar '" .. barName .. "' slots:", v, "- /reload to apply")
        else
            self:Msg("Invalid slot count. Use 1-12")
        end
    elseif subCmd == "config" then
        self:Msg("Bar: " .. barName)
        print("  /cdmx bar " .. barName .. " size <20-80>")
        print("  /cdmx bar " .. barName .. " font <8-24>")
        print("  /cdmx bar " .. barName .. " slots <1-12>")
    else
        self:Msg("Unknown bar command. Use: enable, disable, layout, delete, size, font, slots")
    end
end

--============================================================================
-- PROFILE SLASH COMMAND HANDLER
--============================================================================

function CDM:HandleProfileCommand(args)
    local subCmd = string.lower(args[2] or "")
    
    -- No subcommand: show current profile
    if subCmd == "" then
        self:Msg("Active profile: " .. self.activeProfile)
        self:Msg("Character: " .. self:GetCharKey())
        return
    end
    
    -- List all profiles and which characters use them
    if subCmd == "list" then
        self:Msg("Profiles:")
        for _, name in ipairs(self:GetProfileList()) do
            local marker = (name == self.activeProfile) and " |cff00ff00(active)|r" or ""
            local chars = {}
            for charKey, pName in pairs(CDMxDB.charMap) do
                if pName == name then
                    table.insert(chars, charKey)
                end
            end
            local charStr = #chars > 0 and (" - " .. table.concat(chars, ", ")) or ""
            print("  " .. name .. marker .. charStr)
        end
        return
    end
    
    -- Switch to a profile
    if subCmd == "use" then
        local profileName = args[3]
        if not profileName or profileName == "" then
            self:Msg("Usage: /cdmx profile use <name>")
            return
        end
        self:SetProfile(profileName)
        return
    end
    
    -- Create a new profile
    if subCmd == "create" or subCmd == "new" then
        local profileName = args[3]
        if not profileName or profileName == "" then
            self:Msg("Usage: /cdmx profile create <name>")
            return
        end
        self:CreateProfile(profileName)
        return
    end
    
    -- Copy a profile
    if subCmd == "copy" then
        local src = args[3]
        local dest = args[4]
        if not src or not dest then
            self:Msg("Usage: /cdmx profile copy <source> <destination>")
            return
        end
        self:CopyProfile(src, dest)
        return
    end
    
    -- Delete a profile
    if subCmd == "delete" then
        local profileName = args[3]
        if not profileName or profileName == "" then
            self:Msg("Usage: /cdmx profile delete <name>")
            return
        end
        self:DeleteProfile(profileName)
        return
    end
    
    -- Rename a profile
    if subCmd == "rename" then
        local oldName = args[3]
        local newName = args[4]
        if not oldName or not newName then
            self:Msg("Usage: /cdmx profile rename <old> <new>")
            return
        end
        self:RenameProfile(oldName, newName)
        return
    end
    
    -- Reset current profile
    if subCmd == "reset" then
        self:ResetProfile()
        return
    end
    
    self:Msg("Unknown profile command. Use: list, use, create, copy, delete, rename, reset")
end
