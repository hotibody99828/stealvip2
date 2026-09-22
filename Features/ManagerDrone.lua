-- ==================================================
-- YOKUDO HUB | FEATURE | Manager Drone
-- គ្រប់គ្រង Event → ហៅ Attack ឬ AFK
-- ==================================================

local Players = game:GetService("Players")

local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================
local EVENT_CHECK_INTERVAL = 1
local EVENT_SKIP_THRESHOLD = 7

-- ==================================================
-- STATE
-- ==================================================
local ManagerEnabled = false
local LastEventSec = 0

-- ==================================================
-- GET EVENT TIME
-- ==================================================
local function GetEventSeconds()
    local Success, Value = pcall(function()
        -- ✅ ប្រើ .Text (មិនមែន .Value)
        return Player.PlayerGui.HUD.GameHUD.BottomRight.ExperimentTimer.Text
    end)
    if not Success or not Value then return 0 end

    local Text = tostring(Value)  -- "Event ends in 1m 26s"
    local M = tonumber(string.match(Text, "(%d+)m")) or 0
    local S = tonumber(string.match(Text, "(%d+)s")) or 0
    return M * 60 + S
end

-- ==================================================
-- MAIN LOOP
-- ==================================================
local function MainLoop()
    while ManagerEnabled do
        local EventSec = GetEventSeconds()
        local EventActive = EventSec > 0
        local EventEndingSoon = EventActive and EventSec <= EVENT_SKIP_THRESHOLD

        print("[ManagerDrone] Event:", EventSec, "| Active:", EventActive, "| EndingSoon:", EventEndingSoon)

        -- ==================================================
        -- Event ជិតចប់ (<= 7s) → Stop Attack → ហៅ AFK System
        -- ==================================================
        if EventEndingSoon then
            if _G.YOKUDO_AttackDrone and _G.YOKUDO_AttackDrone.IsEnabled() then
                print("[ManagerDrone] Event Ending Soon → Stop Attack → AFK System")
                _G.YOKUDO_AttackDrone.Stop()
            end

            if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
                _G.YOKUDO_AFKSystem.Enable()
            end
        -- ==================================================
        -- Event ចេញ (ថ្មី) → Stop AFK → ហៅ Attack
        -- ==================================================
        elseif EventActive then
            if _G.YOKUDO_AFKSystem and _G.YOKUDO_AFKSystem.IsEnabled() then
                print("[ManagerDrone] Event Active → Stop AFK → Attack Drone")

                local TreadmillPos = _G.YOKUDO_AFKSystem.GetMyTreadmillPos()
                _G.YOKUDO_AFKSystem.JumpOutTreadmill(TreadmillPos, function()
                    _G.YOKUDO_AFKSystem.Disable()
                    if _G.YOKUDO_AttackDrone then
                        _G.YOKUDO_AttackDrone.Start()
                    end
                end)
            elseif _G.YOKUDO_AttackDrone and not _G.YOKUDO_AttackDrone.IsEnabled() then
                print("[ManagerDrone] Event Active → Attack Drone")
                _G.YOKUDO_AttackDrone.Start()
            end
        -- ==================================================
        -- Event មិនទាន់ចេញ (Event = 0) → AFK Treadmill
        -- ==================================================
        else
            if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
                print("[ManagerDrone] Event Not Active → AFK System")
                _G.YOKUDO_AFKSystem.Enable()
            end
        end

        LastEventSec = EventSec
        task.wait(EVENT_CHECK_INTERVAL)
    end
end

-- ==================================================
-- ENABLE / DISABLE
-- ==================================================
local function EnableManager()
    if ManagerEnabled then return end
    ManagerEnabled = true
    task.spawn(function() MainLoop() end)
    print("[ManagerDrone] Manager Drone: ON")
end

local function DisableManager()
    if not ManagerEnabled then return end
    ManagerEnabled = false
    print("[ManagerDrone] Manager Drone: OFF")
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_ManagerDrone = {
    Enable = EnableManager,
    Disable = DisableManager,
    Toggle = function()
        if ManagerEnabled then DisableManager() else EnableManager() end
    end,
    IsEnabled = function() return ManagerEnabled end,
    GetEventSeconds = GetEventSeconds,
}

print("✅ ManagerDrone Feature Loaded")
