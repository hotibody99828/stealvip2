-- ==================================================
-- YOKUDO HUB | FEATURE | Manager Drone (v10 DEBUG)
-- ✅ Debug Print ច្បាស់ — ដើម្បីមើលបញ្ហា AFK
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================
local PORTAL_CHECK_INTERVAL = 0.5
local PORTAL_NAME = "ScrambleArenaPortal"
local SAFE_ZONE = Vector3.new(533, 70, -366)
local SAFE_ZONE_WAIT = 3
local FLY_SPEED = 500
local ARRIVE_DISTANCE = 5
local FLY_TIMEOUT = 15

-- ==================================================
-- STATE
-- ==================================================
local ManagerEnabled = false
local ManagerThread = nil
local LastPortalState = false
local FlyConnection = nil
local BodyVelocity = nil
local BodyGyro = nil

-- ==================================================
-- DEBUG
-- ==================================================
local function DebugPrint(...)
    print("[ManagerDrone-DEBUG]", ...)
end

-- ==================================================
-- CHECK FARMING MANAGER
-- ==================================================
local function IsFarmingManagerActive()
    if _G.YOKUDO_FarmingManager and _G.YOKUDO_FarmingManager.IsEnabled() then
        DebugPrint("⚠️ FarmingManager Active")
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
-- GET HUMANOID
-- ==================================================
local function GetHumanoid()
    local Char = Player.Character
    if not Char then return nil, nil end
    return Char:FindFirstChildOfClass("Humanoid"), Char:FindFirstChild("HumanoidRootPart")
end

-- ==================================================
-- CLEANUP FLY
-- ==================================================
local function CleanupFly()
    if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end
    if BodyVelocity then
        pcall(function()
            BodyVelocity.Velocity = Vector3.zero
            BodyVelocity.MaxForce = Vector3.zero
        end)
        BodyVelocity:Destroy()
        BodyVelocity = nil
    end
    if BodyGyro then
        pcall(function() BodyGyro.MaxTorque = Vector3.zero end)
        BodyGyro:Destroy()
        BodyGyro = nil
    end
    local Hum, Root = GetHumanoid()
    if Hum then
        pcall(function()
            Hum.PlatformStand = false
            Hum.Sit = false
        end)
    end
    if Root then
        pcall(function()
            Root.AssemblyLinearVelocity = Vector3.zero
            Root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

-- ==================================================
-- FLY TP
-- ==================================================
local function FlyTP(Destination, Callback)
    DebugPrint("🚀 FlyTP Started | Dest:", tostring(Destination))
    CleanupFly()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then
        DebugPrint("❌ FlyTP Failed: No Humanoid/Health=0")
        if Callback then Callback() end
        return
    end

    Hum.PlatformStand = true

    BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.Name = "YokudoBV"
    BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    BodyVelocity.P = 1250
    BodyVelocity.Velocity = Vector3.zero
    BodyVelocity.Parent = Root

    BodyGyro = Instance.new("BodyGyro")
    BodyGyro.Name = "YokudoBG"
    BodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    BodyGyro.P = 3000
    BodyGyro.D = 500
    BodyGyro.CFrame = Root.CFrame
    BodyGyro.Parent = Root

    local StartTime = tick()

    FlyConnection = RunService.Heartbeat:Connect(function()
        if not ManagerEnabled then CleanupFly() return end

        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 or Hum2.Health <= 0 then CleanupFly() return end
        if not BodyVelocity or not BodyGyro then CleanupFly() return end

        local CurrentPos = Root2.Position
        local Dir = Destination - CurrentPos
        local TotalDist = Dir.Magnitude

        if TotalDist <= ARRIVE_DISTANCE then
            DebugPrint("✅ FlyTP Arrived | Dist:", math.floor(TotalDist))
            CleanupFly()
            Root2.CFrame = CFrame.new(Destination)
            if Callback then Callback() end
            return
        end

        if tick() - StartTime > FLY_TIMEOUT then
            DebugPrint("⏰ FlyTP Timeout | Dist Left:", math.floor(TotalDist))
            CleanupFly()
            if Callback then Callback() end
            return
        end

        BodyVelocity.Velocity = Dir.Unit * FLY_SPEED
        BodyGyro.CFrame = CFrame.new(CurrentPos, Destination)
    end)
end

-- ==================================================
-- FLY TO SAFE ZONE
-- ==================================================
local function FlyToSafeZone(Callback)
    DebugPrint("🚀 FlyToSafeZone Called")

    FlyTP(SAFE_ZONE, function()
        DebugPrint("✅ Arrived Safe Zone")
        if Callback then Callback() end
    end)
end

-- ==================================================
-- FLY TO PORTAL
-- ==================================================
local function FlyToPortal(Callback)
    DebugPrint("🚀 FlyToPortal Called")

    local Portal = workspace:FindFirstChild(PORTAL_NAME)
    if not Portal then
        DebugPrint("⚠️ Portal not found in FlyToPortal")
        if Callback then Callback() end
        return
    end

    local PortalPart = Portal:IsA("Model") and (Portal.PrimaryPart or Portal:FindFirstChildWhichIsA("BasePart")) or Portal
    local PortalPos = PortalPart and PortalPart.Position or nil
    if not PortalPos then
        DebugPrint("⚠️ Portal position not found")
        if Callback then Callback() end
        return
    end

    local TargetPos = Vector3.new(PortalPos.X, 75, PortalPos.Z)
    DebugPrint("🚀 Fly TP → Portal | Pos:", tostring(TargetPos))

    FlyTP(TargetPos, function()
        DebugPrint("✅ Arrived Portal")
        if Callback then Callback() end
    end)
end

-- ==================================================
-- FORCE STOP ALL
-- ==================================================
local function ForceStopAll()
    DebugPrint("Force Stop All Features")

    if _G.YOKUDO_AutoEventNew then
        pcall(function() _G.YOKUDO_AutoEventNew.Disable() end)
    end
    if _G.YOKUDO_AFKSystem then
        pcall(function() _G.YOKUDO_AFKSystem.Disable() end)
    end

    CleanupFly()
end

-- ==================================================
-- ENABLE AFK SYSTEM (Walk TP)
-- ==================================================
local function EnableAFKSystem()
    DebugPrint("========== EnableAFKSystem Called ==========")

    -- ✅ Check 1: FarmingManager
    if IsFarmingManagerActive() then
        DebugPrint("❌ Skip AFK: FarmingManager active")
        return
    end

    -- ✅ Check 2: AFKSystem loaded
    if not _G.YOKUDO_AFKSystem then
        DebugPrint("❌ AFKSystem NOT loaded!")
        return
    end
    DebugPrint("✅ AFKSystem loaded")

    -- ✅ Check 3: AFKSystem methods
    if not _G.YOKUDO_AFKSystem.Enable then
        DebugPrint("❌ AFKSystem.Enable not found!")
        return
    end
    DebugPrint("✅ AFKSystem.Enable method found")

    -- ✅ Check 4: AFKSystem.IsEnabled
    local IsEnabled = false
    pcall(function()
        IsEnabled = _G.YOKUDO_AFKSystem.IsEnabled()
    end)
    DebugPrint("AFKSystem IsEnabled:", tostring(IsEnabled))

    -- ✅ Disable មុនបើ Enabled
    if IsEnabled then
        DebugPrint("🔄 AFKSystem already enabled → Disable first")
        pcall(function() _G.YOKUDO_AFKSystem.Disable() end)
        task.wait(0.3)
    end

    -- ✅ Enable AFKSystem
    DebugPrint("🚀 Calling AFKSystem.Enable()...")
    local OK, Err = pcall(function() _G.YOKUDO_AFKSystem.Enable() end)

    if OK then
        DebugPrint("✅ AFKSystem.Enable() OK")

        -- ✅ Check ថា IsEnabled ពិតជា true
        task.wait(0.5)
        local FinalState = false
        pcall(function()
            FinalState = _G.YOKUDO_AFKSystem.IsEnabled()
        end)
        DebugPrint("✅ AFKSystem Final State:", tostring(FinalState))
    else
        DebugPrint("❌ AFKSystem.Enable() FAILED:", tostring(Err))
    end
end

-- ==================================================
-- FULL RESET
-- ==================================================
local function FullReset()
    DebugPrint("🔄 Full Reset...")

    CleanupFly()

    if _G.YOKUDO_AutoEventNew then
        pcall(function() _G.YOKUDO_AutoEventNew.Disable() end)
    end
    if _G.YOKUDO_AFKSystem then
        pcall(function() _G.YOKUDO_AFKSystem.Disable() end)
    end

    LastPortalState = false

    DebugPrint("✅ Full Reset Complete")
end

-- ==================================================
-- CALL MANAGER AFTER DONE
-- ==================================================
local function CallManagerAfterDone()
    DebugPrint("=========================================")
    DebugPrint("🎉 Portal Gone → Call AFK")
    DebugPrint("=========================================")

    if _G.YOKUDO_AutoEventNew then
        pcall(function() _G.YOKUDO_AutoEventNew.Disable() end)
        DebugPrint("✅ AutoEventNew Disabled")
    end

    task.wait(0.5)

    if not IsFarmingManagerActive() then
        EnableAFKSystem()
    else
        DebugPrint("⚠️ FarmingManager Active → Skip AFK")
    end

    LastPortalState = false
    DebugPrint("✅ Call Manager Complete")
end

-- ==================================================
-- SWITCH AFK TO ATTACK
-- ==================================================
local function SwitchAFKToAttack()
    DebugPrint("=========================================")
    DebugPrint("🚪 Portal Spawned → Switch to AutoEventNew")
    DebugPrint("=========================================")

    if IsFarmingManagerActive() then
        DebugPrint("⚠️ Skip Switch (FarmingManager active)")
        return
    end

    if _G.YOKUDO_AFKSystem and _G.YOKUDO_AFKSystem.IsEnabled() then
        pcall(function() _G.YOKUDO_AFKSystem.Disable() end)
        DebugPrint("✅ AFKSystem Disabled")
    end

    task.wait(0.5)

    FlyToSafeZone(function()
        DebugPrint("⏳ Wait 3s at Safe Zone...")
        task.wait(SAFE_ZONE_WAIT)

        FlyToPortal(function()
            if _G.YOKUDO_AutoEventNew then
                _G.YOKUDO_AutoEventNew.Enable()
                DebugPrint("✅ AutoEventNew Enabled")
            end
        end)
    end)
end

-- ==================================================
-- MAIN LOOP
-- ==================================================
local function MainLoop()
    DebugPrint("========== MainLoop Started ==========")

    local InitialPortal = IsPortalSpawned()
    DebugPrint("Initial Portal State:", tostring(InitialPortal))

    if not InitialPortal then
        DebugPrint("Initial: No Portal → Enable AFK")
        task.wait(0.5)
        EnableAFKSystem()
        LastPortalState = false
    else
        DebugPrint("Initial: Portal Spawned → Switch")
        task.wait(0.5)
        SwitchAFKToAttack()
        LastPortalState = true
    end

    while ManagerEnabled do
        if IsFarmingManagerActive() then
            if _G.YOKUDO_AutoEventNew and _G.YOKUDO_AutoEventNew.IsEnabled() then
                DebugPrint("⚠️ FarmingManager active → Stop AutoEventNew")
                _G.YOKUDO_AutoEventNew.Disable()
            end
            LastPortalState = false
            task.wait(PORTAL_CHECK_INTERVAL)
            continue
        end

        local CurrentPortalState = IsPortalSpawned()

        -- ✅ Portal ឃើញ (Spawn)
        if CurrentPortalState and not LastPortalState then
            DebugPrint("=========================================")
            DebugPrint("🚪 PORTAL SPAWNED → SPAWN SIGNAL")
            DebugPrint("=========================================")

            SwitchAFKToAttack()

            LastPortalState = true
        end

        -- ✅ Portal បាត់ (Done)
        if not CurrentPortalState and LastPortalState then
            DebugPrint("=========================================")
            DebugPrint("✅ PORTAL GONE → DONE SIGNAL")
            DebugPrint("=========================================")

            CallManagerAfterDone()

            LastPortalState = false
        end

        task.wait(PORTAL_CHECK_INTERVAL)
    end

    ForceStopAll()
    DebugPrint("MainLoop Stopped")
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

    DebugPrint("Manager Drone: ON")
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

    DebugPrint("Manager Drone: OFF")
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
    FlyToSafeZone = FlyToSafeZone,
    FlyToPortal = FlyToPortal,
}

print("✅ ManagerDrone Feature Loaded (v10 DEBUG)")
