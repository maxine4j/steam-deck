-- SteamDeck InterfaceCursor Module
-- Focused interface cursor for navigating our custom modules with controller D-pad

SteamDeckInterfaceCursorModule = {}
local InterfaceCursor = SteamDeckInterfaceCursorModule

-- State
local cursorFrame = nil
local currentTab = nil
local currentPanel = nil
local currentSelection = nil
local navigationGrid = nil
local slotToPositionMap = {}
local highlightFrame = nil
local contextMenuFrame = nil
local contextMenuOptions = {}
local contextMenuSelectedIndex = 1
local contextMenuActive = false
local dialogPopupActive = false
local dialogPopupFrame = nil
local dialogPopupButtons = {}
local dialogPopupSelectedIndex = 1

-- Configuration
local HIGHLIGHT_COLOR = {1, 1, 0, 1.0}  -- Bright yellow highlight, fully opaque
local HIGHLIGHT_THICKNESS = 4  -- Thicker border for better visibility
local HIGHLIGHT_PADDING = 6  -- Padding around the slot to make border larger
local PULSE_SPEED = 1  -- Seconds per pulse cycle (lower = faster)
local PULSE_MIN_ALPHA = 0.2  -- Minimum alpha for pulsing (0.0 to 1.0)
local PULSE_MAX_ALPHA = 1.0  -- Maximum alpha for pulsing (0.0 to 1.0)

-- D-pad button constants (must match WoW's button names exactly)
local DPAD_UP = "PADDUP"
local DPAD_DOWN = "PADDDOWN"
local DPAD_LEFT = "PADDLEFT"
local DPAD_RIGHT = "PADDRIGHT"

-- Bumper button constants
local BUMPER_LEFT = "PADLSHOULDER"
local BUMPER_RIGHT = "PADRSHOULDER"

-- Action button constants
local BUTTON_A = "PAD1"  -- A button (Xbox) / Cross (PlayStation) - for select/confirm
local BUTTON_X = "PAD3"  -- X button (Xbox) / Square (PlayStation)
local BUTTON_Y = "PAD4"  -- Y button (Xbox) / Triangle (PlayStation)
local BUTTON_B = "PAD2"  -- B button (Xbox) / Circle (PlayStation) - for cancel/close

-- Create the highlight frame that follows the selected slot
local function CreateHighlightFrame()
    local highlight = CreateFrame("Frame", "SteamDeckInterfaceCursorHighlight", UIParent)
    highlight:SetFrameStrata("TOOLTIP")
    highlight:SetFrameLevel(1000)
    highlight:EnableMouse(false)
    
    -- Animation state
    highlight.pulseTime = 0
    
    -- Create border textures for highlight
    local borderThickness = HIGHLIGHT_THICKNESS
    local r, g, b, a = HIGHLIGHT_COLOR[1], HIGHLIGHT_COLOR[2], HIGHLIGHT_COLOR[3], HIGHLIGHT_COLOR[4]
    
    -- Top border
    local top = highlight:CreateTexture(nil, "OVERLAY")
    top:SetColorTexture(r, g, b, a)
    highlight.top = top
    
    -- Bottom border
    local bottom = highlight:CreateTexture(nil, "OVERLAY")
    bottom:SetColorTexture(r, g, b, a)
    highlight.bottom = bottom
    
    -- Left border
    local left = highlight:CreateTexture(nil, "OVERLAY")
    left:SetColorTexture(r, g, b, a)
    highlight.left = left
    
    -- Right border
    local right = highlight:CreateTexture(nil, "OVERLAY")
    right:SetColorTexture(r, g, b, a)
    highlight.right = right
    
    -- Pulse animation OnUpdate
    highlight:SetScript("OnUpdate", function(self, elapsed)
        if not self:IsShown() then
            return
        end
        
        -- Update pulse time
        self.pulseTime = self.pulseTime + elapsed
        
        -- Calculate pulse alpha using sine wave for smooth pulsing
        -- Sine wave goes from -1 to 1, we map it to PULSE_MIN_ALPHA to PULSE_MAX_ALPHA
        local pulseCycle = (self.pulseTime / PULSE_SPEED) * (2 * math.pi)
        local sineValue = (math.sin(pulseCycle) + 1) / 2  -- Normalize to 0-1
        local currentAlpha = PULSE_MIN_ALPHA + (sineValue * (PULSE_MAX_ALPHA - PULSE_MIN_ALPHA))
        
        -- Apply alpha to all border textures
        local r, g, b = HIGHLIGHT_COLOR[1], HIGHLIGHT_COLOR[2], HIGHLIGHT_COLOR[3]
        self.top:SetColorTexture(r, g, b, currentAlpha)
        self.bottom:SetColorTexture(r, g, b, currentAlpha)
        self.left:SetColorTexture(r, g, b, currentAlpha)
        self.right:SetColorTexture(r, g, b, currentAlpha)
    end)
    
    highlight:Hide()
    return highlight
end

-- Update highlight frame to match a slot's position and size
local function UpdateHighlight(slot)
    if not highlightFrame or not slot then
        if highlightFrame then
            highlightFrame:Hide()
        end
        return
    end
    
    local slotWidth, slotHeight = slot:GetSize()
    local borderThickness = HIGHLIGHT_THICKNESS
    local padding = HIGHLIGHT_PADDING
    
    -- Calculate highlight size with padding
    local highlightWidth = slotWidth + (padding * 2)
    local highlightHeight = slotHeight + (padding * 2)
    
    -- Position highlight to match slot with padding (centered)
    highlightFrame:ClearAllPoints()
    highlightFrame:SetPoint("CENTER", slot, "CENTER", 0, 0)
    highlightFrame:SetSize(highlightWidth, highlightHeight)
    
    -- Update border textures with padding
    local r, g, b = HIGHLIGHT_COLOR[1], HIGHLIGHT_COLOR[2], HIGHLIGHT_COLOR[3]
    local baseAlpha = HIGHLIGHT_COLOR[4]
    
    -- Top border (extends full width)
    highlightFrame.top:ClearAllPoints()
    highlightFrame.top:SetSize(highlightWidth, borderThickness)
    highlightFrame.top:SetPoint("TOPLEFT", highlightFrame, "TOPLEFT", 0, 0)
    highlightFrame.top:SetPoint("TOPRIGHT", highlightFrame, "TOPRIGHT", 0, 0)
    highlightFrame.top:SetColorTexture(r, g, b, baseAlpha)
    highlightFrame.top:Show()
    
    -- Bottom border (extends full width)
    highlightFrame.bottom:ClearAllPoints()
    highlightFrame.bottom:SetSize(highlightWidth, borderThickness)
    highlightFrame.bottom:SetPoint("BOTTOMLEFT", highlightFrame, "BOTTOMLEFT", 0, 0)
    highlightFrame.bottom:SetPoint("BOTTOMRIGHT", highlightFrame, "BOTTOMRIGHT", 0, 0)
    highlightFrame.bottom:SetColorTexture(r, g, b, baseAlpha)
    highlightFrame.bottom:Show()
    
    -- Left border (extends full height)
    highlightFrame.left:ClearAllPoints()
    highlightFrame.left:SetSize(borderThickness, highlightHeight)
    highlightFrame.left:SetPoint("TOPLEFT", highlightFrame, "TOPLEFT", 0, 0)
    highlightFrame.left:SetPoint("BOTTOMLEFT", highlightFrame, "BOTTOMLEFT", 0, 0)
    highlightFrame.left:SetColorTexture(r, g, b, baseAlpha)
    highlightFrame.left:Show()
    
    -- Right border (extends full height)
    highlightFrame.right:ClearAllPoints()
    highlightFrame.right:SetSize(borderThickness, highlightHeight)
    highlightFrame.right:SetPoint("TOPRIGHT", highlightFrame, "TOPRIGHT", 0, 0)
    highlightFrame.right:SetPoint("BOTTOMRIGHT", highlightFrame, "BOTTOMRIGHT", 0, 0)
    highlightFrame.right:SetColorTexture(r, g, b, baseAlpha)
    highlightFrame.right:Show()
    
    -- Reset pulse time when highlighting a new slot for consistent animation
    highlightFrame.pulseTime = 0
    
    highlightFrame:Show()
end


-- Find the slot at a specific grid position
local function GetSlotAtPosition(grid, row, col)
    if grid[row] then
        return grid[row][col]
    end
    return nil
end

-- Find the first available slot in the grid
local function FindFirstSlot(grid)
    if not grid then
        return nil, nil, nil
    end
    
    for row = 0, #grid do
        if grid[row] then
            for col = 0, 8 do
                local slot = grid[row][col]
                if slot and slot:IsShown() then
                    return slot, row, col
                end
            end
        end
    end
    return nil, nil, nil
end

-- Find the last available slot in the grid (bottom row, rightmost column)
local function FindLastSlot(grid)
    if not grid then
        return nil, nil, nil
    end
    
    -- Find the maximum row
    local maxRow = -1
    for row = 0, #grid do
        if grid[row] then
            maxRow = row
        end
    end
    
    if maxRow < 0 then
        return nil, nil, nil
    end
    
    -- Find the rightmost column in the last row
    local maxCol = GetMaxColumn(grid, maxRow)
    if maxCol < 0 then
        return nil, nil, nil
    end
    
    -- Try to find a slot in the last row, starting from rightmost column
    for col = maxCol, 0, -1 do
        local slot = GetSlotAtPosition(grid, maxRow, col)
        if slot and slot:IsShown() then
            return slot, maxRow, col
        end
    end
    
    -- Fallback: search all columns in last row
    for col = 0, 20 do
        local slot = GetSlotAtPosition(grid, maxRow, col)
        if slot and slot:IsShown() then
            return slot, maxRow, col
        end
    end
    
    return nil, nil, nil
end

-- Find the maximum row in the grid
local function GetMaxRow(grid)
    if not grid then
        return -1
    end
    local maxRow = -1
    for row = 0, #grid do
        if grid[row] then
            maxRow = row
        end
    end
    return maxRow
end

-- Find the maximum column in the grid
local function GetMaxColumn(grid, row)
    if not grid[row] then
        return -1
    end
    local maxCol = -1
    for col = 0, 20 do  -- Increased range to handle wider grids
        if grid[row][col] then
            maxCol = col
        end
    end
    return maxCol
end

-- Check if we're at the edge of the current panel and can jump to another panel
local function TryJumpToOtherPanel(currentCol, direction)
    if not currentPanel or not currentTab or not currentSelection then
        return nil
    end
    
    local directionStr = tostring(direction)
    local isRightEdge = (directionStr == DPAD_RIGHT or directionStr == "PADDRIGHT")
    local isLeftEdge = (directionStr == DPAD_LEFT or directionStr == "PADDLEFT")
    
    -- Get current position
    local pos = slotToPositionMap[currentSelection]
    if not pos then
        return nil
    end
    
    -- Check if we're at the rightmost column (left panel) or leftmost column (right panel)
    local isAtRightEdge = false
    local isAtLeftEdge = false
    
    if navigationGrid then
        local maxCol = GetMaxColumn(navigationGrid, pos.row)
        isAtRightEdge = (pos.col >= maxCol and isRightEdge)
        isAtLeftEdge = (pos.col <= 0 and isLeftEdge)
    end
    
    -- Determine target panel based on current panel side and direction
    local targetPanel = nil
    if currentPanel.side == "left" and isAtRightEdge and isRightEdge then
        -- Left panel, at right edge, going right -> jump to right panel
        targetPanel = SteamDeckPanels.rightPanel
    elseif currentPanel.side == "right" and isAtLeftEdge and isLeftEdge then
        -- Right panel, at left edge, going left -> jump to left panel
        targetPanel = SteamDeckPanels.leftPanel
    end
    
    if not targetPanel or not targetPanel:IsPanelOpen() then
        return nil
    end
    
    -- Switch to target panel's active tab
    if targetPanel.activeTabId then
        local targetTab = targetPanel.tabs[targetPanel.activeTabId]
        if targetTab and targetTab.module then
            -- Update current panel and tab
            currentPanel = targetPanel
            currentTab = targetTab.module
            
            -- Get navigation grid from target tab
            if targetTab.module.GetNavGrid then
                navigationGrid, slotToPositionMap = targetTab.module:GetNavGrid()
            end
            
            -- Find the leftmost slot in the same row (for right panel) or rightmost slot (for left panel)
            if navigationGrid then
                local targetRow = pos.row
                local maxRow = GetMaxRow(navigationGrid)
                local wasOutOfBounds = false
                
                -- If target row is beyond the maximum row, use the last row instead
                if targetRow > maxRow then
                    targetRow = maxRow
                    wasOutOfBounds = true
                end
                -- If target row is negative (shouldn't happen), use row 0
                if targetRow < 0 then
                    targetRow = 0
                end
                
                -- If the row doesn't exist in the grid, we'll need to use fallback
                if not navigationGrid[targetRow] then
                    wasOutOfBounds = true
                end
                
                local targetCol = 0  -- Start from leftmost column for right panel
                if targetPanel.side == "left" then
                    -- If jumping to left panel, find rightmost column
                    targetCol = GetMaxColumn(navigationGrid, targetRow)
                end
                
                -- Try to find a slot at the target position
                local targetSlot = GetSlotAtPosition(navigationGrid, targetRow, targetCol)
                if targetSlot and targetSlot:IsShown() then
                    -- Activate cursor for the new tab
                    InterfaceCursor:Activate(targetTab.module)
                    return targetSlot
                end
                
                -- If not found, find first available slot in that row
                if targetPanel.side == "right" then
                    for col = 0, 20 do
                        local slot = GetSlotAtPosition(navigationGrid, targetRow, col)
                        if slot and slot:IsShown() then
                            InterfaceCursor:Activate(targetTab.module)
                            return slot
                        end
                    end
                else
                    for col = 20, 0, -1 do
                        local slot = GetSlotAtPosition(navigationGrid, targetRow, col)
                        if slot and slot:IsShown() then
                            InterfaceCursor:Activate(targetTab.module)
                            return slot
                        end
                    end
                end
                
                -- If we were out of bounds and couldn't find a slot in the adjusted row, use last slot
                if wasOutOfBounds then
                    local lastSlot, _, _ = FindLastSlot(navigationGrid)
                    if lastSlot then
                        InterfaceCursor:Activate(targetTab.module)
                        return lastSlot
                    end
                end
            end
            
            -- Fallback: use last slot instead of first when jumping between panels
            if navigationGrid then
                local lastSlot, _, _ = FindLastSlot(navigationGrid)
                if lastSlot then
                    InterfaceCursor:Activate(targetTab.module)
                    return lastSlot
                end
                -- Ultimate fallback: find first slot if no last slot found
                local firstSlot, _, _ = FindFirstSlot(navigationGrid)
                if firstSlot then
                    InterfaceCursor:Activate(targetTab.module)
                    return firstSlot
                end
            end
        end
    end
    
    return nil
end

-- Navigate to adjacent slot based on direction
local function NavigateToAdjacentSlot(grid, slotToPosition, currentSlot, direction)
    local pos = slotToPosition[currentSlot]
    if not pos then
        return nil
    end
    
    local newRow, newCol = pos.row, pos.col
    local directionStr = tostring(direction)
    
    -- Calculate new position based on direction
    if directionStr == DPAD_UP or directionStr == "PADDUP" then
        newRow = newRow - 1
    elseif directionStr == DPAD_DOWN or directionStr == "PADDDOWN" then
        newRow = newRow + 1
    elseif directionStr == DPAD_LEFT or directionStr == "PADDLEFT" then
        newCol = newCol - 1
    elseif directionStr == DPAD_RIGHT or directionStr == "PADDRIGHT" then
        newCol = newCol + 1
    else
        return nil
    end
    
    -- Try to find slot at new position
    local newSlot = GetSlotAtPosition(grid, newRow, newCol)
    if newSlot and newSlot:IsShown() then
        return newSlot
    end
    
    -- If no slot at exact position, try to find nearest valid slot in that direction
    -- For vertical movement, try to find slot in same column
    if directionStr == DPAD_UP or directionStr == "PADDUP" then
        -- Look for nearest slot above in same column
        for checkRow = newRow, 0, -1 do
            local checkSlot = GetSlotAtPosition(grid, checkRow, newCol)
            if checkSlot and checkSlot:IsShown() then
                return checkSlot
            end
        end
    elseif directionStr == DPAD_DOWN or directionStr == "PADDDOWN" then
        -- Look for nearest slot below in same column
        for checkRow = newRow, #grid do
            local checkSlot = GetSlotAtPosition(grid, checkRow, newCol)
            if checkSlot and checkSlot:IsShown() then
                return checkSlot
            end
        end
    -- For horizontal movement, try to find slot in same row
    elseif directionStr == DPAD_LEFT or directionStr == "PADDLEFT" then
        -- Look for nearest slot to the left in same row
        for checkCol = newCol, 0, -1 do
            local checkSlot = GetSlotAtPosition(grid, newRow, checkCol)
            if checkSlot and checkSlot:IsShown() then
                return checkSlot
            end
        end
        
        -- If we can't find a slot to the left, try jumping to the other panel
        return TryJumpToOtherPanel(newCol, direction)
    elseif directionStr == DPAD_RIGHT or directionStr == "PADDRIGHT" then
        -- Look for nearest slot to the right in same row
        -- Find max column in this row
        local maxCol = GetMaxColumn(grid, newRow)
        for checkCol = newCol, maxCol do
            local checkSlot = GetSlotAtPosition(grid, newRow, checkCol)
            if checkSlot and checkSlot:IsShown() then
                return checkSlot
            end
        end
        
        -- If we can't find a slot to the right, try jumping to the other panel
        return TryJumpToOtherPanel(newCol, direction)
    end
    
    return nil
end

-- Handle item usage/interaction
local function HandleItemUse()
    if not currentSelection then
        return
    end
    
    -- Check if it's a bag slot (has bagID and slotID)
    if currentSelection.bagID and currentSelection.slotID then
        -- Bag slot - use the item (similar to right-click behavior)
        if currentSelection.itemLink then
            -- If it has an item link, use it (opens bags, uses consumables, etc.)
            C_Container.UseContainerItem(currentSelection.bagID, currentSelection.slotID)
        elseif SpellCanTargetItem() or SpellCanTargetItemID() then
            -- If a spell is targeting items, use it for targeting
            C_Container.UseContainerItem(currentSelection.bagID, currentSelection.slotID)
        else
            -- Otherwise, pick it up (for moving/equipping)
            C_Container.PickupContainerItem(currentSelection.bagID, currentSelection.slotID)
        end
        return
    end
    
    -- Check if it's an equipment slot (has slotID but no bagID)
    if currentSelection.slotID and not currentSelection.bagID then
        -- Equipment slot - use the item (similar to right-click behavior)
        local itemLink = GetInventoryItemLink("player", currentSelection.slotID)
        if itemLink then
            -- If slot has an item, use it (e.g., use trinket, use consumable)
            UseInventoryItem(currentSelection.slotID)
        else
            -- If slot is empty, pick it up (for equipping from cursor)
            PickupInventoryItem(currentSelection.slotID)
        end
        return
    end
    
    -- For stat frames or other non-item selections, do nothing
    -- (Could add tooltip display here in the future)
end

-- Set selection to a specific slot
local function SetSelection(slot)
    currentSelection = slot
    UpdateHighlight(slot)
    
    -- Hide tooltip and context menu when selection changes
    GameTooltip:Hide()
    if contextMenuFrame then
        contextMenuFrame:Hide()
        contextMenuActive = false
    end
end


-- Handle tab navigation with bumper buttons
local function HandleTabNavigation(direction)
    if not currentTab then
        return
    end
    
    -- Get panel from current tab
    local panel = currentTab.panel
    if not panel or not panel.tabs then
        return
    end
    
    -- Get all tabs sorted by order
    local tabDataArray = {}
    for _, tabData in pairs(panel.tabs) do
        table.insert(tabDataArray, tabData)
    end
    
    -- Sort by order
    table.sort(tabDataArray, function(a, b) return a.order < b.order end)
    
    -- Find current tab index
    local currentIndex = nil
    for i, tabData in ipairs(tabDataArray) do
        if tabData.tabId == panel.activeTabId then
            currentIndex = i
            break
        end
    end
    
    if not currentIndex then
        return
    end
    
    -- Calculate new index
    local newIndex = currentIndex
    if direction == "left" or direction == BUMPER_LEFT or direction == "PADLSHOULDER" then
        newIndex = currentIndex - 1
        if newIndex < 1 then
            newIndex = #tabDataArray  -- Wrap to last tab
        end
    elseif direction == "right" or direction == BUMPER_RIGHT or direction == "PADRSHOULDER" then
        newIndex = currentIndex + 1
        if newIndex > #tabDataArray then
            newIndex = 1  -- Wrap to first tab
        end
    end
    
    -- Switch to new tab
    if newIndex >= 1 and newIndex <= #tabDataArray then
        local newTabData = tabDataArray[newIndex]
        if newTabData and newTabData.tabId then
            panel:SetActiveTab(newTabData.tabId)
        end
    end
end

-- Handle D-pad navigation
local function HandleDpadNavigation(button)
    if not currentTab then
        return
    end
    
    -- Get navigation grid from current tab
    if not navigationGrid then
        if currentTab and currentTab.GetNavGrid then
            navigationGrid, slotToPositionMap = currentTab:GetNavGrid()
        end
    end
    
    if not navigationGrid then
        return
    end
    
    if not currentSelection then
        -- No current selection, select first slot
        local firstSlot, row, col = FindFirstSlot(navigationGrid)
        if firstSlot then
            SetSelection(firstSlot)
        end
        return
    end
    
    -- Use button as-is (already normalized to string)
    local normalizedButton = button
    
    -- Navigate to adjacent slot using stored position map
    local newSlot = NavigateToAdjacentSlot(navigationGrid, slotToPositionMap, currentSelection, normalizedButton)
    if newSlot then
        SetSelection(newSlot)
    end
end

-- Activate cursor for a tab
function InterfaceCursor:Activate(tab)
    currentTab = tab
    
    -- Get panel from tab
    if tab and tab.panel then
        currentPanel = tab.panel
    end
    
    -- Get navigation grid from tab
    if tab and tab.GetNavGrid then
        navigationGrid, slotToPositionMap = tab:GetNavGrid()
    end
    
    -- Show highlight if we have a selection
    if currentSelection then
        UpdateHighlight(currentSelection)
    elseif navigationGrid then
        -- Select first slot if available
        local firstSlot, row, col = FindFirstSlot(navigationGrid)
        if firstSlot then
            SetSelection(firstSlot)
        end
    end
end

-- Deactivate cursor
function InterfaceCursor:Deactivate()
    currentTab = nil
    currentPanel = nil
    currentSelection = nil
    navigationGrid = nil
    slotToPositionMap = {}
    
    if highlightFrame then
        highlightFrame:Hide()
    end
    
    GameTooltip:Hide()
end

-- Refresh navigation grid from current tab
function InterfaceCursor:RefreshGrid()
    if currentTab and currentTab.GetNavGrid then
        navigationGrid, slotToPositionMap = currentTab:GetNavGrid()
        
        -- Validate current selection
        if currentSelection then
            local pos = slotToPositionMap[currentSelection]
            if not pos or not currentSelection:IsShown() then
                -- Current selection is invalid, select first slot
                local firstSlot, _, _ = FindFirstSlot(navigationGrid)
                if firstSlot then
                    SetSelection(firstSlot)
                else
                    currentSelection = nil
                    if highlightFrame then
                        highlightFrame:Hide()
                    end
                end
            else
                -- Update highlight for current selection
                UpdateHighlight(currentSelection)
            end
        elseif navigationGrid then
            -- Select first slot if available
            local firstSlot, row, col = FindFirstSlot(navigationGrid)
            if firstSlot then
                SetSelection(firstSlot)
            end
        end
    end
end

-- Create context menu frame
local function CreateContextMenu()
    local menu = CreateFrame("Frame", "SteamDeckContextMenu", UIParent)
    menu:SetSize(360, 500)  -- Reduced by 10% from 400
    menu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(2000)
    menu:EnableMouse(false)
    menu:Hide()
    
    -- Background
    local bg = menu:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(menu)
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.95)
    menu.bg = bg
    
    -- Border
    local border = CreateFrame("Frame", nil, menu)
    border:SetAllPoints(menu)
    local borderThickness = 2
    local borderColor = {0.5, 0.5, 0.5, 1.0}
    
    local topBorder = border:CreateTexture(nil, "OVERLAY")
    topBorder:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    topBorder:SetSize(360, borderThickness)
    topBorder:SetPoint("TOPLEFT", border, "TOPLEFT", 0, 0)
    topBorder:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, 0)
    
    local bottomBorder = border:CreateTexture(nil, "OVERLAY")
    bottomBorder:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    bottomBorder:SetSize(360, borderThickness)
    bottomBorder:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, 0)
    bottomBorder:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0)
    
    local leftBorder = border:CreateTexture(nil, "OVERLAY")
    leftBorder:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    leftBorder:SetSize(borderThickness, 500)
    leftBorder:SetPoint("TOPLEFT", border, "TOPLEFT", 0, 0)
    leftBorder:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, 0)
    
    local rightBorder = border:CreateTexture(nil, "OVERLAY")
    rightBorder:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    rightBorder:SetSize(borderThickness, 500)
    rightBorder:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, 0)
    rightBorder:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0)
    
    -- Item display area (top section)
    local itemDisplay = CreateFrame("Frame", nil, menu)
    itemDisplay:SetSize(340, 80)  -- Just enough for icon and name
    itemDisplay:SetPoint("TOP", menu, "TOP", 0, -20)
    menu.itemDisplay = itemDisplay
    
    -- Item icon with border
    local itemIconBg = CreateFrame("Frame", nil, itemDisplay)
    itemIconBg:SetSize(64, 64)
    itemIconBg:SetPoint("TOPLEFT", itemDisplay, "TOPLEFT", 10, 0)
    menu.itemIconBg = itemIconBg
    
    local itemIcon = itemIconBg:CreateTexture(nil, "ARTWORK")
    itemIcon:SetSize(60, 60)
    itemIcon:SetPoint("CENTER", itemIconBg, "CENTER", 0, 0)
    itemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    menu.itemIcon = itemIcon
    
    -- Icon border (for quality)
    local iconBorder = itemIconBg:CreateTexture(nil, "OVERLAY")
    iconBorder:SetSize(64, 64)
    iconBorder:SetPoint("CENTER", itemIconBg, "CENTER", 0, 0)
    iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    iconBorder:Hide()
    menu.iconBorder = iconBorder
    
    -- Item name
    local itemName = itemDisplay:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    itemName:SetPoint("LEFT", itemIconBg, "RIGHT", 10, 0)
    itemName:SetPoint("RIGHT", itemDisplay, "RIGHT", -10, 0)
    itemName:SetJustifyH("LEFT")
    itemName:SetText("Item Name")
    menu.itemName = itemName
    
    -- Custom tooltip area (centered, fills space between item display and options)
    local tooltipArea = CreateFrame("Frame", nil, menu)
    tooltipArea:SetPoint("TOP", itemDisplay, "BOTTOM", 0, 0)  -- No gap, tooltip starts immediately after item name
    tooltipArea:SetPoint("BOTTOM", menu, "BOTTOM", 220, 0)  -- Leave room for options at bottom
    tooltipArea:SetPoint("LEFT", menu, "LEFT", 10, 0)
    tooltipArea:SetPoint("RIGHT", menu, "RIGHT", -10, 0)
    menu.tooltipArea = tooltipArea
    
    -- Content frame for tooltip text (no scroll, just regular frame)
    local contentFrame = CreateFrame("Frame", nil, tooltipArea)
    contentFrame:SetWidth(300)
    contentFrame:SetPoint("TOPLEFT", tooltipArea, "TOPLEFT", 10, 0)  -- No top margin, starts at top
    menu.tooltipContent = contentFrame
    
    -- Tooltip text lines container
    menu.tooltipLines = {}
    
    -- Options list (bottom section, anchored to bottom of menu)
    local optionsList = CreateFrame("Frame", nil, menu)
    optionsList:SetSize(340, 200)  -- Reduced height to give tooltip more room
    optionsList:SetPoint("BOTTOM", menu, "BOTTOM", 0, 20)
    menu.optionsList = optionsList
    
    -- Options container
    menu.optionButtons = {}
    
    return menu
end

-- Get item information from selection
local function GetItemInfoFromSelection()
    if not currentSelection then
        return nil
    end
    
    local itemLink = nil
    local itemIcon = nil
    local itemName = nil
    local itemLocation = nil
    
    -- Check if it's a bag slot
    if currentSelection.bagID and currentSelection.slotID then
        itemLink = C_Container.GetContainerItemLink(currentSelection.bagID, currentSelection.slotID)
        if itemLink then
            local itemInfo = C_Container.GetContainerItemInfo(currentSelection.bagID, currentSelection.slotID)
            if itemInfo then
                itemIcon = itemInfo.iconFileID
            end
            itemName = select(1, GetItemInfo(itemLink))  -- GetItemInfo returns itemName as first value
            itemLocation = ItemLocation:CreateFromBagAndSlot(currentSelection.bagID, currentSelection.slotID)
        end
    -- Check if it's an equipment slot
    elseif currentSelection.slotID and not currentSelection.bagID then
        itemLink = GetInventoryItemLink("player", currentSelection.slotID)
        if itemLink then
            itemIcon = GetInventoryItemTexture("player", currentSelection.slotID)
            itemName = select(1, GetItemInfo(itemLink))  -- GetItemInfo returns itemName as first value
            itemLocation = ItemLocation:CreateFromEquipmentSlot(currentSelection.slotID)
        end
    end
    
    if not itemLink then
        return nil
    end
    
    return {
        itemLink = itemLink,
        itemIcon = itemIcon,
        itemName = itemName,
        itemLocation = itemLocation,
        bagID = currentSelection.bagID,
        slotID = currentSelection.slotID,
        isEquipment = (currentSelection.slotID and not currentSelection.bagID)
    }
end

-- Build menu options based on item type
local function BuildMenuOptions(itemInfo)
    local options = {}
    
    if not itemInfo then
        return options
    end
    
    -- Equip option (for equippable items in bags)
    if itemInfo.bagID and itemInfo.slotID and itemInfo.itemLink then
        -- Get ItemInfo from itemLink (C_Item.GetItemInfo accepts itemLink)
        local itemInfoObj = C_Item.GetItemInfo(itemInfo.itemLink)
        if itemInfoObj and C_Item.IsEquippableItem(itemInfoObj) and not C_Item.IsEquippedItem(itemInfoObj) then
            table.insert(options, {
                text = "Equip",
                action = function()
                    -- Equip item by name/link
                    C_Item.EquipItemByName(itemInfo.itemLink)
                end
            })
        end
    end
    
    -- Inspect option (for gear, mounts, pets, and housing items)
    if itemInfo.itemLink then
        table.insert(options, {
            text = "Inspect",
            action = function()
                -- DressUpLink opens equipment preview window for items, mounts, pets, and housing
                -- It handles: DressUpItemLink, DressUpMountLink, DressUpBattlePetLink, and housing previews
                DressUpLink(itemInfo.itemLink)
            end
        })
    end
    
    -- Delete option (for items that can be deleted)
    if itemInfo.bagID and itemInfo.slotID then
        table.insert(options, {
            text = "Delete",
            action = function()
                -- Pick up item to cursor first
                C_Container.PickupContainerItem(itemInfo.bagID, itemInfo.slotID)
                -- Show delete confirmation with appropriate popup based on quality
                if CursorHasItem() then
                    -- Get item quality to determine which popup to use
                    local containerInfo = C_Container.GetContainerItemInfo(itemInfo.bagID, itemInfo.slotID)
                    local itemQuality = containerInfo and containerInfo.quality or 0
                    
                    -- Use DELETE_GOOD_ITEM for rare+ items (except heirlooms)
                    -- LE_ITEM_QUALITY_RARE = 3 (blue), LE_ITEM_QUALITY_EPIC = 4 (purple), LE_ITEM_QUALITY_LEGENDARY = 5 (orange)
                    -- LE_ITEM_QUALITY_HEIRLOOM = 7
                    if itemQuality and itemQuality >= 3 and itemQuality ~= 7 then
                        StaticPopup_Show("DELETE_GOOD_ITEM", itemInfo.itemLink)
                    else
                        StaticPopup_Show("DELETE_ITEM", itemInfo.itemLink)
                    end
                end
            end
        })
    end
    
    return options
end

-- Update context menu selection highlight
local function UpdateContextMenuSelection()
    if not contextMenuFrame then
        return
    end
    
    for i, button in ipairs(contextMenuFrame.optionButtons) do
        if button.highlight then
            if i == contextMenuSelectedIndex then
                button.highlight:Show()
            else
                button.highlight:Hide()
            end
        end
    end
end

-- Update context menu display
local function UpdateContextMenu()
    if not contextMenuFrame then
        return
    end
    
    local itemInfo = GetItemInfoFromSelection()
    if not itemInfo then
        contextMenuFrame:Hide()
        contextMenuActive = false
        return
    end
    
    -- Update item display
    if itemInfo.itemIcon then
        contextMenuFrame.itemIcon:SetTexture(itemInfo.itemIcon)
    else
        contextMenuFrame.itemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    
    -- Get item quality and set colors
    local itemQuality = nil
    if itemInfo.bagID and itemInfo.slotID then
        local containerInfo = C_Container.GetContainerItemInfo(itemInfo.bagID, itemInfo.slotID)
        if containerInfo then
            itemQuality = containerInfo.quality
        end
    elseif itemInfo.isEquipment then
        itemQuality = GetInventoryItemQuality("player", itemInfo.slotID)
    end
    
    -- If we don't have quality from container, try from item link
    if not itemQuality and itemInfo.itemLink then
        local _, _, quality = GetItemInfo(itemInfo.itemLink)
        itemQuality = quality
    end
    
    -- Set item name color based on quality
    if itemQuality and itemQuality > 0 then
        local r, g, b = GetItemQualityColor(itemQuality)
        contextMenuFrame.itemName:SetTextColor(r, g, b, 1)
    else
        contextMenuFrame.itemName:SetTextColor(1, 1, 1, 1)  -- Default white
    end
    
    -- Set icon border color based on quality
    if itemQuality and itemQuality > 0 then
        local r, g, b = GetItemQualityColor(itemQuality)
        contextMenuFrame.iconBorder:SetVertexColor(r, g, b, 1)
        contextMenuFrame.iconBorder:Show()
    else
        contextMenuFrame.iconBorder:Hide()
    end
    
    if itemInfo.itemName then
        contextMenuFrame.itemName:SetText(itemInfo.itemName)
    else
        contextMenuFrame.itemName:SetText("Unknown Item")
    end
    
    -- Clear existing tooltip lines
    for _, line in ipairs(contextMenuFrame.tooltipLines) do
        line:Hide()
    end
    wipe(contextMenuFrame.tooltipLines)
    
    -- Get tooltip data and display it
    local tooltipData = nil
    if itemInfo.bagID and itemInfo.slotID then
        tooltipData = C_TooltipInfo.GetBagItem(itemInfo.bagID, itemInfo.slotID)
    elseif itemInfo.isEquipment then
        tooltipData = C_TooltipInfo.GetInventoryItem("player", itemInfo.slotID)
    else
        tooltipData = C_TooltipInfo.GetHyperlink(itemInfo.itemLink)
    end
    
    -- Display tooltip lines with dynamic sizing
    if tooltipData and tooltipData.lines then
        local contentFrame = contextMenuFrame.tooltipContent
        local spacing = 2
        
        -- Calculate available screen height
        local screenHeight = GetScreenHeight()
        local itemDisplayHeight = contextMenuFrame.itemDisplay:GetHeight()
        local optionsListHeight = contextMenuFrame.optionsList:GetHeight()
        local menuPadding = 40  -- Top and bottom padding
        local maxTooltipHeight = screenHeight - itemDisplayHeight - optionsListHeight - menuPadding
        
        -- First pass: create all lines with default font size (1.5x)
        local baseFont, baseFontHeight, baseFlags = GameFontNormal:GetFont()
        local defaultFontHeight = baseFontHeight * 1.5
        local fontHeight = defaultFontHeight
        local currentY = 0
        local displayedLineIndex = 0
        local linesToDisplay = {}
        
        -- Collect lines to display (skip item name)
        for i, lineData in ipairs(tooltipData.lines) do
            local text = lineData.leftText or ""
            if not (i == 1 and text == itemInfo.itemName) then
                displayedLineIndex = displayedLineIndex + 1
                table.insert(linesToDisplay, {
                    data = lineData,
                    index = displayedLineIndex
                })
            end
        end
        
        -- Try to fit with default font size first
        local needsResize = false
        local actualContentHeight = 0
        
        -- Calculate content height with default font
        for _, lineInfo in ipairs(linesToDisplay) do
            local line = contextMenuFrame.tooltipLines[lineInfo.index]
            if not line then
                line = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                table.insert(contextMenuFrame.tooltipLines, line)
            end
            
            line:SetFont(baseFont, defaultFontHeight, baseFlags)
            line:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
            line:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
            line:SetJustifyH("LEFT")
            line:SetJustifyV("TOP")
            line:SetNonSpaceWrap(true)
            line:SetText(lineInfo.data.leftText or "")
            
            local lineHeight = line:GetHeight()
            actualContentHeight = actualContentHeight + lineHeight + spacing
        end
        
        -- If content is too tall, reduce font size
        if actualContentHeight > maxTooltipHeight then
            needsResize = true
            -- Calculate scale factor
            local scaleFactor = maxTooltipHeight / actualContentHeight
            fontHeight = defaultFontHeight * scaleFactor
            -- Ensure minimum readable font size (at least 0.5x of default)
            if fontHeight < baseFontHeight * 0.5 then
                fontHeight = baseFontHeight * 0.5
            end
        end
        
        -- Second pass: position and display lines with calculated font size
        currentY = 0
        for _, lineInfo in ipairs(linesToDisplay) do
            local line = contextMenuFrame.tooltipLines[lineInfo.index]
            
            -- Set font size
            line:SetFont(baseFont, fontHeight, baseFlags)
            
            line:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -currentY)
            line:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
            line:SetJustifyH("LEFT")
            line:SetJustifyV("TOP")
            line:SetNonSpaceWrap(true)
            
            -- Set text and color
            local text = lineInfo.data.leftText or ""
            if lineInfo.data.leftColor then
                line:SetTextColor(lineInfo.data.leftColor.r, lineInfo.data.leftColor.g, lineInfo.data.leftColor.b, lineInfo.data.leftColor.a or 1)
            else
                line:SetTextColor(1, 1, 1, 1)  -- Default white
            end
            line:SetText(text)
            line:Show()
            
            -- Get actual height after text is set
            local lineHeightActual = line:GetHeight()
            currentY = currentY + lineHeightActual + spacing
        end
        
        -- Hide unused lines
        for i = #linesToDisplay + 1, #contextMenuFrame.tooltipLines do
            contextMenuFrame.tooltipLines[i]:Hide()
        end
        
        -- Update content frame height
        contentFrame:SetHeight(currentY)
        
        -- Calculate and set menu height (expand up to screen height)
        local tooltipAreaHeight = math.min(currentY + 20, maxTooltipHeight)  -- Add padding
        local menuHeight = itemDisplayHeight + tooltipAreaHeight + optionsListHeight + menuPadding
        menuHeight = math.min(menuHeight, screenHeight - 20)  -- Leave some margin from screen edges
        menuHeight = math.max(menuHeight, 500)  -- Minimum height
        
        -- Update menu size
        contextMenuFrame:SetHeight(menuHeight)
        
        -- Update tooltip area bottom anchor to fill available space
        contextMenuFrame.tooltipArea:ClearAllPoints()
        contextMenuFrame.tooltipArea:SetPoint("TOP", contextMenuFrame.itemDisplay, "BOTTOM", 0, 0)
        contextMenuFrame.tooltipArea:SetPoint("BOTTOM", contextMenuFrame.optionsList, "TOP", 0, 0)
        contextMenuFrame.tooltipArea:SetPoint("LEFT", contextMenuFrame, "LEFT", 10, 0)
        contextMenuFrame.tooltipArea:SetPoint("RIGHT", contextMenuFrame, "RIGHT", -10, 0)
    else
        -- No tooltip data, use default menu height
        contextMenuFrame:SetHeight(500)
    end
    
    -- Build and display options
    contextMenuOptions = BuildMenuOptions(itemInfo)
    
    -- Clear existing option buttons
    for _, button in ipairs(contextMenuFrame.optionButtons) do
        button:Hide()
    end
    wipe(contextMenuFrame.optionButtons)
    
    if #contextMenuOptions == 0 then
        -- No options available
        local noOptionsText = contextMenuFrame.optionsList:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noOptionsText:SetPoint("CENTER", contextMenuFrame.optionsList, "CENTER", 0, 0)
        noOptionsText:SetText("No actions available")
        table.insert(contextMenuFrame.optionButtons, noOptionsText)
    else
        -- Create option buttons
        local buttonHeight = 30
        local spacing = 5
        local startY = 0
        
        for i, option in ipairs(contextMenuOptions) do
            local button = CreateFrame("Frame", nil, contextMenuFrame.optionsList)
            button:SetSize(320, buttonHeight)  -- Reduced to match new width
            -- Position from bottom, growing upward
            button:SetPoint("BOTTOM", contextMenuFrame.optionsList, "BOTTOM", 0, startY + (i - 1) * (buttonHeight + spacing))
            
            -- Button background
            local bg = button:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(button)
            bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
            button.bg = bg
            
            -- Highlight for selected option
            local highlight = button:CreateTexture(nil, "OVERLAY")
            highlight:SetAllPoints(button)
            highlight:SetColorTexture(1, 1, 0, 0.3)
            highlight:Hide()
            button.highlight = highlight
            
            -- Option text
            local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("LEFT", button, "LEFT", 10, 0)
            text:SetText(option.text)
            button.text = text
            
            button.option = option
            button.index = i
            table.insert(contextMenuFrame.optionButtons, button)
        end
    end
    
    -- Reset selection to first option
    contextMenuSelectedIndex = 1
    UpdateContextMenuSelection()
end

-- Handle context menu navigation
local function HandleContextMenuNavigation(direction)
    if not contextMenuActive or #contextMenuOptions == 0 then
        return
    end
    
    local directionStr = tostring(direction)
    
    -- Buttons are positioned from bottom (growing upward), so navigation is inverted
    -- UP visually moves to higher index (button above), DOWN moves to lower index (button below)
    if directionStr == DPAD_UP or directionStr == "PADDUP" then
        contextMenuSelectedIndex = contextMenuSelectedIndex + 1  -- Inverted: +1 to go up visually
        if contextMenuSelectedIndex > #contextMenuOptions then
            contextMenuSelectedIndex = 1
        end
    elseif directionStr == DPAD_DOWN or directionStr == "PADDDOWN" then
        contextMenuSelectedIndex = contextMenuSelectedIndex - 1  -- Inverted: -1 to go down visually
        if contextMenuSelectedIndex < 1 then
            contextMenuSelectedIndex = #contextMenuOptions
        end
    end
    
    UpdateContextMenuSelection()
end

-- Handle context menu option selection
local function HandleContextMenuSelect()
    if not contextMenuActive or #contextMenuOptions == 0 then
        return
    end
    
    local option = contextMenuOptions[contextMenuSelectedIndex]
    if option and option.action then
        option.action()
        -- Close menu after action
        if contextMenuFrame then
            contextMenuFrame:Hide()
        end
        contextMenuActive = false
        GameTooltip:Hide()
    end
end

-- Show context menu
local function ShowContextMenu()
    if not currentSelection then
        return
    end
    
    if not contextMenuFrame then
        contextMenuFrame = CreateContextMenu()
    end
    
    UpdateContextMenu()
    contextMenuFrame:Show()
    contextMenuActive = true
end

-- Hide context menu
local function HideContextMenu()
    if contextMenuFrame then
        contextMenuFrame:Hide()
        contextMenuActive = false
        -- Clear tooltip lines
        if contextMenuFrame.tooltipLines then
            for _, line in ipairs(contextMenuFrame.tooltipLines) do
                line:Hide()
            end
        end
    end
end

-- Get currently shown dialog popup
local function GetShownDialog()
    -- Check StaticPopup frames (StaticPopup1, StaticPopup2, etc.)
    for i = 1, 4 do
        local dialog = _G["StaticPopup"..i]
        if dialog and dialog:IsShown() and dialog.which then
            return dialog
        end
    end
    return nil
end

-- Get buttons from dialog popup
local function GetDialogButtons(dialog)
    local buttons = {}
    -- Check for buttons 1-4 (most dialogs use 1-2)
    for i = 1, 4 do
        local button = dialog:GetButton(i)
        if button and button:IsShown() then
            table.insert(buttons, {
                button = button,
                index = i
            })
        end
    end
    return buttons
end

-- Activate cursor for dialog popup
local function ActivateDialogPopup()
    local dialog = GetShownDialog()
    if not dialog then
        dialogPopupActive = false
        dialogPopupFrame = nil
        dialogPopupButtons = {}
        return
    end
    
    dialogPopupFrame = dialog
    dialogPopupButtons = GetDialogButtons(dialog)
    
    -- Prefill edit box with "DELETE" for delete confirmation dialogs
    if dialog.which == "DELETE_GOOD_ITEM" or dialog.which == "DELETE_GOOD_QUEST_ITEM" then
        local editBox = dialog:GetEditBox()
        if editBox and editBox:IsShown() then
            -- Set text to "DELETE" to prefill the confirmation
            editBox:SetText("DELETE")
            -- Trigger the text changed handler to enable the button
            -- The handler checks if text matches DELETE_ITEM_CONFIRM_STRING
            if editBox:GetScript("OnTextChanged") then
                editBox:GetScript("OnTextChanged")(editBox, true)
            end
        end
    end
    
    if #dialogPopupButtons > 0 then
        dialogPopupActive = true
        dialogPopupSelectedIndex = 1
        -- Deactivate regular cursor navigation
        if currentTab then
            InterfaceCursor:Deactivate()
        end
        -- Select first button
        UpdateHighlight(dialogPopupButtons[1].button)
    else
        dialogPopupActive = false
    end
end

-- Handle dialog popup navigation
local function HandleDialogPopupNavigation(direction)
    if not dialogPopupActive or #dialogPopupButtons == 0 then
        return
    end
    
    local directionStr = tostring(direction)
    
    if directionStr == DPAD_LEFT or directionStr == "PADDLEFT" then
        dialogPopupSelectedIndex = dialogPopupSelectedIndex - 1
        if dialogPopupSelectedIndex < 1 then
            dialogPopupSelectedIndex = #dialogPopupButtons
        end
    elseif directionStr == DPAD_RIGHT or directionStr == "PADDRIGHT" then
        dialogPopupSelectedIndex = dialogPopupSelectedIndex + 1
        if dialogPopupSelectedIndex > #dialogPopupButtons then
            dialogPopupSelectedIndex = 1
        end
    end
    
    -- Update highlight
    if dialogPopupButtons[dialogPopupSelectedIndex] then
        UpdateHighlight(dialogPopupButtons[dialogPopupSelectedIndex].button)
    end
end

-- Handle dialog popup button selection
local function HandleDialogPopupSelect()
    if not dialogPopupActive or #dialogPopupButtons == 0 then
        return
    end
    
    local buttonInfo = dialogPopupButtons[dialogPopupSelectedIndex]
    if buttonInfo and buttonInfo.button then
        -- Click the button
        local button = buttonInfo.button
        if button:IsEnabled() then
            -- Use StaticPopup_OnClick to properly handle the click
            if dialogPopupFrame and StaticPopup_OnClick then
                StaticPopup_OnClick(dialogPopupFrame, buttonInfo.index)
            else
                -- Fallback: directly click the button
                button:Click()
            end
        end
    end
end

-- Deactivate dialog popup cursor
local function DeactivateDialogPopup()
    dialogPopupActive = false
    dialogPopupFrame = nil
    dialogPopupButtons = {}
    if highlightFrame then
        highlightFrame:Hide()
    end
    -- Reactivate regular cursor if we had a tab active
    if currentTab then
        InterfaceCursor:Activate(currentTab.module)
    end
end

-- Initialize the module
function InterfaceCursor:Initialize()
    -- Create highlight frame
    highlightFrame = CreateHighlightFrame()
    
    -- Create input handler frame - attach to UIParent so it's always active
    cursorFrame = CreateFrame("Frame", "SteamDeckInterfaceCursorFrame", UIParent)
    
    -- Frame must be shown to receive gamepad events
    cursorFrame:Show()
    
    -- Set frame level high so it can receive input
    cursorFrame:SetFrameStrata("HIGH")
    cursorFrame:SetFrameLevel(1000)
    
    -- Enable gamepad button input
    cursorFrame:EnableGamePadButton(true)
    
    -- Also enable keyboard as fallback (for testing)
    cursorFrame:EnableKeyboard(false)  -- Don't block keyboard, just enable the frame
    
    -- Check for dialog popups periodically
    cursorFrame:SetScript("OnUpdate", function(self, elapsed)
        -- Check if a dialog popup is shown
        local dialog = GetShownDialog()
        if dialog and not dialogPopupActive then
            ActivateDialogPopup()
        elseif not dialog and dialogPopupActive then
            DeactivateDialogPopup()
        end
    end)
    
    -- Handle gamepad button down events
    cursorFrame:SetScript("OnGamePadButtonDown", function(self, button)
        -- Normalize button name (handle string comparisons)
        local buttonStr = tostring(button)
        
        -- Handle dialog popup navigation if popup is active (highest priority)
        if dialogPopupActive then
            -- Handle A to select button
            if buttonStr == BUTTON_A or buttonStr == "PAD1" then
                HandleDialogPopupSelect()
                return
            end
            
            -- Handle B to cancel/close (if second button exists, select it; otherwise just close)
            if buttonStr == BUTTON_B or buttonStr == "PAD2" then
                if #dialogPopupButtons >= 2 then
                    -- Select second button (usually Cancel)
                    dialogPopupSelectedIndex = 2
                    HandleDialogPopupSelect()
                else
                    -- Just close the dialog
                    if dialogPopupFrame then
                        dialogPopupFrame:Hide()
                    end
                end
                return
            end
            
            -- Handle D-pad left/right for navigation
            if buttonStr == DPAD_LEFT or buttonStr == "PADDLEFT" or
               buttonStr == DPAD_RIGHT or buttonStr == "PADDRIGHT" then
                HandleDialogPopupNavigation(buttonStr)
                return
            end
            
            -- Don't process other buttons when popup is active
            return
        end
        
        -- Handle context menu navigation if menu is active
        if contextMenuActive then
            -- Handle Y or B to close menu
            if buttonStr == BUTTON_Y or buttonStr == "PAD4" or
               buttonStr == BUTTON_B or buttonStr == "PAD2" then
                HideContextMenu()
                return
            end
            
            -- Handle A to select option
            if buttonStr == BUTTON_A or buttonStr == "PAD1" then
                HandleContextMenuSelect()
                return
            end
            
            -- Handle D-pad for menu navigation
            if buttonStr == DPAD_UP or buttonStr == "PADDUP" or
               buttonStr == DPAD_DOWN or buttonStr == "PADDDOWN" then
                HandleContextMenuNavigation(buttonStr)
                return
            end
            
            -- Don't process other buttons when menu is open
            return
        end
        
        -- Handle Y button to open context menu
        if (buttonStr == BUTTON_Y or buttonStr == "PAD4") and currentSelection then
            ShowContextMenu()
            return
        end
        
        -- Handle X button for item usage
        if (buttonStr == BUTTON_X or buttonStr == "PAD3") and currentSelection then
            HandleItemUse()
            return
        end
        
        -- Handle bumper buttons for tab navigation
        if (buttonStr == BUMPER_LEFT or buttonStr == "PADLSHOULDER" or
            buttonStr == BUMPER_RIGHT or buttonStr == "PADRSHOULDER") and
           currentTab then
            HandleTabNavigation(buttonStr)
            return
        end
        
        -- Handle D-pad buttons when a tab is active
        if (buttonStr == DPAD_UP or buttonStr == "PADDUP" or 
            buttonStr == DPAD_DOWN or buttonStr == "PADDDOWN" or
            buttonStr == DPAD_LEFT or buttonStr == "PADDLEFT" or
            buttonStr == DPAD_RIGHT or buttonStr == "PADDRIGHT") and
           currentTab then
            HandleDpadNavigation(buttonStr)
        end
    end)
end

return InterfaceCursor

