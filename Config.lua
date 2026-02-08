--[[
    CDMx - Config.lua
    Configuration UI panel for easy settings management
    
    Integrates with Blizzard's Interface Options
    
    Author: Juicetheforce (with Claude assistance)
    Target: WoW 12.0.x (Midnight)
]]--

local ADDON_NAME, CDM = ...

-- VERSION MARKER
print("|cffFF0000=== CDMx Config.lua VERSION: 2026-02-07-FINAL ===|r")

-- Create config module
CDM.Config = {}
local Config = CDM.Config

--[[
    Create the main config panel
]]--
function Config:CreatePanel()
    local panel = CreateFrame("Frame", "CDM_ConfigPanel")
    panel.name = "CDMx"
    
    -- Create scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 3, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", -27, 4)
    
    -- Create content frame (the scrollable area)
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(580, 800)  -- Width and height of scrollable content
    scrollFrame:SetScrollChild(content)
    
    -- Title
    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("CDMx Settings")
    
    -- Version
    local version = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    version:SetText("Version: " .. CDM.version)
    version:SetTextColor(0.5, 0.5, 0.5)
    
    local yOffset = -80
    
    -- === GENERAL SETTINGS ===
    local generalHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    generalHeader:SetPoint("TOPLEFT", 16, yOffset)
    generalHeader:SetText("|cff33ff99General Settings|r")
    yOffset = yOffset - 30
    
    -- Show Hotkeys checkbox
    local showHotkeys = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    showHotkeys:SetPoint("TOPLEFT", 20, yOffset)
    showHotkeys.Text:SetText("Show hotkeys on cooldown icons")
    showHotkeys:SetChecked(CDM.db.showHotkeys)
    showHotkeys:SetScript("OnClick", function(self)
        CDM.db.showHotkeys = self:GetChecked()
        CDM:Print("Hotkeys", CDM.db.showHotkeys and "enabled" or "disabled")
    end)
    yOffset = yOffset - 30
    
    -- Hotkey Position dropdown
    local anchorLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    anchorLabel:SetPoint("TOPLEFT", 20, yOffset)
    anchorLabel:SetText("Hotkey Position:")
    
    local anchorDropdown = CreateFrame("Frame", "CDM_HotkeyAnchorDropdown", content, "UIDropDownMenuTemplate")
    anchorDropdown:SetPoint("TOPLEFT", 120, yOffset + 3)
    
    local function SetAnchor(value)
        CDM.db.hotkeyAnchor = value
        UIDropDownMenu_SetText(anchorDropdown, value:gsub("TOP", "Top "):gsub("BOTTOM", "Bottom "):gsub("LEFT", "Left"):gsub("RIGHT", "Right"):gsub("CENTER", "Center"))
        if CDM.BlizzHooks then
            CDM.BlizzHooks:UpdateAllVisibleFrames()
        end
        if CDM.TrinketBar then
            CDM.TrinketBar:Update()
        end
    end
    
    UIDropDownMenu_Initialize(anchorDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        
        local anchors = {
            {text = "  Top Left", value = "TOPLEFT"},
            {text = "  Top Right", value = "TOPRIGHT"},
            {text = "  Bottom Left", value = "BOTTOMLEFT"},
            {text = "  Bottom Right", value = "BOTTOMRIGHT"},
            {text = "  Center", value = "CENTER"},
        }
        
        for _, anchor in ipairs(anchors) do
            info.text = anchor.text
            info.value = anchor.value
            info.func = function() SetAnchor(anchor.value) end
            info.checked = (CDM.db.hotkeyAnchor == anchor.value)
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    local currentAnchor = CDM.db.hotkeyAnchor or "TOPLEFT"
    UIDropDownMenu_SetText(anchorDropdown, currentAnchor:gsub("TOP", "Top "):gsub("BOTTOM", "Bottom "):gsub("LEFT", "Left"):gsub("RIGHT", "Right"):gsub("CENTER", "Center"))
    UIDropDownMenu_SetWidth(anchorDropdown, 150)
    yOffset = yOffset - 40
    
    -- Proc Glow checkbox
    local procGlow = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    procGlow:SetPoint("TOPLEFT", 20, yOffset)
    procGlow.Text:SetText("Show proc glow when abilities ready")
    procGlow:SetChecked(CDM.db.procGlow)
    procGlow:SetScript("OnClick", function(self)
        CDM.db.procGlow = self:GetChecked()
        CDM:Print("Proc glow", CDM.db.procGlow and "enabled" or "disabled")
    end)
    yOffset = yOffset - 50
    
    -- === ESSENTIAL COOLDOWNS ===
    local essentialHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    essentialHeader:SetPoint("TOPLEFT", 16, yOffset)
    essentialHeader:SetText("|cff33ff99Essential Cooldowns (Large Icons)|r")
    yOffset = yOffset - 30
    
    -- Essential Font Size slider
    local fontSizeSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    fontSizeSlider:SetPoint("TOPLEFT", 20, yOffset)
    fontSizeSlider:SetMinMaxValues(8, 24)
    fontSizeSlider:SetValue(CDM.db.hotkeyFontSize)
    fontSizeSlider:SetValueStep(1)
    fontSizeSlider:SetObeyStepOnDrag(true)
    fontSizeSlider.Text:SetText("Font Size: " .. CDM.db.hotkeyFontSize)
    fontSizeSlider:SetScript("OnValueChanged", function(self, value)
        CDM.db.hotkeyFontSize = value
        self.Text:SetText("Font Size: " .. value)
        if CDM.BlizzHooks then
            CDM.BlizzHooks:UpdateAllVisibleFrames()
        end
    end)
    yOffset = yOffset - 40
    
    -- Essential Border checkbox
    local essentialBorder = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    essentialBorder:SetPoint("TOPLEFT", 20, yOffset)
    essentialBorder.Text:SetText("Show black borders |cffff6600(requires /reload)|r")
    essentialBorder:SetChecked(CDM.db.cooldownManager.showBorder)
    essentialBorder:SetScript("OnClick", function(self)
        CDM.db.cooldownManager.showBorder = self:GetChecked()
        CDM:Print("Essential borders", CDM.db.cooldownManager.showBorder and "enabled" or "disabled")
    end)
    yOffset = yOffset - 30
    
    -- Essential Square checkbox
    local essentialSquare = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    essentialSquare:SetPoint("TOPLEFT", 20, yOffset)
    essentialSquare.Text:SetText("Square icons (uncropped) |cffff6600(requires /reload)|r")
    essentialSquare:SetChecked(CDM.db.cooldownManager.squareIcons)
    essentialSquare:SetScript("OnClick", function(self)
        CDM.db.cooldownManager.squareIcons = self:GetChecked()
        CDM:Print("Essential square icons", CDM.db.cooldownManager.squareIcons and "enabled" or "disabled")
    end)
    yOffset = yOffset - 50
    
    -- === UTILITY COOLDOWNS ===
    local utilityHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    utilityHeader:SetPoint("TOPLEFT", 16, yOffset)
    utilityHeader:SetText("|cff33ff99Utility Cooldowns (Small Icons)|r")
    yOffset = yOffset - 30
    
    -- Utility Font Size slider
    local utilityFontSizeSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    utilityFontSizeSlider:SetPoint("TOPLEFT", 20, yOffset)
    utilityFontSizeSlider:SetMinMaxValues(8, 24)
    utilityFontSizeSlider:SetValue(CDM.db.utilityFontSize or 12)
    utilityFontSizeSlider:SetValueStep(1)
    utilityFontSizeSlider:SetObeyStepOnDrag(true)
    utilityFontSizeSlider.Text:SetText("Font Size: " .. (CDM.db.utilityFontSize or 12))
    utilityFontSizeSlider:SetScript("OnValueChanged", function(self, value)
        CDM.db.utilityFontSize = value
        self.Text:SetText("Font Size: " .. value)
        if CDM.BlizzHooks then
            CDM.BlizzHooks:UpdateAllVisibleFrames()
        end
    end)
    yOffset = yOffset - 40
    
    -- Utility uses same borders/square as Essential (shared cooldownManager settings)
    local utilityNote = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    utilityNote:SetPoint("TOPLEFT", 20, yOffset)
    utilityNote:SetText("|cff888888(Borders and square icons shared with Essential above)|r")
    yOffset = yOffset - 50
    
    -- === TRINKET BAR SETTINGS ===
    local trinketHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    trinketHeader:SetPoint("TOPLEFT", 16, yOffset)
    trinketHeader:SetText("|cff33ff99Trinket Bar|r")
    yOffset = yOffset - 30
    
    -- Trinket Bar Enabled checkbox
    local trinketEnabled = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    trinketEnabled:SetPoint("TOPLEFT", 20, yOffset)
    trinketEnabled.Text:SetText("Enable trinket bar")
    trinketEnabled:SetChecked(CDM.db.trinketBar.enabled)
    trinketEnabled:SetScript("OnClick", function(self)
        CDM.db.trinketBar.enabled = self:GetChecked()
        CDM:Print("Trinket bar", CDM.db.trinketBar.enabled and "enabled" or "disabled")
        if CDM.TrinketBar and CDM.TrinketBar.frame then
            if CDM.db.trinketBar.enabled then
                CDM.TrinketBar:UpdateVisibility()
            else
                CDM.TrinketBar.frame:Hide()
            end
        end
    end)
    yOffset = yOffset - 30
    
    -- Visibility dropdown
    local visibilityLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    visibilityLabel:SetPoint("TOPLEFT", 20, yOffset)
    visibilityLabel:SetText("Visibility:")
    
    local visibilityDropdown = CreateFrame("Frame", "CDM_TrinketVisibilityDropdown", content, "UIDropDownMenuTemplate")
    visibilityDropdown:SetPoint("TOPLEFT", 80, yOffset + 3)
    
    local function SetVisibility(value)
        CDM.db.trinketBar.visibility = value
        UIDropDownMenu_SetText(visibilityDropdown, value)
        if CDM.TrinketBar then
            CDM.TrinketBar:UpdateVisibility()
        end
    end
    
    UIDropDownMenu_Initialize(visibilityDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        
        info.text = "  Always Show"
        info.value = "always"
        info.func = function() SetVisibility("always") end
        info.checked = (CDM.db.trinketBar.visibility == "always")
        UIDropDownMenu_AddButton(info)
        
        info.text = "  In Combat Only"
        info.value = "combat"
        info.func = function() SetVisibility("combat") end
        info.checked = (CDM.db.trinketBar.visibility == "combat")
        UIDropDownMenu_AddButton(info)
        
        info.text = "  Out of Combat Only"
        info.value = "noCombat"
        info.func = function() SetVisibility("noCombat") end
        info.checked = (CDM.db.trinketBar.visibility == "noCombat")
        UIDropDownMenu_AddButton(info)
    end)
    
    UIDropDownMenu_SetText(visibilityDropdown, CDM.db.trinketBar.visibility or "always")
    UIDropDownMenu_SetWidth(visibilityDropdown, 150)
    yOffset = yOffset - 40
    
    -- Trinket Font Size slider
    local trinketFontSizeSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    trinketFontSizeSlider:SetPoint("TOPLEFT", 20, yOffset)
    trinketFontSizeSlider:SetMinMaxValues(8, 20)
    trinketFontSizeSlider:SetValue(CDM.db.trinketBar.hotkeyFontSize or 12)
    trinketFontSizeSlider:SetValueStep(1)
    trinketFontSizeSlider:SetObeyStepOnDrag(true)
    trinketFontSizeSlider.Text:SetText("Font Size: " .. (CDM.db.trinketBar.hotkeyFontSize or 12))
    trinketFontSizeSlider:SetScript("OnValueChanged", function(self, value)
        CDM.db.trinketBar.hotkeyFontSize = value
        self.Text:SetText("Font Size: " .. value)
        if CDM.TrinketBar then
            CDM.TrinketBar:Update()
        end
    end)
    yOffset = yOffset - 40
    
    -- Trinket Border checkbox
    local trinketBorder = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    trinketBorder:SetPoint("TOPLEFT", 20, yOffset)
    trinketBorder.Text:SetText("Show black borders |cffff6600(requires /reload)|r")
    trinketBorder:SetChecked(CDM.db.trinketBar.showBorder)
    trinketBorder:SetScript("OnClick", function(self)
        CDM.db.trinketBar.showBorder = self:GetChecked()
        CDM:Print("Trinket borders", CDM.db.trinketBar.showBorder and "enabled" or "disabled")
    end)
    yOffset = yOffset - 30
    
    -- Trinket Square checkbox
    local trinketSquare = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    trinketSquare:SetPoint("TOPLEFT", 20, yOffset)
    trinketSquare.Text:SetText("Square icons (uncropped) |cffff6600(requires /reload)|r")
    trinketSquare:SetChecked(CDM.db.trinketBar.squareIcons)
    trinketSquare:SetScript("OnClick", function(self)
        CDM.db.trinketBar.squareIcons = self:GetChecked()
        CDM:Print("Trinket square icons", CDM.db.trinketBar.squareIcons and "enabled" or "disabled")
    end)
    yOffset = yOffset - 30
    
    -- Lock Position checkbox
    local trinketLocked = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    trinketLocked:SetPoint("TOPLEFT", 20, yOffset)
    trinketLocked.Text:SetText("Lock position (disable dragging)")
    trinketLocked:SetChecked(CDM.db.trinketBar.locked)
    trinketLocked:SetScript("OnClick", function(self)
        CDM.db.trinketBar.locked = self:GetChecked()
        print("|cff33ff99CDMx:|r Trinket bar", CDM.db.trinketBar.locked and "locked" or "unlocked")
        -- No UpdateLockState needed - trinket bar checks db.locked directly when dragging
    end)
    yOffset = yOffset - 30
    
    -- Icon Size slider
    local iconSizeSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    iconSizeSlider:SetPoint("TOPLEFT", 20, yOffset)
    iconSizeSlider:SetMinMaxValues(20, 80)
    iconSizeSlider:SetValue(CDM.db.trinketBar.iconSize)
    iconSizeSlider:SetValueStep(1)
    iconSizeSlider:SetObeyStepOnDrag(true)
    iconSizeSlider.Text:SetText("Icon Size: " .. CDM.db.trinketBar.iconSize)
    iconSizeSlider:SetScript("OnValueChanged", function(self, value)
        CDM.db.trinketBar.iconSize = value
        self.Text:SetText("Icon Size: " .. value)
        if CDM.TrinketBar then
            CDM.TrinketBar:Update()
        end
    end)
    yOffset = yOffset - 40
    
    -- Padding slider
    local paddingSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    paddingSlider:SetPoint("TOPLEFT", 20, yOffset)
    paddingSlider:SetMinMaxValues(0, 20)
    paddingSlider:SetValue(CDM.db.trinketBar.padding)
    paddingSlider:SetValueStep(1)
    paddingSlider:SetObeyStepOnDrag(true)
    paddingSlider.Text:SetText("Spacing: " .. CDM.db.trinketBar.padding)
    paddingSlider:SetScript("OnValueChanged", function(self, value)
        CDM.db.trinketBar.padding = value
        self.Text:SetText("Spacing: " .. value)
        if CDM.TrinketBar then
            CDM.TrinketBar:Update()
        end
    end)
    yOffset = yOffset - 40
    
    -- Layout toggle button
    local layoutButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    layoutButton:SetPoint("TOPLEFT", 20, yOffset)
    layoutButton:SetSize(150, 25)
    layoutButton:SetText(CDM.db.trinketBar.horizontal and "Horizontal" or "Vertical")
    layoutButton:SetScript("OnClick", function(self)
        CDM.db.trinketBar.horizontal = not CDM.db.trinketBar.horizontal
        self:SetText(CDM.db.trinketBar.horizontal and "Horizontal" or "Vertical")
        if CDM.TrinketBar then
            CDM.TrinketBar:Update()
        end
    end)
    yOffset = yOffset - 40
    
    -- === RELOAD BUTTON ===
    local reloadButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    reloadButton:SetPoint("TOPLEFT", 20, yOffset)
    reloadButton:SetSize(200, 30)
    reloadButton:SetText("Reload UI")
    reloadButton:SetScript("OnClick", function(self)
        ReloadUI()
    end)
    
    local reloadText = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    reloadText:SetPoint("LEFT", reloadButton, "RIGHT", 10, 0)
    reloadText:SetText("|cffff6600Required for icon styling changes|r")
    yOffset = yOffset - 50
    
    -- === CUSTOM BARS ===
    local customBarsHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    customBarsHeader:SetPoint("TOPLEFT", 16, yOffset)
    customBarsHeader:SetText("|cff33ff99Custom Bars|r")
    yOffset = yOffset - 30
    
    local customBarsText = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    customBarsText:SetPoint("TOPLEFT", 20, yOffset)
    customBarsText:SetText("Create custom tracking bars with spells/items from your action bars")
    yOffset = yOffset - 25
    
    -- Universal Lock/Unlock Toggle
    local lockAllCheckbox = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    lockAllCheckbox:SetPoint("TOPLEFT", 20, yOffset)
    lockAllCheckbox:SetSize(24, 24)
    
    -- Check if all bars are locked
    local allLocked = true
    if CDM.db.trinketBar then
        allLocked = allLocked and CDM.db.trinketBar.locked
    end
    for _, barSettings in pairs(CDM.db.customBars or {}) do
        allLocked = allLocked and barSettings.locked
    end
    lockAllCheckbox:SetChecked(allLocked)
    
    lockAllCheckbox:SetScript("OnClick", function(self)
        local locked = self:GetChecked()
        -- Lock/unlock trinket bar (no UpdateLockState method - it checks db directly)
        if CDM.db.trinketBar then
            CDM.db.trinketBar.locked = locked
        end
        -- Lock/unlock all custom bars
        for barName, _ in pairs(CDM.db.customBars or {}) do
            CDM.db.customBars[barName].locked = locked
            if CDM.CustomBars then
                CDM.CustomBars:UpdateLockState(barName)
            end
        end
        print("|cff33ff99CDMx:|r", locked and "All bars locked" or "All bars unlocked")
        print("|cff33ff99CDMx:|r", "Trinket bar will update on next interaction")
    end)
    
    local lockAllLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lockAllLabel:SetPoint("LEFT", lockAllCheckbox, "RIGHT", 5, 0)
    lockAllLabel:SetText("Lock All Bars (Trinket + Custom)")
    yOffset = yOffset - 35
    
    -- Add New Bar button
    local addBarButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    addBarButton:SetPoint("TOPLEFT", 20, yOffset)
    addBarButton:SetSize(150, 25)
    addBarButton:SetText("+ Add New Bar")
    addBarButton:SetScript("OnClick", function(self)
        -- Prompt for bar name
        StaticPopupDialogs["CDMX_NEW_BAR"] = {
            text = "Enter name for new custom bar:",
            button1 = "Create",
            button2 = "Cancel",
            hasEditBox = true,
            OnAccept = function(self, data)
                local editBox = self:GetParent().editBox or self.editBox or _G[self:GetName().."EditBox"]
                local name = editBox and editBox:GetText() or ""
                
                if name and name ~= "" then
                    if CDM.db.customBars[name] then
                        print("|cff33ff99CDMx:|r Bar '" .. name .. "' already exists!")
                    else
                        -- Create new bar with default settings
                        CDM.db.customBars[name] = {
                            enabled = true,
                            locked = false,
                            horizontal = true,
                            iconSize = 40,
                            padding = 5,
                            position = { point = "CENTER", x = 0, y = 0 },
                            squareIcons = CDM.db.customBarsStyle.squareIcons,  -- Use global setting
                            showBorder = CDM.db.customBarsStyle.showBorder,    -- Use global setting
                            hotkeyFontSize = 12,
                            hotkeyAnchor = "TOPLEFT",  -- Where hotkeys appear on icons
                            visibility = "always",
                            items = {},
                            numSlots = 5,  -- Default number of slots
                        }
                        print("|cff33ff99CDMx:|r Created custom bar:", name)
                        print("|cff33ff99CDMx:|r Type /reload to see your new bar")
                        print("|cff33ff99CDMx:|r Use /cdmx bar", name, "config to configure it")
                    end
                else
                    print("|cff33ff99CDMx:|r No name entered")
                end
            end,
            OnShow = function(self)
                local editBox = self:GetParent().editBox or self.editBox or _G[self:GetName().."EditBox"]
                if editBox then
                    editBox:SetFocus()
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("CDMX_NEW_BAR")
    end)
    yOffset = yOffset - 35
    
    -- Global Style Settings for All Custom Bars
    local styleHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    styleHeader:SetPoint("TOPLEFT", 20, yOffset)
    styleHeader:SetText("|cffFFD700Default Style:|r")
    yOffset = yOffset - 25
    
    -- Square Icons checkbox
    local squareCheckbox = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    squareCheckbox:SetPoint("TOPLEFT", 30, yOffset)
    squareCheckbox:SetSize(24, 24)
    squareCheckbox:SetChecked(CDM.db.customBarsStyle.squareIcons)
    squareCheckbox:SetScript("OnClick", function(self)
        CDM.db.customBarsStyle.squareIcons = self:GetChecked()
        -- Update all existing bars
        for barName, barSettings in pairs(CDM.db.customBars or {}) do
            barSettings.squareIcons = self:GetChecked()
            if CDM.CustomBars then
                CDM.CustomBars:UpdateLayout(barName)
                CDM.CustomBars:UpdateBar(barName)
            end
        end
    end)
    local squareLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    squareLabel:SetPoint("LEFT", squareCheckbox, "RIGHT", 5, 0)
    squareLabel:SetText("Square Icons")
    
    -- Show Border checkbox
    local borderCheckbox = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    borderCheckbox:SetPoint("LEFT", squareLabel, "RIGHT", 20, 0)
    borderCheckbox:SetSize(24, 24)
    borderCheckbox:SetChecked(CDM.db.customBarsStyle.showBorder)
    borderCheckbox:SetScript("OnClick", function(self)
        CDM.db.customBarsStyle.showBorder = self:GetChecked()
        -- Update all existing bars
        for barName, barSettings in pairs(CDM.db.customBars or {}) do
            barSettings.showBorder = self:GetChecked()
            if CDM.CustomBars then
                CDM.CustomBars:UpdateBar(barName)
            end
        end
    end)
    local borderLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    borderLabel:SetPoint("LEFT", borderCheckbox, "RIGHT", 5, 0)
    borderLabel:SetText("Show Border")
    yOffset = yOffset - 35
    
    -- Custom Bars Management
    local barListY = yOffset
    
    if CDM.db.customBars and next(CDM.db.customBars) then
        for barName, barSettings in pairs(CDM.db.customBars) do
            -- Bar name header
            local barHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            barHeader:SetPoint("TOPLEFT", 20, barListY)
            barHeader:SetText("|cffFFD700" .. barName .. "|r")
            barListY = barListY - 25
            
            -- Settings summary
            local settingsText = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            settingsText:SetPoint("TOPLEFT", 30, barListY)
            settingsText:SetText(string.format(
                "%s | %s",
                barSettings.horizontal and "Horizontal" or "Vertical",
                barSettings.locked and "|cff888888Locked|r" or "|cff00ff00Unlocked|r"
            ))
            barListY = barListY - 25
            
            -- Slots slider
            local slotsSliderName = "CDMx_Bar_" .. barName:gsub("%W", "") .. "_Slots"
            local slotsSlider = CreateFrame("Slider", slotsSliderName, content, "OptionsSliderTemplate")
            slotsSlider:SetPoint("TOPLEFT", 30, barListY)
            slotsSlider:SetMinMaxValues(1, 12)
            slotsSlider:SetValue(barSettings.numSlots or 5)
            slotsSlider:SetValueStep(1)
            slotsSlider:SetObeyStepOnDrag(true)
            slotsSlider:SetWidth(150)
            _G[slotsSliderName.."Low"]:SetText("1")
            _G[slotsSliderName.."High"]:SetText("12")
            _G[slotsSliderName.."Text"]:SetText("Slots: " .. (barSettings.numSlots or 5))
            slotsSlider:SetScript("OnValueChanged", function(self, value)
                barSettings.numSlots = value
                _G[slotsSliderName.."Text"]:SetText("Slots: " .. value)
                print("|cff33ff99CDMx:|r Bar '" .. barName .. "' slots set to " .. value .. " - /reload to apply")
            end)
            
            -- Icon Size slider
            local sizeSliderName = "CDMx_Bar_" .. barName:gsub("%W", "") .. "_Size"
            local sizeSlider = CreateFrame("Slider", sizeSliderName, content, "OptionsSliderTemplate")
            sizeSlider:SetPoint("LEFT", slotsSlider, "RIGHT", 20, 0)
            sizeSlider:SetMinMaxValues(20, 80)
            sizeSlider:SetValue(barSettings.iconSize or 40)
            sizeSlider:SetValueStep(1)
            sizeSlider:SetObeyStepOnDrag(true)
            sizeSlider:SetWidth(150)
            _G[sizeSliderName.."Low"]:SetText("20")
            _G[sizeSliderName.."High"]:SetText("80")
            _G[sizeSliderName.."Text"]:SetText("Icon Size: " .. (barSettings.iconSize or 40))
            sizeSlider:SetScript("OnValueChanged", function(self, value)
                barSettings.iconSize = value
                _G[sizeSliderName.."Text"]:SetText("Icon Size: " .. value)
                if CDM.CustomBars then
                    CDM.CustomBars:UpdateLayout(barName)
                    CDM.CustomBars:UpdateBar(barName)
                end
            end)
            
            barListY = barListY - 45
            
            -- Padding slider
            local paddingSliderName = "CDMx_Bar_" .. barName:gsub("%W", "") .. "_Padding"
            local paddingSlider = CreateFrame("Slider", paddingSliderName, content, "OptionsSliderTemplate")
            paddingSlider:SetPoint("TOPLEFT", 30, barListY)
            paddingSlider:SetMinMaxValues(0, 20)
            paddingSlider:SetValue(barSettings.padding or 5)
            paddingSlider:SetValueStep(1)
            paddingSlider:SetObeyStepOnDrag(true)
            paddingSlider:SetWidth(150)
            _G[paddingSliderName.."Low"]:SetText("0")
            _G[paddingSliderName.."High"]:SetText("20")
            _G[paddingSliderName.."Text"]:SetText("Padding: " .. (barSettings.padding or 5))
            paddingSlider:SetScript("OnValueChanged", function(self, value)
                barSettings.padding = value
                _G[paddingSliderName.."Text"]:SetText("Padding: " .. value)
                if CDM.CustomBars then
                    CDM.CustomBars:UpdateLayout(barName)
                    CDM.CustomBars:UpdateBar(barName)
                end
            end)
            
            barListY = barListY - 45
            
            -- Font Size slider
            local fontSliderName = "CDMx_Bar_" .. barName:gsub("%W", "") .. "_Font"
            local fontSlider = CreateFrame("Slider", fontSliderName, content, "OptionsSliderTemplate")
            fontSlider:SetPoint("TOPLEFT", 30, barListY)
            fontSlider:SetMinMaxValues(8, 24)
            fontSlider:SetValue(barSettings.hotkeyFontSize or 12)
            fontSlider:SetValueStep(1)
            fontSlider:SetObeyStepOnDrag(true)
            fontSlider:SetWidth(150)
            _G[fontSliderName.."Low"]:SetText("8")
            _G[fontSliderName.."High"]:SetText("24")
            _G[fontSliderName.."Text"]:SetText("Font Size: " .. (barSettings.hotkeyFontSize or 12))
            fontSlider:SetScript("OnValueChanged", function(self, value)
                barSettings.hotkeyFontSize = value
                _G[fontSliderName.."Text"]:SetText("Font Size: " .. value)
                if CDM.CustomBars then
                    CDM.CustomBars:UpdateBar(barName)
                end
            end)
            
            barListY = barListY - 45
            
            -- Buttons row
            local deleteBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
            deleteBtn:SetPoint("TOPLEFT", 30, barListY)
            deleteBtn:SetSize(60, 22)
            deleteBtn:SetText("Delete")
            local deleteName = barName
            deleteBtn:SetScript("OnClick", function()
                CDM.db.customBars[deleteName] = nil
                print("|cff33ff99CDMx:|r Deleted bar:", deleteName, "- /reload to apply")
            end)
            
            local lockBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
            lockBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 5, 0)
            lockBtn:SetSize(80, 22)
            lockBtn:SetText(barSettings.locked and "Unlock" or "Lock")
            local lockName = barName
            lockBtn:SetScript("OnClick", function()
                local s = CDM.db.customBars[lockName]
                if s then
                    s.locked = not s.locked
                    print("|cff33ff99CDMx:|r Bar", lockName, s.locked and "locked" or "unlocked")
                    if CDM.CustomBars then CDM.CustomBars:UpdateLockState(lockName) end
                end
            end)
            
            local layoutBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
            layoutBtn:SetPoint("LEFT", lockBtn, "RIGHT", 5, 0)
            layoutBtn:SetSize(100, 22)
            layoutBtn:SetText("Toggle Layout")
            local layoutName = barName
            layoutBtn:SetScript("OnClick", function()
                local s = CDM.db.customBars[layoutName]
                if s then
                    s.horizontal = not s.horizontal
                    print("|cff33ff99CDMx:|r Bar", layoutName, "layout:", s.horizontal and "horizontal" or "vertical")
                    if CDM.CustomBars then
                        CDM.CustomBars:UpdateLayout(layoutName)
                        CDM.CustomBars:UpdateBar(layoutName)
                    end
                end
            end)
            
            local editItemsBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
            editItemsBtn:SetPoint("LEFT", layoutBtn, "RIGHT", 5, 0)
            editItemsBtn:SetSize(80, 22)
            editItemsBtn:SetText("Edit Items")
            local editBarName = barName
            editItemsBtn:SetScript("OnClick", function()
                CDM.Config:ShowItemPicker(editBarName)
            end)
            
            barListY = barListY - 30
            
            local cmdText = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            cmdText:SetPoint("TOPLEFT", 30, barListY)
            cmdText:SetText("|cff888888Commands: /cdmx bar " .. barName .. " [slots|size|font] <value>|r")
            barListY = barListY - 30
        end
    else
        local noBarsText = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        noBarsText:SetPoint("TOPLEFT", 20, barListY)
        noBarsText:SetText("|cff888888No custom bars created yet|r")
        barListY = barListY - 25
    end
    
    yOffset = barListY - 10
    
    local manageText = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    manageText:SetPoint("TOPLEFT", 20, yOffset)
    manageText:SetText("|cffff6600To manage bars: Use /cdmx bar <name> <command>|r\n" ..
                       "Commands: enable, disable, lock, unlock, layout, delete")
    
    -- Register with Blizzard Interface Options
    if Settings and Settings.RegisterCanvasLayoutCategory then
        -- 11.0+ API
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        -- Pre-11.0 API
        InterfaceOptions_AddCategory(panel)
    end
    
    return panel
end

-- Show Item Picker popup for a custom bar
function Config:ShowItemPicker(barName)
    local barSettings = CDM.db.customBars[barName]
    if not barSettings then
        print("|cff33ff99CDMx:|r Bar not found:", barName)
        return
    end
    
    -- Scan action bars for all spells and items
    local availableItems = {}
    local seenIDs = {}
    
    -- Scan action buttons (uses same logic as HotkeyDetection)
    local actionBars = {
        {prefix = "ActionButton", count = 12},           -- Main bar
        {prefix = "MultiBarBottomLeftButton", count = 12},
        {prefix = "MultiBarBottomRightButton", count = 12},
        {prefix = "MultiBarRightButton", count = 12},
        {prefix = "MultiBarLeftButton", count = 12},
        {prefix = "MultiBar5Button", count = 12},
        {prefix = "MultiBar6Button", count = 12},
        {prefix = "MultiBar7Button", count = 12},
    }
    
    for _, bar in ipairs(actionBars) do
        for i = 1, bar.count do
            local button = _G[bar.prefix .. i]
            if button then
                local actionType, id = GetActionInfo(button.action)
                if actionType == "spell" and id then
                    local spellName = C_Spell.GetSpellName(id)
                    local spellTexture = C_Spell.GetSpellTexture(id)
                    if spellName and not seenIDs["spell:" .. id] then
                        table.insert(availableItems, {
                            type = "spell",
                            id = id,
                            name = spellName,
                            texture = spellTexture,
                        })
                        seenIDs["spell:" .. id] = true
                    end
                elseif actionType == "item" and id then
                    local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(id)
                    if itemName and not seenIDs["item:" .. id] then
                        table.insert(availableItems, {
                            type = "item",
                            id = id,
                            name = itemName,
                            texture = itemTexture,
                        })
                        seenIDs["item:" .. id] = true
                    end
                end
            end
        end
    end
    
    -- Sort alphabetically
    table.sort(availableItems, function(a, b) return a.name < b.name end)
    
    -- Create popup frame
    local picker = CreateFrame("Frame", "CDMx_ItemPicker", UIParent, "BasicFrameTemplateWithInset")
    picker:SetSize(400, 500)
    picker:SetPoint("CENTER")
    picker:SetFrameStrata("DIALOG")
    picker:EnableMouse(true)
    picker:SetMovable(true)
    picker:RegisterForDrag("LeftButton")
    picker:SetScript("OnDragStart", picker.StartMoving)
    picker:SetScript("OnDragStop", picker.StopMovingOrSizing)
    
    -- Title
    picker.title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    picker.title:SetPoint("TOP", 0, -5)
    picker.title:SetText("Edit Items: " .. barName)
    
    -- Instructions
    local instructions = picker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    instructions:SetPoint("TOPLEFT", 15, -30)
    instructions:SetText("Select spells/items to display on this bar:")
    
    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 45)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(360, 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    -- Build existing items lookup
    local selectedItems = {}
    for _, item in ipairs(barSettings.items or {}) do
        selectedItems[item.type .. ":" .. item.id] = true
    end
    
    -- Create checkboxes
    local checkboxes = {}
    local yOffset = -5
    
    for i, item in ipairs(availableItems) do
        local checkbox = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", 10, yOffset)
        checkbox:SetSize(24, 24)
        checkbox:SetChecked(selectedItems[item.type .. ":" .. item.id])
        checkbox.itemData = item
        table.insert(checkboxes, checkbox)
        
        -- Icon
        local icon = scrollChild:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
        icon:SetSize(24, 24)
        icon:SetTexture(item.texture)
        
        -- Name
        local label = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        label:SetText(item.name)
        
        yOffset = yOffset - 30
    end
    
    -- Adjust scroll child height
    scrollChild:SetHeight(math.abs(yOffset))
    
    -- Save button
    local saveBtn = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
    saveBtn:SetPoint("BOTTOMLEFT", 15, 10)
    saveBtn:SetSize(100, 25)
    saveBtn:SetText("Save")
    saveBtn:SetScript("OnClick", function()
        -- Collect selected items
        barSettings.items = {}
        for _, cb in ipairs(checkboxes) do
            if cb:GetChecked() then
                table.insert(barSettings.items, {
                    type = cb.itemData.type,
                    id = cb.itemData.id,
                })
            end
        end
        print("|cff33ff99CDMx:|r Saved " .. #barSettings.items .. " items to bar '" .. barName .. "'")
        print("|cff33ff99CDMx:|r /reload to see changes")
        picker:Hide()
    end)
    
    -- Cancel button
    local cancelBtn = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
    cancelBtn:SetPoint("LEFT", saveBtn, "RIGHT", 10, 0)
    cancelBtn:SetSize(100, 25)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function()
        picker:Hide()
    end)
    
    -- Select All button
    local selectAllBtn = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
    selectAllBtn:SetPoint("BOTTOMRIGHT", -15, 10)
    selectAllBtn:SetSize(100, 25)
    selectAllBtn:SetText("Select All")
    selectAllBtn:SetScript("OnClick", function()
        for _, cb in ipairs(checkboxes) do
            cb:SetChecked(true)
        end
    end)
    
    -- Clear All button
    local clearAllBtn = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
    clearAllBtn:SetPoint("RIGHT", selectAllBtn, "LEFT", -10, 0)
    clearAllBtn:SetSize(100, 25)
    clearAllBtn:SetText("Clear All")
    clearAllBtn:SetScript("OnClick", function()
        for _, cb in ipairs(checkboxes) do
            cb:SetChecked(false)
        end
    end)
    
    picker:Show()
end

-- Initialize config panel on load
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == ADDON_NAME then
        Config:CreatePanel()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
