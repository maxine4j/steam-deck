-- SteamDeck AddOn
-- Main entry point

local SteamDeck = {}
SteamDeck.modules = {}

-- Initialize the addon
function SteamDeck:OnInitialize()
    print("SteamDeck addon loaded!")
    
    -- Initialize modules
    if SteamDeckBagsModule then
        SteamDeck.modules.bags = SteamDeckBagsModule
        SteamDeck.modules.bags:Initialize()
    end
end

-- Register events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "SteamDeck" then
        SteamDeck:OnInitialize()
    end
end)

