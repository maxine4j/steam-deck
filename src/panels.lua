-- SteamDeck Panel Module
-- Generic panel system that supports left/right positioning and tabs

SteamDeckPanels = {}

-- Configuration
local FRAME_PADDING = 20
local TITLE_HEIGHT = 40
local TAB_HEIGHT = 35
local TAB_SPACING = 4
local TAB_PADDING = 8
local TAB_BORDER_THICKNESS = 2
local DEFAULT_WIDTH = 600

-- Create a panel frame (constructor - returns a new panel instance)
-- side: "left" or "right"
-- width: Panel width (optional, tabs can override)
-- tabs: Table of tab modules to register
function SteamDeckPanels:CreatePanel(panelId, side, width, tabs)
    -- Create a new panel instance
    local panel = {}
    -- Set metatable so this instance inherits all methods from SteamDeckPanels
    setmetatable(panel, { __index = SteamDeckPanels })
    
    -- Now initialize this new instance
    panel.frame = CreateFrame("Frame", "SteamDeckPanel"..panelId, UIParent)
    panel.frame:Hide()

    -- Set width if provided, otherwise use default
    if width then
        panel.frame:SetWidth(width)
    else
        panel.frame:SetWidth(DEFAULT_WIDTH)
    end

    -- Anchor based on side
    if side:lower() == "left" then
        panel.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        panel.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    elseif side:lower() == "right" then
        panel.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
        panel.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    else
        error("Panel side must be 'left' or 'right'")
    end

    -- Set strata
    panel.frame:SetFrameStrata("HIGH")
    panel.frame:SetFrameLevel(100)

    -- Configure mouse and keyboard interactions
    panel.frame:EnableMouse(true)
    panel.frame:EnableKeyboard(false)
    panel.frame:SetMovable(false)

    -- Background
    local bg = panel.frame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", panel.frame, "TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMLEFT", panel.frame, "BOTTOMLEFT", 0, 0)
    bg:SetPoint("RIGHT", panel.frame, "RIGHT", 0, 0)
    bg:SetColorTexture(0, 0, 0, 0.8)

    -- Create tab container
    local tabContainer = CreateFrame("Frame", nil, panel.frame)
    tabContainer:SetHeight(TAB_HEIGHT)
    tabContainer:SetPoint("TOPLEFT", panel.frame, "TOPLEFT", 0, -TITLE_HEIGHT)
    tabContainer:SetPoint("TOPRIGHT", panel.frame, "TOPRIGHT", 0, -TITLE_HEIGHT)
    panel.frame.tabsContainer = tabContainer

    -- Content container (where tab content goes)
    local contentContainer = CreateFrame("Frame", nil, panel.frame)
    contentContainer:SetPoint("TOPLEFT", tabContainer, "BOTTOMLEFT", 0, 0)
    contentContainer:SetPoint("BOTTOMLEFT", panel.frame, "BOTTOMLEFT", 0, FRAME_PADDING)
    contentContainer:SetPoint("RIGHT", panel.frame, "RIGHT", -FRAME_PADDING, 0)
    panel.frame.contentContainer = contentContainer

    -- Panel state
    panel.panelId = panelId
    panel.side = side
    panel.tabs = {}
    panel.activeTabId = nil
    panel.lastTabOrder = 0  -- Counter to track tab registration order

    for _, tabModule in ipairs(tabs) do
        panel:RegisterTab(tabModule)
    end

    return panel
end

-- Add a tab to a panel
-- tabModule: The tab module object (must have id, name, Initialize, OnShow, OnHide methods)
function SteamDeckPanels:RegisterTab(tabModule)
    -- Create tab button
    local tabButton = CreateFrame("Button", nil, self.frame.tabsContainer)
    tabButton:SetHeight(TAB_HEIGHT)

    -- Create tab text (will be updated after Initialize)
    local text = tabButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER", tabButton, "CENTER", 0, 0)
    text:SetTextColor(1, 1, 1, 1) -- White text
    tabButton.text = text

    -- Tab background (inactive state)
    local bg = tabButton:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(tabButton)
    bg:SetColorTexture(0.15, 0.15, 0.15, 0.7)
    tabButton.bg = bg

    -- Tab border (inactive state)
    local borderColor = {0.3, 0.3, 0.3, 0.8}
    
    local borderTop = tabButton:CreateTexture(nil, "BORDER")
    borderTop:SetPoint("TOPLEFT", tabButton, "TOPLEFT", 0, 0)
    borderTop:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    local borderBottom = tabButton:CreateTexture(nil, "BORDER")
    borderBottom:SetPoint("BOTTOMLEFT", tabButton, "BOTTOMLEFT", 0, 0)
    borderBottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    local borderLeft = tabButton:CreateTexture(nil, "BORDER")
    borderLeft:SetSize(TAB_BORDER_THICKNESS, TAB_HEIGHT)
    borderLeft:SetPoint("TOPLEFT", tabButton, "TOPLEFT", 0, 0)
    borderLeft:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    local borderRight = tabButton:CreateTexture(nil, "BORDER")
    borderRight:SetSize(TAB_BORDER_THICKNESS, TAB_HEIGHT)
    borderRight:SetPoint("TOPRIGHT", tabButton, "TOPRIGHT", 0, 0)
    borderRight:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    tabButton.borders = {top = borderTop, bottom = borderBottom, left = borderLeft, right = borderRight}

    -- Create content frame for this tab
    local contentFrame = CreateFrame("Frame", nil, self.frame.contentContainer)
    contentFrame:SetAllPoints(self.frame.contentContainer)
    contentFrame:Hide()

    -- Initialize tab module - pass panel and content frame
    tabModule:Initialize(self, contentFrame)
    
    -- Tab click handler (set after we have tabId)
    tabButton:SetScript("OnClick", function()
        self:SetActiveTab(tabModule.tabId)
    end)

    -- Update tab button text with actual name/id after Initialize
    local tabText = tabModule.name
    tabButton.text:SetText(tabText)
    -- Recalculate width if text changed
    local width = tabButton.text:GetStringWidth() + (TAB_PADDING * 2)
    tabButton:SetWidth(width)
    tabButton.borders.top:SetSize(width, TAB_BORDER_THICKNESS)
    tabButton.borders.bottom:SetSize(width, TAB_BORDER_THICKNESS)

    -- Increment order counter before storing
    self.lastTabOrder = self.lastTabOrder + 1
    
    self.tabs[tabModule.tabId] = {
        order = self.lastTabOrder,
        tabId = tabModule.tabId,
        module = tabModule,
        button = tabButton,
        content = contentFrame,
    }
    
    -- Reposition tabs after storing
    self:RepositionTabButtons()
end

function SteamDeckPanels:RepositionTabButtons()
    -- Collect all tab data into an array and sort by order
    local tabDataArray = {}
    for _, tabData in pairs(self.tabs) do
        if tabData.button then
            table.insert(tabDataArray, tabData)
        end
    end
    
    -- Sort by order
    table.sort(tabDataArray, function(a, b) return a.order < b.order end)
    
    -- Extract buttons in sorted order
    local tabButtons = {}
    for _, tabData in ipairs(tabDataArray) do
        table.insert(tabButtons, tabData.button)
    end
    
    -- If no tabs, return early
    if #tabButtons == 0 then
        return
    end
    
    -- Calculate total width of all tabs
    local totalTabWidth = 0
    for i, tabButton in ipairs(tabButtons) do
        if i > 1 then
            totalTabWidth = totalTabWidth + TAB_SPACING
        end
        totalTabWidth = totalTabWidth + tabButton:GetWidth()
    end
    
    -- Center tabs within the container
    local containerWidth = self.frame.tabsContainer:GetWidth()
    if containerWidth <= 0 then
        containerWidth = self.frame:GetWidth()
    end
    local startX = (containerWidth - totalTabWidth) / 2
    
    -- Position first tab
    tabButtons[1]:ClearAllPoints()
    tabButtons[1]:SetPoint("TOPLEFT", self.frame.tabsContainer, "TOPLEFT", startX, 0)
    
    -- Position subsequent tabs
    for i = 2, #tabButtons do
        tabButtons[i]:ClearAllPoints()
        tabButtons[i]:SetPoint("TOPLEFT", tabButtons[i - 1], "TOPRIGHT", TAB_SPACING, 0)
    end
end

function SteamDeckPanels:SetActiveTab(tabId)
    -- First, hide ALL tab content frames and call OnHide for all tabs
    for _, tab in pairs(self.tabs) do
        if tab.content and tab.content:IsShown() then
            -- Update tab button appearance (inactive)
            tab.button.bg:SetColorTexture(0.15, 0.15, 0.15, 0.7)
            for _, border in pairs(tab.button.borders) do
                border:SetColorTexture(0.3, 0.3, 0.3, 0.8)
            end
            -- Hide the tab
            tab.content:Hide()
            tab.module:OnHide()
            -- Deactivate cursor for this tab
            if SteamDeckInterfaceCursorModule then
                SteamDeckInterfaceCursorModule:Deactivate()
            end
        end
    end

    -- Set up the new active tab
    local tab = self.tabs[tabId]
    if not tab then
        error("Tab with id '" .. tostring(tabId) .. "' not found")
        return
    end

    self.activeTabId = tabId

    -- Update tab button appearance (active)
    tab.button.bg:SetColorTexture(0.25, 0.25, 0.25, 0.9)
    local borderColor = {0.5, 0.5, 0.5, 1.0}
    for _, border in pairs(tab.button.borders) do
        border:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    end

    -- Show the tab
    tab.module:OnShow()
    tab.content:Show()
    
    -- Activate cursor for the active tab (if tab supports navigation)
    if SteamDeckInterfaceCursorModule and tab.module.GetNavGrid then
        SteamDeckInterfaceCursorModule:Activate(tab.module)
    end
end

function SteamDeckPanels:OpenPanel()
    self.frame:Show()
    self:RepositionTabButtons()
    
    -- Activate cursor for active tab if panel is opened
    if self.activeTabId then
        local tab = self.tabs[self.activeTabId]
        if tab and tab.module and tab.module.GetNavGrid and SteamDeckInterfaceCursorModule then
            SteamDeckInterfaceCursorModule:Activate(tab.module)
        end
    end
end

function SteamDeckPanels:OpenPanelToTab(tabId)
    self:SetActiveTab(tabId)
    self:OpenPanel()
end

function SteamDeckPanels:ClosePanel()
    -- Deactivate cursor when panel closes
    if SteamDeckInterfaceCursorModule then
        SteamDeckInterfaceCursorModule:Deactivate()
    end
    self.frame:Hide()
end

function SteamDeckPanels:TogglePanel()
    if self.frame:IsShown() then
        self:ClosePanel()
    else
        self:OpenPanel()
    end
end

function SteamDeckPanels:IsPanelOpen()
    return self.frame:IsShown() or false
end

return SteamDeckPanels

