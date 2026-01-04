-- SteamDeck AddOn
-- Main entry point

local SteamDeck = {}
SteamDeck.modules = {}

-- Initialize the addon
function SteamDeck:OnInitialize()
    print("SteamDeck addon loaded!")
    
    -- Initialize interface cursor first (other modules may depend on it)
    if SteamDeckInterfaceCursorModule then
        SteamDeck.modules.interfacecursor = SteamDeckInterfaceCursorModule
        SteamDeck.modules.interfacecursor:Initialize()
    end
    
    -- Initialize modules
    if SteamDeckBagsModule then
        SteamDeck.modules.bags = SteamDeckBagsModule
        SteamDeck.modules.bags:Initialize()
    end
    
    if SteamDeckCharacterModule then
        SteamDeck.modules.character = SteamDeckCharacterModule
        SteamDeck.modules.character:Initialize()
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

