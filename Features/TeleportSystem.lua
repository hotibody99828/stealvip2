-- ==================================================
-- YOKUDO HUB | TELEPORT SYSTEM (v22 - Teleport New)
-- ✅ First Egg → Fly TP + Lock ពីលើ Egg (20m)
-- ✅ First Egg = true → Stop Collect → Drop First
-- ✅ Drop First → Push Up Y+70 → Shot TP ទៅវិញ → ជិត 1200m → Stop + Down ភ្លាម → Walk TP Target
-- ✅ Target Egg → Fly TP + Lock (20m)
-- ✅ 10 Map + WaitAtTarget តាមចម្ងាយ Egg ទៅ Map ជិតបំផុត
-- ✅ Check Player តែ P1_Top1 និង P2_Top1
-- ✅ Push Up Instant (Speed 99999)
-- ✅ ពេល true → Shot TP Top1 (Y+70) → CFrame Instant (Y=70) → Lock + Drop
-- ✅ Recover → Walk TP → Top2
-- ✅ AutoStop ពេល Egg បាត់ពី Workspace + Path Spawn
-- ✅ Save/Restore WalkSpeed ដើមរបស់ Player
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer
local Container = workspace:WaitForChild("AreaEggSlotsClient")

-- ==================================================
-- CONFIG
-- ==================================================
local Config = {
    FirstEggLockDistance = 5,
    ArriveDistance = 2,
    LockDistance = 1,
    WalkSpeed = 200,
    FlyTPDistance = 20,
    FlyOffset = 3,
    FlySpeed = 200,
    StopShotDistance = 1200,
    ShotTPTime = 1.25,
    ShotTPTime2 = 1.25,
    PushUpOffset = 70,
    PushUpSpeed = 99999,
    PlayerCheckDistance = 30,
    LockWait = 0.1,
    WaitForFalseTimeout = 10,
    RecoverDistanceThreshold = 500,
    MaxRepeatCount = 10,
    Position1_Top1 = Vector3.new(612, 70, -333),
    Position1_Top2 = Vector3.new(546, 70, -309),
    Position2_Top1 = Vector3.new(602, 70, -410),
    Position2_Top2 = Vector3.new(541, 70, -414),
    WalkTimeout = 30,
    CollectInterval = 0.02,
    MaxCollectAttempts = 10000,
    EggGoneCheckInterval = 0.5,
}

-- ==================================================
-- ✅ Map Positions (10 Map)
-- ==================================================
local MapPositions = {
    {Pos = Vector3.new(5666, 70, -329), Wait = 8},
    {Pos = Vector3.new(4798, 70, -333), Wait = 6},
    {Pos = Vector3.new(4031, 70, -396), Wait = 4},
    {Pos = Vector3.new(3397, 70, -328), Wait = 2},
    {Pos = Vector3.new(2815, 70, -398), Wait = 1},
    {Pos = Vector3.new(2286, 70, -331), Wait = 1},
    {Pos = Vector3.new(1877, 70, -390), Wait = 1},
    {Pos = Vector3.new(1488, 70, -318), Wait = 1},
    {Pos = Vector3.new(1187, 70, -406), Wait = 1},
    {Pos = Vector3.new(950, 70, -328), Wait = 1},
}

-- ==================================================
-- REMOTES
-- ==================================================
local CollectEvent = ReplicatedStorage.Packages.Networking:FindFirstChild("RF/EggWorld/AskFieldEggCarry")
local DropEvent = ReplicatedStorage.Packages.Networking:FindFirstChild("RF/EggWorld/AskFieldEggDrop")

if not CollectEvent then warn("[TeleportSystem] CollectEvent not found") return end
if not DropEvent then warn("[TeleportSystem] DropEvent not found") return end

print("[TeleportSystem] CollectEvent + DropEvent OK")

-- ==================================================
-- STATE
-- ==================================================
local State = {
    Running = false,
    Step = "idle",
    FirstEggUid = nil,
    FirstEggSlotKey = nil,
    TargetUid = nil,
    SelectedEgg = nil,
    WalkConnection = nil,
    FlyConnection = nil,
    LockConnection = nil,
    DropHeldEgg = nil,
    DropHeldEggConnection = nil,
    FirstCollected = false,
    TargetCollected = false,
    CollectedAgain = false,
    DropDone = false,
    CollectAttempts = 0,
    SavedWalkSpeed = nil,
    FlySequence = 0,
    FirstDropDone = false,
    RepeatCount = 0,
    IsRecoverMode = false,
    SafePosition = nil,
    SafeName = nil,
    CurrentEggUid = nil,
    EggGoneCheckThread = nil,
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

local function GetWalkSpeed() return Config.WalkSpeed or 200 end

local function SavePlayerWalkSpeed()
    local Hum = GetHumanoid()
    if not Hum then return end
    if State.SavedWalkSpeed == nil then
        State.SavedWalkSpeed = Hum.WalkSpeed
        print("[TeleportSystem] ✅ Saved WalkSpeed:", State.SavedWalkSpeed)
    end
end

local function RestoreStats()
    local Hum = GetHumanoid()
    if not Hum then return end
    if State.SavedWalkSpeed ~= nil then
        pcall(function() Hum.WalkSpeed = State.SavedWalkSpeed end)
        print("[TeleportSystem] ✅ Restored WalkSpeed:", State.SavedWalkSpeed)
    else
        pcall(function() Hum.WalkSpeed = 16 end)
    end
end

local function CleanupMovers()
    if State.WalkConnection then State.WalkConnection:Disconnect() State.WalkConnection = nil end
    if State.FlyConnection then State.FlyConnection:Disconnect() State.FlyConnection = nil end
    if State.LockConnection then State.LockConnection:Disconnect() State.LockConnection = nil end
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

-- ✅ Check Egg Gone
local function IsEggGone(Uid)
    if not Uid then return true end
    local InWorkspace = workspace:FindFirstChild(Uid) ~= nil
    local InContainer = Container and Container:FindFirstChild(Uid) ~= nil
    if not InWorkspace and not InContainer then
        return true
    end
    return false
end

-- ✅ Get Nearest Map Wait Time
local function GetNearestMapWait(EggPos)
    if not EggPos then return 8 end
    local NearestMap = nil
    local NearestDist = math.huge
    local NearestWait = 8
    for i, MapData in ipairs(MapPositions) do
        local Dist = (EggPos - MapData.Pos).Magnitude
        if Dist < NearestDist then
            NearestDist = Dist
            NearestMap = i
            NearestWait = MapData.Wait
        end
    end
    print("[TeleportSystem] 🗺️ Nearest Map:", NearestMap, "| Dist:", math.floor(NearestDist) .. "m | Wait:", NearestWait .. "s")
    return NearestWait
end

-- ✅ Get Safe Position (Check Player តែ P1_Top1 + P2_Top1)
local function GetSafePosition()
    local P1_Top1 = Config.Position1_Top1
    local P2_Top1 = Config.Position2_Top1

    local P1_Top1_MinDist = math.huge
    local P2_Top1_MinDist = math.huge

    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= Player then
            local otherChar = otherPlayer.Character
            if otherChar then
                local otherRoot = otherChar:FindFirstChild("HumanoidRootPart")
                if otherRoot then
                    local pos = otherRoot.Position
                    local d1 = (pos - P1_Top1).Magnitude
                    local d2 = (pos - P2_Top1).Magnitude
                    if d1 < P1_Top1_MinDist then P1_Top1_MinDist = d1 end
                    if d2 < P2_Top1_MinDist then P2_Top1_MinDist = d2 end
                end
            end
        end
    end

    print("[TeleportSystem] 📊 P1_Top1_MinDist:", math.floor(P1_Top1_MinDist) .. "m | P2_Top1_MinDist:", math.floor(P2_Top1_MinDist) .. "m")

    local SafePos = P1_Top1
    local SafeName = "P1_Top1"

    if P1_Top1_MinDist < Config.PlayerCheckDistance and P2_Top1_MinDist >= P1_Top1_MinDist then
        SafePos = P2_Top1
        SafeName = "P2_Top1"
        print("[TeleportSystem] ⚠️ Player នៅជិត P1_Top1 → P2_Top1")
    else
        SafePos = P1_Top1
        SafeName = "P1_Top1"
        print("[TeleportSystem] ✅ → P1_Top1")
    end

    State.SafePosition = SafePos
    State.SafeName = SafeName

    return SafePos, SafeName
end

-- ==================================================
-- ✅ PUSH UP INSTANT
-- ==================================================
local function PushUp(Offset, Callback)
    CleanupMovers()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root then if Callback then Callback() end return end

    print("[TeleportSystem] ⬆️ Push Up Instant Y+" .. Offset)

    local StartPos = Root.Position
    local TargetPos = StartPos + Vector3.new(0, Offset, 0)

    pcall(function()
        Hum.PlatformStand = true
        Root.CFrame = CFrame.new(TargetPos)
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end)

    print("[TeleportSystem] ✅ Push Up Instant Done | Y=" .. math.floor(TargetPos.Y))
    if Callback then Callback() end
end

-- ==================================================
-- ✅ CFrame Instant
-- ==================================================
local function CFrameInstant(Destination, Callback)
    CleanupMovers()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then
        if Callback then Callback() end
        return
    end

    print("[TeleportSystem] ⚡ CFrame Instant | From:", Root.Position, "| To:", Destination)

    pcall(function()
        Hum:MoveTo(Root.Position)
        Hum.WalkSpeed = 0
        Root.CFrame = CFrame.new(Destination)
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end)

    if Callback then Callback() end
end

-- ==================================================
-- REMOTES
-- ==================================================
local function RemoteCollectFirst()
    if not CollectEvent or not State.FirstEggSlotKey or not State.FirstEggUid then return false end
    return pcall(function()
        return CollectEvent:InvokeServer({
            FirstAreaSlotKey = State.FirstEggSlotKey,
            Uid = State.FirstEggUid
        })
    end)
end

local function RemoteCollectTarget()
    if not CollectEvent or not State.TargetUid then return false end
    return pcall(function()
        return CollectEvent:InvokeServer({ Uid = State.TargetUid })
    end)
end

local function RemoteDrop()
    if not DropEvent then return false end
    local Success, Result = pcall(function()
        return DropEvent:InvokeServer({ Reason = "PlayerRequest" })
    end)
    return Success and Result
end

-- ==================================================
-- LOCK
-- ==================================================
local function StartLock(TargetPos)
    if State.LockConnection then State.LockConnection:Disconnect() State.LockConnection = nil end
    local LockedCFrame = CFrame.new(TargetPos + Vector3.new(0, Config.LockDistance, 0))
    State.LockConnection = RunService.Heartbeat:Connect(function()
        if not State.Running then
            if State.LockConnection then State.LockConnection:Disconnect() State.LockConnection = nil end
            return
        end
        local _, Root = GetHumanoid()
        if not Root then return end
        Root.CFrame = LockedCFrame
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function StopLock()
    if State.LockConnection then
        State.LockConnection:Disconnect()
        State.LockConnection = nil
    end
end

-- ==================================================
-- FLY TP + LOCK
-- ==================================================
local function FlyTPAndLock(Destination, YOffset, Callback)
    CleanupMovers()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then if Callback then Callback() end return end

    State.FlySequence = State.FlySequence + 1
    local Seq = State.FlySequence
    local LockPos = Destination + Vector3.new(0, YOffset or Config.FlyOffset, 0)
    Hum.PlatformStand = true
    local StartTime = tick()

    State.FlyConnection = RunService.Heartbeat:Connect(function()
        if not State.Running then CleanupMovers() return end
        if Seq ~= State.FlySequence then
            if State.FlyConnection then State.FlyConnection:Disconnect() State.FlyConnection = nil end
            return
        end
        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 or Hum2.Health <= 0 then CleanupMovers() return end
        local CurrentPos = Root2.Position
        local Dir = LockPos - CurrentPos
        local Dist = Dir.Magnitude
        if Dist <= 3 then
            if State.FlyConnection then State.FlyConnection:Disconnect() State.FlyConnection = nil end
            CleanupMovers()
            Root2.CFrame = CFrame.new(LockPos)
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero
            StartLock(LockPos)
            if Callback then Callback() end
            return
        end
        local MoveDir = Dir.Unit
        local MoveStep = MoveDir * Config.FlySpeed * (1/60)
        Root2.CFrame = CFrame.new(CurrentPos + MoveStep)
        Root2.AssemblyLinearVelocity = Vector3.zero
        Root2.AssemblyAngularVelocity = Vector3.zero
        if tick() - StartTime > 10 then
            if State.FlyConnection then State.FlyConnection:Disconnect() State.FlyConnection = nil end
            CleanupMovers()
            Root2.CFrame = CFrame.new(LockPos)
            StartLock(LockPos)
            if Callback then Callback() end
        end
    end)
end

-- ==================================================
-- SHOT TP
-- ==================================================
local function ShotTP(Destination, Time, CheckDrop, Callback)
    CleanupMovers()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then if Callback then Callback() end return end
    local TargetCFrame = CFrame.new(Destination)
    local StartPos = Root.Position
    local StartTime = tick()
    Hum.PlatformStand = true
    local ShotStopRequested = false

    State.FlyConnection = RunService.Heartbeat:Connect(function()
        if not State.Running then CleanupMovers() return end
        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 or Hum2.Health <= 0 then CleanupMovers() return end
        local Elapsed = tick() - StartTime
        local Alpha = math.clamp(Elapsed / Time, 0, 1)
        local NewPos = StartPos:Lerp(Destination, Alpha)
        Root2.CFrame = CFrame.new(NewPos)
        Root2.AssemblyLinearVelocity = Vector3.zero
        Root2.AssemblyAngularVelocity = Vector3.zero
        local Dist = (Root2.Position - Destination).Magnitude
        if CheckDrop and not ShotStopRequested and Dist <= Config.StopShotDistance then
            ShotStopRequested = true
            if State.FlyConnection then State.FlyConnection:Disconnect() State.FlyConnection = nil end
            if Hum2 then Hum2.PlatformStand = false end
            RemoteDrop()
            if Callback then Callback() end
            return
        end
        if Dist <= Config.ArriveDistance or Alpha >= 1 then
            CleanupMovers()
            Root2.CFrame = TargetCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero
            if Callback then Callback() end
        end
    end)
end

-- ==================================================
-- SHOT TP WITH STOP+DROP (សម្រាប់ STEP 3b)
-- ==================================================
local function ShotTPWithStop(Destination, Time, StopDistance, Callback)
    CleanupMovers()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then if Callback then Callback() end return end

    local StartPos = Root.Position
    local StartTime = tick()
    Hum.PlatformStand = true

    print("[TeleportSystem] ⚡ Shot TP → " .. tostring(Destination) .. " | Stop at " .. StopDistance .. "m")

    State.FlyConnection = RunService.Heartbeat:Connect(function()
        if not State.Running then CleanupMovers() return end
        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 or Hum2.Health <= 0 then CleanupMovers() return end

        local Elapsed = tick() - StartTime
        local Alpha = math.clamp(Elapsed / Time, 0, 1)
        local NewPos = StartPos:Lerp(Destination, Alpha)

        Root2.CFrame = CFrame.new(NewPos)
        Root2.AssemblyLinearVelocity = Vector3.zero
        Root2.AssemblyAngularVelocity = Vector3.zero

        local Dist = (Root2.Position - Destination).Magnitude

        if Dist <= StopDistance then
            if State.FlyConnection then State.FlyConnection:Disconnect() State.FlyConnection = nil end
            CleanupMovers()

            local DownPos = Vector3.new(Root2.Position.X, 70, Root2.Position.Z)
            Root2.CFrame = CFrame.new(DownPos)
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero

            print("[TeleportSystem] ✅ Stop + Down Instant | Pos:", DownPos)
            if Callback then Callback() end
            return
        end

        if Alpha >= 1 then
            CleanupMovers()
            if Callback then Callback() end
        end
    end)
end

-- ==================================================
-- WALK TP
-- ==================================================
local function WalkTP(Destination, LockAfterArrive, FlyAtDistance, DropAtDistance, Callback)
    CleanupMovers()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then if Callback then Callback() end return end

    local WalkSpeed = GetWalkSpeed()
    Hum.WalkSpeed = WalkSpeed
    local StartTime = tick()
    local LastCheck = 0
    local FlyDone = false
    local DropDone = false

    State.WalkConnection = RunService.Heartbeat:Connect(function()
        if not State.Running then CleanupMovers() return end
        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 or Hum2.Health <= 0 then CleanupMovers() return end
        Hum2.WalkSpeed = WalkSpeed
        local Dist = (Root2.Position - Destination).Magnitude
        if FlyAtDistance and not FlyDone and Dist <= FlyAtDistance then
            FlyDone = true
            State.WalkConnection:Disconnect() State.WalkConnection = nil
            Hum2:MoveTo(Root2.Position)
            Hum2.WalkSpeed = 0
            FlyTPAndLock(Destination, Config.FlyOffset, function() if Callback then Callback() end end)
            return
        end
        if DropAtDistance and not DropDone and Dist <= DropAtDistance then
            DropDone = true
            RemoteDrop()
        end
        Hum2:MoveTo(Destination)
        if tick() - LastCheck > 0.05 then
            LastCheck = tick()
            if Dist <= Config.ArriveDistance then
                CleanupMovers()
                Hum2:MoveTo(Root2.Position)
                Hum2.WalkSpeed = 0
                if LockAfterArrive then StartLock(Destination) end
                if Callback then Callback() end
                return
            end
            if tick() - StartTime > Config.WalkTimeout then CleanupMovers() if Callback then Callback() end return end
        end
    end)
end

-- ==================================================
-- ✅ EGG GONE CHECK THREAD
-- ==================================================
local function StartEggGoneCheck()
    if State.EggGoneCheckThread then
        pcall(function() task.cancel(State.EggGoneCheckThread) end)
        State.EggGoneCheckThread = nil
    end

    State.EggGoneCheckThread = task.spawn(function()
        while State.Running do
            task.wait(Config.EggGoneCheckInterval)

            if State.CurrentEggUid then
                if IsEggGone(State.CurrentEggUid) then
                    print("[TeleportSystem] ⚠️ Current Egg Gone → AutoStop")
                    AutoStop()
                    return
                end
            end

            if State.TargetUid and not State.DropDone then
                if IsEggGone(State.TargetUid) then
                    print("[TeleportSystem] ⚠️ Target Egg Gone → AutoStop")
                    AutoStop()
                    return
                end
            end

            if State.FirstEggUid and not State.FirstDropDone then
                if IsEggGone(State.FirstEggUid) then
                    print("[TeleportSystem] ⚠️ First Egg Gone → AutoStop")
                    AutoStop()
                    return
                end
            end
        end
    end)
end

-- ==================================================
-- DROPHELDEGG
-- ==================================================
local function SetupDropHeldEgg()
    local PG = Player:FindFirstChild("PlayerGui") or Player:WaitForChild("PlayerGui", 5)
    if not PG then return end
    State.DropHeldEgg = PG:FindFirstChild("DropHeldEgg")
    if not State.DropHeldEgg then warn("[TeleportSystem] DropHeldEgg not found!") return end
    if State.DropHeldEggConnection then State.DropHeldEggConnection:Disconnect() State.DropHeldEggConnection = nil end

    State.DropHeldEggConnection = State.DropHeldEgg:GetPropertyChangedSignal("Enabled"):Connect(function()
        local IsEnabled = State.DropHeldEgg.Enabled == true
        print("[TeleportSystem] ⚡ DropHeldEgg.Enabled →", IsEnabled, "| Step:", State.Step)

        if IsEnabled and State.Running and State.Step == "2_collect_first" then
            State.FirstCollected = true
            State.CurrentEggUid = State.FirstEggUid
            StopLock()
            State.Step = "2b_drop_first"
            task.spawn(function()
                task.wait(0.05)
                RemoteDrop()
                State.FirstDropDone = true
                State.CurrentEggUid = nil
                task.wait(0.2)
                Step3b_AfterDropFirst()
            end)
        end

        if IsEnabled and State.Running and State.Step == "6_collect_target" then
            State.TargetCollected = true
            State.CurrentEggUid = State.TargetUid
            StopLock()
            task.spawn(function()
                task.wait(0.02)
                Step7_ShotToSafePosition()
            end)
        end

        if IsEnabled and State.Running and State.Step == "8b_collect_again" then
            State.CollectedAgain = true
            State.CurrentEggUid = State.TargetUid
            StopLock()
            task.spawn(function()
                task.wait(0.2)
                Step9_WalkToSwapPosition()
            end)
        end
    end)
end

-- ==================================================
-- AUTO STOP
-- ==================================================
local function AutoStop()
    StopLock()
    CleanupMovers()
    RestoreStats()
    State.Running = false
    State.Step = "done"
    State.FirstCollected = false
    State.TargetCollected = false
    State.CollectedAgain = false
    State.DropDone = false
    State.CollectAttempts = 0
    State.FirstDropDone = false
    State.RepeatCount = 0
    State.IsRecoverMode = false
    State.SafePosition = nil
    State.SafeName = nil
    State.CurrentEggUid = nil
    print("[TeleportSystem] ✅ Auto Stop")
    if State.DropHeldEggConnection then
        State.DropHeldEggConnection:Disconnect()
        State.DropHeldEggConnection = nil
    end
    if State.EggGoneCheckThread then
        pcall(function() task.cancel(State.EggGoneCheckThread) end)
        State.EggGoneCheckThread = nil
    end
end

-- ==================================================
-- FORWARD DECLARATIONS
-- ==================================================
function Step3b_AfterDropFirst() end
function Step7_ShotToSafePosition() end
function Step9_WalkToSwapPosition() end
function Step8c_CheckDistanceAndRecover() end
function Step8b_WalkToCollectAgain() end
function Step4_WalkToTargetAndFlyLock() end

-- ==================================================
-- ✅ STEP 1: Walk → First Egg → Fly TP + Lock (20m)
-- ==================================================
local function Step1_WalkToFirstEgg()
    State.Step = "1_to_first"
    local FirstEgg = Container:FindFirstChild(State.FirstEggUid)
    if not FirstEgg then AutoStop() return end
    local FirstPos = GetPosition(FirstEgg)
    if not FirstPos then AutoStop() return end

    WalkTP(FirstPos, false, Config.FlyTPDistance, false, function()
        State.Step = "2_collect_first"
        State.FirstCollected = false
        State.CurrentEggUid = State.FirstEggUid
        task.spawn(function()
            while State.Running and State.Step == "2_collect_first" do
                task.wait(Config.CollectInterval)
                RemoteCollectFirst()
                State.CollectAttempts = State.CollectAttempts + 1
                if State.CollectAttempts > Config.MaxCollectAttempts then AutoStop() return end
            end
        end)
    end)
end

-- ==================================================
-- ✅ STEP 3b: បន្ទាប់ពី Drop First → Push Up → Shot TP → Stop + Down → Walk TP Target
-- ==================================================
function Step3b_AfterDropFirst()
    if not State.Running then return end
    State.Step = "3b_after_drop"
    StopLock()

    PushUp(Config.PushUpOffset, function()
        local TargetPos
        if Container:FindFirstChild(State.TargetUid) then
            TargetPos = GetPosition(Container:FindFirstChild(State.TargetUid))
        elseif workspace:FindFirstChild(State.TargetUid) then
            TargetPos = GetPosition(workspace:FindFirstChild(State.TargetUid))
        end
        if not TargetPos then AutoStop() return end

        ShotTPWithStop(TargetPos, Config.ShotTPTime, Config.StopShotDistance, function()
            task.wait(0.2)
            Step4_WalkToTargetAndFlyLock()
        end)
    end)
end

-- ==================================================
-- ✅ STEP 4: Walk → Egg Target → 20m → Fly TP + Lock → Wait (តាម Map)
-- ==================================================
function Step4_WalkToTargetAndFlyLock()
    if not State.Running then return end
    State.Step = "4_walk_target"

    local TargetPos
    if Container:FindFirstChild(State.TargetUid) then
        TargetPos = GetPosition(Container:FindFirstChild(State.TargetUid))
    elseif workspace:FindFirstChild(State.TargetUid) then
        TargetPos = GetPosition(workspace:FindFirstChild(State.TargetUid))
    end
    if not TargetPos then AutoStop() return end

    local WaitTime = GetNearestMapWait(TargetPos)
    print("[TeleportSystem] Step 4: WaitAtTarget =", WaitTime .. "s")

    WalkTP(TargetPos, false, Config.FlyTPDistance, false, function()
        task.spawn(function()
            task.wait(WaitTime)
            if not State.Running then return end
            State.Step = "6_collect_target"
            State.TargetCollected = false
            State.CurrentEggUid = State.TargetUid
            while State.Running and State.Step == "6_collect_target" do
                task.wait(Config.CollectInterval)
                RemoteCollectTarget()
            end
        end)
    end)
end

-- ==================================================
-- ✅ STEP 7: Push Up Instant → Shot TP Safe (Y+70) → CFrame Instant (Y=70) → Lock + Drop
-- ==================================================
function Step7_ShotToSafePosition()
    if not State.Running then return end
    State.Step = "7_push_up"
    StopLock()

    PushUp(Config.PushUpOffset, function()
        local SafePos, SafeName = GetSafePosition()
        State.SafeName = SafeName
        State.SafePosition = SafePos

        local ShotTarget = SafePos + Vector3.new(0, Config.PushUpOffset, 0)
        print("[TeleportSystem] Step 7: Shot TP → " .. SafeName .. " (Y+70)")

        ShotTP(ShotTarget, Config.ShotTPTime2, false, function()
            CFrameInstant(SafePos, function()
                CleanupMovers()
                StartLock(SafePos)

                task.spawn(function()
                    task.wait(Config.LockWait)
                    RemoteDrop()
                    State.DropDone = true
                    State.CurrentEggUid = nil
                    task.wait(0.2)
                    StopLock()
                    task.wait(0.3)
                    Step8c_CheckDistanceAndRecover()
                end)
            end)
        end)
    end)
end

-- ==================================================
-- ✅ STEP 8c: Check Distance (500m) → Recover/Repeat
-- ==================================================
function Step8c_CheckDistanceAndRecover()
    if not State.Running then return end
    State.Step = "8c_check_distance"

    local TargetPos
    if Container:FindFirstChild(State.TargetUid) then
        TargetPos = GetPosition(Container:FindFirstChild(State.TargetUid))
    elseif workspace:FindFirstChild(State.TargetUid) then
        TargetPos = GetPosition(workspace:FindFirstChild(State.TargetUid))
    end

    if not TargetPos then
        State.IsRecoverMode = true
        Step8b_WalkToCollectAgain()
        return
    end

    local Hum, Root = GetHumanoid()
    if not Root then AutoStop() return end

    local Dist = (Root.Position - TargetPos).Magnitude
    if Dist < Config.RecoverDistanceThreshold then
        State.IsRecoverMode = true
        Step8b_WalkToCollectAgain()
    else
        State.RepeatCount = State.RepeatCount + 1
        if State.RepeatCount >= Config.MaxRepeatCount then AutoStop() return end
        task.wait(0.5)
        Step1_WalkToFirstEgg()
    end
end

-- ==================================================
-- ✅ STEP 8b: Fly TP + Lock ពីលើ Egg Drop → Collect Again
-- ==================================================
function Step8b_WalkToCollectAgain()
    if not State.Running then return end
    State.Step = "8b_to_collect_again"

    local TargetPos
    if Container:FindFirstChild(State.TargetUid) then
        TargetPos = GetPosition(Container:FindFirstChild(State.TargetUid))
    elseif workspace:FindFirstChild(State.TargetUid) then
        TargetPos = GetPosition(workspace:FindFirstChild(State.TargetUid))
    end
    if not TargetPos then Step9_WalkToSwapPosition() return end

    FlyTPAndLock(TargetPos, Config.FlyOffset, function()
        State.Step = "8b_collect_again"
        State.CollectedAgain = false
        State.CurrentEggUid = State.TargetUid
        task.spawn(function()
            while State.Running and State.Step == "8b_collect_again" do
                task.wait(Config.CollectInterval)
                RemoteCollectTarget()
            end
        end)
    end)
end

-- ==================================================
-- ✅ STEP 9: Walk TP → Swap Top
-- ==================================================
function Step9_WalkToSwapPosition()
    if not State.Running then return end
    State.Step = "9_to_swap"

    local SafeName = State.SafeName or "P1_Top1"
    local WalkPos = Config.Position1_Top2
    local WalkName = "P1_Top2"

    if SafeName == "P1_Top1" then
        WalkPos = Config.Position1_Top2
        WalkName = "P1_Top2"
    elseif SafeName == "P2_Top1" then
        WalkPos = Config.Position2_Top2
        WalkName = "P2_Top2"
    end

    print("[TeleportSystem] Step 9: SafeName=" .. SafeName .. " → Walk → " .. WalkName)

    WalkTP(WalkPos, false, false, false, function()
        State.Step = "10_done"
        task.wait(0.2)
        AutoStop()
    end)
end

-- ==================================================
-- PUBLIC API
-- ==================================================
local TeleportSystem = {}

function TeleportSystem.Enable()
    if State.Running then return end
    if not CollectEvent then warn("[TeleportSystem] CollectEvent not found") return end
    if not State.TargetUid then warn("[TeleportSystem] No Target ID") return end

    State.Running = true
    State.Step = "idle"
    State.FirstCollected = false
    State.TargetCollected = false
    State.CollectedAgain = false
    State.DropDone = false
    State.CollectAttempts = 0
    State.FirstDropDone = false
    State.RepeatCount = 0
    State.IsRecoverMode = false
    State.SafePosition = nil
    State.SafeName = nil
    State.CurrentEggUid = nil
    State.SavedWalkSpeed = nil

    -- ✅ Find First Egg
    local FirstEggUid = nil
    local FirstEggSlotKey = nil
    for _, child in ipairs(Container:GetChildren()) do
        if string.find(child.Name, "FirstAreaEgg") then
            FirstEggUid = child.Name
            local SlotNum = string.match(child.Name, "Slot_(%d+)")
            if SlotNum then FirstEggSlotKey = "Forest:Slot_" .. SlotNum end
            break
        end
    end

    if not FirstEggUid or not FirstEggSlotKey then
        warn("[TeleportSystem] First Egg not found!")
        State.Running = false
        return
    end

    State.FirstEggUid = FirstEggUid
    State.FirstEggSlotKey = FirstEggSlotKey
    State.TargetUid = State.SelectedEgg and State.SelectedEgg.Id

    SavePlayerWalkSpeed()
    SetupDropHeldEgg()
    StartEggGoneCheck()

    print("[TeleportSystem] ========== START ==========")
    print("[TeleportSystem] First Egg UID:", FirstEggUid)
    print("[TeleportSystem] First Egg SlotKey:", FirstEggSlotKey)
    print("[TeleportSystem] Target UID:", State.TargetUid)

    task.spawn(function()
        task.wait(0.3)
        Step1_WalkToFirstEgg()
    end)
end

function TeleportSystem.Disable()
    AutoStop()
    print("[TeleportSystem] OFF")
end

function TeleportSystem.SetTargetId(Id)
    State.TargetUid = Id
    print("[TeleportSystem] Target ID: " .. tostring(Id))
end

function TeleportSystem.SetSpeed(Value)
    Value = math.clamp(Value, 50, 1000)
    Config.WalkSpeed = Value
    print("[TeleportSystem] WalkSpeed: " .. tostring(Value))
end

function TeleportSystem.SetMethod(Method)
    print("[TeleportSystem] Method: WalkTP (Only)")
end

function TeleportSystem.GetMethod() return "WalkTP" end
function TeleportSystem.GetSpeed() return Config.WalkSpeed end
function TeleportSystem.IsEnabled() return State.Running end
function TeleportSystem.GetTargetId() return State.TargetUid end

_G.YOKUDO_TeleportSystem = TeleportSystem

print("✅ TeleportSystem v22 Loaded (Teleport New | Push Up Instant | AutoStop Egg Gone)")
