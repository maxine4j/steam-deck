-- Equipment Tab Module
-- Handles equipment slots, character model, and stats display

SteamDeckEquipmentTab = {}
local EquipmentTab = SteamDeckEquipmentTab

-- Configuration
local SLOT_SIZE = 48
local SLOT_SPACING = 4
local MODEL_TOP_OFFSET_Y = 50
local BASE_MOVEMENT_SPEED = 7
local CR_VERSATILITY_DAMAGE_DONE = 29
local STAT_HEADER_HEIGHT = 24
local STAT_CATEGORY_SPACING = 12
local STAT_ITEM_SPACING = 20
local TITLE_HEIGHT = 40
local TAB_HEIGHT = 35
local FRAME_PADDING = 20

-- Equipment slots in default UI layout order
local LEFT_SLOTS = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot",
    "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot"
}

local RIGHT_SLOTS = {
    "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot"
}

local BOTTOM_SLOTS = {
    "MainHandSlot", "SecondaryHandSlot"
}

-- Calculate model size
local function GetModelSize()
    local screenHeight = UIParent:GetHeight()
    local availableHeight = (screenHeight - TITLE_HEIGHT - TAB_HEIGHT - MODEL_TOP_OFFSET_Y) / 2
    return math.min(availableHeight, 400)
end

-- Create equipment slot button
local function CreateEquipmentSlot(parent, slotName, index)
    local slot = CreateFrame("Button", "SteamDeckCharacterSlot"..slotName, parent)
    slot:SetSize(SLOT_SIZE, SLOT_SIZE)
    
    -- Slot background (solid color only, no texture)
    local bg = slot:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(slot)
    bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    slot.bg = bg
    
    -- Get slot ID and slot-specific icon texture name
    local slotID, textureName = GetInventorySlotInfo(slotName)
    slot.slotID = slotID
    slot.slotName = slotName
    slot.backgroundTextureName = textureName
    
    -- Create custom border (not using UI-EmptySlot as it contains the slot icon)
    -- Create border edges manually to avoid showing the slot icon
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
    
    -- Store border references for easy updating
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
    
    -- Item level text (positioned at bottom center)
    local itemLevelText = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    local font, fontSize = itemLevelText:GetFont()
    itemLevelText:SetFont(font, fontSize * 2, "THICKOUTLINE")  -- Increase font size by 2x with thick outline
    itemLevelText:SetPoint("BOTTOM", slot, "BOTTOM", 0, 2)
    itemLevelText:SetJustifyH("CENTER")
    itemLevelText:SetTextColor(1, 1, 1, 1)
    itemLevelText:Hide()
    slot.itemLevelText = itemLevelText
    
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
            PickupInventoryItem(self.slotID)
        elseif button == "RightButton" then
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
        PickupInventoryItem(self.slotID)
    end)
    
    return slot
end

-- Update equipment slot
local function UpdateEquipmentSlot(slot)
    local textureName = GetInventoryItemTexture("player", slot.slotID)
    
    if textureName then
        slot.itemTexture:SetTexture(textureName)
        slot.itemTexture:Show()
        
        -- Show and color the border based on item quality
        if slot.border and type(slot.border) == "table" then
            slot.border.top:Show()
            slot.border.bottom:Show()
            slot.border.left:Show()
            slot.border.right:Show()
            
            -- Get item quality and color
            local itemLink = GetInventoryItemLink("player", slot.slotID)
            local borderColor = {0.5, 0.5, 0.5, 0.8}  -- Default gray
            if itemLink then
                local _, _, quality = GetItemInfo(itemLink)
                if quality and quality > 0 then
                    local r, g, b = GetItemQualityColor(quality)
                    borderColor = {r, g, b, 1.0}  -- Full opacity for quality borders
                end
            end
            
            -- Apply quality color to all border edges
            slot.border.top:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
            slot.border.bottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
            slot.border.left:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
            slot.border.right:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        end
        
        -- Show item level
        if slot.itemLevelText then
            local itemLink = GetInventoryItemLink("player", slot.slotID)
            if itemLink then
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
        end
        
        -- Check if item is broken or unusable
        if GetInventoryItemBroken("player", slot.slotID) or GetInventoryItemEquippedUnusable("player", slot.slotID) then
            slot.itemTexture:SetVertexColor(0.9, 0, 0)
        else
            slot.itemTexture:SetVertexColor(1, 1, 1)
        end
    else
        slot.itemTexture:Hide()
        -- Hide item level text when slot is empty
        if slot.itemLevelText then
            slot.itemLevelText:Hide()
        end
        -- Show the empty slot border when slot is empty
        if slot.border then
            if type(slot.border) == "table" then
                slot.border.top:Show()
                slot.border.bottom:Show()
                slot.border.left:Show()
                slot.border.right:Show()
                -- Set border to default gray color
                local borderColor = {0.5, 0.5, 0.5, 0.8}
                slot.border.top:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
                slot.border.bottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
                slot.border.left:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
                slot.border.right:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
            else
                slot.border:Show()
                slot.border:SetVertexColor(1, 1, 1, 1)
            end
        end
        -- Ensure background is just a solid color, not a texture
        if slot.bg then
            slot.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        end
    end
end

-- Utility functions
local function FormatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(num)
    end
end

local function RemoveTrailingZeros(text)
    return string.gsub(text, "%.?0+%%", "%%")
end

local function HideDefaultCharacter()
    if CharacterFrame then
        CharacterFrame:UnregisterAllEvents()
        CharacterFrame:Hide()
    end
end

local function OverrideCharacterFunction(panel, tabId)
    local toggleCharacter = function()
        if panel:IsPanelOpen() then
            panel:ClosePanel()
        else
            HideDefaultCharacter()
            panel:OpenPanelToTab(tabId)
        end
    end

    _G.ToggleCharacter = toggleCharacter

    -- Hook into CharacterFrame Show method
    if CharacterFrame then
        CharacterFrame.Show = function()
            HideDefaultCharacter()
        end
    end
end

-- Initialize equipment tab
function EquipmentTab:Initialize(panel, contentFrame)
    local tab = self
    
    -- Set tab properties
    self.tabId = "equipment"
    self.name = "Equipment"
    self.panel = panel
    self.content = contentFrame
    self.equipmentSlots = {}
    self.statFrames = {}  -- Store stat frames for navigation
    self.modelScene = nil
    
    -- Apply overrides immediately
    OverrideCharacterFunction(self.panel, self.tabId)
    HideDefaultCharacter()

    -- Re-apply overrides on PLAYER_LOGIN
    local loginFrame = CreateFrame("Frame")
    loginFrame:RegisterEvent("PLAYER_LOGIN")
    loginFrame:SetScript("OnEvent", function()
        OverrideCharacterFunction(self.panel, self.tabId)
    end)
    
    -- Get actual content frame width
    local contentWidth = self.content:GetWidth()
    if contentWidth <= 0 then
        -- Fallback if width not set yet
        contentWidth = 600 - (2 * FRAME_PADDING)
    end
    
    -- Calculate height of left equipment slots (8 slots + spacing)
    local leftSlotsHeight = (#LEFT_SLOTS * SLOT_SIZE) + ((#LEFT_SLOTS - 1) * SLOT_SPACING)
    
    -- Calculate model size - width uses available space, height capped by left slots height
    -- Note: content frame already has FRAME_PADDING on the right from panels.lua
    local slotPadding = 5  -- Padding between slots and model
    local leftSlotArea = SLOT_SIZE + slotPadding
    local rightSlotArea = SLOT_SIZE + slotPadding
    -- Account for left margin (FRAME_PADDING) - right margin already accounted for in contentWidth
    local availableWidth = contentWidth - FRAME_PADDING - leftSlotArea - rightSlotArea
    local modelWidth = availableWidth
    local modelHeight = math.min(modelWidth, leftSlotsHeight)  -- Cap height by left slots
    
    -- Calculate total width of equipment layout (left slots + padding + model + padding + right slots)
    local totalLayoutWidth = SLOT_SIZE + slotPadding + modelWidth + slotPadding + SLOT_SIZE
    
    -- Position layout with left margin (FRAME_PADDING) to match the right margin
    local layoutStartX = FRAME_PADDING
    
    -- Calculate positions
    local leftSlotsX = layoutStartX
    local modelLeftX = leftSlotsX + SLOT_SIZE + slotPadding
    local rightSlotsX = modelLeftX + modelWidth + slotPadding
    local modelCenterX = modelLeftX + (modelWidth / 2)
    
    -- Create background for the model
    local modelBackground = self.content:CreateTexture(nil, "BACKGROUND")
    modelBackground:SetSize(modelWidth, modelHeight)
    modelBackground:SetPoint("TOPLEFT", self.content, "TOPLEFT", modelLeftX, -MODEL_TOP_OFFSET_Y)
    modelBackground:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    
    -- Create border around the model background
    local borderThickness = 2
    local borderColor = {0.7, 0.7, 0.7, 0.8}
    
    local borderTop = self.content:CreateTexture(nil, "BORDER")
    borderTop:SetSize(modelWidth, borderThickness)
    borderTop:SetPoint("TOPLEFT", modelBackground, "TOPLEFT", 0, borderThickness)
    borderTop:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    local borderBottom = self.content:CreateTexture(nil, "BORDER")
    borderBottom:SetSize(modelWidth, borderThickness)
    borderBottom:SetPoint("BOTTOMLEFT", modelBackground, "BOTTOMLEFT", 0, -borderThickness)
    borderBottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    local borderLeft = self.content:CreateTexture(nil, "BORDER")
    borderLeft:SetSize(borderThickness, modelHeight)
    borderLeft:SetPoint("TOPLEFT", modelBackground, "TOPLEFT", -borderThickness, 0)
    borderLeft:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    local borderRight = self.content:CreateTexture(nil, "BORDER")
    borderRight:SetSize(borderThickness, modelHeight)
    borderRight:SetPoint("TOPRIGHT", modelBackground, "TOPRIGHT", borderThickness, 0)
    borderRight:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    -- Create PlayerModel frame
    self.modelScene = CreateFrame("PlayerModel", "SteamDeckCharacterModel", self.content)
    self.modelScene:SetSize(modelWidth, modelHeight)
    self.modelScene:SetPoint("TOPLEFT", self.content, "TOPLEFT", modelLeftX, -MODEL_TOP_OFFSET_Y)
    
    -- Set up the model
    local function SetupModelScene()
        if not self.modelScene:IsShown() then
            self.modelScene:Show()
        end
        
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
                    self.modelScene:SetCreatureDisplayID(creatureDisplayID)
                    return
                end
            end
        end
        
        local inAlternateForm = C_PlayerInfo and C_PlayerInfo.GetAlternateFormInfo and select(2, C_PlayerInfo.GetAlternateFormInfo()) or false
        local useNativeForm = not inAlternateForm
        self.modelScene:SetUnit("player", false, useNativeForm)
    end
    
    self.modelScene.SetupModel = SetupModelScene
    
    -- Create equipment slots
    local leftStartX = leftSlotsX
    local leftStartY = -MODEL_TOP_OFFSET_Y + 2
    local previousLeftSlot = nil
    
    for i, slotName in ipairs(LEFT_SLOTS) do
        local slot = CreateEquipmentSlot(self.content, slotName, i)
        table.insert(self.equipmentSlots, slot)
        
        if i == 1 then
            slot:SetPoint("TOPLEFT", self.content, "TOPLEFT", leftStartX, leftStartY)
        else
            slot:SetPoint("TOPLEFT", previousLeftSlot, "BOTTOMLEFT", 0, -SLOT_SPACING)
        end
        previousLeftSlot = slot
    end
    
    local rightStartY = -MODEL_TOP_OFFSET_Y + 2
    local previousRightSlot = nil
    
    for i, slotName in ipairs(RIGHT_SLOTS) do
        local slot = CreateEquipmentSlot(self.content, slotName, #LEFT_SLOTS + i)
        table.insert(self.equipmentSlots, slot)
        
        if i == 1 then
            slot:SetPoint("TOPLEFT", self.content, "TOPLEFT", rightSlotsX, rightStartY)
        else
            slot:SetPoint("TOPLEFT", previousRightSlot, "BOTTOMLEFT", 0, -SLOT_SPACING)
        end
        previousRightSlot = slot
    end
    
    local bottomMainHandX = modelCenterX - SLOT_SIZE - (SLOT_SPACING / 2)
    local weaponSlotY = -MODEL_TOP_OFFSET_Y - modelHeight - SLOT_SPACING
    
    for i, slotName in ipairs(BOTTOM_SLOTS) do
        local slot = CreateEquipmentSlot(self.content, slotName, #LEFT_SLOTS + #RIGHT_SLOTS + i)
        table.insert(self.equipmentSlots, slot)
        
        if i == 1 then
            slot:SetPoint("TOPLEFT", self.content, "TOPLEFT", bottomMainHandX, weaponSlotY)
        else
            slot:SetPoint("TOPLEFT", self.equipmentSlots[#self.equipmentSlots - 1], "TOPRIGHT", 5, 0)
        end
    end
    
    -- Create stats section - position it below the weapon slots, centered
    local statsContainer = CreateFrame("Frame", nil, self.content)
    -- Calculate Y position below weapon slots
    local weaponSlotBottom = weaponSlotY - SLOT_SIZE  -- Bottom of weapon slots
    local statsSpacing = 40  -- Spacing below weapon slots
    local statsTopY = weaponSlotBottom - statsSpacing  -- Position stats below weapon slots
    local statsLeftX = layoutStartX  -- Align with the equipment layout
    local statsRightX = layoutStartX + totalLayoutWidth  -- Align with the equipment layout
    
    -- Position stats container below the weapon slots
    statsContainer:SetPoint("TOPLEFT", self.content, "TOPLEFT", statsLeftX, statsTopY)
    statsContainer:SetPoint("TOPRIGHT", self.content, "TOPLEFT", statsRightX, statsTopY)
    statsContainer:SetPoint("BOTTOM", self.content, "BOTTOM", 0, FRAME_PADDING)
    statsContainer.frameWidth = totalLayoutWidth
    
    -- Stats update function
    local function UpdateStats()
        if not statsContainer:IsShown() then
            return
        end
        
        local avgItemLevel, avgItemLevelEquipped = GetAverageItemLevel()
        local displayItemLevel = math.max(C_PaperDollInfo.GetMinItemLevel() or 0, avgItemLevelEquipped or 0)
        statsContainer.itemLevelValue:SetText(math.floor(displayItemLevel))
        
        -- Color the item level based on Blizzard's thresholds
        if GetItemLevelColor then
            local r, g, b = GetItemLevelColor()
            statsContainer.itemLevelValue:SetTextColor(r, g, b, 1)
        end
        
        local spec = C_SpecializationInfo.GetSpecialization()
        local primaryStat = nil
        if spec then
            primaryStat = select(6, C_SpecializationInfo.GetSpecializationInfo(spec, false, false, nil, UnitSex("player")))
        end
        
        local strStat, strEffective = UnitStat("player", LE_UNIT_STAT_STRENGTH)
        local agiStat, agiEffective = UnitStat("player", LE_UNIT_STAT_AGILITY)
        local intStat, intEffective = UnitStat("player", LE_UNIT_STAT_INTELLECT)
        local staStat, staEffective = UnitStat("player", LE_UNIT_STAT_STAMINA)
        
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
        
        local _, runSpeed = GetUnitSpeed("player")
        local speedPercent = math.floor((runSpeed / BASE_MOVEMENT_SPEED * 100) + 0.5)
        statsContainer.movementSpeedValue:SetText(speedPercent .. "%")
        
        local critChance = GetCritChance()
        local spellCrit = GetSpellCritChance(2)
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
        
        local versatilityDamageBonus = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)
        local versText = string.format("%.1f%%", versatilityDamageBonus)
        statsContainer.versValue:SetText(RemoveTrailingZeros(versText))
    end
    
    -- Helper function to create category headers
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
        
        local bg = headerFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(headerFrame)
        bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
        
        local title = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("LEFT", headerFrame, "LEFT", 5, 0)
        title:SetText(text)
        title:SetTextColor(1, 1, 1, 1)
        
        return headerFrame
    end
    
    -- Calculate column widths - use full width of stats container
    local containerWidth = totalLayoutWidth  -- Stats container spans the full layout width
    local columnWidth = (containerWidth - STAT_CATEGORY_SPACING) / 2
    local leftColumnX = 0
    local rightColumnX = columnWidth + STAT_CATEGORY_SPACING
    
    -- Create stat rows
    local statYOffset = 0
    
    local itemLevelHeader = CreateStatCategoryHeader(statsContainer, "Item Level", statYOffset)
    -- Make item level header 1.5x taller
    itemLevelHeader:SetHeight(STAT_HEADER_HEIGHT * 2)
    
    local itemLevelValue = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    local itemLevelFont, itemLevelFontSize = itemLevelValue:GetFont()
    itemLevelValue:SetFont(itemLevelFont, itemLevelFontSize * 2)  -- Increase font size by 50%
    itemLevelValue:SetPoint("CENTER", itemLevelHeader, "CENTER", 0, 0)  -- Center both horizontally and vertically within header
    itemLevelValue:SetJustifyH("CENTER")
    itemLevelValue:SetText("0")
    statsContainer.itemLevelValue = itemLevelValue
    
    -- Create selectable frame for Item Level
    local itemLevelFrame = CreateFrame("Frame", nil, statsContainer)
    itemLevelFrame:SetAllPoints(itemLevelHeader)
    itemLevelFrame:EnableMouse(false)
    itemLevelFrame.statType = "ItemLevel"
    table.insert(self.statFrames, itemLevelFrame)
    
    statYOffset = statYOffset - (STAT_HEADER_HEIGHT * 2) - STAT_CATEGORY_SPACING
    
    local leftColumnY = statYOffset
    local rightColumnY = statYOffset
    
    local attributesHeader = CreateStatCategoryHeader(statsContainer, "Attributes", leftColumnY, columnWidth)
    leftColumnY = leftColumnY - STAT_HEADER_HEIGHT - STAT_ITEM_SPACING
    
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
    
    -- Create selectable frame for Primary Stat
    local primaryStatFrame = CreateFrame("Frame", nil, statsContainer)
    primaryStatFrame:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", leftColumnX, leftColumnY)
    primaryStatFrame:SetPoint("TOPRIGHT", statsContainer, "TOPLEFT", leftColumnX + columnWidth, leftColumnY)
    primaryStatFrame:SetHeight(STAT_ITEM_SPACING)
    primaryStatFrame:EnableMouse(false)
    primaryStatFrame.statType = "PrimaryStat"
    table.insert(self.statFrames, primaryStatFrame)
    
    leftColumnY = leftColumnY - STAT_ITEM_SPACING
    
    local staminaLabel = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    staminaLabel:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", leftColumnX + 10, leftColumnY)
    staminaLabel:SetText("Stamina")
    staminaLabel:SetTextColor(0.8, 0.8, 0.8, 1)
    
    local staminaValue = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    staminaValue:SetPoint("TOPRIGHT", statsContainer, "TOPLEFT", leftColumnX + columnWidth - 10, leftColumnY)
    staminaValue:SetJustifyH("RIGHT")
    staminaValue:SetText("0")
    statsContainer.staminaValue = staminaValue
    
    -- Create selectable frame for Stamina
    local staminaFrame = CreateFrame("Frame", nil, statsContainer)
    staminaFrame:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", leftColumnX, leftColumnY)
    staminaFrame:SetPoint("TOPRIGHT", statsContainer, "TOPLEFT", leftColumnX + columnWidth, leftColumnY)
    staminaFrame:SetHeight(STAT_ITEM_SPACING)
    staminaFrame:EnableMouse(false)
    staminaFrame.statType = "Stamina"
    table.insert(self.statFrames, staminaFrame)
    
    leftColumnY = leftColumnY - STAT_ITEM_SPACING
    
    local armorLabel = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    armorLabel:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", leftColumnX + 10, leftColumnY)
    armorLabel:SetText("Armor")
    armorLabel:SetTextColor(0.8, 0.8, 0.8, 1)
    
    local armorValue = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    armorValue:SetPoint("TOPRIGHT", statsContainer, "TOPLEFT", leftColumnX + columnWidth - 10, leftColumnY)
    armorValue:SetJustifyH("RIGHT")
    armorValue:SetText("0")
    statsContainer.armorValue = armorValue
    
    -- Create selectable frame for Armor
    local armorFrame = CreateFrame("Frame", nil, statsContainer)
    armorFrame:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", leftColumnX, leftColumnY)
    armorFrame:SetPoint("TOPRIGHT", statsContainer, "TOPLEFT", leftColumnX + columnWidth, leftColumnY)
    armorFrame:SetHeight(STAT_ITEM_SPACING)
    armorFrame:EnableMouse(false)
    armorFrame.statType = "Armor"
    table.insert(self.statFrames, armorFrame)
    
    leftColumnY = leftColumnY - STAT_ITEM_SPACING
    
    local movementSpeedLabel = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    movementSpeedLabel:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", leftColumnX + 10, leftColumnY)
    movementSpeedLabel:SetText("Movement Speed")
    movementSpeedLabel:SetTextColor(0.8, 0.8, 0.8, 1)
    
    local movementSpeedValue = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    movementSpeedValue:SetPoint("TOPRIGHT", statsContainer, "TOPLEFT", leftColumnX + columnWidth - 10, leftColumnY)
    movementSpeedValue:SetJustifyH("RIGHT")
    movementSpeedValue:SetText("0%")
    statsContainer.movementSpeedValue = movementSpeedValue
    
    -- Create selectable frame for Movement Speed
    local movementSpeedFrame = CreateFrame("Frame", nil, statsContainer)
    movementSpeedFrame:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", leftColumnX, leftColumnY)
    movementSpeedFrame:SetPoint("TOPRIGHT", statsContainer, "TOPLEFT", leftColumnX + columnWidth, leftColumnY)
    movementSpeedFrame:SetHeight(STAT_ITEM_SPACING)
    movementSpeedFrame:EnableMouse(false)
    movementSpeedFrame.statType = "MovementSpeed"
    table.insert(self.statFrames, movementSpeedFrame)
    
    local enhancementsHeader = CreateStatCategoryHeader(statsContainer, "Enhancements", rightColumnY, columnWidth)
    enhancementsHeader:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", rightColumnX, rightColumnY)
    rightColumnY = rightColumnY - STAT_HEADER_HEIGHT - STAT_ITEM_SPACING
    
    local critLabel = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    critLabel:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", rightColumnX + 10, rightColumnY)
    critLabel:SetText("Critical Strike")
    critLabel:SetTextColor(0.8, 0.8, 0.8, 1)
    
    local critValue = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    critValue:SetPoint("TOPRIGHT", statsContainer, "TOPRIGHT", -10, rightColumnY)
    critValue:SetJustifyH("RIGHT")
    critValue:SetText("0.0%")
    statsContainer.critValue = critValue
    
    -- Create selectable frame for Critical Strike
    local critFrame = CreateFrame("Frame", nil, statsContainer)
    critFrame:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", rightColumnX, rightColumnY)
    critFrame:SetPoint("TOPRIGHT", statsContainer, "TOPRIGHT", 0, rightColumnY)
    critFrame:SetHeight(STAT_ITEM_SPACING)
    critFrame:EnableMouse(false)
    critFrame.statType = "CriticalStrike"
    table.insert(self.statFrames, critFrame)
    
    rightColumnY = rightColumnY - STAT_ITEM_SPACING
    
    local hasteLabel = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hasteLabel:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", rightColumnX + 10, rightColumnY)
    hasteLabel:SetText("Haste")
    hasteLabel:SetTextColor(0.8, 0.8, 0.8, 1)
    
    local hasteValue = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    hasteValue:SetPoint("TOPRIGHT", statsContainer, "TOPRIGHT", -10, rightColumnY)
    hasteValue:SetJustifyH("RIGHT")
    hasteValue:SetText("0.0%")
    statsContainer.hasteValue = hasteValue
    
    -- Create selectable frame for Haste
    local hasteFrame = CreateFrame("Frame", nil, statsContainer)
    hasteFrame:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", rightColumnX, rightColumnY)
    hasteFrame:SetPoint("TOPRIGHT", statsContainer, "TOPRIGHT", 0, rightColumnY)
    hasteFrame:SetHeight(STAT_ITEM_SPACING)
    hasteFrame:EnableMouse(false)
    hasteFrame.statType = "Haste"
    table.insert(self.statFrames, hasteFrame)
    
    rightColumnY = rightColumnY - STAT_ITEM_SPACING
    
    local masteryLabel = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    masteryLabel:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", rightColumnX + 10, rightColumnY)
    masteryLabel:SetText("Mastery")
    masteryLabel:SetTextColor(0.8, 0.8, 0.8, 1)
    
    local masteryValue = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    masteryValue:SetPoint("TOPRIGHT", statsContainer, "TOPRIGHT", -10, rightColumnY)
    masteryValue:SetJustifyH("RIGHT")
    masteryValue:SetText("0.0%")
    statsContainer.masteryValue = masteryValue
    
    -- Create selectable frame for Mastery
    local masteryFrame = CreateFrame("Frame", nil, statsContainer)
    masteryFrame:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", rightColumnX, rightColumnY)
    masteryFrame:SetPoint("TOPRIGHT", statsContainer, "TOPRIGHT", 0, rightColumnY)
    masteryFrame:SetHeight(STAT_ITEM_SPACING)
    masteryFrame:EnableMouse(false)
    masteryFrame.statType = "Mastery"
    table.insert(self.statFrames, masteryFrame)
    
    rightColumnY = rightColumnY - STAT_ITEM_SPACING
    
    local versLabel = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    versLabel:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", rightColumnX + 10, rightColumnY)
    versLabel:SetText("Versatility")
    versLabel:SetTextColor(0.8, 0.8, 0.8, 1)
    
    local versValue = statsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    versValue:SetPoint("TOPRIGHT", statsContainer, "TOPRIGHT", -10, rightColumnY)
    versValue:SetJustifyH("RIGHT")
    versValue:SetText("0.0%")
    statsContainer.versValue = versValue
    
    -- Create selectable frame for Versatility
    local versFrame = CreateFrame("Frame", nil, statsContainer)
    versFrame:SetPoint("TOPLEFT", statsContainer, "TOPLEFT", rightColumnX, rightColumnY)
    versFrame:SetPoint("TOPRIGHT", statsContainer, "TOPRIGHT", 0, rightColumnY)
    versFrame:SetHeight(STAT_ITEM_SPACING)
    versFrame:EnableMouse(false)
    versFrame.statType = "Versatility"
    table.insert(self.statFrames, versFrame)
    
    statsContainer.UpdateStats = UpdateStats
    self.statsContainer = statsContainer
    
    -- Register for equipment update events
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self.eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
    self.eventFrame:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    self.eventFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
    self.eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    self.eventFrame:SetScript("OnEvent", function(self, event, unit)
        if unit == "player" or not unit then
            if tab.content and tab.content:IsShown() then
                tab:Refresh()
            end
        end
    end)
end

-- Refresh equipment
function EquipmentTab:Refresh()
    for _, slot in ipairs(self.equipmentSlots) do
        UpdateEquipmentSlot(slot)
    end
    
    if self.modelScene and self.modelScene.SetupModel then
        self.modelScene:SetupModel()
    end
    
    if self.statsContainer and self.statsContainer.UpdateStats then
        self.statsContainer:UpdateStats()
    end
    
    -- Refresh cursor grid if cursor is active for this tab
    if SteamDeckInterfaceCursorModule then
        SteamDeckInterfaceCursorModule:RefreshGrid()
    end
end

-- OnShow callback
function EquipmentTab:OnShow()
    self:Refresh()
end

-- OnHide callback
function EquipmentTab:OnHide()
end

-- Get navigation grid for cursor system
-- Build navigation grid from equipment slots and stats
-- Returns a 2D grid structure: grid[row][col] = slot/frame
-- Also returns slotToPosition map: slotToPosition[slot/frame] = {row, col}
-- Layout:
--   Row 0-7: Left column (col 0) and Right column (col 1) - equipment slots
--   Row 8: Bottom weapon slots (col 0 = MainHand, col 1 = SecondaryHand)
--   Row 9: Item Level (col 0, full width)
--   Rows 10-13: Stats (col 0 = left column stats, col 1 = right column stats)
function EquipmentTab:GetNavGrid()
    local grid = {}
    local slotToPosition = {}
    
    -- Process left column slots (rows 0-7, col 0)
    for i, slotName in ipairs(LEFT_SLOTS) do
        local slot = self.equipmentSlots[i]
        if slot and slot:IsShown() then
            local row = i - 1  -- 0-based row index
            local col = 0
            if not grid[row] then
                grid[row] = {}
            end
            grid[row][col] = slot
            slotToPosition[slot] = {row = row, col = col}
        end
    end
    
    -- Process right column slots (rows 0-7, col 1)
    for i, slotName in ipairs(RIGHT_SLOTS) do
        local slot = self.equipmentSlots[#LEFT_SLOTS + i]
        if slot and slot:IsShown() then
            local row = i - 1  -- 0-based row index
            local col = 1
            if not grid[row] then
                grid[row] = {}
            end
            grid[row][col] = slot
            slotToPosition[slot] = {row = row, col = col}
        end
    end
    
    -- Process bottom weapon slots (row 8, cols 0-1)
    for i, slotName in ipairs(BOTTOM_SLOTS) do
        local slot = self.equipmentSlots[#LEFT_SLOTS + #RIGHT_SLOTS + i]
        if slot and slot:IsShown() then
            local row = 8
            local col = i - 1  -- 0 = MainHand, 1 = SecondaryHand
            if not grid[row] then
                grid[row] = {}
            end
            grid[row][col] = slot
            slotToPosition[slot] = {row = row, col = col}
        end
    end
    
    -- Process stat frames
    -- Item Level (row 9, col 0 - full width, but we'll put it in col 0)
    if self.statFrames[1] and self.statFrames[1]:IsShown() then  -- Item Level is first
        local row = 9
        local col = 0
        if not grid[row] then
            grid[row] = {}
        end
        grid[row][col] = self.statFrames[1]
        slotToPosition[self.statFrames[1]] = {row = row, col = col}
    end
    
    -- Left column stats (rows 10-13, col 0)
    -- Order: PrimaryStat, Stamina, Armor, MovementSpeed
    local leftStatOrder = {2, 3, 4, 5}  -- Indices in statFrames array
    for i, statIndex in ipairs(leftStatOrder) do
        if self.statFrames[statIndex] and self.statFrames[statIndex]:IsShown() then
            local row = 9 + i  -- Rows 10-13
            local col = 0
            if not grid[row] then
                grid[row] = {}
            end
            grid[row][col] = self.statFrames[statIndex]
            slotToPosition[self.statFrames[statIndex]] = {row = row, col = col}
        end
    end
    
    -- Right column stats (rows 10-13, col 1)
    -- Order: CriticalStrike, Haste, Mastery, Versatility
    local rightStatOrder = {6, 7, 8, 9}  -- Indices in statFrames array
    for i, statIndex in ipairs(rightStatOrder) do
        if self.statFrames[statIndex] and self.statFrames[statIndex]:IsShown() then
            local row = 9 + i  -- Rows 10-13
            local col = 1
            if not grid[row] then
                grid[row] = {}
            end
            grid[row][col] = self.statFrames[statIndex]
            slotToPosition[self.statFrames[statIndex]] = {row = row, col = col}
        end
    end
    
    return grid, slotToPosition
end

-- Get context menu data for a selected slot or stat
-- selection: The selected frame/slot/stat
-- Returns: {content, options} or nil if not applicable
function EquipmentTab:GetContextMenuForSelection(selection)
    if not selection then
        return nil
    end
    
    -- Check if it's an equipment slot (has slotID and slotName)
    if selection.slotID and selection.slotName then
        local itemLink = GetInventoryItemLink("player", selection.slotID)
        if not itemLink then
            return nil
        end
        
        -- Get item info
        local itemName = select(1, GetItemInfo(itemLink))
        local itemTexture = GetInventoryItemTexture("player", selection.slotID)
        local _, _, itemQuality = GetItemInfo(itemLink)
        itemQuality = itemQuality or 0
        
        -- Get tooltip data
        local tooltipData = C_TooltipInfo.GetInventoryItem("player", selection.slotID)
        
        -- Get name color based on quality
        local r, g, b = GetItemQualityColor(itemQuality)
        local nameColor = {r, g, b, 1}
        
        -- Create content frame
        local contentFrame = CreateFrame("Frame", nil, UIParent) -- Parent to UIParent initially, cursor.lua will reparent
        contentFrame:SetSize(340, 1) -- Dynamic height
        contentFrame:Hide()
        
        -- Item icon with border
        local itemIconBg = CreateFrame("Frame", nil, contentFrame)
        itemIconBg:SetSize(64, 64)
        itemIconBg:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, 0)
        contentFrame.itemIconBg = itemIconBg
        
        local icon = itemIconBg:CreateTexture(nil, "ARTWORK")
        icon:SetSize(60, 60)
        icon:SetPoint("CENTER", itemIconBg, "CENTER", 0, 0)
        icon:SetTexture(itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
        contentFrame.itemIcon = icon
        
        -- Icon border (for quality)
        local iconBorder = itemIconBg:CreateTexture(nil, "OVERLAY")
        iconBorder:SetSize(64, 64)
        iconBorder:SetPoint("CENTER", itemIconBg, "CENTER", 0, 0)
        iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
        if itemQuality and itemQuality > 0 then
            iconBorder:SetVertexColor(nameColor[1], nameColor[2], nameColor[3], 1)
            iconBorder:Show()
        else
            iconBorder:Hide()
        end
        contentFrame.iconBorder = iconBorder
        
        -- Item name
        local nameText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        nameText:SetPoint("LEFT", itemIconBg, "RIGHT", 10, 0)
        nameText:SetPoint("RIGHT", contentFrame, "RIGHT", -10, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetText(itemName or "Unknown Item")
        nameText:SetTextColor(nameColor[1], nameColor[2], nameColor[3], nameColor[4])
        contentFrame.itemName = nameText
        
        local currentY = -itemIconBg:GetHeight() - 10 -- Start tooltip below icon/name with margin
        contentFrame.tooltipLines = {}
        
        -- Display tooltip lines with dynamic sizing
        if tooltipData and tooltipData.lines then
            local spacing = 2
            local baseFont, baseFontHeight, baseFlags = GameFontNormal:GetFont()
            local defaultFontHeight = baseFontHeight * 1.5
            local fontHeight = defaultFontHeight
            
            local displayedLineIndex = 0
            local linesToDisplay = {}
            
            for i, lineData in ipairs(tooltipData.lines) do
                local text = lineData.leftText or ""
                if not (i == 1 and text == itemName) then
                    displayedLineIndex = displayedLineIndex + 1
                    table.insert(linesToDisplay, {
                        data = lineData,
                        index = displayedLineIndex
                    })
                end
            end
            
            -- Calculate content height with default font
            local actualContentHeight = 0
            for _, lineInfo in ipairs(linesToDisplay) do
                local line = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                table.insert(contentFrame.tooltipLines, line)
                
                line:SetFont(baseFont, defaultFontHeight, baseFlags)
                line:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, currentY)
                line:SetPoint("RIGHT", contentFrame, "RIGHT", -10, currentY)
                line:SetJustifyH("LEFT")
                line:SetJustifyV("TOP")
                line:SetNonSpaceWrap(true)
                line:SetText(lineInfo.data.leftText or "")
                
                local lineHeight = line:GetHeight()
                actualContentHeight = actualContentHeight + lineHeight + spacing
            end
            
            currentY = -itemIconBg:GetHeight() - 10 -- Reset for final positioning
            for _, lineInfo in ipairs(linesToDisplay) do
                local line = contentFrame.tooltipLines[lineInfo.index]
                line:SetFont(baseFont, fontHeight, baseFlags)
                line:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, currentY)
                line:SetPoint("RIGHT", contentFrame, "RIGHT", -10, currentY)
                
                local text = lineInfo.data.leftText or ""
                if lineInfo.data.rightText and lineInfo.data.rightText ~= "" then
                    text = text .. " " .. lineInfo.data.rightText
                end
                if lineInfo.data.leftColor then
                    line:SetTextColor(lineInfo.data.leftColor.r, lineInfo.data.leftColor.g, lineInfo.data.leftColor.b, lineInfo.data.leftColor.a or 1)
                else
                    line:SetTextColor(1, 1, 1)
                end
                line:SetText(text)
                line:Show()
                
                local lineHeightActual = line:GetHeight()
                currentY = currentY - (lineHeightActual + spacing)
            end
        end
        
        contentFrame:SetHeight(math.abs(currentY) + itemIconBg:GetHeight() + 20) -- Total height including icon/name area and padding
        
        -- Build options
        local options = {}
        
        -- Unequip option (item is equipped)
        table.insert(options, {
            text = "Unequip",
            action = function()
                PickupInventoryItem(selection.slotID)
                if CursorHasItem() then
                    -- Try to place in backpack first
                    if PutItemInBackpack() then
                        return
                    end
                    -- Try bags 1-5
                    for bag = 1, 5 do
                        if PutItemInBag(30 + bag) then
                            return
                        end
                    end
                    -- If all failed, clear cursor
                    ClearCursor()
                end
            end
        })
        
        -- Inspect option
        table.insert(options, {
            text = "Inspect",
            action = function()
                DressUpLink(itemLink)
            end
        })
        
        return {
            content = contentFrame,
            options = options
        }
    end
    
    -- For stat frames, we could return nil or show stat info
    -- For now, return nil (no context menu for stats)
    return nil
end

return EquipmentTab
