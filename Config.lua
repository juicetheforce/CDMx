--[[
    CDMx - Config.lua
    Configuration UI with custom-drawn widgets and collapsible sections.
    Dark/gold aesthetic matching modern WoW addon style (CMC, ElvUI).
    
    All sections collapsed by default. No Blizzard UI templates.
    Integrates with Blizzard's Settings panel.
    
    Author: Juicetheforce (with Claude assistance)
    Target: WoW 12.0.x (Midnight)
]]--

local ADDON_NAME, CDM = ...

CDM.Config = {}
local Config = CDM.Config

--============================================================================
-- COLOR PALETTE
--============================================================================

local C = {
    bg          = { 0.10, 0.10, 0.10, 0.95 },
    headerBg    = { 0.15, 0.15, 0.15, 1.0 },
    headerHover = { 0.20, 0.20, 0.20, 1.0 },
    border      = { 0.30, 0.30, 0.30, 1.0 },
    accent      = { 0.80, 0.70, 0.10, 1.0 },
    accentDim   = { 0.50, 0.44, 0.06, 1.0 },
    green       = { 0.20, 0.80, 0.20, 1.0 },
    text        = { 0.90, 0.90, 0.90, 1.0 },
    textDim     = { 0.55, 0.55, 0.55, 1.0 },
    textLabel   = { 0.90, 0.75, 0.10, 1.0 },
    red         = { 0.80, 0.20, 0.20, 1.0 },
    sliderTrack = { 0.08, 0.08, 0.08, 1.0 },
    sliderFill  = { 0.70, 0.60, 0.05, 0.9 },
    inputBg     = { 0.12, 0.12, 0.12, 1.0 },
    buttonBg    = { 0.18, 0.18, 0.18, 1.0 },
    buttonHover = { 0.25, 0.25, 0.25, 1.0 },
}

local CONTENT_WIDTH = 540
local INDENT = 20
local ROW_HEIGHT = 28
local SECTION_GAP = 8

--============================================================================
-- WIDGET FACTORY
--============================================================================

local function CreateSectionHeader(parent, text, yOffset)
    local header = CreateFrame("Button", nil, parent)
    header:SetPoint("TOPLEFT", INDENT, yOffset)
    header:SetSize(CONTENT_WIDTH - (INDENT * 2), 30)
    
    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()
    header.bg:SetColorTexture(unpack(C.headerBg))
    
    header.borderBottom = header:CreateTexture(nil, "ARTWORK")
    header.borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    header.borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    header.borderBottom:SetHeight(1)
    header.borderBottom:SetColorTexture(unpack(C.border))
    
    header.indicator = header:CreateFontString(nil, "OVERLAY")
    header.indicator:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    header.indicator:SetPoint("RIGHT", header, "RIGHT", -10, 0)
    header.indicator:SetTextColor(unpack(C.accent))
    header.indicator:SetText("+")
    
    header.label = header:CreateFontString(nil, "OVERLAY")
    header.label:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    header.label:SetPoint("LEFT", header, "LEFT", 12, 0)
    header.label:SetTextColor(unpack(C.text))
    header.label:SetText(text)
    
    local content = CreateFrame("Frame", nil, parent)
    content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    content:SetWidth(CONTENT_WIDTH - (INDENT * 2))
    content:Hide()
    
    header.expanded = false
    header.content = content
    
    header:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(unpack(C.headerHover))
    end)
    header:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(unpack(C.headerBg))
    end)
    
    header:SetScript("OnClick", function(self)
        self.expanded = not self.expanded
        if self.expanded then
            self.content:Show()
            self.indicator:SetText("-")
        else
            self.content:Hide()
            self.indicator:SetText("+")
        end
        if Config.RecalcLayout then Config:RecalcLayout() end
    end)
    
    return header, content
end

local function CreateCheckbox(parent, label, checked, onChange, yOffset)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 0, yOffset)
    row:SetSize(CONTENT_WIDTH - (INDENT * 2), ROW_HEIGHT)
    
    local cb = CreateFrame("Button", nil, row)
    cb:SetPoint("LEFT", 10, 0)
    cb:SetSize(18, 18)
    
    cb.bg = cb:CreateTexture(nil, "BACKGROUND")
    cb.bg:SetAllPoints()
    cb.bg:SetColorTexture(unpack(C.inputBg))
    
    cb.borderTex = cb:CreateTexture(nil, "BORDER")
    cb.borderTex:SetPoint("TOPLEFT", -1, 1)
    cb.borderTex:SetPoint("BOTTOMRIGHT", 1, -1)
    cb.borderTex:SetColorTexture(unpack(C.border))
    
    cb.check = cb:CreateTexture(nil, "ARTWORK")
    cb.check:SetPoint("TOPLEFT", 2, -2)
    cb.check:SetPoint("BOTTOMRIGHT", -2, 2)
    cb.check:SetColorTexture(unpack(C.accent))
    
    cb.checked = checked
    if checked then cb.check:Show() else cb.check:Hide() end
    
    cb:SetScript("OnClick", function(self)
        self.checked = not self.checked
        if self.checked then self.check:Show() else self.check:Hide() end
        if onChange then onChange(self.checked) end
    end)
    
    local text = row:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    text:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    text:SetTextColor(unpack(C.text))
    text:SetText(label)
    
    return cb, yOffset - ROW_HEIGHT
end

local function CreateSlider(parent, label, min, max, value, step, onChange, yOffset)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 0, yOffset)
    row:SetSize(CONTENT_WIDTH - (INDENT * 2), ROW_HEIGHT + 4)
    
    local labelText = row:CreateFontString(nil, "OVERLAY")
    labelText:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    labelText:SetPoint("LEFT", 10, 0)
    labelText:SetTextColor(unpack(C.textLabel))
    labelText:SetText(label)
    
    local valueText = row:CreateFontString(nil, "OVERLAY")
    valueText:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    valueText:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    valueText:SetTextColor(unpack(C.accent))
    valueText:SetText(tostring(math.floor(value)))
    
    local rightBtn = CreateFrame("Button", nil, row)
    rightBtn:SetPoint("RIGHT", valueText, "LEFT", -8, 0)
    rightBtn:SetSize(16, 16)
    local rightText = rightBtn:CreateFontString(nil, "OVERLAY")
    rightText:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    rightText:SetAllPoints()
    rightText:SetTextColor(unpack(C.textDim))
    rightText:SetText(">")
    rightBtn:SetScript("OnEnter", function() rightText:SetTextColor(unpack(C.accent)) end)
    rightBtn:SetScript("OnLeave", function() rightText:SetTextColor(unpack(C.textDim)) end)
    
    local trackWidth = 180
    local track = CreateFrame("Frame", nil, row)
    track:SetPoint("RIGHT", rightBtn, "LEFT", -6, 0)
    track:SetSize(trackWidth, 10)
    
    track.bg = track:CreateTexture(nil, "BACKGROUND")
    track.bg:SetAllPoints()
    track.bg:SetColorTexture(unpack(C.sliderTrack))
    
    track.borderTex = track:CreateTexture(nil, "BORDER")
    track.borderTex:SetPoint("TOPLEFT", -1, 1)
    track.borderTex:SetPoint("BOTTOMRIGHT", 1, -1)
    track.borderTex:SetColorTexture(0.05, 0.05, 0.05, 1)
    
    track.fill = track:CreateTexture(nil, "ARTWORK")
    track.fill:SetPoint("TOPLEFT", track, "TOPLEFT", 1, -1)
    track.fill:SetHeight(8)
    track.fill:SetColorTexture(unpack(C.sliderFill))
    
    local leftBtn = CreateFrame("Button", nil, row)
    leftBtn:SetPoint("RIGHT", track, "LEFT", -6, 0)
    leftBtn:SetSize(16, 16)
    local leftText = leftBtn:CreateFontString(nil, "OVERLAY")
    leftText:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    leftText:SetAllPoints()
    leftText:SetTextColor(unpack(C.textDim))
    leftText:SetText("<")
    leftBtn:SetScript("OnEnter", function() leftText:SetTextColor(unpack(C.accent)) end)
    leftBtn:SetScript("OnLeave", function() leftText:SetTextColor(unpack(C.textDim)) end)
    
    local currentValue = math.max(min, math.min(max, value))
    
    local function UpdateVisuals()
        local pct = (currentValue - min) / (max - min)
        track.fill:SetWidth(math.max(1, pct * (trackWidth - 2)))
        valueText:SetText(tostring(math.floor(currentValue)))
    end
    
    local function SetValue(v)
        v = math.max(min, math.min(max, v))
        v = math.floor(v / step + 0.5) * step
        if v ~= currentValue then
            currentValue = v
            UpdateVisuals()
            if onChange then onChange(currentValue) end
        end
    end
    
    leftBtn:SetScript("OnClick", function() SetValue(currentValue - step) end)
    rightBtn:SetScript("OnClick", function() SetValue(currentValue + step) end)
    
    track:EnableMouse(true)
    track:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            local x = select(1, GetCursorPosition()) / self:GetEffectiveScale()
            local left = self:GetLeft()
            local pct = math.max(0, math.min(1, (x - left) / trackWidth))
            SetValue(min + pct * (max - min))
        end
    end)
    
    track:EnableMouseWheel(true)
    track:SetScript("OnMouseWheel", function(self, delta)
        SetValue(currentValue + delta * step)
    end)
    
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(self, delta)
        SetValue(currentValue + delta * step)
    end)
    
    UpdateVisuals()
    row.SetValue = SetValue
    row.GetValue = function() return currentValue end
    
    return row, yOffset - (ROW_HEIGHT + 4)
end

local function CreateStepper(parent, label, options, current, onChange, yOffset)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 0, yOffset)
    row:SetSize(CONTENT_WIDTH - (INDENT * 2), ROW_HEIGHT + 2)
    
    local labelText = row:CreateFontString(nil, "OVERLAY")
    labelText:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    labelText:SetPoint("LEFT", 10, 0)
    labelText:SetTextColor(unpack(C.textLabel))
    labelText:SetText(label)
    
    local currentIndex = 1
    for i, opt in ipairs(options) do
        if opt.value == current then currentIndex = i; break end
    end
    
    local rightBtn = CreateFrame("Button", nil, row)
    rightBtn:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    rightBtn:SetSize(20, 20)
    local rightArrow = rightBtn:CreateFontString(nil, "OVERLAY")
    rightArrow:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
    rightArrow:SetAllPoints()
    rightArrow:SetTextColor(unpack(C.textDim))
    rightArrow:SetText(">")
    rightBtn:SetScript("OnEnter", function() rightArrow:SetTextColor(unpack(C.accent)) end)
    rightBtn:SetScript("OnLeave", function() rightArrow:SetTextColor(unpack(C.textDim)) end)
    
    local display = CreateFrame("Frame", nil, row)
    display:SetPoint("RIGHT", rightBtn, "LEFT", -4, 0)
    display:SetSize(160, 22)
    display.bg = display:CreateTexture(nil, "BACKGROUND")
    display.bg:SetAllPoints()
    display.bg:SetColorTexture(unpack(C.inputBg))
    
    local displayText = display:CreateFontString(nil, "OVERLAY")
    displayText:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    displayText:SetPoint("CENTER")
    displayText:SetTextColor(unpack(C.text))
    displayText:SetText(options[currentIndex].text)
    
    local leftBtn = CreateFrame("Button", nil, row)
    leftBtn:SetPoint("RIGHT", display, "LEFT", -4, 0)
    leftBtn:SetSize(20, 20)
    local leftArrow = leftBtn:CreateFontString(nil, "OVERLAY")
    leftArrow:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
    leftArrow:SetAllPoints()
    leftArrow:SetTextColor(unpack(C.textDim))
    leftArrow:SetText("<")
    leftBtn:SetScript("OnEnter", function() leftArrow:SetTextColor(unpack(C.accent)) end)
    leftBtn:SetScript("OnLeave", function() leftArrow:SetTextColor(unpack(C.textDim)) end)
    
    local function UpdateDisplay()
        displayText:SetText(options[currentIndex].text)
        if onChange then onChange(options[currentIndex].value) end
    end
    
    leftBtn:SetScript("OnClick", function()
        currentIndex = currentIndex - 1
        if currentIndex < 1 then currentIndex = #options end
        UpdateDisplay()
    end)
    rightBtn:SetScript("OnClick", function()
        currentIndex = currentIndex + 1
        if currentIndex > #options then currentIndex = 1 end
        UpdateDisplay()
    end)
    
    return row, yOffset - (ROW_HEIGHT + 2)
end

local function CreateStyledButton(parent, text, width, height, onClick, yOffset, xOffset)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetPoint("TOPLEFT", xOffset or 10, yOffset or 0)
    btn:SetSize(width or 120, height or 24)
    
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(unpack(C.buttonBg))
    
    btn.borderTex = btn:CreateTexture(nil, "BORDER")
    btn.borderTex:SetPoint("TOPLEFT", -1, 1)
    btn.borderTex:SetPoint("BOTTOMRIGHT", 1, -1)
    btn.borderTex:SetColorTexture(unpack(C.border))
    
    btn.label = btn:CreateFontString(nil, "OVERLAY")
    btn.label:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    btn.label:SetPoint("CENTER")
    btn.label:SetTextColor(unpack(C.text))
    btn.label:SetText(text)
    
    btn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(unpack(C.buttonHover)) end)
    btn:SetScript("OnLeave", function(self) self.bg:SetColorTexture(unpack(C.buttonBg)) end)
    if onClick then btn:SetScript("OnClick", onClick) end
    
    return btn
end

local function CreateNote(parent, text, yOffset)
    local note = parent:CreateFontString(nil, "OVERLAY")
    note:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    note:SetPoint("TOPLEFT", 10, yOffset)
    note:SetWidth(CONTENT_WIDTH - 60)
    note:SetJustifyH("LEFT")
    note:SetTextColor(unpack(C.textDim))
    note:SetText(text)
    return note, yOffset - 18
end

--[[
    Create a dropdown selector. Shows a button with the current value;
    clicking it opens a list of options to choose from.
    
    @param parent   Frame
    @param label    string - Label text
    @param options  function|table - Either a table of {text, value} or a function
                    that returns one (called each time the dropdown opens, for dynamic lists)
    @param current  any - Currently selected value
    @param onChange function(value, text) - Called when selection changes
    @param yOffset  number
    @return row, newY
]]--
local function CreateDropdown(parent, label, options, current, onChange, yOffset)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 0, yOffset)
    row:SetSize(CONTENT_WIDTH - (INDENT * 2), ROW_HEIGHT + 2)
    
    local labelText = row:CreateFontString(nil, "OVERLAY")
    labelText:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    labelText:SetPoint("LEFT", 10, 0)
    labelText:SetTextColor(unpack(C.textLabel))
    labelText:SetText(label)
    
    -- Find current display text
    local currentText = tostring(current)
    local optList = type(options) == "function" and options() or options
    for _, opt in ipairs(optList) do
        if opt.value == current then currentText = opt.text; break end
    end
    
    -- The clickable button showing current value
    local btn = CreateFrame("Button", nil, row)
    btn:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    btn:SetSize(180, 22)
    
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(unpack(C.inputBg))
    
    btn.border = btn:CreateTexture(nil, "BORDER")
    btn.border:SetPoint("TOPLEFT", -1, 1)
    btn.border:SetPoint("BOTTOMRIGHT", 1, -1)
    btn.border:SetColorTexture(unpack(C.border))
    
    btn.text = btn:CreateFontString(nil, "OVERLAY")
    btn.text:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    btn.text:SetPoint("LEFT", 6, 0)
    btn.text:SetPoint("RIGHT", -18, 0)
    btn.text:SetJustifyH("LEFT")
    btn.text:SetTextColor(unpack(C.text))
    btn.text:SetText(currentText)
    
    local arrow = btn:CreateFontString(nil, "OVERLAY")
    arrow:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    arrow:SetPoint("RIGHT", -4, -1)
    arrow:SetTextColor(unpack(C.textDim))
    arrow:SetText("v")
    
    -- The popup menu frame
    local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    menu:SetFrameStrata("DIALOG")
    menu:SetClampedToScreen(true)
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    menu:SetBackdropColor(0.12, 0.12, 0.14, 0.97)
    menu:SetBackdropBorderColor(unpack(C.border))
    menu:Hide()
    
    local function BuildMenu()
        -- Clear old items
        if menu.items then
            for _, item in ipairs(menu.items) do item:Hide() end
        end
        menu.items = {}
        
        local curOptions = type(options) == "function" and options() or options
        local itemHeight = 20
        local menuWidth = 180
        
        for i, opt in ipairs(curOptions) do
            local item = CreateFrame("Button", nil, menu)
            item:SetSize(menuWidth - 2, itemHeight)
            item:SetPoint("TOPLEFT", 1, -((i - 1) * itemHeight) - 1)
            
            item.highlight = item:CreateTexture(nil, "HIGHLIGHT")
            item.highlight:SetAllPoints()
            item.highlight:SetColorTexture(unpack(C.buttonHover))
            
            item.label = item:CreateFontString(nil, "OVERLAY")
            item.label:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
            item.label:SetPoint("LEFT", 6, 0)
            item.label:SetTextColor(unpack(C.text))
            item.label:SetText(opt.text)
            
            -- Highlight active selection
            if opt.value == current then
                item.label:SetTextColor(unpack(C.accent))
            end
            
            item:SetScript("OnClick", function()
                current = opt.value
                currentText = opt.text
                btn.text:SetText(currentText)
                menu:Hide()
                if onChange then onChange(opt.value, opt.text) end
            end)
            
            table.insert(menu.items, item)
        end
        
        menu:SetSize(menuWidth, (#curOptions * itemHeight) + 2)
    end
    
    btn:SetScript("OnClick", function()
        if menu:IsShown() then
            menu:Hide()
        else
            BuildMenu()
            menu:ClearAllPoints()
            menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
            menu:Show()
        end
    end)
    
    btn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(unpack(C.buttonHover)) end)
    btn:SetScript("OnLeave", function(self) self.bg:SetColorTexture(unpack(C.inputBg)) end)
    
    -- Close menu when clicking elsewhere
    menu:SetScript("OnShow", function()
        menu:SetPropagateKeyboardInput(false)
    end)
    menu:SetScript("OnHide", function()
        menu:SetPropagateKeyboardInput(true)
    end)
    
    -- Close on escape
    menu:EnableKeyboard(true)
    menu:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then self:Hide() end
    end)
    
    -- External method to update the display text
    row.SetValue = function(_, val, txt)
        current = val
        btn.text:SetText(txt or tostring(val))
    end
    
    return row, yOffset - (ROW_HEIGHT + 4)
end

--============================================================================
-- MAIN PANEL
--============================================================================

function Config:CreatePanel()
    local panel = CreateFrame("Frame", "CDMx_ConfigPanel")
    panel.name = "CDMx"
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 4)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(CONTENT_WIDTH)
    content:SetHeight(2000)
    scrollFrame:SetScrollChild(content)
    
    self.panel = panel
    self.content = content
    self.sections = {}
    
    -- Title
    local title = content:CreateFontString(nil, "ARTWORK")
    title:SetFont("Fonts\\MORPHEUS.TTF", 22, "")
    title:SetPoint("TOPLEFT", INDENT, -12)
    title:SetTextColor(unpack(C.text))
    title:SetText("CDMx")
    
    local version = content:CreateFontString(nil, "ARTWORK")
    version:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    version:SetPoint("LEFT", title, "RIGHT", 10, -2)
    version:SetTextColor(unpack(C.textDim))
    version:SetText("v" .. CDM.version)
    
    local subtitle = content:CreateFontString(nil, "ARTWORK")
    subtitle:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetTextColor(unpack(C.textDim))
    subtitle:SetText("Cooldown Manager Extended")
    
    local sectionY = -60
    
    -- ============ GENERAL ============
    local genHeader, genContent = CreateSectionHeader(content, "General", sectionY)
    table.insert(self.sections, {header = genHeader, content = genContent})
    
    local y = -8
    _, y = CreateCheckbox(genContent, "Show hotkeys on cooldown icons", CDM.db.showHotkeys, function(v)
        CDM.db.showHotkeys = v
        if CDM.BlizzHooks then CDM.BlizzHooks:UpdateAllVisibleFrames() end
        if CDM.TrinketBar then CDM.TrinketBar:Update() end
    end, y)
    
    _, y = CreateCheckbox(genContent, "Show proc glow when abilities ready", CDM.db.procGlow, function(v)
        CDM.db.procGlow = v
    end, y)
    
    _, y = CreateStepper(genContent, "Hotkey Position", {
        {text = "Top Left", value = "TOPLEFT"},
        {text = "Top Right", value = "TOPRIGHT"},
        {text = "Bottom Left", value = "BOTTOMLEFT"},
        {text = "Bottom Right", value = "BOTTOMRIGHT"},
        {text = "Center", value = "CENTER"},
    }, CDM.db.hotkeyAnchor or "TOPLEFT", function(v)
        CDM.db.hotkeyAnchor = v
        if CDM.BlizzHooks then CDM.BlizzHooks:UpdateAllVisibleFrames() end
        if CDM.TrinketBar then CDM.TrinketBar:Update() end
    end, y)
    
    _, y = CreateStepper(genContent, "Font Outline", {
        {text = "Outline", value = "OUTLINE"},
        {text = "Thick Outline", value = "THICKOUTLINE"},
        {text = "None", value = ""},
    }, CDM.db.hotkeyOutline or "OUTLINE", function(v)
        CDM.db.hotkeyOutline = v
        if CDM.BlizzHooks then CDM.BlizzHooks:UpdateAllVisibleFrames() end
    end, y)
    
    _, y = CreateSlider(genContent, "X Offset", -20, 20, CDM.db.hotkeyOffsetX or 2, 1, function(v)
        CDM.db.hotkeyOffsetX = v
        if CDM.BlizzHooks then CDM.BlizzHooks:UpdateAllVisibleFrames() end
    end, y)
    
    _, y = CreateSlider(genContent, "Y Offset", -20, 20, CDM.db.hotkeyOffsetY or -2, 1, function(v)
        CDM.db.hotkeyOffsetY = v
        if CDM.BlizzHooks then CDM.BlizzHooks:UpdateAllVisibleFrames() end
    end, y)
    
    genContent:SetHeight(math.abs(y) + 8)
    
    -- ============ BLIZZARD COOLDOWNS ============
    sectionY = sectionY - 30 - SECTION_GAP
    local cdmHeader, cdmContent = CreateSectionHeader(content, "Blizzard Cooldowns", sectionY)
    table.insert(self.sections, {header = cdmHeader, content = cdmContent})
    
    y = -8
    _, y = CreateNote(cdmContent, "Settings for Blizzard's Essential and Utility cooldown bars.", y)
    
    _, y = CreateSlider(cdmContent, "Essential Font Size", 8, 32, CDM.db.hotkeyFontSize or 16, 1, function(v)
        CDM.db.hotkeyFontSize = v
        if CDM.BlizzHooks then CDM.BlizzHooks:UpdateAllVisibleFrames() end
    end, y)
    
    _, y = CreateSlider(cdmContent, "Utility Font Size", 8, 24, CDM.db.utilityFontSize or 12, 1, function(v)
        CDM.db.utilityFontSize = v
        if CDM.BlizzHooks then CDM.BlizzHooks:UpdateAllVisibleFrames() end
    end, y)
    
    _, y = CreateCheckbox(cdmContent, "Show black borders", CDM.db.cooldownManager.showBorder, function(v)
        CDM.db.cooldownManager.showBorder = v
    end, y)
    
    _, y = CreateCheckbox(cdmContent, "Blizzard-style icons (rounded border)", CDM.db.cooldownManager.squareIcons, function(v)
        CDM.db.cooldownManager.squareIcons = v
    end, y)
    
    _, y = CreateNote(cdmContent, "Border and icon changes apply on /reload.", y)
    cdmContent:SetHeight(math.abs(y) + 8)
    
    -- ============ TRINKET BAR ============
    sectionY = sectionY - 30 - SECTION_GAP
    local trinketHeader, trinketContent = CreateSectionHeader(content, "Trinket Bar", sectionY)
    table.insert(self.sections, {header = trinketHeader, content = trinketContent})
    
    y = -8
    _, y = CreateCheckbox(trinketContent, "Enable trinket bar", CDM.db.trinketBar.enabled, function(v)
        CDM.db.trinketBar.enabled = v
        if CDM.TrinketBar and CDM.TrinketBar.frame then
            if v then CDM.TrinketBar:UpdateVisibility() else CDM.TrinketBar.frame:Hide() end
        end
    end, y)
    
    _, y = CreateStepper(trinketContent, "Visibility", {
        {text = "Always Show", value = "always"},
        {text = "In Combat Only", value = "combat"},
        {text = "Out of Combat", value = "noCombat"},
    }, CDM.db.trinketBar.visibility or "always", function(v)
        CDM.db.trinketBar.visibility = v
        if CDM.TrinketBar then CDM.TrinketBar:UpdateVisibility() end
    end, y)
    
    _, y = CreateStepper(trinketContent, "Layout", {
        {text = "Horizontal", value = true},
        {text = "Vertical", value = false},
    }, CDM.db.trinketBar.horizontal, function(v)
        CDM.db.trinketBar.horizontal = v
        if CDM.TrinketBar then CDM.TrinketBar:Update() end
    end, y)
    
    _, y = CreateCheckbox(trinketContent, "Centered layout", CDM.db.trinketBar.centered ~= false, function(v)
        CDM.db.trinketBar.centered = v
        if CDM.TrinketBar then CDM.TrinketBar:Update() end
    end, y)
    
    _, y = CreateSlider(trinketContent, "Icon Size", 20, 80, CDM.db.trinketBar.iconSize or 40, 1, function(v)
        CDM.db.trinketBar.iconSize = v
        if CDM.TrinketBar then CDM.TrinketBar:Update() end
    end, y)
    
    _, y = CreateSlider(trinketContent, "Spacing", 0, 20, CDM.db.trinketBar.padding or 5, 1, function(v)
        CDM.db.trinketBar.padding = v
        if CDM.TrinketBar then CDM.TrinketBar:Update() end
    end, y)
    
    _, y = CreateSlider(trinketContent, "Font Size", 8, 20, CDM.db.trinketBar.hotkeyFontSize or 12, 1, function(v)
        CDM.db.trinketBar.hotkeyFontSize = v
        if CDM.TrinketBar then CDM.TrinketBar:Update() end
    end, y)
    
    _, y = CreateCheckbox(trinketContent, "Show black borders", CDM.db.trinketBar.showBorder, function(v)
        CDM.db.trinketBar.showBorder = v
    end, y)
    
    _, y = CreateCheckbox(trinketContent, "Blizzard-style icons (rounded border)", CDM.db.trinketBar.squareIcons, function(v)
        CDM.db.trinketBar.squareIcons = v
    end, y)
    
    _, y = CreateNote(trinketContent, "Border and icon changes apply on /reload. Position bars using Edit Mode.", y)
    trinketContent:SetHeight(math.abs(y) + 8)
    
    -- ============ CUSTOM BARS ============
    sectionY = sectionY - 30 - SECTION_GAP
    local customHeader, customContent = CreateSectionHeader(content, "Custom Bars", sectionY)
    table.insert(self.sections, {header = customHeader, content = customContent})
    
    y = -8
    _, y = CreateNote(customContent, "Create custom tracking bars for spells and items from your action bars.", y)
    
    local addBtn = CreateStyledButton(customContent, "+ Add New Bar", 140, 26, function()
        StaticPopupDialogs["CDMX_NEW_BAR"] = {
            text = "Enter name for new custom bar:",
            button1 = "Create", button2 = "Cancel", hasEditBox = true,
            OnAccept = function(self)
                local editBox = self:GetParent().editBox or self.editBox or _G[self:GetName().."EditBox"]
                local name = editBox and editBox:GetText() or ""
                if name and name ~= "" then
                    if CDM.db.customBars[name] then
                        CDM:Msg("Bar '" .. name .. "' already exists!")
                    else
                        CDM.db.customBars[name] = {
                            enabled = true, locked = false, horizontal = true,
                            centered = true,
                            iconSize = 40, padding = 5,
                            position = { point = "CENTER", x = 0, y = 0 },
                            squareIcons = CDM.db.customBarsStyle.squareIcons,
                            showBorder = CDM.db.customBarsStyle.showBorder,
                            hotkeyFontSize = 12, hotkeyAnchor = "TOPLEFT",
                            visibility = "always", items = {}, numSlots = 5,
                        }
                        CDM:Msg("Created bar: " .. name .. " - /reload to see it")
                    end
                end
            end,
            OnShow = function(self)
                local editBox = self:GetParent().editBox or self.editBox or _G[self:GetName().."EditBox"]
                if editBox then editBox:SetFocus() end
            end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
        StaticPopup_Show("CDMX_NEW_BAR")
    end, y)
    y = y - 34
    
    y = y - 4
    local styleLabel = customContent:CreateFontString(nil, "OVERLAY")
    styleLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    styleLabel:SetPoint("TOPLEFT", 10, y)
    styleLabel:SetTextColor(unpack(C.textDim))
    styleLabel:SetText("Default Style for New Bars:")
    y = y - 22
    
    _, y = CreateCheckbox(customContent, "Blizzard-style icons (rounded border)", CDM.db.customBarsStyle.squareIcons, function(v)
        CDM.db.customBarsStyle.squareIcons = v
        for barName, s in pairs(CDM.db.customBars or {}) do
            s.squareIcons = v
            if CDM.CustomBars then CDM.CustomBars:UpdateBar(barName) end
        end
    end, y)
    
    _, y = CreateCheckbox(customContent, "Show Border", CDM.db.customBarsStyle.showBorder, function(v)
        CDM.db.customBarsStyle.showBorder = v
        for barName, s in pairs(CDM.db.customBars or {}) do
            s.showBorder = v
            if CDM.CustomBars then CDM.CustomBars:UpdateBar(barName) end
        end
    end, y)
    
    y = y - 8
    
    if CDM.db.customBars and next(CDM.db.customBars) then
        for barName, barSettings in pairs(CDM.db.customBars) do
            local barLabel = customContent:CreateFontString(nil, "OVERLAY")
            barLabel:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
            barLabel:SetPoint("TOPLEFT", 10, y)
            barLabel:SetTextColor(unpack(C.accent))
            barLabel:SetText(barName)
            
            local barStatus = customContent:CreateFontString(nil, "OVERLAY")
            barStatus:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
            barStatus:SetPoint("LEFT", barLabel, "RIGHT", 10, 0)
            barStatus:SetTextColor(unpack(C.textDim))
            barStatus:SetText(string.format("(%s | %d slots | %d items)",
                barSettings.horizontal and "H" or "V",
                barSettings.numSlots or 5, #(barSettings.items or {})))
            y = y - 22
            
            local sep = customContent:CreateTexture(nil, "ARTWORK")
            sep:SetPoint("TOPLEFT", 10, y + 4)
            sep:SetSize(CONTENT_WIDTH - 60, 1)
            sep:SetColorTexture(unpack(C.border))
            
            _, y = CreateSlider(customContent, "Slots", 1, 12, barSettings.numSlots or 5, 1, function(v)
                barSettings.numSlots = v
                CDM:Msg("Bar '" .. barName .. "' slots: " .. v .. " - /reload to apply")
            end, y)
            
            _, y = CreateSlider(customContent, "Icon Size", 20, 80, barSettings.iconSize or 40, 1, function(v)
                barSettings.iconSize = v
                if CDM.CustomBars then
                    CDM.CustomBars:UpdateLayout(barName)
                    CDM.CustomBars:UpdateBar(barName)
                end
            end, y)
            
            _, y = CreateSlider(customContent, "Spacing", 0, 20, barSettings.padding or 5, 1, function(v)
                barSettings.padding = v
                if CDM.CustomBars then
                    CDM.CustomBars:UpdateLayout(barName)
                    CDM.CustomBars:UpdateBar(barName)
                end
            end, y)
            
            _, y = CreateSlider(customContent, "Font Size", 8, 24, barSettings.hotkeyFontSize or 12, 1, function(v)
                barSettings.hotkeyFontSize = v
                if CDM.CustomBars then CDM.CustomBars:UpdateBar(barName) end
            end, y)
            
            _, y = CreateStepper(customContent, "Layout", {
                {text = "Horizontal", value = true},
                {text = "Vertical", value = false},
            }, barSettings.horizontal, function(v)
                barSettings.horizontal = v
                if CDM.CustomBars then
                    CDM.CustomBars:UpdateLayout(barName)
                    CDM.CustomBars:UpdateBar(barName)
                end
            end, y)
            
            _, y = CreateCheckbox(customContent, "Centered layout", barSettings.centered ~= false, function(v)
                barSettings.centered = v
                if CDM.CustomBars then
                    CDM.CustomBars:UpdateLayout(barName)
                    CDM.CustomBars:UpdateBar(barName)
                end
            end, y)
            
            _, y = CreateStepper(customContent, "Visibility", {
                {text = "Always Show", value = "always"},
                {text = "In Combat Only", value = "combat"},
                {text = "Out of Combat", value = "noCombat"},
            }, barSettings.visibility or "always", function(v)
                barSettings.visibility = v
                if CDM.CustomBars then CDM.CustomBars:UpdateVisibility(barName) end
            end, y)
            
            y = y - 4
            local editBtn = CreateStyledButton(customContent, "Edit Items", 90, 22, function()
                Config:ShowItemPicker(barName)
            end, y)
            
            local delBtnName = barName
            local delBtn = CreateStyledButton(customContent, "Delete", 70, 22, function()
                StaticPopupDialogs["CDMX_DELETE_BAR"] = {
                    text = "Delete bar '" .. delBtnName .. "'?",
                    button1 = "Delete", button2 = "Cancel",
                    OnAccept = function()
                        CDM.db.customBars[delBtnName] = nil
                        CDM:Msg("Deleted '" .. delBtnName .. "' - /reload to apply")
                    end,
                    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
                }
                StaticPopup_Show("CDMX_DELETE_BAR")
            end, y, 108)
            delBtn.bg:SetColorTexture(0.25, 0.12, 0.12, 1)
            delBtn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.35, 0.15, 0.15, 1) end)
            delBtn:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.25, 0.12, 0.12, 1) end)
            
            y = y - 34
        end
    else
        local noBars = customContent:CreateFontString(nil, "OVERLAY")
        noBars:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        noBars:SetPoint("TOPLEFT", 10, y)
        noBars:SetTextColor(unpack(C.textDim))
        noBars:SetText("No custom bars created yet.")
        y = y - 22
    end
    
    customContent:SetHeight(math.abs(y) + 8)
    
    -- ============ PROFILES ============
    sectionY = sectionY - 30 - SECTION_GAP
    local profileHeader, profileContent = CreateSectionHeader(content, "Profiles", sectionY)
    table.insert(self.sections, {header = profileHeader, content = profileContent})
    
    y = -8
    _, y = CreateNote(profileContent, "Manage named profiles. Each character can use a different profile, or share one across alts.", y)
    
    -- Show current character
    local currentLabel = profileContent:CreateFontString(nil, "OVERLAY")
    currentLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    currentLabel:SetPoint("TOPLEFT", 10, y)
    currentLabel:SetTextColor(unpack(C.accent))
    currentLabel:SetText("Character: " .. CDM:GetCharKey())
    y = y - 22
    
    -- Profile dropdown (dynamic options - rebuilt each time it opens)
    _, y = CreateDropdown(profileContent, "Active Profile", function()
        local list = {}
        for _, name in ipairs(CDM:GetProfileList()) do
            table.insert(list, { text = name, value = name })
        end
        return list
    end, CDM.activeProfile or "Default", function(v)
        CDM:SetProfile(v)
    end, y)
    
    -- Row 1: New + Copy
    local newBtn = CreateStyledButton(profileContent, "+ New Profile", 120, 24, function()
        StaticPopupDialogs["CDMX_NEW_PROFILE"] = {
            text = "Enter name for new profile:",
            button1 = "Create", button2 = "Cancel", hasEditBox = true,
            OnAccept = function(self)
                local editBox = self:GetParent().editBox or self.editBox or _G[self:GetName().."EditBox"]
                local name = editBox and editBox:GetText() or ""
                if name and name ~= "" then
                    CDM:CreateProfile(name)
                end
            end,
            OnShow = function(self)
                local editBox = self:GetParent().editBox or self.editBox or _G[self:GetName().."EditBox"]
                if editBox then editBox:SetFocus() end
            end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
        StaticPopup_Show("CDMX_NEW_PROFILE")
    end, y)
    
    CreateStyledButton(profileContent, "Copy Current", 120, 24, function()
        StaticPopupDialogs["CDMX_COPY_PROFILE"] = {
            text = "Copy '" .. CDM.activeProfile .. "' to new profile named:",
            button1 = "Copy", button2 = "Cancel", hasEditBox = true,
            OnAccept = function(self)
                local editBox = self:GetParent().editBox or self.editBox or _G[self:GetName().."EditBox"]
                local name = editBox and editBox:GetText() or ""
                if name and name ~= "" then
                    CDM:CopyProfile(CDM.activeProfile, name)
                end
            end,
            OnShow = function(self)
                local editBox = self:GetParent().editBox or self.editBox or _G[self:GetName().."EditBox"]
                if editBox then editBox:SetFocus() end
            end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
        StaticPopup_Show("CDMX_COPY_PROFILE")
    end, y, 138)
    y = y - 30
    
    -- Row 2: Rename + Delete
    CreateStyledButton(profileContent, "Rename", 120, 24, function()
        StaticPopupDialogs["CDMX_RENAME_PROFILE"] = {
            text = "Rename profile '" .. CDM.activeProfile .. "' to:",
            button1 = "Rename", button2 = "Cancel", hasEditBox = true,
            OnAccept = function(self)
                local editBox = self:GetParent().editBox or self.editBox or _G[self:GetName().."EditBox"]
                local name = editBox and editBox:GetText() or ""
                if name and name ~= "" then
                    CDM:RenameProfile(CDM.activeProfile, name)
                end
            end,
            OnShow = function(self)
                local editBox = self:GetParent().editBox or self.editBox or _G[self:GetName().."EditBox"]
                if editBox then editBox:SetFocus() end
            end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
        StaticPopup_Show("CDMX_RENAME_PROFILE")
    end, y)
    
    local delProfileBtn = CreateStyledButton(profileContent, "Delete Profile", 120, 24, function()
        -- Build list of deletable profiles (everything except the active one)
        local deletable = {}
        for _, name in ipairs(CDM:GetProfileList()) do
            if name ~= CDM.activeProfile then
                table.insert(deletable, name)
            end
        end
        
        if #deletable == 0 then
            CDM:Msg("No other profiles to delete. Create another profile first.")
            return
        end
        
        StaticPopupDialogs["CDMX_DELETE_PROFILE"] = {
            text = "Enter name of profile to delete (cannot delete active profile):\n\nDeletable: " .. table.concat(deletable, ", "),
            button1 = "Delete", button2 = "Cancel", hasEditBox = true,
            OnAccept = function(self)
                local editBox = self:GetParent().editBox or self.editBox or _G[self:GetName().."EditBox"]
                local name = editBox and editBox:GetText() or ""
                if name and name ~= "" then
                    CDM:DeleteProfile(name)
                end
            end,
            OnShow = function(self)
                local editBox = self:GetParent().editBox or self.editBox or _G[self:GetName().."EditBox"]
                if editBox then editBox:SetFocus() end
            end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
        StaticPopup_Show("CDMX_DELETE_PROFILE")
    end, y, 138)
    delProfileBtn.bg:SetColorTexture(0.25, 0.12, 0.12, 1)
    delProfileBtn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.35, 0.15, 0.15, 1) end)
    delProfileBtn:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.25, 0.12, 0.12, 1) end)
    y = y - 30
    
    -- Row 3: Reset
    CreateStyledButton(profileContent, "Reset to Defaults", 140, 24, function()
        StaticPopupDialogs["CDMX_RESET_PROFILE"] = {
            text = "Reset profile '" .. CDM.activeProfile .. "' to defaults? All settings will be lost.",
            button1 = "Reset", button2 = "Cancel",
            OnAccept = function()
                CDM:ResetProfile()
            end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
        StaticPopup_Show("CDMX_RESET_PROFILE")
    end, y)
    y = y - 34
    
    -- Character assignments
    local charMapLabel = profileContent:CreateFontString(nil, "OVERLAY")
    charMapLabel:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    charMapLabel:SetPoint("TOPLEFT", 10, y)
    charMapLabel:SetTextColor(unpack(C.textDim))
    charMapLabel:SetText("Character assignments:")
    y = y - 16
    
    for charKey, pName in pairs(CDMxDB.charMap or {}) do
        local charLine = profileContent:CreateFontString(nil, "OVERLAY")
        charLine:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
        charLine:SetPoint("TOPLEFT", 16, y)
        charLine:SetTextColor(unpack(C.text))
        charLine:SetText(charKey .. "  ->  " .. pName)
        y = y - 14
    end
    
    y = y - 4
    _, y = CreateNote(profileContent, "Switching profiles requires /reload to fully apply.", y)
    profileContent:SetHeight(math.abs(y) + 8)
    
    -- ============ UTILITIES ============
    sectionY = sectionY - 30 - SECTION_GAP
    local utilHeader, utilContent = CreateSectionHeader(content, "Utilities", sectionY)
    table.insert(self.sections, {header = utilHeader, content = utilContent})
    
    y = -8
    CreateStyledButton(utilContent, "Open Edit Mode", 160, 26, function()
        if EditModeManagerFrame then ShowUIPanel(EditModeManagerFrame) end
    end, y)
    y = y - 34
    
    CreateStyledButton(utilContent, "Rescan Hotkeys", 160, 26, function()
        if CDM.Hotkeys then
            CDM.Hotkeys:ScanActionBars()
            if CDM.BlizzHooks then CDM.BlizzHooks:UpdateAllVisibleFrames() end
            CDM:Msg("Hotkeys rescanned")
        end
    end, y)
    y = y - 34
    
    CreateStyledButton(utilContent, "Reload UI", 160, 26, function() ReloadUI() end, y)
    y = y - 28
    
    _, y = CreateNote(utilContent, "Reload applies border, icon, and slot changes.", y)
    utilContent:SetHeight(math.abs(y) + 8)
    
    -- Footer
    sectionY = sectionY - 30 - SECTION_GAP - 10
    local footer = content:CreateFontString(nil, "ARTWORK")
    footer:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
    footer:SetPoint("TOPLEFT", INDENT, sectionY)
    footer:SetTextColor(unpack(C.textDim))
    footer:SetText("CDMx v" .. CDM.version .. "  |  /cdmx help for commands  |  Position bars with Edit Mode")
    
    content:SetHeight(math.abs(sectionY) + 40)
    
    -- Layout recalc
    function Config:RecalcLayout()
        local cy = -60
        for _, section in ipairs(self.sections) do
            section.header:ClearAllPoints()
            section.header:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT, cy)
            cy = cy - 30
            if section.header.expanded and section.content:IsShown() then
                cy = cy - section.content:GetHeight() - 4
            end
            cy = cy - SECTION_GAP
        end
        footer:ClearAllPoints()
        footer:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT, cy - 10)
        content:SetHeight(math.abs(cy) + 40)
    end
    
    -- Register with Blizzard Settings
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        Config.settingsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
    
    return panel
end

function Config:Open()
    if Settings and Settings.OpenToCategory and self.settingsCategory then
        Settings.OpenToCategory(self.settingsCategory:GetID())
    elseif SettingsPanel then
        SettingsPanel:Open()
    end
end

--============================================================================
-- ITEM PICKER
--============================================================================

function Config:ShowItemPicker(barName)
    local barSettings = CDM.db.customBars[barName]
    if not barSettings then CDM:Msg("Bar not found: " .. barName); return end
    
    if self.pickerFrame then self.pickerFrame:Hide(); self.pickerFrame = nil end
    
    local availableItems = {}
    local seenIDs = {}
    
    for slot = 1, 120 do
        local actionType, id = GetActionInfo(slot)
        if actionType == "spell" and id then
            local spellName = C_Spell.GetSpellName(id)
            local spellTexture = C_Spell.GetSpellTexture(id)
            if spellName and not seenIDs["spell:" .. id] then
                table.insert(availableItems, { type = "spell", id = id, name = spellName, texture = spellTexture })
                seenIDs["spell:" .. id] = true
            end
        elseif actionType == "item" and id then
            local itemName, _, _, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(id)
            if itemName and not seenIDs["item:" .. id] then
                table.insert(availableItems, { type = "item", id = id, name = itemName, texture = itemTexture })
                seenIDs["item:" .. id] = true
            end
        end
    end
    
    table.sort(availableItems, function(a, b) return a.name < b.name end)
    
    local picker = CreateFrame("Frame", "CDMx_ItemPicker", UIParent, "BackdropTemplate")
    picker:SetSize(380, 480)
    picker:SetPoint("CENTER")
    picker:SetFrameStrata("DIALOG")
    picker:EnableMouse(true)
    picker:SetMovable(true)
    picker:RegisterForDrag("LeftButton")
    picker:SetScript("OnDragStart", picker.StartMoving)
    picker:SetScript("OnDragStop", picker.StopMovingOrSizing)
    picker:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    picker:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    picker:SetBackdropBorderColor(unpack(C.border))
    self.pickerFrame = picker
    
    local titleBar = CreateFrame("Frame", nil, picker)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(28)
    titleBar.bg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBar.bg:SetAllPoints()
    titleBar.bg:SetColorTexture(unpack(C.headerBg))
    
    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    titleText:SetPoint("LEFT", 10, 0)
    titleText:SetTextColor(unpack(C.text))
    titleText:SetText("Edit Items: " .. barName)
    
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetPoint("RIGHT", -6, 0)
    closeBtn:SetSize(20, 20)
    local closeX = closeBtn:CreateFontString(nil, "OVERLAY")
    closeX:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
    closeX:SetAllPoints()
    closeX:SetTextColor(unpack(C.textDim))
    closeX:SetText("x")
    closeBtn:SetScript("OnEnter", function() closeX:SetTextColor(unpack(C.red)) end)
    closeBtn:SetScript("OnLeave", function() closeX:SetTextColor(unpack(C.textDim)) end)
    closeBtn:SetScript("OnClick", function() picker:Hide() end)
    
    local instructions = picker:CreateFontString(nil, "OVERLAY")
    instructions:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    instructions:SetPoint("TOPLEFT", 10, -34)
    instructions:SetTextColor(unpack(C.textDim))
    instructions:SetText("Select spells and items to track on this bar:")
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -52)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 44)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(330, 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    local selectedItems = {}
    for _, item in ipairs(barSettings.items or {}) do
        selectedItems[item.type .. ":" .. item.id] = true
    end
    
    local checkboxes = {}
    local itemY = -4
    
    for _, item in ipairs(availableItems) do
        local row = CreateFrame("Button", nil, scrollChild)
        row:SetPoint("TOPLEFT", 0, itemY)
        row:SetSize(320, 26)
        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(1, 1, 1, 0.03)
        row.highlight:Hide()
        row:SetScript("OnEnter", function(self) self.highlight:Show() end)
        row:SetScript("OnLeave", function(self) self.highlight:Hide() end)
        
        local cb = CreateFrame("Button", nil, row)
        cb:SetPoint("LEFT", 4, 0)
        cb:SetSize(16, 16)
        cb.bg = cb:CreateTexture(nil, "BACKGROUND")
        cb.bg:SetAllPoints()
        cb.bg:SetColorTexture(unpack(C.inputBg))
        cb.borderTex = cb:CreateTexture(nil, "BORDER")
        cb.borderTex:SetPoint("TOPLEFT", -1, 1)
        cb.borderTex:SetPoint("BOTTOMRIGHT", 1, -1)
        cb.borderTex:SetColorTexture(unpack(C.border))
        cb.check = cb:CreateTexture(nil, "ARTWORK")
        cb.check:SetPoint("TOPLEFT", 2, -2)
        cb.check:SetPoint("BOTTOMRIGHT", -2, 2)
        cb.check:SetColorTexture(unpack(C.accent))
        
        local key = item.type .. ":" .. item.id
        cb.checked = selectedItems[key] or false
        if cb.checked then cb.check:Show() else cb.check:Hide() end
        cb.itemData = item
        
        local function ToggleCheck()
            cb.checked = not cb.checked
            if cb.checked then cb.check:Show() else cb.check:Hide() end
        end
        cb:SetScript("OnClick", ToggleCheck)
        row:SetScript("OnClick", ToggleCheck)
        table.insert(checkboxes, cb)
        
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("LEFT", cb, "RIGHT", 6, 0)
        icon:SetSize(22, 22)
        icon:SetTexture(item.texture)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        
        local name = row:CreateFontString(nil, "OVERLAY")
        name:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        name:SetTextColor(unpack(C.text))
        name:SetText(item.name)
        
        local typeBadge = row:CreateFontString(nil, "OVERLAY")
        typeBadge:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
        typeBadge:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        typeBadge:SetTextColor(unpack(C.textDim))
        typeBadge:SetText(item.type == "spell" and "spell" or "item")
        
        itemY = itemY - 26
    end
    
    scrollChild:SetHeight(math.abs(itemY) + 8)
    
    local saveBtn = CreateStyledButton(picker, "Save", 80, 24, function()
        barSettings.items = {}
        for _, cb in ipairs(checkboxes) do
            if cb.checked then
                table.insert(barSettings.items, { type = cb.itemData.type, id = cb.itemData.id })
            end
        end
        
        -- Live rebuild: destroy old icons, recreate bar with new item count
        if CDM.CustomBars and CDM.CustomBars.bars[barName] then
            local frame = CDM.CustomBars.bars[barName]
            -- Hide and clear old icons
            for _, icon in ipairs(frame.icons) do
                icon:Hide()
                icon:SetParent(nil)
            end
            wipe(frame.icons)
            
            -- Create new icons for current items
            for i = 1, #barSettings.items do
                local button = CDM.UI:CreateIconButton(frame, {
                    size = barSettings.iconSize or 40,
                    showBorder = barSettings.showBorder,
                    squareIcons = barSettings.squareIcons,
                    hotkeyFontSize = barSettings.hotkeyFontSize or 12,
                    masqueGroup = "Custom: " .. barName,
                })
                table.insert(frame.icons, button)
            end
            
            CDM.CustomBars:UpdateBar(barName)
            CDM.CustomBars:UpdateLayout(barName)
        end
        
        CDM:Msg("Saved " .. #barSettings.items .. " items to '" .. barName .. "'")
        picker:Hide()
    end, nil)
    saveBtn:ClearAllPoints()
    saveBtn:SetPoint("BOTTOMLEFT", picker, "BOTTOMLEFT", 10, 10)
    
    local cancelBtn = CreateStyledButton(picker, "Cancel", 80, 24, function() picker:Hide() end, nil)
    cancelBtn:ClearAllPoints()
    cancelBtn:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
    
    local selectAllBtn = CreateStyledButton(picker, "Select All", 80, 24, function()
        for _, cb in ipairs(checkboxes) do cb.checked = true; cb.check:Show() end
    end, nil)
    selectAllBtn:ClearAllPoints()
    selectAllBtn:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -10, 10)
    
    local clearAllBtn = CreateStyledButton(picker, "Clear All", 80, 24, function()
        for _, cb in ipairs(checkboxes) do cb.checked = false; cb.check:Hide() end
    end, nil)
    clearAllBtn:ClearAllPoints()
    clearAllBtn:SetPoint("RIGHT", selectAllBtn, "LEFT", -8, 0)
    
    picker:Show()
end

--============================================================================
-- INITIALIZATION
--============================================================================

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == ADDON_NAME then
        Config:CreatePanel()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
