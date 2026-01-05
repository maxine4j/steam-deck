-- Bags Tab Module
-- Handles bag item display and organization

SteamDeckBagsTab = {}
local BagsTab = SteamDeckBagsTab

-- Configuration
local SLOTS_PER_ROW = 8
local SLOT_SIZE = 48
local SLOT_SPACING = 4
local GRID_MARGIN = 20
local SECTION_HEADER_HEIGHT = 24
local SECTION_SPACING = 12
local CATEGORIES = {"Gear", "Tradeskills", "Consumable", "Reputation", "Quest", "Other"}

-- Create a single bag slot button
local function CreateBagSlot(parent, slotIndex)
    local slot = CreateFrame("Button", "SteamDeckBagSlot"..slotIndex, parent)
    slot:SetSize(SLOT_SIZE, SLOT_SIZE)
    
    -- Slot background
    local bg = slot:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(slot)
    bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    -- Create custom border edges
    local borderThickness = 2
    local borderColor = {0.5, 0.5, 0.5, 0.8}
    
    local borderTop = slot:CreateTexture(nil, "BORDER")
    borderTop:SetSize(SLOT_SIZE, borderThickness)
    borderTop:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", slot, "TOPRIGHT", 0, 0)
    borderTop:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    local borderBottom = slot:CreateTexture(nil, "BORDER")
    borderBottom:SetSize(SLOT_SIZE, borderThickness)
    borderBottom:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 0, 0)
    borderBottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    local borderLeft = slot:CreateTexture(nil, "BORDER")
    borderLeft:SetSize(borderThickness, SLOT_SIZE)
    borderLeft:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", 0, 0)
    borderLeft:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    local borderRight = slot:CreateTexture(nil, "BORDER")
    borderRight:SetSize(borderThickness, SLOT_SIZE)
    borderRight:SetPoint("TOPRIGHT", slot, "TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 0, 0)
    borderRight:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    slot.border = {
        top = borderTop,
        bottom = borderBottom,
        left = borderLeft,
        right = borderRight
    }
    
    -- Item texture
    local itemTexture = slot:CreateTexture(nil, "ARTWORK")
    itemTexture:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, -2)
    itemTexture:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
    itemTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    slot.itemTexture = itemTexture
    
    -- Count text
    local count = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    local countFont, countFontSize = count:GetFont()
    count:SetFont(countFont, countFontSize * 1.5, "THICKOUTLINE")
    count:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
    count:SetJustifyH("RIGHT")
    slot.count = count
    
    -- Item level text
    local itemLevelText = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    local font, fontSize = itemLevelText:GetFont()
    itemLevelText:SetFont(font, fontSize * 2, "THICKOUTLINE")
    itemLevelText:SetPoint("BOTTOM", slot, "BOTTOM", 0, 2)
    itemLevelText:SetJustifyH("CENTER")
    itemLevelText:SetTextColor(1, 1, 1, 1)
    itemLevelText:Hide()
    slot.itemLevelText = itemLevelText
    
    -- Tooltip
    slot:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        end
    end)
    slot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Click and drag handling
    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    slot:RegisterForDrag("LeftButton")
    
    slot:SetScript("OnClick", function(self, button)
        if not self.bagID or not self.slotID then
            return
        end
        
        if button == "LeftButton" then
            if SpellCanTargetItem() or SpellCanTargetItemID() then
                C_Container.UseContainerItem(self.bagID, self.slotID)
            else
                C_Container.PickupContainerItem(self.bagID, self.slotID)
            end
        elseif button == "RightButton" then
            if self.itemLink then
                C_Container.UseContainerItem(self.bagID, self.slotID)
            end
        end
    end)
    
    slot:SetScript("OnDragStart", function(self)
        if not self.bagID or not self.slotID then
            return
        end
        if SpellCanTargetItem() or SpellCanTargetItemID() then
            C_Container.UseContainerItem(self.bagID, self.slotID)
        else
            C_Container.PickupContainerItem(self.bagID, self.slotID)
        end
    end)
    
    slot:SetScript("OnReceiveDrag", function(self)
        if not self.bagID or not self.slotID then
            return
        end
        if CursorHasItem() then
            C_Container.PickupContainerItem(self.bagID, self.slotID)
        end
    end)
    
    slot.slotIndex = slotIndex
    return slot
end

-- Determine the category for an item
local function GetItemCategory(bagID, slotID, itemInfo)
    if not itemInfo or not itemInfo.hyperlink then
        return "Other"
    end
    
    local itemID = itemInfo.itemID
    if not itemID then
        return "Other"
    end
    
    local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, 
          itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expacID, setID, isCraftingReagent = 
          C_Item.GetItemInfo(itemID)
    
    if not classID then
        return "Other"
    end
    
    local questInfo = C_Container.GetContainerItemQuestInfo(bagID, slotID)
    if questInfo and questInfo.isQuestItem then
        return "Quest"
    end
    
    if itemEquipLoc and itemEquipLoc ~= "" and itemEquipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" then
        return "Gear"
    end
    
    if classID == Enum.ItemClass.Tradegoods then
        return "Tradeskills"
    end
    
    if classID == Enum.ItemClass.Consumable then
        if itemSubType == "Other" or (itemName and string.find(itemName:lower(), "reputation")) then
            return "Reputation"
        end
        return "Consumable"
    end
    
    if classID == Enum.ItemClass.Miscellaneous then
        if itemSubType == "Other" or (itemName and string.find(itemName:lower(), "reputation")) then
            return "Reputation"
        end
    end
    
    return "Other"
end

-- Create a category section header
local function CreateCategorySection(parent, categoryName)
    local section = {}
    
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(SECTION_HEADER_HEIGHT)
    section.frame = frame
    
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", frame, "LEFT", 0, 0)
    title:SetText(categoryName)
    title:SetTextColor(1, 1, 1, 1)
    section.title = title
    
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
    section.bg = bg
    
    local itemContainer = CreateFrame("Frame", nil, parent)
    section.itemContainer = itemContainer
    section.items = {}
    
    return section
end

-- Update a single slot with item data
local function UpdateSlot(slot, bagID, slotID)
    local itemInfo = C_Container.GetContainerItemInfo(bagID, slotID)
    
    if itemInfo and itemInfo.iconFileID then
        slot.itemTexture:SetTexture(itemInfo.iconFileID)
        slot.itemTexture:Show()
        
        if itemInfo.stackCount and itemInfo.stackCount > 1 then
            slot.count:SetText(itemInfo.stackCount)
            slot.count:Show()
        else
            slot.count:Hide()
        end
        
        if slot.border and type(slot.border) == "table" then
            slot.border.top:Show()
            slot.border.bottom:Show()
            slot.border.left:Show()
            slot.border.right:Show()
            
            local borderColor = {0.5, 0.5, 0.5, 0.8}
            if itemInfo.quality and itemInfo.quality > 0 then
                local r, g, b = GetItemQualityColor(itemInfo.quality)
                borderColor = {r, g, b, 1.0}
            end
            
            slot.border.top:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
            slot.border.bottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
            slot.border.left:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
            slot.border.right:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        end
        
        if slot.itemLevelText then
            local itemLink = itemInfo.hyperlink
            if itemLink then
                local itemID = itemInfo.itemID
                if itemID then
                    local _, _, _, _, _, _, _, _, itemEquipLoc = C_Item.GetItemInfo(itemID)
                    if itemEquipLoc and itemEquipLoc ~= "" and itemEquipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" then
                        local itemLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
                        if itemLevel and itemLevel > 0 then
                            slot.itemLevelText:SetText(tostring(itemLevel))
                            slot.itemLevelText:Show()
                        else
                            slot.itemLevelText:Hide()
                        end
                    else
                        slot.itemLevelText:Hide()
                    end
                else
                    slot.itemLevelText:Hide()
                end
            else
                slot.itemLevelText:Hide()
            end
        end
        
        slot.itemLink = itemInfo.hyperlink
        slot.bagID = bagID
        slot.slotID = slotID
    else
        slot.itemTexture:Hide()
        slot.count:Hide()
        if slot.itemLevelText then
            slot.itemLevelText:Hide()
        end
        if slot.border and type(slot.border) == "table" then
            slot.border.top:Show()
            slot.border.bottom:Show()
            slot.border.left:Show()
            slot.border.right:Show()
            local borderColor = {0.5, 0.5, 0.5, 0.8}
            slot.border.top:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
            slot.border.bottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
            slot.border.left:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
            slot.border.right:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        end
        slot.itemLink = nil
    end
end

-- Hide all default bag frames
local function HideAllDefaultBags()
    for i = 1, 13 do
        local frame = _G["ContainerFrame"..i]
        if frame then
            frame:UnregisterAllEvents()
            frame:Hide()
        end
    end
    
    if MainMenuBarBackpackButton then
        MainMenuBarBackpackButton:Hide()
    end
    
    for i = 0, 3 do
        local bagButton = _G["CharacterBag"..i.."Slot"]
        if bagButton then
            bagButton:Hide()
        end
    end
end

-- Override bag functions to show our panel
local function OverrideBagFunctions(panel, tabId)
    local toggleBags = function()
        if panel:IsPanelOpen() then
            panel:ClosePanel()
        else
            HideAllDefaultBags()
            panel:OpenPanelToTab(tabId)
        end
    end

    if _G.ToggleBackpack then
        _G.ToggleBackpack = toggleBags
    end
    
    if _G.OpenBackpack then
        _G.OpenBackpack = toggleBags
    end
    
    if _G.ToggleAllBags then
        _G.ToggleAllBags = toggleBags
    end
    
    if _G.ToggleBackpack_Combined then
        _G.ToggleBackpack_Combined = toggleBags
    end
    
    if _G.ToggleBackpack_Individual then
        _G.ToggleBackpack_Individual = toggleBags
    end
end

-- Refresh all bag slots
function BagsTab:Refresh()
    -- Clear existing slots and sections
    for _, slot in ipairs(self.bagSlots) do
        slot:Hide()
    end
    wipe(self.bagSlots)
    
    for _, section in pairs(self.categories) do
        if section.frame then
            section.frame:Hide()
        end
        if section.itemContainer then
            section.itemContainer:Hide()
        end
        if section.items then
            for _, slot in ipairs(section.items) do
                slot:Hide()
            end
            wipe(section.items)
        end
    end
    wipe(self.categories)
    
    -- Collect all items and categorize them
    local itemsByCategory = {}
    for bagID = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bagID) or 0
        for slotID = 1, numSlots do
            local itemInfo = C_Container.GetContainerItemInfo(bagID, slotID)
            if itemInfo and itemInfo.iconFileID then
                local category = GetItemCategory(bagID, slotID, itemInfo)
                if not itemsByCategory[category] then
                    itemsByCategory[category] = {}
                end
                table.insert(itemsByCategory[category], {
                    bagID = bagID,
                    slotID = slotID,
                    itemInfo = itemInfo
                })
            end
        end
    end

    -- Calculate total height
    local totalHeight = 0
    local sectionsToCreate = {}
    for _, categoryName in ipairs(CATEGORIES) do
        local categoryItems = itemsByCategory[categoryName]
        if categoryItems and #categoryItems > 0 then
            local numItems = #categoryItems
            local numRows = math.ceil(numItems / SLOTS_PER_ROW)
            local gridHeight = (numRows * SLOT_SIZE) + ((numRows - 1) * SLOT_SPACING)
            local sectionHeight = SECTION_HEADER_HEIGHT + gridHeight + SECTION_SPACING
            
            table.insert(sectionsToCreate, {
                categoryName = categoryName,
                categoryItems = categoryItems,
                gridHeight = gridHeight,
                sectionHeight = sectionHeight
            })
            
            totalHeight = totalHeight + sectionHeight
        end
    end
    
    local startY = -(self.content:GetHeight() - totalHeight) / 2
    local currentY = startY
    local slotIndex = 1
    
    -- Create and position sections
    for _, sectionData in ipairs(sectionsToCreate) do
        local categoryName = sectionData.categoryName
        local categoryItems = sectionData.categoryItems
        local gridHeight = sectionData.gridHeight
        
        local section = self.categories[categoryName]
        if not section then
            section = CreateCategorySection(self.content, categoryName)
            self.categories[categoryName] = section
        end
        
        section.frame:SetPoint("TOPLEFT", self.content, "TOPLEFT", GRID_MARGIN, currentY)
        section.frame:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -GRID_MARGIN, currentY)
        section.frame:Show()
        
        section.itemContainer:SetPoint("TOPLEFT", section.frame, "BOTTOMLEFT", 0, -SECTION_SPACING)
        section.itemContainer:SetPoint("TOPRIGHT", section.frame, "BOTTOMRIGHT", 0, -SECTION_SPACING)
        section.itemContainer:SetHeight(gridHeight)
        section.itemContainer:Show()
        
        local offsetX = 0
        
        for itemIndex, itemData in ipairs(categoryItems) do
            local slot = self.bagSlots[slotIndex]
            if not slot then
                slot = CreateBagSlot(section.itemContainer, slotIndex)
            end
            
            local row = math.floor((itemIndex - 1) / SLOTS_PER_ROW)
            local col = (itemIndex - 1) % SLOTS_PER_ROW
            
            local x = col * (SLOT_SIZE + SLOT_SPACING) + offsetX
            local y = -row * (SLOT_SIZE + SLOT_SPACING)
            
            slot:SetPoint("TOPLEFT", section.itemContainer, "TOPLEFT", x, y)
            slot:Show()
            
            UpdateSlot(slot, itemData.bagID, itemData.slotID)
            
            table.insert(section.items, slot)
            self.bagSlots[slotIndex] = slot
            slotIndex = slotIndex + 1
        end
        
        currentY = currentY - sectionData.sectionHeight
    end
    
    -- Refresh cursor grid if cursor is active for this tab
    if SteamDeckInterfaceCursorModule then
        SteamDeckInterfaceCursorModule:RefreshGrid()
    end
end

-- Initialize the tab
function BagsTab:Initialize(panel, contentFrame)
    self.tabId = "bags"
    self.name = "Bags"
    self.panel = panel
    self.content = contentFrame
    self.bagSlots = {}
    self.categories = {}

    -- Register for bag update events
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("BAG_UPDATE")
    self.eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    self.eventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
    local tab = self
    self.eventFrame:SetScript("OnEvent", function()
        if tab.content and tab.content:IsShown() then
            tab:Refresh()
        end
    end)

    OverrideBagFunctions(panel, self.tabId)
    HideAllDefaultBags()

    -- Hook into container frame Show methods
    for i = 1, 13 do
        local frame = _G["ContainerFrame"..i]
        if frame then
            frame.Show = function(self, ...)
                HideAllDefaultBags()
            end
        end
    end
    
    -- Register for bag open events
    local bagEventFrame = CreateFrame("Frame")
    bagEventFrame:RegisterEvent("BAG_OPEN")
    bagEventFrame:SetScript("OnEvent", function(self, event)
        if event == "BAG_OPEN" then
            HideAllDefaultBags()
        end
    end)
    
    -- Re-apply overrides on PLAYER_LOGIN
    local loginFrame = CreateFrame("Frame")
    loginFrame:RegisterEvent("PLAYER_LOGIN")
    loginFrame:SetScript("OnEvent", function()
        OverrideBagFunctions(panel, self.tabId)
    end)
end

function BagsTab:OnShow()
    self:Refresh()
end

function BagsTab:OnHide()
end

-- Get navigation grid for cursor system
-- Build navigation grid from bag slots
-- Returns a 2D grid structure: grid[row][col] = slot
-- Also returns slotToPosition map: slotToPosition[slot] = {row, col}
function BagsTab:GetNavGrid()
    local SLOTS_PER_ROW = 8
    local grid = {}
    local slotToPosition = {}
    local currentGlobalRow = 0
    
    -- Category display order
    local categoryOrder = {"Gear", "Tradeskills", "Consumable", "Reputation", "Quest", "Other"}
    
    -- Process each category in order (top to bottom)
    for _, categoryName in ipairs(categoryOrder) do
        local section = self.categories[categoryName]
        if section and section.items and #section.items > 0 then
            -- Process items in this category section
            local numItems = #section.items
            local numRows = math.ceil(numItems / SLOTS_PER_ROW)
            
            -- Process each row in this category
            for rowInSection = 0, numRows - 1 do
                -- Process each column in this row
                for colInSection = 0, SLOTS_PER_ROW - 1 do
                    local itemIndex = (rowInSection * SLOTS_PER_ROW) + colInSection + 1
                    
                    if itemIndex <= numItems then
                        local slot = section.items[itemIndex]
                        if slot and slot:IsShown() then
                            -- Assign to global grid position
                            if not grid[currentGlobalRow] then
                                grid[currentGlobalRow] = {}
                            end
                            grid[currentGlobalRow][colInSection] = slot
                            slotToPosition[slot] = {row = currentGlobalRow, col = colInSection}
                        end
                    end
                end
                
                -- Move to next global row
                currentGlobalRow = currentGlobalRow + 1
            end
        end
    end
    
    return grid, slotToPosition
end

-- Get context menu data for a selected slot
-- selection: The selected frame/slot
-- Returns: {content, options} or nil if not applicable
function BagsTab:GetContextMenuForSelection(selection)
    if not selection then
        return nil
    end
    
    -- Check if it's a bag slot (has bagID and slotID)
    if not selection.bagID or not selection.slotID then
        return nil
    end
    
    local itemLink = C_Container.GetContainerItemLink(selection.bagID, selection.slotID)
    if not itemLink then
        return nil
    end
    
    -- Get item info
    local containerInfo = C_Container.GetContainerItemInfo(selection.bagID, selection.slotID)
    if not containerInfo then
        return nil
    end
    
    local itemName = select(1, GetItemInfo(itemLink))
    local itemIcon = containerInfo.iconFileID
    local itemQuality = containerInfo.quality or 0
    
    -- Get tooltip data
    local tooltipData = C_TooltipInfo.GetBagItem(selection.bagID, selection.slotID)
    
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
    itemIconTexture:SetTexture(itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
    
    -- Icon border (for quality)
    local iconBorder = itemIconBg:CreateTexture(nil, "OVERLAY")
    iconBorder:SetSize(64, 64)
    iconBorder:SetPoint("CENTER", itemIconBg, "CENTER", 0, 0)
    iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    if itemQuality and itemQuality > 0 then
        local r, g, b = GetItemQualityColor(itemQuality)
        iconBorder:SetVertexColor(r, g, b, 1)
        iconBorder:Show()
    else
        iconBorder:Hide()
    end
    
    -- Item name
    local itemNameText = itemDisplay:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    itemNameText:SetPoint("LEFT", itemIconBg, "RIGHT", 10, 0)
    itemNameText:SetPoint("RIGHT", itemDisplay, "RIGHT", -10, 0)
    itemNameText:SetJustifyH("LEFT")
    itemNameText:SetText(itemName or "Unknown Item")
    if itemQuality and itemQuality > 0 then
        local r, g, b = GetItemQualityColor(itemQuality)
        itemNameText:SetTextColor(r, g, b)
    else
        itemNameText:SetTextColor(1, 1, 1)
    end
    
    -- Tooltip area
    local tooltipArea = CreateFrame("Frame", nil, content)
    tooltipArea:SetPoint("TOP", itemDisplay, "BOTTOM", 0, 0)
    tooltipArea:SetPoint("LEFT", content, "LEFT", 10, 0)
    tooltipArea:SetPoint("RIGHT", content, "RIGHT", -10, 0)
    content.tooltipArea = tooltipArea
    
    -- Display tooltip lines
    if tooltipData and tooltipData.lines then
        local baseFont, baseFontHeight, baseFlags = GameFontNormal:GetFont()
        local defaultFontHeight = baseFontHeight * 1.5
        local spacing = 2
        local currentY = 0
        local displayedLineIndex = 0
        local tooltipLines = {}
        
        -- Collect lines to display (skip item name)
        for i, lineData in ipairs(tooltipData.lines) do
            local text = lineData.leftText or ""
            if not (i == 1 and text == itemName) then
                displayedLineIndex = displayedLineIndex + 1
                local line = tooltipArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                line:SetFont(baseFont, defaultFontHeight, baseFlags)
                line:SetPoint("TOPLEFT", tooltipArea, "TOPLEFT", 0, currentY)
                line:SetPoint("RIGHT", tooltipArea, "RIGHT", 0, 0)
                line:SetJustifyH("LEFT")
                line:SetJustifyV("TOP")
                line:SetNonSpaceWrap(true)
                
                if lineData.leftColor then
                    local a = lineData.leftColor.a
                    if a then
                        line:SetTextColor(lineData.leftColor.r, lineData.leftColor.g, lineData.leftColor.b, a)
                    else
                        line:SetTextColor(lineData.leftColor.r, lineData.leftColor.g, lineData.leftColor.b)
                    end
                else
                    line:SetTextColor(1, 1, 1)
                end
                
                line:SetText(text)
                line:Show()
                
                local lineHeight = line:GetHeight()
                currentY = currentY - (lineHeight + spacing)
                table.insert(tooltipLines, line)
            end
        end
        
        tooltipArea:SetHeight(math.abs(currentY))
        content.tooltipLines = tooltipLines
    else
        tooltipArea:SetHeight(0)
    end
    
    -- Set content height
    local contentHeight = itemDisplay:GetHeight() + (tooltipArea:GetHeight() or 0)
    content:SetHeight(contentHeight)
    
    -- Build options
    local options = {}
    
    -- Equip option (for equippable items)
    local itemInfoObj = C_Item.GetItemInfo(itemLink)
    if itemInfoObj and C_Item.IsEquippableItem(itemInfoObj) and not C_Item.IsEquippedItem(itemInfoObj) then
        table.insert(options, {
            text = "Equip",
            action = function()
                C_Item.EquipItemByName(itemLink)
            end
        })
    end
    
    -- Inspect option (for gear, mounts, pets, and housing items)
    table.insert(options, {
        text = "Inspect",
        action = function()
            DressUpLink(itemLink)
        end
    })
    
    -- Delete option
    table.insert(options, {
        text = "Delete",
        action = function()
            C_Container.PickupContainerItem(selection.bagID, selection.slotID)
            if CursorHasItem() then
                if itemQuality and itemQuality >= 3 and itemQuality ~= 7 then
                    StaticPopup_Show("DELETE_GOOD_ITEM", itemLink)
                else
                    StaticPopup_Show("DELETE_ITEM", itemLink)
                end
            end
        end
    })
    
    return {
        content = content,
        options = options
    }
end

return BagsTab
