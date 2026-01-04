-- Equipment Tab Module
-- Handles equipment slots, character model, and stats display

SteamDeckCharacterEquipmentTab = {}
local EquipmentTab = SteamDeckCharacterEquipmentTab

-- Equipment tab state
local modelScene = nil
local equipmentSlots = {}

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

-- Initialize equipment tab
function EquipmentTab.Initialize(frame, config)
    local FRAME_PADDING = config.FRAME_PADDING
    local FormatNumber = config.FormatNumber
    local RemoveTrailingZeros = config.RemoveTrailingZeros
    
    -- Get Equipment tab content frame
    local equipmentContent = frame.tabContentFrames["Equipment"]
    
    -- Calculate model size
    local modelSize = GetModelSize()
    
    -- Calculate frame width
    local leftSlotArea = FRAME_PADDING + SLOT_SIZE + 10
    local rightSlotArea = FRAME_PADDING + SLOT_SIZE + 10
    local frameWidth = leftSlotArea + modelSize + rightSlotArea
    frame:SetWidth(frameWidth)
    
    -- Calculate model center position
    local leftSlotsEnd = leftSlotArea
    local rightSlotsStart = frameWidth - rightSlotArea
    local modelCenterX = (leftSlotsEnd + rightSlotsStart) / 2
    local modelLeftX = modelCenterX - (modelSize / 2)
    
    -- Create background for the model
    local modelBackground = equipmentContent:CreateTexture(nil, "BACKGROUND")
    modelBackground:SetSize(modelSize, modelSize)
    modelBackground:SetPoint("TOPLEFT", equipmentContent, "TOPLEFT", modelLeftX, -MODEL_TOP_OFFSET_Y)
    modelBackground:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    
    -- Create border around the model background
    local borderThickness = 2
    local borderColor = {0.7, 0.7, 0.7, 0.8}
    
    local borderTop = equipmentContent:CreateTexture(nil, "BORDER")
    borderTop:SetSize(modelSize, borderThickness)
    borderTop:SetPoint("TOPLEFT", modelBackground, "TOPLEFT", 0, borderThickness)
    borderTop:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    local borderBottom = equipmentContent:CreateTexture(nil, "BORDER")
    borderBottom:SetSize(modelSize, borderThickness)
    borderBottom:SetPoint("BOTTOMLEFT", modelBackground, "BOTTOMLEFT", 0, -borderThickness)
    borderBottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    local borderLeft = equipmentContent:CreateTexture(nil, "BORDER")
    borderLeft:SetSize(borderThickness, modelSize)
    borderLeft:SetPoint("TOPLEFT", modelBackground, "TOPLEFT", -borderThickness, 0)
    borderLeft:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    local borderRight = equipmentContent:CreateTexture(nil, "BORDER")
    borderRight:SetSize(borderThickness, modelSize)
    borderRight:SetPoint("TOPRIGHT", modelBackground, "TOPRIGHT", borderThickness, 0)
    borderRight:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    -- Create PlayerModel frame
    modelScene = CreateFrame("PlayerModel", "SteamDeckCharacterModel", equipmentContent)
    modelScene:SetSize(modelSize, modelSize)
    modelScene:SetPoint("TOPLEFT", equipmentContent, "TOPLEFT", modelLeftX, -MODEL_TOP_OFFSET_Y)
    
    -- Set up the model
    local function SetupModelScene()
        if not modelScene:IsShown() then
            modelScene:Show()
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
                    modelScene:SetCreatureDisplayID(creatureDisplayID)
                    return
                end
            end
        end
        
        local inAlternateForm = C_PlayerInfo and C_PlayerInfo.GetAlternateFormInfo and select(2, C_PlayerInfo.GetAlternateFormInfo()) or false
        local useNativeForm = not inAlternateForm
        modelScene:SetUnit("player", false, useNativeForm)
    end
    
    modelScene.SetupModel = SetupModelScene
    frame.modelScene = modelScene
    
    -- Create equipment slots
    local leftStartX = FRAME_PADDING
    local leftStartY = -MODEL_TOP_OFFSET_Y + 2
    local previousLeftSlot = nil
    
    for i, slotName in ipairs(LEFT_SLOTS) do
        local slot = CreateEquipmentSlot(equipmentContent, slotName, i)
        table.insert(equipmentSlots, slot)
        
        if i == 1 then
            slot:SetPoint("TOPLEFT", equipmentContent, "TOPLEFT", leftStartX, leftStartY)
        else
            slot:SetPoint("TOPLEFT", previousLeftSlot, "BOTTOMLEFT", 0, -SLOT_SPACING)
        end
        previousLeftSlot = slot
    end
    
    local rightStartY = -MODEL_TOP_OFFSET_Y + 2
    local previousRightSlot = nil
    
    for i, slotName in ipairs(RIGHT_SLOTS) do
        local slot = CreateEquipmentSlot(equipmentContent, slotName, #LEFT_SLOTS + i)
        table.insert(equipmentSlots, slot)
        
        if i == 1 then
            slot:SetPoint("TOPRIGHT", equipmentContent, "TOPRIGHT", -FRAME_PADDING, rightStartY)
        else
            slot:SetPoint("TOPLEFT", previousRightSlot, "BOTTOMLEFT", 0, -SLOT_SPACING)
        end
        previousRightSlot = slot
    end
    
    local bottomMainHandX = modelCenterX - SLOT_SIZE - (SLOT_SPACING / 2)
    local weaponSlotY = -MODEL_TOP_OFFSET_Y - modelSize - SLOT_SPACING
    
    for i, slotName in ipairs(BOTTOM_SLOTS) do
        local slot = CreateEquipmentSlot(equipmentContent, slotName, #LEFT_SLOTS + #RIGHT_SLOTS + i)
        table.insert(equipmentSlots, slot)
        
        if i == 1 then
            slot:SetPoint("TOPLEFT", equipmentContent, "TOPLEFT", bottomMainHandX, weaponSlotY)
        else
            slot:SetPoint("TOPLEFT", equipmentSlots[#equipmentSlots - 1], "TOPRIGHT", 5, 0)
        end
    end
    
    -- Create stats section
    local statsContainer = CreateFrame("Frame", nil, equipmentContent)
    local modelBottom = -MODEL_TOP_OFFSET_Y - modelSize - SLOT_SPACING - SLOT_SIZE - 20
    statsContainer:SetPoint("TOPLEFT", equipmentContent, "TOPLEFT", FRAME_PADDING, modelBottom)
    statsContainer:SetPoint("BOTTOMRIGHT", equipmentContent, "BOTTOMRIGHT", -FRAME_PADDING, FRAME_PADDING)
    statsContainer.frameWidth = frameWidth
    
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
    
    -- Calculate column widths
    local containerWidth = statsContainer.frameWidth - (2 * FRAME_PADDING)
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
    
    statsContainer.UpdateStats = UpdateStats
    frame.statsContainer = statsContainer
end

-- Refresh equipment
function EquipmentTab.Refresh(frame)
    for _, slot in ipairs(equipmentSlots) do
        UpdateEquipmentSlot(slot)
    end
    
    if modelScene and modelScene.SetupModel then
        modelScene:SetupModel()
    end
    
    if frame.statsContainer and frame.statsContainer.UpdateStats then
        frame.statsContainer:UpdateStats()
    end
end

