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
end

-- Initialize the tab
function BagsTab:Initialize(panel, contentFrame)

    self.id = "bags"
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

    OverrideBagFunctions(panel, self.id)
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
        OverrideBagFunctions(panel, self.id)
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
      local section = categorySections[categoryName]
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

return BagsTab
