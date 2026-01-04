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
    self.id = "equipment"
    self.name = "Equipment"
    self.panel = panel
    self.content = contentFrame
    self.equipmentSlots = {}
    self.modelScene = nil
    
    -- Apply overrides immediately
    OverrideCharacterFunction(self.panel, self.id)
    HideDefaultCharacter()

    -- Re-apply overrides on PLAYER_LOGIN
    local loginFrame = CreateFrame("Frame")
    loginFrame:RegisterEvent("PLAYER_LOGIN")
    loginFrame:SetScript("OnEvent", function()
        OverrideCharacterFunction(self.panel, self.id)
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
end

-- OnShow callback
function EquipmentTab:OnShow()
    self:Refresh()
end

-- OnHide callback
function EquipmentTab:OnHide()
end

return EquipmentTab
