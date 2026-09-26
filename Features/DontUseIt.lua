-- ==================================================
-- YOKUDO HUB | FEATURE | Don't Use It
-- ✅ WalkSpeed 800 + Fast Click + Egg Check (Poll)
-- ✅ BodyV + BodyG តែម្នាក់ឯង (គ្មាន Tween)
-- ✅ Speed 400/s | Fly Offset 80 | Position Y = 70
-- ✅ Egg Collect = True → Fly Loop P3 ↔ P1 (No Stop)
-- ✅ TIMEOUT = 3 ម៉ោង (10,800s)
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================
local WALK_SPEED_VALUE = 800
local TELEPORT_SPEED = 400
local FLY_OFFSET = 80
local WAIT_BETWEEN_POS = 0.1
local CHECK_INTERVAL = 0.1
local ARRIVE_DISTANCE = 3
local TIMEOUT = 10800  -- ✅ 3 ម៉ោង

local BODY_VELOCITY_P = 5000
local BODY_GYRO_P = 50000
local BODY_GYRO_D = 2000

-- Positions (Y = 70)
local POSITION_1 = Vector3.new(663, 70, -369)
local POSITION_3 = Vector3.new(5974, 70, -368)

-- ==================================================
-- STATE
-- ==================================================
local Enabled = false

-- WalkSpeed
local WalkSpeedConnection = nil
local OriginalWalkSpeed = 16

-- Fast Click
local FastClickPromptConnection = nil
local FastClickHeartbeatConnection = nil
local FastClickCounter = 0

-- Egg Check
local EggCheckThread = nil
local DropHeldEgg = nil
local EggCollectTriggered = false

-- Teleport
local FlyConnection = nil
local BodyVelocity = nil
local BodyGyro = nil
local FlyLoopRunning = false
local FlySequence = 0
local CurrentFlyStep = 1

-- Forward Declarations
local StartFlyLoop
local StopFly

-- ==================================================
-- GET HUMANOID
-- ==================================================
local function GetHumanoid()
    local Char = Player.Character
    if not Char then return nil, nil end
    return Char:FindFirstChildOfClass("Humanoid"), Char:FindFirstChild("HumanoidRootPart")
end

-- ==================================================
-- 1. WALK SPEED 800
-- ==================================================
local function StartWalkSpeed()
    local Hum = GetHumanoid()
    if Hum then
        OriginalWalkSpeed = Hum.WalkSpeed
        Hum.WalkSpeed = WALK_SPEED_VALUE
    end

    if WalkSpeedConnection then WalkSpeedConnection:Disconnect() end
    WalkSpeedConnection = RunService.Heartbeat:Connect(function()
        if not Enabled then return end
        local H = GetHumanoid()
        if H then H.WalkSpeed = WALK_SPEED_VALUE end
    end)

    print("[Don't use it] WalkSpeed: ON (" .. WALK_SPEED_VALUE .. ")")
end

local function StopWalkSpeed()
    if WalkSpeedConnection then
        WalkSpeedConnection:Disconnect()
        WalkSpeedConnection = nil
    end
    local Hum = GetHumanoid()
    if Hum then Hum.WalkSpeed = OriginalWalkSpeed end
    print("[Don't use it] WalkSpeed: OFF")
end

-- ==================================================
-- 2. FAST CLICK
-- ==================================================
local function ApplyHoldDuration(prompt)
    if not prompt then return end
    pcall(function() prompt.HoldDuration = 0 end)
end

local function ScanAllPrompts()
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then ApplyHoldDuration(d) end
    end
    local PG = Player:FindFirstChild("PlayerGui")
    if PG then
        for _, d in ipairs(PG:GetDescendants()) do
            if d:IsA("ProximityPrompt") then ApplyHoldDuration(d) end
        end
    end
end

local function StartFastClick()
    ScanAllPrompts()

    if FastClickPromptConnection then FastClickPromptConnection:Disconnect() end
    FastClickPromptConnection = ProximityPromptService.PromptShown:Connect(function(prompt)
        if not Enabled then return end
        ApplyHoldDuration(prompt)
    end)

    if FastClickHeartbeatConnection then FastClickHeartbeatConnection:Disconnect() end
    FastClickCounter = 0
    FastClickHeartbeatConnection = RunService.Heartbeat:Connect(function()
        if not Enabled then return end
        FastClickCounter = FastClickCounter + 1
        if FastClickCounter >= 30 then
            FastClickCounter = 0
            ScanAllPrompts()
        end
    end)

    print("[Don't use it] Fast Click: ON")
end

local function StopFastClick()
    if FastClickPromptConnection then FastClickPromptConnection:Disconnect() FastClickPromptConnection = nil end
    if FastClickHeartbeatConnection then FastClickHeartbeatConnection:Disconnect() FastClickHeartbeatConnection = nil end
    print("[Don't use it] Fast Click: OFF")
end

-- ==================================================
-- 3. EGG CHECK (POLL)
-- ==================================================
local function GetDropHeldEgg()
    local PG = Player:FindFirstChild("PlayerGui")
    if not PG then return nil end
    return PG:FindFirstChild("DropHeldEgg")
end

local function StartEggCheckThread()
    if EggCheckThread then
        pcall(function() task.cancel(EggCheckThread) end)
        EggCheckThread = nil
    end

    EggCheckThread = task.spawn(function()
        while Enabled do
            task.wait(CHECK_INTERVAL)

            if not DropHeldEgg or not DropHeldEgg.Parent then
                DropHeldEgg = GetDropHeldEgg()
            end

            if DropHeldEgg then
                local IsCollected = DropHeldEgg.Enabled == true

                if IsCollected and not EggCollectTriggered then
                    EggCollectTriggered = true
                    print("[Don't use it] ✅ Egg Collect = TRUE → Start Fly Loop")
                    if StartFlyLoop then StartFlyLoop() end
                elseif not IsCollected and EggCollectTriggered then
                    EggCollectTriggered = false
                    print("[Don't use it] ❌ Egg Collect = FALSE → Stop Fly Loop")
                    if StopFly then StopFly() end
                end
            end
        end
    end)

    print("[Don't use it] Egg Check Thread: STARTED")
end

local function StopEggCheckThread()
    if EggCheckThread then
        pcall(function() task.cancel(EggCheckThread) end)
        EggCheckThread = nil
    end
    print("[Don't use it] Egg Check Thread: STOPPED")
end

-- ==================================================
-- 4. CLEANUP MOVERS
-- ==================================================
local function CleanupMovers(KeepPlatformStand)
    if FlyConnection then
        FlyConnection:Disconnect()
        FlyConnection = nil
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
        pcall(function() BodyGyro.MaxTorque = Vector3.zero end)
        BodyGyro:Destroy()
        BodyGyro = nil
    end

    local Hum, Root = GetHumanoid()
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
            Root.AssemblyLinearVelocity = Vector3.zero
            Root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

-- ==================================================
-- 5. BODYV + BODYG FLY TP
-- ==================================================
local function FlyTP(Destination, Callback)
    FlySequence = FlySequence + 1
    local Seq = FlySequence

    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then
        if Callback then Callback() end
        return
    end

    local FlyPos = Vector3.new(Destination.X, Destination.Y + FLY_OFFSET, Destination.Z)
    local TargetCFrame = CFrame.new(FlyPos)

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

    FlyConnection = RunService.Heartbeat:Connect(function()
        if Seq ~= FlySequence then
            if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end
            return
        end
        if not Enabled then CleanupMovers() return end

        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 or Hum2.Health <= 0 then CleanupMovers() return end
        if not BodyVelocity or not BodyGyro then CleanupMovers() return end

        local CurrentPos = Root2.Position
        local Dir = FlyPos - CurrentPos
        local HorizDist = Vector3.new(Dir.X, 0, Dir.Z).Magnitude
        local VertDist = math.abs(Dir.Y)
        local TotalDist = Dir.Magnitude

        if HorizDist <= ARRIVE_DISTANCE and VertDist <= 2 then
            if BodyVelocity then
                BodyVelocity.Velocity = Vector3.zero
                BodyVelocity.MaxForce = Vector3.zero
            end
            if BodyGyro then BodyGyro.MaxTorque = Vector3.zero end
            if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end

            task.spawn(function()
                task.wait(0.05)
                CleanupMovers(true)
                Root2.CFrame = TargetCFrame
                Root2.AssemblyLinearVelocity = Vector3.zero
                Root2.AssemblyAngularVelocity = Vector3.zero
                if Callback then Callback() end
            end)
            return
        end

        if tick() - StartTime > TIMEOUT then
            CleanupMovers()
            if Callback then Callback() end
            return
        end

        if TotalDist > 1 then
            BodyVelocity.Velocity = Dir.Unit * TELEPORT_SPEED
        else
            BodyVelocity.Velocity = Vector3.zero
        end

        BodyGyro.CFrame = CFrame.new(CurrentPos, CurrentPos + Vector3.new(Dir.X, 0, Dir.Z))
    end)
end

-- ==================================================
-- 6. FLY LOOP (P3 ↔ P1 — No Stop)
-- ==================================================
local function FlyLoopStep()
    if not Enabled or not FlyLoopRunning then return end

    if CurrentFlyStep == 1 then
        print("[Don't use it] Fly → Position 3")
        FlyTP(POSITION_3, function()
            if not Enabled or not FlyLoopRunning then return end
            task.wait(WAIT_BETWEEN_POS)
            CurrentFlyStep = 2
            FlyLoopStep()
        end)
    else
        print("[Don't use it] Fly → Position 1")
        FlyTP(POSITION_1, function()
            if not Enabled or not FlyLoopRunning then return end
            task.wait(WAIT_BETWEEN_POS)
            CurrentFlyStep = 1
            FlyLoopStep()
        end)
    end
end

StartFlyLoop = function()
    if FlyLoopRunning then return end
    FlyLoopRunning = true
    CurrentFlyStep = 1

    print("[Don't use it] ✅ Fly Loop STARTED (P3 ↔ P1 — No Stop)")
    FlyLoopStep()
end

StopFly = function()
    FlyLoopRunning = false
    FlySequence = FlySequence + 1
    CleanupMovers()
    print("[Don't use it] Fly Loop: STOPPED")
end

-- ==================================================
-- ENABLE / DISABLE
-- ==================================================
local function Enable()
    if Enabled then return end
    Enabled = true
    EggCollectTriggered = false
    CurrentFlyStep = 1

    StartWalkSpeed()
    StartFastClick()
    StartEggCheckThread()

    print("[Don't use it] =========================")
    print("[Don't use it] COMBO: ON")
    print("[Don't use it] BodyV + BodyG | Speed 400/s | Offset 80")
    print("[Don't use it] =========================")
end

local function Disable()
    if not Enabled then return end
    Enabled = false
    EggCollectTriggered = false

    StopWalkSpeed()
    StopFastClick()
    StopEggCheckThread()
    StopFly()

    DropHeldEgg = nil

    print("[Don't use it] COMBO: OFF")
end

local function Toggle()
    if Enabled then Disable() else Enable() end
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_DontUseIt = {
    Enable = Enable,
    Disable = Disable,
    Toggle = Toggle,
    IsEnabled = function() return Enabled end,
    POSITION_1 = POSITION_1,
    POSITION_3 = POSITION_3,
    TELEPORT_SPEED = TELEPORT_SPEED,
    FLY_OFFSET = FLY_OFFSET,
}

-- ==================================================
-- REGISTER WITH CHARACTER SYSTEM
-- ==================================================
if _G.YOKUDO_CharacterSystem then
    _G.YOKUDO_CharacterSystem:RegisterFeature({
        Name = "DontUseIt",
        Enable = Enable,
        Disable = Disable,
        IsEnabled = function() return Enabled end,
        OnCharacterAdded = function(Char, Hum, Root)
            if Enabled then
                task.wait(1)
                StartWalkSpeed()
                StartFastClick()
                StartEggCheckThread()
            end
        end
    })
end

print("✅ DontUseIt Feature Loaded (BodyV + BodyG | Speed 400/s | Offset 80)")
