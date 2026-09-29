-- ==================================================
-- YOKUDO HUB | TELEPORT SYSTEM (WALK + CFrame Instant + SHOT TP + LOCK + DROP)
-- ✅ Walk TP: Humanoid:MoveTo() + WalkSpeed 265
-- ✅ ជិតដល់ 20 studs → CFrame Instant + Lock + Collect
-- ✅ DropHeldEgg = true → Lock Camera + Shot TP → Position 1 (1.15s)
-- ✅ Lock Position 1 → Drop → Unlock Camera
-- ✅ Walk TP → Collect វិញ → Position 2 → Stop
-- ✅ Reset WalkSpeed ពេល Stop
-- ✅ សម្រាប់ Tab Auto Farming (AutoFarm.lua)
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Container = workspace:WaitForChild("AreaEggSlotsClient")

-- ==================================================
-- CONFIG
-- ==================================================
local Config = {
    WalkSpeed = 265,
    ShotTPTime = 1.15,
    ArriveDistance = 2,
    LockWait = 0.1,
    NearDistance = 20,
    LockDistance = 1,

    Position1 = Vector3.new(598, 70, -330),
    Position2 = Vector3.new(544, 70, -301),

    WalkTimeout = 30,
    CollectInterval = 0.02,
    TargetCollectTimeout = 10,
}

-- ==================================================
-- REMOTES
-- ==================================================
local CollectEvent = ReplicatedStorage.Packages.Networking:FindFirstChild("RF/EggWorld/AskFieldEggCarry")
local DropEvent = ReplicatedStorage.Packages.Networking:FindFirstChild("RF/EggWorld/AskFieldEggDrop")

if not CollectEvent then
    warn("[TeleportSystem] CollectEvent not found")
    return
end

if not DropEvent then
    warn("[TeleportSystem] DropEvent not found")
    return
end

print("[TeleportSystem] CollectEvent + DropEvent OK")

-- ==================================================
-- STATE
-- ==================================================
local State = {
    Running = false,
    Step = "idle",
    Method = "TeleportFly",
    TargetUid = nil,

    WalkConnection = nil,
    ShotConnection = nil,
    LockConnection = nil,

    DropHeldEgg = nil,
    DropHeldEggConnection = nil,

    TargetCollected = false,
    CollectedAgain = false,
    DropDone = false,

    SavedWalkSpeed = nil,

    -- ✅ Camera Lock State
    CameraLockConnection = nil,
    LockedCameraCFrame = nil,
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
    if State.SavedWalkSpeed == nil then
        State.SavedWalkSpeed = Hum.WalkSpeed
    end
end

local function RestoreStats()
    local Hum = GetHumanoid()
    if not Hum then return end
    if State.SavedWalkSpeed ~= nil then
        pcall(function()
            Hum.WalkSpeed = State.SavedWalkSpeed
        end)
    end
end

-- ==================================================
-- ✅ CAMERA LOCK (នៅ Position បច្ចុប្បន្ន)
-- ==================================================
local function LockCamera()
    local Camera = workspace.CurrentCamera
    if not Camera then return end

    -- ✅ Save Camera CFrame
    State.LockedCameraCFrame = Camera.CFrame

    -- ✅ Lock Camera រាល់ RenderStepped
    if State.CameraLockConnection then
        State.CameraLockConnection:Disconnect()
        State.CameraLockConnection = nil
    end

    State.CameraLockConnection = RunService.RenderStepped:Connect(function()
        if not State.LockedCameraCFrame then return end

        local Cam = workspace.CurrentCamera
        if Cam then
            Cam.CFrame = State.LockedCameraCFrame
        end
    end)

    print("[TeleportSystem] 🔒 Camera Locked:", State.LockedCameraCFrame.Position)
end

local function UnlockCamera()
    if State.CameraLockConnection then
        State.CameraLockConnection:Disconnect()
        State.CameraLockConnection = nil
    end
    State.LockedCameraCFrame = nil

    -- ✅ Reset CameraSubject
    local Camera = workspace.CurrentCamera
    if Camera then
        local Char = Player.Character
        if Char then
            local Hum = Char:FindFirstChildOfClass("Humanoid")
            if Hum then
                Camera.CameraSubject = Hum
            end
        end
    end

    print("[TeleportSystem] 🔓 Camera Unlocked")
end

-- ==================================================
-- CLEANUP
-- ==================================================
local function CleanupMovers()
    if State.WalkConnection then State.WalkConnection:Disconnect() State.WalkConnection = nil end
    if State.ShotConnection then State.ShotConnection:Disconnect() State.ShotConnection = nil end
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

-- ==================================================
-- ✅ LOCK
-- ==================================================
local function StartLock(TargetPos)
    if State.LockConnection then State.LockConnection:Disconnect() State.LockConnection = nil end

    local LockedCFrame = CFrame.new(TargetPos + Vector3.new(0, Config.LockDistance, 0))

    print("[TeleportSystem] 🔒 Lock at:", TargetPos)

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
-- ✅ CFrame Instant
-- ==================================================
local function CFrameInstant(Destination, Callback)
    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then
        if Callback then Callback() end
        return
    end

    Hum:MoveTo(Root.Position)
    Hum.WalkSpeed = 0

    local TargetCFrame = CFrame.new(Destination)
    Root.CFrame = TargetCFrame
    Root.AssemblyLinearVelocity = Vector3.zero
    Root.AssemblyAngularVelocity = Vector3.zero

    print("[TeleportSystem] ⚡ CFrame Instant →", Destination)

    task.wait(0.02)

    if Callback then Callback() end
end

-- ==================================================
-- ✅ SHOT TP (1.15s — សម្រាប់ Position 1)
-- ==================================================
local function ShotTP(Destination, Callback)
    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then
        if Callback then Callback() end
        return
    end

    local TargetCFrame = CFrame.new(Destination)
    local StartPos = Root.Position
    local StartTime = tick()

    Hum.PlatformStand = true

    print(string.format("[TeleportSystem] Shot TP → %s | Time: 1.15s", tostring(Destination)))

    State.ShotConnection = RunService.Heartbeat:Connect(function()
        if not State.Running then CleanupMovers() return end

        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 or Hum2.Health <= 0 then CleanupMovers() return end

        local Elapsed = tick() - StartTime
        local Alpha = math.clamp(Elapsed / Config.ShotTPTime, 0, 1)

        local NewPos = StartPos:Lerp(Destination, Alpha)

        Root2.CFrame = CFrame.new(NewPos)
        Root2.AssemblyLinearVelocity = Vector3.zero
        Root2.AssemblyAngularVelocity = Vector3.zero

        local Dist = (Root2.Position - Destination).Magnitude
        if Dist <= Config.ArriveDistance or Alpha >= 1 then
            CleanupMovers()
            Root2.CFrame = TargetCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero

            print(string.format("[TeleportSystem] ✅ Shot TP Arrived | Dist: %.1f", Dist))
            if Callback then Callback() end
        end
    end)
end

-- ==================================================
-- ✅ WALK TP (ជិតដល់ 20 studs → CFrame Instant + Lock — មិន Reset WalkSpeed)
-- ==================================================
local function WalkTP(Destination, LockAfterArrive, Callback)
    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then
        if Callback then Callback() end
        return
    end

    Hum.WalkSpeed = Config.WalkSpeed

    local StartTime = tick()
    local LastCheck = 0
    local ShotDone = false

    State.WalkConnection = RunService.Heartbeat:Connect(function()
        if not State.Running then CleanupMovers() return end

        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 or Hum2.Health <= 0 then CleanupMovers() return end

        Hum2.WalkSpeed = Config.WalkSpeed

        local Dist = (Root2.Position - Destination).Magnitude

        -- ✅ ជិតដល់ 20 studs → CFrame Instant ភ្លាម
        if not ShotDone and Dist <= Config.NearDistance then
            ShotDone = true

            State.WalkConnection:Disconnect()
            State.WalkConnection = nil
            Hum2:MoveTo(Root2.Position)
            Hum2.WalkSpeed = 0

            print(string.format("[TeleportSystem] ⚡ ជិតដល់ %.0f studs → CFrame Instant + Lock", Dist))

            CFrameInstant(Destination, function()
                if LockAfterArrive then
                    StartLock(Destination)
                end
                if Callback then Callback() end
            end)
            return
        end

        Hum2:MoveTo(Destination)

        if tick() - LastCheck > 0.05 then
            LastCheck = tick()

            if Dist <= Config.ArriveDistance then
                CleanupMovers()
                Hum2:MoveTo(Root2.Position)
                Hum2.WalkSpeed = 0

                if LockAfterArrive then
                    StartLock(Destination)
                end

                if Callback then Callback() end
                return
            end

            if tick() - StartTime > Config.WalkTimeout then
                CleanupMovers()
                if Callback then Callback() end
                return
            end
        end
    end)
end

-- ==================================================
-- REMOTES
-- ==================================================
local function RemoteCollectTarget()
    if not CollectEvent or not State.TargetUid then return false end
    local success = pcall(function()
        return CollectEvent:InvokeServer({ Uid = State.TargetUid })
    end)
    return success
end

local function RemoteDrop()
    if not DropEvent then return false end
    local Success, Result = pcall(function()
        return DropEvent:InvokeServer({ Reason = "PlayerRequest" })
    end)
    return Success and Result
end

-- ==================================================
-- DROPHELDEGG
-- ==================================================
local function SetupDropHeldEgg()
    local PG = Player:FindFirstChild("PlayerGui") or Player:WaitForChild("PlayerGui", 5)
    if not PG then return end

    State.DropHeldEgg = PG:FindFirstChild("DropHeldEgg")
    if not State.DropHeldEgg then warn("[TeleportSystem] DropHeldEgg not found!") return end

    if State.DropHeldEggConnection then State.DropHeldEggConnection:Disconnect() end
    State.DropHeldEggConnection = State.DropHeldEgg:GetPropertyChangedSignal("Enabled"):Connect(function()
        print("[TeleportSystem] DropHeldEgg.Enabled:", State.DropHeldEgg.Enabled)
    end)
end

local function IsTargetCollected()
    if State.DropHeldEgg then return State.DropHeldEgg.Enabled == true end
    local PG = Player:FindFirstChild("PlayerGui")
    if PG then
        local Egg = PG:FindFirstChild("DropHeldEgg")
        if Egg then
            State.DropHeldEgg = Egg
            return Egg.Enabled == true
        end
    end
    return false
end

local function IsTargetInContainer()
    return State.TargetUid and Container and Container:FindFirstChild(State.TargetUid) ~= nil
end

local function IsTargetInWorkspace()
    return State.TargetUid and workspace:FindFirstChild(State.TargetUid) ~= nil
end

local function GetTargetPosition()
    if IsTargetInContainer() then
        local Egg = Container:FindFirstChild(State.TargetUid)
        if Egg then return GetPosition(Egg) end
    elseif IsTargetInWorkspace() then
        local Egg = workspace:FindFirstChild(State.TargetUid)
        if Egg then return GetPosition(Egg) end
    end
    return nil
end

-- ==================================================
-- ✅ AUTO STOP (Reset WalkSpeed + Unlock Camera)
-- ==================================================
local function AutoStop()
    StopLock()
    CleanupMovers()
    UnlockCamera()  -- ✅ Unlock Camera

    -- ✅ Reset WalkSpeed ភ្លាម
    local Char = Player.Character
    if Char then
        local Hum = Char:FindFirstChildOfClass("Humanoid")
        if Hum then
            Hum.WalkSpeed = State.SavedWalkSpeed or Config.WalkSpeed
            print("[TeleportSystem] ✅ WalkSpeed Reset:", Hum.WalkSpeed)
        end
    end

    State.Running = false
    State.Step = "done"
    State.TargetCollected = false
    State.CollectedAgain = false
    State.DropDone = false

    print("[TeleportSystem] ✅ Auto Stop")
end

-- ==================================================
-- ✅ STEP 1: Walk → Target → CFrame Instant → Lock → Collect
-- ==================================================
local function Step1_WalkToTarget()
    State.Step = "1_to_target"
    State.TargetCollected = false

    local TargetPos = GetTargetPosition()
    if not TargetPos then AutoStop() return end

    print("[TeleportSystem] Step 1: Walk → Target")

    WalkTP(TargetPos, true, function()
        print("[TeleportSystem] Step 1 Done: At Target + Locked → Collect")

        local NewTargetPos = GetTargetPosition()
        if NewTargetPos then
            StartLock(NewTargetPos)
        end

        State.Step = "2_collect_target"
        State.TargetCollected = false

        task.spawn(function()
            while State.Running and State.Step == "2_collect_target" do
                task.wait(Config.CollectInterval)

                RemoteCollectTarget()

                if IsTargetCollected() then
                    State.TargetCollected = true
                    print("[TeleportSystem] Step 2 Done: Target Collected → Lock Camera + Shot TP Position 1")

                    task.spawn(function()
                        task.wait(0.1)
                        Step3_ShotToPosition1()
                    end)
                    return
                end
            end
        end)
    end)
end

-- ==================================================
-- ✅ STEP 3: Lock Camera + Shot TP → Position 1 (1.15s)
-- ==================================================
function Step3_ShotToPosition1()
    if not State.Running then return end

    State.Step = "3_to_position1"
    StopLock()

    -- ✅ Lock Camera មុន Shot TP
    LockCamera()

    local Hum = GetHumanoid()
    if Hum then
        Hum.WalkSpeed = Config.WalkSpeed
    end

    print("[TeleportSystem] Step 3: Lock Camera + Shot TP → Position 1 (1.15s)")

    ShotTP(Config.Position1, function()
        print("[TeleportSystem] Step 3 Done: At Position 1 → Lock + Drop")
        Step4_LockAndDrop()
    end)
end

-- ==================================================
-- ✅ STEP 4: Lock Position 1 + Drop + Unlock Camera
-- ==================================================
function Step4_LockAndDrop()
    if not State.Running then return end

    State.Step = "4_drop_at_p1"

    print("[TeleportSystem] Step 4: Lock Position 1 + Drop")

    StartLock(Config.Position1)

    task.spawn(function()
        task.wait(Config.LockWait)

        RemoteDrop()
        print("[TeleportSystem] Step 4 Done: Remote Drop")

        State.DropDone = true

        task.wait(0.2)
        StopLock()

        -- ✅ Unlock Camera ពេល Drop រួច
        UnlockCamera()

        task.spawn(function()
            task.wait(0.3)
            Step5_WalkToCollectAgain()
        end)
    end)
end

-- ==================================================
-- ✅ STEP 5: Walk → Collect វិញ
-- ==================================================
function Step5_WalkToCollectAgain()
    if not State.Running then return end

    State.Step = "5_to_collect_again"
    State.CollectedAgain = false

    local TargetPos = GetTargetPosition()
    if not TargetPos then
        print("[TeleportSystem] Target Gone → Position 2")
        Step7_WalkToPosition2()
        return
    end

    print("[TeleportSystem] Step 5: Walk → Collect Again")

    WalkTP(TargetPos, true, function()
        print("[TeleportSystem] Step 5 Done: At Target + Locked → Collect Again")

        local NewTargetPos = GetTargetPosition()
        if NewTargetPos then
            StartLock(NewTargetPos)
        end

        State.Step = "6_collect_again"
        State.CollectedAgain = false

        task.spawn(function()
            while State.Running and State.Step == "6_collect_again" do
                task.wait(Config.CollectInterval)

                RemoteCollectTarget()

                if IsTargetCollected() then
                    State.CollectedAgain = true
                    print("[TeleportSystem] Step 6 Done: Collected Again")

                    StopLock()

                    task.spawn(function()
                        task.wait(0.3)
                        Step7_WalkToPosition2()
                    end)
                    return
                end
            end
        end)
    end)
end

-- ==================================================
-- ✅ STEP 7: Walk → Position 2 → Stop
-- ==================================================
function Step7_WalkToPosition2()
    if not State.Running then return end

    State.Step = "7_to_position2"

    print("[TeleportSystem] Step 7: Walk → Position 2")

    WalkTP(Config.Position2, false, function()
        print("[TeleportSystem] Step 7 Done: At Position 2 → Stop")

        State.Step = "8_done"

        task.wait(0.2)
        AutoStop()
    end)
end

-- ==================================================
-- ✅ START PROCESS
-- ==================================================
local function StartProcess()
    State.Running = true
    State.Step = "idle"
    State.TargetCollected = false
    State.CollectedAgain = false
    State.DropDone = false

    SetupDropHeldEgg()
    SaveStats()

    print("[TeleportSystem] ========== START ==========")
    print("[TeleportSystem] Target UID:", State.TargetUid)

    task.spawn(function()
        task.wait(0.3)
        Step1_WalkToTarget()
    end)
end

-- ==================================================
-- FULL RESET
-- ==================================================
local function FullReset()
    StopLock()
    CleanupMovers()
    UnlockCamera()  -- ✅ Unlock Camera
    RestoreStats()

    if State.DropHeldEggConnection then
        State.DropHeldEggConnection:Disconnect()
        State.DropHeldEggConnection = nil
    end
    State.DropHeldEgg = nil

    State.Running = false
    State.Step = "idle"
    State.TargetCollected = false
    State.CollectedAgain = false
    State.DropDone = false

    print("[TeleportSystem] Full Reset")
end

-- ==================================================
-- PUBLIC API
-- ==================================================
local TeleportSystem = {}

function TeleportSystem.Enable()
    if State.Running then return end
    if not CollectEvent then warn("[TeleportSystem] CollectEvent not found") return end
    if not DropEvent then warn("[TeleportSystem] DropEvent not found") return end
    if not State.TargetUid then warn("[TeleportSystem] No Target ID") return end

    FullReset()
    StartProcess()

    print("[TeleportSystem] ON | Target: " .. tostring(State.TargetUid))
end

function TeleportSystem.Disable()
    FullReset()
    print("[TeleportSystem] OFF")
end

function TeleportSystem.SetTargetId(Id)
    State.TargetUid = Id
    print("[TeleportSystem] Target ID: " .. tostring(Id))
end

function TeleportSystem.SetSpeed(Value)
    Value = math.clamp(Value, 50, 1100)
    Config.WalkSpeed = Value
    print("[TeleportSystem] Walk Speed: " .. tostring(Value))
end

function TeleportSystem.SetMethod(Method)
    State.Method = (Method == "InstantTeleport") and "InstantTeleport" or "TeleportFly"
    print("[TeleportSystem] Method: " .. State.Method)
end

function TeleportSystem.GetMethod() return State.Method end
function TeleportSystem.GetSpeed() return Config.WalkSpeed end
function TeleportSystem.IsEnabled() return State.Running end
function TeleportSystem.GetTargetId() return State.TargetUid end

-- Export
_G.YOKUDO_TeleportSystem = TeleportSystem

print("✅ TeleportSystem Loaded (Camera Lock + Walk 265 + CFrame Instant + Shot TP 1.15s + Drop)")
