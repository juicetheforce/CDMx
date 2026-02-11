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

-- Manual spell ID overrides for cases where GetBaseSpellID() and
-- C_Spell.GetOverrideSpell() don't resolve the mismatch automatically.
-- Most talent replacements (e.g. Crusader Strike -> Blessed Hammer) are
-- now handled automatically via GetOverrideSpell() in GetHotkeyForSpell().
-- Map: [cooldownManagerID] = actionBarID
Hotkeys.spellIDMap = {
    [49411] = 1217605,   -- Void Metamorphosis (DH)
    [90226] = 198793,    -- Vengeful Retreat (DH)
    [85256] = 383328,    -- Templar's Verdict -> Final Verdict (Paladin talent)
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
    Map an action bar slot number (1-120) to the correct binding command name.
    Slots 1-12 are the main bar, 13-24 are bar 2, etc.
    Each bar range uses a different binding prefix.
]]--
local slotBindingMap = {
    -- Slots 1-12: Main Action Bar
    { start = 1,   stop = 12,  prefix = "ACTIONBUTTON",          offset = 0  },
    -- Slots 13-24: Bottom Left (MultiBar3 in binding names)
    { start = 13,  stop = 24,  prefix = "MULTIACTIONBAR3BUTTON", offset = 12 },
    -- Slots 25-36: Bottom Right (MultiBar4)
    { start = 25,  stop = 36,  prefix = "MULTIACTIONBAR4BUTTON", offset = 24 },
    -- Slots 37-48: Right Bar 2 (MultiBar2)
    { start = 37,  stop = 48,  prefix = "MULTIACTIONBAR2BUTTON", offset = 36 },
    -- Slots 49-60: Right Bar 1 (MultiBar1)
    { start = 49,  stop = 60,  prefix = "MULTIACTIONBAR1BUTTON", offset = 48 },
    -- Slots 61-72: MultiBar5
    { start = 61,  stop = 72,  prefix = "MULTIACTIONBAR5BUTTON", offset = 60 },
    -- Slots 73-84: MultiBar6
    { start = 73,  stop = 84,  prefix = "MULTIACTIONBAR6BUTTON", offset = 72 },
    -- Slots 85-96: MultiBar7
    { start = 85,  stop = 96,  prefix = "MULTIACTIONBAR7BUTTON", offset = 84 },
    -- Slots 97-108: MultiBar8 (if exists in Midnight)
    { start = 97,  stop = 108, prefix = "MULTIACTIONBAR8BUTTON", offset = 96 },
}

--[[
    Get the formatted hotkey text for an action bar slot number.
]]--
function Hotkeys:GetHotkeyForSlot(slot)
    for _, mapping in ipairs(slotBindingMap) do
        if slot >= mapping.start and slot <= mapping.stop then
            local buttonIndex = slot - mapping.offset
            local bindingName = mapping.prefix .. buttonIndex
            local key = GetBindingKey(bindingName)
            if key then
                return CDM.UI:FormatHotkey(key)
            end
            return nil
        end
    end
    return nil
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
    -- Last-match-wins: if a spell is on multiple slots, the higher
    -- slot's keybind takes priority.
    for slot = 1, 120 do
        local spellID, itemID = self:GetSpellFromSlot(slot)
        if spellID or itemID then
            local hotkey = self:GetHotkeyForSlot(slot)
            if hotkey then
                local cacheKey = spellID and ("spell:" .. spellID) or ("item:" .. itemID)
                self.cache[cacheKey] = hotkey
                found = found + 1
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
    Get hotkey for a spell ID. Checks spellIDMap first, then cache,
    then does JIT lookup with alternate IDs.
    
    The spellIDMap is the primary way to handle mismatches between
    Blizzard's Cooldown Manager spell IDs and action bar spell IDs.
    Use /cdtmap or /cdmxdump to diagnose and add new mappings.
]]--
function Hotkeys:GetHotkeyForSpell(spellID)
    if not spellID then return nil end
    
    -- Apply spell ID mapping (CDM ID -> action bar ID)
    local mappedID = self.spellIDMap[spellID]
    if mappedID then
        spellID = mappedID
    end
    
    -- Check cache directly
    local cacheKey = "spell:" .. spellID
    if self.cache[cacheKey] then
        return self.cache[cacheKey]
    end
    
    -- Check if this base spell has been talent-replaced (e.g. Crusader Strike -> Blessed Hammer)
    -- GetOverrideSpell returns the replacement spell if a talent has replaced the base spell
    if C_Spell and C_Spell.GetOverrideSpell then
        local overrideID = C_Spell.GetOverrideSpell(spellID)
        if overrideID and overrideID ~= spellID then
            local overrideKey = "spell:" .. overrideID
            if self.cache[overrideKey] then
                -- Cache result under the base spell too for future lookups
                self.cache[cacheKey] = self.cache[overrideKey]
                return self.cache[cacheKey]
            end
        end
    end
    
    -- Build list of IDs to check: original + alternates + override
    local idsToCheck = { spellID }
    local alt = self.alternateSpellIDs[spellID]
    if alt then table.insert(idsToCheck, alt) end
    if C_Spell and C_Spell.GetOverrideSpell then
        local overrideID = C_Spell.GetOverrideSpell(spellID)
        if overrideID and overrideID ~= spellID then
            table.insert(idsToCheck, overrideID)
        end
    end
    
    -- JIT lookup: scan all slots for matching spell
    for slot = 1, 120 do
        local actionType, id = GetActionInfo(slot)
        if actionType == "spell" and id then
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
    
    -- ElvUI fallback
    if ElvUI then
        local E = unpack(ElvUI)
        if E and E.ActionBars then
            for _, bar in pairs(E.ActionBars.handledBars or {}) do
                if bar.buttons then
                    for _, button in pairs(bar.buttons) do
                        if button.action then
                            local actionType, id = GetActionInfo(button.action)
                            if actionType == "spell" then
                                for _, targetID in ipairs(idsToCheck) do
                                    if id == targetID then
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
    print("--- Action Bar (slot: spell -> hotkey) ---")
    for slot = 1, 120 do
        local actionType, id = GetActionInfo(slot)
        if actionType == "spell" then
            local hotkey = Hotkeys:GetHotkeyForSlot(slot) or "NO KEY"
            print(string.format("  Slot %d: spell:%d (%s) -> [%s]", slot, id, C_Spell.GetSpellName(id) or "?", hotkey))
        elseif actionType == "item" then
            local hotkey = Hotkeys:GetHotkeyForSlot(slot) or "NO KEY"
            print(string.format("  Slot %d: item:%d (%s) -> [%s]", slot, id, C_Item.GetItemNameByID(id) or "?", hotkey))
        end
    end
    print("")
    print("--- Cooldown Manager (frame -> spell -> hotkey) ---")
    local function DumpViewer(viewer, viewerName)
        if not viewer then return end
        for i, child in ipairs({viewer:GetChildren()}) do
            local baseID = child.GetBaseSpellID and child:GetBaseSpellID()
            local rcID = child.rangeCheckSpellID
            local cdID = child.cooldownID
            local spellID = baseID or rcID or cdID
            local method = baseID and "GetBaseSpellID" or (rcID and "rangeCheck" or "cooldownID")
            if spellID then
                local mappedID = Hotkeys.spellIDMap[spellID] or spellID
                local hotkey = Hotkeys:GetHotkeyForSpell(spellID) or "NOT FOUND"
                local mapNote = (mappedID ~= spellID) and string.format(" -> mapped:%d", mappedID) or ""
                print(string.format("  %s[%d]: %s:%d%s (%s) -> [%s]",
                    viewerName, i, method, spellID, mapNote,
                    C_Spell.GetSpellName(spellID) or "?", hotkey))
            end
        end
    end
    DumpViewer(EssentialCooldownViewer, "Essential")
    DumpViewer(UtilityCooldownViewer, "Utility")
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
