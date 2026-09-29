-- ==================================================
-- YOKUDO HUB | FEATURE | Auto Event New (v10 FINAL)
-- ✅ Boss1 & 3: Lock Behind 3 + Above 5 + Face + Attack (Range 100)
-- ✅ Boss2 (Ball): Fly TP → Coil Position (ជិត Boss បំផុត) → Lock Coil → Face + Attack (Range 50)
-- ✅ Boss2: No Lock Boss + Auto Switch Coil
-- ✅ Done (Portal Gone) → Call ManagerDrone → AFK
-- ✅ Full Reset ពេល User ដកធិក
-- ❌ គ្មាន ConfigSystem
-- ❌ គ្មាន Register CharacterSystem
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================
local PORTAL_NAME = "ScrambleArenaPortal"
local PORTAL_LEAVE_NAME = "LeaveTeleport"
local BOSS_CONTAINER = "ScrambleArena"
local COILS_CONTAINER = "Coils"

local BOSS_ORDER = { "Mech", "Ball", "ScrambleHuman" }

-- ✅ Coil Names (4 Coils)
local COIL_NAMES = { "Coil1", "Coil2", "Coil3", "Coil4" }

-- ✅ Coil Settings
local COIL_CHECK_INTERVAL = 1        -- ✅ Check Coil រាល់ 1s
local COIL_BOSS_TRIGGER = 20         -- ✅ Boss មកជិត 20 studs → Face + Attack
local COIL_WAIT_TIMEOUT = 120

-- ✅ Lock Settings (Boss 1 & 3)
local LOCK_BEHIND_NORMAL = 3
local LOCK_ABOVE_HEIGHT = 5

-- ✅ Attack Range
local ATTACK_RANGE_NORMAL = 100
local ATTACK_RANGE_BALL = 50
local ATTACK_INTERVAL = 0.05

local TELEPORT_SPEED = 800
local ARRIVE_DISTANCE = 3
local ARRIVE_TIMEOUT = 20

local GROUND_Y = 70
local PORTAL_FLY_OFFSET = 5
local BOSS_ARENA_Y = -468

local PUSH_UP_Y_THRESHOLD = -472
local PUSH_UP_Y_TARGET = -460

local BODY_VELOCITY_P = 5000
local BODY_GYRO_P = 50000
local BODY_GYRO_D = 2000

local CHECK_INTERVAL = 0.5
local SAFE_WAIT_TIME = 1
local BOSS_CHECK_INTERVAL = 0.3
local BOSS_SPAWN_TIMEOUT = 120
local DEATH_WAIT = 2
local EQUIP_CHECK_INTERVAL = 0.1

local NEXT_BOSS_WAIT_TIMEOUT = 60
local PORTAL_LEAVE_NEAR_THRESHOLD = 50

-- ==================================================
-- STATE
-- ==================================================
local AutoEventEnabled = false
local MainThread = nil
local FlyConnection = nil
local LockConnection = nil
local FaceConnection = nil
local PushUpConnection = nil
local BodyVelocity = nil
local BodyGyro = nil
local CurrentTarget = nil
local CurrentBossName = nil
local CurrentCoil = nil
local LastFire = 0
local TraceSequence = 0
local FlySequence = 0
local IsDead = false

-- ==================================================
-- DEBUG
-- ==================================================
local function DebugPrint(...)
    if _G.YOKUDO_EnablePrint then print("[AutoEventNew]", ...) end
end

-- ==================================================
-- HELPERS
-- ==================================================
local function GetHumanoid()
    local Char = Player.Character
    if not Char then return nil, nil end
    return Char:FindFirstChildOfClass("Humanoid"), Char:FindFirstChild("HumanoidRootPart")
end

local function GetBatSwingRemote()
    local Success, Remote = pcall(function()
        return ReplicatedStorage.Packages.Networking["RE/BatSwing/Trigger"]
    end)
    if Success and Remote then return Remote end
    return nil
end

local function GetPosition(Object)
    if not Object then return nil end
    if Object:IsA("Model") then
        if Object.PrimaryPart then return Object.PrimaryPart.Position end
        local Part = Object:FindFirstChildWhichIsA("BasePart")
        if Part then return Part.Position end
        for _, Desc in ipairs(Object:GetDescendants()) do
            if Desc:IsA("BasePart") then return Desc.Position end
        end
    elseif Object:IsA("BasePart") then
        return Object.Position
    end
    return nil
end

local function GetLookVector(Object)
    if not Object then return Vector3.new(0, 0, -1) end
    local Part = nil
    if Object:IsA("Model") then
        Part = Object.PrimaryPart or Object:FindFirstChildWhichIsA("BasePart")
        if not Part then
            for _, Desc in ipairs(Object:GetDescendants()) do
                if Desc:IsA("BasePart") then Part = Desc break end
            end
        end
    elseif Object:IsA("BasePart") then
        Part = Object
    end
    if Part then return Part.CFrame.LookVector end
    return Vector3.new(0, 0, -1)
end

local function GetLockPosition(Target, BossName)
    if not Target then return nil, nil end
    local CenterPos = nil
    if Target:IsA("Model") then
        local Success, CF, Size = pcall(function() return Target:GetBoundingBox() end)
        if Success and CF then CenterPos = CF.Position end
    end
    if not CenterPos then CenterPos = GetPosition(Target) end
    if not CenterPos then return nil, nil end

    local BehindDist = LOCK_BEHIND_NORMAL
    local LookVector = GetLookVector(Target)
    local LockPos = CenterPos - (LookVector * BehindDist)
    LockPos = Vector3.new(LockPos.X, CenterPos.Y + LOCK_ABOVE_HEIGHT, LockPos.Z)
    return LockPos, CenterPos
end

local function CleanupMovers(KeepPlatformStand)
    if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end
    if LockConnection then LockConnection:Disconnect() LockConnection = nil end
    if FaceConnection then FaceConnection:Disconnect() FaceConnection = nil end
    if BodyVelocity then
        pcall(function() BodyVelocity.Velocity = Vector3.zero BodyVelocity.MaxForce = Vector3.zero end)
        BodyVelocity:Destroy() BodyVelocity = nil
    end
    if BodyGyro then
        pcall(function() BodyGyro.MaxTorque = Vector3.zero end)
        BodyGyro:Destroy() BodyGyro = nil
    end
    local Hum, Root = GetHumanoid()
    if Root then
        for _, Child in ipairs(Root:GetChildren()) do
            if Child.Name == "YokudoBV" or Child.Name == "YokudoBG" then
                pcall(function() Child:Destroy() end)
            end
        end
    end
    if Hum and not KeepPlatformStand then
        pcall(function() Hum.PlatformStand = false Hum.Sit = false end)
    end
    if Root then
        pcall(function()
            Root.AssemblyLinearVelocity = Vector3.zero
            Root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

local function FindPortal() return workspace:FindFirstChild(PORTAL_NAME) end

local function FindPortalLeave()
    local Arena = workspace:FindFirstChild(BOSS_CONTAINER)
    if not Arena then return nil end
    return Arena:FindFirstChild(PORTAL_LEAVE_NAME)
end

local function IsPlayerAtPortalLeave()
    local _, Root = GetHumanoid()
    if not Root then return false end
    local Leave = FindPortalLeave()
    if not Leave then return false end
    local LeavePos = GetPosition(Leave)
    if not LeavePos then return false end
    return (Root.Position - LeavePos).Magnitude <= PORTAL_LEAVE_NEAR_THRESHOLD
end

local function GetClosestPortal()
    local _, Root = GetHumanoid()
    if not Root then return nil, nil, nil end
    if IsPlayerAtPortalLeave() then return nil, nil, nil end
    local PlayerPos = Root.Position
    local Portal = FindPortal()
    local PortalLeave = FindPortalLeave()
    local PortalPos = Portal and GetPosition(Portal) or nil
    local LeavePos = PortalLeave and GetPosition(PortalLeave) or nil
    local BestPortal, BestPos, BestDist = nil, nil, math.huge
    if PortalPos then
        local D = (PortalPos - PlayerPos).Magnitude
        if D < BestDist then BestDist = D BestPortal = Portal BestPos = PortalPos end
    end
    if LeavePos then
        local D = (LeavePos - PlayerPos).Magnitude
        if D < BestDist then BestDist = D BestPortal = PortalLeave BestPos = LeavePos end
    end
    return BestPortal, BestPos, BestDist
end

local function FindAnyBoss()
    local Arena = workspace:FindFirstChild(BOSS_CONTAINER)
    if not Arena then return nil, nil end
    for _, BossName in ipairs(BOSS_ORDER) do
        local Boss = Arena:FindFirstChild(BossName)
        if Boss then return Boss, BossName end
    end
    return nil, nil
end

local function AnyBossAlive()
    local Arena = workspace:FindFirstChild(BOSS_CONTAINER)
    if not Arena then return false end
    for _, BossName in ipairs(BOSS_ORDER) do
        if Arena:FindFirstChild(BossName) then return true end
    end
    return false
end

-- ✅ Find All Coils (4)
local function FindAllCoils()
    local Arena = workspace:FindFirstChild(BOSS_CONTAINER)
    if not Arena then return {} end
    local CoilsFolder = Arena:FindFirstChild(COILS_CONTAINER)
    if not CoilsFolder then return {} end

    local Coils = {}
    for _, CoilName in ipairs(COIL_NAMES) do
        local Coil = CoilsFolder:FindFirstChild(CoilName)
        if Coil then
            table.insert(Coils, Coil)
        end
    end
    return Coils
end

-- ✅ Find Closest Coil to Boss
local function FindClosestCoilToBoss(Boss)
    if not Boss then return nil, nil end
    local BossPos = GetPosition(Boss)
    if not BossPos then return nil, nil end

    local Coils = FindAllCoils()
    if #Coils == 0 then return nil, nil end

    local Closest, ClosestDist = nil, math.huge
    for _, Coil in ipairs(Coils) do
        local CoilPos = GetPosition(Coil)
        if CoilPos then
            local Dist = (CoilPos - BossPos).Magnitude
            DebugPrint(string.format("🔍 Coil: %s | Dist: %.1f", Coil.Name, Dist))
            if Dist < ClosestDist then
                ClosestDist = Dist
                Closest = Coil
            end
        end
    end

    if Closest then
        DebugPrint(string.format("🎯 Closest Coil: %s | Dist: %.1f", Closest.Name, ClosestDist))
    end
    return Closest, ClosestDist
end

-- ✅ Wait For Coil
local function WaitForCoil()
    DebugPrint("⏳ Wait for Coil...")
    local Elapsed = 0
    while AutoEventEnabled and Elapsed < COIL_WAIT_TIMEOUT do
        local Coils = FindAllCoils()
        if #Coils > 0 then return Coils end
        task.wait(COIL_CHECK_INTERVAL)
        Elapsed = Elapsed + COIL_CHECK_INTERVAL
    end
    return {}
end

-- ==================================================
-- BODYV + BODYG FLY TP
-- ==================================================
local function FlyTP(Destination, Callback)
    FlySequence = FlySequence + 1
    local Seq = FlySequence
    CleanupMovers()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then
        if Callback then Callback() end
        return
    end
    Hum.PlatformStand = true
    BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.Name = "YokudoBV"
    BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    BodyVelocity.P = BODY_VELOCITY_P
    BodyVelocity.Velocity = Vector3.zero
    BodyVelocity.Parent = Root
    BodyGyro = Instance.new("BodyGyro")
    BodyGyro.Name = "YokudoBG"
    BodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    BodyGyro.P = BODY_GYRO_P
    BodyGyro.D = BODY_GYRO_D
    BodyGyro.CFrame = Root.CFrame
    BodyGyro.Parent = Root
    local InitDir = (Destination - Root.Position)
    if InitDir.Magnitude > 1 then BodyVelocity.Velocity = InitDir.Unit * TELEPORT_SPEED end
    local StartTime = tick()
    FlyConnection = RunService.Heartbeat:Connect(function()
        if Seq ~= FlySequence then
            if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end
            return
        end
        if not AutoEventEnabled then CleanupMovers() return end
        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 or Hum2.Health <= 0 then CleanupMovers() return end
        if not BodyVelocity or not BodyGyro then CleanupMovers() return end
        local CurrentPos = Root2.Position
        local Dir = Destination - CurrentPos
        local TotalDist = Dir.Magnitude
        if TotalDist <= ARRIVE_DISTANCE then
            if BodyVelocity then BodyVelocity.Velocity = Vector3.zero BodyVelocity.MaxForce = Vector3.zero end
            if BodyGyro then BodyGyro.MaxTorque = Vector3.zero end
            if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end
            task.spawn(function()
                task.wait(0.05)
                CleanupMovers(true)
                Root2.CFrame = CFrame.new(Destination)
                Root2.AssemblyLinearVelocity = Vector3.zero
                Root2.AssemblyAngularVelocity = Vector3.zero
                if Callback then Callback() end
            end)
            return
        end
        if tick() - StartTime > ARRIVE_TIMEOUT then
            CleanupMovers()
            if Callback then Callback() end
            return
        end
        BodyVelocity.Velocity = Dir.Unit * TELEPORT_SPEED
        BodyGyro.CFrame = CFrame.new(CurrentPos, Destination)
    end)
end

-- ==================================================
-- ✅ FLY TO COIL (Position ត្រង់ — គ្មាន Offset)
-- ==================================================
local function FlyToCoil(Coil)
    if not Coil then return false end
    local CoilPos = GetPosition(Coil)
    if not CoilPos then return false end

    -- ✅ Fly TP ត្រង់ Position របស់ Coil
    local TargetPos = Vector3.new(CoilPos.X, CoilPos.Y, CoilPos.Z)

    DebugPrint(string.format("🚀 Fly TP → Coil: %s | Pos: %.1f, %.1f, %.1f",
        Coil.Name, TargetPos.X, TargetPos.Y, TargetPos.Z))

    local Arrived = false
    FlyTP(TargetPos, function() Arrived = true end)

    local WaitTime = 0
    while AutoEventEnabled and not Arrived and WaitTime < 15 do
        task.wait(0.1)
        WaitTime = WaitTime + 0.1
    end

    if Arrived then
        CleanupMovers()
        DebugPrint("✅ At Coil → Stop Fly")
    end
    return Arrived
end

-- ==================================================
-- ✅ LOCK COIL (Lock Position ជាប់នៅ Coil)
-- ==================================================
local function StartLockCoil(Coil)
    if not Coil then return end

    local CoilPos = GetPosition(Coil)
    if not CoilPos then return end

    -- ✅ Lock Pos = Coil Position ត្រង់ (គ្មាន +Y)
    local LockedPos = Vector3.new(CoilPos.X, CoilPos.Y, CoilPos.Z)

    if LockConnection then LockConnection:Disconnect() end
    LockConnection = RunService.Heartbeat:Connect(function()
        if not AutoEventEnabled then
            if LockConnection then LockConnection:Disconnect() LockConnection = nil end
            return
        end

        local Hum, Root = GetHumanoid()
        if not Hum or not Root or Hum.Health <= 0 then return end

        -- ✅ Lock Position ជាប់ (មិនរើ)
        Root.CFrame = CFrame.new(LockedPos)
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end)

    DebugPrint("🔒 Lock Coil:", Coil.Name, "| Pos:", tostring(LockedPos))
end

-- ==================================================
-- ✅ FACE BOSS (គ្មាន Lock Boss)
-- ==================================================
local function StartFaceBoss()
    if FaceConnection then FaceConnection:Disconnect() end
    FaceConnection = RunService.Heartbeat:Connect(function()
        if not AutoEventEnabled then
            if FaceConnection then FaceConnection:Disconnect() FaceConnection = nil end
            return
        end
        if not CurrentTarget or not CurrentTarget.Parent then
            if FaceConnection then FaceConnection:Disconnect() FaceConnection = nil end
            return
        end
        local Hum, Root = GetHumanoid()
        if not Hum or not Root or Hum.Health <= 0 then return end
        local BossPos = GetPosition(CurrentTarget)
        if not BossPos then return end
        local CurrentPos = Root.Position
        Root.CFrame = CFrame.new(CurrentPos, Vector3.new(BossPos.X, CurrentPos.Y, BossPos.Z))
    end)
end

local function StopFaceBoss()
    if FaceConnection then FaceConnection:Disconnect() FaceConnection = nil end
end

-- ==================================================
-- ✅ LOCK BOSS (Boss 1 & 3)
-- ==================================================
local function StartLockBoss()
    if LockConnection then LockConnection:Disconnect() end
    LockConnection = RunService.Heartbeat:Connect(function()
        if not AutoEventEnabled then
            if LockConnection then LockConnection:Disconnect() LockConnection = nil end
            return
        end
        if not CurrentTarget or not CurrentTarget.Parent then
            if LockConnection then LockConnection:Disconnect() LockConnection = nil end
            return
        end
        local Hum, Root = GetHumanoid()
        if not Hum or not Root or Hum.Health <= 0 then return end
        local LockPos, CenterPos = GetLockPosition(CurrentTarget, CurrentBossName)
        if not LockPos or not CenterPos then return end
        Root.CFrame = CFrame.new(LockPos, CenterPos)
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end)
end

-- ==================================================
-- FIRE AT BOSS
-- ==================================================
local function FireAtBoss(Boss, Range)
    if not Boss or not Boss.Parent then return end
    local Remote = GetBatSwingRemote()
    if not Remote then return end
    local Hum, Root = GetHumanoid()
    if not Root then return end
    local BossPos = GetPosition(Boss)
    if not BossPos then return end
    local Dist = math.floor((BossPos - Root.Position).Magnitude)
    if Dist > Range then return end
    TraceSequence = TraceSequence + 1
    local TraceId = tostring(Player.UserId) .. ":" .. tostring(TraceSequence) .. ":" .. tostring(math.floor(workspace:GetServerTimeNow() * 1000))
    pcall(function() Remote:FireServer(nil, TraceId) end)
end

-- ==================================================
-- FIND BAT TOOL
-- ==================================================
local function FindBatTool()
    local Char = Player.Character
    if Char then
        for _, tool in ipairs(Char:GetChildren()) do
            if tool:IsA("Tool") and (tool.ToolTip == "Bat" or tool.Name:find("Bat")) then
                return tool, "equipped"
            end
        end
    end
    local Backpack = Player:FindFirstChild("Backpack")
    if not Backpack then return nil end
    for _, tool in ipairs(Backpack:GetChildren()) do
        if tool:IsA("Tool") and (tool.ToolTip == "Bat" or tool.Name:find("Bat")) then
            return tool, "backpack"
        end
    end
    return nil
end

-- ==================================================
-- AUTO EQUIP BAT
-- ==================================================
local EquipConnection, LastBatCheck, BatEquipped = nil, 0, false
local function StartAutoEquip()
    if EquipConnection then EquipConnection:Disconnect() end
    BatEquipped = false LastBatCheck = 0
    EquipConnection = RunService.Heartbeat:Connect(function()
        if not AutoEventEnabled then return end
        local now = tick()
        if now - LastBatCheck < EQUIP_CHECK_INTERVAL then return end
        LastBatCheck = now
        local Bat, Location = FindBatTool()
        if not Bat then
            if BatEquipped then BatEquipped = false end
            return
        end
        if Location == "backpack" then
            local Hum = GetHumanoid()
            if Hum then
                pcall(function() Hum:EquipTool(Bat) BatEquipped = true end)
            end
        elseif Location == "equipped" then
            if not BatEquipped then BatEquipped = true end
        end
    end)
end

local function StopAutoEquip()
    if EquipConnection then EquipConnection:Disconnect() EquipConnection = nil end
    BatEquipped = false
end

-- ==================================================
-- FLY TO CLOSEST PORTAL
-- ==================================================
local function FlyToClosestPortal()
    if IsPlayerAtPortalLeave() then return true end
    local Portal, PortalPos = GetClosestPortal()
    if not Portal or not PortalPos then return false end
    local Y = GROUND_Y + PORTAL_FLY_OFFSET
    local PortalTarget = Vector3.new(PortalPos.X, Y, PortalPos.Z)
    local Arrived = false
    FlyTP(PortalTarget, function() Arrived = true end)
    local WaitTime = 0
    while AutoEventEnabled and not Arrived and WaitTime < 15 do
        task.wait(0.1)
        WaitTime = WaitTime + 0.1
    end
    return Arrived
end

-- ==================================================
-- ✅ SETUP TARGET
-- ==================================================
local function SetupTargetForBoss(Boss, BossName)
    if not Boss or not Boss.Parent then return false end
    CurrentTarget = Boss
    CurrentBossName = BossName

    if LockConnection then LockConnection:Disconnect() LockConnection = nil end
    if FaceConnection then FaceConnection:Disconnect() FaceConnection = nil end
    CleanupMovers()

    DebugPrint("========================================")
    DebugPrint("🎯 SETUP Target:", BossName)

    -- ✅ Boss 2 (Ball) → Fly Coil → Lock Coil
    if BossName == "Ball" then
        DebugPrint("🚀 Boss 2 (Ball) → Find Closest Coil")

        local Coils = WaitForCoil()
        if #Coils == 0 then
            DebugPrint("❌ No Coils → Skip Boss 2")
            return true
        end
        if not AutoEventEnabled then return false end

        CurrentCoil = FindClosestCoilToBoss(CurrentTarget)
        if not CurrentCoil then
            DebugPrint("❌ No Coil → Skip")
            return true
        end

        FlyToCoil(CurrentCoil)      -- ✅ Fly ទៅ Coil Position
        StartLockCoil(CurrentCoil)  -- ✅ Lock Coil (ជាប់)
        DebugPrint("✅ At Coil → Locked → Wait for Boss")
        return true
    end

    -- ✅ Boss 1 & 3 → Lock Task
    DebugPrint("🚀 Boss", BossName, "→ Fly TP to Lock")
    local LockPos = GetLockPosition(CurrentTarget, BossName)
    if not LockPos then return false end

    local Arrived = false
    FlyTP(LockPos, function() Arrived = true end)
    while AutoEventEnabled and not Arrived do task.wait(0.1) end
    if not AutoEventEnabled then return false end

    StartLockBoss()
    return true
end

-- ==================================================
-- ✅ PUSH UP Y
-- ==================================================
local function StartPushUpY()
    if PushUpConnection then PushUpConnection:Disconnect() end
    PushUpConnection = RunService.Heartbeat:Connect(function()
        if not AutoEventEnabled then return end
        if not IsPlayerAtPortalLeave() then return end
        local Hum, Root = GetHumanoid()
        if not Hum or not Root or Hum.Health <= 0 then return end
        if Root.Position.Y < PUSH_UP_Y_THRESHOLD then
            Root.CFrame = CFrame.new(Root.Position.X, PUSH_UP_Y_TARGET, Root.Position.Z)
            Root.AssemblyLinearVelocity = Vector3.zero
            Root.AssemblyAngularVelocity = Vector3.zero
        end
    end)
end

local function StopPushUpY()
    if PushUpConnection then PushUpConnection:Disconnect() PushUpConnection = nil end
end

-- ==================================================
-- ✅ CALL MANAGER (Done)
-- ==================================================
local function CallManagerDone()
    DebugPrint("🎉 Event Done → Call ManagerDrone")
    AutoEventEnabled = false
    if _G.YOKUDO_ManagerDrone and _G.YOKUDO_ManagerDrone.CallManagerAfterDone then
        pcall(function() _G.YOKUDO_ManagerDrone.CallManagerAfterDone() end)
        DebugPrint("✅ Called ManagerDrone.CallManagerAfterDone()")
    else
        DebugPrint("⚠️ ManagerDrone not available → Fallback AFK")
        if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
            pcall(function() _G.YOKUDO_AFKSystem.Enable() end)
            DebugPrint("✅ Fallback AFK Enabled")
        end
    end
end

-- ==================================================
-- ✅ FULL RESET
-- ==================================================
local function FullReset()
    DebugPrint("🔄 Full Reset...")
    if MainThread then
        pcall(function() task.cancel(MainThread) end)
        MainThread = nil
    end
    CleanupMovers()
    StopAutoEquip()
    StopPushUpY()
    StopFaceBoss()
    CurrentTarget = nil
    CurrentBossName = nil
    CurrentCoil = nil
    LastFire = 0
    TraceSequence = 0
    FlySequence = 0
    IsDead = false
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
    DebugPrint("✅ Full Reset Complete")
end

-- ==================================================
-- ✅ MAIN LOOP
-- ==================================================
local function MainLoop()
    DebugPrint("MainLoop Started")
    StartPushUpY()

    local Boss, BossName = FindAnyBoss()
    local _, Root = GetHumanoid()

    if Boss and Root then
        local Portal, _, PortalDist = GetClosestPortal()
        local BossPos = GetPosition(Boss)
        local BossDist = BossPos and (BossPos - Root.Position).Magnitude or math.huge
        if Portal and PortalDist and PortalDist < BossDist and not IsPlayerAtPortalLeave() then
            DebugPrint("📍 Portal ជិតជាង Boss → Fly Portal មុន")
            FlyToClosestPortal()
            task.wait(SAFE_WAIT_TIME)
            Boss, BossName = FindAnyBoss()
        end
    end

    if not Boss then
        DebugPrint("⏳ No Boss → Find Portal...")
        while AutoEventEnabled do
            Boss, BossName = FindAnyBoss()
            if Boss then break end
            if IsPlayerAtPortalLeave() then break end
            local Portal = GetClosestPortal()
            if Portal then break end
            task.wait(CHECK_INTERVAL)
        end
        if not AutoEventEnabled then return end
        if not Boss then
            FlyToClosestPortal()
            task.wait(SAFE_WAIT_TIME)
        end
        local WaitTime = 0
        while AutoEventEnabled and WaitTime < BOSS_SPAWN_TIMEOUT do
            Boss, BossName = FindAnyBoss()
            if Boss then break end
            task.wait(BOSS_CHECK_INTERVAL)
            WaitTime = WaitTime + BOSS_CHECK_INTERVAL
        end
    end

    if not AutoEventEnabled then return end

    if Boss and BossName then
        SetupTargetForBoss(Boss, BossName)
    else
        DebugPrint("❌ No Boss → Done")
        CallManagerDone()
        return
    end

    local LastCoilCheck = 0
    while AutoEventEnabled do
        local Hum = GetHumanoid()
        if not Hum or Hum.Health <= 0 then
            if not IsDead then IsDead = true end
            task.wait(0.5)
            continue
        end
        if IsDead then IsDead = false end

        if not CurrentTarget or not CurrentTarget.Parent then
            DebugPrint("✅", CurrentBossName, "Dead / Gone")
            StopFaceBoss()
            local WaitTime = 0
            local NewBoss, NewName = nil, nil
            while AutoEventEnabled and WaitTime < NEXT_BOSS_WAIT_TIMEOUT do
                NewBoss, NewName = FindAnyBoss()
                if NewBoss then
                    DebugPrint("✅ New Boss:", NewName)
                    break
                end
                task.wait(BOSS_CHECK_INTERVAL)
                WaitTime = WaitTime + BOSS_CHECK_INTERVAL
            end
            if NewBoss and NewName then
                SetupTargetForBoss(NewBoss, NewName)
            else
                DebugPrint("❌ No Boss → Done → Call Manager")
                CallManagerDone()
                break
            end
            continue
        end

        local now = tick()

        if CurrentBossName == "Ball" then
            -- ✅ Check Coil ថ្មីជិត Boss ជាង រាល់ 1s
            if now - LastCoilCheck >= COIL_CHECK_INTERVAL then
                LastCoilCheck = now
                local NewCoil = FindClosestCoilToBoss(CurrentTarget)
                if NewCoil and NewCoil ~= CurrentCoil then
                    local OldCoilPos = CurrentCoil and GetPosition(CurrentCoil)
                    local NewCoilPos = GetPosition(NewCoil)
                    local BossPos = GetPosition(CurrentTarget)
                    if OldCoilPos and NewCoilPos and BossPos then
                        local OldDist = (OldCoilPos - BossPos).Magnitude
                        local NewDist = (NewCoilPos - BossPos).Magnitude
                        if NewDist < OldDist - 3 then
                            DebugPrint("🔄 Switch Coil:", NewCoil.Name)
                            CurrentCoil = NewCoil
                            FlyToCoil(CurrentCoil)       -- ✅ Fly ទៅ Coil ថ្មី
                            StartLockCoil(CurrentCoil)   -- ✅ Lock Coil ថ្មី
                        end
                    end
                end
            end

            -- ✅ Check Boss ↔ Coil Distance
            local BossPos = GetPosition(CurrentTarget)
            local CoilPos = CurrentCoil and GetPosition(CurrentCoil) or nil
            local InRange = false
            if BossPos and CoilPos then
                local D = (BossPos - CoilPos).Magnitude
                if D <= COIL_BOSS_TRIGGER then InRange = true end
            end
            if InRange then
                StartFaceBoss()  -- ✅ Face Boss (មិន Lock Boss)
                if now - LastFire >= ATTACK_INTERVAL then
                    LastFire = now
                    FireAtBoss(CurrentTarget, ATTACK_RANGE_BALL)
                end
            else
                StopFaceBoss()
            end
        else
            -- ✅ Boss 1 & 3 — Attack Range 100
            if now - LastFire >= ATTACK_INTERVAL then
                LastFire = now
                FireAtBoss(CurrentTarget, ATTACK_RANGE_NORMAL)
            end
        end
        task.wait(0.01)
    end

    DebugPrint("⏳ Wait Path Gone...")
    local Elapsed = 0
    while AutoEventEnabled and Elapsed < 60 do
        local LeaveTP = FindPortalLeave()
        local BossAlive = AnyBossAlive()
        if not LeaveTP and not BossAlive then
            DebugPrint("✅ Path Gone → Done")
            CallManagerDone()
            break
        end
        task.wait(0.5)
        Elapsed = Elapsed + 0.5
    end

    FullReset()
    if AutoEventEnabled then CallManagerDone() end
end

-- ==================================================
-- PUBLIC API
-- ==================================================
local function Enable()
    if AutoEventEnabled then return end
    AutoEventEnabled = true
    CurrentTarget = nil
    CurrentBossName = nil
    CurrentCoil = nil
    LastFire = 0
    TraceSequence = 0
    FlySequence = 0
    IsDead = false
    StartAutoEquip()
    if MainThread then pcall(function() task.cancel(MainThread) end) end
    MainThread = task.spawn(MainLoop)
    DebugPrint("✅ AutoEventNew: ON")
end

local function Disable()
    if not AutoEventEnabled then
        FullReset()
        return
    end
    AutoEventEnabled = false
    FullReset()
    DebugPrint("❌ AutoEventNew: OFF")
end

local function Toggle()
    if AutoEventEnabled then Disable() else Enable() end
end

-- ==================================================
-- EXPORT (គ្មាន Register / ConfigSystem)
-- ==================================================
_G.YOKUDO_AutoEventNew = {
    Enable = Enable,
    Disable = Disable,
    Toggle = Toggle,
    IsEnabled = function() return AutoEventEnabled end,
    FullReset = FullReset,
    CallManagerDone = CallManagerDone,
    FindAnyBoss = FindAnyBoss,
    FindAllCoils = FindAllCoils,
    FindClosestCoilToBoss = FindClosestCoilToBoss,
    FlyToCoil = FlyToCoil,
    StartLockCoil = StartLockCoil,
    LOCK_BEHIND_NORMAL = LOCK_BEHIND_NORMAL,
    ATTACK_RANGE_NORMAL = ATTACK_RANGE_NORMAL,
    ATTACK_RANGE_BALL = ATTACK_RANGE_BALL,
}

print("✅ AutoEventNew Feature Loaded (v10 FINAL — Fly Coil Position + Lock)")
