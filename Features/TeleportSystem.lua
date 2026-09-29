-- ==================================================
-- YOKUDO HUB | TELEPORT SYSTEM (WALK + SHOT + LOCK + DROP)
-- ✅ Walk TP: Humanoid:MoveTo() + Safe Speed Mode
-- ✅ ជិតដល់ 30m → Pause Safe Speed Mode
-- ✅ ជិតដល់ 20m → CFrame Instant + Lock + Collect
-- ✅ DropHeldEgg = true (Signal) → Lock Camera → Shot TP → Position 1 (1.2s)
-- ✅ Lock Position 1 → Drop → Unlock Camera → Resume Safe Speed
-- ✅ Walk TP → Collect វិញ → DropHeldEgg = true → Walk TP → Position 2
-- ✅ Position 2 → AutoStop → Callback FarmingManager
-- ✅ ប្រើសម្រាប់ទាំង Tab Auto Farming + Tab Farming
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
    SafeSpeed = 265,
    ShotTPTime = 1.2,
    ArriveDistance = 2,
    LockWait = 0.1,
    NearDistance = 20,
    SlowDistance = 30,
    LockDistance = 1,

    Position1 = Vector3.new(598, 70, -330),
    Position2 = Vector3.new(544, 70, -301),

    WalkTimeout = 30,
    CollectInterval = 0.02,
    MaxCollectAttempts = 10000,
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
    TargetUid = nil,

    WalkConnection = nil,
    ShotConnection = nil,
    LockConnection = nil,

    DropHeldEgg = nil,
    DropHeldEggConnection = nil,

    TargetCollected = false,
    CollectedAgain = false,
    DropDone = false,
    CollectAttempts = 0,

    SavedWalkSpeed = nil,
    SafeSpeedMode = false,
    SafeSpeedPaused = false,

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

-- ==================================================
-- ✅ SAVE STATS
-- ==================================================
local function SaveStats()
    local Hum = GetHumanoid()
    if not Hum then return end
    if State.SavedWalkSpeed == nil then
        State.SavedWalkSpeed = Hum.WalkSpeed
        print("[TeleportSystem] ✅ Saved WalkSpeed ដើម:", State.SavedWalkSpeed)
    end
end

-- ==================================================
-- ✅ GET WALK SPEED (Safe Mode / ដើម)
-- ==================================================
local function GetWalkSpeed()
    if State.SafeSpeedMode and not State.SafeSpeedPaused then
        return Config.SafeSpeed
    end

    if State.SavedWalkSpeed ~= nil then
        return State.SavedWalkSpeed
    end

    local Hum = GetHumanoid()
    if Hum then
        State.SavedWalkSpeed = Hum.WalkSpeed
        print("[TeleportSystem] ✅ Auto-Save WalkSpeed ដើម:", State.SavedWalkSpeed)
        return Hum.WalkSpeed
    end

    return 16
end

-- ==================================================
-- ✅ SAFE SPEED PAUSE / RESUME
-- ==================================================
local function PauseSafeSpeed()
    if not State.SafeSpeedMode then return end
    if State.SafeSpeedPaused then return end

    State.SafeSpeedPaused = true

    local Hum = GetHumanoid()
    if Hum then
        Hum.WalkSpeed = State.SavedWalkSpeed or 16
    end

    print("[TeleportSystem] ⏸️ Safe Speed PAUSED | Speed:", Hum and Hum.WalkSpeed or "nil")
end

local function ResumeSafeSpeed()
    if not State.SafeSpeedMode then return end
    if not State.SafeSpeedPaused then return end

    State.SafeSpeedPaused = false

    local Hum = GetHumanoid()
    if Hum then
        Hum.WalkSpeed = Config.SafeSpeed
    end

    print("[TeleportSystem] ▶️ Safe Speed RESUMED | Speed:", Config.SafeSpeed)
end

-- ==================================================
-- ✅ CAMERA LOCK
-- ==================================================
local function LockCamera()
    local Camera = workspace.CurrentCamera
    if not Camera then return end

    State.LockedCameraCFrame = Camera.CFrame

    if State.CameraLockConnection then
        State.CameraLockConnection:Disconnect()
        State.CameraLockConnection = nil
    end

    State.CameraLockConnection = RunService.RenderStepped:Connect(function()
        if not State.LockedCameraCFrame then return end
        local Cam = workspace.CurrentCamera
        if Cam then
            Cam.CFrame = State.LockedCameraCFrame
            Cam.Focus = State.LockedCameraCFrame
        end
    end)

    print("[TeleportSystem] 🔒 Camera Locked")
end

local function UnlockCamera()
    if State.CameraLockConnection then
        State.CameraLockConnection:Disconnect()
        State.CameraLockConnection = nil
    end
    State.LockedCameraCFrame = nil

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
-- ✅ SHOT TP (1.2s)
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

    print(string.format("[TeleportSystem] Shot TP → %s | Time: 1.2s", tostring(Destination)))

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
-- ✅ WALK TP
-- ==================================================
local function WalkTP(Destination, LockAfterArrive, Callback)
    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then
        if Callback then Callback() end
        return
    end

    SaveStats()
    ResumeSafeSpeed()

    Hum.WalkSpeed = GetWalkSpeed()

    local StartTime = tick()
    local LastCheck = 0
    local ShotDone = false
    local SlowDone = false

    State.WalkConnection = RunService.Heartbeat:Connect(function()
        if not State.Running then CleanupMovers() return end

        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 or Hum2.Health <= 0 then CleanupMovers() return end

        Hum2.WalkSpeed = GetWalkSpeed()

        local Dist = (Root2.Position - Destination).Magnitude

        -- ✅ ជិតដល់ 30m → Stop Safe Speed
        if not SlowDone and Dist <= Config.SlowDistance then
            SlowDone = true
            PauseSafeSpeed()
            Hum2.WalkSpeed = GetWalkSpeed()
        end

        -- ✅ ជិតដល់ 20m → CFrame Instant + Lock
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
-- ✅ DROPHELDEGG (Signal Listener — Disconnect ចាស់ជានិច្ច)
-- ==================================================
local function SetupDropHeldEgg()
    local PG = Player:FindFirstChild("PlayerGui") or Player:WaitForChild("PlayerGui", 5)
    if not PG then return end

    State.DropHeldEgg = PG:FindFirstChild("DropHeldEgg")
    if not State.DropHeldEgg then warn("[TeleportSystem] DropHeldEgg not found!") return end

    -- ✅ Disconnect Signal ចាស់ជានិច្ច
    if State.DropHeldEggConnection then
        State.DropHeldEggConnection:Disconnect()
        State.DropHeldEggConnection = nil
    end

    -- ✅ Signal Listener ថ្មី
    State.DropHeldEggConnection = State.DropHeldEgg:GetPropertyChangedSignal("Enabled"):Connect(function()
        local IsEnabled = State.DropHeldEgg.Enabled == true
        print("[TeleportSystem] ⚡ DropHeldEgg.Enabled →", IsEnabled, "| Step:", State.Step)

        -- ✅ Step 2 (Collect Target) → Shot TP Position 1
        if IsEnabled and State.Running and State.Step == "2_collect_target" then
            print("[TeleportSystem] ✅ DETECTED TRUE → Shot TP Position 1")

            State.TargetCollected = true
            StopLock()

            task.spawn(function()
                task.wait(0.02)
                Step3_ShotToPosition1()
            end)
        end

        -- ✅ Step 6 (Collect Again) → Walk TP Position 2
        if IsEnabled and State.Running and State.Step == "6_collect_again" then
            print("[TeleportSystem] ✅ Step 6 DETECTED TRUE → Walk TP Position 2")

            State.CollectedAgain = true
            StopLock()

            task.spawn(function()
                task.wait(0.2)
                Step7_WalkToPosition2()
            end)
        end
    end)

    print("[TeleportSystem] ✅ DropHeldEgg Signal Listener Setup")
end

local function IsTargetCollected()
    if State.DropHeldEgg then return State.DropHeldEgg.Enabled == true end
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
-- ✅ AUTO STOP (Callback → FarmingManager)
-- ==================================================
local function AutoStop()
    StopLock()
    CleanupMovers()
    UnlockCamera()
    ResumeSafeSpeed()

    local Char = Player.Character
    if Char then
        local Hum = Char:FindFirstChildOfClass("Humanoid")
        if Hum then
            if State.SavedWalkSpeed ~= nil then
                Hum.WalkSpeed = State.SavedWalkSpeed
            elseif not State.SafeSpeedMode then
                Hum.WalkSpeed = 16
            else
                Hum.WalkSpeed = Config.SafeSpeed
            end
            print("[TeleportSystem] ✅ WalkSpeed Reset:", Hum.WalkSpeed)
        end
    end

    State.Running = false
    State.Step = "done"
    State.TargetCollected = false
    State.CollectedAgain = false
    State.DropDone = false
    State.CollectAttempts = 0

    print("[TeleportSystem] Auto Stop → Callback")

    task.spawn(function()
        task.wait(0.2)
        if _G.YOKUDO_FarmingManager then
            if type(_G.YOKUDO_FarmingManager.OnVIPTPComplete) == "function" then
                local Success, Err = pcall(function()
                    _G.YOKUDO_FarmingManager.OnVIPTPComplete()
                end)
                if not Success then
                    warn("[TeleportSystem] OnVIPTPComplete Error:", Err)
                end
            elseif type(_G.YOKUDO_FarmingManager.OnTeleportComplete) == "function" then
                local Success, Err = pcall(function()
                    _G.YOKUDO_FarmingManager.OnTeleportComplete()
                end)
                if not Success then
                    warn("[TeleportSystem] OnTeleportComplete Error:", Err)
                end
            end
        end
    end)
end

-- ==================================================
-- ✅ STEP 1: Walk → Target → Collect
-- ==================================================
local function Step1_WalkToTarget()
    State.Step = "1_to_target"
    State.TargetCollected = false
    State.CollectAttempts = 0

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

        print("[TeleportSystem] ✅ Step 2: collect_target | Signal:", 
              State.DropHeldEggConnection ~= nil and "Connected" or "NOT Connected")

        task.spawn(function()
            while State.Running and State.Step == "2_collect_target" do
                task.wait(Config.CollectInterval)
                RemoteCollectTarget()
                State.CollectAttempts = State.CollectAttempts + 1
                if State.CollectAttempts > Config.MaxCollectAttempts then
                    print("[TeleportSystem] Max Collect → AutoStop")
                    AutoStop()
                    return
                end
            end
        end)
    end)
end

-- ==================================================
-- ✅ STEP 3: Lock Camera → Shot TP → Position 1 (1.2s)
-- ==================================================
function Step3_ShotToPosition1()
    if not State.Running then return end

    State.Step = "3_to_position1"
    StopLock()
    LockCamera()

    local Hum = GetHumanoid()
    if Hum then
        Hum.WalkSpeed = GetWalkSpeed()
    end

    print("[TeleportSystem] Step 3: Lock Camera → Shot TP → Position 1 (1.2s)")

    ShotTP(Config.Position1, function()
        print("[TeleportSystem] Step 3 Done: At Position 1 → Lock + Drop")
        Step4_LockAndDrop()
    end)
end

-- ==================================================
-- ✅ STEP 4: Lock Position 1 → Drop → Unlock → Walk Collect វិញ
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

        UnlockCamera()
        ResumeSafeSpeed()

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
            end
        end)
    end)
end

-- ==================================================
-- ✅ STEP 7: Walk → Position 2 → Stop → Callback
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
-- ✅ START PROCESS (Reset + Setup + Start)
-- ==================================================
local function StartProcess()
    -- ✅ Reset ទាំងអស់មុន
    if State.DropHeldEggConnection then
        State.DropHeldEggConnection:Disconnect()
        State.DropHeldEggConnection = nil
    end
    State.DropHeldEgg = nil

    State.Running = true
    State.Step = "idle"
    State.TargetCollected = false
    State.CollectedAgain = false
    State.DropDone = false
    State.CollectAttempts = 0

    -- ✅ SetupDropHeldEgg ថ្មី
    SetupDropHeldEgg()
    SaveStats()

    print("[TeleportSystem] ========== START ==========")
    print("[TeleportSystem] Target UID:", State.TargetUid)
    print("[TeleportSystem] Signal:", State.DropHeldEggConnection ~= nil and "Connected" or "NOT Connected")

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
    UnlockCamera()
    ResumeSafeSpeed()

    local Hum = GetHumanoid()
    if Hum and State.SavedWalkSpeed ~= nil then
        pcall(function() Hum.WalkSpeed = State.SavedWalkSpeed end)
    end

    -- ✅ Disconnect Signal ចាស់
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
    State.CollectAttempts = 0
    State.SafeSpeedPaused = false

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

    -- ✅ FullReset មុន
    FullReset()

    -- ✅ Setup DropHeldEgg មុន StartProcess
    SetupDropHeldEgg()

    -- ✅ StartProcess
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

function TeleportSystem.SetSafeSpeedMode(Enabled)
    State.SafeSpeedMode = Enabled == true

    local Hum = GetHumanoid()
    if Hum and State.SavedWalkSpeed == nil then
        State.SavedWalkSpeed = Hum.WalkSpeed
    end

    State.SafeSpeedPaused = false

    if Hum then
        Hum.WalkSpeed = GetWalkSpeed()
    end

    print("[TeleportSystem] Safe Speed Mode:", State.SafeSpeedMode, "| Speed:", GetWalkSpeed())
end

function TeleportSystem.GetSafeSpeedMode()
    return State.SafeSpeedMode
end

function TeleportSystem.GetCurrentSpeed()
    return GetWalkSpeed()
end

function TeleportSystem.IsEnabled() return State.Running end
function TeleportSystem.GetTargetId() return State.TargetUid end

-- Export
_G.YOKUDO_TeleportSystem = TeleportSystem

print("✅ TeleportSystem Loaded (Walk + Shot 1.2s + Lock + Drop + Position 2 + Callback)")
