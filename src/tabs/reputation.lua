-- Reputation Tab Module
-- Handles reputation display with two-column layout

SteamDeckReputationTab = {}
local ReputationTab = SteamDeckReputationTab

-- Configuration
local REP_ENTRY_HEIGHT = 56
local REP_BAR_HEIGHT = 24
local REP_HEADER_HEIGHT = 30
local REP_TAB_HEIGHT = 45
local REP_TAB_SPACING = 2
local MAX_REPUTATION_REACTION = 8
local FRAME_PADDING = 20

-- Reputation type detection
local ReputationType = {
    Standard = 1,
    Friendship = 2,
    MajorFaction = 3
}

local function GetReputationType(factionData)
    if not factionData then
        return nil
    end
    
    local friendshipData = C_GossipInfo and C_GossipInfo.GetFriendshipReputation(factionData.factionID)
    local isFriendshipReputation = friendshipData and friendshipData.friendshipFactionID and friendshipData.friendshipFactionID > 0
    if isFriendshipReputation then
        return ReputationType.Friendship
    end
    
    if C_Reputation and C_Reputation.IsMajorFaction(factionData.factionID) then
        return ReputationType.MajorFaction
    end
    
    return ReputationType.Standard
end

-- Normalize bar values (remove offset from min)
local function NormalizeBarValues(minValue, maxValue, currentValue)
    maxValue = maxValue - minValue
    currentValue = currentValue - minValue
    minValue = 0
    return minValue, maxValue, currentValue
end

-- Get reputation bar color based on reaction
local function GetReputationBarColor(reaction)
    if reaction <= 2 then
        return 0.6, 0.25, 0.25  -- Darker Red (unfriendly)
    elseif reaction == 3 then
        return 0.6, 0.4, 0.25  -- Darker Orange
    elseif reaction == 4 then
        return 0.65, 0.65, 0.3  -- Darker Yellow (neutral)
    else
        return 0.3, 0.6, 0.35  -- Darker Green (friendly)
    end
end

-- Create a reputation entry
local function CreateReputationEntry(parent, factionData, yOffset, isChild, leftPadding, rightPadding)
    local entry = CreateFrame("Frame", nil, parent)
    entry:SetHeight(REP_ENTRY_HEIGHT)
    leftPadding = leftPadding or FRAME_PADDING
    rightPadding = rightPadding or FRAME_PADDING
    entry:SetPoint("TOPLEFT", parent, "TOPLEFT", leftPadding, yOffset)
    entry:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -rightPadding, yOffset)
    
    -- Faction name (with truncation)
    local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameText:SetPoint("TOPLEFT", entry, "TOPLEFT", 0, -5)
    nameText:SetPoint("TOPRIGHT", entry, "TOPRIGHT", 0, -5)
    nameText:SetJustifyH("LEFT")
    nameText:SetNonSpaceWrap(false)
    
    local factionName = factionData.name or ""
    local parentWidth = parent:GetWidth() or 400
    local availableWidth = parentWidth - leftPadding - rightPadding
    
    nameText:SetText(factionName)
    local textWidth = nameText:GetStringWidth()
    
    if textWidth > availableWidth then
        local low, high = 1, #factionName
        while low <= high do
            local mid = math.floor((low + high) / 2)
            local testText = factionName:sub(1, mid) .. "..."
            nameText:SetText(testText)
            local testWidth = nameText:GetStringWidth()
            if testWidth <= availableWidth then
                low = mid + 1
            else
                high = mid - 1
            end
        end
        nameText:SetText(factionName:sub(1, high) .. "...")
    end
    
    nameText:SetTextColor(1, 1, 1, 1)
    entry.nameText = nameText
    
    -- Reputation bar
    local bar = CreateFrame("StatusBar", nil, entry)
    bar:SetHeight(REP_BAR_HEIGHT)
    bar:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -4)
    bar:SetPoint("TOPRIGHT", nameText, "BOTTOMRIGHT", 0, -4)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    
    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints(bar)
    barBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    barBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    bar.bg = barBg
    
    local standingText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    standingText:SetPoint("LEFT", bar, "LEFT", 5, 0)
    standingText:SetJustifyH("LEFT")
    standingText:SetTextColor(1, 1, 1, 1)
    entry.standingText = standingText
    
    local progressText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    progressText:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
    progressText:SetJustifyH("RIGHT")
    progressText:SetTextColor(1, 1, 0.5, 1)
    entry.progressText = progressText
    
    entry.bar = bar
    entry.factionData = factionData
    entry.factionID = factionData.factionID
    entry.factionIndex = factionData.factionIndex
    
    return entry
end

-- Update reputation entry
local function UpdateReputationEntry(entry)
    local factionData = entry.factionData
    if not factionData then
        return
    end
    
    local reputationType = GetReputationType(factionData)
    local minValue, maxValue, currentValue
    local standingText = ""
    local progressText = ""
    local r, g, b = 0.5, 0.5, 0.5
    
    if reputationType == ReputationType.Standard then
        local isCapped = factionData.reaction == MAX_REPUTATION_REACTION
        if isCapped then
            minValue, maxValue, currentValue = 0, 1, 1
            if GetText then
                standingText = GetText("FACTION_STANDING_LABEL" .. factionData.reaction, UnitSex("player")) or ""
            else
                standingText = _G["FACTION_STANDING_LABEL" .. factionData.reaction] or ""
            end
            progressText = ""
        else
            minValue, maxValue, currentValue = factionData.currentReactionThreshold, factionData.nextReactionThreshold, factionData.currentStanding
            minValue, maxValue, currentValue = NormalizeBarValues(minValue, maxValue, currentValue)
            if GetText then
                standingText = GetText("FACTION_STANDING_LABEL" .. factionData.reaction, UnitSex("player")) or ""
            else
                standingText = _G["FACTION_STANDING_LABEL" .. factionData.reaction] or ""
            end
            local currentFormatted = BreakUpLargeNumbers(currentValue)
            local maxFormatted = BreakUpLargeNumbers(maxValue)
            progressText = currentFormatted .. " / " .. maxFormatted
        end
        r, g, b = GetReputationBarColor(factionData.reaction)
        
    elseif reputationType == ReputationType.Friendship then
        local friendshipData = C_GossipInfo.GetFriendshipReputation(factionData.factionID)
        if friendshipData then
            local isMaxRank = not friendshipData.nextThreshold or friendshipData.nextThreshold == 0
            if isMaxRank then
                minValue, maxValue, currentValue = 0, 1, 1
                standingText = friendshipData.reaction or ""
                progressText = ""
            else
                minValue, maxValue, currentValue = friendshipData.reactionThreshold, friendshipData.nextThreshold, friendshipData.standing
                minValue, maxValue, currentValue = NormalizeBarValues(minValue, maxValue, currentValue)
                standingText = friendshipData.reaction or ""
                local currentFormatted = BreakUpLargeNumbers(currentValue)
                local maxFormatted = BreakUpLargeNumbers(maxValue)
                progressText = currentFormatted .. " / " .. maxFormatted
            end
            r, g, b = 0.3, 0.6, 0.35
        end
        
    elseif reputationType == ReputationType.MajorFaction then
        local majorFactionData = C_MajorFactions.GetMajorFactionData(factionData.factionID)
        if majorFactionData then
            local isMaxRenown = C_MajorFactions.HasMaximumRenown(factionData.factionID)
            if isMaxRenown then
                minValue, maxValue, currentValue = 0, 1, 1
                if RENOWN_LEVEL_LABEL then
                    standingText = RENOWN_LEVEL_LABEL:format(majorFactionData.renownLevel) or ""
                else
                    standingText = "Renown " .. majorFactionData.renownLevel
                end
                progressText = ""
            else
                minValue, maxValue, currentValue = 0, majorFactionData.renownLevelThreshold, majorFactionData.renownReputationEarned
                minValue, maxValue, currentValue = NormalizeBarValues(minValue, maxValue, currentValue)
                if RENOWN_LEVEL_LABEL then
                    standingText = RENOWN_LEVEL_LABEL:format(majorFactionData.renownLevel) or ""
                else
                    standingText = "Renown " .. majorFactionData.renownLevel
                end
                local currentFormatted = BreakUpLargeNumbers(currentValue)
                local maxFormatted = BreakUpLargeNumbers(maxValue)
                progressText = currentFormatted .. " / " .. maxFormatted
            end
            r, g, b = 0.3, 0.45, 0.6
        end
    end
    
    entry.bar:SetMinMaxValues(minValue, maxValue)
    entry.bar:SetValue(currentValue)
    entry.bar:SetStatusBarColor(r, g, b, 1)
    
    entry.standingText:SetText(standingText)
    entry.progressText:SetText(progressText)
end

-- Create reputation header entry
local function CreateReputationHeader(parent, factionData, yOffset, hasChildren, leftPadding, rightPadding, tab)
    local header = CreateFrame(hasChildren and "Frame" or "Button", nil, parent)
    header:SetHeight(REP_HEADER_HEIGHT)
    leftPadding = leftPadding or FRAME_PADDING
    rightPadding = rightPadding or FRAME_PADDING
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", leftPadding, yOffset)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -rightPadding, yOffset)
    
    local bg = header:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(header)
    bg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
    
    local nameText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameText:SetPoint("LEFT", header, "LEFT", 10, 0)
    nameText:SetText(factionData.name or "")
    nameText:SetTextColor(1, 0.8, 0, 1)
    header.nameText = nameText
    
    if not hasChildren then
        local indicator = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        indicator:SetPoint("RIGHT", header, "RIGHT", -10, 0)
        indicator:SetText(factionData.isCollapsed and "+" or "-")
        indicator:SetTextColor(1, 1, 1, 1)
        header.indicator = indicator
    end
    
    header.factionData = factionData
    header.factionIndex = factionData.factionIndex
    
    if not hasChildren then
        header:SetScript("OnClick", function()
            if factionData.isCollapsed then
                C_Reputation.ExpandFactionHeader(factionData.factionIndex)
            else
                C_Reputation.CollapseFactionHeader(factionData.factionIndex)
            end
            if tab and tab.content and tab.content.reputationContainer and tab.content.reputationContainer.UpdateReputation then
                tab.content.reputationContainer:UpdateReputation()
            end
        end)
    end
    
    return header
end

-- Initialize reputation tab
function ReputationTab:Initialize(panel, contentFrame)
    local tab = self
    
    -- Set tab properties
    self.tabId = "reputation"
    self.name = "Reputation"
    self.panel = panel
    self.content = contentFrame
    self.leftPaneButtons = {}  -- Store left pane category buttons
    self.rightPaneEntries = {}  -- Store right pane reputation entries
    
    if not self.content then
        return
    end
    
    -- Create all UI elements in the content frame
    local reputationContent = self.content
    
    -- Calculate pane widths (split 35/65 with spacing between for wider reputation list)
    local totalWidth = reputationContent:GetWidth()
    if totalWidth <= 0 then
        totalWidth = 600 - (2 * FRAME_PADDING)
    end
    local paneSpacing = 5
    local availableWidth = totalWidth - paneSpacing
    local leftPaneWidth = availableWidth * 0.35
    local rightPaneWidth = availableWidth * 0.65
    
    -- Left pane: Expansion list
    local leftPane = CreateFrame("Frame", nil, reputationContent)
    leftPane:SetWidth(leftPaneWidth)
    leftPane:SetPoint("TOPLEFT", reputationContent, "TOPLEFT", 0, 0)
    leftPane:SetPoint("BOTTOMLEFT", reputationContent, "BOTTOMLEFT", 0, 0)
    
    local leftScrollFrame = CreateFrame("ScrollFrame", nil, leftPane)
    leftScrollFrame:SetPoint("TOPLEFT", leftPane, "TOPLEFT", 0, 0)
    leftScrollFrame:SetPoint("BOTTOMRIGHT", leftPane, "BOTTOMRIGHT", 0, 0)
    
    local leftContentFrame = CreateFrame("Frame", nil, leftScrollFrame)
    leftContentFrame:SetWidth(leftPaneWidth)
    leftScrollFrame:SetScrollChild(leftContentFrame)
    
    -- Right pane: Reputation list - extends to right edge
    local rightPane = CreateFrame("Frame", nil, reputationContent)
    rightPane:SetPoint("TOPLEFT", leftPane, "TOPRIGHT", paneSpacing, 0)
    rightPane:SetPoint("BOTTOMRIGHT", reputationContent, "BOTTOMRIGHT", 0, 0)
    -- Get actual width after anchoring
    rightPaneWidth = rightPane:GetWidth()
    
    local rightScrollFrame = CreateFrame("ScrollFrame", nil, rightPane)
    rightScrollFrame:SetPoint("TOPLEFT", rightPane, "TOPLEFT", 0, 0)
    rightScrollFrame:SetPoint("BOTTOMRIGHT", rightPane, "BOTTOMRIGHT", 0, 0)
    
    local rightContentFrame = CreateFrame("Frame", nil, rightScrollFrame)
    rightContentFrame:SetWidth(rightPaneWidth)
    rightScrollFrame:SetScrollChild(rightContentFrame)
    
    local rightScrollBar = CreateFrame("Slider", nil, rightScrollFrame)
    rightScrollBar:SetWidth(20)
    rightScrollBar:SetPoint("TOPRIGHT", rightScrollFrame, "TOPRIGHT", 0, 0)
    rightScrollBar:SetPoint("BOTTOMRIGHT", rightScrollFrame, "BOTTOMRIGHT", 0, 0)
    rightScrollBar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    rightScrollBar:SetMinMaxValues(0, 0)
    rightScrollBar:SetValue(0)
    rightScrollBar:SetValueStep(20)
    rightScrollBar:Hide()
    
    local rightScrollBarBg = rightScrollBar:CreateTexture(nil, "BACKGROUND")
    rightScrollBarBg:SetAllPoints(rightScrollBar)
    rightScrollBarBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    
    local selectedExpansionIndex = 1
    local expansions = {}
    
    local function CollectExpansions()
        expansions = {}
        local numFactions = C_Reputation.GetNumFactions()
        local i = 1
        
        local needsRefresh = false
        for j = 1, numFactions do
            local checkData = C_Reputation.GetFactionDataByIndex(j)
            if checkData and checkData.isHeader and checkData.isCollapsed then
                C_Reputation.ExpandFactionHeader(j)
                needsRefresh = true
            end
        end
        
        if needsRefresh then
            numFactions = C_Reputation.GetNumFactions()
        end
        
        while i <= numFactions do
            local factionData = C_Reputation.GetFactionDataByIndex(i)
            if not factionData then
                i = i + 1
                break
            end
            
            factionData.factionIndex = i
            
            if factionData.isHeader and not factionData.isChild then
                local expansionData = {
                    headerIndex = i,
                    headerData = factionData,
                    name = factionData.name,
                    reputations = {}
                }
                
                i = i + 1
                while i <= numFactions do
                    local nextData = C_Reputation.GetFactionDataByIndex(i)
                    if not nextData then
                        break
                    end
                    if nextData.isHeader and not nextData.isChild then
                        break
                    end
                    table.insert(expansionData.reputations, nextData)
                    i = i + 1
                end
                
                table.insert(expansions, expansionData)
            elseif not factionData.isHeader and not factionData.isChild then
                local expansionData = {
                    headerIndex = nil,
                    headerData = nil,
                    name = "Other",
                    reputations = {factionData}
                }
                i = i + 1
                while i <= numFactions do
                    local nextData = C_Reputation.GetFactionDataByIndex(i)
                    if not nextData then
                        break
                    end
                    if nextData.isHeader and not nextData.isChild then
                        break
                    end
                    if not nextData.isHeader and not nextData.isChild then
                        table.insert(expansionData.reputations, nextData)
                    end
                    i = i + 1
                end
                table.insert(expansions, expansionData)
            else
                i = i + 1
            end
        end
        
        if selectedExpansionIndex < 1 or selectedExpansionIndex > #expansions then
            selectedExpansionIndex = 1
        end
    end
    
    local function CreateExpansionButton(parent, expansionData, index, yOffset, isSelected, paneWidth)
        local button = CreateFrame("Button", nil, parent)
        button:SetHeight(REP_TAB_HEIGHT)
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", FRAME_PADDING, yOffset)
        button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -FRAME_PADDING, yOffset)
        
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(button)
        if isSelected then
            bg:SetColorTexture(0.3, 0.5, 0.7, 0.9)
        else
            bg:SetColorTexture(0.15, 0.15, 0.15, 0.7)
        end
        button.bg = bg
        
        local borderThickness = 2
        local borderColor = isSelected and {0.5, 0.7, 1.0, 1.0} or {0.3, 0.3, 0.3, 0.8}
        
        local borderTop = button:CreateTexture(nil, "BORDER")
        borderTop:SetSize(button:GetWidth(), borderThickness)
        borderTop:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        borderTop:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        
        local borderBottom = button:CreateTexture(nil, "BORDER")
        borderBottom:SetSize(button:GetWidth(), borderThickness)
        borderBottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
        borderBottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        
        local borderLeft = button:CreateTexture(nil, "BORDER")
        borderLeft:SetSize(borderThickness, REP_TAB_HEIGHT)
        borderLeft:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        borderLeft:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        
        local borderRight = button:CreateTexture(nil, "BORDER")
        borderRight:SetSize(borderThickness, REP_TAB_HEIGHT)
        borderRight:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
        borderRight:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        
        local buttonText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        buttonText:SetPoint("LEFT", button, "LEFT", 10, 0)
        buttonText:SetPoint("RIGHT", button, "RIGHT", -10, 0)
        buttonText:SetJustifyH("LEFT")
        buttonText:SetNonSpaceWrap(false)
        
        local expansionName = expansionData.name or ""
        local function TruncateText(text, maxChars)
            if #text <= maxChars then
                return text
            end
            return text:sub(1, maxChars - 3) .. "..."
        end
        
        local estimatedMaxChars = math.floor((paneWidth - 20) / 8)
        local truncatedName = TruncateText(expansionName, estimatedMaxChars)
        buttonText:SetText(truncatedName)
        
        if isSelected then
            buttonText:SetTextColor(1, 1, 1, 1)
        else
            buttonText:SetTextColor(0.8, 0.8, 0.8, 1)
        end
        button.text = buttonText
        
        button.expansionData = expansionData
        button.expansionIndex = index
        
        return button
    end
    
    local function UpdateRightPane()
        local children = {rightContentFrame:GetChildren()}
        for _, child in ipairs(children) do
            child:Hide()
            child:SetParent(nil)
        end
        
        -- Clear stored entries
        wipe(tab.rightPaneEntries)
        
        if #expansions == 0 or selectedExpansionIndex < 1 or selectedExpansionIndex > #expansions then
            return
        end
        
        local selectedExpansion = expansions[selectedExpansionIndex]
        if not selectedExpansion then
            return
        end
        
        local leftPadding = 5
        local rightPadding = 5
        
        local normalReps = {}
        local headerGroups = {}
        local currentHeaderGroup = nil
        
        for _, repData in ipairs(selectedExpansion.reputations) do
            if repData.isHeader then
                if currentHeaderGroup then
                    table.insert(headerGroups, currentHeaderGroup)
                end
                currentHeaderGroup = {
                    header = repData,
                    children = {}
                }
            else
                if repData.isChild then
                    if currentHeaderGroup then
                        table.insert(currentHeaderGroup.children, repData)
                    else
                        table.insert(normalReps, repData)
                    end
                else
                    if currentHeaderGroup then
                        table.insert(headerGroups, currentHeaderGroup)
                        currentHeaderGroup = nil
                    end
                    table.insert(normalReps, repData)
                end
            end
        end
        
        if currentHeaderGroup then
            table.insert(headerGroups, currentHeaderGroup)
        end
        
        local yOffset = -FRAME_PADDING
        
        if #normalReps > 0 then
            local fakeFactionData = {
                name = selectedExpansion.name,
                isHeader = true,
                isChild = false,
                factionID = 0
            }
            local header = CreateReputationHeader(rightContentFrame, fakeFactionData, yOffset, true, leftPadding, rightPadding, tab)
            table.insert(tab.rightPaneEntries, header)
            yOffset = yOffset - REP_HEADER_HEIGHT
        end
        
        for _, repData in ipairs(normalReps) do
            local isChild = repData.isChild or false
            local entry = CreateReputationEntry(rightContentFrame, repData, yOffset, isChild, leftPadding, rightPadding)
            UpdateReputationEntry(entry)
            table.insert(tab.rightPaneEntries, entry)
            yOffset = yOffset - REP_ENTRY_HEIGHT
        end
        
        for _, group in ipairs(headerGroups) do
            local headerSpacing = 16
            yOffset = yOffset - headerSpacing
            local header = CreateReputationHeader(rightContentFrame, group.header, yOffset, true, leftPadding, rightPadding, tab)
            table.insert(tab.rightPaneEntries, header)
            yOffset = yOffset - REP_HEADER_HEIGHT
            
            for _, repData in ipairs(group.children) do
                local isChild = repData.isChild or false
                local entry = CreateReputationEntry(rightContentFrame, repData, yOffset, isChild, leftPadding, rightPadding)
                UpdateReputationEntry(entry)
                table.insert(tab.rightPaneEntries, entry)
                yOffset = yOffset - REP_ENTRY_HEIGHT
            end
        end
        
        local totalHeight = math.abs(yOffset) + FRAME_PADDING
        rightContentFrame:SetHeight(math.max(totalHeight, rightPane:GetHeight()))
        
        local maxScroll = math.max(0, totalHeight - rightPane:GetHeight())
        rightScrollBar:SetMinMaxValues(0, maxScroll)
        rightScrollBar:Hide()
    end
    
    local function UpdateLeftPane()
        local children = {leftContentFrame:GetChildren()}
        for _, child in ipairs(children) do
            child:Hide()
            child:SetParent(nil)
        end
        
        -- Clear stored buttons
        wipe(tab.leftPaneButtons)
        
        if #expansions == 0 then
            return
        end
        
        local yOffset = -FRAME_PADDING
        for i = 1, #expansions do
            local isSelected = (i == selectedExpansionIndex)
            local button = CreateExpansionButton(leftContentFrame, expansions[i], i, yOffset, isSelected, leftPaneWidth)
            
            button:SetScript("OnClick", function()
                selectedExpansionIndex = i
                UpdateLeftPane()
                UpdateRightPane()
            end)
            
            -- Store button for navigation
            table.insert(tab.leftPaneButtons, button)
            
            yOffset = yOffset - REP_TAB_HEIGHT - REP_TAB_SPACING
        end
        
        local totalHeight = math.abs(yOffset) + FRAME_PADDING
        leftContentFrame:SetHeight(math.max(totalHeight, leftPane:GetHeight()))
    end
    
    local function UpdateReputation()
        CollectExpansions()
        UpdateLeftPane()
        UpdateRightPane()
        
        -- Refresh cursor grid if cursor is active for this tab
        if SteamDeckInterfaceCursorModule then
            SteamDeckInterfaceCursorModule:RefreshGrid()
        end
    end
    
    rightScrollBar:SetScript("OnValueChanged", function(self, value)
        rightScrollFrame:SetVerticalScroll(value)
    end)
    
    rightScrollFrame:EnableMouseWheel(true)
    rightScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local minValue, maxValue = rightScrollBar:GetMinMaxValues()
        local currentValue = rightScrollBar:GetValue()
        local newValue = math.max(minValue, math.min(maxValue, currentValue - (delta * 30)))
        rightScrollBar:SetValue(newValue)
    end)
    
    leftScrollFrame:EnableMouseWheel(true)
    leftScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        -- Could add left pane scrolling if needed
    end)
    
    local container = CreateFrame("Frame", nil, reputationContent)
    container.UpdateReputation = UpdateReputation
    self.content.reputationContainer = container
    
    -- Store scroll frame reference for auto-scrolling
    self.rightScrollFrame = rightScrollFrame
    
    -- Register for reputation update events
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("UPDATE_FACTION")
    self.eventFrame:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
    self.eventFrame:SetScript("OnEvent", function()
        if tab.content and tab.content:IsShown() then
            UpdateReputation()
        end
    end)
    
    UpdateReputation()
end

-- OnShow callback
function ReputationTab:OnShow()
    if self.content and self.content.reputationContainer and self.content.reputationContainer.UpdateReputation then
        self.content.reputationContainer:UpdateReputation()
    end
    
    -- Refresh cursor grid if cursor is active for this tab
    if SteamDeckInterfaceCursorModule then
        SteamDeckInterfaceCursorModule:RefreshGrid()
    end
end

-- OnHide callback
function ReputationTab:OnHide()
end

-- Get navigation grid for cursor system
-- Build navigation grid from left pane buttons and right pane entries
-- Returns a 2D grid structure: grid[row][col] = frame
-- Also returns slotToPosition map: slotToPosition[frame] = {row, col}
-- Layout:
--   Col 0: Left pane category buttons (rows 0-N)
--   Col 1: Right pane reputation entries (rows 0-M)
function ReputationTab:GetNavGrid()
    local grid = {}
    local slotToPosition = {}
    
    -- Process left pane buttons (col 0)
    for i, button in ipairs(self.leftPaneButtons) do
        if button and button:IsShown() then
            local row = i - 1  -- 0-based row index
            local col = 0
            if not grid[row] then
                grid[row] = {}
            end
            grid[row][col] = button
            slotToPosition[button] = {row = row, col = col}
        end
    end
    
    -- Process right pane entries (col 1)
    for i, entry in ipairs(self.rightPaneEntries) do
        if entry and entry:IsShown() then
            local row = i - 1  -- 0-based row index
            local col = 1
            if not grid[row] then
                grid[row] = {}
            end
            grid[row][col] = entry
            slotToPosition[entry] = {row = row, col = col}
        end
    end
    
    return grid, slotToPosition
end

-- Get reputation info from selection
local function GetReputationInfoFromSelection(selection)
    if not selection then
        return nil
    end
    
    local factionID = nil
    local factionIndex = nil
    
    -- Check if selection has factionID and factionIndex directly
    if selection.factionID and selection.factionIndex then
        factionID = selection.factionID
        factionIndex = selection.factionIndex
    -- Or check if it has factionData
    elseif selection.factionData then
        if selection.factionData.factionID then
            factionID = selection.factionData.factionID
            factionIndex = selection.factionData.factionIndex
        elseif type(selection.factionData) == "table" then
            -- Try to get factionIndex from the stored factionData
            factionIndex = selection.factionIndex
            if factionIndex then
                local tempFactionData = C_Reputation.GetFactionDataByIndex(factionIndex)
                if tempFactionData then
                    factionID = tempFactionData.factionID
                end
            end
        end
    end
    
    if factionID and factionIndex then
        local factionData = C_Reputation.GetFactionDataByIndex(factionIndex)
        if factionData and not factionData.isHeader then
            return {
                factionID = factionID,
                factionIndex = factionIndex,
                factionData = factionData,
                name = factionData.name or "Unknown Faction",
                description = factionData.description or "",
                isHeader = factionData.isHeader or false,
                canToggleAtWar = factionData.canToggleAtWar or false,
                atWarWith = factionData.atWarWith or false,
                canSetInactive = factionData.canSetInactive or false,
                isActive = C_Reputation.IsFactionActive(factionIndex),
                isWatched = factionData.isWatched or false,
                isMajorFaction = C_Reputation.IsMajorFaction(factionID),
            }
        end
    end
    
    -- Fallback: if we have factionIndex directly on the selection, try using it
    if selection.factionIndex then
        local factionData = C_Reputation.GetFactionDataByIndex(selection.factionIndex)
        if factionData and not factionData.isHeader then
            return {
                factionID = factionData.factionID or 0,
                factionIndex = selection.factionIndex,
                factionData = factionData,
                name = factionData.name or "Unknown Faction",
                description = factionData.description or "",
                isHeader = factionData.isHeader or false,
                canToggleAtWar = factionData.canToggleAtWar or false,
                atWarWith = factionData.atWarWith or false,
                canSetInactive = factionData.canSetInactive or false,
                isActive = C_Reputation.IsFactionActive(selection.factionIndex),
                isWatched = factionData.isWatched or false,
                isMajorFaction = C_Reputation.IsMajorFaction(factionData.factionID or 0),
            }
        end
    end
    
    return nil
end

-- Build menu options for reputation entries
local function BuildReputationMenuOptions(repInfo)
    local options = {}
    
    if not repInfo or repInfo.isHeader then
        return options
    end
    
    -- Show Details option (selects the faction, similar to clicking in default UI)
    table.insert(options, {
        text = "Show Details",
        action = function()
            C_Reputation.SetSelectedFaction(repInfo.factionIndex)
        end
    })
    
    -- At War toggle (if applicable)
    if repInfo.canToggleAtWar then
        table.insert(options, {
            text = repInfo.atWarWith and "Stop War" or "At War",
            action = function()
                C_Reputation.ToggleFactionAtWar(repInfo.factionIndex)
            end
        })
    end
    
    -- Make Inactive/Active toggle (if applicable)
    if repInfo.canSetInactive then
        table.insert(options, {
            text = repInfo.isActive and "Make Inactive" or "Make Active",
            action = function()
                C_Reputation.SetFactionActive(repInfo.factionIndex, not repInfo.isActive)
            end
        })
    end
    
    -- Watch Faction toggle
    table.insert(options, {
        text = repInfo.isWatched and "Unwatch Faction" or "Watch Faction",
        action = function()
            C_QuestLog.SetWatchedFaction(repInfo.factionIndex, not repInfo.isWatched)
        end
    })
    
    -- View Renown (for major factions)
    if repInfo.isMajorFaction then
        table.insert(options, {
            text = "View Renown",
            action = function()
                MajorFactions_LoadUI()
                ToggleMajorFactionRenown(repInfo.factionID)
            end
        })
    end
    
    return options
end

-- Get context menu data for a selected reputation entry
-- selection: The selected frame/entry
-- Returns: {content, options} or nil if not applicable
function ReputationTab:GetContextMenuForSelection(selection)
    if not selection then
        return nil
    end
    
    -- Check if it's a reputation entry (has factionID or factionIndex)
    if not selection.factionID and not selection.factionIndex then
        return nil
    end
    
    -- Get reputation info
    local repInfo = GetReputationInfoFromSelection(selection)
    if not repInfo or repInfo.isHeader then
        return nil
    end
    
    -- Create content frame
    local content = CreateFrame("Frame", nil, nil)
    content:SetSize(340, 100)  -- Will be resized based on content
    
    -- Item display area (top section)
    local itemDisplay = CreateFrame("Frame", nil, content)
    itemDisplay:SetSize(340, 80)
    itemDisplay:SetPoint("TOP", content, "TOP", 0, 0)
    content.itemDisplay = itemDisplay
    
    -- Item icon with border
    local itemIconBg = CreateFrame("Frame", nil, itemDisplay)
    itemIconBg:SetSize(64, 64)
    itemIconBg:SetPoint("TOPLEFT", itemDisplay, "TOPLEFT", 10, 0)
    
    local itemIconTexture = itemIconBg:CreateTexture(nil, "ARTWORK")
    itemIconTexture:SetSize(60, 60)
    itemIconTexture:SetPoint("CENTER", itemIconBg, "CENTER", 0, 0)
    itemIconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    
    -- Item name
    local itemNameText = itemDisplay:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    itemNameText:SetPoint("LEFT", itemIconBg, "RIGHT", 10, 0)
    itemNameText:SetPoint("RIGHT", itemDisplay, "RIGHT", -10, 0)
    itemNameText:SetJustifyH("LEFT")
    itemNameText:SetText(repInfo.name)
    itemNameText:SetTextColor(1, 1, 1)  -- White for reputation
    
    -- Description area
    local descriptionArea = CreateFrame("Frame", nil, content)
    descriptionArea:SetPoint("TOP", itemDisplay, "BOTTOM", 0, 0)
    descriptionArea:SetPoint("LEFT", content, "LEFT", 10, 0)
    descriptionArea:SetPoint("RIGHT", content, "RIGHT", -10, 0)
    content.descriptionArea = descriptionArea
    
    -- Display description
    if repInfo.description and repInfo.description ~= "" then
        local baseFont, baseFontHeight, baseFlags = GameFontNormal:GetFont()
        local defaultFontHeight = baseFontHeight * 1.5
        
        local descriptionText = descriptionArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        descriptionText:SetFont(baseFont, defaultFontHeight, baseFlags)
        descriptionText:SetPoint("TOPLEFT", descriptionArea, "TOPLEFT", 0, 0)
        descriptionText:SetPoint("RIGHT", descriptionArea, "RIGHT", 0, 0)
        descriptionText:SetJustifyH("LEFT")
        descriptionText:SetJustifyV("TOP")
        descriptionText:SetNonSpaceWrap(true)
        descriptionText:SetText(repInfo.description)
        descriptionText:Show()
        
        descriptionArea:SetHeight(descriptionText:GetHeight())
    else
        descriptionArea:SetHeight(0)
    end
    
    -- Set content height
    local contentHeight = itemDisplay:GetHeight() + descriptionArea:GetHeight()
    content:SetHeight(contentHeight)
    
    -- Build menu options
    local options = BuildReputationMenuOptions(repInfo)
    
    -- Return menu data structure
    return {
        content = content,
        options = options
    }
end

return ReputationTab
