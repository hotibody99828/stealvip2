-- ==================================================
-- YOKUDO HUB | FEATURE | VIPTP (AFK Farm Only)
-- ✅ ឯករាជ្យ — Speed កំណត់ក្នុង file
-- ✅ First Egg: 1000/s | Recovery: 1000/s | Safe Zone: 700/s
-- ✅ Safe Zone: រង់ចាំ 1s មុន Reset (ការពារធ្លាក់)
-- ✅ Tween + BodyV + BodyG — គណនា Duration ដោយផ្ទាល់
-- ✅ First Egg: Shot TP | Target: Instant TP
-- ✅ Recovery: Tween Direct ទៅ Egg Drop
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Container = workspace:WaitForChild("AreaEggSlotsClient")

-- ==================================================
-- CONFIG (ឯករាជ្យ — Speed ដាច់ដោយឡែក)
-- ==================================================
local Config = {
    -- ✅ Speed ដាច់ដោយឡែក
    FirstEggSpeed = 1000,      -- First Egg
    RecoverySpeed = 1000,      -- Recovery (Egg Drop)
    SafeZoneSpeed = 700,       -- Safe Zone

    NearOffset = 20,

    FlyOffset = 5,
    ShotDistance = 25,
    LockAbove = 1,
    ArriveDistance = 2,
    SafeStopDistance = 5,

    Timeout = 20,
    CollectInterval = 0.05,
    TargetCollectTimeout = 10,
    MaxRecoveryAttempts = 10000,

    BodyVelocityP = 5000,
    BodyGyroP = 50000,
    BodyGyroD = 2000,

    SafeZoneWaitTime = 1.0,    -- ✅ រង់ចាំ 1s មុន Reset

    SafeZone = Vector3.new(533, 70, -366),
    LockPosition = Vector3.new(607.6259155273438, 70.57420349121094, -326.8830261230469),

    SearchPrefix = "FirstAreaEgg",
    PositionThreshold = 1,

    RepeatCheckDelay = 0.05,
}

-- ==================================================
-- REMOTES
-- ==================================================
local CollectEvent = ReplicatedStorage.Packages.Networking:FindFirstChild("RF/EggWorld/AskFieldEggCarry")
local ForestStrike = ReplicatedStorage.Packages.Networking:FindFirstChild("RE/GuardPatrol/ForestStrike")

if not CollectEvent then
    warn("[VIPTP] CollectEvent not found")
    return
end

print("[VIPTP] CollectEvent OK | First:", Config.FirstEggSpeed, "| Recovery:", Config.RecoverySpeed, "| Safe:", Config.SafeZoneSpeed)

-- ==================================================
-- STATE
-- ==================================================
local State = {
    Running = false,
    Step = "idle",
    Mode = "none",
    TargetUid = nil,

    FlySequence = 0,

    TweenConnection = nil,
    FlyConnection = nil,
    LockConnection = nil,
    BodyVelocity = nil,
    BodyGyro = nil,
    ActiveTask = nil,

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
-- GET CHAR / ROOT / HUM
-- ==================================================
local function GetChar()
    return Player.Character
end

local function GetRoot()
    local Char = GetChar()
    if not Char then return nil end
    return Char:FindFirstChild("HumanoidRootPart")
end

local function GetHum()
    local Char = GetChar()
    if not Char then return nil end
    return Char:FindFirstChildOfClass("Humanoid")
end

-- ==================================================
-- GET POSITION
-- ==================================================
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
-- SAVE / RESTORE STATS
-- ==================================================
local function SaveStats()
    local Hum = GetHum()
    if not Hum then return end
    if State.SavedWalkSpeed == nil then State.SavedWalkSpeed = Hum.WalkSpeed end
    if State.SavedJumpPower == nil then State.SavedJumpPower = Hum.JumpPower end
    if State.SavedJumpHeight == nil then State.SavedJumpHeight = Hum.JumpHeight end
    if State.SavedUseJumpPower == nil then State.SavedUseJumpPower = Hum.UseJumpPower end
end

local function RestoreStats()
    local Hum = GetHum()
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
    local Hum = GetHum()
    local Root = GetRoot()
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
    local Char = GetChar()
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

    print("[VIPTP] Ragdoll Bypass: ON")
end

local function DisableRagdollBypass()
    if not State.RagdollEnabled then return end
    State.RagdollEnabled = false
    if State.RagdollConnection then
        State.RagdollConnection:Disconnect()
        State.RagdollConnection = nil
    end
    print("[VIPTP] Ragdoll Bypass: OFF")
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

    local Hum = GetHum()
    local Root = GetRoot()
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
            Root.CanCollide = true
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
        local Root = GetRoot()
        if not Root then return end
        Root.CFrame = State.TargetLockedCFrame
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end)
end

-- ==================================================
-- ✅ TWEEN TELEPORT DIRECT (សម្រាប់ RECOVERY — Speed 1000)
-- ==================================================
local function TweenTeleportDirect(Destination, Speed, Callback)
    State.FlySequence = State.FlySequence + 1
    local Seq = State.FlySequence

    CleanupMovers()

    local Hum = GetHum()
    local Root = GetRoot()
    if not Hum or not Root or Hum.Health <= 0 then
        if Callback then Callback() end
        return
    end

    local FlyPos = Vector3.new(Destination.X, Destination.Y + Config.FlyOffset, Destination.Z)
    local TargetCFrame = CFrame.new(FlyPos)

    Hum.PlatformStand = true

    local Distance = (FlyPos - Root.Position).Magnitude
    local Duration = Distance / Speed

    print(string.format("[VIPTP] Tween Direct | Dist: %.0f | Speed: %d | Duration: %.3fs",
        Distance, Speed, Duration))

    local Tween = TweenService:Create(
        Root,
        TweenInfo.new(Duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { CFrame = TargetCFrame }
    )
    State.TweenConnection = Tween
    Tween:Play()

    Tween.Completed:Wait()

    if Seq ~= State.FlySequence then return end
    if not State.Running then CleanupMovers() return end

    local Hum2 = GetHum()
    local Root2 = GetRoot()
    if not Hum2 or not Root2 or Hum2.Health <= 0 then CleanupMovers() return end

    Root2.CFrame = TargetCFrame
    Root2.AssemblyLinearVelocity = Vector3.zero
    Root2.AssemblyAngularVelocity = Vector3.zero

    task.wait(0.05)

    CleanupMovers(true)

    if Callback then Callback() end
end

-- ==================================================
-- TWEEN + BODYV + BODYG FLY TP
-- ✅ First Egg: Speed 1000 | Safe Zone: Speed 700
-- ✅ Safe Zone: រង់ចាំ 1s មុន Reset
-- ==================================================
local function FlyTP(Destination, Speed, UseShotTP, IsSafeZone, Callback)
    State.FlySequence = State.FlySequence + 1
    local Seq = State.FlySequence

    CleanupMovers()

    local Hum = GetHum()
    local Root = GetRoot()
    if not Hum or not Root or Hum.Health <= 0 then return end

    local FlyPos = Vector3.new(Destination.X, Destination.Y + Config.FlyOffset, Destination.Z)
    local LockCFrame = CFrame.new(Destination + Vector3.new(0, Config.LockAbove, 0))

    Hum.PlatformStand = true

    -- ✅ Step 1: Tween → Near Position
    local StartPos = Root.Position
    local Direction = (FlyPos - StartPos)
    local TotalDist = Direction.Magnitude
    local DirUnit = TotalDist > 0 and Direction.Unit or Vector3.new(0, 0, -1)

    local NearPos = FlyPos - (DirUnit * Config.NearOffset)
    local NearDist = (NearPos - StartPos).Magnitude
    local NearDuration = NearDist / Speed

    print(string.format("[VIPTP] Tween Near | Dist: %.0f | Speed: %d | Duration: %.3fs",
        NearDist, Speed, NearDuration))

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

        task.wait(0.03)

        local Hum2 = GetHum()
        local Root2 = GetRoot()
        if not Hum2 or not Root2 or Hum2.Health <= 0 then CleanupMovers() return end

        -- ✅ Step 2: BodyV + BodyG
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

        local InitDir = (FlyPos - Root2.Position)
        if InitDir.Magnitude > 1 then
            State.BodyVelocity.Velocity = InitDir.Unit * Speed
        end

        local StartTime = tick()
        local ShotDone = false

        State.FlyConnection = RunService.Heartbeat:Connect(function()
            if Seq ~= State.FlySequence then
                if State.FlyConnection then State.FlyConnection:Disconnect() State.FlyConnection = nil end
                return
            end

            if not State.Running then CleanupMovers() return end

            local Hum3 = GetHum()
            local Root3 = GetRoot()
            if not Hum3 or not Root3 or Hum3.Health <= 0 then CleanupMovers() return end
            if not State.BodyVelocity or not State.BodyGyro then CleanupMovers() return end

            local CurrentPos = Root3.Position
            local Dir = FlyPos - CurrentPos
            local HorizDist = Vector3.new(Dir.X, 0, Dir.Z).Magnitude
            local VertDist = math.abs(Dir.Y)
            local TotalDist2 = Dir.Magnitude

            -- ✅ Safe Zone: Fix CFrame → រង់ចាំ 1s → Reset
            if IsSafeZone and HorizDist <= Config.SafeStopDistance then
                if State.BodyVelocity then
                    State.BodyVelocity.Velocity = Vector3.zero
                    State.BodyVelocity.MaxForce = Vector3.zero
                end
                if State.BodyGyro then State.BodyGyro.MaxTorque = Vector3.zero end
                if State.FlyConnection then State.FlyConnection:Disconnect() State.FlyConnection = nil end

                -- ✅ Fix CFrame នៅ Safe Zone (Y ត្រង់ — មិន + FlyOffset)
                Root3.CFrame = CFrame.new(Config.SafeZone)
                Root3.AssemblyLinearVelocity = Vector3.zero
                Root3.AssemblyAngularVelocity = Vector3.zero

                task.spawn(function()
                    -- ✅ រង់ចាំ 1s ឲ្យ Player ចុះដីនឹងនរ
                    task.wait(Config.SafeZoneWaitTime)

                    -- ✅ ពិនិត្យ Y មុន Reset
                    local Root4 = GetRoot()
                    if Root4 and Root4.Position.Y < 60 then
                        Root4.CFrame = CFrame.new(Config.SafeZone)
                        Root4.AssemblyLinearVelocity = Vector3.zero
                        Root4.AssemblyAngularVelocity = Vector3.zero
                    end

                    task.wait(0.1)

                    CleanupMovers()
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

    local Hum = GetHum()
    local Root = GetRoot()
    if not Hum or not Root or Hum.Health <= 0 then return end

    local LockCFrame = CFrame.new(Destination + Vector3.new(0, Config.LockAbove, 0))
    Hum.PlatformStand = true

    task.spawn(function()
        task.wait(0.03)
        Root.CFrame = LockCFrame
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
        task.wait(0.1)
        StartLock(Destination)
        if Callback then Callback() end
    end)
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

    print("[VIPTP] ForestStrike Fired")
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
    local Root = GetRoot()
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

local function CheckTargetUID(TargetUid, Mode)
    if not TargetUid then return "none" end
    Mode = Mode or "spawn_only"

    local InContainer = false
    if Container then
        InContainer = Container:FindFirstChild(TargetUid) ~= nil
    end

    if InContainer then return "spawn" end

    if Mode == "both" then
        local InWorkspace = workspace:FindFirstChild(TargetUid) ~= nil
        if InWorkspace then return "workspace" end
    end

    return "none"
end

-- ==================================================
-- RESET FOR REPEAT
-- ==================================================
local function ResetForRepeat(Location)
    State.Step = "search"
    State.FlySequence = State.FlySequence + 1

    State.FlyTargetStarted = false
    State.CollectDone = false
    State.TargetCollected = false
    State.RemotesFired = false
    State.RecoveryTriggered = false
    State.RecoveryAttempts = 0
    State.CollectAttempts = 0
    State.CollectTime = 0
    State.TargetCollectStartTime = 0

    State.FirstEggList = {}
    State.FirstEggUid = nil
    State.FirstEggSlotKey = nil

    if Location == "spawn" then
        State.Mode = "spawn"
        State.SavedTargetPosition = nil
    elseif Location == "workspace" then
        State.Mode = "workspace"
        local Egg = workspace:FindFirstChild(State.TargetUid)
        if Egg then State.SavedTargetPosition = GetPosition(Egg) end
    end

    if State.LockConnection then
        State.LockConnection:Disconnect()
        State.LockConnection = nil
    end
end

-- ==================================================
-- AUTO STOP (Callback → FarmingManager)
-- ==================================================
local function AutoStop()
    if State.LockConnection then State.LockConnection:Disconnect() State.LockConnection = nil end
    State.TargetLockedCFrame = nil

    if State.ActiveTask then
        pcall(function() task.cancel(State.ActiveTask) end)
        State.ActiveTask = nil
    end

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
            else
                print("[VIPTP] OnVIPTPComplete is not a function (yet)")
            end
        else
            print("[VIPTP] FarmingManager not loaded yet")
        end
    end)
end

-- ==================================================
-- FLY TO TARGET (Instant TP)
-- ==================================================
local function StartFlyToTarget()
    if State.FlyTargetStarted then return end
    State.FlyTargetStarted = true
    State.Step = "to_target"

    local Location = CheckTargetUID(State.TargetUid, "spawn_only")

    local TargetPos
    if Location == "spawn" then
        State.Mode = "spawn"
        local Egg = Container and Container:FindFirstChild(State.TargetUid)
        if Egg then TargetPos = GetPosition(Egg) end
    end

    if not TargetPos then
        print("[VIPTP] Target not in Spawn → AutoStop")
        AutoStop()
        return
    end

    print("[VIPTP] Instant TP to Target | Location: spawn")

    InstantTP(TargetPos, function()
        print("[VIPTP] ✅ Instant TP Arrived Target")
        State.TargetCollected = false
        State.CollectTime = 0
        State.CollectAttempts = 0
        State.RecoveryTriggered = false
        State.TargetCollectStartTime = tick()
        State.Step = "collect_target"
    end)
end

-- ==================================================
-- ✅ RECOVERY (Tween Direct ទៅ Egg Drop — Speed 1000)
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

    State.FlySequence = State.FlySequence + 1
    CleanupMovers()

    local TargetPos
    local Location = CheckTargetUID(State.TargetUid, "both")

    if Location == "workspace" then
        State.Mode = "workspace"
        local Egg = workspace:FindFirstChild(State.TargetUid)
        if Egg then
            TargetPos = GetPosition(Egg)
            State.SavedTargetPosition = TargetPos
        end
    elseif Location == "spawn" then
        State.Mode = "spawn"
        local Egg = Container:FindFirstChild(State.TargetUid)
        if Egg then TargetPos = GetPosition(Egg) end
    else
        print("[VIPTP] Target Gone → AutoStop")
        AutoStop()
        return
    end

    if not TargetPos then AutoStop() return end

    State.RecoveryTriggered = false
    State.TargetCollected = false

    print("[VIPTP] Recovery → Tween Direct (Speed 1000)")
    TweenTeleportDirect(TargetPos, Config.RecoverySpeed, function()
        print("[VIPTP] ✅ Recovery #" .. State.RecoveryAttempts .. " Arrived")
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
-- SAFE ZONE (Speed 700 → រង់ចាំ 1s → រក UID ថ្មី)
-- ==================================================
local function FlyToSafeZone()
    State.Step = "to_safe"
    State.RecoveryTriggered = false
    State.TargetCollected = false

    print("[VIPTP] Tween + BodyV + BodyG to Safe Zone (Speed 700)")

    FlyTP(Config.SafeZone, Config.SafeZoneSpeed, false, true, function()
        print("[VIPTP] ✅ Arrived Safe Zone")

        task.spawn(function()
            task.wait(Config.RepeatCheckDelay)

            print("[VIPTP] Finding New UID from FarmingManager...")

            local NewUid = nil
            local NewLocation = "none"

            if _G.YOKUDO_FarmingManager and _G.YOKUDO_FarmingManager.FindBestEgg then
                local BestEgg = _G.YOKUDO_FarmingManager.FindBestEgg()
                if BestEgg then
                    NewUid = BestEgg.Uid
                    NewLocation = CheckTargetUID(NewUid, "spawn_only")
                    print("[VIPTP] New UID:", NewUid, "| Location:", NewLocation)
                end
            end

            if NewUid and NewLocation ~= "none" then
                print("[VIPTP] ✅ New UID → StartProcess")

                State.TargetUid = NewUid
                State.SavedTargetPosition = nil

                ResetForRepeat(NewLocation)
                task.wait(0.05)
                StartProcess()
            else
                print("[VIPTP] ❌ No UID → Callback Manager")
                AutoStop()
            end
        end)
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

            local Hum = GetHum()
            local Root = GetRoot()
            if not Hum or not Root or Hum.Health <= 0 then break end

            -- Step 1: Collect First
            if State.Step == "collect_first" and not State.CollectDone then
                if IsFirstEggInWorkspace() then
                    State.CollectDone = true
                    FireForestStrike()
                    State.Step = "wait_spawn_back"
                elseif tick() - State.CollectTime > Config.CollectInterval then
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
                    task.spawn(function() StartFlyToTarget() end)
                end
            end

            -- Step 3: Collect Target
            if State.Step == "collect_target" and not State.TargetCollected then
                if IsTargetCollected() then
                    print("[VIPTP] Target Collected (DropHeldEgg)")
                    State.TargetCollected = true
                    State.RecoveryTriggered = false
                    task.spawn(function() FlyToSafeZone() end)
                else
                    if State.Mode == "spawn" then
                        if workspace:FindFirstChild(State.TargetUid) then
                            State.TargetCollected = true
                            task.spawn(function() FlyToSafeZone() end)
                        end
                    elseif State.Mode == "workspace" and State.SavedTargetPosition then
                        local Egg = workspace:FindFirstChild(State.TargetUid)
                        if Egg then
                            local Pos = GetPosition(Egg)
                            if Pos and (Pos - State.SavedTargetPosition).Magnitude >= Config.PositionThreshold then
                                State.TargetCollected = true
                                task.spawn(function() FlyToSafeZone() end)
                            end
                        end
                    end

                    if tick() - State.CollectTime > Config.CollectInterval then
                        State.CollectTime = tick()
                        RemoteCollectTarget()
                        State.CollectAttempts = State.CollectAttempts + 1
                    end

                    if tick() - State.TargetCollectStartTime > Config.TargetCollectTimeout then
                        print("[VIPTP] Target Timeout → Recovery")
                        if not State.RecoveryTriggered then
                            State.RecoveryTriggered = true
                            task.spawn(function() FlyToTargetAgain() end)
                        end
                    end
                end
            end

            -- Step 4: Recovery on Way to Safe
            if State.Step == "to_safe" then
                if not IsTargetCollected() then
                    if not State.RecoveryTriggered then
                        State.RecoveryTriggered = true
                        print("[VIPTP] Egg Dropped → Recovery")
                        task.spawn(function() FlyToTargetAgain() end)
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
function StartProcess()
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

    SetupDropHeldEgg()
    SaveStats()
    EnableRagdollBypass()

    local Location = CheckTargetUID(State.TargetUid, "spawn_only")
    print("[VIPTP] Target Location:", Location)

    if Location == "spawn" then
        State.Mode = "spawn"
    else
        local Waited = 0
        while State.Running and CheckTargetUID(State.TargetUid, "spawn_only") == "none" do
            task.wait(0.1)
            Waited = Waited + 0.1
            if Waited > 3 then
                print("[VIPTP] ⚠️ Target not found 3s → AutoStop")
                AutoStop()
                return
            end
        end
        State.Mode = "spawn"
    end

    SearchFirstEggs()

    if #State.FirstEggList == 0 then
        task.wait(0.3)
        SearchFirstEggs()
        if #State.FirstEggList == 0 then
            AutoStop()
            return
        end
    end

    local Closest = FindClosestEgg()
    if not Closest then AutoStop() return end

    local EggPos = GetPosition(Closest.Slot)
    if not EggPos then AutoStop() return end

    State.Step = "fly_first"
    StartActiveTask()

    -- ✅ First Egg: Speed 1000
    print("[VIPTP] Tween + BodyV + BodyG to First Egg (Speed 1000 | Shot TP)")
    FlyTP(EggPos, Config.FirstEggSpeed, true, false, function()
        State.CollectDone = false
        State.CollectTime = 0
        State.Step = "collect_first"
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

    print("[VIPTP] Full Reset")
end

-- ==================================================
-- ENABLE / DISABLE / SET
-- ==================================================
local function Enable()
    if State.Running then return end
    if not CollectEvent then warn("[VIPTP] CollectEvent not found") return end
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
    FIRST_EGG_SPEED = Config.FirstEggSpeed,
    RECOVERY_SPEED = Config.RecoverySpeed,
    SAFE_ZONE_SPEED = Config.SafeZoneSpeed,
    FLY_OFFSET = Config.FlyOffset,
    SAFE_ZONE = Config.SafeZone,
}

print("✅ VIPTP Loaded (First: 1000 | Recovery: 1000 | Safe: 700 | Wait 1s)")
