-- ==================================================
-- YOKUDO HUB | FEATURE | Manager Drone (v3 FINAL)
-- ✅ Portal ឃើញ = SPAWN → AutoEventNew.Enable()
-- ✅ Portal បាត់ = DONE → AutoEventNew.Disable() → AFK
-- ✅ AutoEventNew CallManagerDone() → Manager ចាប់យក
-- ✅ Full Reset ពេល User ដកធិក
-- ✅ Guard: FarmingManager ដំណើរការ → មិនហៅ AFK
-- ✅ Register ជាមួយ CharacterSystem
-- ==================================================

local Players = game:GetService("Players")
local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================
local PORTAL_CHECK_INTERVAL = 0.5
local SAFE_ZONE = Vector3.new(533, 70, -366)
local AFK_JUMP_WAIT = 0.5
local SAFE_ZONE_WAIT = 1

-- ==================================================
-- STATE
-- ==================================================
local ManagerEnabled = false
local ManagerThread = nil
local LastPortalState = false

-- ==================================================
-- CHECK FARMING MANAGER
-- ==================================================
local function IsFarmingManagerActive()
    if _G.YOKUDO_FarmingManager and _G.YOKUDO_FarmingManager.IsEnabled() then
        return true
    end
    return false
end

-- ==================================================
-- CHECK PORTAL
-- ==================================================
local function IsPortalSpawned()
    local Portal = workspace:FindFirstChild("ScrambleArenaPortal")
    return Portal ~= nil
end

-- ==================================================
-- CHECK AUTO EVENT NEW
-- ==================================================
local function IsAutoEventNewActive()
    if _G.YOKUDO_AutoEventNew and _G.YOKUDO_AutoEventNew.IsEnabled() then
        return true
    end
    return false
end

-- ==================================================
-- FORCE STOP ALL FEATURES
-- ==================================================
local function ForceStopAll()
    print("[ManagerDrone] Force Stop All Features")

    if _G.YOKUDO_AutoEventNew then
        pcall(function() _G.YOKUDO_AutoEventNew.Disable() end)
    end
    if _G.YOKUDO_AFKSystem then
        pcall(function() _G.YOKUDO_AFKSystem.Disable() end)
    end
end

-- ==================================================
-- ENABLE AFK SYSTEM
-- ==================================================
local function EnableAFKSystem()
    if IsFarmingManagerActive() then
        print("[ManagerDrone] Skip AFK (FarmingManager active)")
        return
    end

    if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
        _G.YOKUDO_AFKSystem.Enable()
        print("[ManagerDrone] ✅ AFK System Enabled")
    end
end

-- ==================================================
-- ✅ FULL RESET (ពេល User ដកធិក)
-- ==================================================
local function FullReset()
    print("[ManagerDrone] 🔄 Full Reset...")

    -- 1. Stop AutoEventNew
    if _G.YOKUDO_AutoEventNew then
        pcall(function() _G.YOKUDO_AutoEventNew.Disable() end)
    end

    -- 2. Stop AFKSystem
    if _G.YOKUDO_AFKSystem then
        pcall(function() _G.YOKUDO_AFKSystem.Disable() end)
    end

    -- 3. Stop AttackDrone (បើមាន)
    if _G.YOKUDO_AttackDrone then
        pcall(function() _G.YOKUDO_AttackDrone.Stop() end)
    end

    -- 4. Reset State
    LastPortalState = false

    print("[ManagerDrone] ✅ Full Reset Complete")
end

-- ==================================================
-- ✅ CALL MANAGER AFTER DONE
-- ==================================================
local function CallManagerAfterDone()
    print("[ManagerDrone] 🎉 Event Done → Call Manager → AFK")

    if _G.YOKUDO_AutoEventNew and _G.YOKUDO_AutoEventNew.IsEnabled() then
        _G.YOKUDO_AutoEventNew.Disable()
    end

    task.wait(0.5)

    if not IsFarmingManagerActive() then
        EnableAFKSystem()
    else
        print("[ManagerDrone] FarmingManager Active → Skip AFK")
    end
end

-- ==================================================
-- ✅ SWITCH FROM AFK TO AUTO EVENT
-- ==================================================
local function SwitchAFKToAttack()
    print("[ManagerDrone] 🚪 Portal Spawned → Switch AFK to AutoEventNew")

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
        print("[ManagerDrone] No Treadmill → Stop AFK → Call AutoEventNew")
        if _G.YOKUDO_AFKSystem then
            _G.YOKUDO_AFKSystem.Disable()
        end
        task.wait(0.5)
        if _G.YOKUDO_AutoEventNew then
            _G.YOKUDO_AutoEventNew.Enable()
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

        print("[ManagerDrone] Call AutoEventNew")
        if _G.YOKUDO_AutoEventNew then
            _G.YOKUDO_AutoEventNew.Enable()
        end
    end)
end

-- ==================================================
-- MAIN LOOP (Portal Signal)
-- ==================================================
local function MainLoop()
    print("[ManagerDrone] MainLoop Started (Portal Signal)")

    while ManagerEnabled do
        if IsFarmingManagerActive() then
            if _G.YOKUDO_AutoEventNew and _G.YOKUDO_AutoEventNew.IsEnabled() then
                print("[ManagerDrone] FarmingManager active → Stop AutoEventNew")
                _G.YOKUDO_AutoEventNew.Disable()
            end
            LastPortalState = false
            task.wait(PORTAL_CHECK_INTERVAL)
            continue
        end

        local CurrentPortalState = IsPortalSpawned()

        -- ✅ Portal ឃើញ (Spawn)
        if CurrentPortalState and not LastPortalState then
            print("[ManagerDrone] ================================")
            print("[ManagerDrone] 🚪 PORTAL SPAWNED → SPAWN SIGNAL")
            print("[ManagerDrone] ================================")

            if _G.YOKUDO_AFKSystem and _G.YOKUDO_AFKSystem.IsEnabled() then
                SwitchAFKToAttack()
            elseif _G.YOKUDO_AutoEventNew and not _G.YOKUDO_AutoEventNew.IsEnabled() then
                print("[ManagerDrone] Portal Spawned → Enable AutoEventNew")
                _G.YOKUDO_AutoEventNew.Enable()
            end

            LastPortalState = true
        end

        -- ✅ Portal បាត់ (Done)
        if not CurrentPortalState and LastPortalState then
            print("[ManagerDrone] ================================")
            print("[ManagerDrone] ✅ PORTAL GONE → DONE SIGNAL")
            print("[ManagerDrone] ================================")

            CallManagerAfterDone()

            LastPortalState = false
        end

        task.wait(PORTAL_CHECK_INTERVAL)
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
    LastPortalState = false

    if ManagerThread then
        pcall(function() task.cancel(ManagerThread) end)
        ManagerThread = nil
    end

    ManagerThread = task.spawn(function() MainLoop() end)

    print("[ManagerDrone] Manager Drone: ON")
end

local function DisableManager()
    if not ManagerEnabled then
        FullReset()
        return
    end
    ManagerEnabled = false

    if ManagerThread then
        pcall(function() task.cancel(ManagerThread) end)
        ManagerThread = nil
    end

    -- ✅ Full Reset
    FullReset()

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
    IsPortalSpawned = IsPortalSpawned,
    ForceStopAll = ForceStopAll,
    SwitchAFKToAttack = SwitchAFKToAttack,
    IsAutoEventNewActive = IsAutoEventNewActive,
    CallManagerAfterDone = CallManagerAfterDone,
    FullReset = FullReset,
}

print("✅ ManagerDrone Feature Loaded (v3 FINAL + Full Reset)")
