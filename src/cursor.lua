-- SteamDeck InterfaceCursor Module
-- Focused interface cursor for navigating our custom modules with controller D-pad

SteamDeckInterfaceCursorModule = {}
local InterfaceCursor = SteamDeckInterfaceCursorModule

-- State
local cursorFrame = nil
local currentTab = nil
local currentSelection = nil
local navigationGrid = nil
local slotToPositionMap = {}
local highlightFrame = nil

-- Configuration
local HIGHLIGHT_COLOR = {1, 1, 0, 1.0}  -- Bright yellow highlight, fully opaque
local HIGHLIGHT_THICKNESS = 4  -- Thicker border for better visibility

-- D-pad button constants (must match WoW's button names exactly)
local DPAD_UP = "PADDUP"
local DPAD_DOWN = "PADDDOWN"
local DPAD_LEFT = "PADDLEFT"
local DPAD_RIGHT = "PADDRIGHT"

-- Create the highlight frame that follows the selected slot
local function CreateHighlightFrame()
    local highlight = CreateFrame("Frame", "SteamDeckInterfaceCursorHighlight", UIParent)
    highlight:SetFrameStrata("TOOLTIP")
    highlight:SetFrameLevel(1000)
    highlight:EnableMouse(false)
    
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
    
    -- Position highlight to match slot
    highlightFrame:ClearAllPoints()
    highlightFrame:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, 0)
    highlightFrame:SetSize(slotWidth, slotHeight)
    
    -- Update border textures
    local r, g, b, a = HIGHLIGHT_COLOR[1], HIGHLIGHT_COLOR[2], HIGHLIGHT_COLOR[3], HIGHLIGHT_COLOR[4]
    
    -- Top border
    highlightFrame.top:ClearAllPoints()
    highlightFrame.top:SetSize(slotWidth, borderThickness)
    highlightFrame.top:SetPoint("TOPLEFT", highlightFrame, "TOPLEFT", 0, 0)
    highlightFrame.top:SetPoint("TOPRIGHT", highlightFrame, "TOPRIGHT", 0, 0)
    highlightFrame.top:SetColorTexture(r, g, b, a)
    highlightFrame.top:Show()
    
    -- Bottom border
    highlightFrame.bottom:ClearAllPoints()
    highlightFrame.bottom:SetSize(slotWidth, borderThickness)
    highlightFrame.bottom:SetPoint("BOTTOMLEFT", highlightFrame, "BOTTOMLEFT", 0, 0)
    highlightFrame.bottom:SetPoint("BOTTOMRIGHT", highlightFrame, "BOTTOMRIGHT", 0, 0)
    highlightFrame.bottom:SetColorTexture(r, g, b, a)
    highlightFrame.bottom:Show()
    
    -- Left border
    highlightFrame.left:ClearAllPoints()
    highlightFrame.left:SetSize(borderThickness, slotHeight)
    highlightFrame.left:SetPoint("TOPLEFT", highlightFrame, "TOPLEFT", 0, 0)
    highlightFrame.left:SetPoint("BOTTOMLEFT", highlightFrame, "BOTTOMLEFT", 0, 0)
    highlightFrame.left:SetColorTexture(r, g, b, a)
    highlightFrame.left:Show()
    
    -- Right border
    highlightFrame.right:ClearAllPoints()
    highlightFrame.right:SetSize(borderThickness, slotHeight)
    highlightFrame.right:SetPoint("TOPRIGHT", highlightFrame, "TOPRIGHT", 0, 0)
    highlightFrame.right:SetPoint("BOTTOMRIGHT", highlightFrame, "BOTTOMRIGHT", 0, 0)
    highlightFrame.right:SetColorTexture(r, g, b, a)
    highlightFrame.right:Show()
    
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
    elseif directionStr == DPAD_RIGHT or directionStr == "PADDRIGHT" then
        -- Look for nearest slot to the right in same row
        -- Find max column in this row
        local maxCol = 0
        if grid[newRow] then
            for col = 0, 8 do
                if grid[newRow][col] then
                    maxCol = col
                end
            end
        end
        for checkCol = newCol, maxCol do
            local checkSlot = GetSlotAtPosition(grid, newRow, checkCol)
            if checkSlot and checkSlot:IsShown() then
                return checkSlot
            end
        end
    end
    
    return nil
end

-- Set selection to a specific slot
local function SetSelection(slot)
    currentSelection = slot
    UpdateHighlight(slot)
    
    -- Hide tooltip for now (as requested)
    GameTooltip:Hide()
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
    
    -- Handle gamepad button down events
    cursorFrame:SetScript("OnGamePadButtonDown", function(self, button)
        -- Normalize button name (handle string comparisons)
        local buttonStr = tostring(button)
        
        -- Only handle D-pad buttons when a tab is active
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

