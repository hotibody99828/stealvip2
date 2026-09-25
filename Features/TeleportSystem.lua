-- ==================================================
-- YOKUDO HUB - TELEPORT SYSTEM (DUAL MODE + DUAL OPTION + RECOVERY)
-- ✅ រលូត (មិនកន្រាក់) — Stop BodyV/G + task.wait(0.1)
-- ✅ Egg Drop ច្រើនដង — Recovery Loop
-- ✅ Check លឿន — COLLECT_INTERVAL = 0.05
-- ✅ មិនជាប់គាំង — Timeout
-- ✅ Shot TP = 25 | Recovery = No Shot TP
-- ✅ Safe Zone: Stop + Reset + Destroy
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local Container = workspace:WaitForChild("AreaEggSlotsClient")

-- ==================================================
-- REMOTES
-- ==================================================
local CollectEvent = nil
local ForestStrike = nil

pcall(function()
    CollectEvent = ReplicatedStorage.Packages.Networking["RF/EggWorld/AskFieldEggCarry"]
end)

pcall(function()
    ForestStrike = ReplicatedStorage.Packages.Networking["RE/GuardPatrol/ForestStrike"]
end)

if not CollectEvent then
    warn("[YOKUDO] CollectEvent not found")
    return
end

print("[YOKUDO] TeleportSystem: CollectEvent OK")

-- ==================================================
-- SETTINGS
-- ==================================================
local TARGET_UID = nil
local SAFE_ZONE = Vector3.new(533, 70, -366)

local FLY_SPEED = 1000
local RETURN_SPEED = 800

local CurrentMethod = "TeleportFly"

local FLY_OFFSET = 5
local SHOT_DISTANCE = 25
local LOCK_ABOVE = 1

local ARRIVE_DISTANCE = 5
local SAFE_LOCK_DISTANCE = 3
local TIMEOUT_SECONDS = 30

local COLLECT_INTERVAL = 0.05     -- ✅ លឿន
local SEARCH_PREFIX = "FirstAreaEgg"
local POSITION_THRESHOLD = 1

local MAX_RECOVERY_ATTEMPTS = 10  -- ✅ កំណត់ចំនួន Recovery អតិបរមា
local TARGET_COLLECT_TIMEOUT = 15 -- ✅ Timeout សម្រាប់ Target Collection

local LOCK_POSITION = Vector3.new(
    607.6259155273438,
    70.57420349121094,
    -326.8830261230469
)

-- ==================================================
-- BODY SETTINGS
-- ==================================================
local BODY_VELOCITY_P = 10000
local BODY_GYRO_P = 100000
local BODY_GYRO_D = 2000

-- ==================================================
-- RAGDOLL BYPASS
-- ==================================================
local RagdollEnabled = false
local RagdollConnection = nil
local ForceUpConnection = nil

-- ==================================================
-- DROPHELDEGG
-- ==================================================
local PlayerGui = nil
local DropHeldEgg = nil
local DropHeldEggConnection = nil
local LastDropState = false

-- ==================================================
-- STATE
-- ==================================================
local Running = false
local CurrentStep = "idle"
local CurrentMode = "none"

local FlyConnection = nil
local BodyVelocity = nil
local BodyGyro = nil
local ActiveHeartbeat = nil
local LockConnection = nil

local FirstEggList = {}
local FirstEggUid = nil
local FirstEggSlotKey = nil

local CollectAttempts = 0
local CollectTime = 0
local TargetCollectStartTime = 0  -- ✅ សម្រាប់ Timeout

local FlyTargetStarted = false
local CollectDone = false
local TargetCollected = false
local RemotesFired = false
local RecoveryTriggered = false
local RecoveryAttempts = 0

local SavedTargetPosition = nil
local TargetLockedCFrame = nil

local SavedWalkSpeed = nil
local SavedJumpPower = nil
local SavedJumpHeight = nil
local SavedUseJumpPower = nil

-- ==================================================
-- GET CHARACTER
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
        for _, descendant in ipairs(Char:GetDescendants()) do
            if descendant.Name:find("RagdollConstraint") then
                descendant:Destroy()
            end
            if descendant.Name:find("RagdollAttachment") then
                descendant:Destroy()
            end
        end

        for _, descendant in ipairs(Char:GetDescendants()) do
            if descendant:IsA("Motor6D") then
                descendant.Enabled = true
            end
        end
    end)
end

local function EnableRagdollBypass()
    if RagdollEnabled then return end
    RagdollEnabled = true

    RagdollConnection = RunService.Heartbeat:Connect(function()
        if not RagdollEnabled then return end
        ForceUp()
    end)

    ForceUpConnection = task.spawn(function()
        while RagdollEnabled do
            task.wait(0.1)
            ForceUp()
            CleanupRagdollConstraints()
        end
    end)

    print("[YOKUDO] Ragdoll Bypass: ON")
end

local function DisableRagdollBypass()
    if not RagdollEnabled then return end
    RagdollEnabled = false

    if RagdollConnection then
        RagdollConnection:Disconnect()
        RagdollConnection = nil
    end

    print("[YOKUDO] Ragdoll Bypass: OFF")
end

-- ==================================================
-- SAVE / RESTORE STATS
-- ==================================================
local function SaveStats()
    local Hum = GetHum()
    if not Hum then return end

    if SavedWalkSpeed == nil then SavedWalkSpeed = Hum.WalkSpeed end
    if SavedJumpPower == nil then SavedJumpPower = Hum.JumpPower end
    if SavedJumpHeight == nil then SavedJumpHeight = Hum.JumpHeight end
    if SavedUseJumpPower == nil then SavedUseJumpPower = Hum.UseJumpPower end
end

local function RestoreStats()
    local Hum = GetHum()
    if not Hum then return end

    if SavedWalkSpeed ~= nil then pcall(function() Hum.WalkSpeed = SavedWalkSpeed end) end
    if SavedJumpPower ~= nil then pcall(function() Hum.JumpPower = SavedJumpPower end) end
    if SavedJumpHeight ~= nil then pcall(function() Hum.JumpHeight = SavedJumpHeight end) end
    if SavedUseJumpPower ~= nil then pcall(function() Hum.UseJumpPower = SavedUseJumpPower end) end
end

-- ==================================================
-- CLEANUP
-- ==================================================
local function CleanupMovers()
    if FlyConnection then
        FlyConnection:Disconnect()
        FlyConnection = nil
    end
    if LockConnection then
        LockConnection:Disconnect()
        LockConnection = nil
    end
    if BodyVelocity then
        pcall(function()
            BodyVelocity.Velocity = Vector3.zero
            BodyVelocity.MaxForce = Vector3.zero
        end)
        BodyVelocity:Destroy()
        BodyVelocity = nil
    end
    if BodyGyro then
        pcall(function()
            BodyGyro.MaxTorque = Vector3.zero
        end)
        BodyGyro:Destroy()
        BodyGyro = nil
    end

    local Root = GetRoot()
    if Root then
        for _, Child in ipairs(Root:GetChildren()) do
            if Child.Name == "YokudoBV" or Child.Name == "YokudoBG" then
                pcall(function() Child:Destroy() end)
            end
        end
    end

    local Hum = GetHum()
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
-- LOCK AT TARGET (Y+1)
-- ==================================================
local function StartLock(TargetPosition)
    if not TargetPosition then return end

    TargetLockedCFrame = CFrame.new(TargetPosition + Vector3.new(0, LOCK_ABOVE, 0))

    if LockConnection then
        LockConnection:Disconnect()
    end

    LockConnection = RunService.Heartbeat:Connect(function()
        if not Running then
            if LockConnection then LockConnection:Disconnect() LockConnection = nil end
            return
        end

        local Root = GetRoot()
        if not Root then return end

        Root.CFrame = TargetLockedCFrame
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end)
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
-- SETUP DROPHELDEGG
-- ==================================================
local function SetupDropHeldEgg()
    PlayerGui = Player:FindFirstChild("PlayerGui")
    if not PlayerGui then
        PlayerGui = Player:WaitForChild("PlayerGui", 5)
    end

    if not PlayerGui then
        warn("[YOKUDO] PlayerGui not found!")
        return
    end

    DropHeldEgg = PlayerGui:FindFirstChild("DropHeldEgg")
    if not DropHeldEgg then
        warn("[YOKUDO] DropHeldEgg not found!")
        return
    end

    LastDropState = DropHeldEgg.Enabled
    print("[YOKUDO] DropHeldEgg found | Enabled: " .. tostring(DropHeldEgg.Enabled))

    if DropHeldEggConnection then
        DropHeldEggConnection:Disconnect()
        DropHeldEggConnection = nil
    end

    DropHeldEggConnection = DropHeldEgg:GetPropertyChangedSignal("Enabled"):Connect(function()
        print("[YOKUDO] DropHeldEgg.Enabled changed: " .. tostring(LastDropState) .. " → " .. tostring(DropHeldEgg.Enabled))
        LastDropState = DropHeldEgg.Enabled
    end)
end

-- ==================================================
-- CHECK TARGET COLLECTED
-- ==================================================
local function IsTargetCollectedByDropHeldEgg()
    if not DropHeldEgg then return false end
    return DropHeldEgg.Enabled == true
end

-- ==================================================
-- SEARCH FIRST EGGS
-- ==================================================
local function SearchFirstEggs()
    FirstEggList = {}
    if not Container then return end

    for _, Slot in ipairs(Container:GetChildren()) do
        if string.find(Slot.Name, SEARCH_PREFIX) then
            local SlotNum = string.match(Slot.Name, "Slot_(%d+)")
            if SlotNum then
                table.insert(FirstEggList, {
                    Slot = Slot,
                    Uid = Slot.Name,
                    SlotKey = "Forest:Slot_" .. SlotNum,
                    SlotNum = tonumber(SlotNum)
                })
            end
        end
    end
end

local function FindClosestEgg()
    local Root = GetRoot()
    if not Root then return nil end

    local Closest = nil
    local ClosestDistance = 9999

    for _, Egg in ipairs(FirstEggList) do
        local Pos = GetPosition(Egg.Slot)
        if Pos then
            local Dist = (Pos - Root.Position).Magnitude
            if Dist < ClosestDistance then
                ClosestDistance = Dist
                Closest = Egg
            end
        end
    end

    if Closest then
        FirstEggUid = Closest.Uid
        FirstEggSlotKey = Closest.SlotKey
    end

    return Closest
end

-- ==================================================
-- ✅ FLY TP (រលូត — Stop BodyV/G + task.wait(0.1) ពីរដង)
-- ==================================================
local function FlyTP(Destination, Speed, UseShotTP, IsSafeZone, Callback)
    CleanupMovers()

    local Hum = GetHum()
    local Root = GetRoot()
    if not Hum or not Root then return end
    if Hum.Health <= 0 then return end

    local FlyPos = Vector3.new(Destination.X, Destination.Y + FLY_OFFSET, Destination.Z)

    local LockCFrame
    if IsSafeZone then
        LockCFrame = CFrame.new(Destination)
    else
        LockCFrame = CFrame.new(Destination + Vector3.new(0, LOCK_ABOVE, 0))
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

    local StartTime = tick()
    local ShotDone = false

    FlyConnection = RunService.Heartbeat:Connect(function()
        if not Running then
            CleanupMovers()
            return
        end

        local Hum2 = GetHum()
        local Root2 = GetRoot()
        if not Hum2 or not Root2 then
            CleanupMovers()
            return
        end
        if Hum2.Health <= 0 then return end

        if not BodyVelocity or not BodyGyro then
            CleanupMovers()
            return
        end

        local CurrentPos = Root2.Position
        local Direction = (FlyPos - CurrentPos)
        local HorizDist = Vector3.new(Direction.X, 0, Direction.Z).Magnitude
        local VertDist = math.abs(Direction.Y)
        local TotalDist = Direction.Magnitude

        -- ✅ Shot TP = 25 (រលូត)
        if not IsSafeZone and UseShotTP and not ShotDone and HorizDist <= SHOT_DISTANCE then
            ShotDone = true

            -- ✅ Stop BodyV/G
            if BodyVelocity then
                BodyVelocity.Velocity = Vector3.zero
                BodyVelocity.MaxForce = Vector3.zero
            end
            if BodyGyro then
                BodyGyro.MaxTorque = Vector3.zero
            end

            -- ✅ រង់ចាំ 0.1 វិនាទី
            task.wait(0.1)

            -- ✅ TP CFrame
            Root2.CFrame = LockCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero

            -- ✅ រង់ចាំ 0.1 វិនាទីម្តងទៀត
            task.wait(0.1)

            -- ✅ Cleanup + Lock
            CleanupMovers()
            StartLock(Destination)

            if Callback then Callback() end
            return
        end

        -- ✅ Safe Zone (រលូត)
        if IsSafeZone then
            if HorizDist <= SAFE_LOCK_DISTANCE then
                if BodyVelocity then
                    BodyVelocity.Velocity = Vector3.zero
                    BodyVelocity.MaxForce = Vector3.zero
                end
                if BodyGyro then
                    BodyGyro.MaxTorque = Vector3.zero
                end

                task.wait(0.1)

                Root2.CFrame = LockCFrame
                Root2.AssemblyLinearVelocity = Vector3.zero
                Root2.AssemblyAngularVelocity = Vector3.zero

                task.wait(0.1)

                CleanupMovers()
                StartLock(Destination)

                if Callback then Callback() end
                return
            end
        end

        -- ✅ Arrived (រលូត)
        if HorizDist <= ARRIVE_DISTANCE and VertDist <= 2 then
            if BodyVelocity then
                BodyVelocity.Velocity = Vector3.zero
                BodyVelocity.MaxForce = Vector3.zero
            end
            if BodyGyro then
                BodyGyro.MaxTorque = Vector3.zero
            end

            task.wait(0.1)

            Root2.CFrame = LockCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero

            task.wait(0.1)

            CleanupMovers()
            StartLock(Destination)

            if Callback then Callback() end
            return
        end

        -- ✅ Timeout
        if tick() - StartTime > TIMEOUT_SECONDS then
            CleanupMovers()
            if Callback then Callback() end
            return
        end

        -- ✅ បន្តហោះ
        if TotalDist > 1 then
            BodyVelocity.Velocity = Direction.Unit * Speed
        else
            BodyVelocity.Velocity = Vector3.zero
        end

        BodyGyro.CFrame = CFrame.new(CurrentPos, CurrentPos + Vector3.new(Direction.X, 0, Direction.Z))
    end)
end

-- ==================================================
-- INSTANT FLY TP
-- ==================================================
local function InstantFlyTP(Destination, Callback)
    if not Destination then
        if Callback then Callback() end
        return
    end

    CleanupMovers()

    local Hum = GetHum()
    local Root = GetRoot()
    if not Hum or not Root then return end
    if Hum.Health <= 0 then return end

    local LockCFrame = CFrame.new(Destination + Vector3.new(0, LOCK_ABOVE, 0))

    Root.CFrame = LockCFrame
    Root.AssemblyLinearVelocity = Vector3.zero
    Root.AssemblyAngularVelocity = Vector3.zero

    task.wait(0.1)

    CleanupMovers()
    StartLock(Destination)

    if Callback then Callback() end
end

-- ==================================================
-- TELEPORT TO TARGET
-- ==================================================
local function TeleportToTarget(TargetPos, Callback)
    if CurrentMethod == "InstantTeleport" then
        print("[YOKUDO] Instant TP to Target")
        InstantFlyTP(TargetPos, Callback)
    else
        print("[YOKUDO] FlyTP to Target (Shot TP 25)")
        FlyTP(TargetPos, FLY_SPEED, true, false, Callback)
    end
end

-- ==================================================
-- REMOTE COLLECT
-- ==================================================
local function RemoteCollectFirst()
    if not CollectEvent or not FirstEggSlotKey or not FirstEggUid then return false end
    local success = pcall(function()
        return CollectEvent:InvokeServer({
            FirstAreaSlotKey = FirstEggSlotKey,
            Uid = FirstEggUid
        })
    end)
    return success
end

local function RemoteCollectTarget()
    if not CollectEvent or not TARGET_UID then return false end
    local success = pcall(function()
        return CollectEvent:InvokeServer({
            Uid = TARGET_UID
        })
    end)
    return success
end

-- ==================================================
-- FIRE FOREST STRIKE
-- ==================================================
local function FireForestStrike()
    if RemotesFired then return end
    RemotesFired = true

    EnableRagdollBypass()

    pcall(function()
        ForestStrike:FireServer({
            EggUid = FirstEggUid,
            GuardCFrame = CFrame.new(LOCK_POSITION)
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
-- CHECK EGG
-- ==================================================
local function IsFirstEggInWorkspace()
    if not FirstEggUid then return false end
    return workspace:FindFirstChild(FirstEggUid) ~= nil
end

local function IsFirstEggInContainer()
    if not FirstEggUid then return false end
    if not Container then return false end
    return Container:FindFirstChild(FirstEggUid) ~= nil
end

local function IsTargetInContainer()
    if not TARGET_UID or not Container then return false end
    return Container:FindFirstChild(TARGET_UID) ~= nil
end

local function IsTargetInWorkspace()
    if not TARGET_UID then return false end
    return workspace:FindFirstChild(TARGET_UID) ~= nil
end

local function IsTargetStillExists()
    return IsTargetInContainer() or IsTargetInWorkspace()
end

-- ==================================================
-- AUTO STOP
-- ==================================================
local function AutoStop()
    Running = false
    CurrentStep = "done"

    if LockConnection then
        LockConnection:Disconnect()
        LockConnection = nil
    end
    TargetLockedCFrame = nil

    if BodyVelocity then
        pcall(function()
            BodyVelocity.Velocity = Vector3.zero
            BodyVelocity.MaxForce = Vector3.zero
        end)
        BodyVelocity:Destroy()
        BodyVelocity = nil
    end
    if BodyGyro then
        pcall(function()
            BodyGyro.MaxTorque = Vector3.zero
        end)
        BodyGyro:Destroy()
        BodyGyro = nil
    end

    local Root = GetRoot()
    if Root then
        pcall(function()
            Root.CFrame = CFrame.new(SAFE_ZONE)
            Root.AssemblyLinearVelocity = Vector3.zero
            Root.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    local Hum = GetHum()
    if Hum then
        pcall(function()
            Hum.PlatformStand = false
            Hum.Sit = false
            Hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end

    task.wait(0.2)

    CleanupMovers()
    DisableRagdollBypass()
    StopActiveHeartbeat()
    RestoreStats()

    -- ✅ Reset State ទាំងអស់
    FirstEggList = {}
    FirstEggUid = nil
    FirstEggSlotKey = nil
    CollectAttempts = 0
    CollectTime = 0
    TargetCollectStartTime = 0
    FlyTargetStarted = false
    CollectDone = false
    TargetCollected = false
    RemotesFired = false
    RecoveryTriggered = false
    RecoveryAttempts = 0
    SavedTargetPosition = nil

    print("[YOKUDO] TeleportSystem: Auto Stop + Reset State")
end

-- ==================================================
-- START FLY TO TARGET
-- ==================================================
local function StartFlyToTarget()
    if FlyTargetStarted then return end
    FlyTargetStarted = true

    CurrentStep = "to_target"

    local TargetPos = nil

    if CurrentMode == "spawn" then
        local TargetEgg = Container and Container:FindFirstChild(TARGET_UID)
        if TargetEgg then
            TargetPos = GetPosition(TargetEgg)
        end
    elseif CurrentMode == "workspace" then
        if SavedTargetPosition then
            TargetPos = SavedTargetPosition
        else
            local WSEgg = workspace:FindFirstChild(TARGET_UID)
            if WSEgg then
                TargetPos = GetPosition(WSEgg)
                SavedTargetPosition = TargetPos
            end
        end
    end

    if not TargetPos then
        AutoStop()
        return
    end

    TeleportToTarget(TargetPos, function()
        print("[YOKUDO] ✅ StartFlyToTarget Arrived → collect_target")

        TargetCollected = false
        CollectTime = 0
        CollectAttempts = 0
        RecoveryTriggered = false
        TargetCollectStartTime = tick()  -- ✅ Reset Timeout

        CurrentStep = "collect_target"
    end)
end

-- ==================================================
-- ✅ FLY TO TARGET AGAIN (Recovery — Loop ច្រើនដង)
-- ==================================================
local function FlyToTargetAgain()
    RecoveryAttempts = RecoveryAttempts + 1

    if RecoveryAttempts > MAX_RECOVERY_ATTEMPTS then
        print("[YOKUDO] ⚠️ Max Recovery Attempts → AutoStop")
        AutoStop()
        return
    end

    print("[YOKUDO] ⚠️ Egg Dropped → Recovery #" .. RecoveryAttempts .. " (No Shot TP)")
    CurrentStep = "recovery"

    local TargetPos = nil

    if IsTargetInContainer() then
        CurrentMode = "spawn"
        local TargetEgg = Container:FindFirstChild(TARGET_UID)
        if TargetEgg then
            TargetPos = GetPosition(TargetEgg)
        end
    elseif IsTargetInWorkspace() then
        CurrentMode = "workspace"
        local WSEgg = workspace:FindFirstChild(TARGET_UID)
        if WSEgg then
            TargetPos = GetPosition(WSEgg)
            SavedTargetPosition = TargetPos
        end
    else
        print("[YOKUDO] ✅ Target Gone (Both) → AutoStop")
        AutoStop()
        return
    end

    if not TargetPos then
        print("[YOKUDO] Target Pos not found → AutoStop")
        AutoStop()
        return
    end

    -- ✅ FlyTP ធម្មតា (No Shot TP)
    FlyTP(TargetPos, FLY_SPEED, false, false, function()
        print("[YOKUDO] ✅ Recovery #" .. RecoveryAttempts .. " Arrived → collect_target")

        TargetCollected = false
        CollectTime = 0
        CollectAttempts = 0
        RecoveryTriggered = false
        RemotesFired = false
        TargetCollectStartTime = tick()  -- ✅ Reset Timeout

        CurrentStep = "collect_target"
    end)
end

-- ==================================================
-- FLY TO SAFE ZONE
-- ==================================================
local function FlyToSafeZone()
    CurrentStep = "to_safe"

    print("[YOKUDO] FlyTP to Safe Zone")

    FlyTP(SAFE_ZONE, RETURN_SPEED, false, true, function()
        print("[YOKUDO] ✅ Arrived Safe Zone → AutoStop")

        TargetCollected = false
        CollectDone = false
        CollectTime = 0
        CollectAttempts = 0
        RecoveryTriggered = false
        RemotesFired = false
        FlyTargetStarted = false
        RecoveryAttempts = 0
        SavedTargetPosition = nil

        task.wait(0.2)

        AutoStop()
    end)
end

-- ==================================================
-- HEARTBEAT (Check លឿន + Timeout)
-- ==================================================
local function StartActiveHeartbeat()
    if ActiveHeartbeat then
        ActiveHeartbeat:Disconnect()
        ActiveHeartbeat = nil
    end

    ActiveHeartbeat = RunService.Heartbeat:Connect(function()
        if not Running then return end

        local Hum = GetHum()
        local Root = GetRoot()
        if not Hum or not Root then return end
        if Hum.Health <= 0 then return end

        -- Step 1: Collect First Egg
        if CurrentStep == "collect_first" and not CollectDone then
            if IsFirstEggInWorkspace() then
                CollectDone = true
                FireForestStrike()
                CurrentStep = "wait_spawn_back"
                return
            end

            if tick() - CollectTime > COLLECT_INTERVAL then
                CollectTime = tick()

                if IsFirstEggInContainer() then
                    RemoteCollectFirst()
                    CollectAttempts = CollectAttempts + 1
                else
                    if IsFirstEggInWorkspace() then
                        CollectDone = true
                        FireForestStrike()
                        CurrentStep = "wait_spawn_back"
                    end
                end
            end
        end

        -- Step 2: Wait First Egg Spawn Back
        if CurrentStep == "wait_spawn_back" and not FlyTargetStarted then
            if IsFirstEggInContainer() then
                task.spawn(function() StartFlyToTarget() end)
            end
        end

        -- Step 3: Collect Target Egg (Check លឿន)
        if CurrentStep == "collect_target" and not TargetCollected then

            -- ✅ ពិនិត្យ DropHeldEgg ជាមុន — លឿនជាងគេ
            if IsTargetCollectedByDropHeldEgg() then
                print("[YOKUDO] ✅ DropHeldEgg.Enabled = true → Target Collected!")
                TargetCollected = true
                task.spawn(function() FlyToSafeZone() end)
                return
            end

            -- ✅ ពិនិត្យ Mode ដើម
            if CurrentMode == "spawn" then
                if workspace:FindFirstChild(TARGET_UID) then
                    TargetCollected = true
                    task.spawn(function() FlyToSafeZone() end)
                    return
                end
            elseif CurrentMode == "workspace" then
                if SavedTargetPosition then
                    local WSEgg = workspace:FindFirstChild(TARGET_UID)
                    if WSEgg then
                        local CurrentPos = GetPosition(WSEgg)
                        if CurrentPos then
                            local Dist = (CurrentPos - SavedTargetPosition).Magnitude
                            if Dist >= POSITION_THRESHOLD then
                                TargetCollected = true
                                task.spawn(function() FlyToSafeZone() end)
                                return
                            end
                        end
                    end
                end
            end

            -- ✅ បន្ត Collect — លឿន
            if tick() - CollectTime > COLLECT_INTERVAL then
                CollectTime = tick()
                RemoteCollectTarget()
                CollectAttempts = CollectAttempts + 1
            end

            -- ✅ Timeout — កុំឲ្យជាប់គាំង
            if tick() - TargetCollectStartTime > TARGET_COLLECT_TIMEOUT then
                print("[YOKUDO] ⚠️ Target Collect Timeout → Recovery")
                if not RecoveryTriggered then
                    RecoveryTriggered = true
                    task.spawn(function() FlyToTargetAgain() end)
                end
                return
            end
        end

        -- Step 4: Recovery (Egg Drop តាមផ្លូវ)
        if CurrentStep == "to_safe" then
            if not IsTargetCollectedByDropHeldEgg() then
                if not RecoveryTriggered then
                    RecoveryTriggered = true
                    print("[YOKUDO] ⚠️ Egg Dropped on Way → Recovery!")
                    task.spawn(function()
                        FlyToTargetAgain()
                    end)
                end
                return
            else
                RecoveryTriggered = false
            end
        end
    end)
end

local function StopActiveHeartbeat()
    if ActiveHeartbeat then
        ActiveHeartbeat:Disconnect()
        ActiveHeartbeat = nil
    end
end

-- ==================================================
-- MAIN PROCESS
-- ==================================================
local function StartProcess()
    Running = true
    CurrentStep = "search"

    CollectAttempts = 0
    CollectTime = 0
    TargetCollectStartTime = 0
    FlyTargetStarted = false
    CollectDone = false
    TargetCollected = false
    RemotesFired = false
    RecoveryTriggered = false
    RecoveryAttempts = 0
    SavedTargetPosition = nil
    TargetLockedCFrame = nil
    LastDropState = false

    SetupDropHeldEgg()

    SaveStats()
    EnableRagdollBypass()

    if IsTargetInContainer() then
        CurrentMode = "spawn"
        print("[YOKUDO] Target found in Container → spawn mode")
    elseif IsTargetInWorkspace() then
        CurrentMode = "workspace"
        local WSEgg = workspace:FindFirstChild(TARGET_UID)
        if WSEgg then
            SavedTargetPosition = GetPosition(WSEgg)
        end
        print("[YOKUDO] Target found in Workspace → workspace mode")
    else
        local WaitTime = 0
        while Running and not IsTargetInContainer() and not IsTargetInWorkspace() do
            task.wait(0.5)
            WaitTime = WaitTime + 0.5
            if WaitTime > 60 then
                AutoStop()
                return
            end
        end

        if IsTargetInContainer() then
            CurrentMode = "spawn"
        elseif IsTargetInWorkspace() then
            CurrentMode = "workspace"
            local WSEgg = workspace:FindFirstChild(TARGET_UID)
            if WSEgg then
                SavedTargetPosition = GetPosition(WSEgg)
            end
        end
    end

    SearchFirstEggs()

    if #FirstEggList == 0 then
        AutoStop()
        return
    end

    local Closest = FindClosestEgg()

    if not Closest then
        AutoStop()
        return
    end

    local EggPos = GetPosition(Closest.Slot)
    if not EggPos then
        AutoStop()
        return
    end

    CurrentStep = "fly_first"

    StartActiveHeartbeat()

    print("[YOKUDO] FlyTP to First Egg (Shot TP 25)")
    FlyTP(EggPos, FLY_SPEED, true, false, function()
        CollectDone = false
        CollectTime = 0
        CurrentStep = "collect_first"
    end)
end

-- ==================================================
-- FULL RESET
-- ==================================================
local function FullReset()
    Running = false
    CurrentStep = "idle"
    CurrentMode = "none"

    FirstEggList = {}
    FirstEggUid = nil
    FirstEggSlotKey = nil
    CollectAttempts = 0
    CollectTime = 0
    TargetCollectStartTime = 0
    FlyTargetStarted = false
    CollectDone = false
    TargetCollected = false
    RemotesFired = false
    RecoveryTriggered = false
    RecoveryAttempts = 0
    SavedTargetPosition = nil
    TargetLockedCFrame = nil
    LastDropState = false

    if DropHeldEggConnection then
        DropHeldEggConnection:Disconnect()
        DropHeldEggConnection = nil
    end
    DropHeldEgg = nil
    PlayerGui = nil

    CleanupMovers()
    DisableRagdollBypass()
    StopActiveHeartbeat()
    RestoreStats()

    print("[YOKUDO] TeleportSystem: Full Reset")
end

-- ==================================================
-- ENABLE / DISABLE / SET
-- ==================================================
local function Enable()
    if Running then return end
    if not CollectEvent then warn("[YOKUDO] CollectEvent not found") return end
    if not TARGET_UID then warn("[YOKUDO] No Target ID") return end

    FullReset()
    StartProcess()

    print("[YOKUDO] TeleportSystem: ON | Method: " .. CurrentMethod)
end

local function Disable()
    FullReset()
    print("[YOKUDO] TeleportSystem: OFF")
end

local function SetTargetId(Id)
    TARGET_UID = Id
    print("[YOKUDO] TeleportSystem Target ID: " .. tostring(Id))
end

local function SetSpeed(Value)
    Value = math.clamp(Value, 50, 1100)
    FLY_SPEED = Value
    RETURN_SPEED = Value
    print("[YOKUDO] TeleportSystem Speed: " .. tostring(Value))
end

local function SetMethod(Method)
    if Method == "InstantTeleport" then
        CurrentMethod = "InstantTeleport"
    else
        CurrentMethod = "TeleportFly"
    end
    print("[YOKUDO] TeleportSystem Method: " .. CurrentMethod)
end

local function GetMethod()
    return CurrentMethod
end

local function GetSpeed()
    return FLY_SPEED
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_TeleportSystem = {
    Enable = Enable,
    Disable = Disable,
    SetTargetId = SetTargetId,
    SetSpeed = SetSpeed,
    SetMethod = SetMethod,
    GetMethod = GetMethod,
    GetSpeed = GetSpeed,
    IsEnabled = function() return Running end,
    GetTargetId = function() return TARGET_UID end
}

print("✅ TeleportSystem Loaded (Smooth + Multi Recovery + Fast Check + No Stuck)")
