-- ==================================================
-- YOKUDO HUB | TELEPORT SYSTEM (TWEEN + BODYV + BODYG)
-- Tween Speed 350 | BodyV + BodyG Speed 1000/s
-- Shot TP → Lock | Safe Zone → Reset + Stop
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Container = workspace:WaitForChild("AreaEggSlotsClient")

-- ==================================================
-- CONFIG
-- ==================================================
local Config = {
    FlySpeed = 1000,
    ReturnSpeed = 1000,

    -- ✅ Tween Speed (គណនា Duration តាមចម្ងាយ)
    TweenSpeed = 350,
    MinTweenDuration = 0.1,
    MaxTweenDuration = 5,

    FlyOffset = 5,
    ShotDistance = 25,
    LockAbove = 1,
    ArriveDistance = 2,
    SafeStopDistance = 5,
    NearOffset = 20,

    Timeout = 20,
    CollectInterval = 0.05,
    TargetCollectTimeout = 10,
    MaxRecoveryAttempts = 10000,

    BodyVelocityP = 5000,
    BodyGyroP = 50000,
    BodyGyroD = 2000,

    SafeZone = Vector3.new(533, 70, -366),
    LockPosition = Vector3.new(607.6259155273438, 70.57420349121094, -326.8830261230469),

    SearchPrefix = "FirstAreaEgg",
    PositionThreshold = 1,
}

-- ==================================================
-- REMOTES
-- ==================================================
local CollectEvent = ReplicatedStorage.Packages.Networking:FindFirstChild("RF/EggWorld/AskFieldEggCarry")
local ForestStrike = ReplicatedStorage.Packages.Networking:FindFirstChild("RE/GuardPatrol/ForestStrike")

if not CollectEvent then
    warn("[YOKUDO] CollectEvent not found")
    return
end

print("[YOKUDO] TeleportSystem: CollectEvent OK")

-- ==================================================
-- STATE
-- ==================================================
local State = {
    Running = false,
    Step = "idle",
    Mode = "none",
    Method = "TeleportFly",
    TargetUid = nil,

    FlySequence = 0,

    TweenConnection = nil,
    FlyConnection = nil,
    LockConnection = nil,
    BodyVelocity = nil,
    BodyGyro = nil,
    ActiveHeartbeat = nil,

    FirstEggList = {},
    FirstEggUid = nil,
    FirstEggSlotKey = nil,

    SavedTargetPosition = nil,
    TargetLockedCFrame = nil,

    FlyTargetStarted = false,
    CollectDone = false,
    TargetCollected = false,
    RemotesFired = false,
    RecoveryTriggered = false,
    RecoveryAttempts = 0,

    CollectAttempts = 0,
    CollectTime = 0,
    TargetCollectStartTime = 0,

    PlayerGui = nil,
    DropHeldEgg = nil,
    DropHeldEggConnection = nil,

    RagdollEnabled = false,
    RagdollConnection = nil,
    ForceUpConnection = nil,

    SavedWalkSpeed = nil,
    SavedJumpPower = nil,
    SavedJumpHeight = nil,
    SavedUseJumpPower = nil,
}

-- ==================================================
-- UTILS
-- ==================================================
local function GetHumanoid()
    local Char = Player.Character
    if not Char then return nil, nil end
    return Char:FindFirstChildOfClass("Humanoid"), Char:FindFirstChild("HumanoidRootPart")
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

local function SaveStats()
    local Hum = GetHumanoid()
    if not Hum then return end
    if State.SavedWalkSpeed == nil then State.SavedWalkSpeed = Hum.WalkSpeed end
    if State.SavedJumpPower == nil then State.SavedJumpPower = Hum.JumpPower end
    if State.SavedJumpHeight == nil then State.SavedJumpHeight = Hum.JumpHeight end
    if State.SavedUseJumpPower == nil then State.SavedUseJumpPower = Hum.UseJumpPower end
end

local function RestoreStats()
    local Hum = GetHumanoid()
    if not Hum then return end
    if State.SavedWalkSpeed ~= nil then pcall(function() Hum.WalkSpeed = State.SavedWalkSpeed end) end
    if State.SavedJumpPower ~= nil then pcall(function() Hum.JumpPower = State.SavedJumpPower end) end
    if State.SavedJumpHeight ~= nil then pcall(function() Hum.JumpHeight = State.SavedJumpHeight end) end
    if State.SavedUseJumpPower ~= nil then pcall(function() Hum.UseJumpPower = State.SavedUseJumpPower end) end
end

-- ==================================================
-- RAGDOLL BYPASS
-- ==================================================
local function ForceUp()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return end
    pcall(function()
        if Hum:GetState() == Enum.HumanoidStateType.Physics then
            Hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        Hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        Hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        Hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        Hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        Hum.PlatformStand = false
        Hum.Sit = false
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
        Root.CanCollide = true
        Hum.BreakJointsOnDeath = false
        Hum.RequiresNeck = false
    end)
end

local function CleanupRagdollConstraints()
    local Char = Player.Character
    if not Char then return end
    pcall(function()
        for _, d in ipairs(Char:GetDescendants()) do
            if d.Name:find("RagdollConstraint") or d.Name:find("RagdollAttachment") then
                d:Destroy()
            end
        end
        for _, d in ipairs(Char:GetDescendants()) do
            if d:IsA("Motor6D") then d.Enabled = true end
        end
    end)
end

local function EnableRagdollBypass()
    if State.RagdollEnabled then return end
    State.RagdollEnabled = true

    State.RagdollConnection = RunService.Heartbeat:Connect(function()
        if not State.RagdollEnabled then return end
        ForceUp()
    end)

    State.ForceUpConnection = task.spawn(function()
        while State.RagdollEnabled do
            task.wait(0.1)
            ForceUp()
            CleanupRagdollConstraints()
        end
    end)

    print("[YOKUDO] Ragdoll Bypass: ON")
end

local function DisableRagdollBypass()
    if not State.RagdollEnabled then return end
    State.RagdollEnabled = false
    if State.RagdollConnection then
        State.RagdollConnection:Disconnect()
        State.RagdollConnection = nil
    end
    print("[YOKUDO] Ragdoll Bypass: OFF")
end

-- ==================================================
-- CLEANUP MOVERS
-- ==================================================
local function CleanupMovers(KeepPlatformStand)
    if State.TweenConnection then
        pcall(function() State.TweenConnection:Cancel() end)
        State.TweenConnection = nil
    end
    if State.FlyConnection then
        State.FlyConnection:Disconnect()
        State.FlyConnection = nil
    end
    if State.LockConnection then
        State.LockConnection:Disconnect()
        State.LockConnection = nil
    end
    if State.BodyVelocity then
        pcall(function()
            State.BodyVelocity.Velocity = Vector3.zero
            State.BodyVelocity.MaxForce = Vector3.zero
        end)
        State.BodyVelocity:Destroy()
        State.BodyVelocity = nil
    end
    if State.BodyGyro then
        pcall(function() State.BodyGyro.MaxTorque = Vector3.zero end)
        State.BodyGyro:Destroy()
        State.BodyGyro = nil
    end

    local Hum, Root = GetHumanoid()
    if Root then
        for _, c in ipairs(Root:GetChildren()) do
            if c.Name == "YokudoBV" or c.Name == "YokudoBG" then
                pcall(function() c:Destroy() end)
            end
        end
    end

    if Hum and not KeepPlatformStand then
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
-- LOCK AT TARGET
-- ==================================================
local function StartLock(Position)
    if not Position then return end
    State.TargetLockedCFrame = CFrame.new(Position + Vector3.new(0, Config.LockAbove, 0))

    if State.LockConnection then State.LockConnection:Disconnect() end

    State.LockConnection = RunService.Heartbeat:Connect(function()
        if not State.Running then
            if State.LockConnection then State.LockConnection:Disconnect() State.LockConnection = nil end
            return
        end
        local _, Root = GetHumanoid()
        if not Root then return end
        Root.CFrame = State.TargetLockedCFrame
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end)
end

-- ==================================================
-- TWEEN + BODYV + BODYG FLY TP (Speed 350)
-- ==================================================
local function FlyTP(Destination, Speed, UseShotTP, IsSafeZone, Callback)
    State.FlySequence = State.FlySequence + 1
    local Seq = State.FlySequence

    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then return end

    local FlyPos = Vector3.new(Destination.X, Destination.Y + Config.FlyOffset, Destination.Z)
    local LockCFrame = CFrame.new(Destination + Vector3.new(0, Config.LockAbove, 0))

    Hum.PlatformStand = true

    -- ✅ Step 1: Tween ទៅ Near Position (TweenSpeed = 350)
    local StartPos = Root.Position
    local Direction = (FlyPos - StartPos)
    local TotalDist = Direction.Magnitude
    local DirUnit = TotalDist > 0 and Direction.Unit or Vector3.new(0, 0, -1)

    local NearPos = FlyPos - (DirUnit * Config.NearOffset)
    local NearDist = (NearPos - StartPos).Magnitude

    -- ✅ Duration = ចម្ងាយ ÷ TweenSpeed
    local NearDuration = math.clamp(
        NearDist / Config.TweenSpeed,
        Config.MinTweenDuration,
        Config.MaxTweenDuration
    )

    print("[YOKUDO] Tween Near | Dist:", math.floor(NearDist), "| Duration:", string.format("%.2f", NearDuration) .. "s")

    local TweenNear = TweenService:Create(
        Root,
        TweenInfo.new(NearDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { CFrame = CFrame.new(NearPos, FlyPos) }
    )
    State.TweenConnection = TweenNear
    TweenNear:Play()

    task.spawn(function()
        TweenNear.Completed:Wait()

        if Seq ~= State.FlySequence then return end
        if not State.Running then CleanupMovers() return end

        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 or Hum2.Health <= 0 then CleanupMovers() return end

        -- ✅ Step 2: BodyV + BodyG → Destination (Speed 1000/s)
        State.BodyVelocity = Instance.new("BodyVelocity")
        State.BodyVelocity.Name = "YokudoBV"
        State.BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        State.BodyVelocity.P = Config.BodyVelocityP
        State.BodyVelocity.Velocity = Vector3.zero
        State.BodyVelocity.Parent = Root2

        State.BodyGyro = Instance.new("BodyGyro")
        State.BodyGyro.Name = "YokudoBG"
        State.BodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        State.BodyGyro.P = Config.BodyGyroP
        State.BodyGyro.D = Config.BodyGyroD
        State.BodyGyro.CFrame = Root2.CFrame
        State.BodyGyro.Parent = Root2

        local StartTime = tick()
        local ShotDone = false

        State.FlyConnection = RunService.Heartbeat:Connect(function()
            if Seq ~= State.FlySequence then
                if State.FlyConnection then State.FlyConnection:Disconnect() State.FlyConnection = nil end
                return
            end

            if not State.Running then CleanupMovers() return end

            local Hum3, Root3 = GetHumanoid()
            if not Hum3 or not Root3 or Hum3.Health <= 0 then CleanupMovers() return end
            if not State.BodyVelocity or not State.BodyGyro then CleanupMovers() return end

            local CurrentPos = Root3.Position
            local Dir = FlyPos - CurrentPos
            local HorizDist = Vector3.new(Dir.X, 0, Dir.Z).Magnitude
            local VertDist = math.abs(Dir.Y)
            local TotalDist2 = Dir.Magnitude

            -- ✅ Safe Zone
            if IsSafeZone and HorizDist <= Config.SafeStopDistance then
                if State.BodyVelocity then
                    State.BodyVelocity.Velocity = Vector3.zero
                    State.BodyVelocity.MaxForce = Vector3.zero
                end
                if State.BodyGyro then State.BodyGyro.MaxTorque = Vector3.zero end
                if State.FlyConnection then State.FlyConnection:Disconnect() State.FlyConnection = nil end

                task.spawn(function()
                    task.wait(0.05)
                    CleanupMovers(true)
                    task.wait(0.05)
                    if Callback then Callback() end
                end)
                return
            end

            -- ✅ Shot TP
            if not IsSafeZone and UseShotTP and not ShotDone and HorizDist <= Config.ShotDistance then
                ShotDone = true
                if State.BodyVelocity then
                    State.BodyVelocity.Velocity = Vector3.zero
                    State.BodyVelocity.MaxForce = Vector3.zero
                end
                if State.BodyGyro then State.BodyGyro.MaxTorque = Vector3.zero end
                if State.FlyConnection then State.FlyConnection:Disconnect() State.FlyConnection = nil end

                task.spawn(function()
                    task.wait(0.05)
                    CleanupMovers(true)
                    Root3.CFrame = LockCFrame
                    Root3.AssemblyLinearVelocity = Vector3.zero
                    Root3.AssemblyAngularVelocity = Vector3.zero
                    task.wait(0.05)
                    StartLock(Destination)
                    if Callback then Callback() end
                end)
                return
            end

            -- ✅ Arrived
            if HorizDist <= Config.ArriveDistance and VertDist <= 2 then
                if State.BodyVelocity then
                    State.BodyVelocity.Velocity = Vector3.zero
                    State.BodyVelocity.MaxForce = Vector3.zero
                end
                if State.BodyGyro then State.BodyGyro.MaxTorque = Vector3.zero end
                if State.FlyConnection then State.FlyConnection:Disconnect() State.FlyConnection = nil end

                task.spawn(function()
                    task.wait(0.05)
                    CleanupMovers(true)
                    Root3.CFrame = LockCFrame
                    Root3.AssemblyLinearVelocity = Vector3.zero
                    Root3.AssemblyAngularVelocity = Vector3.zero
                    task.wait(0.05)
                    StartLock(Destination)
                    if Callback then Callback() end
                end)
                return
            end

            -- ✅ Timeout
            if tick() - StartTime > Config.Timeout then
                CleanupMovers()
                if Callback then Callback() end
                return
            end

            -- ✅ បន្តហោះ (Speed ថេរ 1000/s)
            if TotalDist2 > 1 then
                State.BodyVelocity.Velocity = Dir.Unit * Speed
            else
                State.BodyVelocity.Velocity = Vector3.zero
            end

            State.BodyGyro.CFrame = CFrame.new(CurrentPos, CurrentPos + Vector3.new(Dir.X, 0, Dir.Z))
        end)
    end)
end

-- ==================================================
-- INSTANT TP
-- ==================================================
local function InstantTP(Destination, Callback)
    if not Destination then if Callback then Callback() end return end

    State.FlySequence = State.FlySequence + 1
    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then return end

    local LockCFrame = CFrame.new(Destination + Vector3.new(0, Config.LockAbove, 0))
    Hum.PlatformStand = true

    task.spawn(function()
        Root.CFrame = LockCFrame
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
        task.wait(0.05)
        StartLock(Destination)
        if Callback then Callback() end
    end)
end

-- ==================================================
-- TELEPORT TO TARGET
-- ==================================================
local function TeleportToTarget(TargetPos, Callback)
    if State.Method == "InstantTeleport" then
        print("[YOKUDO] Instant TP to Target")
        InstantTP(TargetPos, Callback)
    else
        print("[YOKUDO] Tween Speed 350 + BodyV + BodyG to Target")
        FlyTP(TargetPos, Config.FlySpeed, true, false, Callback)
    end
end

-- ==================================================
-- REMOTES
-- ==================================================
local function RemoteCollectFirst()
    if not CollectEvent or not State.FirstEggSlotKey or not State.FirstEggUid then return false end
    local success = pcall(function()
        return CollectEvent:InvokeServer({
            FirstAreaSlotKey = State.FirstEggSlotKey,
            Uid = State.FirstEggUid
        })
    end)
    return success
end

local function RemoteCollectTarget()
    if not CollectEvent or not State.TargetUid then return false end
    local success = pcall(function()
        return CollectEvent:InvokeServer({ Uid = State.TargetUid })
    end)
    return success
end

local function FireForestStrike()
    if State.RemotesFired then return end
    State.RemotesFired = true
    EnableRagdollBypass()

    pcall(function()
        ForestStrike:FireServer({
            EggUid = State.FirstEggUid,
            GuardCFrame = CFrame.new(Config.LockPosition)
        })
    end)

    task.spawn(function()
        for i = 1, 10 do
            task.wait(0.05)
            ForceUp()
            CleanupRagdollConstraints()
        end
    end)

    print("[YOKUDO] ForestStrike Fired")
end

-- ==================================================
-- DROPHELDEGG
-- ==================================================
local function SetupDropHeldEgg()
    State.PlayerGui = Player:FindFirstChild("PlayerGui") or Player:WaitForChild("PlayerGui", 5)
    if not State.PlayerGui then return end

    State.DropHeldEgg = State.PlayerGui:FindFirstChild("DropHeldEgg")
    if not State.DropHeldEgg then warn("[YOKUDO] DropHeldEgg not found!") return end

    if State.DropHeldEggConnection then State.DropHeldEggConnection:Disconnect() end
    State.DropHeldEggConnection = State.DropHeldEgg:GetPropertyChangedSignal("Enabled"):Connect(function()
        print("[YOKUDO] DropHeldEgg.Enabled:", State.DropHeldEgg.Enabled)
    end)
end

local function IsTargetCollected()
    return State.DropHeldEgg and State.DropHeldEgg.Enabled == true
end

-- ==================================================
-- SEARCH FIRST EGGS
-- ==================================================
local function SearchFirstEggs()
    State.FirstEggList = {}
    if not Container then return end

    for _, Slot in ipairs(Container:GetChildren()) do
        if string.find(Slot.Name, Config.SearchPrefix) then
            local SlotNum = string.match(Slot.Name, "Slot_(%d+)")
            if SlotNum then
                table.insert(State.FirstEggList, {
                    Slot = Slot,
                    Uid = Slot.Name,
                    SlotKey = "Forest:Slot_" .. SlotNum,
                })
            end
        end
    end
end

local function FindClosestEgg()
    local _, Root = GetHumanoid()
    if not Root then return nil end

    local Closest, ClosestDist = nil, 9999
    for _, Egg in ipairs(State.FirstEggList) do
        local Pos = GetPosition(Egg.Slot)
        if Pos then
            local Dist = (Pos - Root.Position).Magnitude
            if Dist < ClosestDist then
                ClosestDist = Dist
                Closest = Egg
            end
        end
    end

    if Closest then
        State.FirstEggUid = Closest.Uid
        State.FirstEggSlotKey = Closest.SlotKey
    end
    return Closest
end

-- ==================================================
-- CHECK HELPERS
-- ==================================================
local function IsFirstEggInWorkspace()
    return State.FirstEggUid and workspace:FindFirstChild(State.FirstEggUid) ~= nil
end

local function IsFirstEggInContainer()
    return State.FirstEggUid and Container and Container:FindFirstChild(State.FirstEggUid) ~= nil
end

local function IsTargetInContainer()
    return State.TargetUid and Container and Container:FindFirstChild(State.TargetUid) ~= nil
end

local function IsTargetInWorkspace()
    return State.TargetUid and workspace:FindFirstChild(State.TargetUid) ~= nil
end

-- ==================================================
-- AUTO STOP
-- ==================================================
local function AutoStop()
    if State.LockConnection then State.LockConnection:Disconnect() State.LockConnection = nil end
    State.TargetLockedCFrame = nil

    if State.ActiveHeartbeat then State.ActiveHeartbeat:Disconnect() State.ActiveHeartbeat = nil end

    CleanupMovers()
    DisableRagdollBypass()
    RestoreStats()

    State.Running = false
    State.Step = "done"
    State.FlySequence = State.FlySequence + 1

    State.FirstEggList = {}
    State.FirstEggUid = nil
    State.FirstEggSlotKey = nil
    State.CollectAttempts = 0
    State.CollectTime = 0
    State.TargetCollectStartTime = 0
    State.FlyTargetStarted = false
    State.CollectDone = false
    State.TargetCollected = false
    State.RemotesFired = false
    State.RecoveryTriggered = false
    State.RecoveryAttempts = 0
    State.SavedTargetPosition = nil

    print("[YOKUDO] TeleportSystem: Auto Stop")
end

-- ==================================================
-- FLY TO TARGET
-- ==================================================
local function StartFlyToTarget()
    if State.FlyTargetStarted then return end
    State.FlyTargetStarted = true
    State.Step = "to_target"

    local TargetPos
    if State.Mode == "spawn" then
        local Egg = Container and Container:FindFirstChild(State.TargetUid)
        if Egg then TargetPos = GetPosition(Egg) end
    elseif State.Mode == "workspace" then
        TargetPos = State.SavedTargetPosition
        if not TargetPos then
            local Egg = workspace:FindFirstChild(State.TargetUid)
            if Egg then
                TargetPos = GetPosition(Egg)
                State.SavedTargetPosition = TargetPos
            end
        end
    end

    if not TargetPos then AutoStop() return end

    TeleportToTarget(TargetPos, function()
        State.TargetCollected = false
        State.CollectTime = 0
        State.CollectAttempts = 0
        State.RecoveryTriggered = false
        State.TargetCollectStartTime = tick()
        State.Step = "collect_target"
    end)
end

-- ==================================================
-- RECOVERY (Tween Speed 350 + BodyV + BodyG)
-- ==================================================
local function FlyToTargetAgain()
    State.RecoveryAttempts = State.RecoveryAttempts + 1
    if State.RecoveryAttempts > Config.MaxRecoveryAttempts then
        print("[YOKUDO] Max Recovery → AutoStop")
        AutoStop()
        return
    end

    print("[YOKUDO] Recovery #" .. State.RecoveryAttempts)
    State.Step = "recovery"

    State.FlySequence = State.FlySequence + 1
    CleanupMovers()

    local TargetPos
    if IsTargetInContainer() then
        State.Mode = "spawn"
        local Egg = Container:FindFirstChild(State.TargetUid)
        if Egg then TargetPos = GetPosition(Egg) end
    elseif IsTargetInWorkspace() then
        State.Mode = "workspace"
        local Egg = workspace:FindFirstChild(State.TargetUid)
        if Egg then
            TargetPos = GetPosition(Egg)
            State.SavedTargetPosition = TargetPos
        end
    else
        print("[YOKUDO] Target Gone → AutoStop")
        AutoStop()
        return
    end

    if not TargetPos then AutoStop() return end

    State.RecoveryTriggered = false
    State.TargetCollected = false

    FlyTP(TargetPos, Config.FlySpeed, false, false, function()
        print("[YOKUDO] Recovery #" .. State.RecoveryAttempts .. " Arrived")
        State.TargetCollected = false
        State.CollectTime = 0
        State.CollectAttempts = 0
        State.RecoveryTriggered = false
        State.RemotesFired = false
        State.TargetCollectStartTime = tick()
        State.Step = "collect_target"
    end)
end

-- ==================================================
-- SAFE ZONE (Reset + Stop ពេលមកដល់)
-- ==================================================
local function FlyToSafeZone()
    State.Step = "to_safe"
    State.RecoveryTriggered = false
    State.TargetCollected = false

    print("[YOKUDO] Tween Speed 350 to Safe Zone")

    FlyTP(Config.SafeZone, Config.ReturnSpeed, false, true, function()
        print("[YOKUDO] ✅ Arrived Safe Zone → Reset + Stop")

        if State.LockConnection then State.LockConnection:Disconnect() State.LockConnection = nil end
        State.TargetLockedCFrame = nil

        if State.ActiveHeartbeat then State.ActiveHeartbeat:Disconnect() State.ActiveHeartbeat = nil end

        CleanupMovers()
        DisableRagdollBypass()
        RestoreStats()

        State.Running = false
        State.Step = "idle"
        State.Mode = "none"
        State.FlySequence = State.FlySequence + 1

        State.FirstEggList = {}
        State.FirstEggUid = nil
        State.FirstEggSlotKey = nil
        State.CollectAttempts = 0
        State.CollectTime = 0
        State.TargetCollectStartTime = 0
        State.FlyTargetStarted = false
        State.CollectDone = false
        State.TargetCollected = false
        State.RemotesFired = false
        State.RecoveryTriggered = false
        State.RecoveryAttempts = 0
        State.SavedTargetPosition = nil

        print("[YOKUDO] TeleportSystem: Reset + Stopped")
    end)
end

-- ==================================================
-- HEARTBEAT LOOP
-- ==================================================
local function StartActiveHeartbeat()
    if State.ActiveHeartbeat then State.ActiveHeartbeat:Disconnect() end

    State.ActiveHeartbeat = RunService.Heartbeat:Connect(function()
        if not State.Running then return end

        local Hum, Root = GetHumanoid()
        if not Hum or not Root or Hum.Health <= 0 then return end

        -- Step 1: Collect First
        if State.Step == "collect_first" and not State.CollectDone then
            if IsFirstEggInWorkspace() then
                State.CollectDone = true
                FireForestStrike()
                State.Step = "wait_spawn_back"
                return
            end

            if tick() - State.CollectTime > Config.CollectInterval then
                State.CollectTime = tick()
                if IsFirstEggInContainer() then
                    RemoteCollectFirst()
                    State.CollectAttempts = State.CollectAttempts + 1
                elseif IsFirstEggInWorkspace() then
                    State.CollectDone = true
                    FireForestStrike()
                    State.Step = "wait_spawn_back"
                end
            end
        end

        -- Step 2: Wait First Egg Spawn
        if State.Step == "wait_spawn_back" and not State.FlyTargetStarted then
            if IsFirstEggInContainer() then
                task.spawn(function()
                    task.wait(0.05)
                    StartFlyToTarget()
                end)
            end
        end

        -- Step 3: Collect Target
        if State.Step == "collect_target" and not State.TargetCollected then
            if IsTargetCollected() then
                print("[YOKUDO] Target Collected (DropHeldEgg)")
                State.TargetCollected = true
                State.RecoveryTriggered = false
                task.spawn(function() task.wait(0.05) FlyToSafeZone() end)
                return
            end

            if State.Mode == "spawn" then
                if workspace:FindFirstChild(State.TargetUid) then
                    State.TargetCollected = true
                    task.spawn(function() task.wait(0.05) FlyToSafeZone() end)
                    return
                end
            elseif State.Mode == "workspace" and State.SavedTargetPosition then
                local Egg = workspace:FindFirstChild(State.TargetUid)
                if Egg then
                    local Pos = GetPosition(Egg)
                    if Pos and (Pos - State.SavedTargetPosition).Magnitude >= Config.PositionThreshold then
                        State.TargetCollected = true
                        task.spawn(function() task.wait(0.05) FlyToSafeZone() end)
                        return
                    end
                end
            end

            if tick() - State.CollectTime > Config.CollectInterval then
                State.CollectTime = tick()
                RemoteCollectTarget()
                State.CollectAttempts = State.CollectAttempts + 1
            end

            if tick() - State.TargetCollectStartTime > Config.TargetCollectTimeout then
                print("[YOKUDO] Target Timeout → Recovery")
                if not State.RecoveryTriggered then
                    State.RecoveryTriggered = true
                    task.spawn(function() task.wait(0.05) FlyToTargetAgain() end)
                end
            end
        end

        -- Step 4: Recovery on Way to Safe
        if State.Step == "to_safe" then
            if not IsTargetCollected() then
                if not State.RecoveryTriggered then
                    State.RecoveryTriggered = true
                    print("[YOKUDO] Egg Dropped → Recovery")
                    task.spawn(function() task.wait(0.05) FlyToTargetAgain() end)
                end
            else
                State.RecoveryTriggered = false
            end
        end
    end)
end

-- ==================================================
-- MAIN PROCESS
-- ==================================================
local function StartProcess()
    State.Running = true
    State.Step = "search"
    State.FlySequence = 0

    State.CollectAttempts = 0
    State.CollectTime = 0
    State.TargetCollectStartTime = 0
    State.FlyTargetStarted = false
    State.CollectDone = false
    State.TargetCollected = false
    State.RemotesFired = false
    State.RecoveryTriggered = false
    State.RecoveryAttempts = 0
    State.SavedTargetPosition = nil
    State.TargetLockedCFrame = nil

    SetupDropHeldEgg()
    SaveStats()
    EnableRagdollBypass()

    if IsTargetInContainer() then
        State.Mode = "spawn"
        print("[YOKUDO] Mode: spawn")
    elseif IsTargetInWorkspace() then
        State.Mode = "workspace"
        local Egg = workspace:FindFirstChild(State.TargetUid)
        if Egg then State.SavedTargetPosition = GetPosition(Egg) end
        print("[YOKUDO] Mode: workspace")
    else
        local Waited = 0
        while State.Running and not IsTargetInContainer() and not IsTargetInWorkspace() do
            task.wait(0.2)
            Waited = Waited + 0.2
            if Waited > 30 then AutoStop() return end
        end
        if IsTargetInContainer() then
            State.Mode = "spawn"
        elseif IsTargetInWorkspace() then
            State.Mode = "workspace"
            local Egg = workspace:FindFirstChild(State.TargetUid)
            if Egg then State.SavedTargetPosition = GetPosition(Egg) end
        end
    end

    SearchFirstEggs()
    if #State.FirstEggList == 0 then AutoStop() return end

    local Closest = FindClosestEgg()
    if not Closest then AutoStop() return end

    local EggPos = GetPosition(Closest.Slot)
    if not EggPos then AutoStop() return end

    State.Step = "fly_first"
    StartActiveHeartbeat()

    print("[YOKUDO] Tween Speed 350 + BodyV + BodyG to First Egg")
    FlyTP(EggPos, Config.FlySpeed, true, false, function()
        State.CollectDone = false
        State.CollectTime = 0
        State.Step = "collect_first"
    end)
end

-- ==================================================
-- PUBLIC API
-- ==================================================
local function FullReset()
    if State.LockConnection then State.LockConnection:Disconnect() State.LockConnection = nil end
    State.TargetLockedCFrame = nil

    if State.ActiveHeartbeat then State.ActiveHeartbeat:Disconnect() State.ActiveHeartbeat = nil end

    if State.DropHeldEggConnection then
        State.DropHeldEggConnection:Disconnect()
        State.DropHeldEggConnection = nil
    end
    State.DropHeldEgg = nil
    State.PlayerGui = nil

    CleanupMovers()
    DisableRagdollBypass()
    RestoreStats()

    State.Running = false
    State.Step = "idle"
    State.Mode = "none"
    State.FlySequence = State.FlySequence + 1

    State.FirstEggList = {}
    State.FirstEggUid = nil
    State.FirstEggSlotKey = nil
    State.CollectAttempts = 0
    State.CollectTime = 0
    State.TargetCollectStartTime = 0
    State.FlyTargetStarted = false
    State.CollectDone = false
    State.TargetCollected = false
    State.RemotesFired = false
    State.RecoveryTriggered = false
    State.RecoveryAttempts = 0
    State.SavedTargetPosition = nil

    print("[YOKUDO] TeleportSystem: Full Reset")
end

local TeleportSystem = {}

function TeleportSystem.Enable()
    if State.Running then return end
    if not CollectEvent then warn("[YOKUDO] CollectEvent not found") return end
    if not State.TargetUid then warn("[YOKUDO] No Target ID") return end

    FullReset()
    StartProcess()
    print("[YOKUDO] TeleportSystem: ON | Method: " .. State.Method)
end

function TeleportSystem.Disable()
    FullReset()
    print("[YOKUDO] TeleportSystem: OFF")
end

function TeleportSystem.SetTargetId(Id)
    State.TargetUid = Id
    print("[YOKUDO] Target ID: " .. tostring(Id))
end

function TeleportSystem.SetSpeed(Value)
    Value = math.clamp(Value, 50, 1100)
    Config.FlySpeed = Value
    Config.ReturnSpeed = Value
    print("[YOKUDO] Speed: " .. tostring(Value))
end

function TeleportSystem.SetMethod(Method)
    State.Method = (Method == "InstantTeleport") and "InstantTeleport" or "TeleportFly"
    print("[YOKUDO] Method: " .. State.Method)
end

function TeleportSystem.GetMethod() return State.Method end
function TeleportSystem.GetSpeed() return Config.FlySpeed end
function TeleportSystem.IsEnabled() return State.Running end
function TeleportSystem.GetTargetId() return State.TargetUid end

_G.YOKUDO_TeleportSystem = TeleportSystem

print("✅ TeleportSystem Loaded (Tween Speed 350 + BodyV + BodyG)")
