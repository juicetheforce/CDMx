--[[
    Cooldown Tracker - TrinketBar.lua
    Custom bar for tracking equipped trinket cooldowns
    
    Shows only on-use trinkets (ignores passive stat trinkets)
    Displays cooldowns, hotkeys, and icons
    Draggable and configurable
    
    Author: Ryan (with Claude assistance)
    Target: WoW 12.0.x (Midnight)
]]--

local ADDON_NAME, CDM = ...

-- Create trinket bar module
CDM.TrinketBar = {}
local TrinketBar = CDM.TrinketBar

-- Trinket slots
local TRINKET_SLOT_1 = 13
local TRINKET_SLOT_2 = 14

-- Masque support
local MSQ = LibStub and LibStub("Masque", true)
local MasqueGroup

--[[
    Initialize Masque support if available
]]--
function TrinketBar:InitializeMasque()
    if MSQ then
        MasqueGroup = MSQ:Group("CDMx", "Trinket Bar")
        if CDM.debug then
            CDM:Print("Masque support enabled for Trinket Bar")
        end
    end
end

--[[
    Create the main trinket bar frame
]]--
function TrinketBar:Create()
    if self.frame then
        return self.frame
    end
    
    -- Create main container frame
    local frame = CreateFrame("Frame", "CDM_TrinketBar", UIParent)
    frame:SetSize(200, 50)  -- Will resize based on icons
    frame:SetFrameStrata("MEDIUM")
    
    -- Load saved position or use default (center of screen)
    local pos = CDM.db.trinketBar.position
    frame:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
    
    -- Make it draggable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    
    frame:SetScript("OnDragStart", function(self)
        if not CDM.db.trinketBar.locked then
            self:StartMoving()
        end
    end)
    
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, _, x, y = self:GetPoint()
        CDM.db.trinketBar.position = {
            point = point,
            x = math.floor(x),
            y = math.floor(y)
        }
        if CDM.debug then
            CDM:Print(string.format("Trinket bar moved to: %s %.0f, %.0f", point, x, y))
        end
    end)
    
    -- Visual background (for visibility when dragging)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetColorTexture(0, 0, 0, 0.5)
    frame.bg:SetAllPoints()
    
    -- Title text (shows when unlocked)
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    frame.title:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    frame.title:SetText("Trinkets (drag to move)")
    frame.title:Hide()
    
    -- Container for trinket icons
    frame.icons = {}
    
    self.frame = frame
    
    if CDM.debug then
        CDM:Print("Trinket bar created")
    end
    
    return frame
end

--[[
    Create a trinket icon button
]]--
function TrinketBar:CreateIcon(index)
    local frame = self.frame
    if not frame then return end
    
    local iconSize = CDM.db.trinketBar.iconSize or 40
    
    -- Create button
    local button = CreateFrame("Button", "CDM_TrinketIcon" .. index, frame)
    button:SetSize(iconSize, iconSize)
    
    -- Icon texture
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    -- Square icons (no cropping) for ElvUI aesthetic
    if CDM.db.trinketBar.squareIcons then
        button.icon:SetTexCoord(0, 1, 0, 1)
    else
        button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)  -- Crop edges like Blizzard does
    end
    
    -- Black border for ElvUI look
    if CDM.db.trinketBar.showBorder then
        -- Create backdrop frame behind the icon
        button.backdrop = button:CreateTexture(nil, "BACKGROUND")
        button.backdrop:SetAllPoints(button)
        button.backdrop:SetColorTexture(0, 0, 0, 1)
        
        -- Inset the icon slightly to show border (2px border)
        button.icon:ClearAllPoints()
        button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    end
    
    -- Border
    button.border = button:CreateTexture(nil, "BORDER")
    button.border:SetAllPoints()
    button.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    button.border:SetBlendMode("ADD")
    button.border:Hide()  -- Hide by default, show on mouseover or cooldown
    
    -- Cooldown frame (the spinning sweep)
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints()
    button.cooldown:SetDrawEdge(false)  -- Don't draw the bright edge
    button.cooldown:SetDrawSwipe(true)   -- Do draw the sweep
    button.cooldown:SetSwipeColor(0, 0, 0, 0.8)
    button.cooldown:SetHideCountdownNumbers(false)  -- Show countdown text
    button.cooldown:SetReverse(false)
    button.cooldown:Hide()  -- Start hidden until a cooldown is active
    
    -- Hotkey text
    button.hotkey = button:CreateFontString(nil, "OVERLAY")
    local hotkeyFontSize = CDM.db.trinketBar.hotkeyFontSize or 12
    local anchor = CDM.db.hotkeyAnchor or "TOPLEFT"
    local offsetX = CDM.db.hotkeyOffsetX or 2
    local offsetY = CDM.db.hotkeyOffsetY or -2
    
    -- Use zero offset for CENTER anchor
    if anchor == "CENTER" then
        offsetX = 0
        offsetY = 0
    end
    
    button.hotkey:SetFont("Fonts\\FRIZQT__.TTF", hotkeyFontSize, "OUTLINE")
    button.hotkey:SetPoint(anchor, button, anchor, offsetX, offsetY)
    button.hotkey:SetTextColor(1, 1, 1, 1)
    button.CDM_HotkeyAnchor = anchor
    
    -- Count text (for charges if trinket has them)
    button.count = button:CreateFontString(nil, "OVERLAY")
    button.count:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.count:SetTextColor(1, 1, 1, 1)
    
    -- Store the equipment slot for tooltip
    button.slot = nil
    
    -- Register with Masque if available
    if MasqueGroup then
        MasqueGroup:AddButton(button, {
            Icon = button.icon,
            Cooldown = button.cooldown,
            Count = button.count,
            HotKey = button.hotkey,
        })
    end
    
    -- Tooltip support - show EQUIPPED item
    button:SetScript("OnEnter", function(self)
        if self.slot then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetInventoryItem("player", self.slot)
            GameTooltip:Show()
        end
    end)
    
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    button:Hide()
    
    return button
end

--[[
    Update trinket bar layout based on configuration
]]--
function TrinketBar:UpdateLayout()
    if not self.frame then return end
    
    local iconSize = CDM.db.trinketBar.iconSize or 40
    local padding = CDM.db.trinketBar.padding or 5
    local horizontal = CDM.db.trinketBar.horizontal
    
    -- Resize all icons first
    for _, icon in ipairs(self.frame.icons) do
        icon:SetSize(iconSize, iconSize)
    end
    
    -- Position icons
    local visibleIcons = {}
    for _, icon in ipairs(self.frame.icons) do
        if icon:IsShown() then
            table.insert(visibleIcons, icon)
        end
    end
    
    local visibleCount = #visibleIcons
    
    for i, icon in ipairs(visibleIcons) do
        icon:ClearAllPoints()
        
        if i == 1 then
            -- First icon - centered in frame
            icon:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
        else
            -- Subsequent icons
            local prevIcon = visibleIcons[i - 1]
            if horizontal then
                icon:SetPoint("LEFT", prevIcon, "RIGHT", padding, 0)
            else
                icon:SetPoint("TOP", prevIcon, "BOTTOM", 0, -padding)
            end
        end
    end
    
    -- Resize frame to fit icons
    if visibleCount > 0 then
        if horizontal then
            self.frame:SetSize(
                (iconSize * visibleCount) + (padding * (visibleCount - 1)),
                iconSize
            )
        else
            self.frame:SetSize(
                iconSize,
                (iconSize * visibleCount) + (padding * (visibleCount - 1))
            )
        end
    else
        self.frame:SetSize(iconSize, iconSize)  -- Default size when empty
    end
end

--[[
    Check if an item is an on-use trinket (has an active ability)
]]--
function TrinketBar:IsOnUseTrinket(itemID)
    if not itemID then return false end
    
    -- Check if item has a usable spell
    local itemSpell = C_Item.GetItemSpell(itemID)
    if itemSpell then
        return true
    end
    
    return false
end

--[[
    Get trinket info from an equipment slot
    Returns: itemID, icon, hotkey, start, duration
]]--
function TrinketBar:GetTrinketInfo(slot)
    local itemID = GetInventoryItemID("player", slot)
    
    if not itemID then
        return nil
    end
    
    -- Check if it's on-use
    if not self:IsOnUseTrinket(itemID) then
        return nil
    end
    
    -- Get icon
    local icon = C_Item.GetItemIconByID(itemID)
    
    -- Get hotkey (check if trinket is on action bars)
    local hotkey = CDM.Hotkeys:GetHotkeyForItem(itemID)
    
    -- Get cooldown info
    local start, duration, enable = C_Container.GetItemCooldown(itemID)
    
    return itemID, icon, hotkey, start, duration
end

--[[
    Update trinket bar visibility based on settings
]]--
function TrinketBar:UpdateVisibility()
    if not self.frame then return end
    
    if not CDM.db.trinketBar.enabled then
        self.frame:Hide()
        return
    end
    
    local visibility = CDM.db.trinketBar.visibility or "always"
    local inCombat = InCombatLockdown()
    
    if visibility == "always" then
        self.frame:Show()
    elseif visibility == "combat" then
        if inCombat then
            self.frame:Show()
        else
            self.frame:Hide()
        end
    elseif visibility == "noCombat" then
        if inCombat then
            self.frame:Hide()
        else
            self.frame:Show()
        end
    end
end

--[[
    Update all trinket icons
]]--
function TrinketBar:Update()
    if not self.frame then
        self:Create()
    end
    
    self:UpdateVisibility()
    
    if not self.frame:IsShown() then
        return
    end
    
    -- Update fonts on existing icons
    local hotkeyFontSize = CDM.db.trinketBar.hotkeyFontSize or 12
    local anchor = CDM.db.hotkeyAnchor or "TOPLEFT"
    local offsetX = CDM.db.hotkeyOffsetX or 2
    local offsetY = CDM.db.hotkeyOffsetY or -2
    
    -- Use zero offset for CENTER anchor
    if anchor == "CENTER" then
        offsetX = 0
        offsetY = 0
    end
    
    for _, icon in pairs(self.frame.icons) do
        if icon and icon.hotkey then
            -- Update font
            icon.hotkey:SetFont("Fonts\\FRIZQT__.TTF", hotkeyFontSize, "OUTLINE")
            
            -- Update anchor if it changed
            if icon.CDM_HotkeyAnchor ~= anchor then
                icon.hotkey:ClearAllPoints()
                icon.hotkey:SetPoint(anchor, icon, anchor, offsetX, offsetY)
                icon.CDM_HotkeyAnchor = anchor
            end
        end
    end
    
    -- Update lock state visuals
    if CDM.db.trinketBar.locked then
        self.frame.bg:SetAlpha(0)
        self.frame.title:Hide()
    else
        self.frame.bg:SetAlpha(0.5)
        self.frame.title:Show()
    end
    
    -- Track which slots have trinkets
    local trinketSlots = {
        {slot = TRINKET_SLOT_1, index = 1},
        {slot = TRINKET_SLOT_2, index = 2},
    }
    
    local visibleIndex = 1
    
    for _, data in ipairs(trinketSlots) do
        local itemID, icon, hotkey, start, duration = self:GetTrinketInfo(data.slot)
        
        -- Create icon if needed
        if not self.frame.icons[data.index] then
            self.frame.icons[data.index] = self:CreateIcon(data.index)
        end
        
        local button = self.frame.icons[data.index]
        
        if itemID then
            -- Show and update icon
            button.itemID = itemID
            button.slot = data.slot  -- Store slot for tooltip
            button.icon:SetTexture(icon)
            
            -- Update hotkey
            if hotkey then
                button.hotkey:SetText(hotkey)
                button.hotkey:Show()
            else
                button.hotkey:Hide()
            end
            
            -- Update cooldown
            if start and duration and duration > 0 then
                button.cooldown:SetCooldown(start, duration)
                button.cooldown:Show()
            else
                button.cooldown:Clear()
                button.cooldown:Hide()  -- Hide when no cooldown to prevent light square
            end
            
            button:Show()
            visibleIndex = visibleIndex + 1
        else
            button:Hide()
        end
    end
    
    -- Update layout (this also resizes the frame)
    self:UpdateLayout()
    
    -- Make sure background matches frame size
    if self.frame.bg then
        self.frame.bg:ClearAllPoints()
        self.frame.bg:SetAllPoints(self.frame)
    end
end

--[[
    Initialize trinket bar
]]--
function TrinketBar:Initialize()
    -- Initialize Masque support
    self:InitializeMasque()
    
    -- Create the frame
    self:Create()
    
    -- Initial update
    self:Update()
    
    -- Register events
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    frame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Entering combat
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Leaving combat
    
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_EQUIPMENT_CHANGED" then
            -- Trinket was equipped/unequipped
            local slot = ...
            if slot == TRINKET_SLOT_1 or slot == TRINKET_SLOT_2 then
                if CDM.debug then
                    CDM:Print("Trinket changed in slot", slot)
                end
                TrinketBar:Update()
            end
        elseif event == "BAG_UPDATE_COOLDOWN" then
            -- Cooldowns updated
            TrinketBar:Update()
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Initial load
            C_Timer.After(2, function()
                TrinketBar:Update()
            end)
        elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            -- Combat state changed - update visibility
            TrinketBar:UpdateVisibility()
        end
    end)
    
    if CDM.debug then
        CDM:Print("Trinket bar initialized")
    end
end

-- Initialize when addon loads
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        TrinketBar:Initialize()
    end
end)
