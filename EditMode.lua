--[[
    CDMx - EditMode.lua
    Hooks into Blizzard's Edit Mode to show movable overlays for
    all CDMx bars (trinket bar + custom bars).
    
    When Edit Mode is opened:
      - Colored mover overlays appear on top of each CDMx bar
      - Bars become visible regardless of combat/visibility settings
      - Bars become draggable regardless of lock state
      - Mover shows bar name label
    
    When Edit Mode is closed:
      - Movers hide
      - Bars return to their normal visibility/lock behavior
      - Positions are saved
    
    This avoids the taint issues that come from trying to register
    custom systems with EditModeManagerFrame directly.
    
    Author: Juicetheforce (with Claude assistance)
    Target: WoW 12.0.x (Midnight)
]]--

local ADDON_NAME, CDM = ...

CDM.EditMode = {}
local EditMode = CDM.EditMode

-- Track whether we're currently in Edit Mode
EditMode.active = false

-- Mover frames keyed by bar identifier
EditMode.movers = {}

-- Store original state to restore when exiting Edit Mode
EditMode.savedState = {}

--============================================================================
-- MOVER FRAME CREATION
--============================================================================

-- Accent color for CDMx movers (distinguishes from Blizzard's blue)
local MOVER_COLOR = { r = 0.2, g = 0.8, b = 0.4, a = 0.15 }      -- Very subtle green tint
local MOVER_BORDER_COLOR = { r = 0.2, g = 1.0, b = 0.4, a = 0.9 } -- Bright green border
local MOVER_LABEL_COLOR = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }  -- White text

--[[
    Create a mover overlay frame for a CDMx bar.
    The mover sits on top of the bar and handles dragging.
    
    @param barID    string - Unique identifier for this bar
    @param barFrame Frame  - The actual CDMx bar frame to overlay
    @param label    string - Display name shown on the mover
    @param settings table  - Bar settings table (must have .position and .locked)
    @return mover   Frame
]]--
function EditMode:CreateMover(barID, barFrame, label, settings)
    if self.movers[barID] then
        return self.movers[barID]
    end
    
    local mover = CreateFrame("Frame", "CDMx_Mover_" .. barID, UIParent)
    mover:SetFrameStrata("DIALOG")  -- Above everything
    mover:SetClampedToScreen(true)
    
    -- Background fill
    mover.bg = mover:CreateTexture(nil, "BACKGROUND")
    mover.bg:SetAllPoints()
    mover.bg:SetColorTexture(MOVER_COLOR.r, MOVER_COLOR.g, MOVER_COLOR.b, MOVER_COLOR.a)
    
    -- Border (1px lines on each edge)
    local borderSize = 2
    
    mover.borderTop = mover:CreateTexture(nil, "ARTWORK")
    mover.borderTop:SetColorTexture(MOVER_BORDER_COLOR.r, MOVER_BORDER_COLOR.g, MOVER_BORDER_COLOR.b, MOVER_BORDER_COLOR.a)
    mover.borderTop:SetPoint("TOPLEFT", mover, "TOPLEFT", 0, 0)
    mover.borderTop:SetPoint("TOPRIGHT", mover, "TOPRIGHT", 0, 0)
    mover.borderTop:SetHeight(borderSize)
    
    mover.borderBottom = mover:CreateTexture(nil, "ARTWORK")
    mover.borderBottom:SetColorTexture(MOVER_BORDER_COLOR.r, MOVER_BORDER_COLOR.g, MOVER_BORDER_COLOR.b, MOVER_BORDER_COLOR.a)
    mover.borderBottom:SetPoint("BOTTOMLEFT", mover, "BOTTOMLEFT", 0, 0)
    mover.borderBottom:SetPoint("BOTTOMRIGHT", mover, "BOTTOMRIGHT", 0, 0)
    mover.borderBottom:SetHeight(borderSize)
    
    mover.borderLeft = mover:CreateTexture(nil, "ARTWORK")
    mover.borderLeft:SetColorTexture(MOVER_BORDER_COLOR.r, MOVER_BORDER_COLOR.g, MOVER_BORDER_COLOR.b, MOVER_BORDER_COLOR.a)
    mover.borderLeft:SetPoint("TOPLEFT", mover, "TOPLEFT", 0, 0)
    mover.borderLeft:SetPoint("BOTTOMLEFT", mover, "BOTTOMLEFT", 0, 0)
    mover.borderLeft:SetWidth(borderSize)
    
    mover.borderRight = mover:CreateTexture(nil, "ARTWORK")
    mover.borderRight:SetColorTexture(MOVER_BORDER_COLOR.r, MOVER_BORDER_COLOR.g, MOVER_BORDER_COLOR.b, MOVER_BORDER_COLOR.a)
    mover.borderRight:SetPoint("TOPRIGHT", mover, "TOPRIGHT", 0, 0)
    mover.borderRight:SetPoint("BOTTOMRIGHT", mover, "BOTTOMRIGHT", 0, 0)
    mover.borderRight:SetWidth(borderSize)
    
    -- Label
    mover.label = mover:CreateFontString(nil, "OVERLAY")
    mover.label:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    mover.label:SetPoint("CENTER", mover, "CENTER", 0, 0)
    mover.label:SetTextColor(MOVER_LABEL_COLOR.r, MOVER_LABEL_COLOR.g, MOVER_LABEL_COLOR.b, MOVER_LABEL_COLOR.a)
    mover.label:SetText("CDMx: " .. label)
    
    -- "CDMx" badge in corner
    mover.badge = mover:CreateFontString(nil, "OVERLAY")
    mover.badge:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    mover.badge:SetPoint("BOTTOMRIGHT", mover, "BOTTOMRIGHT", -3, 3)
    mover.badge:SetTextColor(0.5, 1.0, 0.5, 0.7)
    mover.badge:SetText("CDMx")
    
    -- Drag support
    mover:SetMovable(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    
    -- Store references
    mover._barFrame = barFrame
    mover._barSettings = settings
    mover._barID = barID
    
    mover:SetScript("OnDragStart", function(self)
        self:StartMoving()
        -- Real-time: bar follows mover during drag
        self._dragging = true
        self:SetScript("OnUpdate", function(self)
            if not self._dragging then return end
            local bf = self._barFrame
            if bf then
                local point, _, _, x, y = self:GetPoint()
                if point then
                    bf:ClearAllPoints()
                    bf:SetPoint(point, UIParent, point, x, y)
                end
            end
        end)
    end)
    
    mover:SetScript("OnDragStop", function(self)
        self._dragging = false
        self:SetScript("OnUpdate", nil)
        self:StopMovingOrSizing()
        
        -- Save final position
        local point, _, _, x, y = self:GetPoint()
        local s = self._barSettings
        local bf = self._barFrame
        
        -- For centered bars, convert position to CENTER-relative
        -- so the bar grows symmetrically when icons are added/removed
        if s and s.centered ~= false and bf then
            local cx, cy = bf:GetCenter()
            local ux, uy = UIParent:GetCenter()
            if cx and ux then
                point = "CENTER"
                x = math.floor(cx - ux)
                y = math.floor(cy - uy)
            end
        end
        
        if s then
            s.position = {
                point = point,
                x = math.floor(x),
                y = math.floor(y),
            }
        end
        
        -- Snap bar to final position
        if bf then
            bf:ClearAllPoints()
            bf:SetPoint(point, UIParent, point, math.floor(x), math.floor(y))
        end
    end)
    
    -- Tooltip on hover
    mover:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("CDMx: " .. label, 0.2, 1.0, 0.4)
        GameTooltip:AddLine("Drag to reposition", 1, 1, 1)
        GameTooltip:AddLine("Close Edit Mode to lock", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    
    mover:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    mover:Hide()
    
    self.movers[barID] = mover
    return mover
end

--[[
    Position and size a mover to match its bar frame.
]]--
function EditMode:SyncMoverToBar(barID)
    local mover = self.movers[barID]
    if not mover or not mover._barFrame then return end
    
    local barFrame = mover._barFrame
    
    -- Match size (with minimum so empty bars are still clickable)
    local w = math.max(barFrame:GetWidth() or 60, 60)
    local h = math.max(barFrame:GetHeight() or 30, 30)
    mover:SetSize(w, h)
    
    -- Match position
    mover:ClearAllPoints()
    local point, _, _, x, y = barFrame:GetPoint()
    if point then
        mover:SetPoint(point, UIParent, point, x, y)
    else
        mover:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

--============================================================================
-- ENTER / EXIT EDIT MODE
--============================================================================

--[[
    Called when Blizzard Edit Mode is entered.
    Shows mover overlays on all CDMx bars.
]]--
function EditMode:OnEnterEditMode()
    if self.active then return end
    self.active = true
    
    if CDM.debug then
        CDM:Print("Edit Mode entered - showing CDMx movers")
    end
    
    -- Save current state and show movers for Trinket Bar
    if CDM.TrinketBar and CDM.TrinketBar.frame then
        local settings = CDM.db.trinketBar
        local barFrame = CDM.TrinketBar.frame
        
        -- Save original visibility/lock state
        self.savedState["trinket"] = {
            wasShown = barFrame:IsShown(),
            wasLocked = settings.locked,
        }
        
        -- Force bar visible during Edit Mode
        barFrame:Show()
        
        -- Create/update mover
        local mover = self:CreateMover("trinket", barFrame, "Trinket Bar", settings)
        self:SyncMoverToBar("trinket")
        mover:Show()
    end
    
    -- Show movers for all Custom Bars
    if CDM.CustomBars and CDM.db.customBars then
        for barName, barSettings in pairs(CDM.db.customBars) do
            local barFrame = CDM.CustomBars.bars[barName]
            if barFrame then
                local barID = "custom_" .. barName
                
                -- Save original state
                self.savedState[barID] = {
                    wasShown = barFrame:IsShown(),
                    wasLocked = barSettings.locked,
                }
                
                -- Force bar visible
                barFrame:Show()
                
                -- Create/update mover
                local mover = self:CreateMover(barID, barFrame, barName, barSettings)
                self:SyncMoverToBar(barID)
                mover:Show()
            end
        end
    end
end

--[[
    Called when Blizzard Edit Mode is exited.
    Hides all movers and restores bar state.
]]--
function EditMode:OnExitEditMode()
    if not self.active then return end
    self.active = false
    
    if CDM.debug then
        CDM:Print("Edit Mode exited - hiding CDMx movers")
    end
    
    -- Hide all movers
    for barID, mover in pairs(self.movers) do
        mover:Hide()
    end
    
    -- Restore Trinket Bar state
    if CDM.TrinketBar and CDM.TrinketBar.frame then
        local saved = self.savedState["trinket"]
        if saved then
            -- Restore position from settings (mover may have updated it)
            local settings = CDM.db.trinketBar
            local barFrame = CDM.TrinketBar.frame
            barFrame:ClearAllPoints()
            local pos = settings.position
            barFrame:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER",
                            pos.x or 0, pos.y or 0)
        end
        
        -- Let normal visibility logic take over
        CDM.TrinketBar:UpdateVisibility()
    end
    
    -- Restore Custom Bar state
    if CDM.CustomBars and CDM.db.customBars then
        for barName, barSettings in pairs(CDM.db.customBars) do
            local barFrame = CDM.CustomBars.bars[barName]
            if barFrame then
                -- Restore position
                barFrame:ClearAllPoints()
                local pos = barSettings.position
                barFrame:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER",
                                pos.x or 0, pos.y or 0)
                
                -- Let normal visibility/lock take over
                CDM.CustomBars:UpdateVisibility(barName)
            end
        end
    end
    
    -- Clear saved state
    wipe(self.savedState)
end

--============================================================================
-- INITIALIZATION & HOOKS
--============================================================================

function EditMode:Initialize()
    -- Wait for EditModeManagerFrame to exist
    if not EditModeManagerFrame then
        if CDM.debug then
            CDM:Print("EditModeManagerFrame not found - Edit Mode hooks skipped")
        end
        return
    end
    
    -- Hook Enter/Exit Edit Mode
    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
        -- Small delay to let Blizzard's Edit Mode finish setting up
        C_Timer.After(0.1, function()
            EditMode:OnEnterEditMode()
        end)
    end)
    
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
        EditMode:OnExitEditMode()
    end)
    
    -- Also hook the Hide event (Edit Mode can be closed by pressing Escape)
    EditModeManagerFrame:HookScript("OnHide", function()
        if EditMode.active then
            EditMode:OnExitEditMode()
        end
    end)
    
    if CDM.debug then
        CDM:Print("Edit Mode hooks installed")
    end
end

-- Initialize after login (bars need to exist first)
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    -- Delay to ensure bars are created first
    C_Timer.After(3, function()
        EditMode:Initialize()
    end)
end)

--============================================================================
-- SLASH COMMAND (for testing)
--============================================================================

SLASH_CDMXEDIT1 = "/cdmxedit"
SlashCmdList["CDMXEDIT"] = function()
    if EditMode.active then
        CDM:Msg("Edit Mode movers are currently |cff00ff00active|r")
        local count = 0
        for barID, _ in pairs(EditMode.movers) do
            count = count + 1
        end
        CDM:Msg("Tracking " .. count .. " mover(s)")
    else
        CDM:Msg("Edit Mode movers are currently |cffff0000inactive|r")
        CDM:Msg("Open Edit Mode (ESC menu) to see CDMx movers")
    end
end
