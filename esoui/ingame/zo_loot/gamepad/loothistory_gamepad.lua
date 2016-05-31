ZO_GAMEPAD_LOOT_HISTORY_ENTRY_SPACING_Y = -1
local GAMEPAD_LOOT_HISTORY_ENTRY_TEMPLATE = "ZO_LootHistory_GamepadEntry"

local ZO_LootHistory_Gamepad = ZO_LootHistory_Shared:Subclass()

function ZO_LootHistory_Gamepad:New(...)
    return ZO_LootHistory_Shared.New(self, ...)
end

function ZO_LootHistory_Gamepad:Initialize(control)
    ZO_LootHistory_Shared.Initialize(self, control)
end

function ZO_LootHistory_Gamepad:InitializeFragment()
    GAMEPAD_LOOT_HISTORY_FRAGMENT = ZO_HUDFadeSceneFragment:New(ZO_LootHistoryControl_Gamepad)
    GAMEPAD_LOOT_HISTORY_FRAGMENT:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_FRAGMENT_SHOWN then
            self:DisplayLootQueue()
        elseif newState == SCENE_FRAGMENT_HIDING then
            self:HideLootQueue()
        end
    end)

    SCENE_MANAGER:GetScene("lootGamepad"):AddFragment(GAMEPAD_LOOT_HISTORY_FRAGMENT)
end

function ZO_LootHistory_Gamepad:InitializeFadingControlBuffer(control)
    local HORIZ_OFFSET = 0
    local VERTICAL_OFFSET = -160
    local anchor = ZO_Anchor:New(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, HORIZ_OFFSET, VERTICAL_OFFSET)
    local MAX_ENTRIES = 5
    local CONTAINER_SHOW_TIME_MS = self:GetContainerShowTime()
    local PERSISTENT_CONTAINER_SHOW_TIME_MS = self:GetPersistentContainerShowTime()

    self.lootStreamPersistent = self:CreateFadingStationaryControlBuffer(control:GetNamedChild("PersistentContainer"), "ZO_LootHistory_FadeShared", "ZO_LootHistory_IconEntranceShared", "ZO_LootHistory_ContainerFadeShared", anchor, MAX_ENTRIES, PERSISTENT_CONTAINER_SHOW_TIME_MS, "GamepadPersistent")
    self.lootStream = self:CreateFadingStationaryControlBuffer(control:GetNamedChild("Container"), "ZO_LootHistory_FadeShared", "ZO_LootHistory_IconEntranceShared", "ZO_LootHistory_ContainerFadeShared", anchor, MAX_ENTRIES, CONTAINER_SHOW_TIME_MS, "Gamepad")

    self.lootStreamPersistent:SetAdditionalEntrySpacingY(ZO_GAMEPAD_LOOT_HISTORY_ENTRY_SPACING_Y)
    self.lootStream:SetAdditionalEntrySpacingY(ZO_GAMEPAD_LOOT_HISTORY_ENTRY_SPACING_Y)
end

function ZO_LootHistory_Gamepad:SetEntryTemplate()
    self.entryTemplate = GAMEPAD_LOOT_HISTORY_ENTRY_TEMPLATE
end

function ZO_LootHistory_Gamepad:CanShowItemsInHistory()
    local currentSceneName = SCENE_MANAGER:GetCurrentSceneName()
    return currentSceneName == "gamepadInteract" or currentSceneName == "gamepad_inventory_root" 
           or SCENE_MANAGER:IsSceneOnStack("gamepad_inventory_root")
end

function ZO_LootHistory_Gamepad:OnLootReceived(...)
    ZO_LootHistory_Shared.OnLootReceived(self, ...)
end

function ZO_LootHistory_Gamepad:OnGoldUpdate(...)
    ZO_LootHistory_Shared.OnGoldUpdate(self, ...)
end

function ZO_LootHistory_Gamepad:OnTelvarStoneUpdate(...)
    ZO_LootHistory_Shared.OnTelvarStoneUpdate(self, ...)
end

function ZO_LootHistory_Gamepad_OnInitialized(control)
    LOOT_HISTORY_GAMEPAD = ZO_LootHistory_Gamepad:New(control)
    SYSTEMS:RegisterGamepadObject(ZO_LOOT_HISTORY_NAME, LOOT_HISTORY_GAMEPAD)
end