--[[
    CDMx - CustomBars.lua
    Custom cooldown tracking bars
    
    Allows users to create custom bars and populate them with spells/items
    from their action bars.
    
    Author: Ryan (with Claude assistance)
    Target: WoW 12.0.x (Midnight)
]]--

local ADDON_NAME, CDM = ...

-- Create custom bars module
CDM.CustomBars = {}
local CustomBars = CDM.CustomBars

-- Active bar frames
CustomBars.bars = {}

-- Masque support
local MSQ = LibStub and LibStub("Masque", true)
local MasqueGroups = {}

--[[
    Initialize Masque support for a custom bar
]]--
function CustomBars:InitializeMasque(barName)
    if MSQ then
        MasqueGroups[barName] = MSQ:Group("CDMx", "Custom Bars", barName)
        if CDM.debug then
            CDM:Print("Masque support enabled for custom bar:", barName)
        end
    end
end

--[[
    Create a button for a custom bar
]]--
function CustomBars:CreateButton(parent, barName)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(40, 40)
    
    -- Background
    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    
    -- Icon (ARTWORK layer so backdrop shows behind it)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)  -- Rounded by default
    
    -- Apply border and icon styling
    local barSettings = CDM.db.customBars[barName]
    if barSettings and barSettings.showBorder then
        button.backdrop = button:CreateTexture(nil, "BACKGROUND")
        button.backdrop:SetAllPoints(button)
        button.backdrop:SetColorTexture(0, 0, 0, 1)
        
        button.icon:ClearAllPoints()
        button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    else
        button.icon:SetAllPoints()
    end
    
    -- Square vs rounded icons
    if barSettings and barSettings.squareIcons then
        button.icon:SetTexCoord(0, 1, 0, 1)
    end
    
    -- Cooldown frame
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.icon)
    button.cooldown:SetDrawEdge(false)
    button.cooldown:SetReverse(false)
    button.cooldown:Hide()
    
    -- Hotkey text
    button.hotkey = button:CreateFontString(nil, "OVERLAY")
    local hotkeyFontSize = (barSettings and barSettings.hotkeyFontSize) or 12
    local anchor = CDM.db.hotkeyAnchor or "TOPLEFT"
    local offsetX = CDM.db.hotkeyOffsetX or 2
    local offsetY = CDM.db.hotkeyOffsetY or -2
    
    if anchor == "CENTER" then
        offsetX = 0
        offsetY = 0
    end
    
    button.hotkey:SetFont("Fonts\\FRIZQT__.TTF", hotkeyFontSize, "OUTLINE")
    button.hotkey:SetPoint(anchor, button, anchor, offsetX, offsetY)
    button.hotkey:SetTextColor(1, 1, 1, 1)
    button.CDM_HotkeyAnchor = anchor
    
    -- Count text
    button.count = button:CreateFontString(nil, "OVERLAY")
    button.count:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.count:SetTextColor(1, 1, 1, 1)
    
    -- Store item/spell info
    button.itemType = nil  -- "spell" or "item"
    button.itemID = nil
    
    -- Tooltip support
    button:SetScript("OnEnter", function(self)
        if self.itemType == "spell" and self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.itemID)
            GameTooltip:Show()
        elseif self.itemType == "item" and self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:Show()
        end
    end)
    
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Register with Masque if available
    if MasqueGroups[barName] then
        MasqueGroups[barName]:AddButton(button, {
            Icon = button.icon,
            Cooldown = button.cooldown,
            Count = button.count,
            HotKey = button.hotkey,
        })
    end
    
    return button
end

--[[
    Create a custom bar frame
]]--
function CustomBars:CreateBar(barName)
    if not CDM.db.customBars[barName] then
        CDM:Print("Error: Custom bar", barName, "not found in settings")
        return
    end
    
    local settings = CDM.db.customBars[barName]
    
    -- Initialize Masque for this bar
    self:InitializeMasque(barName)
    
    -- Create main frame
    local frame = CreateFrame("Frame", "CDMx_CustomBar_" .. barName, UIParent)
    frame:SetSize(200, 50)  -- Will be resized based on content
    
    -- Background (only visible when unlocked)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.5)
    frame.bg:SetAlpha(settings.locked and 0 or 0.5)
    
    -- Title (only visible when unlocked)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -5)
    frame.title:SetText(barName)
    if settings.locked then
        frame.title:Hide()
    end
    
    -- Make draggable when unlocked
    frame:SetMovable(true)
    frame:EnableMouse(not settings.locked)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not settings.locked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        settings.position = { point = point, x = x, y = y }
    end)
    
    -- Restore position
    if settings.position then
        frame:ClearAllPoints()
        frame:SetPoint(settings.position.point or "CENTER", 
                      UIParent, 
                      settings.position.point or "CENTER", 
                      settings.position.x or 0, 
                      settings.position.y or 0)
    else
        frame:SetPoint("CENTER", 0, 0)
    end
    
    -- Create icon buttons
    frame.icons = {}
    for i = 1, #settings.items do
        local icon = self:CreateButton(frame, barName)
        table.insert(frame.icons, icon)
    end
    
    -- Store frame
    self.bars[barName] = frame
    
    return frame
end

--[[
    Update a custom bar's layout
]]--
function CustomBars:UpdateLayout(barName)
    local frame = self.bars[barName]
    if not frame then return end
    
    local settings = CDM.db.customBars[barName]
    if not settings then return end
    
    local iconSize = settings.iconSize or 40
    local padding = settings.padding or 5
    local horizontal = settings.horizontal
    
    -- Resize and position icons
    for i, icon in ipairs(frame.icons) do
        icon:SetSize(iconSize, iconSize)
        icon:ClearAllPoints()
        
        if i == 1 then
            icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
        else
            if horizontal then
                icon:SetPoint("LEFT", frame.icons[i-1], "RIGHT", padding, 0)
            else
                icon:SetPoint("TOP", frame.icons[i-1], "BOTTOM", 0, -padding)
            end
        end
    end
    
    -- Resize frame to fit icons
    local numIcons = #frame.icons
    if numIcons > 0 then
        if horizontal then
            frame:SetSize((iconSize * numIcons) + (padding * (numIcons - 1)) + 20, 
                         iconSize + 40)
        else
            frame:SetSize(iconSize + 20, 
                         (iconSize * numIcons) + (padding * (numIcons - 1)) + 40)
        end
    end
end

--[[
    Update a custom bar's content (icons, cooldowns, hotkeys)
]]--
function CustomBars:UpdateBar(barName)
    local frame = self.bars[barName]
    if not frame then return end
    
    local settings = CDM.db.customBars[barName]
    if not settings or not settings.enabled then
        frame:Hide()
        return
    end
    
    -- Update visibility based on settings
    self:UpdateVisibility(barName)
    
    if not frame:IsShown() then
        return
    end
    
    -- Update fonts on existing icons
    local hotkeyFontSize = settings.hotkeyFontSize or 12
    local anchor = CDM.db.hotkeyAnchor or "TOPLEFT"
    local offsetX = CDM.db.hotkeyOffsetX or 2
    local offsetY = CDM.db.hotkeyOffsetY or -2
    
    if anchor == "CENTER" then
        offsetX = 0
        offsetY = 0
    end
    
    for i, icon in ipairs(frame.icons) do
        -- Update font
        icon.hotkey:SetFont("Fonts\\FRIZQT__.TTF", hotkeyFontSize, "OUTLINE")
        
        -- Update anchor if changed
        if icon.CDM_HotkeyAnchor ~= anchor then
            icon.hotkey:ClearAllPoints()
            icon.hotkey:SetPoint(anchor, icon, anchor, offsetX, offsetY)
            icon.CDM_HotkeyAnchor = anchor
        end
        
        -- Update item data
        local itemData = settings.items[i]
        if itemData then
            icon.itemType = itemData.type
            icon.itemID = itemData.id
            
            -- Get icon texture
            local texture
            if itemData.type == "spell" then
                texture = C_Spell.GetSpellTexture(itemData.id)
            elseif itemData.type == "item" then
                texture = C_Item.GetItemIconByID(itemData.id)
            end
            
            if texture then
                icon.icon:SetTexture(texture)
                icon:Show()
                
                -- Get hotkey
                local hotkey
                if itemData.type == "spell" then
                    hotkey = CDM.Hotkeys:GetHotkeyForSpell(itemData.id)
                elseif itemData.type == "item" then
                    hotkey = CDM.Hotkeys:GetHotkeyForItem(itemData.id)
                end
                
                if hotkey then
                    icon.hotkey:SetText(hotkey)
                    icon.hotkey:Show()
                else
                    icon.hotkey:Hide()
                end
                
                -- Update cooldown
                if itemData.type == "spell" then
                    local cooldownInfo = C_Spell.GetSpellCooldown(itemData.id)
                    if cooldownInfo and cooldownInfo.startTime > 0 and cooldownInfo.duration > 1.5 then
                        icon.cooldown:SetCooldown(cooldownInfo.startTime, cooldownInfo.duration)
                        icon.cooldown:Show()
                    else
                        icon.cooldown:Hide()
                    end
                    
                    -- Charges
                    local chargeInfo = C_Spell.GetSpellCharges(itemData.id)
                    if chargeInfo and chargeInfo.maxCharges > 1 then
                        icon.count:SetText(chargeInfo.currentCharges)
                        icon.count:Show()
                    else
                        icon.count:Hide()
                    end
                elseif itemData.type == "item" then
                    local start, duration = C_Container.GetItemCooldown(itemData.id)
                    if start > 0 and duration > 1.5 then
                        icon.cooldown:SetCooldown(start, duration)
                        icon.cooldown:Show()
                    else
                        icon.cooldown:Hide()
                    end
                    
                    -- Item count
                    local count = C_Item.GetItemCount(itemData.id)
                    if count > 1 then
                        icon.count:SetText(count)
                        icon.count:Show()
                    else
                        icon.count:Hide()
                    end
                    
                    -- Grey out if don't have it
                    if count > 0 then
                        icon:SetAlpha(1.0)
                    else
                        icon:SetAlpha(0.4)
                    end
                end
            else
                icon:Hide()
            end
        else
            icon:Hide()
        end
    end
    
    -- Update lock state visuals
    if settings.locked then
        frame.bg:SetAlpha(0)
        frame.title:Hide()
        frame:EnableMouse(false)
    else
        frame.bg:SetAlpha(0.5)
        frame.title:Show()
        frame:EnableMouse(true)
    end
end

--[[
    Update visibility for a custom bar
]]--
function CustomBars:UpdateVisibility(barName)
    local frame = self.bars[barName]
    if not frame then return end
    
    local settings = CDM.db.customBars[barName]
    if not settings or not settings.enabled then
        frame:Hide()
        return
    end
    
    local visibility = settings.visibility or "always"
    local inCombat = InCombatLockdown()
    
    if visibility == "always" then
        frame:Show()
    elseif visibility == "combat" then
        if inCombat then
            frame:Show()
        else
            frame:Hide()
        end
    elseif visibility == "noCombat" then
        if inCombat then
            frame:Hide()
        else
            frame:Show()
        end
    end
end

--[[
    Update lock state for a custom bar
]]--
function CustomBars:UpdateLockState(barName)
    local frame = self.bars[barName]
    if not frame then return end
    
    local settings = CDM.db.customBars[barName]
    if not settings then return end
    
    if settings.locked then
        frame.bg:SetAlpha(0)
        frame.title:Hide()
        frame:EnableMouse(false)
    else
        frame.bg:SetAlpha(0.5)
        frame.title:Show()
        frame:EnableMouse(true)
    end
end

--[[
    Initialize all custom bars
]]--
function CustomBars:Initialize()
    if not CDM.db.customBars then
        CDM.db.customBars = {}
    end
    
    -- Create bars
    for barName, _ in pairs(CDM.db.customBars) do
        self:CreateBar(barName)
        self:UpdateLayout(barName)
        self:UpdateBar(barName)
    end
    
    -- Register events
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    frame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    
    frame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            -- Update visibility for all bars
            for barName, _ in pairs(CDM.db.customBars) do
                CustomBars:UpdateVisibility(barName)
            end
        else
            -- Update all bars
            for barName, _ in pairs(CDM.db.customBars) do
                CustomBars:UpdateBar(barName)
            end
        end
    end)
    
    if CDM.debug then
        CDM:Print("Custom bars initialized")
    end
end

-- Initialize when addon loads
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(2, function()
            CustomBars:Initialize()
        end)
    end
end)
