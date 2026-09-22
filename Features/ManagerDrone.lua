-- ==================================================
-- YOKUDO HUB | FEATURE | Manager Drone
-- គ្រប់គ្រង Event → ហៅ Attack ឬ AFK
-- ✅ ប្រើ ExperimentTimer.Value.Text
-- ✅ Stop ពេល Disable
-- ✅ Event Threshold = 4s
-- ==================================================

local Players = game:GetService("Players")

local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================
local EVENT_CHECK_INTERVAL = 1
local EVENT_SKIP_THRESHOLD = 4  -- ✅ ប្តូរពី 7 ទៅ 4

-- ==================================================
-- STATE
-- ==================================================
local ManagerEnabled = false
local LastEventSec = 0
local ManagerThread = nil

-- ==================================================
-- GET EVENT TIME (Seconds)
-- ✅ ប្រើ ExperimentTimer.Value.Text
-- ==================================================
local function GetEventSeconds()
    local Success, Value = pcall(function()
        return game:GetService("Players").LocalPlayer.PlayerGui
            .HUD.GameHUD.BottomRight.ExperimentTimer.Value.Text
    end)
    if not Success or not Value then
        return 0
    end

    local Text = tostring(Value)  -- "Event ends in 1m 26s"
    local M = tonumber(string.match(Text, "(%d+)m")) or 0
    local S = tonumber(string.match(Text, "(%d+)s")) or 0
    local TotalSec = M * 60 + S

    return TotalSec
end

-- ==================================================
-- FORCE STOP ALL FEATURES (✅ ថ្មី)
-- ==================================================
local function ForceStopAll()
    print("[ManagerDrone] Force Stop All Features")

    -- Stop Attack Drone
    if _G.YOKUDO_AttackDrone then
        pcall(function() _G.YOKUDO_AttackDrone.Stop() end)
    end

    -- Disable AFK System
    if _G.YOKUDO_AFKSystem then
        pcall(function() _G.YOKUDO_AFKSystem.Disable() end)
    end
end

-- ==================================================
-- MAIN LOOP
-- ==================================================
local function MainLoop()
    while ManagerEnabled do
        local EventSec = GetEventSeconds()

        -- ✅ Logic:
        -- EventSec = 0 → Event មិនទាន់ចេញ
        -- EventSec = 1-4 → Event ជិតចប់
        -- EventSec > 4 → Event កំពុងដំណើរការ

        local EventNotActive = EventSec <= 0
        local EventEndingSoon = EventSec > 0 and EventSec <= EVENT_SKIP_THRESHOLD
        local EventActive = EventSec > EVENT_SKIP_THRESHOLD

        print("[ManagerDrone] Event:", EventSec, "| NotActive:", EventNotActive, "| EndingSoon:", EventEndingSoon, "| Active:", EventActive)

        -- ==================================================
        -- Event មិនទាន់ចេញ (EventSec = 0) → AFK System
        -- ==================================================
        if EventNotActive then
            if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
                print("[ManagerDrone] Event Not Active → AFK System")
                _G.YOKUDO_AFKSystem.Enable()
            end
        -- ==================================================
        -- Event ជិតចប់ (1s <= EventSec <= 4s) → Stop Attack → AFK System
        -- ==================================================
        elseif EventEndingSoon then
            if _G.YOKUDO_AttackDrone and _G.YOKUDO_AttackDrone.IsEnabled() then
                print("[ManagerDrone] Event Ending Soon (<= 4s) → Stop Attack → AFK System")
                _G.YOKUDO_AttackDrone.Stop()
            end

            if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
                _G.YOKUDO_AFKSystem.Enable()
            end
        -- ==================================================
        -- Event កំពុងដំណើរការ (EventSec > 4s) → Attack Drone
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
        end

        LastEventSec = EventSec
        task.wait(EVENT_CHECK_INTERVAL)
    end

    -- ✅ ពេល Loop ចេញ → Stop Features ទាំងអស់
    ForceStopAll()

    print("[ManagerDrone] MainLoop Stopped")
end

-- ==================================================
-- ENABLE / DISABLE
-- ==================================================
local function EnableManager()
    if ManagerEnabled then return end
    ManagerEnabled = true

    -- Stop Thread ចាស់ (បើមាន)
    if ManagerThread then
        pcall(function() task.cancel(ManagerThread) end)
        ManagerThread = nil
    end

    ManagerThread = task.spawn(function() MainLoop() end)

    print("[ManagerDrone] Manager Drone: ON")
end

local function DisableManager()
    if not ManagerEnabled then return end
    ManagerEnabled = false

    -- Stop Thread
    if ManagerThread then
        pcall(function() task.cancel(ManagerThread) end)
        ManagerThread = nil
    end

    -- ✅ Force Stop Features ទាំងអស់
    ForceStopAll()

    print("[ManagerDrone] Manager Drone: OFF")
end

local function ToggleManager()
    if ManagerEnabled then
        DisableManager()
    else
        EnableManager()
    end
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_ManagerDrone = {
    Enable = EnableManager,
    Disable = DisableManager,
    Toggle = ToggleManager,
    IsEnabled = function() return ManagerEnabled end,
    GetEventSeconds = GetEventSeconds,
    ForceStopAll = ForceStopAll,
}

print("✅ ManagerDrone Feature Loaded (Stop at 4s + Force Stop)")
