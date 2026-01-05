-- SteamDeck AddOn
-- Main entry point

local SteamDeckAddon = {}

local PANEL_WIDTH = 600;

-- Initialize the addon
function SteamDeckAddon:OnInitialize()
    -- Initialize the interface cursor module
    if SteamDeckInterfaceCursorModule then
        SteamDeckInterfaceCursorModule:Initialize()
    end

    -- Store panels globally for cursor access
    SteamDeckPanels.leftPanel = SteamDeckPanels:CreatePanel("Left", "left", PANEL_WIDTH, {
        SteamDeckEquipmentTab,
        SteamDeckReputationTab,
        SteamDeckCurrenciesTab,
    })

    SteamDeckPanels.rightPanel = SteamDeckPanels:CreatePanel("Right", "right", PANEL_WIDTH, {
        SteamDeckBagsTab,
    })
end

-- Register events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "SteamDeck" then
        SteamDeckAddon:OnInitialize()
    end
end)
