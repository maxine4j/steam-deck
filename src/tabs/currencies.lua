-- Currencies Tab Module
-- Handles currency display with two-column layout

SteamDeckCurrenciesTab = {}
local CurrenciesTab = SteamDeckCurrenciesTab

-- Configuration
local CURRENCY_ENTRY_HEIGHT = 34
local CURRENCY_ICON_SIZE = 32
local CURRENCY_HEADER_HEIGHT = 30
local REP_TAB_HEIGHT = 45
local REP_TAB_SPACING = 2
local FRAME_PADDING = 20

-- Create currency entry
local function CreateCurrencyEntry(parent, currencyData, yOffset, leftPadding, rightPadding)
    local entry = CreateFrame("Button", nil, parent)
    entry:SetHeight(CURRENCY_ENTRY_HEIGHT)
    leftPadding = leftPadding or FRAME_PADDING
    rightPadding = rightPadding or FRAME_PADDING
    entry:SetPoint("TOPLEFT", parent, "TOPLEFT", leftPadding, yOffset)
    entry:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -rightPadding, yOffset)
    
    local icon = entry:CreateTexture(nil, "ARTWORK")
    icon:SetSize(CURRENCY_ICON_SIZE, CURRENCY_ICON_SIZE)
    icon:SetPoint("LEFT", entry, "LEFT", 0, 0)
    entry.icon = icon
    
    local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    local nameFont, nameFontSize = nameText:GetFont()
    nameText:SetFont(nameFont, nameFontSize * 0.8)
    nameText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    nameText:SetPoint("RIGHT", entry, "RIGHT", -80, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetNonSpaceWrap(false)
    nameText:SetTextColor(1, 1, 1, 1)
    entry.nameText = nameText
    
    local quantityText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    local qtyFont, qtyFontSize = quantityText:GetFont()
    quantityText:SetFont(qtyFont, qtyFontSize * 0.8)
    quantityText:SetPoint("RIGHT", entry, "RIGHT", -5, 0)
    quantityText:SetJustifyH("RIGHT")
    quantityText:SetTextColor(1, 1, 0.5, 1)
    entry.quantityText = quantityText
    
    entry.currencyData = currencyData
    entry.currencyID = currencyData.currencyID
    
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
    
    if currencyData.iconFileID and currencyData.iconFileID > 0 then
        entry.icon:SetTexture(currencyData.iconFileID)
        entry.icon:Show()
    else
        entry.icon:Hide()
    end
    
    local currencyName = currencyData.name or ""
    entry.nameText:SetText(currencyName)
    local textWidth = entry.nameText:GetStringWidth()
    local availableWidth = entry:GetWidth() - CURRENCY_ICON_SIZE - 8 - 80
    
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
local function CreateCurrencyHeader(parent, currencyData, yOffset, hasChildren, leftPadding, rightPadding, tab)
    local header = CreateFrame(hasChildren and "Frame" or "Button", nil, parent)
    header:SetHeight(CURRENCY_HEADER_HEIGHT)
    leftPadding = leftPadding or FRAME_PADDING
    rightPadding = rightPadding or FRAME_PADDING
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", leftPadding, yOffset)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -rightPadding, yOffset)
    
    local bg = header:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(header)
    bg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
    
    local nameText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    local nameFont, nameFontSize = nameText:GetFont()
    nameText:SetFont(nameFont, nameFontSize * 0.8)
    nameText:SetPoint("LEFT", header, "LEFT", 10, 0)
    nameText:SetText(currencyData.name or "")
    nameText:SetTextColor(1, 0.8, 0, 1)
    header.nameText = nameText
    
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
    
    if not hasChildren then
        header:SetScript("OnClick", function()
            if currencyData.isHeaderExpanded then
                C_CurrencyInfo.ExpandCurrencyList(currencyData.currencyIndex, false)
            else
                C_CurrencyInfo.ExpandCurrencyList(currencyData.currencyIndex, true)
            end
            if tab and tab.content and tab.content.currencyContainer and tab.content.currencyContainer.UpdateCurrency then
                tab.content.currencyContainer:UpdateCurrency()
            end
        end)
    end
    
    return header
end

-- Initialize currencies tab
function CurrenciesTab:Initialize(panel, contentFrame)
    local tab = self
    
    -- Set tab properties
    self.id = "currencies"
    self.name = "Currencies"
    self.panel = panel
    self.content = contentFrame
    
    if not self.content then
        return
    end
    
    -- Create all UI elements in the content frame
    local currencyContent = self.content
    
    local totalWidth = currencyContent:GetWidth()
    if totalWidth <= 0 then
        totalWidth = 600 - (2 * FRAME_PADDING)
    end
    local paneSpacing = 5
    local availableWidth = totalWidth - paneSpacing
    local leftPaneWidth = availableWidth * 0.35
    local rightPaneWidth = availableWidth * 0.65
    
    local leftPane = CreateFrame("Frame", nil, currencyContent)
    leftPane:SetWidth(leftPaneWidth)
    leftPane:SetPoint("TOPLEFT", currencyContent, "TOPLEFT", 0, 0)
    leftPane:SetPoint("BOTTOMLEFT", currencyContent, "BOTTOMLEFT", 0, 0)
    
    local leftScrollFrame = CreateFrame("ScrollFrame", nil, leftPane)
    leftScrollFrame:SetPoint("TOPLEFT", leftPane, "TOPLEFT", 0, 0)
    leftScrollFrame:SetPoint("BOTTOMRIGHT", leftPane, "BOTTOMRIGHT", 0, 0)
    
    local leftContentFrame = CreateFrame("Frame", nil, leftScrollFrame)
    leftContentFrame:SetWidth(leftPaneWidth)
    leftScrollFrame:SetScrollChild(leftContentFrame)
    
    local rightPane = CreateFrame("Frame", nil, currencyContent)
    rightPane:SetPoint("TOPLEFT", leftPane, "TOPRIGHT", paneSpacing, 0)
    rightPane:SetPoint("BOTTOMRIGHT", currencyContent, "BOTTOMRIGHT", 0, 0)
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
    
    local selectedCategoryIndex = 1
    local categories = {}
    
    local function CollectCategories()
        categories = {}
        local numCurrencies = C_CurrencyInfo.GetCurrencyListSize()
        local i = 1
        
        local needsRefresh = false
        for j = 1, numCurrencies do
            local checkData = C_CurrencyInfo.GetCurrencyListInfo(j)
            if checkData and checkData.isHeader and not checkData.isHeaderExpanded then
                C_CurrencyInfo.ExpandCurrencyList(j, true)
                needsRefresh = true
            end
        end
        
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
            
            if currencyData.isHeader and currencyData.currencyListDepth == 0 then
                local categoryData = {
                    headerIndex = i,
                    headerData = currencyData,
                    name = currencyData.name,
                    currencies = {}
                }
                
                i = i + 1
                while i <= numCurrencies do
                    local nextData = C_CurrencyInfo.GetCurrencyListInfo(i)
                    if not nextData then
                        break
                    end
                    if nextData.isHeader and nextData.currencyListDepth == 0 then
                        break
                    end
                    table.insert(categoryData.currencies, nextData)
                    i = i + 1
                end
                
                table.insert(categories, categoryData)
            elseif not currencyData.isHeader and currencyData.currencyListDepth == 0 then
                local categoryData = {
                    headerIndex = nil,
                    headerData = nil,
                    name = "Other",
                    currencies = {currencyData}
                }
                i = i + 1
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
        
        if legacyIndex and legacyCategoryData then
            table.remove(categories, legacyIndex)
            
            local legacyCurrencies = legacyCategoryData.currencies
            local promotedCategories = {}
            local orphanCurrencies = {}
            
            local i = 1
            while i <= #legacyCurrencies do
                local currencyData = legacyCurrencies[i]
                
                if currencyData.isHeader and currencyData.currencyListDepth == 1 then
                    local promotedCategory = {
                        headerIndex = currencyData.currencyIndex,
                        headerData = currencyData,
                        name = currencyData.name,
                        currencies = {}
                    }
                    
                    i = i + 1
                    while i <= #legacyCurrencies do
                        local nextData = legacyCurrencies[i]
                        if not nextData then
                            break
                        end
                        if nextData.currencyListDepth == 1 then
                            break
                        end
                        if nextData.currencyListDepth > 1 then
                            table.insert(promotedCategory.currencies, nextData)
                        end
                        i = i + 1
                    end
                    
                    table.insert(promotedCategories, promotedCategory)
                elseif not currencyData.isHeader and currencyData.currencyListDepth == 1 then
                    table.insert(orphanCurrencies, currencyData)
                    i = i + 1
                else
                    i = i + 1
                end
            end
            
            for _, promotedCategory in ipairs(promotedCategories) do
                table.insert(categories, promotedCategory)
            end
            
            if #orphanCurrencies > 0 then
                local otherCategoryIndex = nil
                for idx, categoryData in ipairs(categories) do
                    if categoryData.name == "Other" then
                        otherCategoryIndex = idx
                        break
                    end
                end
                
                if otherCategoryIndex then
                    for _, currencyData in ipairs(orphanCurrencies) do
                        table.insert(categories[otherCategoryIndex].currencies, currencyData)
                    end
                else
                    local otherCategory = {
                        headerIndex = nil,
                        headerData = nil,
                        name = "Other",
                        currencies = orphanCurrencies
                    }
                    table.insert(categories, otherCategory)
                end
            end
            
            if selectedCategoryIndex == legacyIndex then
                selectedCategoryIndex = 1
            elseif selectedCategoryIndex > legacyIndex then
                selectedCategoryIndex = selectedCategoryIndex - 1 + #promotedCategories
            end
        end
        
        if selectedCategoryIndex < 1 or selectedCategoryIndex > #categories then
            selectedCategoryIndex = 1
        end
    end
    
    local function CreateCategoryButton(parent, categoryData, index, yOffset, isSelected, paneWidth)
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
        
        local categoryName = categoryData.name or ""
        local function TruncateText(text, maxChars)
            if #text <= maxChars then
                return text
            end
            return text:sub(1, maxChars - 3) .. "..."
        end
        
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
    
    local function UpdateRightPane()
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
        
        local leftPadding = 5
        local rightPadding = 5
        
        local normalCurrencies = {}
        local headerGroups = {}
        local currentHeaderGroup = nil
        
        for _, currencyData in ipairs(selectedCategory.currencies) do
            if currencyData.isHeader then
                if currentHeaderGroup then
                    table.insert(headerGroups, currentHeaderGroup)
                end
                currentHeaderGroup = {
                    header = currencyData,
                    children = {}
                }
            else
                if currencyData.currencyListDepth > 0 then
                    if currentHeaderGroup then
                        table.insert(currentHeaderGroup.children, currencyData)
                    else
                        table.insert(normalCurrencies, currencyData)
                    end
                else
                    if currentHeaderGroup then
                        table.insert(headerGroups, currentHeaderGroup)
                        currentHeaderGroup = nil
                    end
                    table.insert(normalCurrencies, currencyData)
                end
            end
        end
        
        if currentHeaderGroup then
            table.insert(headerGroups, currentHeaderGroup)
        end
        
        local yOffset = -FRAME_PADDING
        
        if #normalCurrencies > 0 then
            local fakeCurrencyData = {
                name = selectedCategory.name,
                isHeader = true,
                currencyListDepth = 0,
                currencyID = 0
            }
            CreateCurrencyHeader(rightContentFrame, fakeCurrencyData, yOffset, true, leftPadding, rightPadding, tab)
            yOffset = yOffset - CURRENCY_HEADER_HEIGHT
        end
        
        for _, currencyData in ipairs(normalCurrencies) do
            local entry = CreateCurrencyEntry(rightContentFrame, currencyData, yOffset, leftPadding, rightPadding)
            UpdateCurrencyEntry(entry)
            yOffset = yOffset - CURRENCY_ENTRY_HEIGHT
        end
        
        for _, group in ipairs(headerGroups) do
            local headerSpacing = 16
            yOffset = yOffset - headerSpacing
            local header = CreateCurrencyHeader(rightContentFrame, group.header, yOffset, true, leftPadding, rightPadding, tab)
            yOffset = yOffset - CURRENCY_HEADER_HEIGHT
            
            for _, currencyData in ipairs(group.children) do
                local entry = CreateCurrencyEntry(rightContentFrame, currencyData, yOffset, leftPadding, rightPadding)
                UpdateCurrencyEntry(entry)
                yOffset = yOffset - CURRENCY_ENTRY_HEIGHT
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
        
        if #categories == 0 then
            return
        end
        
        local yOffset = -FRAME_PADDING
        for i = 1, #categories do
            local isSelected = (i == selectedCategoryIndex)
            local button = CreateCategoryButton(leftContentFrame, categories[i], i, yOffset, isSelected, leftPaneWidth)
            
            button:SetScript("OnClick", function()
                selectedCategoryIndex = i
                UpdateLeftPane()
                UpdateRightPane()
            end)
            
            yOffset = yOffset - REP_TAB_HEIGHT - REP_TAB_SPACING
        end
        
        local totalHeight = math.abs(yOffset) + FRAME_PADDING
        leftContentFrame:SetHeight(math.max(totalHeight, leftPane:GetHeight()))
    end
    
    local function UpdateCurrency()
        CollectCategories()
        UpdateLeftPane()
        UpdateRightPane()
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
    
    local container = CreateFrame("Frame", nil, currencyContent)
    container.UpdateCurrency = UpdateCurrency
    self.content.currencyContainer = container
    
    -- Register for currency update events
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    self.eventFrame:RegisterEvent("PLAYER_MONEY")
    self.eventFrame:SetScript("OnEvent", function()
        if tab.content and tab.content:IsShown() then
            UpdateCurrency()
        end
    end)
    
    UpdateCurrency()
end

-- OnShow callback
function CurrenciesTab:OnShow()
    if self.content and self.content.currencyContainer and self.content.currencyContainer.UpdateCurrency then
        self.content.currencyContainer:UpdateCurrency()
    end
end

-- OnHide callback
function CurrenciesTab:OnHide()
end

return CurrenciesTab
