-- ==================================================
-- YOKUDO HUB | FEATURE | Manager Drone (v7 FINAL)
-- ✅ គ្មាន Portal → AFKSystem.Enable() (Walk TP)
-- ✅ ឃើញ Portal → AFKSystem.Disable() → AutoEventNew.Enable()
-- ✅ Portal បាត់ → AutoEventNew.Disable() → Full Reset → AFKSystem.Enable()
-- ✅ Guard: FarmingManager ដំណើរការ → មិនហៅ AFK
-- ==================================================

local Players = game:GetService("Players")
local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================
local PORTAL_CHECK_INTERVAL = 0.5
local PORTAL_NAME = "ScrambleArenaPortal"

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
    local Portal = workspace:FindFirstChild(PORTAL_NAME)
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
-- FORCE STOP ALL
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
-- ✅ ENABLE AFK SYSTEM (Walk TP)
-- ==================================================
local function EnableAFKSystem()
    if IsFarmingManagerActive() then
        print("[ManagerDrone] Skip AFK (FarmingManager active)")
        return
    end

    if not _G.YOKUDO_AFKSystem then
        print("[ManagerDrone] ❌ AFKSystem not loaded!")
        return
    end

    -- ✅ Disable មុនបើ Enabled (Reset State)
    if _G.YOKUDO_AFKSystem.IsEnabled() then
        pcall(function() _G.YOKUDO_AFKSystem.Disable() end)
        task.wait(0.3)
    end

    -- ✅ Enable AFKSystem ជាប់
    local OK = pcall(function() _G.YOKUDO_AFKSystem.Enable() end)
    if OK then
        print("[ManagerDrone] ✅ AFKSystem Enabled (Walk TP)")
    else
        print("[ManagerDrone] ❌ AFKSystem Enable Failed")
    end
end

-- ==================================================
-- FULL RESET
-- ==================================================
local function FullReset()
    print("[ManagerDrone] 🔄 Full Reset...")

    if _G.YOKUDO_AutoEventNew then
        pcall(function() _G.YOKUDO_AutoEventNew.Disable() end)
    end
    if _G.YOKUDO_AFKSystem then
        pcall(function() _G.YOKUDO_AFKSystem.Disable() end)
    end

    LastPortalState = false

    print("[ManagerDrone] ✅ Full Reset Complete")
end

-- ==================================================
-- ✅ CALL MANAGER AFTER DONE (Portal បាត់)
-- ==================================================
local function CallManagerAfterDone()
    print("[ManagerDrone] ================================")
    print("[ManagerDrone] 🎉 Portal Gone → Stop + Reset → AFK")
    print("[ManagerDrone] ================================")

    -- ✅ 1. Stop AutoEventNew
    if _G.YOKUDO_AutoEventNew then
        pcall(function() _G.YOKUDO_AutoEventNew.Disable() end)
        print("[ManagerDrone] ✅ AutoEventNew Stopped")
    end

    task.wait(0.5)

    -- ✅ 2. Enable AFKSystem ជាប់
    if not IsFarmingManagerActive() then
        EnableAFKSystem()
    else
        print("[ManagerDrone] FarmingManager Active → Skip AFK")
    end

    LastPortalState = false
    print("[ManagerDrone] ✅ Call Manager Complete")
end

-- ==================================================
-- ✅ SWITCH FROM AFK TO AUTO EVENT (Portal ឃើញ)
-- ==================================================
local function SwitchAFKToAttack()
    print("[ManagerDrone] ================================")
    print("[ManagerDrone] 🚪 Portal Spawned → Switch to AutoEventNew")
    print("[ManagerDrone] ================================")

    if IsFarmingManagerActive() then
        print("[ManagerDrone] Skip Switch (FarmingManager active)")
        return
    end

    -- ✅ 1. Stop AFKSystem
    if _G.YOKUDO_AFKSystem and _G.YOKUDO_AFKSystem.IsEnabled() then
        pcall(function() _G.YOKUDO_AFKSystem.Disable() end)
        print("[ManagerDrone] ✅ AFKSystem Disabled")
    end

    task.wait(0.5)

    -- ✅ 2. Enable AutoEventNew
    if _G.YOKUDO_AutoEventNew then
        pcall(function() _G.YOKUDO_AutoEventNew.Enable() end)
        print("[ManagerDrone] ✅ AutoEventNew Enabled")
    end
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

            SwitchAFKToAttack()

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

    -- ✅ បើគ្មាន Portal ពេល Start → Enable AFK
    task.spawn(function()
        task.wait(0.5)
        if not IsPortalSpawned() then
            print("[ManagerDrone] No Portal → Enable AFK")
            EnableAFKSystem()
        end
    end)
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
    EnableAFKSystem = EnableAFKSystem,
    IsFarmingManagerActive = IsFarmingManagerActive,
}

print("✅ ManagerDrone Feature Loaded (v7 FINAL — Portal Gone → AFK)")
