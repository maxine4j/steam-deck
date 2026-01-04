-- SteamDeck Bags Module
-- Replaces default bag UI with a custom right-side frame

SteamDeckBagsModule = {}
local BagsModule = SteamDeckBagsModule
local bagsFrame = nil
local bagSlots = {}
local isOpen = false

-- Configuration
local SLOTS_PER_ROW = 8
local SLOT_SIZE = 48
local SLOT_SPACING = 4
local FRAME_PADDING = 20
local GRID_PADDING = 10
local GRID_MARGIN = 20

-- Store original functions
local originalToggleBackpack = nil
local originalOpenBackpack = nil
local originalToggleAllBags = nil

-- Hide all default bag frames
local function HideAllDefaultBags()
    -- Hide all container frames (they're numbered)
    for i = 1, 13 do
        local frame = _G["ContainerFrame"..i]
        if frame then
            frame:UnregisterAllEvents()
            frame:Hide()
        end
    end
    
    -- Hide the main backpack button
    if MainMenuBarBackpackButton then
        MainMenuBarBackpackButton:Hide()
    end
    
    -- Hide bag slots
    for i = 0, 3 do
        local bagButton = _G["CharacterBag"..i.."Slot"]
        if bagButton then
            bagButton:Hide()
        end
    end
end

-- Override ToggleBackpack
local function OverrideToggleBackpack()
    -- Prevent default bag behavior immediately
    HideAllDefaultBags()
    -- Toggle our custom bags
    BagsModule:Toggle()
    -- Ensure default bags stay hidden
    HideAllDefaultBags()
    -- Don't call the original function - we've completely replaced it
end

-- Override OpenBackpack
local function OverrideOpenBackpack()
    HideAllDefaultBags()
    -- Use toggle behavior so pressing B again closes the bags
    BagsModule:Toggle()
end

-- Override ToggleAllBags
local function OverrideToggleAllBags()
    HideAllDefaultBags()
    BagsModule:Toggle()
end

-- Create the main bags frame
local function CreateBagsFrame()
    local frame = CreateFrame("Frame", "SteamDeckBagsFrame", UIParent)
    
    -- Calculate frame width based on maximum grid width (8 slots per row)
    -- Max grid width = (SLOTS_PER_ROW * SLOT_SIZE) + ((SLOTS_PER_ROW - 1) * SLOT_SPACING)
    local maxGridWidth = (SLOTS_PER_ROW * SLOT_SIZE) + ((SLOTS_PER_ROW - 1) * SLOT_SPACING)
    -- Frame width = grid width + frame padding on both sides + grid margin on both sides
    local frameWidth = maxGridWidth + (2 * FRAME_PADDING) + (2 * GRID_MARGIN)
    frame:SetWidth(frameWidth)
    
    -- Anchor to right side and full height of screen
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    
    -- Set strata to HIGH so it appears above other UI elements but doesn't block input
    -- Using HIGH instead of DIALOG prevents it from acting like a modal dialog
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(100)
    
    -- Don't enable mouse on the main frame - it covers too much area and blocks other UI
    -- Mouse interaction will be handled by the individual bag slot buttons (which are Buttons)
    frame:EnableMouse(false)
    
    -- Don't enable keyboard - we handle toggle through function override
    -- This prevents the frame from blocking all keyboard input
    frame:EnableKeyboard(false)
    
    -- Keep isOpen state in sync with frame visibility
    frame:SetScript("OnShow", function()
        isOpen = true
    end)
    frame:SetScript("OnHide", function()
        isOpen = false
        HideAllDefaultBags()
    end)
    
    -- Ensure frame is not draggable
    frame:SetMovable(false)
    
    -- Background (extends to right edge of screen)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bg:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    bg:SetColorTexture(0, 0, 0, 0.8)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -10)
    title:SetText("Bags")
    
    -- Container for slots
    local container = CreateFrame("Frame", nil, frame)
    container:SetPoint("TOP", title, "BOTTOM", 0, -20)
    container:SetPoint("LEFT", frame, "LEFT", FRAME_PADDING, 0)
    container:SetPoint("RIGHT", frame, "RIGHT", -FRAME_PADDING, 0)
    container:SetPoint("BOTTOM", frame, "BOTTOM", 0, FRAME_PADDING)
    
    frame.container = container
    frame:Hide()
    
    return frame
end

-- Create a single bag slot button
local function CreateBagSlot(parent, slotIndex)
    local slot = CreateFrame("Button", "SteamDeckBagSlot"..slotIndex, parent)
    slot:SetSize(SLOT_SIZE, SLOT_SIZE)
    
    -- Slot background
    local bg = slot:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(slot)
    bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    -- Border (needs to be behind the item icon)
    local border = slot:CreateTexture(nil, "BORDER")
    border:SetAllPoints(slot)
    border:SetTexture("Interface\\Buttons\\UI-EmptySlot")
    slot.border = border
    
    -- Item texture (on ARTWORK layer, which is above BORDER)
    local itemTexture = slot:CreateTexture(nil, "ARTWORK")
    itemTexture:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, -2)
    itemTexture:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
    itemTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    slot.itemTexture = itemTexture
    
    -- Count text
    local count = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
    count:SetJustifyH("RIGHT")
    slot.count = count
    
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
            -- Check if we're targeting a spell with an item
            if SpellCanTargetItem() or SpellCanTargetItemID() then
                -- Use the item to target the spell
                C_Container.UseContainerItem(self.bagID, self.slotID)
            else
                -- Pick up the item (or swap if cursor has item)
                C_Container.PickupContainerItem(self.bagID, self.slotID)
            end
        elseif button == "RightButton" then
            -- Right-click to use item (if usable)
            if self.itemLink then
                C_Container.UseContainerItem(self.bagID, self.slotID)
            end
        end
    end)
    
    -- Drag start - pick up the item when dragging begins
    slot:SetScript("OnDragStart", function(self)
        if not self.bagID or not self.slotID then
            return
        end
        -- Same logic as left-click - pick up the item
        if SpellCanTargetItem() or SpellCanTargetItemID() then
            C_Container.UseContainerItem(self.bagID, self.slotID)
        else
            C_Container.PickupContainerItem(self.bagID, self.slotID)
        end
    end)
    
    -- Receive drag - handle when item is dropped on this slot
    slot:SetScript("OnReceiveDrag", function(self)
        if not self.bagID or not self.slotID then
            return
        end
        -- If cursor has an item, place it in this slot (or swap)
        if CursorHasItem() then
            C_Container.PickupContainerItem(self.bagID, self.slotID)
        end
    end)
    
    slot.slotIndex = slotIndex
    return slot
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
        
        -- Quality border color
        if itemInfo.quality and itemInfo.quality > 0 then
            local r, g, b = GetItemQualityColor(itemInfo.quality)
            slot.border:SetVertexColor(r, g, b, 1)
        else
            slot.border:SetVertexColor(1, 1, 1, 1)
        end
        
        slot.itemLink = itemInfo.hyperlink
        slot.bagID = bagID
        slot.slotID = slotID
    else
        slot.itemTexture:Hide()
        slot.count:Hide()
        slot.border:SetVertexColor(1, 1, 1, 1)
        slot.itemLink = nil
    end
end

-- Refresh all bag slots (only showing slots with items)
local function RefreshBags()
    if not bagsFrame or not isOpen then
        return
    end
    
    -- First pass: collect all slots that have items
    local itemsWithSlots = {}
    for bagID = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bagID) or 0
        for slotID = 1, numSlots do
            local itemInfo = C_Container.GetContainerItemInfo(bagID, slotID)
            if itemInfo and itemInfo.iconFileID then
                table.insert(itemsWithSlots, {
                    bagID = bagID,
                    slotID = slotID,
                    itemInfo = itemInfo
                })
            end
        end
    end
    
    local totalItems = #itemsWithSlots
    
    -- Calculate grid dimensions based on items, not total slots
    local numRows = math.ceil(totalItems / SLOTS_PER_ROW)
    local actualCols = math.min(SLOTS_PER_ROW, totalItems)
    local gridWidth = (actualCols * SLOT_SIZE) + ((actualCols - 1) * SLOT_SPACING)
    local gridHeight = (numRows * SLOT_SIZE) + ((numRows - 1) * SLOT_SPACING)
    
    -- Clear existing slots
    for _, slot in ipairs(bagSlots) do
        slot:Hide()
    end
    wipe(bagSlots)
    
    -- Create and position slots only for items
    for slotIndex, itemData in ipairs(itemsWithSlots) do
        local slot = bagSlots[slotIndex]
        if not slot then
            slot = CreateBagSlot(bagsFrame.container, slotIndex)
        end
        
        -- Calculate position
        local row = math.floor((slotIndex - 1) / SLOTS_PER_ROW)
        local col = (slotIndex - 1) % SLOTS_PER_ROW
        
        local x = col * (SLOT_SIZE + SLOT_SPACING)
        local y = -row * (SLOT_SIZE + SLOT_SPACING)
        
        -- Center the grid both horizontally and vertically with margin
        local containerWidth = bagsFrame.container:GetWidth()
        local containerHeight = bagsFrame.container:GetHeight()
        
        -- Ensure we have valid dimensions
        if containerWidth <= 0 or containerHeight <= 0 then
            return
        end
        
        -- Account for margin on all sides
        local availableWidth = containerWidth - (2 * GRID_MARGIN)
        local availableHeight = containerHeight - (2 * GRID_MARGIN)
        local offsetX = (availableWidth - gridWidth) / 2 + GRID_MARGIN
        local offsetY = (availableHeight - gridHeight) / 2 + GRID_MARGIN
        
        slot:SetPoint("TOPLEFT", bagsFrame.container, "TOPLEFT", x + offsetX, y - offsetY)
        slot:Show()
        
        -- Update slot with item data
        UpdateSlot(slot, itemData.bagID, itemData.slotID)
        
        bagSlots[slotIndex] = slot
    end
end

-- Open the bags frame
function BagsModule:Open()
    if not bagsFrame then
        bagsFrame = CreateBagsFrame()
    end
    
    isOpen = true
    bagsFrame:Show()
    RefreshBags()
end

-- Close the bags frame
function BagsModule:Close()
    if bagsFrame then
        bagsFrame:Hide()
        isOpen = false
        -- Ensure default bags stay hidden when we close
        HideAllDefaultBags()
    end
end

-- Toggle the bags frame
function BagsModule:Toggle()
    -- Ensure frame exists
    if not bagsFrame then
        bagsFrame = CreateBagsFrame()
    end
    
    -- Use our tracked state - it's kept in sync by OnShow/OnHide scripts
    -- This is more reliable than checking IsShown() which might have timing issues
    if isOpen then
        -- Frame is open, close it
        self:Close()
    else
        -- Frame is closed, open it
        self:Open()
    end
end

-- Apply function overrides
local function ApplyOverrides()
    -- Store original functions before overriding (only if not already stored)
    if ToggleBackpack and not originalToggleBackpack then
        originalToggleBackpack = ToggleBackpack
    end
    -- Force override - replace the function completely
    if ToggleBackpack then
        _G.ToggleBackpack = OverrideToggleBackpack
        ToggleBackpack = OverrideToggleBackpack
    end
    
    if OpenBackpack and not originalOpenBackpack then
        originalOpenBackpack = OpenBackpack
    end
    if OpenBackpack then
        OpenBackpack = OverrideOpenBackpack
    end
    
    if ToggleAllBags and not originalToggleAllBags then
        originalToggleAllBags = ToggleAllBags
    end
    if ToggleAllBags then
        ToggleAllBags = OverrideToggleAllBags
    end
    
    -- Also override the internal toggle functions if they exist
    if ToggleBackpack_Combined then
        ToggleBackpack_Combined = OverrideToggleBackpack
    end
    if ToggleBackpack_Individual then
        ToggleBackpack_Individual = OverrideToggleBackpack
    end
end

-- Initialize the module
function BagsModule:Initialize()
    -- Apply overrides immediately
    ApplyOverrides()
    
    -- Hide default bags initially
    HideAllDefaultBags()
    
    -- Register for bag update events
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
    eventFrame:RegisterEvent("BAG_OPEN")
    eventFrame:SetScript("OnEvent", function(self, event)
        -- Hide default bags whenever they try to show
        if event == "BAG_OPEN" then
            HideAllDefaultBags()
        end
        if isOpen then
            RefreshBags()
        end
    end)
    
    -- Hook into container frame Show methods to prevent them from showing
    for i = 1, 13 do
        local frame = _G["ContainerFrame"..i]
        if frame then
            local originalShow = frame.Show
            frame.Show = function(self, ...)
                HideAllDefaultBags()
                -- Don't call original Show, just hide it
            end
        end
    end
    
    -- Re-apply overrides on PLAYER_LOGIN to ensure they persist
    local loginFrame = CreateFrame("Frame")
    loginFrame:RegisterEvent("PLAYER_LOGIN")
    loginFrame:SetScript("OnEvent", function()
        -- Re-apply overrides after everything is loaded
        ApplyOverrides()
        
        -- Verify override is applied
        if ToggleBackpack == OverrideToggleBackpack then
            -- Override is correctly applied
        else
            -- Force apply again
            ApplyOverrides()
        end
    end)
end

return BagsModule

