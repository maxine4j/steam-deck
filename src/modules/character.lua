-- SteamDeck Character Module
-- Replaces default character frame with a custom left-side paper doll

SteamDeckCharacterModule = {}
local CharacterModule = SteamDeckCharacterModule
local characterFrame = nil
local modelScene = nil
local equipmentSlots = {}
local isOpen = false
local activeTab = "Equipment"  -- Current active tab

-- Configuration
local SLOT_SIZE = 48  -- Smaller slots to fit around larger model
local SLOT_SPACING = 4
local FRAME_PADDING = 20
local TITLE_HEIGHT = 40  -- Space for title at top
local TAB_HEIGHT = 35  -- Height of tab buttons
local TAB_SPACING = 4  -- Spacing between tabs
local TAB_PADDING = 8  -- Horizontal padding inside tabs
local MODEL_TOP_OFFSET_Y = 50  -- Offset from top for model (below title + tabs)
local BASE_MOVEMENT_SPEED = 7  -- Base movement speed constant
local CR_VERSATILITY_DAMAGE_DONE = 29  -- Combat rating constant for versatility damage
local STAT_HEADER_HEIGHT = 24  -- Height of stat category headers
local STAT_CATEGORY_SPACING = 12  -- Spacing between stat categories
local STAT_ITEM_SPACING = 20  -- Spacing between stat items
local REP_ENTRY_HEIGHT = 56  -- Height of each reputation entry (taller to accommodate larger bar)
local REP_BAR_HEIGHT = 24  -- Height of reputation progress bar (60% of 40 = 24)
local REP_HEADER_HEIGHT = 30  -- Height of reputation header entries
local REP_CHILD_INDENT = 30  -- Indentation for child/sub-reputations
local REP_TAB_HEIGHT = 45  -- Height of tab buttons
local REP_TAB_SPACING = 2  -- Spacing between tabs
local MAX_REPUTATION_REACTION = 8  -- Maximum reputation reaction level
local CURRENCY_ENTRY_HEIGHT = 34  -- Height of each currency entry (reduced by 40% from 56)
local CURRENCY_ICON_SIZE = 32  -- Size of currency icon
local CURRENCY_HEADER_HEIGHT = 30  -- Height of currency header entries

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

-- Model configuration
local MODEL_CENTER_OFFSET_X = 80  -- Offset from left to center model (wider frame allows more space)

-- Calculate model size to take up top half of screen
-- This will be calculated when frame is created
local function GetModelSize()
    local screenHeight = UIParent:GetHeight()
    local availableHeight = (screenHeight - TITLE_HEIGHT - TAB_HEIGHT - MODEL_TOP_OFFSET_Y) / 2
    -- Make it square and ensure it's a reasonable size
    return math.min(availableHeight, 400)  -- Cap at 400 for very large screens
end

-- Equipment slots in default UI layout order
-- Left side (top to bottom)
local LEFT_SLOTS = {
    "HeadSlot",
    "NeckSlot",
    "ShoulderSlot",
    "BackSlot",
    "ChestSlot",
    "ShirtSlot",
    "TabardSlot",
    "WristSlot"
}

-- Right side (top to bottom)
local RIGHT_SLOTS = {
    "HandsSlot",
    "WaistSlot",
    "LegsSlot",
    "FeetSlot",
    "Finger0Slot",
    "Finger1Slot",
    "Trinket0Slot",
    "Trinket1Slot"
}

-- Bottom slots
local BOTTOM_SLOTS = {
    "MainHandSlot",
    "SecondaryHandSlot"
}

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

-- Create equipment slot button
local function CreateEquipmentSlot(parent, slotName, index)
    local slot = CreateFrame("Button", "SteamDeckCharacterSlot"..slotName, parent)
    slot:SetSize(SLOT_SIZE, SLOT_SIZE)
    
    -- Slot background
    local bg = slot:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(slot)
    bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    -- Border
    local border = slot:CreateTexture(nil, "BORDER")
    border:SetAllPoints(slot)
    border:SetTexture("Interface\\Buttons\\UI-EmptySlot")
    slot.border = border
    
    -- Item texture
    local itemTexture = slot:CreateTexture(nil, "ARTWORK")
    itemTexture:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, -2)
    itemTexture:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
    itemTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    slot.itemTexture = itemTexture
    
    -- Get slot ID
    local slotID, textureName = GetInventorySlotInfo(slotName)
    slot.slotID = slotID
    slot.slotName = slotName
    slot.backgroundTextureName = textureName
    
    -- Set background texture
    if textureName then
        bg:SetTexture(textureName)
    end
    
    -- Tooltip
    slot:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local hasItem = GameTooltip:SetInventoryItem("player", self.slotID)
        if not hasItem then
            local slotNameUpper = string.upper(self.slotName)
            GameTooltip:SetText(_G[slotNameUpper] or self.slotName)
        end
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Click and drag handling
    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    slot:RegisterForDrag("LeftButton")
    
    slot:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            -- PickupInventoryItem handles both picking up and placing items
            PickupInventoryItem(self.slotID)
        elseif button == "RightButton" then
            -- Use item if usable
            local itemLink = GetInventoryItemLink("player", self.slotID)
            if itemLink then
                UseInventoryItem(self.slotID)
            end
        end
    end)
    
    slot:SetScript("OnDragStart", function(self)
        PickupInventoryItem(self.slotID)
    end)
    
    slot:SetScript("OnReceiveDrag", function(self)
        -- PickupInventoryItem handles placing items from cursor
        PickupInventoryItem(self.slotID)
    end)
    
    return slot
end

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

-- Get reputation bar color based on reaction (darker pastel colors for better text contrast)
local function GetReputationBarColor(reaction)
    -- FACTION_BAR_COLORS mapping: reaction 1-8
    -- 1-2: Darker Red (unfriendly), 3: Darker Orange, 4: Darker Yellow (neutral), 5-8: Darker Green (friendly)
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
    -- Use provided padding or default FRAME_PADDING for other uses
    leftPadding = leftPadding or FRAME_PADDING
    rightPadding = rightPadding or FRAME_PADDING
    -- No indentation for child reputations - they align with normal reps
    entry:SetPoint("TOPLEFT", parent, "TOPLEFT", leftPadding, yOffset)
    entry:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -rightPadding, yOffset)
    
    -- Faction name (with truncation to prevent wrapping)
    local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameText:SetPoint("TOPLEFT", entry, "TOPLEFT", 0, -5)
    nameText:SetPoint("TOPRIGHT", entry, "TOPRIGHT", 0, -5)
    nameText:SetJustifyH("LEFT")
    nameText:SetNonSpaceWrap(false)
    
    -- Truncate long names using actual text width measurement
    local factionName = factionData.name or ""
    
    -- Calculate available width for text (same as bar width - full entry width minus padding)
    -- We'll use the parent's width since entry might not be laid out yet
    local parentWidth = parent:GetWidth() or 400  -- Fallback if parent width not available
    local availableWidth = parentWidth - leftPadding - rightPadding  -- Match the bar width
    
    -- Set initial text to measure
    nameText:SetText(factionName)
    local textWidth = nameText:GetStringWidth()
    
    -- Truncate if needed
    if textWidth > availableWidth then
        -- Binary search for the right truncation point
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
    
    -- Reputation bar (flat pastel style for Steam Deck)
    local bar = CreateFrame("StatusBar", nil, entry)
    bar:SetHeight(REP_BAR_HEIGHT)
    bar:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -4)
    bar:SetPoint("TOPRIGHT", nameText, "BOTTOMRIGHT", 0, -4)
    -- Use a simple solid color texture for flat appearance
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    
    -- Bar background (flat dark gray)
    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints(bar)
    barBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    barBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    bar.bg = barBg
    
    -- Standing text (on the bar)
    local standingText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    standingText:SetPoint("LEFT", bar, "LEFT", 5, 0)
    standingText:SetJustifyH("LEFT")
    standingText:SetTextColor(1, 1, 1, 1)
    entry.standingText = standingText
    
    -- Progress text (on the bar, right side)
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
            r, g, b = 0.3, 0.6, 0.35  -- Darker Green for friendships (better text contrast)
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
            r, g, b = 0.3, 0.45, 0.6  -- Darker Blue for major factions (renown, better text contrast)
        end
    end
    
    -- Update bar
    entry.bar:SetMinMaxValues(minValue, maxValue)
    entry.bar:SetValue(currentValue)
    entry.bar:SetStatusBarColor(r, g, b, 1)
    
    -- Update texts
    entry.standingText:SetText(standingText)
    entry.progressText:SetText(progressText)
end

-- Create reputation header entry
local function CreateReputationHeader(parent, factionData, yOffset, hasChildren, leftPadding, rightPadding)
    -- Use Frame instead of Button if it has children (non-clickable)
    local header = CreateFrame(hasChildren and "Frame" or "Button", nil, parent)
    header:SetHeight(REP_HEADER_HEIGHT)
    -- Use provided padding or default FRAME_PADDING
    -- Headers are never indented, even if they are children
    leftPadding = leftPadding or FRAME_PADDING
    rightPadding = rightPadding or FRAME_PADDING
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", leftPadding, yOffset)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -rightPadding, yOffset)
    
    -- Header background
    local bg = header:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(header)
    bg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
    
    -- Header name
    local nameText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameText:SetPoint("LEFT", header, "LEFT", 10, 0)
    nameText:SetText(factionData.name or "")
    nameText:SetTextColor(1, 0.8, 0, 1)
    header.nameText = nameText
    
    -- Collapse/expand indicator (only show if header is clickable)
    if not hasChildren then
        local indicator = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        indicator:SetPoint("RIGHT", header, "RIGHT", -10, 0)
        indicator:SetText(factionData.isCollapsed and "+" or "-")
        indicator:SetTextColor(1, 1, 1, 1)
        header.indicator = indicator
    end
    
    header.factionData = factionData
    header.factionIndex = factionData.factionIndex
    
    -- Click handler to toggle collapse (only for headers without children)
    if not hasChildren then
        header:SetScript("OnClick", function()
            if factionData.isCollapsed then
                C_Reputation.ExpandFactionHeader(factionData.factionIndex)
            else
                C_Reputation.CollapseFactionHeader(factionData.factionIndex)
            end
            -- Refresh reputation display
            if characterFrame and characterFrame.reputationContainer then
                characterFrame.reputationContainer:UpdateReputation()
            end
        end)
    end
    
    return header
end

-- Create a tab button for reputation categories
local function CreateReputationTab(parent, tabData, index, isSelected)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetHeight(REP_TAB_HEIGHT)
    tab:SetPoint("LEFT", parent, "LEFT", 0, 0)
    tab:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    
    -- Tab background
    local bg = tab:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(tab)
    if isSelected then
        bg:SetColorTexture(0.3, 0.5, 0.7, 0.9)  -- Highlighted
    else
        bg:SetColorTexture(0.15, 0.15, 0.15, 0.7)  -- Normal
    end
    tab.bg = bg
    
    -- Tab border
    local borderThickness = 2
    local borderColor = isSelected and {0.5, 0.7, 1.0, 1.0} or {0.3, 0.3, 0.3, 0.8}
    
    local borderTop = tab:CreateTexture(nil, "BORDER")
    borderTop:SetSize(tab:GetWidth(), borderThickness)
    borderTop:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    borderTop:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    local borderBottom = tab:CreateTexture(nil, "BORDER")
    borderBottom:SetSize(tab:GetWidth(), borderThickness)
    borderBottom:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
    borderBottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    local borderLeft = tab:CreateTexture(nil, "BORDER")
    borderLeft:SetSize(borderThickness, REP_TAB_HEIGHT)
    borderLeft:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    borderLeft:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    local borderRight = tab:CreateTexture(nil, "BORDER")
    borderRight:SetSize(borderThickness, REP_TAB_HEIGHT)
    borderRight:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 0, 0)
    borderRight:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    -- Tab text
    local tabText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tabText:SetPoint("LEFT", tab, "LEFT", 10, 0)
    tabText:SetText(tabData.name or "")
    if isSelected then
        tabText:SetTextColor(1, 1, 1, 1)
    else
        tabText:SetTextColor(0.8, 0.8, 0.8, 1)
    end
    tab.text = tabText
    
    tab.tabData = tabData
    tab.tabIndex = index
    
    return tab
end

-- Create currency entry
local function CreateCurrencyEntry(parent, currencyData, yOffset, leftPadding, rightPadding)
    local entry = CreateFrame("Button", nil, parent)
    entry:SetHeight(CURRENCY_ENTRY_HEIGHT)
    leftPadding = leftPadding or FRAME_PADDING
    rightPadding = rightPadding or FRAME_PADDING
    entry:SetPoint("TOPLEFT", parent, "TOPLEFT", leftPadding, yOffset)
    entry:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -rightPadding, yOffset)
    
    -- Currency icon
    local icon = entry:CreateTexture(nil, "ARTWORK")
    icon:SetSize(CURRENCY_ICON_SIZE, CURRENCY_ICON_SIZE)
    icon:SetPoint("LEFT", entry, "LEFT", 0, 0)
    entry.icon = icon
    
    -- Currency name (20% smaller font)
    local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    local nameFont, nameFontSize = nameText:GetFont()
    nameText:SetFont(nameFont, nameFontSize * 0.8)
    nameText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    nameText:SetPoint("RIGHT", entry, "RIGHT", -80, 0)  -- Reduced from -100 to give more space for names
    nameText:SetJustifyH("LEFT")
    nameText:SetNonSpaceWrap(false)
    nameText:SetTextColor(1, 1, 1, 1)
    entry.nameText = nameText
    
    -- Currency quantity (20% smaller font)
    local quantityText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    local qtyFont, qtyFontSize = quantityText:GetFont()
    quantityText:SetFont(qtyFont, qtyFontSize * 0.8)
    quantityText:SetPoint("RIGHT", entry, "RIGHT", -5, 0)
    quantityText:SetJustifyH("RIGHT")
    quantityText:SetTextColor(1, 1, 0.5, 1)
    entry.quantityText = quantityText
    
    entry.currencyData = currencyData
    entry.currencyID = currencyData.currencyID
    
    -- Tooltip
    entry:SetScript("OnEnter", function(self)
        if self.currencyID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local currencyLink = C_CurrencyInfo.GetCurrencyLink(self.currencyID, 0)
            if currencyLink then
                GameTooltip:SetHyperlink(currencyLink)
            else
                GameTooltip:SetText(self.currencyData.name or "")
            end
            GameTooltip:Show()
        end
    end)
    entry:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    return entry
end

-- Update currency entry
local function UpdateCurrencyEntry(entry)
    local currencyData = entry.currencyData
    if not currencyData then
        return
    end
    
    -- Update icon
    if currencyData.iconFileID and currencyData.iconFileID > 0 then
        entry.icon:SetTexture(currencyData.iconFileID)
        entry.icon:Show()
    else
        entry.icon:Hide()
    end
    
    -- Update name (with truncation)
    local currencyName = currencyData.name or ""
    entry.nameText:SetText(currencyName)
    local textWidth = entry.nameText:GetStringWidth()
    local availableWidth = entry:GetWidth() - CURRENCY_ICON_SIZE - 8 - 80  -- Icon + spacing + quantity space (reduced from 100)
    
    if textWidth > availableWidth then
        local low, high = 1, #currencyName
        while low <= high do
            local mid = math.floor((low + high) / 2)
            local testText = currencyName:sub(1, mid) .. "..."
            entry.nameText:SetText(testText)
            local testWidth = entry.nameText:GetStringWidth()
            if testWidth <= availableWidth then
                low = mid + 1
            else
                high = mid - 1
            end
        end
        entry.nameText:SetText(currencyName:sub(1, high) .. "...")
    end
    
    -- Update quantity
    local quantity = currencyData.quantity or 0
    local maxQuantity = currencyData.maxQuantity or 0
    local quantityStr = ""
    
    if maxQuantity > 0 then
        quantityStr = BreakUpLargeNumbers(quantity) .. " / " .. BreakUpLargeNumbers(maxQuantity)
    else
        quantityStr = BreakUpLargeNumbers(quantity)
    end
    
    entry.quantityText:SetText(quantityStr)
end

-- Create currency header entry
local function CreateCurrencyHeader(parent, currencyData, yOffset, hasChildren, leftPadding, rightPadding)
    local header = CreateFrame(hasChildren and "Frame" or "Button", nil, parent)
    header:SetHeight(CURRENCY_HEADER_HEIGHT)
    leftPadding = leftPadding or FRAME_PADDING
    rightPadding = rightPadding or FRAME_PADDING
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", leftPadding, yOffset)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -rightPadding, yOffset)
    
    -- Header background
    local bg = header:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(header)
    bg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
    
    -- Header name (20% smaller font)
    local nameText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    local nameFont, nameFontSize = nameText:GetFont()
    nameText:SetFont(nameFont, nameFontSize * 0.8)
    nameText:SetPoint("LEFT", header, "LEFT", 10, 0)
    nameText:SetText(currencyData.name or "")
    nameText:SetTextColor(1, 0.8, 0, 1)
    header.nameText = nameText
    
    -- Collapse/expand indicator (only show if header is clickable, 20% smaller font)
    if not hasChildren then
        local indicator = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        local indFont, indFontSize = indicator:GetFont()
        indicator:SetFont(indFont, indFontSize * 0.8)
        indicator:SetPoint("RIGHT", header, "RIGHT", -10, 0)
        indicator:SetText(currencyData.isHeaderExpanded and "-" or "+")
        indicator:SetTextColor(1, 1, 1, 1)
        header.indicator = indicator
    end
    
    header.currencyData = currencyData
    header.currencyIndex = currencyData.currencyIndex
    
    -- Click handler to toggle collapse (only for headers without children)
    if not hasChildren then
        header:SetScript("OnClick", function()
            if currencyData.isHeaderExpanded then
                C_CurrencyInfo.ExpandCurrencyList(currencyData.currencyIndex, false)
            else
                C_CurrencyInfo.ExpandCurrencyList(currencyData.currencyIndex, true)
            end
            -- Refresh currency display
            if characterFrame and characterFrame.currencyContainer then
                characterFrame.currencyContainer:UpdateCurrency()
            end
        end)
    end
    
    return header
end

-- Create currency pane
local function CreateCurrencyPane(currencyContent, parentFrame)
    -- Calculate pane widths (split 40/60 with spacing between)
    local totalWidth = currencyContent:GetWidth()
    local paneSpacing = 5
    local availableWidth = totalWidth - paneSpacing
    local leftPaneWidth = availableWidth * 0.4
    local rightPaneWidth = availableWidth * 0.6
    
    -- Left pane: Category list
    local leftPane = CreateFrame("Frame", nil, currencyContent)
    leftPane:SetWidth(leftPaneWidth)
    leftPane:SetPoint("TOPLEFT", currencyContent, "TOPLEFT", 0, 0)
    leftPane:SetPoint("BOTTOMLEFT", currencyContent, "BOTTOMLEFT", 0, 0)
    
    -- Left pane scroll frame
    local leftScrollFrame = CreateFrame("ScrollFrame", nil, leftPane)
    leftScrollFrame:SetPoint("TOPLEFT", leftPane, "TOPLEFT", 0, 0)
    leftScrollFrame:SetPoint("BOTTOMRIGHT", leftPane, "BOTTOMRIGHT", 0, 0)
    
    local leftContentFrame = CreateFrame("Frame", nil, leftScrollFrame)
    leftContentFrame:SetWidth(leftPaneWidth)
    leftScrollFrame:SetScrollChild(leftContentFrame)
    
    -- Right pane: Currency list
    local rightPane = CreateFrame("Frame", nil, currencyContent)
    rightPane:SetWidth(rightPaneWidth)
    rightPane:SetPoint("TOPLEFT", leftPane, "TOPRIGHT", paneSpacing, 0)
    rightPane:SetPoint("BOTTOMRIGHT", currencyContent, "BOTTOMRIGHT", 0, 0)
    
    -- Right pane scroll frame
    local rightScrollFrame = CreateFrame("ScrollFrame", nil, rightPane)
    rightScrollFrame:SetPoint("TOPLEFT", rightPane, "TOPLEFT", 0, 0)
    rightScrollFrame:SetPoint("BOTTOMRIGHT", rightPane, "BOTTOMRIGHT", 0, 0)
    
    local rightContentFrame = CreateFrame("Frame", nil, rightScrollFrame)
    rightContentFrame:SetWidth(rightPaneWidth)
    rightScrollFrame:SetScrollChild(rightContentFrame)
    
    -- Right pane scroll bar
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
    
    -- Track selected category (default to first)
    local selectedCategoryIndex = 1
    local categories = {}
    
    -- Function to collect categories and their currencies
    local function CollectCategories()
        categories = {}
        local numCurrencies = C_CurrencyInfo.GetCurrencyListSize()
        local i = 1
        
        -- First pass: expand all headers to ensure we can see all children
        local needsRefresh = false
        for j = 1, numCurrencies do
            local checkData = C_CurrencyInfo.GetCurrencyListInfo(j)
            if checkData and checkData.isHeader and not checkData.isHeaderExpanded then
                C_CurrencyInfo.ExpandCurrencyList(j, true)
                needsRefresh = true
            end
        end
        
        -- If we expanded any headers, refresh the currency list
        if needsRefresh then
            numCurrencies = C_CurrencyInfo.GetCurrencyListSize()
        end
        
        while i <= numCurrencies do
            local currencyData = C_CurrencyInfo.GetCurrencyListInfo(i)
            if not currencyData then
                i = i + 1
                break
            end
            
            currencyData.currencyIndex = i
            
            -- Top-level header (depth 0) - start a new category
            if currencyData.isHeader and currencyData.currencyListDepth == 0 then
                local categoryData = {
                    headerIndex = i,
                    headerData = currencyData,
                    name = currencyData.name,
                    currencies = {}
                }
                
                -- Collect everything until next top-level header
                i = i + 1
                while i <= numCurrencies do
                    local nextData = C_CurrencyInfo.GetCurrencyListInfo(i)
                    if not nextData then
                        break
                    end
                    -- Stop if we hit another top-level header
                    if nextData.isHeader and nextData.currencyListDepth == 0 then
                        break
                    end
                    -- Add everything else (children and currencies) to this category
                    table.insert(categoryData.currencies, nextData)
                    i = i + 1
                end
                
                table.insert(categories, categoryData)
            elseif not currencyData.isHeader and currencyData.currencyListDepth == 0 then
                -- Top-level currency before any header - create an "Other" category
                local categoryData = {
                    headerIndex = nil,
                    headerData = nil,
                    name = "Other",
                    currencies = {currencyData}
                }
                i = i + 1
                -- Collect any following top-level currencies until we hit a header
                while i <= numCurrencies do
                    local nextData = C_CurrencyInfo.GetCurrencyListInfo(i)
                    if not nextData then
                        break
                    end
                    if nextData.isHeader and nextData.currencyListDepth == 0 then
                        break
                    end
                    if not nextData.isHeader and nextData.currencyListDepth == 0 then
                        table.insert(categoryData.currencies, nextData)
                    end
                    i = i + 1
                end
                table.insert(categories, categoryData)
            else
                -- Skip (shouldn't happen at top level)
                i = i + 1
            end
        end
        
        -- Find and process Legacy category: promote its children to top level and remove Legacy
        local legacyIndex = nil
        local legacyCategoryData = nil
        
        for idx, categoryData in ipairs(categories) do
            if categoryData.name == "Legacy" then
                legacyIndex = idx
                legacyCategoryData = categoryData
                break
            end
        end
        
        -- If we found Legacy, promote its children to top level
        if legacyIndex and legacyCategoryData then
            -- Remove Legacy category
            table.remove(categories, legacyIndex)
            
            -- Process Legacy's currencies: promote depth 1 headers to top-level categories
            local legacyCurrencies = legacyCategoryData.currencies
            local promotedCategories = {}
            local orphanCurrencies = {}  -- Direct currencies at depth 1 (not under a header)
            
            local i = 1
            while i <= #legacyCurrencies do
                local currencyData = legacyCurrencies[i]
                
                -- Check if this is a depth 1 header (direct child of Legacy)
                if currencyData.isHeader and currencyData.currencyListDepth == 1 then
                    -- This header becomes a top-level category
                    local promotedCategory = {
                        headerIndex = currencyData.currencyIndex,
                        headerData = currencyData,
                        name = currencyData.name,
                        currencies = {}
                    }
                    
                    -- Collect all children of this header (depth > 1) until we hit another depth 1 item
                    i = i + 1
                    while i <= #legacyCurrencies do
                        local nextData = legacyCurrencies[i]
                        if not nextData then
                            break
                        end
                        -- Stop if we hit another depth 1 item (another header or currency)
                        if nextData.currencyListDepth == 1 then
                            break
                        end
                        -- Add children (depth > 1) to this promoted category
                        if nextData.currencyListDepth > 1 then
                            table.insert(promotedCategory.currencies, nextData)
                        end
                        i = i + 1
                    end
                    
                    table.insert(promotedCategories, promotedCategory)
                elseif not currencyData.isHeader and currencyData.currencyListDepth == 1 then
                    -- Direct currency at depth 1 (not under a header) - goes to "Other"
                    table.insert(orphanCurrencies, currencyData)
                    i = i + 1
                else
                    -- Skip items at depth > 1 (they should be handled by their parent headers)
                    i = i + 1
                end
            end
            
            -- Insert promoted categories into the categories list
            for _, promotedCategory in ipairs(promotedCategories) do
                table.insert(categories, promotedCategory)
            end
            
            -- Handle orphan currencies: merge into "Other" or create "Other"
            if #orphanCurrencies > 0 then
                local otherCategoryIndex = nil
                for idx, categoryData in ipairs(categories) do
                    if categoryData.name == "Other" then
                        otherCategoryIndex = idx
                        break
                    end
                end
                
                if otherCategoryIndex then
                    -- Merge orphan currencies into existing "Other" category
                    for _, currencyData in ipairs(orphanCurrencies) do
                        table.insert(categories[otherCategoryIndex].currencies, currencyData)
                    end
                else
                    -- Create new "Other" category with orphan currencies
                    local otherCategory = {
                        headerIndex = nil,
                        headerData = nil,
                        name = "Other",
                        currencies = orphanCurrencies
                    }
                    table.insert(categories, otherCategory)
                end
            end
            
            -- Adjust selectedCategoryIndex if Legacy was selected or removed
            if selectedCategoryIndex == legacyIndex then
                selectedCategoryIndex = 1
            elseif selectedCategoryIndex > legacyIndex then
                -- Adjust for removed Legacy, but add back the number of promoted categories
                selectedCategoryIndex = selectedCategoryIndex - 1 + #promotedCategories
            end
        end
        
        -- Ensure we have at least one category selected
        if selectedCategoryIndex < 1 or selectedCategoryIndex > #categories then
            selectedCategoryIndex = 1
        end
    end
    
    -- Create category button for left pane
    local function CreateCategoryButton(parent, categoryData, index, yOffset, isSelected, paneWidth)
        local button = CreateFrame("Button", nil, parent)
        button:SetHeight(REP_TAB_HEIGHT)
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", FRAME_PADDING, yOffset)
        button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -FRAME_PADDING, yOffset)
        
        -- Button background
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(button)
        if isSelected then
            bg:SetColorTexture(0.3, 0.5, 0.7, 0.9)  -- Highlighted
        else
            bg:SetColorTexture(0.15, 0.15, 0.15, 0.7)  -- Normal
        end
        button.bg = bg
        
        -- Button border
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
        
        -- Button text (with truncation for long names)
        local buttonText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        buttonText:SetPoint("LEFT", button, "LEFT", 10, 0)
        buttonText:SetPoint("RIGHT", button, "RIGHT", -10, 0)
        buttonText:SetJustifyH("LEFT")
        buttonText:SetNonSpaceWrap(false)
        
        -- Truncate text if too long
        local categoryName = categoryData.name or ""
        local function TruncateText(text, maxChars)
            if #text <= maxChars then
                return text
            end
            return text:sub(1, maxChars - 3) .. "..."
        end
        
        -- Estimate max characters based on button width
        local estimatedMaxChars = math.floor((paneWidth - 20) / 8)
        local truncatedName = TruncateText(categoryName, estimatedMaxChars)
        buttonText:SetText(truncatedName)
        
        if isSelected then
            buttonText:SetTextColor(1, 1, 1, 1)
        else
            buttonText:SetTextColor(0.8, 0.8, 0.8, 1)
        end
        button.text = buttonText
        
        button.categoryData = categoryData
        button.categoryIndex = index
        
        return button
    end
    
    -- Update right pane (currencies list) - defined first so UpdateLeftPane can call it
    local function UpdateRightPane()
        -- Clear existing entries
        local children = {rightContentFrame:GetChildren()}
        for _, child in ipairs(children) do
            child:Hide()
            child:SetParent(nil)
        end
        
        if #categories == 0 or selectedCategoryIndex < 1 or selectedCategoryIndex > #categories then
            return
        end
        
        local selectedCategory = categories[selectedCategoryIndex]
        if not selectedCategory then
            return
        end
        
        -- Create currency entries
        local leftPadding = 5
        local scrollBarWidth = 20
        local rightPadding = 5 + scrollBarWidth
        
        -- Sort currencies: normal currencies first, then headers with children
        local normalCurrencies = {}
        local headerGroups = {}
        local currentHeaderGroup = nil
        
        for _, currencyData in ipairs(selectedCategory.currencies) do
            if currencyData.isHeader then
                -- Start a new header group
                if currentHeaderGroup then
                    table.insert(headerGroups, currentHeaderGroup)
                end
                currentHeaderGroup = {
                    header = currencyData,
                    children = {}
                }
            else
                -- Currency entry - check if it's a child or a normal currency
                if currencyData.currencyListDepth > 0 then
                    -- This is a child of a header - add to current header group
                    if currentHeaderGroup then
                        table.insert(currentHeaderGroup.children, currencyData)
                    else
                        -- Orphaned child (shouldn't happen, but handle it)
                        table.insert(normalCurrencies, currencyData)
                    end
                else
                    -- This is a normal (top-level) currency - close any current header group and add to normal currencies
                    if currentHeaderGroup then
                        table.insert(headerGroups, currentHeaderGroup)
                        currentHeaderGroup = nil
                    end
                    table.insert(normalCurrencies, currencyData)
                end
            end
        end
        
        -- Add the last header group if it exists
        if currentHeaderGroup then
            table.insert(headerGroups, currentHeaderGroup)
        end
        
        -- Display: normal currencies first, then header groups
        local yOffset = -FRAME_PADDING
        
        -- Display fake category header above normal currencies (if there are any normal currencies)
        if #normalCurrencies > 0 then
            local fakeCurrencyData = {
                name = selectedCategory.name,
                isHeader = true,
                currencyListDepth = 0,
                currencyID = 0
            }
            local categoryHeader = CreateCurrencyHeader(rightContentFrame, fakeCurrencyData, yOffset, true, leftPadding, rightPadding)
            yOffset = yOffset - CURRENCY_HEADER_HEIGHT
        end
        
        -- Display normal currencies first
        for _, currencyData in ipairs(normalCurrencies) do
            local entry = CreateCurrencyEntry(rightContentFrame, currencyData, yOffset, leftPadding, rightPadding)
            UpdateCurrencyEntry(entry)
            yOffset = yOffset - CURRENCY_ENTRY_HEIGHT
        end
        
        -- Display header groups (headers with their children)
        for _, group in ipairs(headerGroups) do
            -- Add extra margin before header
            local headerSpacing = 16
            yOffset = yOffset - headerSpacing
            -- Display the header
            local header = CreateCurrencyHeader(rightContentFrame, group.header, yOffset, true, leftPadding, rightPadding)
            yOffset = yOffset - CURRENCY_HEADER_HEIGHT
            
            -- Display the header's children
            for _, currencyData in ipairs(group.children) do
                local entry = CreateCurrencyEntry(rightContentFrame, currencyData, yOffset, leftPadding, rightPadding)
                UpdateCurrencyEntry(entry)
                yOffset = yOffset - CURRENCY_ENTRY_HEIGHT
            end
        end
        
        -- Update right content frame height
        local totalHeight = math.abs(yOffset) + FRAME_PADDING
        rightContentFrame:SetHeight(math.max(totalHeight, rightPane:GetHeight()))
        
        -- Update scroll bar
        local maxScroll = math.max(0, totalHeight - rightPane:GetHeight())
        rightScrollBar:SetMinMaxValues(0, maxScroll)
        rightScrollBar:Hide()  -- Always hide the scrollbar
    end
    
    -- Update left pane (categories list)
    local function UpdateLeftPane()
        -- Clear existing buttons
        local children = {leftContentFrame:GetChildren()}
        for _, child in ipairs(children) do
            child:Hide()
            child:SetParent(nil)
        end
        
        if #categories == 0 then
            return
        end
        
        -- Create category buttons
        local yOffset = -FRAME_PADDING
        for i = 1, #categories do
            local isSelected = (i == selectedCategoryIndex)
            local button = CreateCategoryButton(leftContentFrame, categories[i], i, yOffset, isSelected, leftPaneWidth)
            
            -- Click handler
            button:SetScript("OnClick", function()
                selectedCategoryIndex = i
                UpdateLeftPane()
                UpdateRightPane()
            end)
            
            yOffset = yOffset - REP_TAB_HEIGHT - REP_TAB_SPACING
        end
        
        -- Update left content frame height
        local totalHeight = math.abs(yOffset) + FRAME_PADDING
        leftContentFrame:SetHeight(math.max(totalHeight, leftPane:GetHeight()))
    end
    
    -- Main update function
    local function UpdateCurrency()
        CollectCategories()
        UpdateLeftPane()
        UpdateRightPane()
    end
    
    -- Right scroll bar script
    rightScrollBar:SetScript("OnValueChanged", function(self, value)
        rightScrollFrame:SetVerticalScroll(value)
    end)
    
    -- Mouse wheel scrolling for right pane
    rightScrollFrame:EnableMouseWheel(true)
    rightScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local minValue, maxValue = rightScrollBar:GetMinMaxValues()
        local currentValue = rightScrollBar:GetValue()
        local newValue = math.max(minValue, math.min(maxValue, currentValue - (delta * 30)))
        rightScrollBar:SetValue(newValue)
    end)
    
    -- Mouse wheel scrolling for left pane
    leftScrollFrame:EnableMouseWheel(true)
    leftScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        -- Could add left pane scrolling if needed
    end)
    
    -- Store update function
    local container = CreateFrame("Frame", nil, currencyContent)
    container.UpdateCurrency = UpdateCurrency
    parentFrame.currencyContainer = container
    
    -- Initial update
    UpdateCurrency()
end

-- Create reputation pane
local function CreateReputationPane(reputationContent, parentFrame)
    -- Calculate pane widths (split 40/60 with spacing between)
    local totalWidth = reputationContent:GetWidth()
    local paneSpacing = 5  -- Reduced spacing
    local availableWidth = totalWidth - paneSpacing
    local leftPaneWidth = availableWidth * 0.4
    local rightPaneWidth = availableWidth * 0.6
    
    -- Left pane: Expansion list
    local leftPane = CreateFrame("Frame", nil, reputationContent)
    leftPane:SetWidth(leftPaneWidth)
    leftPane:SetPoint("TOPLEFT", reputationContent, "TOPLEFT", 0, 0)
    leftPane:SetPoint("BOTTOMLEFT", reputationContent, "BOTTOMLEFT", 0, 0)
    
    -- Left pane scroll frame
    local leftScrollFrame = CreateFrame("ScrollFrame", nil, leftPane)
    leftScrollFrame:SetPoint("TOPLEFT", leftPane, "TOPLEFT", 0, 0)
    leftScrollFrame:SetPoint("BOTTOMRIGHT", leftPane, "BOTTOMRIGHT", 0, 0)
    
    local leftContentFrame = CreateFrame("Frame", nil, leftScrollFrame)
    leftContentFrame:SetWidth(leftPaneWidth)
    leftScrollFrame:SetScrollChild(leftContentFrame)
    
    -- Right pane: Reputation list
    local rightPane = CreateFrame("Frame", nil, reputationContent)
    rightPane:SetWidth(rightPaneWidth)
    rightPane:SetPoint("TOPLEFT", leftPane, "TOPRIGHT", paneSpacing, 0)
    rightPane:SetPoint("BOTTOMRIGHT", reputationContent, "BOTTOMRIGHT", 0, 0)
    
    -- Right pane scroll frame
    local rightScrollFrame = CreateFrame("ScrollFrame", nil, rightPane)
    rightScrollFrame:SetPoint("TOPLEFT", rightPane, "TOPLEFT", 0, 0)
    rightScrollFrame:SetPoint("BOTTOMRIGHT", rightPane, "BOTTOMRIGHT", 0, 0)
    
    local rightContentFrame = CreateFrame("Frame", nil, rightScrollFrame)
    rightContentFrame:SetWidth(rightPaneWidth)
    rightScrollFrame:SetScrollChild(rightContentFrame)
    
    -- Right pane scroll bar
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
    
    -- Track selected expansion (default to first)
    local selectedExpansionIndex = 1
    local expansions = {}
    
    -- Function to collect expansions and their reputations
    local function CollectExpansions()
        expansions = {}
        local numFactions = C_Reputation.GetNumFactions()
        local i = 1
        
        -- First pass: expand all headers to ensure we can see all children
        local needsRefresh = false
        for j = 1, numFactions do
            local checkData = C_Reputation.GetFactionDataByIndex(j)
            if checkData and checkData.isHeader and checkData.isCollapsed then
                C_Reputation.ExpandFactionHeader(j)
                needsRefresh = true
            end
        end
        
        -- If we expanded any headers, refresh the faction list
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
            
            -- Top-level header (not a child) - start a new expansion
            if factionData.isHeader and not factionData.isChild then
                local expansionData = {
                    headerIndex = i,
                    headerData = factionData,
                    name = factionData.name,
                    reputations = {}
                }
                
                -- Collect everything until next top-level header
                i = i + 1
                while i <= numFactions do
                    local nextData = C_Reputation.GetFactionDataByIndex(i)
                    if not nextData then
                        break
                    end
                    -- Stop if we hit another top-level header
                    if nextData.isHeader and not nextData.isChild then
                        break
                    end
                    -- Add everything else (children and top-level factions) to this expansion
                    table.insert(expansionData.reputations, nextData)
                    i = i + 1
                end
                
                table.insert(expansions, expansionData)
            elseif not factionData.isHeader and not factionData.isChild then
                -- Top-level faction before any header - create an "Other" expansion
                local expansionData = {
                    headerIndex = nil,
                    headerData = nil,
                    name = "Other",
                    reputations = {factionData}
                }
                i = i + 1
                -- Collect any following top-level factions until we hit a header
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
                -- Skip (shouldn't happen at top level)
                i = i + 1
            end
        end
        
        -- Ensure we have at least one expansion selected
        if selectedExpansionIndex < 1 or selectedExpansionIndex > #expansions then
            selectedExpansionIndex = 1
        end
    end
    
    -- Create expansion button for left pane
    local function CreateExpansionButton(parent, expansionData, index, yOffset, isSelected, paneWidth)
        local button = CreateFrame("Button", nil, parent)
        button:SetHeight(REP_TAB_HEIGHT)
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", FRAME_PADDING, yOffset)
        button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -FRAME_PADDING, yOffset)
        
        -- Button background
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(button)
        if isSelected then
            bg:SetColorTexture(0.3, 0.5, 0.7, 0.9)  -- Highlighted
        else
            bg:SetColorTexture(0.15, 0.15, 0.15, 0.7)  -- Normal
        end
        button.bg = bg
        
        -- Button border
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
        
        -- Button text (with truncation for long names)
        local buttonText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        buttonText:SetPoint("LEFT", button, "LEFT", 10, 0)
        buttonText:SetPoint("RIGHT", button, "RIGHT", -10, 0)
        buttonText:SetJustifyH("LEFT")
        buttonText:SetNonSpaceWrap(false)
        
        -- Truncate text if too long - use a helper function
        local expansionName = expansionData.name or ""
        local function TruncateText(text, maxChars)
            if #text <= maxChars then
                return text
            end
            return text:sub(1, maxChars - 3) .. "..."
        end
        
        -- Estimate max characters based on button width (rough estimate: ~8 pixels per character)
        local estimatedMaxChars = math.floor((paneWidth - 20) / 8)  -- Account for padding
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
    
    -- Update right pane (reputations list) - defined first so UpdateLeftPane can call it
    local function UpdateRightPane()
        -- Clear existing entries
        local children = {rightContentFrame:GetChildren()}
        for _, child in ipairs(children) do
            child:Hide()
            child:SetParent(nil)
        end
        
        if #expansions == 0 or selectedExpansionIndex < 1 or selectedExpansionIndex > #expansions then
            return
        end
        
        local selectedExpansion = expansions[selectedExpansionIndex]
        if not selectedExpansion then
            return
        end
        
        -- Create reputation entries
        -- Use minimal padding to balance margins across the entire UI
        local leftPadding = 5  -- Small left margin to bring bars closer to expansion tabs
        local scrollBarWidth = 20
        local rightPadding = 5 + scrollBarWidth  -- Small right margin + scrollbar
        
        -- Sort reputations: normal reps first, then headers with children
        local normalReps = {}
        local headerGroups = {}
        local currentHeaderGroup = nil
        
        for _, repData in ipairs(selectedExpansion.reputations) do
            if repData.isHeader then
                -- Start a new header group
                if currentHeaderGroup then
                    table.insert(headerGroups, currentHeaderGroup)
                end
                currentHeaderGroup = {
                    header = repData,
                    children = {}
                }
            else
                -- Reputation entry - check if it's a child or a normal rep
                if repData.isChild then
                    -- This is a child of a header - add to current header group
                    if currentHeaderGroup then
                        table.insert(currentHeaderGroup.children, repData)
                    else
                        -- Orphaned child (shouldn't happen, but handle it)
                        table.insert(normalReps, repData)
                    end
                else
                    -- This is a normal (top-level) rep - close any current header group and add to normal reps
                    if currentHeaderGroup then
                        table.insert(headerGroups, currentHeaderGroup)
                        currentHeaderGroup = nil
                    end
                    table.insert(normalReps, repData)
                end
            end
        end
        
        -- Add the last header group if it exists
        if currentHeaderGroup then
            table.insert(headerGroups, currentHeaderGroup)
        end
        
        -- Display: normal reps first, then header groups
        local yOffset = -FRAME_PADDING
        
        -- Display fake expansion header above normal reps (if there are any normal reps)
        if #normalReps > 0 then
            local fakeFactionData = {
                name = selectedExpansion.name,
                isHeader = true,
                isChild = false,
                factionID = 0
            }
            local expansionHeader = CreateReputationHeader(rightContentFrame, fakeFactionData, yOffset, true, leftPadding, rightPadding)
            yOffset = yOffset - REP_HEADER_HEIGHT
        end
        
        -- Display normal reputations first
        for _, repData in ipairs(normalReps) do
            local isChild = repData.isChild or false
            local entry = CreateReputationEntry(rightContentFrame, repData, yOffset, isChild, leftPadding, rightPadding)
            UpdateReputationEntry(entry)
            yOffset = yOffset - REP_ENTRY_HEIGHT
        end
        
        -- Display header groups (headers with their children)
        for _, group in ipairs(headerGroups) do
            -- Add extra margin before header (4x base spacing = ~16 pixels)
            local headerSpacing = 16  -- 4x a base spacing of 4 pixels
            yOffset = yOffset - headerSpacing
            -- Display the header
            local header = CreateReputationHeader(rightContentFrame, group.header, yOffset, true, leftPadding, rightPadding)
            yOffset = yOffset - REP_HEADER_HEIGHT
            
            -- Display the header's children
            for _, repData in ipairs(group.children) do
                local isChild = repData.isChild or false
                local entry = CreateReputationEntry(rightContentFrame, repData, yOffset, isChild, leftPadding, rightPadding)
                UpdateReputationEntry(entry)
                yOffset = yOffset - REP_ENTRY_HEIGHT
            end
        end
        
        -- Update right content frame height
        local totalHeight = math.abs(yOffset) + FRAME_PADDING
        rightContentFrame:SetHeight(math.max(totalHeight, rightPane:GetHeight()))
        
        -- Update scroll bar (always hidden, but keep it functional for scrolling)
        local maxScroll = math.max(0, totalHeight - rightPane:GetHeight())
        rightScrollBar:SetMinMaxValues(0, maxScroll)
        rightScrollBar:Hide()  -- Always hide the scrollbar
    end
    
    -- Update left pane (expansions list)
    local function UpdateLeftPane()
        -- Clear existing buttons
        local children = {leftContentFrame:GetChildren()}
        for _, child in ipairs(children) do
            child:Hide()
            child:SetParent(nil)
        end
        
        if #expansions == 0 then
            return
        end
        
        -- Create expansion buttons
        local yOffset = -FRAME_PADDING
        for i = 1, #expansions do
            local isSelected = (i == selectedExpansionIndex)
            local button = CreateExpansionButton(leftContentFrame, expansions[i], i, yOffset, isSelected, leftPaneWidth)
            
            -- Click handler
            button:SetScript("OnClick", function()
                selectedExpansionIndex = i
                UpdateLeftPane()
                UpdateRightPane()
            end)
            
            yOffset = yOffset - REP_TAB_HEIGHT - REP_TAB_SPACING
        end
        
        -- Update left content frame height
        local totalHeight = math.abs(yOffset) + FRAME_PADDING
        leftContentFrame:SetHeight(math.max(totalHeight, leftPane:GetHeight()))
    end
    
    -- Main update function
    local function UpdateReputation()
        CollectExpansions()
        UpdateLeftPane()
        UpdateRightPane()
    end
    
    -- Right scroll bar script
    rightScrollBar:SetScript("OnValueChanged", function(self, value)
        rightScrollFrame:SetVerticalScroll(value)
    end)
    
    -- Mouse wheel scrolling for right pane (scrollbar is hidden but functional)
    rightScrollFrame:EnableMouseWheel(true)
    rightScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local minValue, maxValue = rightScrollBar:GetMinMaxValues()
        local currentValue = rightScrollBar:GetValue()
        local newValue = math.max(minValue, math.min(maxValue, currentValue - (delta * 30)))
        rightScrollBar:SetValue(newValue)
    end)
    
    -- Mouse wheel scrolling for left pane
    leftScrollFrame:EnableMouseWheel(true)
    leftScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        -- Could add left pane scrolling if needed
    end)
    
    -- Store update function
    local container = CreateFrame("Frame", nil, reputationContent)
    container.UpdateReputation = UpdateReputation
    parentFrame.reputationContainer = container
    
    -- Initial update
    UpdateReputation()
end

-- Update equipment slot
local function UpdateEquipmentSlot(slot)
    local textureName = GetInventoryItemTexture("player", slot.slotID)
    
    if textureName then
        slot.itemTexture:SetTexture(textureName)
        slot.itemTexture:Show()
        
        -- Quality border color
        local itemLink = GetInventoryItemLink("player", slot.slotID)
        if itemLink then
            local _, _, quality = GetItemInfo(itemLink)
            if quality and quality > 0 then
                local r, g, b = GetItemQualityColor(quality)
                slot.border:SetVertexColor(r, g, b, 1)
            else
                slot.border:SetVertexColor(1, 1, 1, 1)
            end
        else
            slot.border:SetVertexColor(1, 1, 1, 1)
        end
        
        -- Check if item is broken or unusable
        if GetInventoryItemBroken("player", slot.slotID) or GetInventoryItemEquippedUnusable("player", slot.slotID) then
            slot.itemTexture:SetVertexColor(0.9, 0, 0)
        else
            slot.itemTexture:SetVertexColor(1, 1, 1)
        end
    else
        slot.itemTexture:Hide()
        slot.border:SetVertexColor(1, 1, 1, 1)
    end
end

-- Create the main character frame
local function CreateCharacterFrame()
    local frame = CreateFrame("Frame", "SteamDeckCharacterFrame", UIParent)
    
    -- Calculate model size for this frame (top half of screen)
    local modelSize = GetModelSize()
    
    -- Calculate frame width - wider to accommodate larger model and slots
    -- Left slot area: FRAME_PADDING + SLOT_SIZE
    -- Right slot area: FRAME_PADDING + SLOT_SIZE  
    -- Model in center
    local leftSlotArea = FRAME_PADDING + SLOT_SIZE + 10  -- Extra spacing
    local rightSlotArea = FRAME_PADDING + SLOT_SIZE + 10  -- Extra spacing
    local frameWidth = leftSlotArea + modelSize + rightSlotArea
    frame:SetWidth(frameWidth)
    
    -- Calculate model center position to be centered between left and right slots
    local leftSlotsEnd = leftSlotArea
    local rightSlotsStart = frameWidth - rightSlotArea
    local modelCenterX = (leftSlotsEnd + rightSlotsStart) / 2
    local modelLeftX = modelCenterX - (modelSize / 2)  -- Model's left edge position
    
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
        -- Set up model scene when frame is shown
        if modelScene and modelScene.SetupModel then
            modelScene:SetupModel()
        end
        -- Update stats when frame is shown
        if frame.statsContainer and frame.statsContainer.UpdateStats then
            frame.statsContainer:UpdateStats()
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
    
    -- Create tabs
    local totalTabWidth = 0
    for i, tabData in ipairs(tabs) do
        local tabButton = CreateFrame("Button", nil, tabContainer)
        tabButton:SetHeight(TAB_HEIGHT)
        
        -- Calculate tab width based on text
        local fontString = tabButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fontString:SetText(tabData.text)
        local textWidth = fontString:GetStringWidth()
        local tabWidth = textWidth + (TAB_PADDING * 2)
        tabButton:SetWidth(tabWidth)
        
        -- Position tabs (centered)
        if i == 1 then
            -- First tab: calculate total width and center
            totalTabWidth = tabWidth
            for j = 2, #tabs do
                local tempFont = tabButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                tempFont:SetText(tabs[j].text)
                totalTabWidth = totalTabWidth + tempFont:GetStringWidth() + (TAB_PADDING * 2) + TAB_SPACING
            end
            local startX = (tabContainer:GetWidth() - totalTabWidth) / 2
            tabButton:SetPoint("TOPLEFT", tabContainer, "TOPLEFT", startX, 0)
        else
            -- Subsequent tabs
            tabButton:SetPoint("TOPLEFT", frame.tabButtons[i - 1], "TOPRIGHT", TAB_SPACING, 0)
        end
        
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
                -- Update reputation when switching to reputation tab
                if tabId == "Reputation" and self.reputationContainer then
                    self.reputationContainer:UpdateReputation()
                end
                -- Update currencies when switching to currencies tab
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
    
    -- Get Equipment tab content frame
    local equipmentContent = frame.tabContentFrames["Equipment"]
    
    -- Create background for the model (centered, top half)
    local modelBackground = equipmentContent:CreateTexture(nil, "BACKGROUND")
    modelBackground:SetSize(modelSize, modelSize)
    modelBackground:SetPoint("TOPLEFT", equipmentContent, "TOPLEFT", modelLeftX, -MODEL_TOP_OFFSET_Y)
    modelBackground:SetColorTexture(0.1, 0.1, 0.1, 0.9) -- Dark background
    
    -- Create border around the model background (4 edges)
    local borderThickness = 2
    local borderColor = {0.7, 0.7, 0.7, 0.8} -- Light grey
    
    -- Top border
    local borderTop = equipmentContent:CreateTexture(nil, "BORDER")
    borderTop:SetSize(modelSize, borderThickness)
    borderTop:SetPoint("TOPLEFT", modelBackground, "TOPLEFT", 0, borderThickness)
    borderTop:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    -- Bottom border
    local borderBottom = equipmentContent:CreateTexture(nil, "BORDER")
    borderBottom:SetSize(modelSize, borderThickness)
    borderBottom:SetPoint("BOTTOMLEFT", modelBackground, "BOTTOMLEFT", 0, -borderThickness)
    borderBottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    -- Left border
    local borderLeft = equipmentContent:CreateTexture(nil, "BORDER")
    borderLeft:SetSize(borderThickness, modelSize)
    borderLeft:SetPoint("TOPLEFT", modelBackground, "TOPLEFT", -borderThickness, 0)
    borderLeft:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    -- Right border
    local borderRight = equipmentContent:CreateTexture(nil, "BORDER")
    borderRight:SetSize(borderThickness, modelSize)
    borderRight:SetPoint("TOPRIGHT", modelBackground, "TOPRIGHT", borderThickness, 0)
    borderRight:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    -- Create PlayerModel frame for character model (centered, top half)
    -- PlayerModel frames support SetUnit and are easier to work with
    modelScene = CreateFrame("PlayerModel", "SteamDeckCharacterModel", equipmentContent)
    modelScene:SetSize(modelSize, modelSize)
    modelScene:SetPoint("TOPLEFT", equipmentContent, "TOPLEFT", modelLeftX, -MODEL_TOP_OFFSET_Y)
    
    -- Set up the model
    local function SetupModelScene()
        -- Ensure model is shown
        if not modelScene:IsShown() then
            modelScene:Show()
        end
        
        -- Try to handle shapeshift forms if available
        local form = GetShapeshiftFormID()
        if form and C_PlayerInfo and C_PlayerInfo.GetDisplayID then
            local creatureDisplayID = C_PlayerInfo.GetDisplayID()
            if creatureDisplayID ~= 0 and not UnitOnTaxi("player") then
                local nativeDisplayID = C_PlayerInfo.GetNativeDisplayID()
                local displayIDIsNative = (creatureDisplayID == nativeDisplayID)
                local displayRaceIsNative = C_PlayerInfo.IsDisplayRaceNative()
                local isMirrorImage = C_PlayerInfo.IsMirrorImage()
                local useShapeshiftDisplayID = (not displayIDIsNative and not isMirrorImage and displayRaceIsNative)
                
                if useShapeshiftDisplayID then
                    modelScene:SetCreatureDisplayID(creatureDisplayID)
                    return
                end
            end
        end
        
        -- Standard player model setup
        local inAlternateForm = C_PlayerInfo and C_PlayerInfo.GetAlternateFormInfo and select(2, C_PlayerInfo.GetAlternateFormInfo()) or false
        local useNativeForm = not inAlternateForm
        
        -- Use SetUnit for PlayerModel frames
        -- Parameters: unit, sheatheWeapon (optional), useNativeForm (optional)
        modelScene:SetUnit("player", false, useNativeForm)
    end
    
    -- Store setup function for later use
    modelScene.SetupModel = SetupModelScene
    
    -- Create equipment slots in default UI layout
    -- Position slots to align with the larger model
    -- Left side slots - positioned to align with model top
    local leftStartX = FRAME_PADDING
    local leftStartY = -MODEL_TOP_OFFSET_Y + 2
    local previousLeftSlot = nil
    
    for i, slotName in ipairs(LEFT_SLOTS) do
        local slot = CreateEquipmentSlot(equipmentContent, slotName, i)
        table.insert(equipmentSlots, slot)
        
        if i == 1 then
            -- First slot anchored to content frame, aligned with model top
            slot:SetPoint("TOPLEFT", equipmentContent, "TOPLEFT", leftStartX, leftStartY)
        else
            -- Subsequent slots anchored below previous
            slot:SetPoint("TOPLEFT", previousLeftSlot, "BOTTOMLEFT", 0, -SLOT_SPACING)
        end
        previousLeftSlot = slot
    end
    
    -- Right side slots - positioned to align with model top
    local rightStartY = -MODEL_TOP_OFFSET_Y + 2
    local previousRightSlot = nil
    
    for i, slotName in ipairs(RIGHT_SLOTS) do
        local slot = CreateEquipmentSlot(equipmentContent, slotName, #LEFT_SLOTS + i)
        table.insert(equipmentSlots, slot)
        
        if i == 1 then
            -- First slot anchored to content frame top-right, aligned with model top
            slot:SetPoint("TOPRIGHT", equipmentContent, "TOPRIGHT", -FRAME_PADDING, rightStartY)
        else
            -- Subsequent slots anchored below previous (using TOPLEFT to align left edge)
            slot:SetPoint("TOPLEFT", previousRightSlot, "BOTTOMLEFT", 0, -SLOT_SPACING)
        end
        previousRightSlot = slot
    end
    
    -- Bottom slots (weapons) - positioned just below the model
    -- Center them horizontally with the model
    local bottomMainHandX = modelCenterX - SLOT_SIZE - (SLOT_SPACING / 2)  -- Center main hand below model
    -- Calculate Y position: model bottom + small gap
    local weaponSlotY = -MODEL_TOP_OFFSET_Y - modelSize - SLOT_SPACING  -- Just below model
    
    for i, slotName in ipairs(BOTTOM_SLOTS) do
        local slot = CreateEquipmentSlot(equipmentContent, slotName, #LEFT_SLOTS + #RIGHT_SLOTS + i)
        table.insert(equipmentSlots, slot)
        
        if i == 1 then
            -- Main hand slot - centered below model
            slot:SetPoint("TOPLEFT", equipmentContent, "TOPLEFT", bottomMainHandX, weaponSlotY)
        else
            -- Off hand slot to the right of main hand
            slot:SetPoint("TOPLEFT", equipmentSlots[#equipmentSlots - 1], "TOPRIGHT", 5, 0)
        end
    end
    
    frame.modelScene = modelScene
    frame.slotContainer = slotContainer
    
    -- Create stats section in bottom half
    local statsContainer = CreateFrame("Frame", nil, equipmentContent)
    local modelBottom = -MODEL_TOP_OFFSET_Y - modelSize - SLOT_SPACING - SLOT_SIZE - 20  -- Below weapon slots
    statsContainer:SetPoint("TOPLEFT", equipmentContent, "TOPLEFT", FRAME_PADDING, modelBottom)
    statsContainer:SetPoint("BOTTOMRIGHT", equipmentContent, "BOTTOMRIGHT", -FRAME_PADDING, FRAME_PADDING)
    
    -- Store frame width for column calculations
    statsContainer.frameWidth = frameWidth
    
    -- Stats update function
    local function UpdateStats()
        if not statsContainer:IsShown() then
            return
        end
        
        -- Item Level
        local avgItemLevel, avgItemLevelEquipped = GetAverageItemLevel()
        local displayItemLevel = math.max(C_PaperDollInfo.GetMinItemLevel() or 0, avgItemLevelEquipped or 0)
        statsContainer.itemLevelValue:SetText(math.floor(displayItemLevel))
        
        -- Get primary stat based on spec
        local spec = C_SpecializationInfo.GetSpecialization()
        local primaryStat = nil
        if spec then
            primaryStat = select(6, C_SpecializationInfo.GetSpecializationInfo(spec, false, false, nil, UnitSex("player")))
        end
        
        -- Attributes
        local strStat, strEffective = UnitStat("player", LE_UNIT_STAT_STRENGTH)
        local agiStat, agiEffective = UnitStat("player", LE_UNIT_STAT_AGILITY)
        local intStat, intEffective = UnitStat("player", LE_UNIT_STAT_INTELLECT)
        local staStat, staEffective = UnitStat("player", LE_UNIT_STAT_STAMINA)
        
        -- Display primary stat
        -- Get stat names using the same method as Blizzard
        local statName = nil
        local statValue = 0
        
        if primaryStat == LE_UNIT_STAT_STRENGTH then
            statName = _G["SPELL_STAT"..LE_UNIT_STAT_STRENGTH.."_NAME"] or "Strength"
            statValue = strEffective
        elseif primaryStat == LE_UNIT_STAT_AGILITY then
            statName = _G["SPELL_STAT"..LE_UNIT_STAT_AGILITY.."_NAME"] or "Agility"
            statValue = agiEffective
        elseif primaryStat == LE_UNIT_STAT_INTELLECT then
            statName = _G["SPELL_STAT"..LE_UNIT_STAT_INTELLECT.."_NAME"] or "Intellect"
            statValue = intEffective
        else
            -- Fallback to highest stat
            if strEffective >= agiEffective and strEffective >= intEffective then
                statName = _G["SPELL_STAT"..LE_UNIT_STAT_STRENGTH.."_NAME"] or "Strength"
                statValue = strEffective
            elseif agiEffective >= intEffective then
                statName = _G["SPELL_STAT"..LE_UNIT_STAT_AGILITY.."_NAME"] or "Agility"
                statValue = agiEffective
            else
                statName = _G["SPELL_STAT"..LE_UNIT_STAT_INTELLECT.."_NAME"] or "Intellect"
                statValue = intEffective
            end
        end
        
        statsContainer.primaryStatLabel:SetText(statName or "Primary Stat")
        statsContainer.primaryStatValue:SetText(FormatNumber(statValue))
        
        statsContainer.staminaValue:SetText(FormatNumber(staEffective))
        
        local baselineArmor, effectiveArmor = UnitArmor("player")
        statsContainer.armorValue:SetText(FormatNumber(effectiveArmor))
        
        -- Movement Speed
        local _, runSpeed = GetUnitSpeed("player")
        local speedPercent = math.floor((runSpeed / BASE_MOVEMENT_SPEED * 100) + 0.5)
        statsContainer.movementSpeedValue:SetText(speedPercent .. "%")
        
        -- Enhancements
        local critChance = GetCritChance()
        local spellCrit = GetSpellCritChance(2)  -- Start with holy school
        for i = 3, 7 do
            spellCrit = math.min(spellCrit, GetSpellCritChance(i))
        end
        local rangedCrit = GetRangedCritChance()
        critChance = math.max(critChance, spellCrit, rangedCrit)
        local critText = string.format("%.1f%%", critChance)
        statsContainer.critValue:SetText(RemoveTrailingZeros(critText))
        
        local haste = GetHaste()
        local hasteText = string.format("%.1f%%", haste)
        statsContainer.hasteValue:SetText(RemoveTrailingZeros(hasteText))
        
        local mastery = GetMasteryEffect()
        local masteryText = string.format("%.1f%%", mastery)
        statsContainer.masteryValue:SetText(RemoveTrailingZeros(masteryText))
        
        -- Versatility: GetCombatRatingBonus + GetVersatilityBonus
        local versatilityDamageBonus = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)
        local versText = string.format("%.1f%%", versatilityDamageBonus)
        statsContainer.versValue:SetText(RemoveTrailingZeros(versText))
    end
    
    -- Helper function to create category headers with background (larger font)
    local function CreateStatCategoryHeader(parent, text, yOffset, width)
        local headerFrame = CreateFrame("Frame", nil, parent)
        headerFrame:SetHeight(STAT_HEADER_HEIGHT)
        if width then
            headerFrame:SetWidth(width)
            headerFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
        else
            headerFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
            headerFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
        end
        
        -- Background
        local bg = headerFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(headerFrame)
        bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
        
        -- Title text (larger font)
        local title = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("LEFT", headerFrame, "LEFT", 5, 0)
        title:SetText(text)
        title:SetTextColor(1, 1, 1, 1)
        
        return headerFrame
    end
    
    -- Calculate column widths for two-column layout
    local containerWidth = statsContainer.frameWidth - (2 * FRAME_PADDING)
    local columnWidth = (containerWidth - STAT_CATEGORY_SPACING) / 2
    local leftColumnX = 0
    local rightColumnX = columnWidth + STAT_CATEGORY_SPACING
    
    -- Create stat rows with two-column layout
    local statYOffset = 0
    
    -- Item Level header (full width at top)
    local itemLevelHeader = CreateStatCategoryHeader(statsContainer, "Item Level", statYOffset)
    statYOffset = statYOffset - STAT_HEADER_HEIGHT - STAT_ITEM_SPACING
    
    local itemLevelValue = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    itemLevelValue:SetPoint("TOPRIGHT", statsContainer, "TOPRIGHT", -10, statYOffset)
    itemLevelValue:SetJustifyH("RIGHT")
    itemLevelValue:SetText("0")
    statsContainer.itemLevelValue = itemLevelValue
    statYOffset = statYOffset - STAT_ITEM_SPACING
    
    -- Add margin before next category
    statYOffset = statYOffset - STAT_CATEGORY_SPACING
    
    -- Two-column layout starts here
    local leftColumnY = statYOffset
    local rightColumnY = statYOffset
    
    -- Left column: Attributes header
    local attributesHeader = CreateStatCategoryHeader(statsContainer, "Attributes", leftColumnY, columnWidth)
    leftColumnY = leftColumnY - STAT_HEADER_HEIGHT - STAT_ITEM_SPACING
    
    -- Primary Stat (left column)
    local primaryStatLabel = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    primaryStatLabel:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", leftColumnX + 10, leftColumnY)
    primaryStatLabel:SetText("Primary Stat")
    primaryStatLabel:SetTextColor(0.8, 0.8, 0.8, 1)
    statsContainer.primaryStatLabel = primaryStatLabel
    
    local primaryStatValue = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    primaryStatValue:SetPoint("TOPRIGHT", statsContainer, "TOPLEFT", leftColumnX + columnWidth - 10, leftColumnY)
    primaryStatValue:SetJustifyH("RIGHT")
    primaryStatValue:SetText("0")
    statsContainer.primaryStatValue = primaryStatValue
    leftColumnY = leftColumnY - STAT_ITEM_SPACING
    
    -- Stamina (left column)
    local staminaLabel = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    staminaLabel:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", leftColumnX + 10, leftColumnY)
    staminaLabel:SetText("Stamina")
    staminaLabel:SetTextColor(0.8, 0.8, 0.8, 1)
    
    local staminaValue = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    staminaValue:SetPoint("TOPRIGHT", statsContainer, "TOPLEFT", leftColumnX + columnWidth - 10, leftColumnY)
    staminaValue:SetJustifyH("RIGHT")
    staminaValue:SetText("0")
    statsContainer.staminaValue = staminaValue
    leftColumnY = leftColumnY - STAT_ITEM_SPACING
    
    -- Armor (left column)
    local armorLabel = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    armorLabel:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", leftColumnX + 10, leftColumnY)
    armorLabel:SetText("Armor")
    armorLabel:SetTextColor(0.8, 0.8, 0.8, 1)
    
    local armorValue = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    armorValue:SetPoint("TOPRIGHT", statsContainer, "TOPLEFT", leftColumnX + columnWidth - 10, leftColumnY)
    armorValue:SetJustifyH("RIGHT")
    armorValue:SetText("0")
    statsContainer.armorValue = armorValue
    leftColumnY = leftColumnY - STAT_ITEM_SPACING
    
    -- Movement Speed (left column)
    local movementSpeedLabel = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    movementSpeedLabel:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", leftColumnX + 10, leftColumnY)
    movementSpeedLabel:SetText("Movement Speed")
    movementSpeedLabel:SetTextColor(0.8, 0.8, 0.8, 1)
    
    local movementSpeedValue = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    movementSpeedValue:SetPoint("TOPRIGHT", statsContainer, "TOPLEFT", leftColumnX + columnWidth - 10, leftColumnY)
    movementSpeedValue:SetJustifyH("RIGHT")
    movementSpeedValue:SetText("0%")
    statsContainer.movementSpeedValue = movementSpeedValue
    
    -- Right column: Enhancements header
    local enhancementsHeader = CreateStatCategoryHeader(statsContainer, "Enhancements", rightColumnY, columnWidth)
    enhancementsHeader:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", rightColumnX, rightColumnY)
    rightColumnY = rightColumnY - STAT_HEADER_HEIGHT - STAT_ITEM_SPACING
    
    -- Crit (right column)
    local critLabel = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    critLabel:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", rightColumnX + 10, rightColumnY)
    critLabel:SetText("Critical Strike")
    critLabel:SetTextColor(0.8, 0.8, 0.8, 1)
    
    local critValue = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    critValue:SetPoint("TOPRIGHT", statsContainer, "TOPRIGHT", -10, rightColumnY)
    critValue:SetJustifyH("RIGHT")
    critValue:SetText("0.0%")
    statsContainer.critValue = critValue
    rightColumnY = rightColumnY - STAT_ITEM_SPACING
    
    -- Haste (right column)
    local hasteLabel = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hasteLabel:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", rightColumnX + 10, rightColumnY)
    hasteLabel:SetText("Haste")
    hasteLabel:SetTextColor(0.8, 0.8, 0.8, 1)
    
    local hasteValue = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    hasteValue:SetPoint("TOPRIGHT", statsContainer, "TOPRIGHT", -10, rightColumnY)
    hasteValue:SetJustifyH("RIGHT")
    hasteValue:SetText("0.0%")
    statsContainer.hasteValue = hasteValue
    rightColumnY = rightColumnY - STAT_ITEM_SPACING
    
    -- Mastery (right column)
    local masteryLabel = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    masteryLabel:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", rightColumnX + 10, rightColumnY)
    masteryLabel:SetText("Mastery")
    masteryLabel:SetTextColor(0.8, 0.8, 0.8, 1)
    
    local masteryValue = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    masteryValue:SetPoint("TOPRIGHT", statsContainer, "TOPRIGHT", -10, rightColumnY)
    masteryValue:SetJustifyH("RIGHT")
    masteryValue:SetText("0.0%")
    statsContainer.masteryValue = masteryValue
    rightColumnY = rightColumnY - STAT_ITEM_SPACING
    
    -- Versatility (right column)
    local versLabel = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    versLabel:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", rightColumnX + 10, rightColumnY)
    versLabel:SetText("Versatility")
    versLabel:SetTextColor(0.8, 0.8, 0.8, 1)
    
    local versValue = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    versValue:SetPoint("TOPRIGHT", statsContainer, "TOPRIGHT", -10, rightColumnY)
    versValue:SetJustifyH("RIGHT")
    versValue:SetText("0.0%")
    statsContainer.versValue = versValue
    
    -- Store update function
    statsContainer.UpdateStats = UpdateStats
    frame.statsContainer = statsContainer
    
    -- Create reputation pane content
    local reputationContent = frame.tabContentFrames["Reputation"]
    CreateReputationPane(reputationContent, frame)
    
    -- Create currency pane content
    local currenciesContent = frame.tabContentFrames["Currencies"]
    CreateCurrencyPane(currenciesContent, frame)
    
    -- Initialize tabs (set Equipment as active)
    frame:UpdateTabs()
    
    frame:Hide()
    
    return frame
end

-- Refresh equipment slots
local function RefreshEquipment()
    if not characterFrame or not isOpen then
        return
    end
    
    for _, slot in ipairs(equipmentSlots) do
        UpdateEquipmentSlot(slot)
    end
    
    -- Update model scene
    if modelScene and modelScene.SetupModel then
        modelScene:SetupModel()
    end
    
    -- Update stats
    if characterFrame.statsContainer and characterFrame.statsContainer.UpdateStats then
        characterFrame.statsContainer:UpdateStats()
    end
end

-- Open the character frame
function CharacterModule:Open()
    if not characterFrame then
        characterFrame = CreateCharacterFrame()
    end
    
    isOpen = true
    characterFrame:Show()
    RefreshEquipment()
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
            RefreshEquipment()
                -- Update reputation if tab is active
                if activeTab == "Reputation" and characterFrame and characterFrame.reputationContainer then
                    characterFrame.reputationContainer:UpdateReputation()
                end
                -- Update currencies if tab is active
                if activeTab == "Currencies" and characterFrame and characterFrame.currencyContainer then
                    characterFrame.currencyContainer:UpdateCurrency()
                end
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

