-- SteamDeck Character Module
-- Replaces default character frame with a custom left-side paper doll

SteamDeckCharacterModule = {}
local CharacterModule = SteamDeckCharacterModule

-- Tab modules will be loaded from TOC and available as globals
local EquipmentTab = SteamDeckCharacterEquipmentTab or {}
local ReputationTab = SteamDeckCharacterReputationTab or {}
local CurrenciesTab = SteamDeckCharacterCurrenciesTab or {}

-- Module state
local characterFrame = nil
local isOpen = false
local activeTab = "Equipment"  -- Current active tab

-- Expose characterFrame getter for tab modules
function CharacterModule:GetCharacterFrame()
    return characterFrame
end

-- Configuration (shared constants)
local FRAME_PADDING = 20
local TITLE_HEIGHT = 40  -- Space for title at top
local TAB_HEIGHT = 35  -- Height of tab buttons
local TAB_SPACING = 4  -- Spacing between tabs
local TAB_PADDING = 8  -- Horizontal padding inside tabs

-- Helper function to remove trailing zeros from decimal strings
-- Handles patterns like "100.0k" -> "100k", "34.0%" -> "34%", "123.50g" -> "123.5g"
local function RemoveTrailingZeros(str)
    -- Remove ".0" or ".00" etc. before suffix (k, g, %) or at end of string
    -- First handle suffixes, then handle end of string
    str = str:gsub("%.0+([kg%%])", "%1")  -- Remove ".0" or ".00" before k, g, or %
    str = str:gsub("%.0+$", "")  -- Remove ".0" or ".00" at end of string
    return str
end

-- Helper function for formatting large numbers with k/g suffixes (3 significant figures)
local function FormatNumber(value)
    value = math.floor(value + 0.5)  -- Round to nearest integer
    
    if value >= 1000000000 then
        -- Billions (g)
        local billions = value / 1000000000
        local formatted
        if billions >= 100 then
            formatted = string.format("%.0fg", billions)
        elseif billions >= 10 then
            formatted = string.format("%.1fg", billions)
        else
            formatted = string.format("%.2fg", billions)
        end
        return RemoveTrailingZeros(formatted)
    elseif value >= 1000000 then
        -- Millions (g)
        local millions = value / 1000000
        local formatted
        if millions >= 100 then
            formatted = string.format("%.0fg", millions)
        elseif millions >= 10 then
            formatted = string.format("%.1fg", millions)
        else
            formatted = string.format("%.2fg", millions)
        end
        return RemoveTrailingZeros(formatted)
    elseif value >= 1000 then
        -- Thousands (k)
        local thousands = value / 1000
        local formatted
        if thousands >= 100 then
            formatted = string.format("%.0fk", thousands)
        elseif thousands >= 10 then
            formatted = string.format("%.1fk", thousands)
        else
            formatted = string.format("%.2fk", thousands)
        end
        return RemoveTrailingZeros(formatted)
    else
        return tostring(value)
    end
end

-- Store original functions
local originalToggleCharacter = nil

-- Hide default character frame
local function HideDefaultCharacter()
    if CharacterFrame then
        CharacterFrame:UnregisterAllEvents()
        CharacterFrame:Hide()
    end
end

-- Override ToggleCharacter
local function OverrideToggleCharacter()
    HideDefaultCharacter()
    CharacterModule:Toggle()
    HideDefaultCharacter()
end

-- Create the main character frame
local function CreateCharacterFrame()
    local frame = CreateFrame("Frame", "SteamDeckCharacterFrame", UIParent)
    
    -- Calculate frame width - use a reasonable default for now
    -- Tabs will adjust this if needed
    local frameWidth = 600
    frame:SetWidth(frameWidth)
    
    -- Anchor to left side and full height of screen
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    
    -- Set strata
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(100)
    
    -- Don't enable mouse on main frame
    frame:EnableMouse(false)
    frame:EnableKeyboard(false)
    
    -- Keep isOpen state in sync
    frame:SetScript("OnShow", function()
        isOpen = true
        -- Recalculate tab positions when frame is shown (in case width changed)
        if frame.PositionTabs then
            frame:PositionTabs()
        end
    end)
    frame:SetScript("OnHide", function()
        isOpen = false
        HideDefaultCharacter()
    end)
    
    frame:SetMovable(false)
    
    -- Background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bg:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    bg:SetColorTexture(0, 0, 0, 0.8)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -10)
    title:SetText("Character")
    
    -- Create tab container
    local tabContainer = CreateFrame("Frame", nil, frame)
    tabContainer:SetHeight(TAB_HEIGHT)
    tabContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -TITLE_HEIGHT)
    tabContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -TITLE_HEIGHT)
    
    -- Tab definitions
    local tabs = {
        {id = "Equipment", text = "Equipment"},
        {id = "Reputation", text = "Reputation"},
        {id = "Currencies", text = "Currencies"}
    }
    
    -- Store tab buttons
    frame.tabButtons = {}
    frame.tabContentFrames = {}
    
    -- Function to position tabs (centered)
    local function PositionTabs()
        if not frame.tabButtons or #frame.tabButtons == 0 then
            return
        end
        
        -- Calculate total width of all tabs
        local totalTabWidth = 0
        for i, tabButton in ipairs(frame.tabButtons) do
            if i > 1 then
                totalTabWidth = totalTabWidth + TAB_SPACING
            end
            totalTabWidth = totalTabWidth + tabButton:GetWidth()
        end
        
        -- Center tabs within the container
        local containerWidth = tabContainer:GetWidth()
        if containerWidth <= 0 then
            containerWidth = frame:GetWidth()
        end
        local startX = (containerWidth - totalTabWidth) / 2
        
        -- Position first tab
        frame.tabButtons[1]:ClearAllPoints()
        frame.tabButtons[1]:SetPoint("TOPLEFT", tabContainer, "TOPLEFT", startX, 0)
        
        -- Position subsequent tabs
        for i = 2, #frame.tabButtons do
            frame.tabButtons[i]:ClearAllPoints()
            frame.tabButtons[i]:SetPoint("TOPLEFT", frame.tabButtons[i - 1], "TOPRIGHT", TAB_SPACING, 0)
        end
    end
    
    -- Create tabs
    for i, tabData in ipairs(tabs) do
        local tabButton = CreateFrame("Button", nil, tabContainer)
        tabButton:SetHeight(TAB_HEIGHT)
        
        -- Calculate tab width based on text
        local fontString = tabButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fontString:SetText(tabData.text)
        local textWidth = fontString:GetStringWidth()
        local tabWidth = textWidth + (TAB_PADDING * 2)
        tabButton:SetWidth(tabWidth)
        
        -- Store tab button
        frame.tabButtons[i] = tabButton
        
        -- Tab background (inactive state)
        local bg = tabButton:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(tabButton)
        bg:SetColorTexture(0.15, 0.15, 0.15, 0.7)
        tabButton.bg = bg
        
        -- Tab border (inactive state) - create border edges
        local borderThickness = 2
        local borderColor = {0.3, 0.3, 0.3, 0.8}
        
        -- Top border
        local borderTop = tabButton:CreateTexture(nil, "BORDER")
        borderTop:SetSize(tabWidth, borderThickness)
        borderTop:SetPoint("TOPLEFT", tabButton, "TOPLEFT", 0, 0)
        borderTop:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        
        -- Bottom border
        local borderBottom = tabButton:CreateTexture(nil, "BORDER")
        borderBottom:SetSize(tabWidth, borderThickness)
        borderBottom:SetPoint("BOTTOMLEFT", tabButton, "BOTTOMLEFT", 0, 0)
        borderBottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        
        -- Left border
        local borderLeft = tabButton:CreateTexture(nil, "BORDER")
        borderLeft:SetSize(borderThickness, TAB_HEIGHT)
        borderLeft:SetPoint("TOPLEFT", tabButton, "TOPLEFT", 0, 0)
        borderLeft:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        
        -- Right border
        local borderRight = tabButton:CreateTexture(nil, "BORDER")
        borderRight:SetSize(borderThickness, TAB_HEIGHT)
        borderRight:SetPoint("TOPRIGHT", tabButton, "TOPRIGHT", 0, 0)
        borderRight:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        
        -- Store border references for easy updating
        tabButton.borderTop = borderTop
        tabButton.borderBottom = borderBottom
        tabButton.borderLeft = borderLeft
        tabButton.borderRight = borderRight
        
        -- Tab text
        local tabText = tabButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tabText:SetPoint("CENTER", tabButton, "CENTER", 0, 0)
        tabText:SetText(tabData.text)
        tabText:SetTextColor(0.8, 0.8, 0.8, 1)
        tabButton.text = tabText
        tabButton.tabId = tabData.id
        
        -- Tab click handler
        tabButton:SetScript("OnClick", function()
            activeTab = tabData.id
            frame:UpdateTabs()
        end)
        
        -- Hover effects
        tabButton:SetScript("OnEnter", function(self)
            if activeTab ~= self.tabId then
                self.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
            end
        end)
        tabButton:SetScript("OnLeave", function(self)
            if activeTab ~= self.tabId then
                self.bg:SetColorTexture(0.15, 0.15, 0.15, 0.7)
            end
        end)
        
        frame.tabButtons[i] = tabButton
        
        -- Create content frame for this tab
        local contentFrame = CreateFrame("Frame", nil, frame)
        contentFrame:SetPoint("TOPLEFT", tabContainer, "BOTTOMLEFT", 0, 0)
        contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        contentFrame:Hide()
        frame.tabContentFrames[tabData.id] = contentFrame
    end
    
    -- Position tabs after all are created
    PositionTabs()
    
    -- Store PositionTabs function for later use (in case frame size changes)
    frame.PositionTabs = PositionTabs
    
    -- Function to update tab appearance
    function frame:UpdateTabs()
        local activeBorderColor = {0.5, 0.7, 1.0, 1.0}
        local inactiveBorderColor = {0.3, 0.3, 0.3, 0.8}
        
        for i, tabButton in ipairs(self.tabButtons) do
            if activeTab == tabButton.tabId then
                -- Active tab: highlight background and border
                tabButton.bg:SetColorTexture(0.3, 0.5, 0.7, 0.9)
                tabButton.borderTop:SetColorTexture(activeBorderColor[1], activeBorderColor[2], activeBorderColor[3], activeBorderColor[4])
                tabButton.borderBottom:SetColorTexture(activeBorderColor[1], activeBorderColor[2], activeBorderColor[3], activeBorderColor[4])
                tabButton.borderLeft:SetColorTexture(activeBorderColor[1], activeBorderColor[2], activeBorderColor[3], activeBorderColor[4])
                tabButton.borderRight:SetColorTexture(activeBorderColor[1], activeBorderColor[2], activeBorderColor[3], activeBorderColor[4])
                tabButton.text:SetTextColor(1, 1, 1, 1)
            else
                -- Inactive tab: normal background and border
                tabButton.bg:SetColorTexture(0.15, 0.15, 0.15, 0.7)
                tabButton.borderTop:SetColorTexture(inactiveBorderColor[1], inactiveBorderColor[2], inactiveBorderColor[3], inactiveBorderColor[4])
                tabButton.borderBottom:SetColorTexture(inactiveBorderColor[1], inactiveBorderColor[2], inactiveBorderColor[3], inactiveBorderColor[4])
                tabButton.borderLeft:SetColorTexture(inactiveBorderColor[1], inactiveBorderColor[2], inactiveBorderColor[3], inactiveBorderColor[4])
                tabButton.borderRight:SetColorTexture(inactiveBorderColor[1], inactiveBorderColor[2], inactiveBorderColor[3], inactiveBorderColor[4])
                tabButton.text:SetTextColor(0.8, 0.8, 0.8, 1)
            end
        end
        
        -- Show/hide content frames
        for tabId, contentFrame in pairs(self.tabContentFrames) do
            if activeTab == tabId then
                contentFrame:Show()
                -- Notify tabs when they become active
                if tabId == "Reputation" and self.reputationContainer then
                    self.reputationContainer:UpdateReputation()
                end
                if tabId == "Currencies" and self.currencyContainer then
                    self.currencyContainer:UpdateCurrency()
                end
            else
                contentFrame:Hide()
            end
        end
    end
    
    -- Store tab container
    frame.tabContainer = tabContainer
    
    -- Initialize tab content (load tab modules)
    EquipmentTab.Initialize(frame, {
        FRAME_PADDING = FRAME_PADDING,
        FormatNumber = FormatNumber,
        RemoveTrailingZeros = RemoveTrailingZeros
    })
    
    ReputationTab.Initialize(frame, {
        FRAME_PADDING = FRAME_PADDING
    })
    
    CurrenciesTab.Initialize(frame, {
        FRAME_PADDING = FRAME_PADDING
    })
    
    -- Initialize tabs (set Equipment as active)
    frame:UpdateTabs()
    
    frame:Hide()
    
    return frame
end

-- Refresh function (delegates to active tab)
local function Refresh()
    if not characterFrame or not isOpen then
        return
    end
    
    -- Refresh equipment tab
    if EquipmentTab.Refresh then
        EquipmentTab.Refresh(characterFrame)
    end
    
    -- Update reputation if tab is active
    if activeTab == "Reputation" and characterFrame.reputationContainer then
        characterFrame.reputationContainer:UpdateReputation()
    end
    
    -- Update currencies if tab is active
    if activeTab == "Currencies" and characterFrame.currencyContainer then
        characterFrame.currencyContainer:UpdateCurrency()
    end
end

-- Open the character frame
function CharacterModule:Open()
    if not characterFrame then
        characterFrame = CreateCharacterFrame()
    end
    
    isOpen = true
    characterFrame:Show()
    Refresh()
end

-- Close the character frame
function CharacterModule:Close()
    if characterFrame then
        characterFrame:Hide()
        isOpen = false
        HideDefaultCharacter()
    end
end

-- Toggle the character frame
function CharacterModule:Toggle()
    if not characterFrame then
        characterFrame = CreateCharacterFrame()
    end
    
    if isOpen then
        self:Close()
    else
        self:Open()
    end
end

-- Apply function overrides
local function ApplyOverrides()
    if ToggleCharacter and not originalToggleCharacter then
        originalToggleCharacter = ToggleCharacter
    end
    if ToggleCharacter then
        _G.ToggleCharacter = OverrideToggleCharacter
        ToggleCharacter = OverrideToggleCharacter
    end
end

-- Initialize the module
function CharacterModule:Initialize()
    -- Tab modules should be loaded from TOC before this
    EquipmentTab = SteamDeckCharacterEquipmentTab or EquipmentTab
    ReputationTab = SteamDeckCharacterReputationTab or ReputationTab
    CurrenciesTab = SteamDeckCharacterCurrenciesTab or CurrenciesTab
    
    -- Apply overrides immediately
    ApplyOverrides()
    
    -- Hide default character frame initially
    HideDefaultCharacter()
    
    -- Register for equipment update events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    eventFrame:RegisterEvent("UNIT_MODEL_CHANGED")
    eventFrame:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    eventFrame:RegisterEvent("UNIT_STATS")
    eventFrame:RegisterEvent("PLAYER_DAMAGE_DONE_MODS")
    eventFrame:RegisterEvent("SPELL_POWER_CHANGED")
    eventFrame:RegisterEvent("UPDATE_FACTION")
    eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    eventFrame:SetScript("OnEvent", function(self, event)
        HideDefaultCharacter()
        if isOpen then
            Refresh()
        end
    end)
    
    -- Update stats periodically (for movement speed and other dynamic stats)
    local statsUpdateFrame = CreateFrame("Frame")
    statsUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= 0.5 then  -- Update every 0.5 seconds
            self.elapsed = 0
            if isOpen and characterFrame and characterFrame.statsContainer and characterFrame.statsContainer.UpdateStats then
                characterFrame.statsContainer:UpdateStats()
            end
        end
    end)
    
    -- Hook into CharacterFrame Show method
    if CharacterFrame then
        local originalShow = CharacterFrame.Show
        CharacterFrame.Show = function(self, ...)
            HideDefaultCharacter()
        end
    end
    
    -- Re-apply overrides on PLAYER_LOGIN
    local loginFrame = CreateFrame("Frame")
    loginFrame:RegisterEvent("PLAYER_LOGIN")
    loginFrame:SetScript("OnEvent", function()
        ApplyOverrides()
    end)
end

return CharacterModule

