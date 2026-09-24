-- ==================================================
-- YOKUDO HUB | FEATURE | VIPTP (AFK Farm Only)
-- ដាច់ដោយឡែកសម្រាប់ AFK Farm
-- Speed: Fly 1000 | Return 800 | Offset 15
-- Method: InstantTeleport
-- Task spawn + Task workspace
-- ✅ Register ជាមួយ CharacterSystem
-- ✅ Callback ទៅ FarmingManager ពេល AutoStop
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
    warn("[VIPTP] CollectEvent not found")
    return
end

print("[VIPTP] CollectEvent OK")

-- ==================================================
-- SETTINGS (កំណត់ក្នុង file ខ្លួនឯង)
-- ==================================================
local TARGET_UID = nil
local SAFE_ZONE = Vector3.new(533, 70, -366)

local FLY_SPEED = 1000
local RETURN_SPEED = 800
local FLY_OFFSET = 15

local SHOT_DISTANCE = 15
local LOCK_ABOVE = 2        -- Lock Y + 2
local DROP_DISTANCE = 5     -- Distance > 5 = Drop

local ARRIVE_DISTANCE = 2
local SAFE_LOCK_DISTANCE = 3
local TIMEOUT_SECONDS = 30

local COLLECT_INTERVAL = 0.2
local SEARCH_PREFIX = "FirstAreaEgg"
local POSITION_THRESHOLD = 1

local LOCK_POSITION = Vector3.new(
    607.6259155273438,
    70.57420349121094,
    -326.8830261230469
)

-- ==================================================
-- RAGDOLL BYPASS
-- ==================================================
local RagdollEnabled = false
local RagdollConnection = nil
local ForceUpConnection = nil

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
local FlyBackConnection = nil

local FirstEggList = {}
local FirstEggUid = nil
local FirstEggSlotKey = nil

local CollectAttempts = 0
local CollectTime = 0

local FlyTargetStarted = false
local CollectDone = false
local TargetCollected = false
local RemotesFired = false
local FlyBackActive = false

local SavedTargetPosition = nil
local SavedY = nil
local TargetLockedCFrame = nil

local SavedWalkSpeed = nil
local SavedJumpPower = nil
local SavedJumpHeight = nil
local SavedUseJumpPower = nil

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

    print("[VIPTP] Ragdoll Bypass: ON")
end

local function DisableRagdollBypass()
    if not RagdollEnabled then return end
    RagdollEnabled = false

    if RagdollConnection then
        RagdollConnection:Disconnect()
        RagdollConnection = nil
    end

    print("[VIPTP] Ragdoll Bypass: OFF")
end

-- ==================================================
-- SAVE / RESTORE STATS
-- ==================================================
local function SaveStats()
    local Hum = GetHumanoid()
    if not Hum then return end

    if SavedWalkSpeed == nil then SavedWalkSpeed = Hum.WalkSpeed end
    if SavedJumpPower == nil then SavedJumpPower = Hum.JumpPower end
    if SavedJumpHeight == nil then SavedJumpHeight = Hum.JumpHeight end
    if SavedUseJumpPower == nil then SavedUseJumpPower = Hum.UseJumpPower end
end

local function RestoreStats()
    local Hum = GetHumanoid()
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
    if FlyBackConnection then
        FlyBackConnection:Disconnect()
        FlyBackConnection = nil
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

    local Hum, Root = GetHumanoid()
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
-- LOCK AT TARGET (Y+2)
-- ==================================================
local function StartLock(TargetPosition)
    TargetLockedCFrame = CFrame.new(TargetPosition + Vector3.new(0, LOCK_ABOVE, 0))

    if LockConnection then
        LockConnection:Disconnect()
    end

    LockConnection = RunService.Heartbeat:Connect(function()
        if not Running then
            if LockConnection then LockConnection:Disconnect() LockConnection = nil end
            return
        end

        local Hum, Root = GetHumanoid()
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
    local Hum, Root = GetHumanoid()
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
-- FLY TP
-- ==================================================
local function FlyTP(Destination, Speed, UseShotTP, IsSafeZone, Callback)
    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return end
    if Hum.Health <= 0 then return end

    local FlyPos = Vector3.new(Destination.X, Destination.Y + FLY_OFFSET, Destination.Z)
    local LockCFrame = CFrame.new(Destination + Vector3.new(0, LOCK_ABOVE, 0))

    Hum.PlatformStand = true

    BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.Name = "YokudoBV"
    BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    BodyVelocity.P = 1250
    BodyVelocity.Velocity = Vector3.zero
    BodyVelocity.Parent = Root

    BodyGyro = Instance.new("BodyGyro")
    BodyGyro.Name = "YokudoBG"
    BodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    BodyGyro.P = 3000
    BodyGyro.D = 500
    BodyGyro.CFrame = Root.CFrame
    BodyGyro.Parent = Root

    local StartTime = tick()
    local ShotDone = false

    FlyConnection = RunService.Heartbeat:Connect(function()
        if not Running then
            CleanupMovers()
            return
        end

        local Hum2, Root2 = GetHumanoid()
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

        if IsSafeZone then
            if HorizDist <= SAFE_LOCK_DISTANCE then
                CleanupMovers()
                Root2.CFrame = LockCFrame
                Root2.AssemblyLinearVelocity = Vector3.zero
                Root2.AssemblyAngularVelocity = Vector3.zero
                StartLock(Destination)
                if Callback then Callback() end
                return
            end
        end

        if not IsSafeZone and UseShotTP and not ShotDone and HorizDist <= SHOT_DISTANCE then
            ShotDone = true
            CleanupMovers()
            Root2.CFrame = LockCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero
            StartLock(Destination)
            if Callback then Callback() end
            return
        end

        if HorizDist <= ARRIVE_DISTANCE and VertDist <= 2 then
            CleanupMovers()
            Root2.CFrame = LockCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero
            StartLock(Destination)
            if Callback then Callback() end
            return
        end

        if tick() - StartTime > TIMEOUT_SECONDS then
            CleanupMovers()
            if Callback then Callback() end
            return
        end

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
    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return end
    if Hum.Health <= 0 then return end

    local LockCFrame = CFrame.new(Destination + Vector3.new(0, LOCK_ABOVE, 0))

    Root.CFrame = LockCFrame
    Root.AssemblyLinearVelocity = Vector3.zero
    Root.AssemblyAngularVelocity = Vector3.zero

    StartLock(Destination)

    if Callback then Callback() end
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

    print("[VIPTP] ForestStrike Fired")
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

-- ==================================================
-- AUTO STOP
-- ==================================================
local function AutoStop()
    Running = false
    CurrentStep = "done"

    CleanupMovers()
    DisableRagdollBypass()
    StopActiveHeartbeat()
    RestoreStats()

    print("[VIPTP] Auto Stop")

    -- ✅ Callback ទៅ FarmingManager
    if _G.YOKUDO_FarmingManager and _G.YOKUDO_FarmingManager.OnVIPTPComplete then
        task.spawn(function()
            task.wait(0.5)
            _G.YOKUDO_FarmingManager.OnVIPTPComplete()
        end)
    end
end

-- ==================================================
-- ✅ FLY BACK (Auto Check Distance)
-- ==================================================
local function StartFlyBack()
    if FlyBackActive then return end
    FlyBackActive = true

    print("[VIPTP] Fly Back Started (Auto Check Distance)")

    if FlyBackConnection then
        FlyBackConnection:Disconnect()
    end

    FlyBackConnection = RunService.Heartbeat:Connect(function()
        if not Running then
            if FlyBackConnection then FlyBackConnection:Disconnect() FlyBackConnection = nil end
            FlyBackActive = false
            return
        end

        local Hum, Root = GetHumanoid()
        if not Hum or not Root then return end
        if Hum.Health <= 0 then return end

        -- ពិនិត្យថា Egg នៅកន្លែងណា
        local TargetEgg = nil
        if IsTargetInWorkspace() then
            TargetEgg = workspace:FindFirstChild(TARGET_UID)
        elseif IsTargetInContainer() then
            TargetEgg = Container:FindFirstChild(TARGET_UID)
        end

        if not TargetEgg then return end

        local EggPos = GetPosition(TargetEgg)
        if not EggPos then return end

        local Dist = (EggPos - Root.Position).Magnitude

        if Dist > DROP_DISTANCE then
            print("[VIPTP] Egg Drop Detected! Dist: " .. math.floor(Dist) .. " → Fly Back")

            if FlyBackConnection then
                FlyBackConnection:Disconnect()
                FlyBackConnection = nil
            end
            FlyBackActive = false

            -- FlyTP ទៅយក Egg (Speed 1000)
            FlyTP(EggPos, FLY_SPEED, true, false, function()
                -- ពេលដល់ Egg → Lock Y + 2
                StartLock(EggPos)

                -- Save Y
                local EggY = EggPos.Y
                SavedY = EggY

                print("[VIPTP] Fly Back → Lock at Egg | Saved Y: " .. tostring(EggY))

                -- Auto Collect រហូត Y Change
                task.spawn(function()
                    while Running do
                        local Egg2 = nil
                        if IsTargetInWorkspace() then
                            Egg2 = workspace:FindFirstChild(TARGET_UID)
                        elseif IsTargetInContainer() then
                            Egg2 = Container:FindFirstChild(TARGET_UID)
                        end

                        if not Egg2 then
                            -- Egg បាត់ → Collect បាន
                            print("[VIPTP] Fly Back → Egg Collected!")
                            break
                        end

                        local Pos2 = GetPosition(Egg2)
                        if Pos2 then
                            local NewY = Pos2.Y
                            if math.abs(NewY - SavedY) >= POSITION_THRESHOLD then
                                print("[VIPTP] Fly Back → Y Change! " .. tostring(SavedY) .. " → " .. tostring(NewY))
                                break
                            end
                        end

                        -- Collect
                        RemoteCollectTarget()
                        task.wait(COLLECT_INTERVAL)
                    end

                    -- Y Change → FlyTP ទៅ Safe Zone
                    if Running then
                        print("[VIPTP] Fly Back → Y Change → FlyTP to Safe Zone")
                        FlyTP(SAFE_ZONE, RETURN_SPEED, false, true, function()
                            -- ពេលដល់ Safe Zone → Check TARGET_UID ម្តងទៀត
                            task.wait(0.5)
                            CheckTargetAtSafeZone()
                        end)
                    end
                end)
            end)
        end
    end)
end

-- ==================================================
-- ✅ CHECK TARGET AT SAFE ZONE
-- ==================================================
function CheckTargetAtSafeZone()
    if not Running then return end

    print("[VIPTP] At Safe Zone → Check TARGET_UID")

    if IsTargetInWorkspace() then
        print("[VIPTP] Target found in Workspace → Task workspace")
        StartTask("workspace")
    elseif IsTargetInContainer() then
        print("[VIPTP] Target found in Container → Task spawn")
        StartTask("spawn")
    else
        print("[VIPTP] Target not found → Done")
        AutoStop()
    end
end

-- ==================================================
-- ✅ START TASK (spawn ឬ workspace)
-- ==================================================
function StartTask(Mode)
    if not Running then return end

    CurrentMode = Mode
    print("[VIPTP] Starting Task: " .. Mode)

    -- Reset flags
    FlyTargetStarted = false
    CollectDone = false
    TargetCollected = false
    RemotesFired = false
    FlyBackActive = false
    SavedY = nil

    -- Search First Eggs
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

    print("[VIPTP] FlyTP to First Egg (Shot TP)")
    FlyTP(EggPos, FLY_SPEED, true, false, function()
        CurrentStep = "collect_first"
    end)
end

-- ==================================================
-- HEARTBEAT
-- ==================================================
function StartActiveHeartbeat()
    if ActiveHeartbeat then
        ActiveHeartbeat:Disconnect()
        ActiveHeartbeat = nil
    end

    ActiveHeartbeat = RunService.Heartbeat:Connect(function()
        if not Running then return end

        local Hum, Root = GetHumanoid()
        if not Hum or not Root then return end
        if Hum.Health <= 0 then return end

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

        -- ✅ Task spawn: រង់ចាំ First Egg ចូល Container វិញ
        if CurrentMode == "spawn" then
            if CurrentStep == "wait_spawn_back" and not FlyTargetStarted then
                if IsFirstEggInContainer() then
                    FlyTargetStarted = true
                    task.spawn(function()
                        StartFlyToTarget()
                    end)
                end
            end
        end

        -- ✅ Task workspace: Instant TP ទៅ Target ភ្លាម
        if CurrentMode == "workspace" then
            if CurrentStep == "collect_first" and CollectDone and not FlyTargetStarted then
                FlyTargetStarted = true
                task.spawn(function()
                    StartFlyToTarget()
                end)
            end
        end

        if CurrentStep == "collect_target" and not TargetCollected then
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

            if tick() - CollectTime > COLLECT_INTERVAL then
                CollectTime = tick()
                RemoteCollectTarget()
                CollectAttempts = CollectAttempts + 1
            end
        end
    end)
end

function StopActiveHeartbeat()
    if ActiveHeartbeat then
        ActiveHeartbeat:Disconnect()
        ActiveHeartbeat = nil
    end
end

-- ==================================================
-- FLY TO TARGET
-- ==================================================
function StartFlyToTarget()
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

    -- Instant TP ទៅ Target Egg
    print("[VIPTP] Instant TP to Target Egg")
    InstantFlyTP(TargetPos, function()
        -- Lock Y + 2
        StartLock(TargetPos)

        -- Save Y (Task workspace)
        if CurrentMode == "workspace" then
            SavedY = TargetPos.Y
            print("[VIPTP] Task workspace → Saved Y: " .. tostring(SavedY))
        end

        CurrentStep = "collect_target"
    end)
end

-- ==================================================
-- FLY TO SAFE (NO SHOT TP)
-- ==================================================
local function FlyToSafeZone()
    CurrentStep = "to_safe"

    print("[VIPTP] FlyTP to Safe Zone")

    FlyTP(SAFE_ZONE, RETURN_SPEED, false, true, function()
        -- ពេលដល់ Safe Zone → Check TARGET_UID ម្តងទៀត
        task.wait(0.5)
        CheckTargetAtSafeZone()
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
    FlyTargetStarted = false
    CollectDone = false
    TargetCollected = false
    RemotesFired = false
    FlyBackActive = false
    SavedTargetPosition = nil
    SavedY = nil
    TargetLockedCFrame = nil

    CleanupMovers()
    DisableRagdollBypass()
    StopActiveHeartbeat()
    RestoreStats()

    print("[VIPTP] Full Reset")
end

-- ==================================================
-- ENABLE / DISABLE / SET
-- ==================================================
local function Enable()
    if Running then return end
    if not CollectEvent then warn("[VIPTP] CollectEvent not found") return end
    if not TARGET_UID then warn("[VIPTP] No Target ID") return end

    FullReset()
    Running = true

    SaveStats()
    EnableRagdollBypass()

    -- ✅ Check Egg នៅកន្លែងណា ដើម្បីកំណត់ Mode
    if IsTargetInContainer() then
        print("[VIPTP] Target in Container → Task spawn")
        StartTask("spawn")
    elseif IsTargetInWorkspace() then
        print("[VIPTP] Target in Workspace → Task workspace")
        local WSEgg = workspace:FindFirstChild(TARGET_UID)
        if WSEgg then
            SavedTargetPosition = GetPosition(WSEgg)
        end
        StartTask("workspace")
    else
        -- រង់ចាំ Egg លេចឡើង
        task.spawn(function()
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
                StartTask("spawn")
            elseif IsTargetInWorkspace() then
                local WSEgg = workspace:FindFirstChild(TARGET_UID)
                if WSEgg then
                    SavedTargetPosition = GetPosition(WSEgg)
                end
                StartTask("workspace")
            end
        end)
    end

    print("[VIPTP] ON | Target: " .. tostring(TARGET_UID))
end

local function Disable()
    FullReset()
    print("[VIPTP] OFF")
end

local function SetTargetId(Id)
    TARGET_UID = Id
    print("[VIPTP] Target ID: " .. tostring(Id))
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_VIPTP = {
    Enable = Enable,
    Disable = Disable,
    SetTargetId = SetTargetId,
    IsEnabled = function() return Running end,
    GetTargetId = function() return TARGET_UID end,
    GetMode = function() return CurrentMode end,
    FLY_SPEED = FLY_SPEED,
    RETURN_SPEED = RETURN_SPEED,
    FLY_OFFSET = FLY_OFFSET,
    LOCK_ABOVE = LOCK_ABOVE,
    DROP_DISTANCE = DROP_DISTANCE,
    SAFE_ZONE = SAFE_ZONE,
}

-- ==================================================
-- REGISTER WITH CHARACTER SYSTEM
-- ==================================================
if _G.YOKUDO_CharacterSystem then
    _G.YOKUDO_CharacterSystem:RegisterFeature({
        Name = "VIPTP",
        Enable = Enable,
        Disable = Disable,
        IsEnabled = function() return Running end,
        OnCharacterAdded = function(Char, Hum, Root)
            if Running then
                task.wait(1)
                pcall(function()
                    local TargetId = TARGET_UID
                    Disable()
                    task.wait(0.5)
                    if TargetId then
                        SetTargetId(TargetId)
                    end
                    Enable()
                end)
            end
        end
    })
end

print("✅ VIPTP Loaded (Task spawn + Task workspace + Fly Back)")
