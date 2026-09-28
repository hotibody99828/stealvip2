-- ==================================================
-- YOKUDO HUB | FEATURE | VIPTP (AFK Farm Only)
-- ✅ Walk TP: Humanoid:MoveTo() + WalkSpeed 275
-- ✅ Shot TP: Heartbeat Lerp → Position 1 (663, 70, -369)
-- ✅ Lock CFrame → Remote Drop → Walk TP Safe Zone
-- ✅ សម្រាប់ Tab Auto Farming (FarmingManager)
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
    -- Walk Speed
    WalkSpeed = 275,

    -- Shot TP
    ShotTPTime = 1.0,           -- Shot TP ក្នុង 1s
    ArriveDistance = 2,
    LockWait = 0.1,

    -- Positions
    SafeZone = Vector3.new(533, 70, -366),
    Position1 = Vector3.new(663, 70, -369),

    -- Timing
    WalkTimeout = 30,
    CollectInterval = 0.05,
    TargetCollectTimeout = 10,
    MaxRecoveryAttempts = 10000,

    -- Search
    SearchPrefix = "FirstAreaEgg",
    PositionThreshold = 1,
}

-- ==================================================
-- REMOTES
-- ==================================================
local CollectEvent = ReplicatedStorage.Packages.Networking:FindFirstChild("RF/EggWorld/AskFieldEggCarry")
local DropEvent = ReplicatedStorage.Packages.Networking:FindFirstChild("RF/EggWorld/AskFieldEggDrop")

if not CollectEvent then
    warn("[VIPTP] CollectEvent not found")
    return
end

if not DropEvent then
    warn("[VIPTP] DropEvent not found")
    return
end

print("[VIPTP] CollectEvent + DropEvent OK")

-- ==================================================
-- STATE
-- ==================================================
local State = {
    Running = false,
    Step = "idle",
    Mode = "none",
    TargetUid = nil,

    WalkConnection = nil,
    ShotConnection = nil,
    LockConnection = nil,
    ActiveTask = nil,

    SavedTargetPosition = nil,
    TargetLockedCFrame = nil,

    CollectDone = false,
    TargetCollected = false,
    RecoveryTriggered = false,
    RecoveryAttempts = 0,

    CollectAttempts = 0,
    CollectTime = 0,
    TargetCollectStartTime = 0,

    PlayerGui = nil,
    DropHeldEgg = nil,
    DropHeldEggConnection = nil,

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
-- CLEANUP
-- ==================================================
local function CleanupMovers()
    if State.WalkConnection then
        State.WalkConnection:Disconnect()
        State.WalkConnection = nil
    end
    if State.ShotConnection then
        State.ShotConnection:Disconnect()
        State.ShotConnection = nil
    end
    if State.LockConnection then
        State.LockConnection:Disconnect()
        State.LockConnection = nil
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
-- ✅ WALK TP (Humanoid:MoveTo + WalkSpeed 275)
-- ==================================================
local function WalkTP(Destination, Callback)
    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then
        if Callback then Callback() end
        return
    end

    -- ✅ Set WalkSpeed 275
    Hum.WalkSpeed = Config.WalkSpeed

    print(string.format("[VIPTP] Walk TP → %s | Speed: %d", tostring(Destination), Config.WalkSpeed))

    local StartTime = tick()
    local LastCheck = 0

    -- ✅ Loop MoveTo រាល់ Heartbeat (ដើរទៅ Destination)
    State.WalkConnection = RunService.Heartbeat:Connect(function()
        if not State.Running then
            CleanupMovers()
            return
        end

        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 or Hum2.Health <= 0 then
            CleanupMovers()
            return
        end

        -- ✅ Set WalkSpeed រាល់ Heartbeat
        Hum2.WalkSpeed = Config.WalkSpeed

        -- ✅ MoveTo Destination
        Hum2:MoveTo(Destination)

        -- ✅ Check រាល់ 0.05s
        if tick() - LastCheck > 0.05 then
            LastCheck = tick()

            local Dist = (Root2.Position - Destination).Magnitude
            if Dist <= Config.ArriveDistance then
                CleanupMovers()
                Hum2:MoveTo(Root2.Position)  -- ✅ Stop MoveTo
                print(string.format("[VIPTP] ✅ Walk TP Arrived | Dist: %.1f", Dist))
                if Callback then Callback() end
                return
            end

            -- ✅ Timeout
            if tick() - StartTime > Config.WalkTimeout then
                CleanupMovers()
                print("[VIPTP] Walk TP Timeout")
                if Callback then Callback() end
                return
            end
        end
    end)
end

-- ==================================================
-- ✅ SHOT TP (Heartbeat Lerp)
-- ==================================================
local function ShotTP(Destination, Callback)
    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then
        if Callback then Callback() end
        return
    end

    local StartPos = Root.Position
    local StartTime = tick()

    Hum.PlatformStand = true

    print(string.format("[VIPTP] Shot TP → %s | Time: %.1fs", tostring(Destination), Config.ShotTPTime))

    State.ShotConnection = RunService.Heartbeat:Connect(function()
        if not State.Running then
            CleanupMovers()
            return
        end

        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 or Hum2.Health <= 0 then
            CleanupMovers()
            return
        end

        local Elapsed = tick() - StartTime
        local Alpha = math.clamp(Elapsed / Config.ShotTPTime, 0, 1)

        local NewPos = StartPos:Lerp(Destination, Alpha)

        Root2.CFrame = CFrame.new(NewPos)
        Root2.AssemblyLinearVelocity = Vector3.zero
        Root2.AssemblyAngularVelocity = Vector3.zero

        -- ✅ Check Arrived
        local Dist = (Root2.Position - Destination).Magnitude
        if Dist <= Config.ArriveDistance or Alpha >= 1 then
            CleanupMovers()
            Root2.CFrame = CFrame.new(Destination)
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero

            print(string.format("[VIPTP] ✅ Shot TP Arrived | Dist: %.1f", Dist))
            if Callback then Callback() end
        end
    end)
end

-- ==================================================
-- ✅ LOCK CFrame
-- ==================================================
local function StartLock(TargetPos)
    if State.LockConnection then
        State.LockConnection:Disconnect()
        State.LockConnection = nil
    end

    local LockedCFrame = CFrame.new(TargetPos)

    State.LockConnection = RunService.Heartbeat:Connect(function()
        if not State.Running then
            if State.LockConnection then
                State.LockConnection:Disconnect()
                State.LockConnection = nil
            end
            return
        end

        local _, Root = GetHumanoid()
        if not Root then return end

        Root.CFrame = LockedCFrame
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end)

    print("[VIPTP] 🔒 Lock CFrame at:", TargetPos)
end

-- ==================================================
-- REMOTES
-- ==================================================
local function RemoteCollectTarget()
    if not CollectEvent or not State.TargetUid then return false end

    print("[VIPTP] Remote Collect:", State.TargetUid)

    local success = pcall(function()
        return CollectEvent:InvokeServer({ Uid = State.TargetUid })
    end)
    return success
end

local function RemoteDrop()
    if not DropEvent then return false end

    print("[VIPTP] Remote Drop")

    local Success, Result = pcall(function()
        return DropEvent:InvokeServer({ Reason = "PlayerRequest" })
    end)

    print("[VIPTP] Drop Result:", Success, Result)
    return Success and Result
end

-- ==================================================
-- DROPHELDEGG
-- ==================================================
local function SetupDropHeldEgg()
    State.PlayerGui = Player:FindFirstChild("PlayerGui") or Player:WaitForChild("PlayerGui", 5)
    if not State.PlayerGui then return end

    State.DropHeldEgg = State.PlayerGui:FindFirstChild("DropHeldEgg")
    if not State.DropHeldEgg then warn("[VIPTP] DropHeldEgg not found!") return end

    if State.DropHeldEggConnection then State.DropHeldEggConnection:Disconnect() end
    State.DropHeldEggConnection = State.DropHeldEgg:GetPropertyChangedSignal("Enabled"):Connect(function()
        print("[VIPTP] DropHeldEgg.Enabled:", State.DropHeldEgg.Enabled)
    end)
end

local function IsTargetCollected()
    if State.DropHeldEgg then
        return State.DropHeldEgg.Enabled == true
    end
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

-- ==================================================
-- CHECK HELPERS
-- ==================================================
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

    if State.ActiveTask then
        pcall(function() task.cancel(State.ActiveTask) end)
        State.ActiveTask = nil
    end

    CleanupMovers()
    RestoreStats()

    State.Running = false
    State.Step = "done"

    State.CollectAttempts = 0
    State.CollectTime = 0
    State.TargetCollectStartTime = 0
    State.CollectDone = false
    State.TargetCollected = false
    State.RecoveryTriggered = false
    State.RecoveryAttempts = 0
    State.SavedTargetPosition = nil

    print("[VIPTP] Auto Stop → Callback FarmingManager")

    task.spawn(function()
        task.wait(0.2)
        if _G.YOKUDO_FarmingManager then
            if type(_G.YOKUDO_FarmingManager.OnVIPTPComplete) == "function" then
                local Success, Err = pcall(function()
                    _G.YOKUDO_FarmingManager.OnVIPTPComplete()
                end)
                if not Success then
                    warn("[VIPTP] OnVIPTPComplete Error:", Err)
                end
            end
        end
    end)
end

-- ==================================================
-- RECOVERY (Walk TP ទៅ Egg Drop)
-- ==================================================
local function FlyToTargetAgain()
    State.RecoveryAttempts = State.RecoveryAttempts + 1
    if State.RecoveryAttempts > Config.MaxRecoveryAttempts then
        print("[VIPTP] Max Recovery → AutoStop")
        AutoStop()
        return
    end

    print("[VIPTP] Recovery #" .. State.RecoveryAttempts)
    State.Step = "recovery"

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
        print("[VIPTP] Target Gone → AutoStop")
        AutoStop()
        return
    end

    if not TargetPos then AutoStop() return end

    State.RecoveryTriggered = false
    State.TargetCollected = false

    -- ✅ Walk TP ទៅ Egg Drop
    WalkTP(TargetPos, function()
        print("[VIPTP] ✅ Recovery #" .. State.RecoveryAttempts .. " Arrived")

        State.TargetCollected = false
        State.CollectTime = 0
        State.CollectAttempts = 0
        State.RecoveryTriggered = false
        State.TargetCollectStartTime = tick()
        State.Step = "collect_target"
    end)
end

-- ==================================================
-- WALK TP SAFE ZONE
-- ==================================================
local function FlyToSafeZone()
    State.Step = "to_safe"
    State.RecoveryTriggered = false
    State.TargetCollected = false

    print("[VIPTP] Walk TP to Safe Zone")

    WalkTP(Config.SafeZone, function()
        print("[VIPTP] ✅ Arrived Safe Zone → AutoStop")
        AutoStop()
    end)
end

-- ==================================================
-- ACTIVE TASK
-- ==================================================
local function StartActiveTask()
    if State.ActiveTask then
        pcall(function() task.cancel(State.ActiveTask) end)
        State.ActiveTask = nil
    end

    State.ActiveTask = task.spawn(function()
        while State.Running do
            task.wait(0.05)

            local Hum, Root = GetHumanoid()
            if not Hum or not Root or Hum.Health <= 0 then break end

            -- Step 1: Collect Target
            if State.Step == "collect_target" and not State.TargetCollected then
                if IsTargetCollected() then
                    print("[VIPTP] ✅ Target Collected (DropHeldEgg = true) → Shot TP Position 1")
                    State.TargetCollected = true
                    State.RecoveryTriggered = false

                    -- ✅ Shot TP → Position 1
                    ShotTP(Config.Position1, function()
                        print("[VIPTP] ✅ Shot TP Arrived Position 1 → Lock")

                        -- ✅ Lock CFrame នៅ Position 1
                        StartLock(Config.Position1)

                        -- ✅ Remote Drop
                        task.spawn(function()
                            task.wait(Config.LockWait)
                            RemoteDrop()
                            print("[VIPTP] ✅ Remote Drop Done")

                            -- ✅ Stop Lock
                            if State.LockConnection then
                                State.LockConnection:Disconnect()
                                State.LockConnection = nil
                            end

                            -- ✅ Walk TP ទៅ Safe Zone
                            task.spawn(function()
                                task.wait(0.2)
                                FlyToSafeZone()
                            end)
                        end)
                    end)
                else
                    -- ✅ Remote Collect រាល់ 0.05s
                    if tick() - State.CollectTime > Config.CollectInterval then
                        State.CollectTime = tick()
                        RemoteCollectTarget()
                        State.CollectAttempts = State.CollectAttempts + 1
                    end

                    -- ✅ Timeout → Recovery
                    if tick() - State.TargetCollectStartTime > Config.TargetCollectTimeout then
                        print("[VIPTP] Target Timeout → Recovery")
                        if not State.RecoveryTriggered then
                            State.RecoveryTriggered = true
                            task.spawn(function() task.wait(0.05) FlyToTargetAgain() end)
                        end
                    end
                end
            end

            -- Step 2: Recovery on Way to Safe
            if State.Step == "to_safe" then
                if not IsTargetCollected() then
                    if not State.RecoveryTriggered then
                        State.RecoveryTriggered = true
                        print("[VIPTP] Egg Dropped → Recovery")
                        task.spawn(function() task.wait(0.05) FlyToTargetAgain() end)
                    end
                else
                    State.RecoveryTriggered = false
                end
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

    State.CollectAttempts = 0
    State.CollectTime = 0
    State.TargetCollectStartTime = 0
    State.CollectDone = false
    State.TargetCollected = false
    State.RecoveryTriggered = false
    State.RecoveryAttempts = 0
    State.SavedTargetPosition = nil
    State.TargetLockedCFrame = nil

    SetupDropHeldEgg()
    SaveStats()

    -- ✅ Walk TP ទៅ Safe Zone មុន
    State.Step = "to_safe_first"

    print("[VIPTP] StartProcess → Walk TP to Safe Zone")

    WalkTP(Config.SafeZone, function()
        print("[VIPTP] ✅ At Safe Zone → Walk TP to Target")

        -- ✅ Walk TP ទៅ Target
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
        end

        if not TargetPos then AutoStop() return end

        State.Step = "to_target"

        WalkTP(TargetPos, function()
            print("[VIPTP] ✅ Arrived Target → Collect")

            State.TargetCollected = false
            State.CollectTime = 0
            State.CollectAttempts = 0
            State.RecoveryTriggered = false
            State.TargetCollectStartTime = tick()
            State.Step = "collect_target"

            StartActiveTask()
        end)
    end)
end

-- ==================================================
-- FULL RESET
-- ==================================================
local function FullReset()
    if State.LockConnection then State.LockConnection:Disconnect() State.LockConnection = nil end
    State.TargetLockedCFrame = nil

    if State.ActiveTask then
        pcall(function() task.cancel(State.ActiveTask) end)
        State.ActiveTask = nil
    end

    if State.DropHeldEggConnection then
        State.DropHeldEggConnection:Disconnect()
        State.DropHeldEggConnection = nil
    end
    State.DropHeldEgg = nil
    State.PlayerGui = nil

    CleanupMovers()
    RestoreStats()

    State.Running = false
    State.Step = "idle"
    State.Mode = "none"

    State.CollectAttempts = 0
    State.CollectTime = 0
    State.TargetCollectStartTime = 0
    State.CollectDone = false
    State.TargetCollected = false
    State.RecoveryTriggered = false
    State.RecoveryAttempts = 0
    State.SavedTargetPosition = nil

    print("[VIPTP] Full Reset")
end

-- ==================================================
-- ENABLE / DISABLE / SET
-- ==================================================
local function Enable()
    if State.Running then return end
    if not CollectEvent then warn("[VIPTP] CollectEvent not found") return end
    if not DropEvent then warn("[VIPTP] DropEvent not found") return end
    if not State.TargetUid then warn("[VIPTP] No Target ID") return end

    FullReset()
    StartProcess()

    print("[VIPTP] ON | Target: " .. tostring(State.TargetUid))
end

local function Disable()
    FullReset()
    print("[VIPTP] OFF")
end

local function SetTargetId(Id)
    State.TargetUid = Id
    print("[VIPTP] Target ID: " .. tostring(Id))
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_VIPTP = {
    Enable = Enable,
    Disable = Disable,
    SetTargetId = SetTargetId,
    IsEnabled = function() return State.Running end,
    GetTargetId = function() return State.TargetUid end,
    GetMode = function() return State.Mode end,
    WALK_SPEED = Config.WalkSpeed,
    SAFE_ZONE = Config.SafeZone,
    POSITION_1 = Config.Position1,
}

print("✅ VIPTP Loaded (Walk TP 275 + Shot TP + Lock + Drop)")
