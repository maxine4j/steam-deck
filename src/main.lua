-- SteamDeck AddOn
-- Main entry point

local SteamDeckAddon = {}

local PANEL_WIDTH = 600;

-- Initialize the addon
function SteamDeckAddon:OnInitialize()

    SteamDeckPanels:CreatePanel("Right", "right", PANEL_WIDTH, {
        SteamDeckBagsTab,
    })

    SteamDeckPanels:CreatePanel("Left", "left", PANEL_WIDTH, {
        SteamDeckEquipmentTab,
        SteamDeckReputationTab,
        -- SteamDeckCharacterCurrenciesTab,
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
