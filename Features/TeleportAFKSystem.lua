-- ==================================================
-- YOKUDO HUB | FEATURE | Teleport AFK System
-- ដាច់ពី TeleportSystem ចាស់ទាំងស្រុង
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

-- ✅ AFK Container (ដាច់ពី TeleportSystem ចាស់)
local AFK_Container = workspace:WaitForChild("AreaEggSlotsClient")

-- ==================================================
-- ✅ AFK REMOTES (ដាច់ពី TeleportSystem ចាស់)
-- ==================================================
local AFK_CollectEvent = nil
local AFK_ForestStrike = nil

pcall(function()
    AFK_CollectEvent = ReplicatedStorage.Packages.Networking["RF/EggWorld/AskFieldEggCarry"]
end)

pcall(function()
    AFK_ForestStrike = ReplicatedStorage.Packages.Networking["RE/GuardPatrol/ForestStrike"]
end)

if not AFK_CollectEvent then
    warn("[YOKUDO] TeleportAFKSystem: AFK_CollectEvent not found")
    return
end

print("[YOKUDO] TeleportAFKSystem: AFK_CollectEvent OK")

-- ==================================================
-- ✅ AFK SETTINGS (ដាច់ពី TeleportSystem ចាស់)
-- ==================================================
local AFK_TARGET_UID = nil
local AFK_SAFE_ZONE = Vector3.new(533, 70, -366)

local AFK_FLY_OFFSET = 10
local AFK_FLY_SPEED = 1000
local AFK_RETURN_SPEED = 1000

local AFK_LOCK_ABOVE = 1
local AFK_SHOT_DISTANCE = 15

local AFK_ARRIVE_DISTANCE = 2
local AFK_SAFE_LOCK_DISTANCE = 3
local AFK_TIMEOUT_SECONDS = 30

local AFK_COLLECT_INTERVAL = 0.2
local AFK_SEARCH_PREFIX = "FirstAreaEgg"
local AFK_POSITION_THRESHOLD = 1

local AFK_LOCK_POSITION = Vector3.new(
    607.6259155273438,
    70.57420349121094,
    -326.8830261230469
)

-- ==================================================
-- ✅ AFK STATE (ដាច់ពី TeleportSystem ចាស់)
-- ==================================================
local AFK_RagdollEnabled = false
local AFK_RagdollConnection = nil
local AFK_ForceUpConnection = nil

local AFK_Running = false
local AFK_CurrentStep = "idle"
local AFK_CurrentMode = "none"

local AFK_FlyConnection = nil
local AFK_BodyVelocity = nil
local AFK_BodyGyro = nil
local AFK_ActiveHeartbeat = nil
local AFK_LockConnection = nil

local AFK_FirstEggList = {}
local AFK_FirstEggUid = nil
local AFK_FirstEggSlotKey = nil

local AFK_CollectAttempts = 0
local AFK_CollectTime = 0

local AFK_FlyTargetStarted = false
local AFK_CollectDone = false
local AFK_TargetCollected = false
local AFK_RemotesFired = false

local AFK_SavedTargetPosition = nil
local AFK_SavedTargetY = nil
local AFK_TargetLockedCFrame = nil

local AFK_SavedWalkSpeed = nil
local AFK_SavedJumpPower = nil
local AFK_SavedJumpHeight = nil
local AFK_SavedUseJumpPower = nil

-- ==================================================
-- GET HUMANOID
-- ==================================================
local function GetHumanoid()
    local Char = Player.Character
    if not Char then return nil, nil end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    local Root = Char:FindFirstChild("HumanoidRootPart")
    return Hum, Root
end

-- ==================================================
-- STOP LOCK
-- ==================================================
local function StopLock()
    if AFK_LockConnection then
        AFK_LockConnection:Disconnect()
        AFK_LockConnection = nil
        print("[YOKUDO] TeleportAFKSystem: Lock Stopped")
    end
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
    if AFK_RagdollEnabled then return end
    AFK_RagdollEnabled = true
    AFK_RagdollConnection = RunService.Heartbeat:Connect(function()
        if not AFK_RagdollEnabled then return end
        ForceUp()
    end)
    AFK_ForceUpConnection = task.spawn(function()
        while AFK_RagdollEnabled do
            task.wait(0.1)
            ForceUp()
            CleanupRagdollConstraints()
        end
    end)
    print("[YOKUDO] TeleportAFKSystem: Ragdoll Bypass ON")
end

local function DisableRagdollBypass()
    if not AFK_RagdollEnabled then return end
    AFK_RagdollEnabled = false
    if AFK_RagdollConnection then
        AFK_RagdollConnection:Disconnect()
        AFK_RagdollConnection = nil
    end
    print("[YOKUDO] TeleportAFKSystem: Ragdoll Bypass OFF")
end

-- ==================================================
-- SAVE / RESTORE STATS
-- ==================================================
local function SaveStats()
    local Hum = GetHumanoid()
    if not Hum then return end
    if AFK_SavedWalkSpeed == nil then AFK_SavedWalkSpeed = Hum.WalkSpeed end
    if AFK_SavedJumpPower == nil then AFK_SavedJumpPower = Hum.JumpPower end
    if AFK_SavedJumpHeight == nil then AFK_SavedJumpHeight = Hum.JumpHeight end
    if AFK_SavedUseJumpPower == nil then AFK_SavedUseJumpPower = Hum.UseJumpPower end
end

local function RestoreStats()
    local Hum = GetHumanoid()
    if not Hum then return end
    if AFK_SavedWalkSpeed ~= nil then pcall(function() Hum.WalkSpeed = AFK_SavedWalkSpeed end) end
    if AFK_SavedJumpPower ~= nil then pcall(function() Hum.JumpPower = AFK_SavedJumpPower end) end
    if AFK_SavedJumpHeight ~= nil then pcall(function() Hum.JumpHeight = AFK_SavedJumpHeight end) end
    if AFK_SavedUseJumpPower ~= nil then pcall(function() Hum.UseJumpPower = AFK_SavedUseJumpPower end) end
end

-- ==================================================
-- CLEANUP
-- ==================================================
local function CleanupMovers()
    if AFK_FlyConnection then
        AFK_FlyConnection:Disconnect()
        AFK_FlyConnection = nil
    end
    StopLock()
    if AFK_BodyVelocity then
        pcall(function()
            AFK_BodyVelocity.Velocity = Vector3.zero
            AFK_BodyVelocity.MaxForce = Vector3.zero
        end)
        AFK_BodyVelocity:Destroy()
        AFK_BodyVelocity = nil
    end
    if AFK_BodyGyro then
        pcall(function() AFK_BodyGyro.MaxTorque = Vector3.zero end)
        AFK_BodyGyro:Destroy()
        AFK_BodyGyro = nil
    end
    local Hum, Root = GetHumanoid()
    if Root then
        for _, Child in ipairs(Root:GetChildren()) do
            if Child.Name == "YokudoAFKBV" or Child.Name == "YokudoAFKBG" then
                pcall(function() Child:Destroy() end)
            end
        end
    end
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
-- LOCK AT TARGET
-- ==================================================
local function StartLock(TargetPosition)
    AFK_TargetLockedCFrame = CFrame.new(TargetPosition + Vector3.new(0, AFK_LOCK_ABOVE, 0))
    StopLock()
    AFK_LockConnection = RunService.Heartbeat:Connect(function()
        if not AFK_Running then
            StopLock()
            return
        end
        local Hum, Root = GetHumanoid()
        if not Root then return end
        Root.CFrame = AFK_TargetLockedCFrame
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
-- SEARCH FIRST EGGS (ប្រើ AFK_Container)
-- ==================================================
local function SearchFirstEggs()
    AFK_FirstEggList = {}
    if not AFK_Container then return end
    for _, Slot in ipairs(AFK_Container:GetChildren()) do
        if string.find(Slot.Name, AFK_SEARCH_PREFIX) then
            local SlotNum = string.match(Slot.Name, "Slot_(%d+)")
            if SlotNum then
                table.insert(AFK_FirstEggList, {
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
    local Hum, Root = GetHumanoid()
    if not Root then return nil end
    local Closest = nil
    local ClosestDistance = 9999
    for _, Egg in ipairs(AFK_FirstEggList) do
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
        AFK_FirstEggUid = Closest.Uid
        AFK_FirstEggSlotKey = Closest.SlotKey
    end
    return Closest
end

-- ==================================================
-- FLY TP
-- ==================================================
local function FlyTP(Destination, Speed, UseShotTP, IsSafeZone, Callback)
    CleanupMovers()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return end
    if Hum.Health <= 0 then return end

    local FlyPos = Vector3.new(Destination.X, Destination.Y + AFK_FLY_OFFSET, Destination.Z)
    local LockCFrame = CFrame.new(Destination + Vector3.new(0, AFK_LOCK_ABOVE, 0))

    Hum.PlatformStand = true

    AFK_BodyVelocity = Instance.new("BodyVelocity")
    AFK_BodyVelocity.Name = "YokudoAFKBV"
    AFK_BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    AFK_BodyVelocity.P = 1250
    AFK_BodyVelocity.Velocity = Vector3.zero
    AFK_BodyVelocity.Parent = Root

    AFK_BodyGyro = Instance.new("BodyGyro")
    AFK_BodyGyro.Name = "YokudoAFKBG"
    AFK_BodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    AFK_BodyGyro.P = 3000
    AFK_BodyGyro.D = 500
    AFK_BodyGyro.CFrame = Root.CFrame
    AFK_BodyGyro.Parent = Root

    local StartTime = tick()
    local ShotDone = false

    AFK_FlyConnection = RunService.Heartbeat:Connect(function()
        if not AFK_Running then CleanupMovers() return end
        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 then CleanupMovers() return end
        if Hum2.Health <= 0 then return end
        if not AFK_BodyVelocity or not AFK_BodyGyro then CleanupMovers() return end

        local CurrentPos = Root2.Position
        local Direction = (FlyPos - CurrentPos)
        local HorizDist = Vector3.new(Direction.X, 0, Direction.Z).Magnitude
        local VertDist = math.abs(Direction.Y)
        local TotalDist = Direction.Magnitude

        if IsSafeZone then
            if HorizDist <= AFK_SAFE_LOCK_DISTANCE then
                CleanupMovers()
                StopLock()
                Root2.CFrame = CFrame.new(AFK_SAFE_ZONE)
                Root2.AssemblyLinearVelocity = Vector3.zero
                Root2.AssemblyAngularVelocity = Vector3.zero
                if Callback then Callback() end
                return
            end
        end

        if not IsSafeZone and UseShotTP and not ShotDone and HorizDist <= AFK_SHOT_DISTANCE then
            ShotDone = true
            CleanupMovers()
            Root2.CFrame = LockCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero
            StartLock(Destination)
            if Callback then Callback() end
            return
        end

        if HorizDist <= AFK_ARRIVE_DISTANCE and VertDist <= 2 then
            CleanupMovers()
            Root2.CFrame = LockCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero
            StartLock(Destination)
            if Callback then Callback() end
            return
        end

        if tick() - StartTime > AFK_TIMEOUT_SECONDS then
            CleanupMovers()
            if Callback then Callback() end
            return
        end

        if TotalDist > 1 then
            AFK_BodyVelocity.Velocity = Direction.Unit * Speed
        else
            AFK_BodyVelocity.Velocity = Vector3.zero
        end
        AFK_BodyGyro.CFrame = CFrame.new(CurrentPos, CurrentPos + Vector3.new(Direction.X, 0, Direction.Z))
    end)
end

-- ==================================================
-- INSTANT TP
-- ==================================================
local function InstantTP(Destination, Callback)
    CleanupMovers()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return end
    if Hum.Health <= 0 then return end

    local LockCFrame = CFrame.new(Destination + Vector3.new(0, AFK_LOCK_ABOVE, 0))
    Root.CFrame = LockCFrame
    Root.AssemblyLinearVelocity = Vector3.zero
    Root.AssemblyAngularVelocity = Vector3.zero
    StartLock(Destination)
    if Callback then Callback() end
    print("[YOKUDO] TeleportAFKSystem: Instant TP")
end

-- ==================================================
-- REMOTE COLLECT (ប្រើ AFK_CollectEvent)
-- ==================================================
local function RemoteCollectFirst()
    if not AFK_CollectEvent or not AFK_FirstEggSlotKey or not AFK_FirstEggUid then return false end
    return pcall(function()
        return AFK_CollectEvent:InvokeServer({
            FirstAreaSlotKey = AFK_FirstEggSlotKey,
            Uid = AFK_FirstEggUid
        })
    end)
end

local function RemoteCollectTarget()
    if not AFK_CollectEvent or not AFK_TARGET_UID then return false end
    return pcall(function()
        return AFK_CollectEvent:InvokeServer({
            Uid = AFK_TARGET_UID
        })
    end)
end

-- ==================================================
-- FIRE FOREST STRIKE (ប្រើ AFK_ForestStrike)
-- ==================================================
local function FireForestStrike()
    if AFK_RemotesFired then return end
    AFK_RemotesFired = true
    EnableRagdollBypass()
    pcall(function()
        AFK_ForestStrike:FireServer({
            EggUid = AFK_FirstEggUid,
            GuardCFrame = CFrame.new(AFK_LOCK_POSITION)
        })
    end)
    task.spawn(function()
        for i = 1, 10 do
            task.wait(0.05)
            ForceUp()
            CleanupRagdollConstraints()
        end
    end)
    print("[YOKUDO] TeleportAFKSystem: ForestStrike Fired")
end

-- ==================================================
-- CHECK EGG (ប្រើ AFK_Container)
-- ==================================================
local function IsFirstEggInWorkspace()
    if not AFK_FirstEggUid then return false end
    return workspace:FindFirstChild(AFK_FirstEggUid) ~= nil
end

local function IsFirstEggInContainer()
    if not AFK_FirstEggUid then return false end
    if not AFK_Container then return false end
    return AFK_Container:FindFirstChild(AFK_FirstEggUid) ~= nil
end

local function IsTargetInContainer()
    if not AFK_TARGET_UID or not AFK_Container then return false end
    return AFK_Container:FindFirstChild(AFK_TARGET_UID) ~= nil
end

local function IsTargetInWorkspace()
    if not AFK_TARGET_UID then return false end
    return workspace:FindFirstChild(AFK_TARGET_UID) ~= nil
end

-- ==================================================
-- AUTO STOP
-- ==================================================
local function AutoStop()
    AFK_Running = false
    AFK_CurrentStep = "done"
    StopLock()
    CleanupMovers()
    DisableRagdollBypass()
    StopActiveHeartbeat()
    RestoreStats()
    print("[YOKUDO] TeleportAFKSystem: Auto Stop")
end

-- ==================================================
-- FLY TO TARGET
-- ==================================================
function StartFlyToTarget()
    if AFK_FlyTargetStarted then return end
    AFK_FlyTargetStarted = true
    AFK_CurrentStep = "to_target"

    local TargetPos = nil
    if AFK_CurrentMode == "spawn" then
        local TargetEgg = AFK_Container and AFK_Container:FindFirstChild(AFK_TARGET_UID)
        if TargetEgg then
            TargetPos = GetPosition(TargetEgg)
        end
    elseif AFK_CurrentMode == "workspace" then
        if AFK_SavedTargetPosition then
            TargetPos = AFK_SavedTargetPosition
        else
            local WSEgg = workspace:FindFirstChild(AFK_TARGET_UID)
            if WSEgg then
                TargetPos = GetPosition(WSEgg)
                AFK_SavedTargetPosition = TargetPos
            end
        end
    end

    if not TargetPos then AutoStop() return end

    InstantTP(TargetPos, function()
        AFK_CurrentStep = "collect_target"
    end)
end

-- ==================================================
-- FLY TO SAFE
-- ==================================================
local function FlyToSafeZone()
    AFK_CurrentStep = "to_safe"
    print("[YOKUDO] TeleportAFKSystem: Fly to Safe Zone")
    StopLock()
    FlyTP(AFK_SAFE_ZONE, AFK_RETURN_SPEED, false, true, function()
        AutoStop()
    end)
end

-- ==================================================
-- HEARTBEAT (Mode 1 + Mode 2)
-- ==================================================
function StartActiveHeartbeat()
    if AFK_ActiveHeartbeat then
        AFK_ActiveHeartbeat:Disconnect()
        AFK_ActiveHeartbeat = nil
    end
    AFK_ActiveHeartbeat = RunService.Heartbeat:Connect(function()
        if not AFK_Running then return end
        local Hum, Root = GetHumanoid()
        if not Hum or not Root then return end
        if Hum.Health <= 0 then return end

        if AFK_CurrentStep == "collect_first" and not AFK_CollectDone then
            if IsFirstEggInWorkspace() then
                AFK_CollectDone = true
                FireForestStrike()
                AFK_CurrentStep = "wait_spawn_back"
                return
            end
            if tick() - AFK_CollectTime > AFK_COLLECT_INTERVAL then
                AFK_CollectTime = tick()
                if IsFirstEggInContainer() then
                    RemoteCollectFirst()
                    AFK_CollectAttempts = AFK_CollectAttempts + 1
                else
                    if IsFirstEggInWorkspace() then
                        AFK_CollectDone = true
                        FireForestStrike()
                        AFK_CurrentStep = "wait_spawn_back"
                    end
                end
            end
        end

        if AFK_CurrentStep == "wait_spawn_back" and not AFK_FlyTargetStarted then
            if IsFirstEggInContainer() then
                task.spawn(function() StartFlyToTarget() end)
            end
        end

        if AFK_CurrentStep == "collect_target" and not AFK_TargetCollected then
            if AFK_CurrentMode == "spawn" then
                if workspace:FindFirstChild(AFK_TARGET_UID) then
                    AFK_TargetCollected = true
                    task.spawn(function() FlyToSafeZone() end)
                    return
                end
            elseif AFK_CurrentMode == "workspace" then
                if AFK_SavedTargetY then
                    local WSEgg = workspace:FindFirstChild(AFK_TARGET_UID)
                    if WSEgg then
                        local CurrentPos = GetPosition(WSEgg)
                        if CurrentPos then
                            local CurrentY = CurrentPos.Y
                            local DeltaY = math.abs(CurrentY - AFK_SavedTargetY)
                            if DeltaY >= AFK_POSITION_THRESHOLD then
                                AFK_TargetCollected = true
                                task.spawn(function() FlyToSafeZone() end)
                                return
                            end
                        end
                    end
                end
            end
            if tick() - AFK_CollectTime > AFK_COLLECT_INTERVAL then
                AFK_CollectTime = tick()
                RemoteCollectTarget()
                AFK_CollectAttempts = AFK_CollectAttempts + 1
            end
        end
    end)
end

function StopActiveHeartbeat()
    if AFK_ActiveHeartbeat then
        AFK_ActiveHeartbeat:Disconnect()
        AFK_ActiveHeartbeat = nil
    end
end

-- ==================================================
-- MAIN PROCESS (Mode 1 + Mode 2)
-- ==================================================
local function StartProcess()
    AFK_Running = true
    AFK_CurrentStep = "search"

    AFK_CollectAttempts = 0
    AFK_CollectTime = 0
    AFK_FlyTargetStarted = false
    AFK_CollectDone = false
    AFK_TargetCollected = false
    AFK_RemotesFired = false
    AFK_SavedTargetPosition = nil
    AFK_SavedTargetY = nil
    AFK_TargetLockedCFrame = nil

    SaveStats()
    EnableRagdollBypass()

    if IsTargetInContainer() then
        AFK_CurrentMode = "spawn"
        print("[YOKUDO] TeleportAFKSystem: Mode 1 (spawn)")
    elseif IsTargetInWorkspace() then
        AFK_CurrentMode = "workspace"
        local WSEgg = workspace:FindFirstChild(AFK_TARGET_UID)
        if WSEgg then
            AFK_SavedTargetPosition = GetPosition(WSEgg)
            AFK_SavedTargetY = AFK_SavedTargetPosition.Y
        end
        print("[YOKUDO] TeleportAFKSystem: Mode 2 (workspace)")
    else
        print("[YOKUDO] TeleportAFKSystem: Target not found → AutoStop")
        AutoStop()
        return
    end

    SearchFirstEggs()
    if #AFK_FirstEggList == 0 then AutoStop() return end

    local Closest = FindClosestEgg()
    if not Closest then AutoStop() return end

    local EggPos = GetPosition(Closest.Slot)
    if not EggPos then AutoStop() return end

    AFK_CurrentStep = "fly_first"
    StartActiveHeartbeat()

    print("[YOKUDO] TeleportAFKSystem: Fly to First Egg")
    FlyTP(EggPos, AFK_FLY_SPEED, true, false, function()
        AFK_CurrentStep = "collect_first"
    end)
end

-- ==================================================
-- FULL RESET
-- ==================================================
local function FullReset()
    AFK_Running = false
    AFK_CurrentStep = "idle"
    AFK_CurrentMode = "none"

    AFK_FirstEggList = {}
    AFK_FirstEggUid = nil
    AFK_FirstEggSlotKey = nil
    AFK_CollectAttempts = 0
    AFK_CollectTime = 0
    AFK_FlyTargetStarted = false
    AFK_CollectDone = false
    AFK_TargetCollected = false
    AFK_RemotesFired = false
    AFK_SavedTargetPosition = nil
    AFK_SavedTargetY = nil
    AFK_TargetLockedCFrame = nil

    StopLock()
    CleanupMovers()
    DisableRagdollBypass()
    StopActiveHeartbeat()
    RestoreStats()
    print("[YOKUDO] TeleportAFKSystem: Full Reset")
end

-- ==================================================
-- ENABLE / DISABLE / SET
-- ==================================================
local function Enable()
    if AFK_Running then return end
    if not AFK_CollectEvent then warn("[YOKUDO] TeleportAFKSystem: AFK_CollectEvent not found") return end
    if not AFK_TARGET_UID then warn("[YOKUDO] TeleportAFKSystem: No Target ID") return end

    FullReset()
    StartProcess()
    print("[YOKUDO] TeleportAFKSystem: ON")
end

local function Disable()
    FullReset()
    print("[YOKUDO] TeleportAFKSystem: OFF")
end

local function SetTargetId(Id)
    AFK_TARGET_UID = Id
    print("[YOKUDO] TeleportAFKSystem Target ID: " .. tostring(Id))
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_TeleportAFKSystem = {
    Enable = Enable,
    Disable = Disable,
    SetTargetId = SetTargetId,
    IsEnabled = function() return AFK_Running end,
    GetTargetId = function() return AFK_TARGET_UID end
}

print("✅ TeleportAFKSystem Loaded (ដាច់ពី TeleportSystem ចាស់)")
