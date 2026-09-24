-- ==================================================
-- YOKUDO HUB | FEATURE | Manager Drone
-- គ្រប់គ្រង Event → ហៅ Attack ឬ AFK
-- ✅ Event ចេញ → Stop AFK → Jump Out → Call Attack
-- ✅ Event Sec <= 10 → Stop Attack → Call AFK
-- ✅ Stop ពេល Disable
-- ✅ Guard: បើ FarmingManager ដំណើរការ → មិនហៅ AFKSystem
-- ✅ Register ជាមួយ CharacterSystem
-- ==================================================

local Players = game:GetService("Players")

local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================
local EVENT_CHECK_INTERVAL = 1
local EVENT_STOP_ATTACK_THRESHOLD = 10
local SAFE_WAIT_TIME = 1
local SAFE_ZONE = Vector3.new(533, 70, -366)
local AFK_JUMP_WAIT = 0.5

-- ==================================================
-- STATE
-- ==================================================
local ManagerEnabled = false
local LastEventSec = 0
local LastEventText = ""
local ManagerThread = nil

-- ==================================================
-- ✅ CHECK FARMING MANAGER
-- ==================================================
local function IsFarmingManagerActive()
    if _G.YOKUDO_FarmingManager and _G.YOKUDO_FarmingManager.IsEnabled() then
        return true
    end
    return false
end

-- ==================================================
-- GET EVENT INFO
-- ==================================================
local function GetEventInfo()
    local Success, Value = pcall(function()
        return game:GetService("Players").LocalPlayer.PlayerGui
            .HUD.GameHUD.BottomRight.ExperimentTimer.Value.Text
    end)
    if not Success or not Value then
        return 0, "", false
    end

    local Text = tostring(Value)

    local HasEventEnds = string.find(Text, "Event ends") ~= nil
    local IsEventActive = HasEventEnds

    local M = tonumber(string.match(Text, "(%d+)m")) or 0
    local S = tonumber(string.match(Text, "(%d+)s")) or 0
    local TotalSec = M * 60 + S

    return TotalSec, Text, IsEventActive
end

-- ==================================================
-- FORCE STOP ALL FEATURES
-- ==================================================
local function ForceStopAll()
    print("[ManagerDrone] Force Stop All Features")

    if _G.YOKUDO_AttackDrone then
        pcall(function() _G.YOKUDO_AttackDrone.Stop() end)
    end
    if _G.YOKUDO_AFKSystem then
        pcall(function() _G.YOKUDO_AFKSystem.Disable() end)
    end
end

-- ==================================================
-- ✅ ENABLE AFK SYSTEM (មាន Guard)
-- ==================================================
local function EnableAFKSystem()
    -- ✅ បើ FarmingManager ដំណើរការ → មិនហៅ AFKSystem
    if IsFarmingManagerActive() then
        print("[ManagerDrone] Skip AFK (FarmingManager active)")
        return
    end

    if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
        _G.YOKUDO_AFKSystem.Enable()
        print("[ManagerDrone] AFK System Enabled")
    end
end

-- ==================================================
-- SWITCH FROM AFK TO ATTACK
-- ==================================================
local function SwitchAFKToAttack()
    print("[ManagerDrone] Event Detected → Switch AFK to Attack")

    -- ✅ បើ FarmingManager ដំណើរការ → មិនធ្វើអ្វីទេ
    if IsFarmingManagerActive() then
        print("[ManagerDrone] Skip Switch (FarmingManager active)")
        return
    end

    local TreadmillPos = nil
    if _G.YOKUDO_AFKSystem then
        TreadmillPos = _G.YOKUDO_AFKSystem.GetMyTreadmillPos()
    end

    if not TreadmillPos and _G.YOKUDO_AFKSystem then
        local _, Treadmill = _G.YOKUDO_AFKSystem.FindMyPlotAndTreadmill()
        if Treadmill then
            TreadmillPos = Treadmill.Position
        end
    end

    if not TreadmillPos then
        print("[ManagerDrone] No Treadmill → Stop AFK → Call Attack")
        if _G.YOKUDO_AFKSystem then
            _G.YOKUDO_AFKSystem.Disable()
        end
        task.wait(0.5)
        if _G.YOKUDO_AttackDrone then
            _G.YOKUDO_AttackDrone.Start()
        end
        return
    end

    print("[ManagerDrone] Jumping out of Treadmill...")
    _G.YOKUDO_AFKSystem.JumpOutTreadmill(TreadmillPos, function()
        print("[ManagerDrone] ✅ Jumped out!")

        if _G.YOKUDO_AFKSystem then
            _G.YOKUDO_AFKSystem.Disable()
        end

        task.wait(AFK_JUMP_WAIT)

        print("[ManagerDrone] Call Attack Drone → Fly TP to Safe Zone → Spawn Loop")
        if _G.YOKUDO_AttackDrone then
            _G.YOKUDO_AttackDrone.Start()
        end
    end)
end

-- ==================================================
-- MAIN LOOP
-- ==================================================
local function MainLoop()
    while ManagerEnabled do
        -- ✅ បើ FarmingManager ដំណើរការ → Stop AttackDrone
        if IsFarmingManagerActive() then
            if _G.YOKUDO_AttackDrone and _G.YOKUDO_AttackDrone.IsEnabled() then
                print("[ManagerDrone] FarmingManager active → Stop AttackDrone")
                _G.YOKUDO_AttackDrone.Stop()
            end

            -- ✅ មិនហៅ AFKSystem (ទុកឲ្យ FarmingManager គ្រប់គ្រង)
            LastEventSec = 0
            LastEventText = ""
            task.wait(EVENT_CHECK_INTERVAL)
            continue
        end

        local EventSec, EventText, IsEventActive = GetEventInfo()

        local EventNotActive = not IsEventActive
        local EventStopAttack = IsEventActive and EventSec > 0 and EventSec <= EVENT_STOP_ATTACK_THRESHOLD
        local EventActive = IsEventActive and EventSec > EVENT_STOP_ATTACK_THRESHOLD

        print("[ManagerDrone] Text:", EventText, "| Sec:", EventSec, "| IsActive:", IsEventActive, "| NotActive:", EventNotActive, "| StopAttack:", EventStopAttack, "| Active:", EventActive)

        if EventNotActive then
            if _G.YOKUDO_AttackDrone and _G.YOKUDO_AttackDrone.IsEnabled() then
                print("[ManagerDrone] Event Not Active → Stop Attack")
                _G.YOKUDO_AttackDrone.Stop()
            end

            -- ✅ ប្រើ Function ថ្មី EnableAFKSystem() ដែលមាន Guard
            EnableAFKSystem()
        elseif EventStopAttack then
            if _G.YOKUDO_AttackDrone and _G.YOKUDO_AttackDrone.IsEnabled() then
                print("[ManagerDrone] Event <= 10s → Stop Attack → AFK System")
                _G.YOKUDO_AttackDrone.Stop()
            end

            -- ✅ ប្រើ Function ថ្មី EnableAFKSystem() ដែលមាន Guard
            EnableAFKSystem()
        elseif EventActive then
            if _G.YOKUDO_AFKSystem and _G.YOKUDO_AFKSystem.IsEnabled() then
                print("[ManagerDrone] Event Active → Switch AFK to Attack")
                SwitchAFKToAttack()
            elseif _G.YOKUDO_AttackDrone and not _G.YOKUDO_AttackDrone.IsEnabled() then
                print("[ManagerDrone] Event Active → Attack Drone")
                _G.YOKUDO_AttackDrone.Start()
            end
        end

        LastEventSec = EventSec
        LastEventText = EventText
        task.wait(EVENT_CHECK_INTERVAL)
    end

    ForceStopAll()
    print("[ManagerDrone] MainLoop Stopped")
end

-- ==================================================
-- ENABLE / DISABLE
-- ==================================================
local function EnableManager()
    if ManagerEnabled then return end
    ManagerEnabled = true

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

    if ManagerThread then
        pcall(function() task.cancel(ManagerThread) end)
        ManagerThread = nil
    end

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
    GetEventInfo = GetEventInfo,
    ForceStopAll = ForceStopAll,
    SwitchAFKToAttack = SwitchAFKToAttack,
}


print("✅ ManagerDrone Feature Loaded (Switch AFK to Attack + Guard + Register)")
