--[[
    Cooldown Tracker - Core.lua
    Handles addon initialization, namespace setup, and saved variables
    
    Author: Juicetheforce (with Claude assistance)
    Target: WoW 12.0.x (Midnight pre-patch / Midnight)
]]--

-- Create addon namespace
local ADDON_NAME, CDM = ...

-- Version info
CDM.version = "0.1.0-alpha"
CDM.debug = false  -- Show important debug info
CDM.verbose = false  -- Show ALL debug info (very spammy)

-- Initialize saved variables structure
local defaults = {
    enabled = true,
    showHotkeys = true,
    debug = false,  -- Persists across sessions when toggled
    
    -- Hotkey display settings
    hotkeyFontSize = 16,  -- Bigger default font (for Essential cooldowns)
    utilityFontSize = 12, -- Smaller font for Utility cooldowns
    hotkeyFont = "Fonts\\FRIZQT__.TTF",  -- Default WoW font
    hotkeyOffsetX = 2,  -- Offset from anchor point (positive = away from edge)
    hotkeyOffsetY = -2,  -- Negative Y = down from top
    hotkeyAnchor = "TOPLEFT",  -- Where to anchor
    hotkeyOutline = "OUTLINE",  -- OUTLINE, THICKOUTLINE, or NONE
    procGlow = true,  -- Show proc glow when abilities come off cooldown
    
    -- Cooldown Manager styling
    cooldownManager = {
        squareIcons = false,  -- true = square, false = rounded (default Blizzard style)
        showBorder = true,    -- Show black border around icons
    },
    
    -- Trinket bar settings
    trinketBar = {
        enabled = true,
        locked = false,  -- false = draggable, true = locked in place
        horizontal = true,  -- true = horizontal row, false = vertical column
        iconSize = 40,
        padding = 5,  -- Space between icons
        position = { point = "CENTER", x = 0, y = 0 },
        squareIcons = true,  -- true = square (ElvUI style), false = rounded (Blizzard style)
        showBorder = true,  -- Show black border around icons
        hotkeyFontSize = 12,  -- Font size for hotkeys on trinket icons
        visibility = "always",  -- "always", "combat", "noCombat"
    },
    
    -- Custom bars settings (Phase 2+)
    customBars = {
        -- Empty by default - users create their own
    },
    
    -- Custom bars style (applies to all custom bars)
    customBarsStyle = {
        squareIcons = true,   -- Match ElvUI style by default
        showBorder = true,    -- Show black border
    },
}

-- Debug print function
function CDM:Print(...)
    if self.debug then
        print("|cff33ff99CDMx:|r", ...)
    end
end

-- Initialize function
function CDM:Initialize()
    -- Load or create saved variables
    if not CDMxDB then
        CDMxDB = defaults
        self:Print("Initialized with default settings")
    else
        -- Merge defaults with saved settings
        for k, v in pairs(defaults) do
            if CDMxDB[k] == nil then
                CDMxDB[k] = v
            end
        end
        self:Print("Loaded saved settings")
    end
    
    -- Store reference to DB
    self.db = CDMxDB
    
    -- Initialize runtime debug flag from saved setting
    self.debug = self.db.debug or false
    
    self:Print("Version", self.version, "initialized")
end

-- Create event frame for addon loading
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        CDM:Initialize()
    elseif event == "PLAYER_LOGIN" then
        CDM:Print("Player logged in - ready to track cooldowns!")
        
        -- Phase 1: Just confirm we can see the cooldown manager
        if EditModeManagerFrame then
            CDM:Print("Edit Mode detected - Cooldown Manager should be available")
        else
            CDM:Print("WARNING: Edit Mode not found - unexpected for 12.0")
        end
    end
end)

-- Slash commands for testing
SLASH_CDMX1 = "/cdmx"
SLASH_CDMX2 = "/cdm"

SlashCmdList["CDMX"] = function(msg)
    -- Parse arguments BEFORE lowercasing to preserve bar names
    local args = {}
    for word in msg:gmatch("%S+") do
        table.insert(args, word)
    end
    
    -- Only lowercase the first argument (the command)
    local cmd = string.lower(args[1] or "")
    
    if cmd == "" or cmd == "help" then
        print("|cff33ff99Cooldown Tracker Commands:|r")
        print("/cdmx toggle - Enable/disable the addon")
        print("/cdmx debug - Toggle debug output")
        print("/cdmx verbose - Toggle verbose debug (very spammy)")
        print("/cdmx version - Show version info")
        print("/cdmx status - Show current status")
        print("|cff33ff99Hotkey Display:|r")
        print("/cdmx fontsize <number> - Set hotkey font size (default 16)")
        print("/cdmx position <anchor> - Set hotkey position: TOPRIGHT, TOPLEFT, CENTER, etc.")
        print("/cdmx offset <x> <y> - Fine-tune position (e.g., /cdmx offset -5 -5)")
        print("/cdmx outline <type> - Set outline: OUTLINE, THICKOUTLINE, NONE")
        print("/cdmx procglow - Toggle proc glow when abilities are ready")
        print("|cff33ff99Cooldown Manager Styling:|r")
        print("/cdmx cdmsquare - Toggle square vs rounded icons")
        print("/cdmx cdmborder - Toggle black borders on/off")
        print("|cff33ff99Trinket Bar:|r")
        print("/cdmx trinkets - Toggle trinket bar on/off")
        print("/cdmx lock - Lock/unlock trinket bar (prevent dragging)")
        print("/cdmx trinketsize <number> - Set trinket icon size (default 40)")
        print("/cdmx trinketpadding <number> - Set spacing between icons (default 5)")
        print("/cdmx trinketlayout - Toggle horizontal/vertical layout")
        print("/cdmx trinketsquare - Toggle square vs rounded icons")
        print("/cdmx trinketborder - Toggle black borders on/off")
        print("/cdmx reload - Reload UI to apply changes")
        print("|cff33ff99Interface:|r")
        print("/cdmx config - Open settings panel")
        print("|cff33ff99Custom Bars:|r")
        print("/cdmx bar <name> - Manage a custom bar")
        print("  enable/disable - Toggle bar")
        print("  lock/unlock - Lock/unlock position")
        print("  layout - Toggle horizontal/vertical")
        print("  delete - Remove the bar")
    elseif cmd == "bar" then
        local barName = args[2]  -- Preserve case!
        local subCmd = string.lower(args[3] or "")  -- Lowercase command only
        
        if not barName or barName == "" then
            print("|cff33ff99CDMx:|r Usage: /cdmx bar <barname> <command>")
            print("|cff33ff99CDMx:|r Commands: create, list, enable, disable, lock, unlock, layout, delete, config")
            return
        end
        
        -- Create a new bar
        if barName == "create" then
            local newBarName = args[3]
            if not newBarName or newBarName == "" then
                print("|cff33ff99CDMx:|r Usage: /cdmx bar create <name>")
                return
            end
            
            if CDM.db.customBars[newBarName] then
                print("|cff33ff99CDMx:|r Bar '" .. newBarName .. "' already exists!")
                return
            end
            
            CDM.db.customBars[newBarName] = {
                enabled = true,
                locked = false,
                horizontal = true,
                iconSize = 40,
                padding = 5,
                position = { point = "CENTER", x = 0, y = 0 },
                squareIcons = false,
                showBorder = true,
                hotkeyFontSize = 12,
                visibility = "always",
                items = {},
                numSlots = 5,
            }
            print("|cff33ff99CDMx:|r Created custom bar:", newBarName)
            print("|cff33ff99CDMx:|r Type /reload to see your new bar")
            print("|cff33ff99CDMx:|r Use /cdmx bar", newBarName, "config to configure it")
            return
        end
        
        -- List all bars
        if barName == "list" then
            print("|cff33ff99CDMx:|r Custom bars:")
            for name, _ in pairs(CDM.db.customBars or {}) do
                print("  - '" .. name .. "'")
            end
            return
        end
        
        if not CDM.db.customBars[barName] then
            print("|cff33ff99CDMx:|r Bar '" .. barName .. "' not found")
            print("|cff33ff99CDMx:|r Use '/cdmx bar list' to see all bars")
            return
        end
        
        if subCmd == "enable" then
            CDM.db.customBars[barName].enabled = true
            print("|cff33ff99CDMx:|r Bar '" .. barName .. "' enabled")
            if CDM.CustomBars then CDM.CustomBars:UpdateBar(barName) end
        elseif subCmd == "disable" then
            CDM.db.customBars[barName].enabled = false
            print("|cff33ff99CDMx:|r Bar '" .. barName .. "' disabled")
            if CDM.CustomBars then CDM.CustomBars:UpdateBar(barName) end
        elseif subCmd == "lock" then
            CDM.db.customBars[barName].locked = true
            print("|cff33ff99CDMx:|r Bar '" .. barName .. "' locked")
            if CDM.CustomBars then CDM.CustomBars:UpdateLockState(barName) end
        elseif subCmd == "unlock" then
            CDM.db.customBars[barName].locked = false
            print("|cff33ff99CDMx:|r Bar '" .. barName .. "' unlocked")
            if CDM.CustomBars then CDM.CustomBars:UpdateLockState(barName) end
        elseif subCmd == "layout" then
            CDM.db.customBars[barName].horizontal = not CDM.db.customBars[barName].horizontal
            print("|cff33ff99CDMx:|r Bar '" .. barName .. "' layout:", CDM.db.customBars[barName].horizontal and "horizontal" or "vertical")
            if CDM.CustomBars then 
                CDM.CustomBars:UpdateLayout(barName)
                CDM.CustomBars:UpdateBar(barName)
            end
        elseif subCmd == "delete" then
            CDM.db.customBars[barName] = nil
            print("|cff33ff99CDMx:|r Bar '" .. barName .. "' deleted - /reload to remove")
        elseif subCmd == "config" then
            print("|cff33ff99CDMx:|r Configure bar: " .. barName)
            print("|cff33ff99CDMx:|r Commands:")
            print("  /cdmx bar " .. barName .. " size <20-80> - Icon size")
            print("  /cdmx bar " .. barName .. " font <8-24> - Hotkey font size")
            print("  /cdmx bar " .. barName .. " slots <1-12> - Number of slots")
        elseif subCmd == "size" then
            local value = tonumber(args[4])
            if value and value >= 20 and value <= 80 then
                CDM.db.customBars[barName].iconSize = value
                print("|cff33ff99CDMx:|r Bar '" .. barName .. "' icon size set to " .. value)
                if CDM.CustomBars then
                    CDM.CustomBars:UpdateLayout(barName)
                    CDM.CustomBars:UpdateBar(barName)
                end
            else
                print("|cff33ff99CDMx:|r Invalid size. Use 20-80")
            end
        elseif subCmd == "font" then
            local value = tonumber(args[4])
            if value and value >= 8 and value <= 24 then
                CDM.db.customBars[barName].hotkeyFontSize = value
                print("|cff33ff99CDMx:|r Bar '" .. barName .. "' font size set to " .. value)
                if CDM.CustomBars then
                    CDM.CustomBars:UpdateBar(barName)
                end
            else
                print("|cff33ff99CDMx:|r Invalid font size. Use 8-24")
            end
        elseif subCmd == "slots" then
            local value = tonumber(args[4])
            if value and value >= 1 and value <= 12 then
                CDM.db.customBars[barName].numSlots = value
                print("|cff33ff99CDMx:|r Bar '" .. barName .. "' slots set to " .. value)
                print("|cff33ff99CDMx:|r /reload to apply")
            else
                print("|cff33ff99CDMx:|r Invalid slot count. Use 1-12")
            end
        else
            print("|cff33ff99CDMx:|r Unknown command. Use: enable, disable, lock, unlock, layout, delete, config, size, font, slots")
        end
    elseif cmd == "nukebars" then
        CDM.db.customBars = {}
        print("|cff33ff99CDMx:|r Deleted ALL custom bars - /reload to apply")
    elseif cmd == "config" then
        -- Open settings panel
        if SettingsPanel then
            SettingsPanel:Open()
            CDM:Print("Settings panel opened - look for 'CDMx' under AddOns")
        else
            CDM:Print("Open ESC → Interface Options → AddOns → CDMx")
        end
    elseif cmd == "toggle" then
        CDM.db.enabled = not CDM.db.enabled
        CDM:Print("Addon", CDM.db.enabled and "enabled" or "disabled")
    elseif cmd == "debug" then
        CDM.db.debug = not CDM.db.debug
        CDM.debug = CDM.db.debug  -- Update runtime variable
        CDM:Print("Debug mode", CDM.debug and "enabled" or "disabled")
    elseif cmd == "verbose" then
        CDM.verbose = not CDM.verbose
        CDM:Print("Verbose mode", CDM.verbose and "enabled (VERY SPAMMY)" or "disabled")
    elseif cmd == "version" then
        CDM:Print("Version:", CDM.version)
    elseif cmd == "status" then
        CDM:Print("Status:")
        CDM:Print("  Enabled:", CDM.db.enabled)
        CDM:Print("  Debug:", CDM.debug)
        CDM:Print("  Show Hotkeys:", CDM.db.showHotkeys)
        CDM:Print("  Font Size:", CDM.db.hotkeyFontSize)
        CDM:Print("  Position:", CDM.db.hotkeyAnchor)
        CDM:Print("  Offset: X=" .. CDM.db.hotkeyOffsetX .. ", Y=" .. CDM.db.hotkeyOffsetY)
        CDM:Print("  Outline:", CDM.db.hotkeyOutline)
    elseif cmd == "fontsize" then
        local size = tonumber(args[2])
        if size and size >= 8 and size <= 32 then
            CDM.db.hotkeyFontSize = size
            CDM:Print("Font size set to:", size)
            CDM:Print("Type /reload to apply changes")
        else
            print("|cff33ff99CDMx:|r Usage: /cdmx fontsize <8-32>")
        end
    elseif cmd == "position" then
        local pos = args[2] and string.upper(args[2])
        local validPositions = {
            TOPRIGHT = true, TOPLEFT = true, TOP = true,
            BOTTOMRIGHT = true, BOTTOMLEFT = true, BOTTOM = true,
            CENTER = true, LEFT = true, RIGHT = true
        }
        if pos and validPositions[pos] then
            CDM.db.hotkeyAnchor = pos
            CDM:Print("Position set to:", pos)
            CDM:Print("Type /reload to apply changes")
        else
            print("|cff33ff99CDMx:|r Usage: /cdmx position <TOPRIGHT|TOPLEFT|CENTER|etc>")
        end
    elseif cmd == "outline" then
        local outline = args[2] and string.upper(args[2])
        local validOutlines = {
            OUTLINE = true,
            THICKOUTLINE = true,
            NONE = true
        }
        if outline and validOutlines[outline] then
            CDM.db.hotkeyOutline = outline == "NONE" and "" or outline
            CDM:Print("Outline set to:", outline)
            CDM:Print("Type /reload to apply changes")
        else
            print("|cff33ff99CDMx:|r Usage: /cdmx outline <OUTLINE|THICKOUTLINE|NONE>")
        end
    elseif cmd == "offset" then
        local x = tonumber(args[2])
        local y = tonumber(args[3])
        if x and y then
            CDM.db.hotkeyOffsetX = x
            CDM.db.hotkeyOffsetY = y
            CDM:Print(string.format("Offset set to: X=%d, Y=%d", x, y))
            CDM:Print("Type /reload to apply changes")
        else
            print("|cff33ff99CDMx:|r Usage: /cdmx offset <x> <y>")
            CDM:Print("Example: /cdmx offset -8 -8")
        end
    elseif cmd == "reload" then
        ReloadUI()
    elseif cmd == "trinkets" then
        CDM.db.trinketBar.enabled = not CDM.db.trinketBar.enabled
        CDM:Print("Trinket bar", CDM.db.trinketBar.enabled and "enabled" or "disabled")
        if CDM.TrinketBar then
            CDM.TrinketBar:Update()
        end
    elseif cmd == "lock" then
        CDM.db.trinketBar.locked = not CDM.db.trinketBar.locked
        CDM:Print("Trinket bar", CDM.db.trinketBar.locked and "locked" or "unlocked")
        if CDM.TrinketBar then
            CDM.TrinketBar:Update()
        end
    elseif cmd == "trinketsize" then
        local size = tonumber(args[2])
        if size and size >= 20 and size <= 80 then
            CDM.db.trinketBar.iconSize = size
            CDM:Print("Trinket icon size set to:", size)
            if CDM.TrinketBar then
                CDM.TrinketBar:Update()
            end
        else
            print("|cff33ff99CDMx:|r Usage: /cdmx trinketsize <20-80>")
        end
    elseif cmd == "trinketpadding" then
        local padding = tonumber(args[2])
        if padding and padding >= 0 and padding <= 20 then
            CDM.db.trinketBar.padding = padding
            CDM:Print("Trinket padding set to:", padding)
            if CDM.TrinketBar then
                CDM.TrinketBar:Update()
            end
        else
            print("|cff33ff99CDMx:|r Usage: /cdmx trinketpadding <0-20>")
        end
    elseif cmd == "trinketlayout" then
        CDM.db.trinketBar.horizontal = not CDM.db.trinketBar.horizontal
        CDM:Print("Trinket bar layout:", CDM.db.trinketBar.horizontal and "horizontal" or "vertical")
        if CDM.TrinketBar then
            CDM.TrinketBar:Update()
        end
    elseif cmd == "trinketsquare" then
        CDM.db.trinketBar.squareIcons = not CDM.db.trinketBar.squareIcons
        CDM:Print("Square icons:", CDM.db.trinketBar.squareIcons and "enabled" or "disabled")
        CDM:Print("Type /reload to apply changes")
    elseif cmd == "trinketborder" then
        CDM.db.trinketBar.showBorder = not CDM.db.trinketBar.showBorder
        CDM:Print("Icon borders:", CDM.db.trinketBar.showBorder and "enabled" or "disabled")
        CDM:Print("Type /reload to apply changes")
    elseif cmd == "procglow" then
        CDM.db.procGlow = not CDM.db.procGlow
        CDM:Print("Proc glow", CDM.db.procGlow and "enabled" or "disabled")
    elseif cmd == "cdmsquare" then
        CDM.db.cooldownManager.squareIcons = not CDM.db.cooldownManager.squareIcons
        CDM:Print("Cooldown Manager square icons:", CDM.db.cooldownManager.squareIcons and "enabled" or "disabled")
        CDM:Print("Type /reload to apply changes")
    elseif cmd == "cdmborder" then
        CDM.db.cooldownManager.showBorder = not CDM.db.cooldownManager.showBorder
        CDM:Print("Cooldown Manager borders:", CDM.db.cooldownManager.showBorder and "enabled" or "disabled")
        CDM:Print("Type /reload to apply changes")
    else
        CDM:Print("Unknown command. Type /cdmx help for commands.")
    end
end

-- Custom bar item picker dialog
StaticPopupDialogs["CDMX_PICK_ITEMS"] = {
    text = "Select items for bar: %s",
    button1 = "Done",
    button2 = "Cancel",
    OnShow = function(self, data)
        -- TODO: Show checkboxes for available spells/items
    end,
    OnAccept = function(self, data)
        -- TODO: Save selected items
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
