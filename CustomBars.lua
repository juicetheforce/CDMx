--[[
    CDMx - CustomBars.lua
    Custom cooldown tracking bars.
    
    Users create bars and populate them with spells/items from their
    action bars via the item picker in Config.lua.
    
    Author: Juicetheforce (with Claude assistance)
    Target: WoW 12.0.x (Midnight)
]]--

local ADDON_NAME, CDM = ...

CDM.CustomBars = {}
local CustomBars = CDM.CustomBars

-- Active bar frames keyed by bar name
CustomBars.bars = {}

--============================================================================
-- BAR CREATION
--============================================================================

--[[
    Create a custom bar and its icon buttons from saved settings.
]]--
function CustomBars:CreateBar(barName)
    local settings = CDM.db.customBars[barName]
    if not settings then
        CDM:Msg("Error: Custom bar '" .. barName .. "' not found in settings")
        return
    end
    
    -- Create the movable frame
    local frame = CDM.UI:CreateBarFrame("CustomBar_" .. barName, settings)
    
    -- Create icon buttons for each tracked item
    for i = 1, #settings.items do
        local button = CDM.UI:CreateIconButton(frame, {
            size = settings.iconSize or 40,
            showBorder = settings.showBorder,
            squareIcons = settings.squareIcons,
            hotkeyFontSize = settings.hotkeyFontSize or 12,
            masqueGroup = "Custom: " .. barName,
        })
        table.insert(frame.icons, button)
    end
    
    self.bars[barName] = frame
    return frame
end

--============================================================================
-- UPDATES
--============================================================================

--[[
    Update layout (icon positions and frame size) for a bar.
]]--
function CustomBars:UpdateLayout(barName)
    local frame = self.bars[barName]
    if not frame then return end
    local settings = CDM.db.customBars[barName]
    if not settings then return end
    
    CDM.UI:LayoutBar(frame, settings)
end

--[[
    Update a bar's content: icons, cooldowns, hotkeys, visibility, lock state.
]]--
function CustomBars:UpdateBar(barName)
    local frame = self.bars[barName]
    if not frame then return end
    
    local settings = CDM.db.customBars[barName]
    if not settings then return end
    
    -- Visibility
    CDM.UI:UpdateVisibility(frame, settings.visibility, settings.enabled)
    if not frame:IsShown() then return end
    
    -- Update each icon
    for i, button in ipairs(frame.icons) do
        local itemData = settings.items[i]
        if itemData then
            local texture, spellID, itemID
            
            if itemData.type == "spell" then
                spellID = itemData.id
                texture = C_Spell.GetSpellTexture(spellID)
            elseif itemData.type == "item" then
                itemID = itemData.id
                texture = C_Item.GetItemIconByID(itemID)
            end
            
            if texture then
                button.icon:SetTexture(texture)
                button.tooltipType = itemData.type
                button.tooltipID = itemData.id
                button:Show()
                
                -- Hotkey
                CDM.UI:UpdateHotkey(button, spellID, itemID, settings.hotkeyFontSize)
                
                -- Cooldown
                if spellID then
                    local info = C_Spell.GetSpellCooldown(spellID)
                    if info then
                        CDM.UI:UpdateCooldown(button, info.startTime, info.duration)
                    end
                    
                    -- Charges
                    local chargeInfo = C_Spell.GetSpellCharges(spellID)
                    if chargeInfo and chargeInfo.maxCharges > 1 then
                        button.count:SetText(chargeInfo.currentCharges)
                        button.count:Show()
                    else
                        button.count:Hide()
                    end
                    
                elseif itemID then
                    local start, duration = C_Container.GetItemCooldown(itemID)
                    CDM.UI:UpdateCooldown(button, start, duration)
                    
                    -- Item count
                    local count = C_Item.GetItemCount(itemID)
                    if count > 1 then
                        button.count:SetText(count)
                        button.count:Show()
                    else
                        button.count:Hide()
                    end
                    
                    -- Grey out if player doesn't have the item
                    button:SetAlpha(count > 0 and 1.0 or 0.4)
                end
            else
                button:Hide()
            end
        else
            button:Hide()
        end
    end
end

--[[
    Update visibility for a specific bar.
]]--
function CustomBars:UpdateVisibility(barName)
    local frame = self.bars[barName]
    if not frame then return end
    local settings = CDM.db.customBars[barName]
    CDM.UI:UpdateVisibility(frame, settings.visibility, settings.enabled)
end

--============================================================================
-- INITIALIZATION
--============================================================================

function CustomBars:Initialize()
    if not CDM.db.customBars then
        CDM.db.customBars = {}
    end
    
    -- Create and update all bars
    for barName, _ in pairs(CDM.db.customBars) do
        self:CreateBar(barName)
        self:UpdateLayout(barName)
        self:UpdateBar(barName)
    end
    
    -- Register events for cooldown updates
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            for barName, _ in pairs(CDM.db.customBars) do
                CustomBars:UpdateVisibility(barName)
            end
        else
            for barName, _ in pairs(CDM.db.customBars) do
                CustomBars:UpdateBar(barName)
            end
        end
    end)
    
    if CDM.debug then
        CDM:Print("Custom bars initialized")
    end
end

-- Auto-initialize on login
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    C_Timer.After(2, function()
        CustomBars:Initialize()
    end)
end)
