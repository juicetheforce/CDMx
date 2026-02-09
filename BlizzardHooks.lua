--[[
    CDMx - BlizzardHooks.lua
    Hooks into Blizzard's Essential and Utility cooldown viewers
    to add hotkey text and styling to their icons.
    
    Uses the SetCooldown hook to detect when cooldowns appear,
    then adds/updates hotkey text on each frame.
    
    Author: Juicetheforce (with Claude assistance)
    Target: WoW 12.0.x (Midnight)
]]--

local ADDON_NAME, CDM = ...

CDM.BlizzHooks = {}
local BlizzHooks = CDM.BlizzHooks

--============================================================================
-- STYLING & HOTKEYS ON BLIZZARD FRAMES
--============================================================================

--[[
    Apply CDMx styling (borders, square icons) to a Blizzard cooldown frame.
    These are Blizzard-owned frames so we create our overlays carefully.
]]--
function BlizzHooks:StyleFrame(frame)
    if not frame or frame.CDM_Styled then return end
    
    local icon = frame.Icon or frame.icon
    if not icon then return end
    
    local cmSettings = CDM.db.cooldownManager
    
    -- Square vs rounded icons
    if cmSettings.squareIcons then
        icon:SetTexCoord(0, 1, 0, 1)
    else
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
    
    -- Black border
    if cmSettings.showBorder then
        if not frame.CDM_Border then
            frame.CDM_Border = frame:CreateTexture(nil, "BACKGROUND")
            frame.CDM_Border:SetColorTexture(0, 0, 0, 1)
            frame.CDM_Border:SetAllPoints(frame)
            
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
            icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
        end
    end
    
    frame.CDM_Styled = true
end

--[[
    Add or update hotkey text on a Blizzard cooldown frame.
    Determines font size based on frame height (Essential = large, Utility = small).
]]--
function BlizzHooks:UpdateHotkeyText(frame, spellID, itemID)
    if not frame or not CDM.db.showHotkeys then return end
    
    -- Style the frame first
    self:StyleFrame(frame)
    
    -- Determine font size from frame height
    local frameHeight = frame:GetHeight()
    local fontSize
    if frameHeight and frameHeight < 40 then
        fontSize = CDM.db.utilityFontSize or 12
    else
        fontSize = CDM.db.hotkeyFontSize or 16
    end
    
    local anchor = CDM.db.hotkeyAnchor or "TOPLEFT"
    
    -- Create hotkey FontString if needed, or recreate if anchor changed
    if frame.CDM_HotkeyText and frame.CDM_HotkeyAnchor ~= anchor then
        frame.CDM_HotkeyText:Hide()
        frame.CDM_HotkeyText = nil
    end
    
    if not frame.CDM_HotkeyText then
        local fontPath = CDM.db.hotkeyFont or "Fonts\\FRIZQT__.TTF"
        local outline = CDM.db.hotkeyOutline or "OUTLINE"
        local offsetX = CDM.db.hotkeyOffsetX or 2
        local offsetY = CDM.db.hotkeyOffsetY or -2
        if anchor == "CENTER" then offsetX = 0; offsetY = 0 end
        
        frame.CDM_HotkeyText = frame:CreateFontString(nil, "OVERLAY")
        frame.CDM_HotkeyText:SetFont(fontPath, fontSize, outline)
        frame.CDM_HotkeyText:SetTextColor(1, 1, 1, 1)
        frame.CDM_HotkeyText:SetPoint(anchor, frame, anchor, offsetX, offsetY)
        frame.CDM_HotkeyAnchor = anchor
    end
    
    -- Update font size (may differ between Essential/Utility)
    local fontPath = CDM.db.hotkeyFont or "Fonts\\FRIZQT__.TTF"
    local outline = CDM.db.hotkeyOutline or "OUTLINE"
    frame.CDM_HotkeyText:SetFont(fontPath, fontSize, outline)
    
    -- Look up hotkey
    local hotkey = nil
    if spellID and CDM.Hotkeys then
        hotkey = CDM.Hotkeys:GetHotkeyForSpell(spellID)
    elseif itemID and CDM.Hotkeys then
        hotkey = CDM.Hotkeys:GetHotkeyForItem(itemID)
    end
    
    if hotkey then
        frame.CDM_HotkeyText:SetText(hotkey)
        frame.CDM_HotkeyText:Show()
    else
        frame.CDM_HotkeyText:Hide()
    end
end

--============================================================================
-- FRAME SCANNING
--============================================================================

--[[
    Scan all children of Essential and Utility cooldown viewers
    and update hotkey text on each.
]]--
function BlizzHooks:UpdateAllVisibleFrames()
    if CDM.debug then
        CDM:Print("Scanning cooldown manager frames...")
    end
    
    local updated = 0
    
    local function ScanViewer(viewer, viewerName)
        if not viewer then
            if CDM.debug then CDM:Print(viewerName .. " not found!") end
            return
        end
        for _, child in ipairs({viewer:GetChildren()}) do
            -- Use GetBaseSpellID() method first (reliable), then rangeCheckSpellID,
            -- then cooldownID property as last resort
            local spellID = (child.GetBaseSpellID and child:GetBaseSpellID())
                         or child.rangeCheckSpellID
                         or child.cooldownID
            if spellID then
                self:UpdateHotkeyText(child, spellID, nil)
                updated = updated + 1
            end
        end
    end
    
    ScanViewer(EssentialCooldownViewer, "EssentialCooldownViewer")
    ScanViewer(UtilityCooldownViewer, "UtilityCooldownViewer")
    
    if CDM.debug then
        CDM:Print(string.format("Updated %d cooldown frames", updated))
    end
end

--============================================================================
-- HOOKING
--============================================================================

--[[
    Hook the Cooldown:SetCooldown() method to detect when Blizzard
    creates/updates cooldown frames. This is our main entry point for
    adding hotkeys to cooldown manager icons.
]]--
function BlizzHooks:HookSetCooldownMethod()
    CDM:Print("Hooking Cooldown:SetCooldown()...")
    
    local cooldownMT = getmetatable(ActionButton1Cooldown).__index
    if not cooldownMT or not cooldownMT.SetCooldown then
        CDM:Print("WARNING: Could not find Cooldown metatable")
        return
    end
    
    hooksecurefunc(cooldownMT, "SetCooldown", function(self, start, duration)
        local parent = self:GetParent()
        if not parent then return end
        
        local parentName = parent:GetName() or ""
        
        -- Skip action bar buttons (we only want cooldown manager frames)
        if parentName:match("^ElvUI_Bar") or parentName:match("^ActionButton")
           or parentName:match("^MultiBar") then
            return
        end
        
        local grandparent = parent:GetParent()
        if not grandparent then return end
        
        local gpName = grandparent:GetName() or ""
        if not gpName:match("CooldownViewer") then return end
        
        local spellID = (parent.GetBaseSpellID and parent:GetBaseSpellID())
                     or parent.rangeCheckSpellID
                     or parent.cooldownID
        if spellID then
            BlizzHooks:UpdateHotkeyText(parent, spellID, nil)
        end
    end)
    
    CDM:Print("SetCooldown hook installed")
end

--============================================================================
-- EVENT HANDLING
--============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        BlizzHooks:HookSetCooldownMethod()
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Staggered scans to catch abilities that appear late
        C_Timer.After(3, function() BlizzHooks:UpdateAllVisibleFrames() end)
        C_Timer.After(6, function() BlizzHooks:UpdateAllVisibleFrames() end)
        C_Timer.After(10, function() BlizzHooks:UpdateAllVisibleFrames() end)
        C_Timer.After(15, function()
            if not InCombatLockdown() then
                BlizzHooks:UpdateAllVisibleFrames()
            end
        end)
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        BlizzHooks:UpdateAllVisibleFrames()
        C_Timer.After(0.5, function() BlizzHooks:UpdateAllVisibleFrames() end)
        
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        BlizzHooks:UpdateAllVisibleFrames()
    end
end)

--============================================================================
-- SLASH COMMANDS
--============================================================================

SLASH_CDMSCAN1 = "/cdmxscan"
SlashCmdList["CDMSCAN"] = function()
    CDM:Msg("Manual cooldown frame scan...")
    BlizzHooks:HookSetCooldownMethod()
end

SLASH_CDMUPDATE1 = "/cdtupdate"
SlashCmdList["CDMUPDATE"] = function()
    BlizzHooks:UpdateAllVisibleFrames()
    CDM:Msg("Updated all visible frames")
end

-- Targeted probe: call all spell-related methods on frames missing rangeCheckSpellID
SLASH_CDMXFRAMES1 = "/cdmxframes"
SlashCmdList["CDMXFRAMES"] = function()
    print("=== CDMx METHOD PROBE ===")
    local function ProbeViewer(viewer, viewerName)
        if not viewer then return end
        for i, child in ipairs({viewer:GetChildren()}) do
            local rcID = child.rangeCheckSpellID
            local cdProp = child.cooldownID
            if not rcID then
                print(string.format("--- %s[%d] rangeCheck:nil cooldownID(prop):%s ---",
                    viewerName, i, tostring(cdProp)))
                
                local methods = {
                    "GetCooldownID", "GetBaseSpellID", "GetSpellID",
                    "GetLinkedSpell", "GetAuraSpellID", "GetNameText",
                    "GetIconTexture", "GetSpellTexture", "GetCooldownInfo",
                    "GetSpellCooldownInfo", "GetSpellChargeInfo",
                }
                for _, method in ipairs(methods) do
                    if child[method] and type(child[method]) == "function" then
                        local ok, r1, r2, r3 = pcall(child[method], child)
                        if ok then
                            local parts = {tostring(r1)}
                            if r2 ~= nil then table.insert(parts, tostring(r2)) end
                            if r3 ~= nil then table.insert(parts, tostring(r3)) end
                            print(string.format("  %s() = %s", method, table.concat(parts, ", ")))
                        else
                            print(string.format("  %s() = ERROR: %s", method, tostring(r1)))
                        end
                    end
                end
                print("")
            end
        end
    end
    ProbeViewer(EssentialCooldownViewer, "Essential")
    ProbeViewer(UtilityCooldownViewer, "Utility")
    print("=== END ===")
end
