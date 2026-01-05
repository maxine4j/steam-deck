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

-- Auto-scroll to keep selection visible in scrollable areas
local function AutoScrollToSelection(slot)
    if not slot or not currentTab then
        return
    end
    
    -- Check if this tab has a scroll frame (reputation/currencies tabs)
    local scrollFrame = currentTab.rightScrollFrame
    if not scrollFrame then
        return
    end
    
    -- Only auto-scroll for right pane entries (col 1)
    local pos = slotToPositionMap[slot]
    if not pos or pos.col ~= 1 then
        return
    end
    
    -- Get scroll frame dimensions and scroll state
    local scrollHeight = scrollFrame:GetHeight()
    local scrollRange = scrollFrame:GetVerticalScrollRange()
    local currentScroll = scrollFrame:GetVerticalScroll()
    
    -- If there's no scroll range, nothing to scroll
    if scrollRange <= 0 then
        return
    end
    
    -- Get the scroll child frame
    local scrollChild = scrollFrame:GetScrollChild()
    if not scrollChild then
        return
    end
    
    -- Get slot position relative to scroll child (slots are children of scrollChild)
    local slotPoint, slotRelativeTo, slotRelativePoint, slotX, slotY = slot:GetPoint(1)
    if not slotRelativeTo or slotRelativeTo ~= scrollChild then
        return
    end
    
    -- slotY is negative (top to bottom), so we need to convert it
    -- The slot's top edge is at -slotY from the top of scrollChild
    local slotTopFromChild = -slotY
    local slotBottomFromChild = slotTopFromChild + slot:GetHeight()
    
    -- Calculate visible area in scroll child coordinates
    -- currentScroll is how far we've scrolled down (positive = scrolled down)
    local visibleTop = currentScroll
    local visibleBottom = currentScroll + scrollHeight
    
    -- Define scroll threshold (percentage of visible height from edges)
    local scrollThreshold = 0.25  -- 25% from top/bottom
    local thresholdPixels = scrollHeight * scrollThreshold
    
    -- Check if we need to scroll down (slot is near bottom of visible area)
    local distanceFromVisibleBottom = visibleBottom - slotBottomFromChild
    if distanceFromVisibleBottom < thresholdPixels and currentScroll < scrollRange then
        -- Scroll down to bring more content into view
        local scrollAmount = thresholdPixels - distanceFromVisibleBottom + 50  -- Extra 50px for smooth scrolling
        local newScroll = math.min(scrollRange, currentScroll + scrollAmount)
        scrollFrame:SetVerticalScroll(newScroll)
        return
    end
    
    -- Check if we need to scroll up (slot is near top of visible area)
    local distanceFromVisibleTop = slotTopFromChild - visibleTop
    if distanceFromVisibleTop < thresholdPixels and currentScroll > 0 then
        -- Scroll up to bring more content into view
        local scrollAmount = thresholdPixels - distanceFromVisibleTop + 50  -- Extra 50px for smooth scrolling
        local newScroll = math.max(0, currentScroll - scrollAmount)
        scrollFrame:SetVerticalScroll(newScroll)
        return
    end
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
    
    -- Auto-scroll if needed (for reputation/currencies tabs)
    AutoScrollToSelection(slot)
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

-- Forward declaration for ShowContextMenu (defined later)
local ShowContextMenu

-- Handle item usage/interaction
local function HandleItemUse()
    if not currentSelection then
        return
    end
    
    -- Check if it's a reputation entry - show context menu
    -- Check for factionID and factionIndex properties (non-header entries)
    if currentSelection.factionID and currentSelection.factionIndex then
        -- Make sure it's not a header
        local factionData = C_Reputation.GetFactionDataByIndex(currentSelection.factionIndex)
        if factionData and not factionData.isHeader then
            ShowContextMenu()
            return
        end
    end
    
    -- Also check if it's a reputation entry by checking if it has factionData
    if currentSelection.factionData and currentSelection.factionData.factionID then
        -- Make sure it's not a header
        if not currentSelection.factionData.isHeader then
            ShowContextMenu()
            return
        end
    end
    
    -- Check if it's a button (non-item frame) - click it
    if currentSelection:IsObjectType("Button") then
        local onClickHandler = currentSelection:GetScript("OnClick")
        if onClickHandler then
            -- Call the button's OnClick handler
            onClickHandler(currentSelection, "LeftButton")
            -- Refresh navigation grid after clicking (content may have changed)
            -- Use a small delay to ensure UI updates have completed
            C_Timer.After(0.05, function()
                if currentTab then
                    InterfaceCursor:RefreshGrid()
                end
            end)
            return
        else
            -- Fallback: use Click method if available
            if currentSelection.Click then
                currentSelection:Click("LeftButton")
                -- Refresh navigation grid after clicking (content may have changed)
                C_Timer.After(0.05, function()
                    if currentTab then
                        InterfaceCursor:RefreshGrid()
                    end
                end)
                return
            end
        end
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
    
    -- Reset selection if current selection is not in the new grid or not visible
    if currentSelection then
        local pos = slotToPositionMap[currentSelection]
        if not pos or not currentSelection:IsShown() then
            currentSelection = nil
        end
    end
    
    -- Show highlight if we have a valid selection
    if currentSelection and currentSelection:IsShown() then
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
        -- Store the current position before refreshing
        local savedRow = nil
        local savedCol = nil
        if currentSelection then
            local pos = slotToPositionMap[currentSelection]
            if pos then
                savedRow = pos.row
                savedCol = pos.col
            end
        end
        
        -- Refresh the grid
        navigationGrid, slotToPositionMap = currentTab:GetNavGrid()
        
        -- Try to restore selection at the same position
        if savedRow ~= nil and savedCol ~= nil and navigationGrid then
            local slotAtPosition = GetSlotAtPosition(navigationGrid, savedRow, savedCol)
            if slotAtPosition and slotAtPosition:IsShown() then
                -- Found a slot at the same position, select it
                SetSelection(slotAtPosition)
                return
            end
        end
        
        -- Validate current selection (fallback if position restore failed)
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
    
    -- Content area (where tabs place their content frame)
    local contentArea = CreateFrame("Frame", nil, menu)
    contentArea:SetPoint("TOP", menu, "TOP", 0, -20)
    contentArea:SetPoint("BOTTOM", menu, "BOTTOM", 220, 0)  -- Leave room for options at bottom
    contentArea:SetPoint("LEFT", menu, "LEFT", 10, 0)
    contentArea:SetPoint("RIGHT", menu, "RIGHT", -10, 0)
    menu.contentArea = contentArea
    
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
    
    -- Unequip option (for equipped items in equipment slots)
    if itemInfo.isEquipment and itemInfo.slotID and itemInfo.itemLink then
        -- Check if there's actually an item equipped in this slot
        local equippedItemLink = GetInventoryItemLink("player", itemInfo.slotID)
        if equippedItemLink then
            table.insert(options, {
                text = "Unequip",
                action = function()
                    -- Check if item is locked (can't unequip during combat for some slots)
                    if IsInventoryItemLocked(itemInfo.slotID) then
                        return
                    end
                    
                    -- Pick up the item from the equipment slot
                    PickupInventoryItem(itemInfo.slotID)
                    
                    -- Try to put it in the backpack first
                    if CursorHasItem() then
                        if PutItemInBackpack() then
                            return
                        end
                        
                        -- If backpack is full, try other bags (bags 1-5, inventory IDs 31-35)
                        -- CONTAINER_BAG_OFFSET = 30, so bag 1 = 31, bag 2 = 32, etc.
                        for bag = 1, 5 do
                            if PutItemInBag(30 + bag) then
                                return
                            end
                        end
                        
                        -- If all bags are full, clear cursor (item stays equipped)
                        if CursorHasItem() then
                            ClearCursor()
                        end
                    end
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
    
    -- Try to get context menu data from the current tab first (new abstraction)
    local menuData = nil
    if currentTab and currentTab.GetContextMenuForSelection then
        menuData = currentTab:GetContextMenuForSelection(currentSelection)
    end
    
    if menuData then
        -- Hide/clear any previous content
        if contextMenuFrame.currentContent then
            contextMenuFrame.currentContent:Hide()
            contextMenuFrame.currentContent:SetParent(nil)
        end
        
        -- Set content frame from tab
        if menuData.content then
            menuData.content:SetParent(contextMenuFrame.contentArea)
            menuData.content:ClearAllPoints()
            menuData.content:SetPoint("TOPLEFT", contextMenuFrame.contentArea, "TOPLEFT", 0, 0)
            menuData.content:SetPoint("TOPRIGHT", contextMenuFrame.contentArea, "TOPRIGHT", 0, 0)
            -- Don't anchor bottom - let it grow naturally so we can measure it
            menuData.content:Show()
            contextMenuFrame.currentContent = menuData.content
        end
        
        -- Use options from tab
        contextMenuOptions = menuData.options or {}
        
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
                button:SetSize(320, buttonHeight)
                button:SetPoint("BOTTOM", contextMenuFrame.optionsList, "BOTTOM", 0, startY + (i - 1) * (buttonHeight + spacing))
                
                local bg = button:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints(button)
                bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
                button.bg = bg
                
                local highlight = button:CreateTexture(nil, "OVERLAY")
                highlight:SetAllPoints(button)
                highlight:SetColorTexture(1, 1, 0, 0.3)
                highlight:Hide()
                button.highlight = highlight
                
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
        
        -- Calculate and set menu height with dynamic sizing
        if contextMenuFrame.currentContent then
            -- First, calculate options list height
            local optionsListHeight = #contextMenuOptions * 35
            local menuPadding = 60  -- Top and bottom padding
            
            -- Calculate available screen height
            local screenHeight = GetScreenHeight()
            local maxMenuHeight = screenHeight - 40  -- Leave some margin from screen edges
            local maxContentHeight = maxMenuHeight - optionsListHeight - menuPadding
            
            -- Measure actual content height by finding the bounds of all visible elements
            local function MeasureContentHeight(frame)
                local topY = 0
                local bottomY = math.huge
                local hasBounds = false
                
                -- Helper to check a region's bounds
                local function CheckRegionBounds(region, parentFrame)
                    if not region:IsShown() then
                        return
                    end
                    
                    if region:IsObjectType("FontString") then
                        -- For FontStrings, use GetStringHeight which accounts for wrapping
                        local point, relativeTo, relativePoint, x, y = region:GetPoint()
                        if y then
                            local height = region:GetStringHeight() or region:GetHeight() or 0
                            if height > 0 then
                                topY = math.max(topY, y)
                                bottomY = math.min(bottomY, y - height)
                                hasBounds = true
                            end
                        end
                    else
                        -- For other regions, use GetHeight
                        local point, relativeTo, relativePoint, x, y = region:GetPoint()
                        if y then
                            local height = region:GetHeight() or 0
                            if height > 0 then
                                topY = math.max(topY, y)
                                bottomY = math.min(bottomY, y - height)
                                hasBounds = true
                            end
                        end
                    end
                end
                
                -- Check all regions
                local regions = {frame:GetRegions()}
                for _, region in ipairs(regions) do
                    CheckRegionBounds(region, frame)
                end
                
                -- Recursively check children
                local function CheckChildBounds(child, parentFrame)
                    if not child:IsShown() then
                        return
                    end
                    
                    local point, relativeTo, relativePoint, x, y = child:GetPoint()
                    if y then
                        local height = child:GetHeight() or 0
                        if height > 0 then
                            topY = math.max(topY, y)
                            bottomY = math.min(bottomY, y - height)
                            hasBounds = true
                        end
                    end
                    
                    -- Check child's regions
                    local childRegions = {child:GetRegions()}
                    for _, region in ipairs(childRegions) do
                        CheckRegionBounds(region, child)
                    end
                    
                    -- Recursively check grandchildren
                    local grandchildren = {child:GetChildren()}
                    for _, grandchild in ipairs(grandchildren) do
                        CheckChildBounds(grandchild, child)
                    end
                end
                
                local children = {frame:GetChildren()}
                for _, child in ipairs(children) do
                    CheckChildBounds(child, frame)
                end
                
                if hasBounds and topY ~= 0 and bottomY ~= math.huge then
                    return math.max(0, topY - bottomY)
                end
                
                -- Fallback to GetHeight
                return frame:GetHeight() or 0
            end
            
            local contentHeight = MeasureContentHeight(contextMenuFrame.currentContent)
            
            -- If content is too tall, try to expand menu first
            if contentHeight > maxContentHeight then
                -- Try expanding menu up to screen height
                local expandedMenuHeight = contentHeight + optionsListHeight + menuPadding
                if expandedMenuHeight <= maxMenuHeight then
                    -- Menu can fit with expansion
                    contextMenuFrame:SetHeight(expandedMenuHeight)
                else
                    -- Still too tall, need to shrink font size
                    -- Calculate scale factor
                    local scaleFactor = maxContentHeight / contentHeight
                    -- Ensure minimum readable font size (at least 0.5x of original)
                    scaleFactor = math.max(scaleFactor, 0.5)
                    
                    -- Recursively shrink all FontStrings in the content frame
                    local function ShrinkFontStrings(frame, scale)
                        -- Check all regions (including FontStrings)
                        local regions = {frame:GetRegions()}
                        for _, region in ipairs(regions) do
                            if region:IsObjectType("FontString") then
                                local font, fontSize, flags = region:GetFont()
                                if font and fontSize then
                                    region:SetFont(font, fontSize * scale, flags)
                                end
                            end
                        end
                        
                        -- Recursively check children
                        local children = {frame:GetChildren()}
                        for _, child in ipairs(children) do
                            ShrinkFontStrings(child, scale)
                        end
                    end
                    
                    ShrinkFontStrings(contextMenuFrame.currentContent, scaleFactor)
                    
                    -- Re-measure content height after font shrinking
                    contentHeight = MeasureContentHeight(contextMenuFrame.currentContent)
                    local finalMenuHeight = contentHeight + optionsListHeight + menuPadding
                    contextMenuFrame:SetHeight(math.max(finalMenuHeight, 500))
                end
            else
                -- Content fits, use calculated height
                local menuHeight = contentHeight + optionsListHeight + menuPadding
                menuHeight = math.max(menuHeight, 500)
                contextMenuFrame:SetHeight(menuHeight)
            end
            
            -- Update contentArea bottom anchor to prevent overlap with buttons
            -- This must happen AFTER setting menu height
            contextMenuFrame.contentArea:ClearAllPoints()
            contextMenuFrame.contentArea:SetPoint("TOP", contextMenuFrame, "TOP", 0, -20)
            contextMenuFrame.contentArea:SetPoint("BOTTOM", contextMenuFrame.optionsList, "TOP", 0, 0)
            contextMenuFrame.contentArea:SetPoint("LEFT", contextMenuFrame, "LEFT", 10, 0)
            contextMenuFrame.contentArea:SetPoint("RIGHT", contextMenuFrame, "RIGHT", -10, 0)
            
            -- Re-measure content height after contentArea is updated
            local maxContentFrameHeight = contextMenuFrame.contentArea:GetHeight()
            -- Add a buffer (20 pixels) to prevent cutting off the last line
            -- This accounts for spacing, padding, and measurement inaccuracies
            local bufferHeight = 20
            local maxContentFrameHeightWithBuffer = maxContentFrameHeight + bufferHeight
            local actualContentHeight = MeasureContentHeight(contextMenuFrame.currentContent)
            
            -- If content still overflows, apply additional font shrinking
            if actualContentHeight > maxContentFrameHeightWithBuffer then
                local additionalScaleFactor = maxContentFrameHeightWithBuffer / actualContentHeight
                additionalScaleFactor = math.max(additionalScaleFactor, 0.5)
                
                -- Shrink fonts further if needed
                if additionalScaleFactor < 1.0 then
                    local function ShrinkFontStrings(frame, scale)
                        local regions = {frame:GetRegions()}
                        for _, region in ipairs(regions) do
                            if region:IsObjectType("FontString") then
                                local font, fontSize, flags = region:GetFont()
                                if font and fontSize then
                                    region:SetFont(font, fontSize * scale, flags)
                                end
                            end
                        end
                        local children = {frame:GetChildren()}
                        for _, child in ipairs(children) do
                            ShrinkFontStrings(child, scale)
                        end
                    end
                    ShrinkFontStrings(contextMenuFrame.currentContent, additionalScaleFactor)
                    
                    -- Re-measure after additional shrinking
                    actualContentHeight = MeasureContentHeight(contextMenuFrame.currentContent)
                end
                
                -- Set explicit height to constrain (use buffer height to prevent cutoff)
                -- Only clip if content is significantly larger than available space
                if actualContentHeight > maxContentFrameHeightWithBuffer then
                    contextMenuFrame.currentContent:SetHeight(maxContentFrameHeightWithBuffer)
                    contextMenuFrame.currentContent:SetClipsChildren(true)
                else
                    -- Content fits with buffer, allow natural height
                    contextMenuFrame.currentContent:SetClipsChildren(false)
                end
            else
                -- Content fits within buffer, allow natural height
                contextMenuFrame.currentContent:SetClipsChildren(false)
            end
        else
            -- No content, use default height
            local optionsListHeight = #contextMenuOptions * 35
            local menuPadding = 60
            contextMenuFrame:SetHeight(optionsListHeight + menuPadding + 200)  -- Default content area height
        end
        
        return
    end
    
    -- No context menu data available - hide menu
    contextMenuFrame:Hide()
    contextMenuActive = false
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

-- Show context menu (implementation)
ShowContextMenu = function()
    if not currentSelection then
        return
    end
    
    if not contextMenuFrame then
        contextMenuFrame = CreateContextMenu()
    end
    
    -- Update the menu content
    UpdateContextMenu()
    
    -- Only show if we have options or content to display
    if contextMenuOptions and #contextMenuOptions > 0 then
        contextMenuFrame:Show()
        contextMenuActive = true
    elseif currentSelection.factionID or currentSelection.factionData then
        -- Even if no options, show menu if it's a reputation entry (might have description)
        contextMenuFrame:Show()
        contextMenuActive = true
    end
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
        
        -- Handle B button to close panels (only if no context menu or dialog popup is active)
        if (buttonStr == BUTTON_B or buttonStr == "PAD2") and not contextMenuActive and not dialogPopupActive then
            -- Close the currently focused panel first
            if currentPanel then
                if currentPanel:IsPanelOpen() then
                    currentPanel:ClosePanel()
                    return
                end
            end
            
            -- Fallback: close any open panel if cursor isn't focused on one
            if SteamDeckPanels.leftPanel and SteamDeckPanels.leftPanel:IsPanelOpen() then
                SteamDeckPanels.leftPanel:ClosePanel()
                return
            end
            if SteamDeckPanels.rightPanel and SteamDeckPanels.rightPanel:IsPanelOpen() then
                SteamDeckPanels.rightPanel:ClosePanel()
                return
            end
        end
        
        -- Handle Y button to open context menu
        if (buttonStr == BUTTON_Y or buttonStr == "PAD4") and currentSelection then
            ShowContextMenu()
            return
        end
        
        -- Handle A button for item usage and button clicks
        if (buttonStr == BUTTON_A or buttonStr == "PAD1") and currentSelection then
            HandleItemUse()
            return
        end
        
        -- Handle X button for item usage (legacy, keeping for backwards compatibility)
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

