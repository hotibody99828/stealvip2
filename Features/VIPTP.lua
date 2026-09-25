-- ==================================================
-- YOKUDO HUB | FEATURE | VIPTP (AFK Farm Only)
-- ដាច់ដោយឡែកសម្រាប់ AFK Farm
-- ✅ ប្រើ VIPTP_ Prefix ដើម្បីកុំឲ្យជាន់គ្នាជាមួយ TeleportSystem
-- ✅ រៀបចំ Function ត្រឹមត្រូវ ១០០% (គ្មាន Error)
-- Method: InstantTeleport (Fixed)
-- Fly Speed: 1000 | Return Speed: 1000
-- Fly Offset First: 5 | Fly Offset Safe: 50
-- ✅ Auto Callback ទៅ FarmingManager ពេល AutoStop
-- ✅ ForestStrike = Remote Drop Egg (First Egg Only)
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Container = workspace:WaitForChild("AreaEggSlotsClient")

-- ==================================================
-- REMOTES (VIPTP_ Prefix)
-- ==================================================
local VIPTP_CollectEvent = nil
local VIPTP_ForestStrike = nil

pcall(function()
    VIPTP_CollectEvent = ReplicatedStorage.Packages.Networking["RF/EggWorld/AskFieldEggCarry"]
end)

pcall(function()
    VIPTP_ForestStrike = ReplicatedStorage.Packages.Networking["RE/GuardPatrol/ForestStrike"]
end)

if not VIPTP_CollectEvent then
    warn("[VIPTP] CollectEvent not found")
    return
end

print("[VIPTP] CollectEvent OK")

-- ==================================================
-- SETTINGS (VIPTP_ Prefix)
-- ==================================================
local VIPTP_TARGET_UID = nil
local VIPTP_SAFE_ZONE = Vector3.new(533, 70, -366)

local VIPTP_FLY_SPEED = 1000
local VIPTP_RETURN_SPEED = 1000
local VIPTP_FLY_OFFSET_FIRST = 5
local VIPTP_FLY_OFFSET_SAFE = 50

local VIPTP_SHOT_DISTANCE = 30
local VIPTP_LOCK_ABOVE = 1

local VIPTP_ARRIVE_DISTANCE = 5
local VIPTP_SAFE_LOCK_DISTANCE = 5
local VIPTP_TIMEOUT_SECONDS = 15

local VIPTP_COLLECT_INTERVAL = 0.2
local VIPTP_SEARCH_PREFIX = "FirstAreaEgg"
local VIPTP_POSITION_THRESHOLD = 1

local VIPTP_LOCK_POSITION = Vector3.new(
    607.6259155273438,
    70.57420349121094,
    -326.8830261230469
)

-- ==================================================
-- RAGDOLL BYPASS (VIPTP_ Prefix)
-- ==================================================
local VIPTP_RagdollEnabled = false
local VIPTP_RagdollConnection = nil
local VIPTP_ForceUpConnection = nil

-- ==================================================
-- STATE (VIPTP_ Prefix)
-- ==================================================
local VIPTP_Running = false
local VIPTP_CurrentStep = "idle"
local VIPTP_CurrentMode = "none"

local VIPTP_FlyConnection = nil
local VIPTP_BodyVelocity = nil
local VIPTP_BodyGyro = nil
local VIPTP_ActiveHeartbeat = nil
local VIPTP_LockConnection = nil

local VIPTP_FirstEggList = {}
local VIPTP_FirstEggUid = nil
local VIPTP_FirstEggSlotKey = nil

local VIPTP_CollectAttempts = 0
local VIPTP_CollectTime = 0

local VIPTP_FlyTargetStarted = false
local VIPTP_CollectDone = false
local VIPTP_TargetCollected = false
local VIPTP_ForestStrikeFired = false

local VIPTP_SavedTargetPosition = nil
local VIPTP_TargetLockedCFrame = nil

local VIPTP_SavedWalkSpeed = nil
local VIPTP_SavedJumpPower = nil
local VIPTP_SavedJumpHeight = nil
local VIPTP_SavedUseJumpPower = nil

-- ==================================================
-- FORWARD DECLARATIONS (ការពារ Error)
-- ==================================================
local VIPTP_StopActiveHeartbeat
local VIPTP_StartActiveHeartbeat
local VIPTP_StartFlyToTarget
local VIPTP_AutoStop
local VIPTP_FlyUpAndToSafeZone
local VIPTP_StartProcess

-- ==================================================
-- GET HUMANOID
-- ==================================================
local function VIPTP_GetHumanoid()
    local Char = Player.Character
    if not Char then return nil, nil end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    local Root = Char:FindFirstChild("HumanoidRootPart")
    return Hum, Root
end

-- ==================================================
-- RAGDOLL BYPASS
-- ==================================================
local function VIPTP_ForceUp()
    local Hum, Root = VIPTP_GetHumanoid()
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

local function VIPTP_CleanupRagdollConstraints()
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

local function VIPTP_EnableRagdollBypass()
    if VIPTP_RagdollEnabled then return end
    VIPTP_RagdollEnabled = true

    VIPTP_RagdollConnection = RunService.Heartbeat:Connect(function()
        if not VIPTP_RagdollEnabled then return end
        VIPTP_ForceUp()
    end)

    VIPTP_ForceUpConnection = task.spawn(function()
        while VIPTP_RagdollEnabled do
            task.wait(0.1)
            VIPTP_ForceUp()
            VIPTP_CleanupRagdollConstraints()
        end
    end)

    print("[VIPTP] Ragdoll Bypass: ON")
end

local function VIPTP_DisableRagdollBypass()
    if not VIPTP_RagdollEnabled then return end
    VIPTP_RagdollEnabled = false

    if VIPTP_RagdollConnection then
        VIPTP_RagdollConnection:Disconnect()
        VIPTP_RagdollConnection = nil
    end

    print("[VIPTP] Ragdoll Bypass: OFF")
end

-- ==================================================
-- SAVE / RESTORE STATS
-- ==================================================
local function VIPTP_SaveStats()
    local Hum = VIPTP_GetHumanoid()
    if not Hum then return end

    if VIPTP_SavedWalkSpeed == nil then VIPTP_SavedWalkSpeed = Hum.WalkSpeed end
    if VIPTP_SavedJumpPower == nil then VIPTP_SavedJumpPower = Hum.JumpPower end
    if VIPTP_SavedJumpHeight == nil then VIPTP_SavedJumpHeight = Hum.JumpHeight end
    if VIPTP_SavedUseJumpPower == nil then VIPTP_SavedUseJumpPower = Hum.UseJumpPower end
end

local function VIPTP_RestoreStats()
    local Hum = VIPTP_GetHumanoid()
    if not Hum then return end

    if VIPTP_SavedWalkSpeed ~= nil then pcall(function() Hum.WalkSpeed = VIPTP_SavedWalkSpeed end) end
    if VIPTP_SavedJumpPower ~= nil then pcall(function() Hum.JumpPower = VIPTP_SavedJumpPower end) end
    if VIPTP_SavedJumpHeight ~= nil then pcall(function() Hum.JumpHeight = VIPTP_SavedJumpHeight end) end
    if VIPTP_SavedUseJumpPower ~= nil then pcall(function() Hum.UseJumpPower = VIPTP_SavedUseJumpPower end) end
end

-- ==================================================
-- CLEANUP
-- ==================================================
local function VIPTP_CleanupMovers()
    if VIPTP_FlyConnection then
        VIPTP_FlyConnection:Disconnect()
        VIPTP_FlyConnection = nil
    end
    if VIPTP_LockConnection then
        VIPTP_LockConnection:Disconnect()
        VIPTP_LockConnection = nil
    end
    if VIPTP_BodyVelocity then
        pcall(function()
            VIPTP_BodyVelocity.Velocity = Vector3.zero
            VIPTP_BodyVelocity.MaxForce = Vector3.zero
        end)
        VIPTP_BodyVelocity:Destroy()
        VIPTP_BodyVelocity = nil
    end
    if VIPTP_BodyGyro then
        pcall(function()
            VIPTP_BodyGyro.MaxTorque = Vector3.zero
        end)
        VIPTP_BodyGyro:Destroy()
        VIPTP_BodyGyro = nil
    end

    local Hum, Root = VIPTP_GetHumanoid()
    if Root then
        for _, Child in ipairs(Root:GetChildren()) do
            if Child.Name == "YokudoBV" or Child.Name == "YokudoBG" then
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
local function VIPTP_StartLock(TargetPosition)
    VIPTP_TargetLockedCFrame = CFrame.new(TargetPosition + Vector3.new(0, VIPTP_LOCK_ABOVE, 0))

    if VIPTP_LockConnection then
        VIPTP_LockConnection:Disconnect()
    end

    VIPTP_LockConnection = RunService.Heartbeat:Connect(function()
        if not VIPTP_Running then
            if VIPTP_LockConnection then VIPTP_LockConnection:Disconnect() VIPTP_LockConnection = nil end
            return
        end

        local Hum, Root = VIPTP_GetHumanoid()
        if not Root then return end

        Root.CFrame = VIPTP_TargetLockedCFrame
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end)
end

-- ==================================================
-- GET POSITION
-- ==================================================
local function VIPTP_GetPosition(Object)
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
-- SEARCH FIRST EGGS
-- ==================================================
local function VIPTP_SearchFirstEggs()
    VIPTP_FirstEggList = {}
    if not Container then return end

    for _, Slot in ipairs(Container:GetChildren()) do
        if string.find(Slot.Name, VIPTP_SEARCH_PREFIX) then
            local SlotNum = string.match(Slot.Name, "Slot_(%d+)")
            if SlotNum then
                table.insert(VIPTP_FirstEggList, {
                    Slot = Slot,
                    Uid = Slot.Name,
                    SlotKey = "Forest:Slot_" .. SlotNum,
                    SlotNum = tonumber(SlotNum)
                })
            end
        end
    end
end

local function VIPTP_FindClosestEgg()
    local Hum, Root = VIPTP_GetHumanoid()
    if not Root then return nil end

    local Closest = nil
    local ClosestDistance = 9999

    for _, Egg in ipairs(VIPTP_FirstEggList) do
        local Pos = VIPTP_GetPosition(Egg.Slot)
        if Pos then
            local Dist = (Pos - Root.Position).Magnitude
            if Dist < ClosestDistance then
                ClosestDistance = Dist
                Closest = Egg
            end
        end
    end

    if Closest then
        VIPTP_FirstEggUid = Closest.Uid
        VIPTP_FirstEggSlotKey = Closest.SlotKey
    end

    return Closest
end

-- ==================================================
-- FLY TP
-- ==================================================
local function VIPTP_FlyTP(Destination, Speed, Offset, UseShotTP, IsSafeZone, Callback)
    VIPTP_CleanupMovers()

    local Hum, Root = VIPTP_GetHumanoid()
    if not Hum or not Root then return end
    if Hum.Health <= 0 then return end

    local FlyPos = Vector3.new(Destination.X, Destination.Y + Offset, Destination.Z)
    local LockCFrame = CFrame.new(Destination + Vector3.new(0, VIPTP_LOCK_ABOVE, 0))

    Hum.PlatformStand = true

    VIPTP_BodyVelocity = Instance.new("BodyVelocity")
    VIPTP_BodyVelocity.Name = "YokudoBV"
    VIPTP_BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    VIPTP_BodyVelocity.P = 1250
    VIPTP_BodyVelocity.Velocity = Vector3.zero
    VIPTP_BodyVelocity.Parent = Root

    VIPTP_BodyGyro = Instance.new("BodyGyro")
    VIPTP_BodyGyro.Name = "YokudoBG"
    VIPTP_BodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    VIPTP_BodyGyro.P = 3000
    VIPTP_BodyGyro.D = 500
    VIPTP_BodyGyro.CFrame = Root.CFrame
    VIPTP_BodyGyro.Parent = Root

    local StartTime = tick()
    local ShotDone = false

    VIPTP_FlyConnection = RunService.Heartbeat:Connect(function()
        if not VIPTP_Running then
            VIPTP_CleanupMovers()
            return
        end

        local Hum2, Root2 = VIPTP_GetHumanoid()
        if not Hum2 or not Root2 then
            VIPTP_CleanupMovers()
            return
        end
        if Hum2.Health <= 0 then return end

        if not VIPTP_BodyVelocity or not VIPTP_BodyGyro then
            VIPTP_CleanupMovers()
            return
        end

        local CurrentPos = Root2.Position
        local Direction = (FlyPos - CurrentPos)
        local HorizDist = Vector3.new(Direction.X, 0, Direction.Z).Magnitude
        local VertDist = math.abs(Direction.Y)
        local TotalDist = Direction.Magnitude

        if IsSafeZone then
            if HorizDist <= VIPTP_SAFE_LOCK_DISTANCE then
                VIPTP_CleanupMovers()
                Root2.CFrame = LockCFrame
                Root2.AssemblyLinearVelocity = Vector3.zero
                Root2.AssemblyAngularVelocity = Vector3.zero
                VIPTP_StartLock(Destination)
                if Callback then Callback() end
                return
            end
        end

        if not IsSafeZone and UseShotTP and not ShotDone and HorizDist <= VIPTP_SHOT_DISTANCE then
            ShotDone = true
            VIPTP_CleanupMovers()
            Root2.CFrame = LockCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero
            VIPTP_StartLock(Destination)
            if Callback then Callback() end
            return
        end

        if HorizDist <= VIPTP_ARRIVE_DISTANCE and VertDist <= 2 then
            VIPTP_CleanupMovers()
            Root2.CFrame = LockCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero
            VIPTP_StartLock(Destination)
            if Callback then Callback() end
            return
        end

        if tick() - StartTime > VIPTP_TIMEOUT_SECONDS then
            VIPTP_CleanupMovers()
            if Callback then Callback() end
            return
        end

        if TotalDist > 1 then
            VIPTP_BodyVelocity.Velocity = Direction.Unit * Speed
        else
            VIPTP_BodyVelocity.Velocity = Vector3.zero
        end

        VIPTP_BodyGyro.CFrame = CFrame.new(CurrentPos, CurrentPos + Vector3.new(Direction.X, 0, Direction.Z))
    end)
end

-- ==================================================
-- INSTANT FLY TP
-- ==================================================
local function VIPTP_InstantFlyTP(Destination, Callback)
    VIPTP_CleanupMovers()

    local Hum, Root = VIPTP_GetHumanoid()
    if not Hum or not Root then return end
    if Hum.Health <= 0 then return end

    local LockCFrame = CFrame.new(Destination + Vector3.new(0, VIPTP_LOCK_ABOVE, 0))

    Root.CFrame = LockCFrame
    Root.AssemblyLinearVelocity = Vector3.zero
    Root.AssemblyAngularVelocity = Vector3.zero

    VIPTP_StartLock(Destination)

    if Callback then Callback() end
end

-- ==================================================
-- TELEPORT TO TARGET
-- ==================================================
local function VIPTP_TeleportToTarget(TargetPos, Callback)
    print("[VIPTP] Instant TP to Target")
    VIPTP_InstantFlyTP(TargetPos, Callback)
end

-- ==================================================
-- REMOTE COLLECT
-- ==================================================
local function VIPTP_RemoteCollectFirst()
    if not VIPTP_CollectEvent or not VIPTP_FirstEggSlotKey or not VIPTP_FirstEggUid then return false end
    local success = pcall(function()
        return VIPTP_CollectEvent:InvokeServer({
            FirstAreaSlotKey = VIPTP_FirstEggSlotKey,
            Uid = VIPTP_FirstEggUid
        })
    end)
    return success
end

local function VIPTP_RemoteCollectTarget()
    if not VIPTP_CollectEvent or not VIPTP_TARGET_UID then return false end
    local success = pcall(function()
        return VIPTP_CollectEvent:InvokeServer({
            Uid = VIPTP_TARGET_UID
        })
    end)
    return success
end

-- ==================================================
-- FIRE FOREST STRIKE
-- ==================================================
local function VIPTP_FireForestStrike()
    if VIPTP_ForestStrikeFired then return end
    VIPTP_ForestStrikeFired = true

    VIPTP_EnableRagdollBypass()

    pcall(function()
        VIPTP_ForestStrike:FireServer({
            EggUid = VIPTP_FirstEggUid,
            GuardCFrame = CFrame.new(VIPTP_LOCK_POSITION)
        })
    end)

    task.spawn(function()
        for i = 1, 10 do
            task.wait(0.05)
            VIPTP_ForceUp()
            VIPTP_CleanupRagdollConstraints()
        end
    end)

    print("[VIPTP] ForestStrike Fired (Drop First Egg)")
end

-- ==================================================
-- CHECK EGG
-- ==================================================
local function VIPTP_IsFirstEggInWorkspace()
    if not VIPTP_FirstEggUid then return false end
    return workspace:FindFirstChild(VIPTP_FirstEggUid) ~= nil
end

local function VIPTP_IsFirstEggInContainer()
    if not VIPTP_FirstEggUid then return false end
    if not Container then return false end
    return Container:FindFirstChild(VIPTP_FirstEggUid) ~= nil
end

local function VIPTP_IsTargetInContainer()
    if not VIPTP_TARGET_UID or not Container then return false end
    return Container:FindFirstChild(VIPTP_TARGET_UID) ~= nil
end

local function VIPTP_IsTargetInWorkspace()
    if not VIPTP_TARGET_UID then return false end
    return workspace:FindFirstChild(VIPTP_TARGET_UID) ~= nil
end

-- ==================================================
-- STOP ACTIVE HEARTBEAT
-- ==================================================
VIPTP_StopActiveHeartbeat = function()
    if VIPTP_ActiveHeartbeat then
        VIPTP_ActiveHeartbeat:Disconnect()
        VIPTP_ActiveHeartbeat = nil
    end
end

-- ==================================================
-- FLY TO TARGET (Forward Declaration)
-- ==================================================
VIPTP_StartFlyToTarget = function()
    if VIPTP_FlyTargetStarted then return end
    VIPTP_FlyTargetStarted = true

    VIPTP_CurrentStep = "to_target"

    local TargetPos = nil

    if VIPTP_CurrentMode == "spawn" then
        local TargetEgg = Container and Container:FindFirstChild(VIPTP_TARGET_UID)
        if TargetEgg then
            TargetPos = VIPTP_GetPosition(TargetEgg)
        end
    elseif VIPTP_CurrentMode == "workspace" then
        if VIPTP_SavedTargetPosition then
            TargetPos = VIPTP_SavedTargetPosition
        else
            local WSEgg = workspace:FindFirstChild(VIPTP_TARGET_UID)
            if WSEgg then
                TargetPos = VIPTP_GetPosition(WSEgg)
                VIPTP_SavedTargetPosition = TargetPos
            end
        end
    end

    if not TargetPos then
        VIPTP_AutoStop()
        return
    end

    VIPTP_TeleportToTarget(TargetPos, function()
        VIPTP_CurrentStep = "collect_target"
    end)
end

-- ==================================================
-- FLY UP + FLY TO SAFE ZONE (Forward Declaration)
-- ==================================================
VIPTP_FlyUpAndToSafeZone = function()
    VIPTP_CurrentStep = "fly_up"

    local Hum, Root = VIPTP_GetHumanoid()
    if not Root then
        VIPTP_AutoStop()
        return
    end

    local UpPosition = Vector3.new(VIPTP_SAFE_ZONE.X, VIPTP_SAFE_ZONE.Y + VIPTP_FLY_OFFSET_SAFE, VIPTP_SAFE_ZONE.Z)

    print("[VIPTP] Fly Up to Y+" .. VIPTP_FLY_OFFSET_SAFE .. " → " .. tostring(UpPosition))

    VIPTP_FlyTP(UpPosition, VIPTP_RETURN_SPEED, 0, false, false, function()
        print("[VIPTP] ✅ Reached Fly Up Offset → Fly to Safe Zone")

        VIPTP_FlyTP(VIPTP_SAFE_ZONE, VIPTP_RETURN_SPEED, 0, false, true, function()
            print("[VIPTP] ✅ Reached Safe Zone")
            VIPTP_AutoStop()
        end)
    end)
end

-- ==================================================
-- AUTO STOP (Forward Declaration)
-- ==================================================
VIPTP_AutoStop = function()
    VIPTP_Running = false
    VIPTP_CurrentStep = "done"

    VIPTP_CleanupMovers()
    VIPTP_DisableRagdollBypass()
    VIPTP_StopActiveHeartbeat()
    VIPTP_RestoreStats()

    print("[VIPTP] Auto Stop")

    if _G.YOKUDO_FarmingManager and _G.YOKUDO_FarmingManager.OnVIPTPComplete then
        task.spawn(function()
            task.wait(0.2)
            _G.YOKUDO_FarmingManager.OnVIPTPComplete()
        end)
    end
end

-- ==================================================
-- START ACTIVE HEARTBEAT (Forward Declaration)
-- ==================================================
VIPTP_StartActiveHeartbeat = function()
    if VIPTP_ActiveHeartbeat then
        VIPTP_ActiveHeartbeat:Disconnect()
        VIPTP_ActiveHeartbeat = nil
    end

    VIPTP_ActiveHeartbeat = RunService.Heartbeat:Connect(function()
        if not VIPTP_Running then return end

        local Hum, Root = VIPTP_GetHumanoid()
        if not Hum or not Root then return end
        if Hum.Health <= 0 then return end

        -- Step: Collect First Egg
        if VIPTP_CurrentStep == "collect_first" and not VIPTP_CollectDone then
            if VIPTP_IsFirstEggInWorkspace() then
                VIPTP_CollectDone = true
                VIPTP_FireForestStrike()
                VIPTP_CurrentStep = "wait_spawn_back"
                return
            end

            if tick() - VIPTP_CollectTime > VIPTP_COLLECT_INTERVAL then
                VIPTP_CollectTime = tick()

                if VIPTP_IsFirstEggInContainer() then
                    VIPTP_RemoteCollectFirst()
                    VIPTP_CollectAttempts = VIPTP_CollectAttempts + 1
                else
                    if VIPTP_IsFirstEggInWorkspace() then
                        VIPTP_CollectDone = true
                        VIPTP_FireForestStrike()
                        VIPTP_CurrentStep = "wait_spawn_back"
                    end
                end
            end
        end

        -- Step: Wait First Egg Back to Spawn
        if VIPTP_CurrentStep == "wait_spawn_back" and not VIPTP_FlyTargetStarted then
            if VIPTP_IsFirstEggInContainer() then
                print("[VIPTP] First Egg Back to Spawn → Stop Remote First")
                VIPTP_ForestStrikeFired = false
                task.spawn(function() VIPTP_StartFlyToTarget() end)
            end
        end

        -- Step: Collect Target Egg
        if VIPTP_CurrentStep == "collect_target" and not VIPTP_TargetCollected then
            if VIPTP_CurrentMode == "spawn" then
                if workspace:FindFirstChild(VIPTP_TARGET_UID) then
                    VIPTP_TargetCollected = true
                    task.spawn(function() VIPTP_FlyUpAndToSafeZone() end)
                    return
                end
            elseif VIPTP_CurrentMode == "workspace" then
                if VIPTP_SavedTargetPosition then
                    local WSEgg = workspace:FindFirstChild(VIPTP_TARGET_UID)
                    if WSEgg then
                        local CurrentPos = VIPTP_GetPosition(WSEgg)
                        if CurrentPos then
                            local Dist = (CurrentPos - VIPTP_SavedTargetPosition).Magnitude
                            if Dist >= VIPTP_POSITION_THRESHOLD then
                                VIPTP_TargetCollected = true
                                task.spawn(function() VIPTP_FlyUpAndToSafeZone() end)
                                return
                            end
                        end
                    end
                end
            end

            if tick() - VIPTP_CollectTime > VIPTP_COLLECT_INTERVAL then
                VIPTP_CollectTime = tick()
                VIPTP_RemoteCollectTarget()
                VIPTP_CollectAttempts = VIPTP_CollectAttempts + 1
            end
        end
    end)
end

-- ==================================================
-- MAIN PROCESS (Forward Declaration)
-- ==================================================
VIPTP_StartProcess = function()
    VIPTP_Running = true
    VIPTP_CurrentStep = "search"

    VIPTP_CollectAttempts = 0
    VIPTP_CollectTime = 0
    VIPTP_FlyTargetStarted = false
    VIPTP_CollectDone = false
    VIPTP_TargetCollected = false
    VIPTP_ForestStrikeFired = false
    VIPTP_SavedTargetPosition = nil
    VIPTP_TargetLockedCFrame = nil

    VIPTP_SaveStats()
    VIPTP_EnableRagdollBypass()

    -- Auto Detect Option (spawn or workspace)
    if VIPTP_IsTargetInContainer() then
        VIPTP_CurrentMode = "spawn"
        print("[VIPTP] Target found in Container → spawn mode")
    elseif VIPTP_IsTargetInWorkspace() then
        VIPTP_CurrentMode = "workspace"
        local WSEgg = workspace:FindFirstChild(VIPTP_TARGET_UID)
        if WSEgg then
            VIPTP_SavedTargetPosition = VIPTP_GetPosition(WSEgg)
        end
        print("[VIPTP] Target found in Workspace → workspace mode")
    else
        local WaitTime = 0
        while VIPTP_Running and not VIPTP_IsTargetInContainer() and not VIPTP_IsTargetInWorkspace() do
            task.wait(0.5)
            WaitTime = WaitTime + 0.5
            if WaitTime > 60 then
                VIPTP_AutoStop()
                return
            end
        end

        if VIPTP_IsTargetInContainer() then
            VIPTP_CurrentMode = "spawn"
        elseif VIPTP_IsTargetInWorkspace() then
            VIPTP_CurrentMode = "workspace"
            local WSEgg = workspace:FindFirstChild(VIPTP_TARGET_UID)
            if WSEgg then
                VIPTP_SavedTargetPosition = VIPTP_GetPosition(WSEgg)
            end
        end
    end

    VIPTP_SearchFirstEggs()

    if #VIPTP_FirstEggList == 0 then
        VIPTP_AutoStop()
        return
    end

    local Closest = VIPTP_FindClosestEgg()

    if not Closest then
        VIPTP_AutoStop()
        return
    end

    local EggPos = VIPTP_GetPosition(Closest.Slot)
    if not EggPos then
        VIPTP_AutoStop()
        return
    end

    VIPTP_CurrentStep = "fly_first"

    VIPTP_StartActiveHeartbeat()

    print("[VIPTP] FlyTP to First Egg (Shot TP, Offset " .. VIPTP_FLY_OFFSET_FIRST .. ")")
    VIPTP_FlyTP(EggPos, VIPTP_FLY_SPEED, VIPTP_FLY_OFFSET_FIRST, true, false, function()
        VIPTP_CurrentStep = "collect_first"
    end)
end

-- ==================================================
-- FULL RESET
-- ==================================================
local function VIPTP_FullReset()
    VIPTP_Running = false
    VIPTP_CurrentStep = "idle"
    VIPTP_CurrentMode = "none"

    VIPTP_FirstEggList = {}
    VIPTP_FirstEggUid = nil
    VIPTP_FirstEggSlotKey = nil
    VIPTP_CollectAttempts = 0
    VIPTP_CollectTime = 0
    VIPTP_FlyTargetStarted = false
    VIPTP_CollectDone = false
    VIPTP_TargetCollected = false
    VIPTP_ForestStrikeFired = false
    VIPTP_SavedTargetPosition = nil
    VIPTP_TargetLockedCFrame = nil

    VIPTP_CleanupMovers()
    VIPTP_DisableRagdollBypass()
    VIPTP_StopActiveHeartbeat()
    VIPTP_RestoreStats()

    print("[VIPTP] Full Reset")
end

-- ==================================================
-- ENABLE / DISABLE / SET
-- ==================================================
local function VIPTP_Enable()
    if VIPTP_Running then return end
    if not VIPTP_CollectEvent then warn("[VIPTP] CollectEvent not found") return end
    if not VIPTP_TARGET_UID then warn("[VIPTP] No Target ID") return end

    VIPTP_FullReset()
    VIPTP_StartProcess()

    print("[VIPTP] ON | Target: " .. tostring(VIPTP_TARGET_UID))
end

local function VIPTP_Disable()
    VIPTP_FullReset()
    print("[VIPTP] OFF")
end

local function VIPTP_SetTargetId(Id)
    VIPTP_TARGET_UID = Id
    print("[VIPTP] Target ID: " .. tostring(Id))
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_VIPTP = {
    Enable = VIPTP_Enable,
    Disable = VIPTP_Disable,
    SetTargetId = VIPTP_SetTargetId,
    IsEnabled = function() return VIPTP_Running end,
    GetTargetId = function() return VIPTP_TARGET_UID end,
    GetMode = function() return VIPTP_CurrentMode end,
    FLY_SPEED = VIPTP_FLY_SPEED,
    RETURN_SPEED = VIPTP_RETURN_SPEED,
    FLY_OFFSET_FIRST = VIPTP_FLY_OFFSET_FIRST,
    FLY_OFFSET_SAFE = VIPTP_FLY_OFFSET_SAFE,
    SAFE_ZONE = VIPTP_SAFE_ZONE,
}

print("✅ VIPTP Loaded (AFK Farm Only | VIPTP_ Prefix | Instant | First Offset 5 | Safe Offset 50 | ForestStrike First Only | Fixed All Errors)")
