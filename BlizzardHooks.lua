local ADDON_NAME, CDM = ...

print("CDMx: BlizzardHooks.lua loaded")

CDM.BlizzHooks = {}
local BlizzHooks = CDM.BlizzHooks

BlizzHooks.hookedFrames = {}
BlizzHooks.activeCooldowns = {}

-- Proc glow functions (simplified)
function BlizzHooks:ShowProcGlow(frame)
    -- TODO: Add proc glow back later
end

function BlizzHooks:HideProcGlow(frame)
    -- TODO: Add proc glow back later
end

function BlizzHooks:CheckCooldownsForProcGlow()
    -- TODO: Add proc glow back later
end

function BlizzHooks:AddHotkeyToFrame(frame, spellID, itemID)
    if not frame or not CDM.db.showHotkeys then return end
    
    -- Check if hotkey text exists and if anchor changed - recreate if needed
    local anchor = CDM.db.hotkeyAnchor or "TOPLEFT"
    if frame.CDM_HotkeyText and frame.CDM_HotkeyAnchor ~= anchor then
        frame.CDM_HotkeyText:Hide()
        frame.CDM_HotkeyText = nil
    end
    
    if frame.CDM_HotkeyText then return frame.CDM_HotkeyText end
    
    -- Add backdrop border (ElvUI style)
    if CDM.db.cooldownManager.showBorder and not frame.CDM_Backdrop then
        frame.CDM_Backdrop = frame:CreateTexture(nil, "BACKGROUND")
        frame.CDM_Backdrop:SetAllPoints(frame)
        frame.CDM_Backdrop:SetColorTexture(0, 0, 0, 1)
        
        -- Find the icon texture and adjust it for border
        for _, region in ipairs({frame:GetRegions()}) do
            if region:GetObjectType() == "Texture" and region:GetDrawLayer() == "BACKGROUND" then
                region:ClearAllPoints()
                region:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
                region:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
                
                -- Square icons option
                if CDM.db.cooldownManager.squareIcons then
                    region:SetTexCoord(0, 1, 0, 1)
                end
                break
            end
        end
    end
    
    local hotkeyText = frame:CreateFontString(nil, "OVERLAY")
    local fontPath = CDM.db.hotkeyFont or "Fonts\\FRIZQT__.TTF"
    local outline = CDM.db.hotkeyOutline or "OUTLINE"
    local offsetX = CDM.db.hotkeyOffsetX or 2
    local offsetY = CDM.db.hotkeyOffsetY or -2
    
    -- Use zero offset for CENTER anchor
    if anchor == "CENTER" then
        offsetX = 0
        offsetY = 0
    end
    
    -- Use different font size for Utility vs Essential cooldowns
    local frameHeight = frame:GetHeight()
    local fontSize
    if frameHeight and frameHeight < 40 then
        -- Utility cooldowns (smaller icons)
        fontSize = CDM.db.utilityFontSize or 12
    else
        -- Essential cooldowns (larger icons)
        fontSize = CDM.db.hotkeyFontSize or 16
    end
    
    hotkeyText:SetFont(fontPath, fontSize, outline)
    hotkeyText:SetTextColor(1, 1, 1, 1)
    hotkeyText:SetPoint(anchor, frame, anchor, offsetX, offsetY)
    
    frame.CDM_HotkeyText = hotkeyText
    frame.CDM_HotkeyAnchor = anchor  -- Store the anchor we used
    return hotkeyText
end

function BlizzHooks:UpdateHotkeyText(frame, spellID, itemID)
    if not frame or not CDM.db.showHotkeys then return end
    
    -- Apply styling to the frame (borders, square icons)
    self:StyleCooldownFrame(frame)
    
    local hotkeyText = self:AddHotkeyToFrame(frame, spellID, itemID)
    if not hotkeyText then return end
    
    local hotkey = nil
    if spellID then
        hotkey = CDM.Hotkeys:GetHotkeyForSpell(spellID)
    elseif itemID then
        hotkey = CDM.Hotkeys:GetHotkeyForItem(itemID)
    end
    
    if hotkey then
        hotkeyText:SetText(hotkey)
        hotkeyText:Show()
        if CDM.debug then
            CDM:Print(string.format("Updated hotkey: %s -> %s", 
                spellID and ("spell:" .. spellID) or ("item:" .. itemID), hotkey))
        end
    else
        hotkeyText:Hide()
    end
end

function BlizzHooks:StyleCooldownFrame(frame)
    if not frame then return end
    if frame.CDM_Styled then return end  -- Already styled
    
    -- Find the icon texture (Blizzard cooldown frames have an 'Icon' child)
    local icon = frame.Icon or frame.icon
    if not icon then return end
    
    -- Apply square/rounded styling
    if CDM.db.cooldownManager and CDM.db.cooldownManager.squareIcons then
        icon:SetTexCoord(0, 1, 0, 1)  -- Square
    else
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)  -- Rounded (default)
    end
    
    -- Add black border
    if CDM.db.cooldownManager and CDM.db.cooldownManager.showBorder then
        if not frame.CDM_Border then
            frame.CDM_Border = frame:CreateTexture(nil, "BACKGROUND")
            frame.CDM_Border:SetColorTexture(0, 0, 0, 1)
            frame.CDM_Border:SetAllPoints(frame)
            
            -- Inset the icon to show border
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
            icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
        end
    end
    
    frame.CDM_Styled = true
end

function BlizzHooks:UpdateAllVisibleFrames()
    if CDM.debug then
        CDM:Print("Scanning for visible Cooldown Manager frames...")
    end
    local updated = 0
    
    if EssentialCooldownViewer then
        for _, child in ipairs({EssentialCooldownViewer:GetChildren()}) do
            local spellID = child.rangeCheckSpellID or child.cooldownID
            if spellID then
                self:UpdateHotkeyText(child, spellID, nil)
                
                -- Update font size on existing hotkey text
                if child.CDM_HotkeyText then
                    local frameHeight = child:GetHeight()
                    local fontSize
                    if frameHeight and frameHeight < 40 then
                        fontSize = CDM.db.utilityFontSize or 12
                    else
                        fontSize = CDM.db.hotkeyFontSize or 16
                    end
                    local fontPath = CDM.db.hotkeyFont or "Fonts\\FRIZQT__.TTF"
                    local outline = CDM.db.hotkeyOutline or "OUTLINE"
                    child.CDM_HotkeyText:SetFont(fontPath, fontSize, outline)
                end
                
                updated = updated + 1
            end
        end
    else
        if CDM.debug then
            CDM:Print("EssentialCooldownViewer not found!")
        end
    end
    
    if UtilityCooldownViewer then
        for _, child in ipairs({UtilityCooldownViewer:GetChildren()}) do
            local spellID = child.rangeCheckSpellID or child.cooldownID
            if spellID then
                self:UpdateHotkeyText(child, spellID, nil)
                
                -- Update font size on existing hotkey text
                if child.CDM_HotkeyText then
                    local frameHeight = child:GetHeight()
                    local fontSize
                    if frameHeight and frameHeight < 40 then
                        fontSize = CDM.db.utilityFontSize or 12
                    else
                        fontSize = CDM.db.hotkeyFontSize or 16
                    end
                    local fontPath = CDM.db.hotkeyFont or "Fonts\\FRIZQT__.TTF"
                    local outline = CDM.db.hotkeyOutline or "OUTLINE"
                    child.CDM_HotkeyText:SetFont(fontPath, fontSize, outline)
                end
                
                updated = updated + 1
            end
        end
    else
        if CDM.debug then
            CDM:Print("UtilityCooldownViewer not found!")
        end
    end
    
    if CDM.debug then
        CDM:Print(string.format("Updated %d cooldown frames", updated))
    end
end

function BlizzHooks:HookSetCooldownMethod()
    CDM:Print("Hooking Cooldown:SetCooldown() method...")
    
    local cooldownMT = getmetatable(ActionButton1Cooldown).__index
    if not cooldownMT or not cooldownMT.SetCooldown then
        CDM:Print("WARNING: Could not find Cooldown metatable")
        return
    end
    
    local trackedFrames = {}
    
    hooksecurefunc(cooldownMT, "SetCooldown", function(self, start, duration)
        local parent = self:GetParent()
        if not parent then return end
        
        local parentName = parent:GetName() or "unnamed"
        
        -- Filter action bars
        if parentName:match("^ElvUI_Bar") or parentName:match("^ActionButton") or parentName:match("^MultiBar") then
            return
        end
        
        if trackedFrames[parent] then return end
        trackedFrames[parent] = true
        
        local grandparent = parent:GetParent()
        if not grandparent then return end
        
        local gpName = grandparent:GetName() or "unnamed"
        if not gpName:match("CooldownViewer") then return end
        
        if CDM.debug then
            CDM:Print("  Grandparent:", gpName)
        end
        
        local spellID = parent.rangeCheckSpellID or parent.cooldownID
        if spellID then
            if CDM.debug then
                CDM:Print(string.format("    ✓ Found spell ID: %d", spellID))
            end
            BlizzHooks:UpdateHotkeyText(parent, spellID, nil)
        end
    end)
    
    CDM:Print("SetCooldown hook installed")
end

function BlizzHooks:ScanForCooldownFrames()
    self:HookSetCooldownMethod()
end

-- Initialize
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- After combat
frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")  -- When spells are used

frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        BlizzHooks:ScanForCooldownFrames()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Update visible frames after a short delay
        C_Timer.After(3, function()
            BlizzHooks:UpdateAllVisibleFrames()
        end)
        
        -- Do additional scans to catch transformed abilities (e.g., Eradicate on login)
        C_Timer.After(6, function()
            BlizzHooks:UpdateAllVisibleFrames()
        end)
        
        C_Timer.After(10, function()
            BlizzHooks:UpdateAllVisibleFrames()
        end)
        
        -- Final scan when combat drops (in case we logged in during combat)
        C_Timer.After(15, function()
            if not InCombatLockdown() then
                BlizzHooks:UpdateAllVisibleFrames()
            end
        end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Update immediately after leaving combat
        BlizzHooks:UpdateAllVisibleFrames()
        
        -- And again after a short delay to catch any stragglers
        C_Timer.After(0.5, function()
            BlizzHooks:UpdateAllVisibleFrames()
        end)
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        -- Update when any spell cooldown changes (catches ability usage)
        BlizzHooks:UpdateAllVisibleFrames()
    end
end)

-- Commands
SLASH_CDMSCAN1 = "/cdmxscan"
SlashCmdList["CDMSCAN"] = function()
    CDM:Print("=== Manual Cooldown Frame Scan ===")
    BlizzHooks:ScanForCooldownFrames()
end

SLASH_CDMUPDATE1 = "/cdtupdate"
SlashCmdList["CDMUPDATE"] = function()
    BlizzHooks:UpdateAllVisibleFrames()
end

SLASH_CDMRESET1 = "/cdtreset"
SlashCmdList["CDMRESET"] = function()
    CDM:Print("Clearing tracked frames")
    wipe(BlizzHooks.hookedFrames)
end
