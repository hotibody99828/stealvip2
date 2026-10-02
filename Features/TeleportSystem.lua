-- ==================================================
-- YOKUDO HUB | TELEPORT SYSTEM (SMART SAFE v33)
-- ✅ Fix ALL Errors (Line 741 + Line 685 + Line 213)
-- ✅ Nearest First Egg — ជិតបំផុត
-- ✅ Collect Timeout 20s
-- ✅ After Complete → Call Manager → Check New First Egg
-- ✅ Simple Logic
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
    ArriveDistance = 2,
    LockDistance = 1,
    FlyTPDistance = 20,
    FlyOffset = 3,
    StopShotDistance = 1200,
    ShotTPTime = 1.30,
    ShotTPTime2 = 1.30,
    PushUpOffset = 50,
    PlayerCheckDistance = 30,
    LockWait = 0.1,
    RecoverDistanceThreshold = 500,
    MaxRepeatCount = 10,

    CollectTimeout = 20,           -- ✅ 20s
    CollectCheckInterval = 0.5,

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
-- MAP POSITIONS
-- ==================================================
local MapPositions = {
    {Pos = Vector3.new(5666, 70, -329), MapId = 1},
    {Pos = Vector3.new(4798, 70, -333), MapId = 2},
    {Pos = Vector3.new(4031, 70, -396), MapId = 3},
    {Pos = Vector3.new(3397, 70, -328), MapId = 4},
    {Pos = Vector3.new(2815, 70, -398), MapId = 5},
    {Pos = Vector3.new(2286, 70, -331), MapId = 6},
    {Pos = Vector3.new(1877, 70, -390), MapId = 7},
    {Pos = Vector3.new(1488, 70, -318), MapId = 8},
    {Pos = Vector3.new(1187, 70, -406), MapId = 9},
    {Pos = Vector3.new(950, 70, -328), MapId = 10},
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
    CollectStartTime = nil,

    SavedWalkSpeed = nil,
    SavedJumpPower = nil,
    SavedJumpHeight = nil,
    SavedUseJumpPower = nil,

    FlySequence = 0,
    FirstDropDone = false,
    RepeatCount = 0,
    IsRecoverMode = false,

    SafePosition = nil,
    SafeName = nil,
    CurrentEggUid = nil,
    EggGoneCheckThread = nil,

    OnComplete = nil,
}

-- ==================================================
-- FORWARD DECLARATIONS
-- ==================================================
local GetHumanoid
local GetPosition
local SavePlayerStats
local RestoreStats
local CleanupMovers
local IsEggGone
local GetNearestMapWait
local GetSafePosition
local GetPlayerSpeed
local PushUp
local CFrameInstant
local RemoteCollectFirst
local RemoteCollectTarget
local RemoteDrop
local StartLock
local StopLock
local FlyTPAndLock
local ShotTP
local ShotTPWithStop
local WalkTP
local AutoStop
local Step1_WalkToFirstEgg
local Step3b_AfterDropFirst
local Step4_WalkToTargetAndFlyLock
local Step7_ShotToSafePosition
local Step8b_WalkToCollectAgain
local Step8c_CheckDistanceAndRecover
local Step9_WalkToSwapPosition
local StartEggGoneCheck
local StartCollectTimeout
local SetupDropHeldEgg
local StartProcess
local FullReset
local NotifyComplete

-- ==================================================
-- UTILS
-- ==================================================
GetHumanoid = function()
    local Player = Players.LocalPlayer
    if not Player then return nil, nil end
    
    local Char = Player.Character
    if not Char then return nil, nil end
    
    if not Char.Parent then return nil, nil end
    
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    if not Hum then return nil, nil end
    
    local Root = Char:FindFirstChild("HumanoidRootPart")
    if not Root then return nil, nil end
    
    if Hum.Health <= 0 then return nil, nil end
    
    return Hum, Root
end

GetPosition = function(Object)
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

GetPlayerSpeed = function()
    if State.SavedWalkSpeed and State.SavedWalkSpeed > 0 then
        return State.SavedWalkSpeed
    end
    local Hum = GetHumanoid()
    if Hum then
        return Hum.WalkSpeed
    end
    return 16
end

SavePlayerStats = function()
    local Hum, Root = GetHumanoid()
    if not Hum then return end

    State.SavedWalkSpeed = Hum.WalkSpeed
    State.SavedJumpPower = Hum.JumpPower
    State.SavedJumpHeight = Hum.JumpHeight
    State.SavedUseJumpPower = Hum.UseJumpPower

    print(string.format("[TeleportSystem] ✅ Saved WalkSpeed: %.1f | JumpPower: %.1f",
        State.SavedWalkSpeed, State.SavedJumpPower))
end

RestoreStats = function()
    local Hum, Root = GetHumanoid()
    if not Hum then return end
    if not Root then return end

    if State.SavedWalkSpeed ~= nil then
        pcall(function() Hum.WalkSpeed = State.SavedWalkSpeed end)
        print(string.format("[TeleportSystem] ✅ Restored WalkSpeed: %.1f", State.SavedWalkSpeed))
    end
end

CleanupMovers = function()
    if State.WalkConnection then State.WalkConnection:Disconnect() State.WalkConnection = nil end
    if State.FlyConnection then State.FlyConnection:Disconnect() State.FlyConnection = nil end
    if State.LockConnection then State.LockConnection:Disconnect() State.LockConnection = nil end

    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return end
    
    pcall(function()
        Hum.PlatformStand = false
        Hum.Sit = false
    end)
    pcall(function()
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end)
end

IsEggGone = function(Uid)
    if not Uid then return true end
    local InWorkspace = workspace:FindFirstChild(Uid) ~= nil
    local InContainer = Container and Container:FindFirstChild(Uid) ~= nil
    if not InWorkspace and not InContainer then return true end
    return false
end

GetNearestMapWait = function(EggPos)
    if not EggPos then return 8 end
    
    local NearestDist = math.huge
    local NearestMapId = 1
    local NearestMapName = "Unknown"
    
    for _, MapData in ipairs(MapPositions) do
        local Dist = (EggPos - MapData.Pos).Magnitude
        if Dist < NearestDist then
            NearestDist = Dist
            NearestMapId = MapData.MapId
        end
    end
    
    local Wait = 8
    
    if _G.YOKUDO_MapSettings then
        Wait = _G.YOKUDO_MapSettings.GetMapWait(NearestMapId)
        local MapInfo = _G.YOKUDO_MapSettings.GetMapData(NearestMapId)
        if MapInfo then
            NearestMapName = MapInfo.Name
        end
    end
    
    print(string.format("[TeleportSystem] 🗺️ %s (Map %d) | Wait: %d | Dist: %.1f",
        NearestMapName, NearestMapId, Wait, NearestDist))
    
    return Wait
end

GetSafePosition = function()
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

    local SafePos = P1_Top1
    local SafeName = "P1_Top1"

    if P1_Top1_MinDist < Config.PlayerCheckDistance and P2_Top1_MinDist >= P1_Top1_MinDist then
        SafePos = P2_Top1
        SafeName = "P2_Top1"
    end

    State.SafePosition = SafePos
    State.SafeName = SafeName
    return SafePos, SafeName
end

PushUp = function(Offset, Callback)
    CleanupMovers()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root then
        if Callback then Callback() end
        return
    end

    local TargetPos = Root.Position + Vector3.new(0, Offset, 0)

    pcall(function()
        Hum.PlatformStand = true
        Root.CFrame = CFrame.new(TargetPos)
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end)

    if Callback then Callback() end
end

CFrameInstant = function(Destination, Callback)
    CleanupMovers()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root then
        if Callback then Callback() end
        return
    end
    
    if not Destination then
        if Callback then Callback() end
        return
    end

    pcall(function()
        Hum:MoveTo(Root.Position)
        Hum.WalkSpeed = 0
        Root.CFrame = CFrame.new(Destination)
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end)

    if Callback then Callback() end
end

RemoteCollectFirst = function()
    if not CollectEvent or not State.FirstEggSlotKey or not State.FirstEggUid then return false end
    return pcall(function()
        return CollectEvent:InvokeServer({
            FirstAreaSlotKey = State.FirstEggSlotKey,
            Uid = State.FirstEggUid
        })
    end)
end

RemoteCollectTarget = function()
    if not CollectEvent or not State.TargetUid then return false end
    return pcall(function()
        return CollectEvent:InvokeServer({ Uid = State.TargetUid })
    end)
end

RemoteDrop = function()
    if not DropEvent then return false end
    local Success, Result = pcall(function()
        return DropEvent:InvokeServer({ Reason = "PlayerRequest" })
    end)
    return Success and Result
end

StartLock = function(TargetPos)
    if not TargetPos then return end
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

StopLock = function()
    if State.LockConnection then
        State.LockConnection:Disconnect()
        State.LockConnection = nil
    end
end

-- ==================================================
-- ✅ FLY TP AND LOCK (Safe Check ALL)
-- ==================================================
FlyTPAndLock = function(Destination, YOffset, Callback)
    CleanupMovers()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root then
        if Callback then Callback() end
        return
    end
    
    if not Destination then
        warn("[TeleportSystem] ⚠️ FlyTPAndLock: Destination is nil!")
        if Callback then Callback() end
        return
    end
    
    if typeof(Destination) ~= "Vector3" then
        warn("[TeleportSystem] ⚠️ FlyTPAndLock: Destination is not Vector3!")
        if Callback then Callback() end
        return
    end

    local PlayerSpeed = GetPlayerSpeed()
    print(string.format("[TeleportSystem] ✈️ FlyTP | Speed: %.1f", PlayerSpeed))

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
        if not Hum2 or not Root2 then CleanupMovers() return end
        
        if not Destination then CleanupMovers() return end
        
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
        local MoveStep = Dir.Unit * PlayerSpeed * (1/60)
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
-- ✅ SHOT TP (Safe Check ALL)
-- ==================================================
ShotTP = function(Destination, Time, CheckDrop, Callback)
    CleanupMovers()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root then
        if Callback then Callback() end
        return
    end
    
    if not Destination then
        warn("[TeleportSystem] ⚠️ ShotTP: Destination is nil!")
        if Callback then Callback() end
        return
    end
    
    if typeof(Destination) ~= "Vector3" then
        warn("[TeleportSystem] ⚠️ ShotTP: Destination is not Vector3!")
        if Callback then Callback() end
        return
    end

    local PlayerSpeed = GetPlayerSpeed()
    print(string.format("[TeleportSystem] ✈️ ShotTP | Speed: %.1f", PlayerSpeed))

    local TargetCFrame = CFrame.new(Destination)
    local StartPos = Root.Position
    local StartTime = tick()
    Hum.PlatformStand = true
    local ShotStopRequested = false

    State.FlyConnection = RunService.Heartbeat:Connect(function()
        if not State.Running then CleanupMovers() return end
        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 then CleanupMovers() return end
        
        if not Destination then CleanupMovers() return end
        
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
            print(string.format("[TeleportSystem] 🥚 First Egg Dropped (Dist: %.1f)", Dist))
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
-- ✅ SHOT TP WITH STOP (Safe Check ALL)
-- ==================================================
ShotTPWithStop = function(Destination, Time, StopDistance, Callback)
    CleanupMovers()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root then
        if Callback then Callback() end
        return
    end
    
    if not Destination then
        warn("[TeleportSystem] ⚠️ ShotTPWithStop: Destination is nil!")
        if Callback then Callback() end
        return
    end
    
    if typeof(Destination) ~= "Vector3" then
        warn("[TeleportSystem] ⚠️ ShotTPWithStop: Destination is not Vector3!")
        if Callback then Callback() end
        return
    end

    local PlayerSpeed = GetPlayerSpeed()
    print(string.format("[TeleportSystem] ✈️ ShotTPWithStop | Speed: %.1f", PlayerSpeed))

    local StartPos = Root.Position
    local StartTime = tick()
    Hum.PlatformStand = true

    State.FlyConnection = RunService.Heartbeat:Connect(function()
        if not State.Running then CleanupMovers() return end
        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 then CleanupMovers() return end

        if not Destination then 
            CleanupMovers() 
            return 
        end
        
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

            print(string.format("[TeleportSystem] ✅ Shot TP Stopped | Dist: %.1f", Dist))
            
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
-- ✅ WALK TP (Safe Check ALL)
-- ==================================================
WalkTP = function(Destination, LockAfterArrive, FlyAtDistance, DropAtDistance, Callback)
    CleanupMovers()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root then
        if Callback then Callback() end
        return
    end
    
    if not Destination then
        warn("[TeleportSystem] ⚠️ WalkTP: Destination is nil!")
        if Callback then Callback() end
        return
    end
    
    if typeof(Destination) ~= "Vector3" then
        warn("[TeleportSystem] ⚠️ WalkTP: Destination is not Vector3!")
        if Callback then Callback() end
        return
    end

    local PlayerSpeed = GetPlayerSpeed()
    Hum.WalkSpeed = PlayerSpeed
    
    print(string.format("[TeleportSystem] 🚶 WalkTP | Speed: %.1f", PlayerSpeed))

    local StartTime = tick()
    local LastCheck = 0
    local FlyDone = false
    local DropDone = false

    State.WalkConnection = RunService.Heartbeat:Connect(function()
        if not State.Running then CleanupMovers() return end
        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 then CleanupMovers() return end
        
        Hum2.WalkSpeed = PlayerSpeed
        
        local Dist = (Root2.Position - Destination).Magnitude

        if FlyAtDistance and not FlyDone and Dist <= FlyAtDistance then
            FlyDone = true
            State.WalkConnection:Disconnect() State.WalkConnection = nil
            Hum2:MoveTo(Root2.Position)
            Hum2.WalkSpeed = 0
            FlyTPAndLock(Destination, Config.FlyOffset, function()
                if Callback then Callback() end
            end)
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
            if tick() - StartTime > Config.WalkTimeout then
                CleanupMovers()
                print("[TeleportSystem] ⚠️ WalkTP Timeout")
                if Callback then Callback() end
                return
            end
        end
    end)
end

-- ==================================================
-- ✅ COLLECT TIMEOUT (20s)
-- ==================================================
StartCollectTimeout = function(EggUid, Callback)
    State.CollectStartTime = tick()
    
    task.spawn(function()
        while State.Running and State.CollectStartTime do
            task.wait(Config.CollectCheckInterval)
            
            if not State.Running then break end
            
            local Elapsed = tick() - State.CollectStartTime
            if Elapsed >= Config.CollectTimeout then
                print(string.format("[TeleportSystem] ⚠️ Collect Timeout (%.1fs) → Auto Stop", Elapsed))
                State.CollectStartTime = nil
                
                if Callback then Callback() end
                AutoStop()
                return
            end
            
            if EggUid and IsEggGone(EggUid) then
                print("[TeleportSystem] ✅ Collect Done (Egg Gone)")
                State.CollectStartTime = nil
                return
            end
        end
    end)
end

NotifyComplete = function()
    print("[TeleportSystem] ✅ NotifyComplete → Call FarmingManager")

    if State.OnComplete then
        pcall(function() State.OnComplete() end)
    end

    if _G.YOKUDO_FarmingManager and _G.YOKUDO_FarmingManager.OnTeleportComplete then
        pcall(function() _G.YOKUDO_FarmingManager.OnTeleportComplete() end)
    end
end

AutoStop = function()
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
    State.CollectStartTime = nil
    State.FirstDropDone = false
    State.RepeatCount = 0
    State.IsRecoverMode = false
    State.SafePosition = nil
    State.SafeName = nil
    State.CurrentEggUid = nil

    if State.DropHeldEggConnection then
        State.DropHeldEggConnection:Disconnect()
        State.DropHeldEggConnection = nil
    end
    if State.EggGoneCheckThread then
        pcall(function() task.cancel(State.EggGoneCheckThread) end)
        State.EggGoneCheckThread = nil
    end

    print("[TeleportSystem] ✅ Auto Stop + Restored WalkSpeed")

    NotifyComplete()
end

-- ==================================================
-- ✅ STEP 1 (Walk TP → First Egg ជិតបំផុត)
-- ==================================================
Step1_WalkToFirstEgg = function()
    State.Step = "1_to_first"
    
    local Hum, Root = GetHumanoid()
    if not Hum or not Root then
        warn("[TeleportSystem] ⚠️ Step1: No Humanoid → Wait 1s")
        task.wait(1)
        Hum, Root = GetHumanoid()
        if not Hum or not Root then AutoStop() return end
    end
    
    -- ✅ រក First Egg ជិតបំផុត
    local PlayerPos = Root.Position
    local NearestUid = nil
    local NearestSlotKey = nil
    local NearestPos = nil
    local NearestDist = math.huge
    
    for _, child in ipairs(Container:GetChildren()) do
        if string.find(child.Name, "FirstAreaEgg") then
            local EggPos = GetPosition(child)
            if EggPos then
                local Dist = (EggPos - PlayerPos).Magnitude
                if Dist < NearestDist then
                    NearestDist = Dist
                    NearestUid = child.Name
                    NearestPos = EggPos
                    
                    local SlotNum = string.match(child.Name, "Slot_(%d+)")
                    if SlotNum then
                        NearestSlotKey = "Forest:Slot_" .. SlotNum
                    end
                end
            end
        end
    end
    
    if not NearestUid or not NearestSlotKey then
        warn("[TeleportSystem] ⚠️ Step1: First Egg not found")
        AutoStop()
        return
    end
    
    State.FirstEggUid = NearestUid
    State.FirstEggSlotKey = NearestSlotKey
    
    print(string.format("[TeleportSystem] 🥚 Nearest First Egg: %s | Dist: %.1f", NearestUid, NearestDist))

    WalkTP(NearestPos, false, Config.FlyTPDistance, false, function()
        State.Step = "2_collect_first"
        State.FirstCollected = false
        State.CurrentEggUid = State.FirstEggUid
        
        StartCollectTimeout(State.FirstEggUid)
        
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
-- ✅ STEP 3B (Short TP → 1200m → Drop → Walk TP)
-- ==================================================
Step3b_AfterDropFirst = function()
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
        
        if not TargetPos then 
            warn("[TeleportSystem] ⚠️ Step3b: Target not found → AutoStop")
            AutoStop() 
            return 
        end

        print("[TeleportSystem] ⚡ Short TP → Target")

        ShotTPWithStop(TargetPos, Config.ShotTPTime, Config.StopShotDistance, function()
            print("[TeleportSystem] ✅ Short TP Stopped (1200m)")

            RemoteDrop()
            State.FirstDropDone = true
            print("[TeleportSystem] 🥚 First Egg Dropped")

            task.wait(0.3)

            -- ✅ Check TargetPos ម្តងទៀត
            local NewTargetPos
            if Container:FindFirstChild(State.TargetUid) then
                NewTargetPos = GetPosition(Container:FindFirstChild(State.TargetUid))
            elseif workspace:FindFirstChild(State.TargetUid) then
                NewTargetPos = GetPosition(workspace:FindFirstChild(State.TargetUid))
            end
            
            if not NewTargetPos then
                warn("[TeleportSystem] ⚠️ Step3b: Target gone after drop → AutoStop")
                AutoStop()
                return
            end

            print("[TeleportSystem] 🚶 Walk TP → Target")
            WalkTP(NewTargetPos, false, Config.FlyTPDistance, false, function()
                task.spawn(function()
                    local WaitTime = GetNearestMapWait(NewTargetPos)
                    task.wait(WaitTime)
                    if not State.Running then return end
                    
                    State.Step = "6_collect_target"
                    State.TargetCollected = false
                    State.CurrentEggUid = State.TargetUid
                    
                    StartCollectTimeout(State.TargetUid)
                    
                    while State.Running and State.Step == "6_collect_target" do
                        task.wait(Config.CollectInterval)
                        RemoteCollectTarget()
                    end
                end)
            end)
        end)
    end)
end

Step7_ShotToSafePosition = function()
    if not State.Running then return end
    State.Step = "7_push_up"
    StopLock()

    PushUp(Config.PushUpOffset, function()
        local SafePos, SafeName = GetSafePosition()
        State.SafeName = SafeName
        State.SafePosition = SafePos

        if not SafePos then AutoStop() return end

        local ShotTarget = SafePos + Vector3.new(0, Config.PushUpOffset, 0)

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

Step8c_CheckDistanceAndRecover = function()
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

Step8b_WalkToCollectAgain = function()
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
        
        StartCollectTimeout(State.TargetUid)
        
        task.spawn(function()
            while State.Running and State.Step == "8b_collect_again" do
                task.wait(Config.CollectInterval)
                RemoteCollectTarget()
            end
        end)
    end)
end

Step9_WalkToSwapPosition = function()
    if not State.Running then return end
    State.Step = "9_to_swap"

    local SafeName = State.SafeName or "P1_Top1"
    local WalkPos = Config.Position1_Top2

    if SafeName == "P1_Top1" then
        WalkPos = Config.Position1_Top2
    elseif SafeName == "P2_Top1" then
        WalkPos = Config.Position2_Top2
    end

    WalkTP(WalkPos, false, false, false, function()
        State.Step = "10_done"
        task.wait(0.2)
        AutoStop()
    end)
end

StartEggGoneCheck = function()
    if State.EggGoneCheckThread then
        pcall(function() task.cancel(State.EggGoneCheckThread) end)
        State.EggGoneCheckThread = nil
    end

    State.EggGoneCheckThread = task.spawn(function()
        while State.Running do
            task.wait(Config.EggGoneCheckInterval)

            if State.CurrentEggUid then
                if IsEggGone(State.CurrentEggUid) then
                    AutoStop()
                    return
                end
            end

            if State.TargetUid and not State.DropDone then
                if IsEggGone(State.TargetUid) then
                    AutoStop()
                    return
                end
            end

            if State.FirstEggUid and not State.FirstDropDone then
                if IsEggGone(State.FirstEggUid) then
                    AutoStop()
                    return
                end
            end
        end
    end)
end

SetupDropHeldEgg = function()
    local PG = Player:FindFirstChild("PlayerGui") or Player:WaitForChild("PlayerGui", 5)
    if not PG then return end
    State.DropHeldEgg = PG:FindFirstChild("DropHeldEgg")
    if not State.DropHeldEgg then warn("[TeleportSystem] DropHeldEgg not found!") return end
    if State.DropHeldEggConnection then State.DropHeldEggConnection:Disconnect() State.DropHeldEggConnection = nil end

    State.DropHeldEggConnection = State.DropHeldEgg:GetPropertyChangedSignal("Enabled"):Connect(function()
        local IsEnabled = State.DropHeldEgg.Enabled == true

        if IsEnabled and State.Running and State.Step == "2_collect_first" then
            State.FirstCollected = true
            State.CurrentEggUid = State.FirstEggUid
            State.CollectStartTime = nil
            StopLock()
            State.Step = "2b_drop_first"
            task.spawn(function()
                task.wait(0.05)
                State.FirstDropDone = true
                State.CurrentEggUid = nil
                task.wait(0.2)
                Step3b_AfterDropFirst()
            end)
        end

        if IsEnabled and State.Running and State.Step == "6_collect_target" then
            State.TargetCollected = true
            State.CurrentEggUid = State.TargetUid
            State.CollectStartTime = nil
            StopLock()
            task.spawn(function()
                task.wait(0.02)
                Step7_ShotToSafePosition()
            end)
        end

        if IsEnabled and State.Running and State.Step == "8b_collect_again" then
            State.CollectedAgain = true
            State.CurrentEggUid = State.TargetUid
            State.CollectStartTime = nil
            StopLock()
            task.spawn(function()
                task.wait(0.2)
                Step9_WalkToSwapPosition()
            end)
        end
    end)
end

-- ==================================================
-- ✅ START PROCESS
-- ==================================================
StartProcess = function()
    if State.Running then AutoStop() end
    task.wait(0.2)

    local PlayerRoot = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not PlayerRoot then
        warn("[TeleportSystem] ⚠️ PlayerRoot not found!")
        return
    end
    
    local PlayerPos = PlayerRoot.Position
    local FirstEggUid = nil
    local FirstEggSlotKey = nil
    local NearestDist = math.huge
    
    for _, child in ipairs(Container:GetChildren()) do
        if string.find(child.Name, "FirstAreaEgg") then
            local EggPos = GetPosition(child)
            if EggPos then
                local Dist = (EggPos - PlayerPos).Magnitude
                if Dist < NearestDist then
                    NearestDist = Dist
                    FirstEggUid = child.Name
                    
                    local SlotNum = string.match(child.Name, "Slot_(%d+)")
                    if SlotNum then
                        FirstEggSlotKey = "Forest:Slot_" .. SlotNum
                    end
                end
            end
        end
    end

    if not FirstEggUid or not FirstEggSlotKey then
        warn("[TeleportSystem] First Egg not found!")
        return
    end
    
    print(string.format("[TeleportSystem] 🥚 Nearest First Egg: %s | Dist: %.1f", 
        FirstEggUid, NearestDist))

    if not State.TargetUid then
        warn("[TeleportSystem] No Target ID")
        return
    end
    
    if string.find(State.TargetUid, "FirstAreaEgg") then
        warn("[TeleportSystem] ⚠️ Target ជា First Egg!")
        return
    end
    
    local Players = game:GetService("Players")
    for _, P in ipairs(Players:GetPlayers()) do
        if P.Name == State.TargetUid or P.DisplayName == State.TargetUid then
            warn("[TeleportSystem] ⚠️ Target ជា Player:", State.TargetUid)
            return
        end
    end
    
    local TargetInContainer = Container:FindFirstChild(State.TargetUid)
    local TargetInWorkspace = workspace:FindFirstChild(State.TargetUid)
    
    if not TargetInContainer and not TargetInWorkspace then
        warn("[TeleportSystem] ⚠️ Target not found:", State.TargetUid)
        return
    end

    print(string.format("[TeleportSystem] 🥚 First Egg: %s", FirstEggUid))
    print(string.format("[TeleportSystem] 🎯 Target Egg: %s", State.TargetUid))

    SavePlayerStats()

    State.Running = true
    State.Step = "idle"
    State.FirstEggUid = FirstEggUid
    State.FirstEggSlotKey = FirstEggSlotKey
    State.FirstCollected = false
    State.TargetCollected = false
    State.CollectedAgain = false
    State.DropDone = false
    State.CollectAttempts = 0
    State.CollectStartTime = nil
    State.FirstDropDone = false
    State.RepeatCount = 0
    State.IsRecoverMode = false
    State.SafePosition = nil
    State.SafeName = nil
    State.CurrentEggUid = nil

    SetupDropHeldEgg()
    StartEggGoneCheck()

    task.spawn(function()
        task.wait(0.3)
        Step1_WalkToFirstEgg()
    end)
end

FullReset = function()
    StopLock()
    CleanupMovers()
    RestoreStats()

    if State.DropHeldEggConnection then
        State.DropHeldEggConnection:Disconnect()
        State.DropHeldEggConnection = nil
    end
    State.DropHeldEgg = nil

    if State.EggGoneCheckThread then
        pcall(function() task.cancel(State.EggGoneCheckThread) end)
        State.EggGoneCheckThread = nil
    end

    State.Running = false
    State.Step = "idle"
    State.FirstCollected = false
    State.TargetCollected = false
    State.CollectedAgain = false
    State.DropDone = false
    State.FirstDropDone = false
    State.RepeatCount = 0
    State.IsRecoverMode = false
    State.SafePosition = nil
    State.SafeName = nil
    State.CurrentEggUid = nil
    State.CollectStartTime = nil

    print("[TeleportSystem] Full Reset")
end

-- ==================================================
-- ✅ CHARACTER ADDED (Respawn → FullReset + Restart)
-- ==================================================
Player.CharacterAdded:Connect(function(Char)
    if not State.Running then return end
    
    print("[TeleportSystem] 🔄 Character Added → FullReset + Restart")
    
    task.wait(3)
    
    if not State.TargetUid then
        print("[TeleportSystem] ⚠️ No TargetUid → Stop")
        FullReset()
        return
    end
    
    FullReset()
    
    task.wait(0.5)
    
    local TargetInContainer = Container:FindFirstChild(State.TargetUid)
    local TargetInWorkspace = workspace:FindFirstChild(State.TargetUid)
    
    if not TargetInContainer and not TargetInWorkspace then
        print("[TeleportSystem] ⚠️ Target not found → Stop")
        return
    end
    
    print("[TeleportSystem] ✅ Restarting Teleport System...")
    StartProcess()
end)

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

function TeleportSystem.SetOnComplete(Callback)
    State.OnComplete = Callback
end

function TeleportSystem.GetSavedWalkSpeed() return State.SavedWalkSpeed end
function TeleportSystem.GetWalkSpeed() return GetPlayerSpeed() end
function TeleportSystem.IsEnabled() return State.Running end
function TeleportSystem.GetTargetId() return State.TargetUid end

-- Export
_G.YOKUDO_TeleportSystem = TeleportSystem

print("✅ TeleportSystem Loaded (v33 — Fix ALL Errors)")
