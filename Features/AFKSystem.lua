-- ==================================================
-- YOKUDO HUB | FEATURE | AFK System (WALK TP + ORIGINAL SPEED)
-- រក Plot + Treadmill → Walk TP → Jump Out
-- ✅ Walk TP: Humanoid:MoveTo() + Speed ដើមរបស់ Player
-- ✅ Save Speed ដើម មុន Walk | Restore ពេល Stop
-- ✅ JumpOut រហូតដល់ Dist > 5
-- ✅ Register ជាមួយ CharacterSystem
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================
local ARRIVE_TIMEOUT = 30
local JUMP_DISTANCE_THRESHOLD = 5
local JUMP_MAX_ATTEMPTS = 50
local JUMP_ATTEMPT_WAIT = 0.2
local DIST_TREADMILL_THRESHOLD = 5
local DIST_CHECK_INTERVAL = 4
local SAFE_WAIT_TIME = 1
local SAFE_ZONE = Vector3.new(533, 70, -366)

-- ==================================================
-- STATE
-- ==================================================
local AFKEnabled = false
local MyPlot = nil
local MyTreadmill = nil
local MyTreadmillPos = nil
local WalkConnection = nil
local IsWalking = false
local DistCheckThread = nil
local SavedWalkSpeed = nil

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
-- SAVE / RESTORE WALK SPEED
-- ==================================================
local function SaveWalkSpeed()
    local Hum = GetHumanoid()
    if not Hum then return end
    if SavedWalkSpeed == nil then
        SavedWalkSpeed = Hum.WalkSpeed
        print("[AFK] Saved WalkSpeed ដើម:", SavedWalkSpeed)
    end
end

local function RestoreWalkSpeed()
    local Hum = GetHumanoid()
    if not Hum then return end
    if SavedWalkSpeed ~= nil then
        pcall(function()
            Hum.WalkSpeed = SavedWalkSpeed
        end)
    end
end

-- ==================================================
-- CLEANUP
-- ==================================================
local function CleanupMovers()
    if WalkConnection then
        WalkConnection:Disconnect()
        WalkConnection = nil
    end

    local Hum, Root = GetHumanoid()
    if Hum then
        pcall(function()
            if SavedWalkSpeed ~= nil then
                Hum.WalkSpeed = SavedWalkSpeed
            end
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

    IsWalking = false
end

-- ==================================================
-- FIND MY PLOT AND TREADMILL
-- ==================================================
local function FindMyPlotAndTreadmill()
    local Plots = workspace:FindFirstChild("Plots")
    if not Plots then return nil, nil end

    for _, plot in ipairs(Plots:GetChildren()) do
        if plot:IsA("Model") then
            local PlotSign = plot:FindFirstChild("PlotSign")
            if PlotSign then
                local PlayerPlotSign = PlotSign:FindFirstChild("PlayerPlotSign")
                if PlayerPlotSign then
                    local Frame = PlayerPlotSign:FindFirstChild("Frame")
                    if Frame then
                        local PlayerName = Frame:FindFirstChild("PlayerName")
                        if PlayerName and PlayerName:IsA("TextLabel") then
                            if PlayerName.Text == Player.Name
                            or PlayerName.Text == Player.DisplayName then
                                local Treadmill = plot:FindFirstChild("TreadmillBottom")
                                return plot, Treadmill
                            end
                        end
                    end
                end
            end
        end
    end
    return nil, nil
end

-- ==================================================
-- ✅ WALK TP (ប្រើ Speed ដើមរបស់ Player)
-- ==================================================
local function WalkTP(Destination, Callback)
    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then
        if Callback then Callback() end
        return
    end

    -- ✅ Save WalkSpeed ដើម
    SaveWalkSpeed()

    -- ✅ ប្រើ Speed ដើម
    Hum.WalkSpeed = SavedWalkSpeed or Hum.WalkSpeed
    IsWalking = true

    print(string.format("[AFK] Walk TP → %s | Speed: %d", tostring(Destination), Hum.WalkSpeed))

    local StartTime = tick()

    WalkConnection = RunService.Heartbeat:Connect(function()
        if not AFKEnabled then
            CleanupMovers()
            return
        end

        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 or Hum2.Health <= 0 then
            CleanupMovers()
            return
        end

        -- ✅ ប្រើ Speed ដើមរាល់ Heartbeat
        Hum2.WalkSpeed = SavedWalkSpeed or Hum2.WalkSpeed

        local Dist = (Root2.Position - Destination).Magnitude

        if Dist <= 3 then
            CleanupMovers()
            Hum2:MoveTo(Root2.Position)
            print("[AFK] ✅ Walk TP Arrived")
            if Callback then Callback() end
            return
        end

        if tick() - StartTime > ARRIVE_TIMEOUT then
            CleanupMovers()
            print("[AFK] Walk TP Timeout")
            if Callback then Callback() end
            return
        end

        Hum2:MoveTo(Destination)
    end)
end

-- ==================================================
-- JUMP OUT TREADMILL
-- ==================================================
local function JumpOutTreadmill(TreadmillPos, Callback)
    local Hum, Root = GetHumanoid()
    if not Hum or not Root or not TreadmillPos then
        if Callback then Callback() end
        return
    end

    print("[AFK] Starting Jump Out...")

    task.spawn(function()
        local Attempts = 0
        while AFKEnabled and Attempts < JUMP_MAX_ATTEMPTS do
            local Hum2, Root2 = GetHumanoid()
            if not Hum2 or not Root2 then break end
            if Hum2.Health <= 0 then break end

            local DistToTreadmill = math.floor((Root2.Position - TreadmillPos).Magnitude)

            if DistToTreadmill > JUMP_DISTANCE_THRESHOLD then
                print("[AFK] ✅ Jumped out! Distance:", DistToTreadmill)
                if Callback then Callback() end
                return
            end

            pcall(function() Hum2.Jump = true end)
            Attempts = Attempts + 1
            task.wait(JUMP_ATTEMPT_WAIT)
        end

        print("[AFK] JumpOut timeout")
        if Callback then Callback() end
    end)
end

-- ==================================================
-- DISTANCE CHECK LOOP
-- ==================================================
local function StartDistanceCheck()
    if DistCheckThread then
        pcall(function() task.cancel(DistCheckThread) end)
        DistCheckThread = nil
    end

    DistCheckThread = task.spawn(function()
        while AFKEnabled do
            task.wait(DIST_CHECK_INTERVAL)
            if not AFKEnabled then break end

            local Hum, Root = GetHumanoid()
            if not Root or not MyTreadmillPos then continue end

            local DistToTreadmill = math.floor((Root.Position - MyTreadmillPos).Magnitude)

            if DistToTreadmill > DIST_TREADMILL_THRESHOLD then
                print("[AFK] Player jumped out! Walk back to Treadmill")
                WalkTP(MyTreadmillPos)
            end
        end
    end)
end

-- ==================================================
-- ENABLE
-- ==================================================
local function EnableAFK()
    if AFKEnabled then return end
    AFKEnabled = true

    MyPlot, MyTreadmill = FindMyPlotAndTreadmill()
    if MyTreadmill then
        MyTreadmillPos = MyTreadmill.Position
        print("[AFK] Treadmill found:", MyTreadmill:GetFullName())
    else
        warn("[AFK] Treadmill not found!")
        AFKEnabled = false
        return
    end

    print("[AFK] Walk to Safe Zone first")
    WalkTP(SAFE_ZONE, function()
        task.wait(SAFE_WAIT_TIME)
        print("[AFK] Safe Zone Reached → Walk to Treadmill")
        WalkTP(MyTreadmillPos, function()
            print("[AFK] Arrived at Treadmill → Start Distance Check")
            StartDistanceCheck()
        end)
    end)

    print("[AFK] AFK System: ON (Walk TP + Speed ដើម)")
end

-- ==================================================
-- DISABLE
-- ==================================================
local function DisableAFK()
    if not AFKEnabled then return end
    AFKEnabled = false

    if DistCheckThread then
        pcall(function() task.cancel(DistCheckThread) end)
        DistCheckThread = nil
    end

    CleanupMovers()
    RestoreWalkSpeed()
    MyPlot = nil
    MyTreadmill = nil
    MyTreadmillPos = nil

    print("[AFK] AFK System: OFF")
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_AFKSystem = {
    Enable = EnableAFK,
    Disable = DisableAFK,
    IsEnabled = function() return AFKEnabled end,
    FindMyPlotAndTreadmill = FindMyPlotAndTreadmill,
    WalkTP = WalkTP,
    FlyTP = WalkTP,  -- ✅ Alias
    JumpOutTreadmill = JumpOutTreadmill,
    GetMyTreadmillPos = function() return MyTreadmillPos end,
    GetMyTreadmill = function() return MyTreadmill end,
    GetMyPlot = function() return MyPlot end,
    IsFlying = function() return IsWalking end,
    IsWalking = function() return IsWalking end,
    SAFE_ZONE = SAFE_ZONE,
}

-- ==================================================
-- REGISTER WITH CHARACTER SYSTEM
-- ==================================================
if _G.YOKUDO_CharacterSystem then
    _G.YOKUDO_CharacterSystem:RegisterFeature({
        Name = "AFKSystem",
        Enable = EnableAFK,
        Disable = DisableAFK,
        IsEnabled = function() return AFKEnabled end,
        OnCharacterAdded = function(Char, Hum, Root)
            if AFKEnabled then
                task.wait(1)
                pcall(function()
                    if MyTreadmillPos then
                        StartDistanceCheck()
                    end
                end)
            end
        end
    })
end

print("✅ AFKSystem Feature Loaded (WALK TP + ORIGINAL SPEED)")
