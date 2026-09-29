-- ==================================================
-- YOKUDO HUB | FEATURE | Manager Drone (v5 FINAL)
-- ✅ គ្មាន Portal → AFKSystem.Enable()
-- ✅ ឃើញ Portal → AFKSystem.Disable() → Fly Safe Zone → Wait 3s → Fly Portal → AutoEventNew.Enable()
-- ✅ Portal បាត់ → AutoEventNew.Disable() → Full Reset → AFKSystem.Enable()
-- ✅ Guard: FarmingManager ដំណើរការ → មិនហៅ AFK
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
local AFK_JUMP_WAIT = 0.5
local SAFE_ZONE_WAIT = 3          -- ✅ រង់ចាំ 3s នៅ Safe Zone
local FLY_SPEED = 500
local ARRIVE_DISTANCE = 5

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
-- ✅ FLY TP (BodyV + BodyG)
-- ==================================================
local function FlyTP(Destination, Callback)
    CleanupFly()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then
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
            CleanupFly()
            Root2.CFrame = CFrame.new(Destination)
            if Callback then Callback() end
            return
        end

        if tick() - StartTime > 15 then
            CleanupFly()
            if Callback then Callback() end
            return
        end

        BodyVelocity.Velocity = Dir.Unit * FLY_SPEED
        BodyGyro.CFrame = CFrame.new(CurrentPos, Destination)
    end)
end

-- ==================================================
-- ✅ FLY TO SAFE ZONE
-- ==================================================
local function FlyToSafeZone(Callback)
    print("[ManagerDrone] 🚀 Fly TP → Safe Zone")

    FlyTP(SAFE_ZONE, function()
        print("[ManagerDrone] ✅ Arrived Safe Zone")
        if Callback then Callback() end
    end)
end

-- ==================================================
-- ✅ FLY TO PORTAL
-- ==================================================
local function FlyToPortal(Callback)
    local Portal = workspace:FindFirstChild(PORTAL_NAME)
    if not Portal then
        print("[ManagerDrone] ⚠️ Portal not found")
        if Callback then Callback() end
        return
    end

    local PortalPart = Portal:IsA("Model") and (Portal.PrimaryPart or Portal:FindFirstChildWhichIsA("BasePart")) or Portal
    local PortalPos = PortalPart and PortalPart.Position or nil
    if not PortalPos then
        print("[ManagerDrone] ⚠️ Portal position not found")
        if Callback then Callback() end
        return
    end

    print("[ManagerDrone] 🚀 Fly TP → Portal | Pos:", tostring(PortalPos))

    FlyTP(PortalPos, function()
        print("[ManagerDrone] ✅ Arrived Portal")
        if Callback then Callback() end
    end)
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
-- ✅ FULL RESET
-- ==================================================
local function FullReset()
    print("[ManagerDrone] 🔄 Full Reset...")

    CleanupFly()

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

    -- ✅ 2. Full Reset (Stop Lock, Fly, Face)
    FullReset()

    task.wait(0.5)

    -- ✅ 3. Enable AFKSystem
    if not IsFarmingManagerActive() then
        EnableAFKSystem()
        print("[ManagerDrone] ✅ AFKSystem Enabled")
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
    print("[ManagerDrone] 🚪 Portal Spawned → Switch AFK to AutoEventNew")
    print("[ManagerDrone] ================================")

    if IsFarmingManagerActive() then
        print("[ManagerDrone] Skip Switch (FarmingManager active)")
        return
    end

    -- ✅ 1. Stop AFK System
    if _G.YOKUDO_AFKSystem then
        pcall(function() _G.YOKUDO_AFKSystem.Disable() end)
        print("[ManagerDrone] ✅ AFKSystem Disabled")
    end

    task.wait(0.5)

    -- ✅ 2. Fly TP → Safe Zone
    FlyToSafeZone(function()
        -- ✅ 3. រង់ចាំ 3s នៅ Safe Zone
        print("[ManagerDrone] ⏳ Wait 3s at Safe Zone...")
        task.wait(SAFE_ZONE_WAIT)

        -- ✅ 4. Fly TP → Portal
        FlyToPortal(function()
            -- ✅ 5. Enable AutoEventNew
            if _G.YOKUDO_AutoEventNew then
                _G.YOKUDO_AutoEventNew.Enable()
                print("[ManagerDrone] ✅ AutoEventNew Enabled")
            end
        end)
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

        -- ✅ Portal ឃើញ (Spawn) → Switch AFK to AutoEventNew
        if CurrentPortalState and not LastPortalState then
            print("[ManagerDrone] ================================")
            print("[ManagerDrone] 🚪 PORTAL SPAWNED → SPAWN SIGNAL")
            print("[ManagerDrone] ================================")

            if _G.YOKUDO_AFKSystem and _G.YOKUDO_AFKSystem.IsEnabled() then
                SwitchAFKToAttack()
            elseif _G.YOKUDO_AutoEventNew and not _G.YOKUDO_AutoEventNew.IsEnabled() then
                -- ✅ បើគ្មាន AFK → Fly Safe Zone → Wait 3s → Fly Portal → Enable
                SwitchAFKToAttack()
            end

            LastPortalState = true
        end

        -- ✅ Portal បាត់ (Done) → Stop + Reset + AFK
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
    FlyToSafeZone = FlyToSafeZone,
    FlyToPortal = FlyToPortal,
}

print("✅ ManagerDrone Feature Loaded (v5 FINAL + Safe Zone + Portal)")
