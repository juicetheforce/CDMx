--[[
    CDMx - TrinketBar.lua
    Dedicated bar for tracking equipped on-use trinket cooldowns.
    
    Shows only on-use trinkets (ignores passive stat trinkets).
    Displays cooldowns, hotkeys, and icons.
    
    Author: Juicetheforce (with Claude assistance)
    Target: WoW 12.0.x (Midnight)
]]--

local ADDON_NAME, CDM = ...

CDM.TrinketBar = {}
local TrinketBar = CDM.TrinketBar

local TRINKET_SLOT_1 = 13
local TRINKET_SLOT_2 = 14

--============================================================================
-- CREATION
--============================================================================

function TrinketBar:Create()
    if self.frame then return self.frame end
    
    local settings = CDM.db.trinketBar
    
    -- Use shared UI to create a movable bar frame
    self.frame = CDM.UI:CreateBarFrame("TrinketBar", settings)
    
    return self.frame
end

--[[
    Create a trinket icon button for a given index (1 or 2).
]]--
function TrinketBar:CreateIcon(index)
    if not self.frame then return end
    
    local settings = CDM.db.trinketBar
    
    local button = CDM.UI:CreateIconButton(self.frame, {
        size = settings.iconSize or 40,
        showBorder = settings.showBorder,
        squareIcons = settings.squareIcons,
        hotkeyFontSize = settings.hotkeyFontSize or 12,
        masqueGroup = "Trinket Bar",
        frameName = "CDMx_TrinketIcon" .. index,
    })
    
    -- Trinkets use inventory tooltip (shows equipped item, not item ID)
    button.tooltipType = "inventory"
    button.tooltipSlot = nil  -- Set during Update()
    
    button:Hide()
    return button
end

--============================================================================
-- TRINKET DETECTION
--============================================================================

--[[
    Check if an item is an on-use trinket (has a usable spell).
]]--
function TrinketBar:IsOnUseTrinket(itemID)
    if not itemID then return false end
    return C_Item.GetItemSpell(itemID) ~= nil
end

--[[
    Get trinket info from an equipment slot.
    Returns: itemID, icon, hotkey, start, duration (or nil if not on-use)
]]--
function TrinketBar:GetTrinketInfo(slot)
    local itemID = GetInventoryItemID("player", slot)
    if not itemID then return nil end
    if not self:IsOnUseTrinket(itemID) then return nil end
    
    local icon = C_Item.GetItemIconByID(itemID)
    local hotkey = CDM.Hotkeys and CDM.Hotkeys:GetHotkeyForItem(itemID) or nil
    local start, duration = C_Container.GetItemCooldown(itemID)
    
    return itemID, icon, hotkey, start, duration
end

--============================================================================
-- UPDATE
--============================================================================

function TrinketBar:Update()
    if not self.frame then
        self:Create()
    end
    
    local settings = CDM.db.trinketBar
    
    -- Visibility
    CDM.UI:UpdateVisibility(self.frame, settings.visibility, settings.enabled)
    if not self.frame:IsShown() then return end
    
    -- Update each trinket slot
    local trinketSlots = {
        { slot = TRINKET_SLOT_1, index = 1 },
        { slot = TRINKET_SLOT_2, index = 2 },
    }
    
    for _, data in ipairs(trinketSlots) do
        -- Create icon if needed
        if not self.frame.icons[data.index] then
            self.frame.icons[data.index] = self:CreateIcon(data.index)
        end
        
        local button = self.frame.icons[data.index]
        local itemID, icon, hotkey, start, duration = self:GetTrinketInfo(data.slot)
        
        if itemID then
            button.tooltipSlot = data.slot
            button.icon:SetTexture(icon)
            
            -- Hotkey
            CDM.UI:UpdateHotkey(button, nil, itemID, settings.hotkeyFontSize)
            
            -- Cooldown
            CDM.UI:UpdateCooldown(button, start, duration)
            
            button:Show()
        else
            button:Hide()
        end
    end
    
    -- Layout (centered, no title offset)
    CDM.UI:LayoutBarCentered(self.frame, settings)
end

function TrinketBar:UpdateVisibility()
    if not self.frame then return end
    local settings = CDM.db.trinketBar
    CDM.UI:UpdateVisibility(self.frame, settings.visibility, settings.enabled)
end

--============================================================================
-- INITIALIZATION
--============================================================================

function TrinketBar:Initialize()
    self:Create()
    self:Update()
    
    -- Register events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_EQUIPMENT_CHANGED" then
            local slot = ...
            if slot == TRINKET_SLOT_1 or slot == TRINKET_SLOT_2 then
                TrinketBar:Update()
            end
        elseif event == "BAG_UPDATE_COOLDOWN" then
            TrinketBar:Update()
        elseif event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(2, function() TrinketBar:Update() end)
        elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            TrinketBar:UpdateVisibility()
        end
    end)
    
    if CDM.debug then
        CDM:Print("Trinket bar initialized")
    end
end

-- Auto-initialize on login
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    TrinketBar:Initialize()
end)
