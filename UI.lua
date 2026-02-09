--[[
    CDMx - UI.lua
    Shared UI utilities for icon buttons, styling, hotkey display, 
    movable frames, and visibility management.
    
    This module eliminates duplication between TrinketBar, CustomBars,
    and BlizzardHooks by providing a single source of truth for all
    visual element creation and updates.
    
    Author: Juicetheforce (with Claude assistance)
    Target: WoW 12.0.x (Midnight)
]]--

local ADDON_NAME, CDM = ...

CDM.UI = {}
local UI = CDM.UI

-- Masque support (shared across all bar types)
local MSQ = nil
UI.masqueGroups = {}

function UI:InitMasque()
    MSQ = LibStub and LibStub("Masque", true)
    if MSQ and CDM.debug then
        CDM:Print("Masque library found")
    end
end

function UI:GetMasqueGroup(groupName)
    if not MSQ then return nil end
    if not self.masqueGroups[groupName] then
        self.masqueGroups[groupName] = MSQ:Group("CDMx", groupName)
    end
    return self.masqueGroups[groupName]
end

--============================================================================
-- HOTKEY FORMATTING
--============================================================================

--[[
    Format a raw keybinding string for compact display on icons.
    e.g. "SHIFT-1" -> "S1", "CTRL-BUTTON4" -> "CM4"
]]--
function UI:FormatHotkey(key)
    if not key then return nil end
    key = key:gsub("SHIFT%-", "S")
    key = key:gsub("CTRL%-", "C")
    key = key:gsub("ALT%-", "A")
    key = key:gsub("BUTTON", "M")
    key = key:gsub("MOUSEWHEELUP", "MwU")
    key = key:gsub("MOUSEWHEELDOWN", "MwD")
    return key
end

--============================================================================
-- ICON BUTTON CREATION
--============================================================================

--[[
    Create a standard icon button used across all bar types.
    
    @param parent       Frame - Parent frame for the button
    @param options      Table with:
        size            number  - Icon size in pixels (default 40)
        showBorder      boolean - Show 2px black border (default true)
        squareIcons     boolean - Square texcoord vs rounded crop (default true)
        hotkeyFontSize  number  - Hotkey font size (default 12)
        hotkeyAnchor    string  - Anchor point for hotkey text (default from db)
        masqueGroup     string  - Masque group name (optional)
        frameName       string  - Global frame name (optional)
    
    @return button      Frame with .icon, .cooldown, .hotkey, .count, .bg
]]--
function UI:CreateIconButton(parent, options)
    options = options or {}
    local size = options.size or 40
    local showBorder = options.showBorder ~= false  -- default true
    local squareIcons = options.squareIcons ~= false  -- default true
    local hotkeyFontSize = options.hotkeyFontSize or 12
    local anchor = options.hotkeyAnchor or CDM.db.hotkeyAnchor or "TOPLEFT"
    
    local button = CreateFrame("Button", options.frameName, parent)
    button:SetSize(size, size)
    
    -- Background (dark fill behind icon)
    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    
    -- Border backdrop (black border behind icon)
    if showBorder then
        button.backdrop = button:CreateTexture(nil, "BACKGROUND")
        button.backdrop:SetAllPoints(button)
        button.backdrop:SetColorTexture(0, 0, 0, 1)
    end
    
    -- Icon texture
    button.icon = button:CreateTexture(nil, "ARTWORK")
    if showBorder then
        button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    else
        button.icon:SetAllPoints()
    end
    button.icon:SetTexCoord(squareIcons and 0 or 0.07, squareIcons and 1 or 0.93,
                            squareIcons and 0 or 0.07, squareIcons and 1 or 0.93)
    
    -- Cooldown sweep overlay
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.icon)
    button.cooldown:SetDrawEdge(false)
    button.cooldown:SetDrawSwipe(true)
    button.cooldown:SetSwipeColor(0, 0, 0, 0.8)
    button.cooldown:SetHideCountdownNumbers(false)
    button.cooldown:SetReverse(false)
    button.cooldown:Hide()
    
    -- Hotkey text
    button.hotkey = button:CreateFontString(nil, "OVERLAY")
    self:ApplyHotkeyStyle(button, hotkeyFontSize, anchor)
    
    -- Count/charges text (small, bottom-right corner)
    button.count = button:CreateFontString(nil, "OVERLAY")
    button.count:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button.count:SetTextColor(1, 1, 1, 1)
    
    -- Store creation options for later style updates
    button._cdmOptions = {
        showBorder = showBorder,
        squareIcons = squareIcons,
    }
    
    -- Register with Masque if requested
    if options.masqueGroup then
        local group = self:GetMasqueGroup(options.masqueGroup)
        if group then
            group:AddButton(button, {
                Icon = button.icon,
                Cooldown = button.cooldown,
                Count = button.count,
                HotKey = button.hotkey,
            })
        end
    end
    
    -- Tooltip support (set button.tooltipType and button.tooltipID to activate)
    button:SetScript("OnEnter", function(self)
        if self.tooltipType == "spell" and self.tooltipID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.tooltipID)
            GameTooltip:Show()
        elseif self.tooltipType == "item" and self.tooltipID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.tooltipID)
            GameTooltip:Show()
        elseif self.tooltipType == "inventory" and self.tooltipSlot then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetInventoryItem("player", self.tooltipSlot)
            GameTooltip:Show()
        end
    end)
    
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    return button
end

--============================================================================
-- STYLING UPDATES (live, no /reload needed)
--============================================================================

--[[
    Apply hotkey font style to a button's hotkey text.
    Call this when font size or anchor changes.
]]--
function UI:ApplyHotkeyStyle(button, fontSize, anchor)
    if not button or not button.hotkey then return end
    
    fontSize = fontSize or 12
    anchor = anchor or CDM.db.hotkeyAnchor or "TOPLEFT"
    local fontPath = CDM.db.hotkeyFont or "Fonts\\FRIZQT__.TTF"
    local outline = CDM.db.hotkeyOutline or "OUTLINE"
    local offsetX = CDM.db.hotkeyOffsetX or 2
    local offsetY = CDM.db.hotkeyOffsetY or -2
    
    if anchor == "CENTER" then
        offsetX = 0
        offsetY = 0
    end
    
    button.hotkey:SetFont(fontPath, fontSize, outline)
    button.hotkey:ClearAllPoints()
    button.hotkey:SetPoint(anchor, button, anchor, offsetX, offsetY)
    button.hotkey:SetTextColor(1, 1, 1, 1)
    button._cdmHotkeyAnchor = anchor
    button._cdmHotkeyFontSize = fontSize
end

--[[
    Update the hotkey text on a button using the hotkey detection system.
    
    @param button   Frame - Button with .hotkey FontString
    @param spellID  number or nil
    @param itemID   number or nil
    @param fontSize number - Override font size (optional)
    @param anchor   string - Override anchor (optional)
]]--
function UI:UpdateHotkey(button, spellID, itemID, fontSize, anchor)
    if not button or not button.hotkey then return end
    if not CDM.db.showHotkeys then
        button.hotkey:Hide()
        return
    end
    
    -- Update style if params changed
    fontSize = fontSize or button._cdmHotkeyFontSize
    anchor = anchor or CDM.db.hotkeyAnchor or "TOPLEFT"
    if button._cdmHotkeyAnchor ~= anchor or button._cdmHotkeyFontSize ~= fontSize then
        self:ApplyHotkeyStyle(button, fontSize, anchor)
    end
    
    -- Look up the hotkey
    local hotkey = nil
    if spellID and CDM.Hotkeys then
        hotkey = CDM.Hotkeys:GetHotkeyForSpell(spellID)
    elseif itemID and CDM.Hotkeys then
        hotkey = CDM.Hotkeys:GetHotkeyForItem(itemID)
    end
    
    if hotkey then
        button.hotkey:SetText(hotkey)
        button.hotkey:Show()
    else
        button.hotkey:Hide()
    end
end

--[[
    Update cooldown sweep on a button.
    
    @param button   Frame - Button with .cooldown Cooldown frame
    @param start    number - GetTime() when cooldown started
    @param duration number - Duration in seconds
    @param minDuration number - Minimum duration to show sweep (default 1.5, filters GCD)
]]--
function UI:UpdateCooldown(button, start, duration, minDuration)
    if not button or not button.cooldown then return end
    minDuration = minDuration or 1.5
    
    if start and start > 0 and duration and duration > minDuration then
        button.cooldown:SetCooldown(start, duration)
        button.cooldown:Show()
    else
        button.cooldown:Clear()
        button.cooldown:Hide()
    end
end

--[[
    Update icon styling (border, square) on an existing button.
    For use when global style settings change.
]]--
function UI:UpdateButtonStyle(button, showBorder, squareIcons)
    if not button or not button.icon then return end
    
    -- Update texcoord
    button.icon:SetTexCoord(
        squareIcons and 0 or 0.07, squareIcons and 1 or 0.93,
        squareIcons and 0 or 0.07, squareIcons and 1 or 0.93
    )
    
    -- Update border
    if showBorder then
        if not button.backdrop then
            button.backdrop = button:CreateTexture(nil, "BACKGROUND")
            button.backdrop:SetAllPoints(button)
            button.backdrop:SetColorTexture(0, 0, 0, 1)
        end
        button.backdrop:Show()
        button.icon:ClearAllPoints()
        button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    else
        if button.backdrop then
            button.backdrop:Hide()
        end
        button.icon:ClearAllPoints()
        button.icon:SetAllPoints(button)
    end
    
    button._cdmOptions = button._cdmOptions or {}
    button._cdmOptions.showBorder = showBorder
    button._cdmOptions.squareIcons = squareIcons
end

--============================================================================
-- MOVABLE BAR FRAME
--============================================================================

--[[
    Create a movable bar frame with background, title, drag support,
    and position saving.
    
    @param name     string - Unique frame name (prefixed with CDMx_)
    @param settings table  - Must contain: position {point, x, y}
    @return frame   Frame  - Positioned container for icon buttons
]]--
function UI:CreateBarFrame(name, settings)
    local frameName = "CDMx_" .. name:gsub("%W", "")
    local frame = CreateFrame("Frame", frameName, UIParent)
    frame:SetSize(200, 50)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    
    -- Movable (used by EditMode movers, not direct dragging)
    frame:SetMovable(true)
    
    -- Restore saved position
    local pos = settings.position or { point = "CENTER", x = 0, y = 0 }
    frame:ClearAllPoints()
    frame:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER",
                   pos.x or 0, pos.y or 0)
    
    -- Store settings reference for EditMode and other systems
    frame._cdmSettings = settings
    
    -- Container for icon buttons
    frame.icons = {}
    
    return frame
end

--============================================================================
-- VISIBILITY MANAGEMENT
--============================================================================

--[[
    Update frame visibility based on combat state settings.
    
    @param frame      Frame
    @param visibility string - "always", "combat", or "noCombat"
    @param enabled    boolean - Master enable toggle
]]--
function UI:UpdateVisibility(frame, visibility, enabled)
    if not frame then return end
    
    if enabled == false then
        frame:Hide()
        return
    end
    
    visibility = visibility or "always"
    local inCombat = InCombatLockdown()
    
    if visibility == "always" then
        frame:Show()
    elseif visibility == "combat" then
        if inCombat then frame:Show() else frame:Hide() end
    elseif visibility == "noCombat" then
        if inCombat then frame:Hide() else frame:Show() end
    end
end

--============================================================================
-- BAR LAYOUT
--============================================================================

--[[
    Lay out icon buttons within a bar frame.
    Handles both horizontal and vertical orientation, and resizes the
    parent frame to fit.
    
    @param frame      Frame - Bar frame with .icons table
    @param settings   table - iconSize, padding, horizontal
    @param offsetY    number - Y offset for first icon from top (default -30)
]]--
function UI:LayoutBar(frame, settings, offsetY)
    if not frame or not frame.icons then return end
    
    local iconSize = settings.iconSize or 40
    local padding = settings.padding or 5
    local horizontal = settings.horizontal
    offsetY = offsetY or -30
    
    -- Collect visible icons
    local visibleIcons = {}
    for _, icon in ipairs(frame.icons) do
        icon:SetSize(iconSize, iconSize)
        if icon:IsShown() then
            table.insert(visibleIcons, icon)
        end
    end
    
    local count = #visibleIcons
    if count == 0 then
        frame:SetSize(iconSize, iconSize)
        return
    end
    
    -- Position icons
    for i, icon in ipairs(visibleIcons) do
        icon:ClearAllPoints()
        if i == 1 then
            icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, offsetY)
        else
            if horizontal then
                icon:SetPoint("LEFT", visibleIcons[i - 1], "RIGHT", padding, 0)
            else
                icon:SetPoint("TOP", visibleIcons[i - 1], "BOTTOM", 0, -padding)
            end
        end
    end
    
    -- Resize frame to fit
    local margin = 20  -- 10px each side
    local titleSpace = math.abs(offsetY)
    if horizontal then
        frame:SetSize(
            (iconSize * count) + (padding * (count - 1)) + margin,
            iconSize + titleSpace
        )
    else
        frame:SetSize(
            iconSize + margin,
            (iconSize * count) + (padding * (count - 1)) + titleSpace
        )
    end
end

--[[
    Simplified layout for bars where all icons are always visible
    (like trinket bar). Positions icons centered in the frame.
    
    @param frame    Frame - Bar frame with .icons table
    @param settings table - iconSize, padding, horizontal
]]--
function UI:LayoutBarCentered(frame, settings)
    if not frame or not frame.icons then return end
    
    local iconSize = settings.iconSize or 40
    local padding = settings.padding or 5
    local horizontal = settings.horizontal
    
    local visibleIcons = {}
    for _, icon in ipairs(frame.icons) do
        icon:SetSize(iconSize, iconSize)
        if icon:IsShown() then
            table.insert(visibleIcons, icon)
        end
    end
    
    local count = #visibleIcons
    if count == 0 then
        frame:SetSize(iconSize, iconSize)
        return
    end
    
    for i, icon in ipairs(visibleIcons) do
        icon:ClearAllPoints()
        if i == 1 then
            if horizontal then
                icon:SetPoint("LEFT", frame, "LEFT", 0, 0)
            else
                icon:SetPoint("TOP", frame, "TOP", 0, 0)
            end
        else
            if horizontal then
                icon:SetPoint("LEFT", visibleIcons[i - 1], "RIGHT", padding, 0)
            else
                icon:SetPoint("TOP", visibleIcons[i - 1], "BOTTOM", 0, -padding)
            end
        end
    end
    
    -- Resize
    if horizontal then
        frame:SetSize(
            (iconSize * count) + (padding * (count - 1)),
            iconSize
        )
    else
        frame:SetSize(
            iconSize,
            (iconSize * count) + (padding * (count - 1))
        )
    end
end
