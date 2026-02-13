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
-- SLOT → BINDING MAP (built dynamically from actual button frames)
--============================================================================

--[[
    Known Blizzard action button frame sets and their binding prefixes.
    We scan these frames at runtime to discover which action slot each
    button owns, then map slot → binding name. This works regardless of
    whether the player uses default bars, ElvUI, or other bar addons,
    because the slot↔binding relationship is defined by the frames.
    
    Previous approach used a hardcoded slot→binding table, but the mapping
    differs between ElvUI and default Blizzard bars (e.g. slots 61-72 are
    MULTIACTIONBAR1BUTTON on default bars but MULTIACTIONBAR5BUTTON in
    some ElvUI configs). Dynamic discovery eliminates this problem.
]]--
local blizzardButtonSets = {
    { frame = "ActionButton",              binding = "ACTIONBUTTON" },
    { frame = "MultiBarBottomLeftButton",  binding = "MULTIACTIONBAR1BUTTON" },
    { frame = "MultiBarBottomRightButton", binding = "MULTIACTIONBAR2BUTTON" },
    { frame = "MultiBarRightButton",       binding = "MULTIACTIONBAR3BUTTON" },
    { frame = "MultiBarLeftButton",        binding = "MULTIACTIONBAR4BUTTON" },
    { frame = "MultiBar5Button",           binding = "MULTIACTIONBAR5BUTTON" },
    { frame = "MultiBar6Button",           binding = "MULTIACTIONBAR6BUTTON" },
    { frame = "MultiBar7Button",           binding = "MULTIACTIONBAR7BUTTON" },
    { frame = "MultiBar8Button",           binding = "MULTIACTIONBAR8BUTTON" },
}

-- Runtime cache: slot number → binding command name (e.g. 61 → "MULTIACTIONBAR1BUTTON1")
Hotkeys.slotToBinding = {}

--[[
    Scan all known action button frames and build the slot → binding map.
    Called during ScanActionBars to keep the map current.
]]--
function Hotkeys:BuildSlotBindingMap()
    wipe(self.slotToBinding)
    
    for _, set in ipairs(blizzardButtonSets) do
        for i = 1, 12 do
            local frame = _G[set.frame .. i]
            if frame then
                local slot = nil
                
                -- ActionButton slots depend on current bar page, but
                -- ACTIONBUTTON1 always triggers button 1 on the main bar
                -- regardless of paging. Map button index directly.
                if set.frame == "ActionButton" then
                    slot = i
                else
                    -- Multi-action bars: get the fixed slot from the frame
                    if frame.GetAttribute then
                        local ok, action = pcall(frame.GetAttribute, frame, "action")
                        if ok and action and type(action) == "number" and action > 0 then
                            slot = action
                        end
                    end
                    -- Fallback: try the .action property
                    if not slot and frame.action and type(frame.action) == "number" then
                        slot = frame.action
                    end
                end
                
                if slot then
                    self.slotToBinding[slot] = set.binding .. i
                end
            end
        end
    end
    
    if CDM.debug then
        local count = 0
        for _ in pairs(self.slotToBinding) do count = count + 1 end
        CDM:Print(string.format("Built slot->binding map: %d slots mapped", count))
    end
end

--[[
    Get the formatted hotkey text for an action bar slot number.
    Uses the dynamically built slot→binding map.
]]--
function Hotkeys:GetHotkeyForSlot(slot)
    local bindingName = self.slotToBinding[slot]
    if bindingName then
        local key = GetBindingKey(bindingName)
        if key then
            return CDM.UI:FormatHotkey(key)
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
    
    -- Build the slot→binding map from actual button frames
    -- This must happen before scanning so GetHotkeyForSlot works
    self:BuildSlotBindingMap()
    
    local found = 0
    
    -- Scan action bar slots. Range covers:
    -- 1-12: Main bar, 13-72: Bar pages 2-6
    -- 73-120: MultiBar BottomLeft/Right, Right1/Right2
    -- 145-192: MultiBar 5-8 (Dragonflight+)
    -- Last-match-wins: if a spell is on multiple slots, the higher
    -- slot's keybind takes priority.
    for slot = 1, 180 do
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
    for slot = 1, 180 do
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
    for slot = 1, 180 do
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
    for slot = 1, 180 do
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
