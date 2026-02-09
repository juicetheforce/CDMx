--[[
    CDMx - HotkeyDetection.lua
    Scans action bars to detect which hotkey is bound to each spell/item.
    
    Core system for adding hotkey displays to cooldown icons:
    1. Scan all action bar slots on login and changes
    2. Map spell/item IDs to action slots
    3. Get the binding for each slot
    4. Cache for quick lookup (with JIT fallback for misses)
    
    Author: Juicetheforce (with Claude assistance)
    Target: WoW 12.0.x (Midnight)
]]--

local ADDON_NAME, CDM = ...

CDM.Hotkeys = {}
local Hotkeys = CDM.Hotkeys

-- Cache: "spell:12345" -> "S1", "item:67890" -> "CM4"
Hotkeys.cache = {}

--============================================================================
-- SPELL ID MAPPINGS
--============================================================================

-- Cooldown Manager sometimes uses different spell IDs than action bars.
-- Map: [cooldownManagerID] = actionBarID
Hotkeys.spellIDMap = {
    [49411] = 1217605,   -- Void Metamorphosis
    [90226] = 198793,    -- Vengeful Retreat
}

-- When looking up spell A, also check spell B (for transformed abilities)
Hotkeys.alternateSpellIDs = {
    [1226019] = 1225826,  -- Reap <-> Eradicate
    [1225826] = 1226019,
}

--============================================================================
-- ACTION BAR SCANNING
--============================================================================

--[[
    Get the formatted hotkey text for an action bar slot number.
]]--
function Hotkeys:GetHotkeyForSlot(slot)
    local key = GetBindingKey("ACTIONBUTTON" .. slot)
    if not key then return nil end
    return CDM.UI:FormatHotkey(key)
end

--[[
    Get spell/item ID from an action slot.
    Returns: spellID, itemID (one will be nil)
]]--
function Hotkeys:GetSpellFromSlot(slot)
    local actionType, id = GetActionInfo(slot)
    if actionType == "spell" then
        return id, nil
    elseif actionType == "item" then
        return nil, id
    end
    return nil, nil
end

--[[
    Full scan of all action bars. Builds the spell/item -> hotkey cache.
]]--
function Hotkeys:ScanActionBars()
    wipe(self.cache)
    
    local found = 0
    
    -- Scan standard action bar slots (covers all bar addons)
    for slot = 1, 120 do
        local spellID, itemID = self:GetSpellFromSlot(slot)
        if spellID or itemID then
            local hotkey = self:GetHotkeyForSlot(slot)
            if hotkey then
                local cacheKey = spellID and ("spell:" .. spellID) or ("item:" .. itemID)
                if not self.cache[cacheKey] then
                    self.cache[cacheKey] = hotkey
                    found = found + 1
                end
            end
        end
    end
    
    -- Also scan ElvUI action buttons directly if available
    if ElvUI then
        local E = unpack(ElvUI)
        if E and E.ActionBars then
            for _, bar in pairs(E.ActionBars.handledBars or {}) do
                if bar.buttons then
                    for _, button in pairs(bar.buttons) do
                        if button.action then
                            local spellID, itemID = self:GetSpellFromSlot(button.action)
                            if spellID or itemID then
                                local bindTarget = button.keyBoundTarget or button.bindName
                                if bindTarget then
                                    local rawKey = GetBindingKey(bindTarget)
                                    if rawKey then
                                        local hotkey = CDM.UI:FormatHotkey(rawKey)
                                        local cacheKey = spellID and ("spell:" .. spellID) or ("item:" .. itemID)
                                        if not self.cache[cacheKey] then
                                            self.cache[cacheKey] = hotkey
                                            found = found + 1
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
        CDM:Print(string.format("Scanned action bars, found %d hotkeys", found))
    end
end

--============================================================================
-- HOTKEY LOOKUP
--============================================================================

--[[
    Get hotkey for a spell ID. Checks cache first, then does JIT lookup
    including spell ID mapping and alternate IDs.
]]--
function Hotkeys:GetHotkeyForSpell(spellID)
    if not spellID then return nil end
    
    -- Apply spell ID mapping
    local mappedID = self.spellIDMap[spellID]
    if mappedID then
        spellID = mappedID
    end
    
    -- Check cache
    local cacheKey = "spell:" .. spellID
    if self.cache[cacheKey] then
        return self.cache[cacheKey]
    end
    
    -- JIT lookup: scan all slots for this spell (and alternates)
    local idsToCheck = { spellID }
    local alt = self.alternateSpellIDs[spellID]
    if alt then table.insert(idsToCheck, alt) end
    
    for slot = 1, 120 do
        local actionType, id = GetActionInfo(slot)
        if actionType == "spell" then
            for _, targetID in ipairs(idsToCheck) do
                if id == targetID then
                    local hotkey = self:GetHotkeyForSlot(slot)
                    if hotkey then
                        self.cache[cacheKey] = hotkey
                        if CDM.debug then
                            CDM:Print(string.format("JIT: spell:%d slot %d -> %s", id, slot, hotkey))
                        end
                        return hotkey
                    end
                end
            end
        end
    end
    
    -- Try ElvUI fallback
    if ElvUI then
        local E = unpack(ElvUI)
        if E and E.ActionBars then
            for _, bar in pairs(E.ActionBars.handledBars or {}) do
                if bar.buttons then
                    for _, button in pairs(bar.buttons) do
                        if button.action then
                            local actionType, id = GetActionInfo(button.action)
                            if actionType == "spell" and id == spellID then
                                local bindTarget = button.keyBoundTarget or button.bindName
                                if bindTarget then
                                    local rawKey = GetBindingKey(bindTarget)
                                    if rawKey then
                                        local hotkey = CDM.UI:FormatHotkey(rawKey)
                                        self.cache[cacheKey] = hotkey
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
    
    return nil
end

--[[
    Get hotkey for an item ID. Cache-only (no JIT for items).
]]--
function Hotkeys:GetHotkeyForItem(itemID)
    if not itemID then return nil end
    return self.cache["item:" .. itemID]
end

--[[
    Force rescan of action bars and update all displays.
]]--
function Hotkeys:Update()
    self:ScanActionBars()
end

--============================================================================
-- EVENT HANDLING
--============================================================================

local lastRescanTime = 0
local RESCAN_THROTTLE = 2
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

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
eventFrame:RegisterEvent("UPDATE_BINDINGS")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, function()
            Hotkeys:ScanActionBars()
            lastActionBarState = GetActionBarState()
        end)
        
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        local slot = ...
        local now = GetTime()
        if now - lastRescanTime < RESCAN_THROTTLE then return end
        
        local actionType, id = GetActionInfo(slot)
        local newState = actionType and id and (actionType .. ":" .. id) or nil
        if newState ~= lastActionBarState[slot] then
            lastRescanTime = now
            Hotkeys:ScanActionBars()
            lastActionBarState = GetActionBarState()
            
            C_Timer.After(0.5, function()
                if CDM.BlizzHooks then
                    CDM.BlizzHooks:UpdateAllVisibleFrames()
                end
            end)
        end
        
    elseif event == "UPDATE_BINDINGS" then
        Hotkeys:Update()
        
    elseif event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        C_Timer.After(1, function()
            Hotkeys:Update()
            lastActionBarState = GetActionBarState()
        end)
    end
end)

--============================================================================
-- SLASH COMMANDS (debug/diagnostics)
--============================================================================

SLASH_CDMHOTKEYS1 = "/cdthotkeys"
SlashCmdList["CDMHOTKEYS"] = function()
    CDM:Msg("Rescanning action bars...")
    Hotkeys:ScanActionBars()
    if CDM.BlizzHooks then
        CDM.BlizzHooks:UpdateAllVisibleFrames()
    end
    if CDM.debug then
        CDM:Print("Sample cache:")
        local count = 0
        for key, hotkey in pairs(Hotkeys.cache) do
            CDM:Print("  ", key, "=>", hotkey)
            count = count + 1
            if count >= 10 then break end
        end
    end
end

SLASH_CDMDUMP1 = "/cdmxdump"
SlashCmdList["CDMDUMP"] = function()
    print("=== CDMx SPELL ID DUMP ===")
    print("")
    print("--- Action Bar ---")
    for slot = 1, 120 do
        local actionType, id = GetActionInfo(slot)
        if actionType == "spell" then
            print(string.format("  Slot %d: spell:%d (%s)", slot, id, C_Spell.GetSpellName(id) or "?"))
        elseif actionType == "item" then
            print(string.format("  Slot %d: item:%d (%s)", slot, id, C_Item.GetItemNameByID(id) or "?"))
        end
    end
    print("")
    print("--- Cooldown Manager ---")
    if EssentialCooldownViewer then
        for _, child in ipairs({EssentialCooldownViewer:GetChildren()}) do
            local sid = child.rangeCheckSpellID or child.cooldownID
            if sid then
                print(string.format("  Essential: spell:%d (%s)", sid, C_Spell.GetSpellName(sid) or "?"))
            end
        end
    end
    if UtilityCooldownViewer then
        for _, child in ipairs({UtilityCooldownViewer:GetChildren()}) do
            local sid = child.rangeCheckSpellID or child.cooldownID
            if sid then
                print(string.format("  Utility: spell:%d (%s)", sid, C_Spell.GetSpellName(sid) or "?"))
            end
        end
    end
    print("=== END ===")
end

SLASH_CDMMAP1 = "/cdtmap"
SlashCmdList["CDMMAP"] = function(msg)
    local args = {}
    for word in msg:gmatch("%S+") do table.insert(args, word) end
    
    if #args == 0 then
        print("CDMx spell ID mappings:")
        for cdmID, barID in pairs(Hotkeys.spellIDMap) do
            print(string.format("  %d -> %d", cdmID, barID))
        end
        print("Usage: /cdtmap <cooldownManagerID> <actionBarID>")
        return
    end
    
    local cdmID, barID = tonumber(args[1]), tonumber(args[2])
    if cdmID and barID then
        Hotkeys.spellIDMap[cdmID] = barID
        CDM:Msg(string.format("Mapped: %d -> %d (run /cdtupdate to apply)", cdmID, barID))
    else
        CDM:Msg("Usage: /cdtmap <cooldownManagerID> <actionBarID>")
    end
end

SLASH_CDMSLOT1 = "/cdmxslot"
SlashCmdList["CDMSLOT"] = function(msg)
    local slot = tonumber(msg)
    if not slot then
        CDM:Msg("Usage: /cdmxslot <number>")
        return
    end
    
    CDM:Msg(string.format("=== Slot %d ===", slot))
    local actionType, id = GetActionInfo(slot)
    if actionType then
        CDM:Msg("Type:", actionType, "ID:", id)
        if actionType == "spell" then
            CDM:Msg("Name:", C_Spell.GetSpellName(id) or "?")
        elseif actionType == "item" then
            CDM:Msg("Name:", C_Item.GetItemNameByID(id) or "?")
        end
        CDM:Msg("Hotkey:", Hotkeys:GetHotkeyForSlot(slot) or "None")
        local cacheKey = actionType == "spell" and ("spell:" .. id) or ("item:" .. id)
        CDM:Msg("Cached:", Hotkeys.cache[cacheKey] or "NO")
    else
        CDM:Msg("Empty slot")
    end
end
