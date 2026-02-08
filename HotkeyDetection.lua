--[[
    Cooldown Tracker - HotkeyDetection.lua
    Scans action bars to detect which hotkey is bound to each spell/item
    
    This is the core of adding hotkey displays to cooldown icons.
    We need to:
    1. Scan all action bar slots
    2. Map spell IDs to action slots
    3. Get the binding for each slot
    4. Cache this information for quick lookup
    
    Author: Ryan (with Claude assistance)
    Target: WoW 12.0.x (Midnight)
]]--

local ADDON_NAME, CDM = ...

-- Create hotkey detection module
CDM.Hotkeys = {}
local Hotkeys = CDM.Hotkeys

-- Cache for spell ID -> hotkey mappings
Hotkeys.cache = {}

-- Spell ID mappings for abilities that use different IDs in different contexts
-- Format: [cooldownManagerSpellID] = actionBarSpellID
Hotkeys.spellIDMap = {
    [49411] = 1217605,   -- Void Metamorphosis (cooldown manager ID -> action bar ID)
    [90226] = 198793,    -- Vengeful Retreat
    -- Reap/Eradicate: No mapping needed, JIT lookup handles it after first use
    -- Note: Voidblade (1245412) is the SAME on both action bar and cooldown manager
}

-- Alternate spell IDs to check during JIT lookup
-- When we see spell A on cooldown manager, also check for spell B on action bars
Hotkeys.alternateSpellIDs = {
    [1226019] = 1225826,  -- When cooldown shows Reap (1226019), also check for Eradicate (1225826)
    [1225826] = 1226019,  -- When cooldown shows Eradicate (1225826), also check for Reap (1226019)
}

-- List of action bar button names to scan
-- These are the standard WoW action bar frame names
local ACTION_BAR_BUTTONS = {
    -- Main action bar (1-12)
    "ActionButton",
    -- Bottom left bar (13-24)
    "MultiBarBottomLeftButton",
    -- Bottom right bar (25-36)
    "MultiBarBottomRightButton",
    -- Right bar (37-48)
    "MultiBarRightButton",
    -- Right bar 2 (49-60)
    "MultiBarLeftButton",
    -- Extra bars (added in various expansions)
    "MultiBar5Button",  -- Bar 5
    "MultiBar6Button",  -- Bar 6
    "MultiBar7Button",  -- Bar 7
}

--[[
    Get the hotkey text for an action bar slot
    This handles shift/ctrl/alt modifiers
]]--
function Hotkeys:GetHotkeyForSlot(slot)
    local key = GetBindingKey("ACTIONBUTTON" .. slot)
    
    if not key then
        return nil
    end
    
    -- Clean up the binding text for display
    key = key:gsub("SHIFT%-", "S")
    key = key:gsub("CTRL%-", "C")
    key = key:gsub("ALT%-", "A")
    key = key:gsub("BUTTON", "M")  -- Mouse buttons
    key = key:gsub("MOUSEWHEELUP", "MwU")
    key = key:gsub("MOUSEWHEELDOWN", "MwD")
    
    return key
end

--[[
    Get spell ID from an action slot
    Returns: spellID, itemID (one will be nil)
]]--
function Hotkeys:GetSpellFromSlot(slot)
    local actionType, id = GetActionInfo(slot)
    
    if actionType == "spell" then
        return id, nil
    elseif actionType == "item" then
        return nil, id
    elseif actionType == "macro" then
        -- Macros can contain spells or items, but we'll handle this in Phase 2
        return nil, nil
    end
    
    return nil, nil
end

--[[
    Scan all action bars and build the cache
    This maps spell IDs to their hotkeys
]]--
function Hotkeys:ScanActionBars()
    -- Clear existing cache
    wipe(self.cache)
    
    local scanned = 0
    local found = 0
    
    -- Method 1: Scan standard action bar slots (works for default UI)
    for slot = 1, 120 do  -- Cover all possible action slots
        local spellID, itemID = self:GetSpellFromSlot(slot)
        
        if spellID or itemID then
            local hotkey = self:GetHotkeyForSlot(slot)
            
            if hotkey then
                local cacheKey = spellID and ("spell:" .. spellID) or ("item:" .. itemID)
                if not self.cache[cacheKey] then  -- Don't overwrite if already found
                    self.cache[cacheKey] = hotkey
                    found = found + 1
                    
                    if CDM.debug and (spellID == 1226019 or spellID == 1245412) then
                        local spellName = spellID and C_Spell.GetSpellName(spellID) or "Unknown"
                        CDM:Print(string.format("Cached slot %d: %s => %s (%s)", 
                            slot, cacheKey, hotkey, spellName))
                    end
                end
            end
        end
        scanned = scanned + 1
    end
    
    -- Method 2: Scan ElvUI action buttons directly (if ElvUI is loaded)
    if ElvUI then
        local E = unpack(ElvUI)
        if E and E.ActionBars then
            for barName, bar in pairs(E.ActionBars.handledBars or {}) do
                if bar.buttons then
                    for _, button in pairs(bar.buttons) do
                        if button.action then
                            local spellID, itemID = self:GetSpellFromSlot(button.action)
                            if spellID or itemID then
                                -- Get hotkey directly from button (ElvUI stores it)
                                local hotkey = button.keyBoundTarget or button.bindName
                                if hotkey then
                                    hotkey = GetBindingKey(hotkey)
                                    if hotkey then
                                        -- Clean up the binding text
                                        hotkey = hotkey:gsub("SHIFT%-", "S")
                                        hotkey = hotkey:gsub("CTRL%-", "C")
                                        hotkey = hotkey:gsub("ALT%-", "A")
                                        hotkey = hotkey:gsub("BUTTON", "M")
                                        
                                        local cacheKey = spellID and ("spell:" .. spellID) or ("item:" .. itemID)
                                        self.cache[cacheKey] = hotkey
                                        found = found + 1
                                        
                                        if CDM.verbose then
                                            CDM:Print("Found ElvUI binding:", cacheKey, "=", hotkey)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    if CDM.debug then
        CDM:Print(string.format("Scanned %d slots, found %d with hotkeys", scanned, found))
    end
end

--[[
    Get hotkey for a spell ID
    Returns: hotkey string or nil
]]--
function Hotkeys:GetHotkeyForSpell(spellID)
    if not spellID then return nil end
    
    -- Check if this spell ID needs to be mapped to a different ID
    local mappedID = self.spellIDMap[spellID]
    if mappedID then
        if CDM.debug then
            CDM:Print(string.format("Mapped spell %d -> %d", spellID, mappedID))
        end
        spellID = mappedID
    end
    
    local cacheKey = "spell:" .. spellID
    local cached = self.cache[cacheKey]
    
    -- If in cache, return it
    if cached then
        return cached
    end
    
    -- NOT in cache - do just-in-time lookup
    if CDM.debug then
        CDM:Print(string.format("⚡ JIT lookup for spell:%d", spellID))
    end
    
    -- Build list of spell IDs to check (original + alternates)
    local spellIDsToCheck = {spellID}
    local alternateID = self.alternateSpellIDs[spellID]
    if alternateID then
        table.insert(spellIDsToCheck, alternateID)
        if CDM.debug then
            CDM:Print(string.format("  Also checking alternate: %d", alternateID))
        end
    end
    
    -- Scan all action slots quickly to find any of these spell IDs
    for slot = 1, 120 do
        local actionType, id = GetActionInfo(slot)
        if actionType == "spell" then
            -- Check if this matches any of our target spell IDs
            for _, targetID in ipairs(spellIDsToCheck) do
                if id == targetID then
                    local hotkey = self:GetHotkeyForSlot(slot)
                    if hotkey then
                        -- Cache it for next time (using ORIGINAL spell ID as key)
                        self.cache[cacheKey] = hotkey
                        if CDM.debug then
                            CDM:Print(string.format("  ✓ Found spell:%d in slot %d: %s", id, slot, hotkey))
                        end
                        return hotkey
                    end
                end
            end
        end
    end
    
    -- Still not found - check ElvUI directly
    if ElvUI then
        local E = unpack(ElvUI)
        if E and E.ActionBars then
            for barName, bar in pairs(E.ActionBars.handledBars or {}) do
                if bar.buttons then
                    for _, button in pairs(bar.buttons) do
                        if button.action then
                            local actionType, id = GetActionInfo(button.action)
                            if actionType == "spell" and id == spellID then
                                local hotkey = button.keyBoundTarget or button.bindName
                                if hotkey then
                                    hotkey = GetBindingKey(hotkey)
                                    if hotkey then
                                        hotkey = hotkey:gsub("SHIFT%-", "S")
                                        hotkey = hotkey:gsub("CTRL%-", "C")
                                        hotkey = hotkey:gsub("ALT%-", "A")
                                        -- Cache it
                                        self.cache[cacheKey] = hotkey
                                        if CDM.debug then
                                            CDM:Print(string.format("  ✓ Found in ElvUI: %s", hotkey))
                                        end
                                        return hotkey
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Not found anywhere
    return nil
end

--[[
    Get hotkey for an item ID
    Returns: hotkey string or nil
]]--
function Hotkeys:GetHotkeyForItem(itemID)
    if not itemID then return nil end
    return self.cache["item:" .. itemID]
end

--[[
    Force a rescan of action bars
    Called when action bars change
]]--
function Hotkeys:Update()
    self:ScanActionBars()
end

-- Event handling for keeping hotkeys updated
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
frame:RegisterEvent("UPDATE_BINDINGS")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

-- Track the last action bar state to detect actual changes
local lastActionBarState = {}
local function GetActionBarState()
    local state = {}
    for slot = 1, 120 do
        local actionType, id = GetActionInfo(slot)
        if actionType and id then
            state[slot] = actionType .. ":" .. id
        end
    end
    return state
end

-- Throttle rescanning
local lastRescanTime = 0
local RESCAN_THROTTLE = 2  -- At most once per 2 seconds

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Initial scan when player loads in
        if CDM.debug then
            CDM:Print("Performing initial action bar scan...")
        end
        C_Timer.After(2, function()  -- Small delay to let everything load
            Hotkeys:ScanActionBars()
            lastActionBarState = GetActionBarState()
        end)
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        local slot = ...
        
        -- Throttle to prevent spam
        local now = GetTime()
        if now - lastRescanTime < RESCAN_THROTTLE then
            return
        end
        
        -- Check if this is an actual change (ability moved) vs just a state update
        local actionType, id = GetActionInfo(slot)
        local newState = actionType and id and (actionType .. ":" .. id) or nil
        local oldState = lastActionBarState[slot]
        
        if newState ~= oldState then
            -- Actual change detected - do a FULL rescan to catch everything
            if CDM.debug then
                CDM:Print(string.format("Action bar slot %d changed: %s -> %s", 
                    slot, 
                    oldState or "empty", 
                    newState or "empty"))
                CDM:Print("Performing full action bar rescan...")
            end
            lastRescanTime = now
            
            -- Full rescan
            Hotkeys:ScanActionBars()
            
            -- Update cooldown manager frames after a small delay
            C_Timer.After(0.5, function()
                if CDM.BlizzHooks then
                    if CDM.debug then
                        CDM:Print("Updating cooldown manager frames...")
                    end
                    CDM.BlizzHooks:UpdateAllVisibleFrames()
                end
            end)
            
            -- Update state
            lastActionBarState = GetActionBarState()
        end
    elseif event == "UPDATE_BINDINGS" then
        -- Keybindings changed - always rescan
        if CDM.debug then
            CDM:Print("Keybindings updated, rescanning...")
        end
        Hotkeys:Update()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        -- Spec or talent changed, abilities might be different
        if CDM.debug then
            CDM:Print("Spec/talents changed, rescanning...")
        end
        C_Timer.After(1, function()  -- Small delay to let spec change complete
            Hotkeys:Update()
            lastActionBarState = GetActionBarState()
        end)
    end
end)

-- Expose a manual update command for testing
SLASH_CDMHOTKEYS1 = "/cdthotkeys"
SlashCmdList["CDMHOTKEYS"] = function(msg)
    CDM:Print("Manually rescanning action bars...")
    Hotkeys:ScanActionBars()
    
    -- Also update cooldown manager frames
    if CDM.BlizzHooks then
        CDM.BlizzHooks:UpdateAllVisibleFrames()
    end
    
    -- Print some examples if debug is on
    if CDM.debug then
        CDM:Print("Sample cache entries:")
        local count = 0
        for key, hotkey in pairs(Hotkeys.cache) do
            CDM:Print(" ", key, "=>", hotkey)
            count = count + 1
            if count >= 10 then break end  -- Show first 10
        end
    end
end

-- Command to dump all spell IDs for comparison
SLASH_CDMDUMP1 = "/cdmxdump"
SlashCmdList["CDMDUMP"] = function(msg)
    print("=== COOLDOWN TRACKER SPELL ID DUMP ===")
    print("")
    print("--- Action Bar Spell IDs ---")
    for slot = 1, 120 do
        local actionType, id = GetActionInfo(slot)
        if actionType == "spell" then
            local spellName = C_Spell.GetSpellName(id)
            print(string.format("Slot %d: spell:%d (%s)", slot, id, spellName or "Unknown"))
        elseif actionType == "item" then
            local itemName = C_Item.GetItemNameByID(id)
            print(string.format("Slot %d: item:%d (%s)", slot, id, itemName or "Unknown"))
        end
    end
    
    print("")
    print("--- Cooldown Manager Spell IDs ---")
    
    -- Check Essential viewer
    if EssentialCooldownViewer then
        for _, child in ipairs({EssentialCooldownViewer:GetChildren()}) do
            local spellID = child.rangeCheckSpellID or child.cooldownID
            if spellID then
                local spellName = C_Spell.GetSpellName(spellID)
                print(string.format("Essential: spell:%d (%s)", spellID, spellName or "Unknown"))
            end
        end
    end
    
    -- Check Utility viewer
    if UtilityCooldownViewer then
        for _, child in ipairs({UtilityCooldownViewer:GetChildren()}) do
            local spellID = child.rangeCheckSpellID or child.cooldownID
            if spellID then
                local spellName = C_Spell.GetSpellName(spellID)
                print(string.format("Utility: spell:%d (%s)", spellID, spellName or "Unknown"))
            end
        end
    end
    
    print("")
    print("=== END DUMP ===")
    print("Look for spells that appear in Cooldown Manager but NOT in Action Bars (or with different IDs)")
end

SLASH_CDMMAP1 = "/cdtmap"
SlashCmdList["CDMMAP"] = function(msg)
    local args = {}
    for word in msg:gmatch("%S+") do
        table.insert(args, word)
    end
    
    if #args == 0 then
        print("CDMx: Current spell ID mappings:")
        for cdmID, barID in pairs(Hotkeys.spellIDMap) do
            print(string.format("  %d -> %d", cdmID, barID))
        end
        print("CDMx: Usage: /cdtmap <cooldownManagerSpellID> <actionBarSpellID>")
        return
    end
    
    local cdmID = tonumber(args[1])
    local barID = tonumber(args[2])
    
    if cdmID and barID then
        Hotkeys.spellIDMap[cdmID] = barID
        print(string.format("CDMx: Added mapping: %d -> %d", cdmID, barID))
        print("CDMx: Run /cdtupdate to apply")
    else
        print("CDMx: Usage: /cdtmap <cooldownManagerSpellID> <actionBarSpellID>")
    end
end
SLASH_CDMSLOT1 = "/cdmxslot"
SlashCmdList["CDMSLOT"] = function(msg)
    local slot = tonumber(msg)
    if not slot then
        CDM:Print("Usage: /cdmxslot <number>  (e.g., /cdmxslot 4)")
        return
    end
    
    CDM:Print(string.format("=== Action Slot %d ===", slot))
    local actionType, id = GetActionInfo(slot)
    
    if actionType then
        CDM:Print("Type:", actionType)
        CDM:Print("ID:", id)
        
        if actionType == "spell" then
            local spellName = C_Spell.GetSpellName(id)
            CDM:Print("Spell Name:", spellName or "Unknown")
        elseif actionType == "item" then
            local itemName = C_Item.GetItemNameByID(id)
            CDM:Print("Item Name:", itemName or "Unknown")
        end
        
        local hotkey = Hotkeys:GetHotkeyForSlot(slot)
        CDM:Print("Hotkey:", hotkey or "None")
        
        -- Check if it's in cache
        local cacheKey = actionType == "spell" and ("spell:" .. id) or ("item:" .. id)
        local cached = Hotkeys.cache[cacheKey]
        CDM:Print("In cache:", cached or "NO")
    else
        CDM:Print("Empty slot")
    end
end
