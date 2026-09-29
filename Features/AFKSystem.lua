-- ==================================================
-- YOKUDO HUB | FEATURE | AFK System (WALK TP ONLY) (v3 FINAL)
-- ✅ Walk TP: Humanoid:MoveTo() + Speed ដើម
-- ✅ គ្មាន Fly | គ្មាន Shot TP
-- ✅ Character Respawn → Resume
-- ❌ គ្មាន Debug Print
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================
local ARRIVE_TIMEOUT = 60
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
local DistCheckThread = nil

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
-- CLEANUP
-- ==================================================
local function CleanupMovers()
    if WalkConnection then
        WalkConnection:Disconnect()
        WalkConnection = nil
    end

    local Hum, Root = GetHumanoid()
    if Hum and Root then
        pcall(function()
            Hum:MoveTo(Root.Position)
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
-- WALK TP
-- ==================================================
local function WalkTP(Destination, Callback)
    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then
        if Callback then Callback() end
        return
    end

    local StartTime = tick()
    local LastCheck = 0

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

        Hum2:MoveTo(Destination)

        if tick() - LastCheck > 0.05 then
            LastCheck = tick()

            local Dist = (Root2.Position - Destination).Magnitude
            if Dist <= 3 then
                CleanupMovers()
                if Callback then Callback() end
                return
            end

            if tick() - StartTime > ARRIVE_TIMEOUT then
                CleanupMovers()
                if Callback then Callback() end
                return
            end
        end
    end)
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
-- JUMP OUT TREADMILL
-- ==================================================
local function JumpOutTreadmill(TreadmillPos, Callback)
    local Hum, Root = GetHumanoid()
    if not Hum or not Root or not TreadmillPos then
        if Callback then Callback() end
        return
    end

    task.spawn(function()
        local Attempts = 0
        while AFKEnabled and Attempts < JUMP_MAX_ATTEMPTS do
            local Hum2, Root2 = GetHumanoid()
            if not Hum2 or not Root2 then break end
            if Hum2.Health <= 0 then break end

            local DistToTreadmill = math.floor((Root2.Position - TreadmillPos).Magnitude)

            if DistToTreadmill > JUMP_DISTANCE_THRESHOLD then
                if Callback then Callback() end
                return
            end

            pcall(function() Hum2.Jump = true end)
            Attempts = Attempts + 1
            task.wait(JUMP_ATTEMPT_WAIT)
        end

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
    else
        warn("[AFK] Treadmill not found!")
        AFKEnabled = false
        return
    end

    WalkTP(SAFE_ZONE, function()
        task.wait(SAFE_WAIT_TIME)
        WalkTP(MyTreadmillPos, function()
            StartDistanceCheck()
        end)
    end)

    print("[AFK] AFK System: ON (Walk TP Only)")
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
    MyPlot = nil
    MyTreadmill = nil
    MyTreadmillPos = nil

    print("[AFK] AFK System: OFF")
end

-- ==================================================
-- ✅ CHARACTER ADDED (Resume ពេល Respawn)
-- ==================================================
Player.CharacterAdded:Connect(function(Char)
    if not AFKEnabled then return end

    task.wait(2)  -- ✅ រង់ចាំ Character Load

    -- ✅ Cleanup ចាស់
    CleanupMovers()

    -- ✅ Re-Find Treadmill
    MyPlot, MyTreadmill = FindMyPlotAndTreadmill()
    if MyTreadmill then
        MyTreadmillPos = MyTreadmill.Position
    else
        warn("[AFK] Treadmill not found after Respawn!")
        AFKEnabled = false
        return
    end

    -- ✅ Walk to Treadmill again
    WalkTP(MyTreadmillPos, function()
        StartDistanceCheck()
    end)

    print("[AFK] AFK System: Resumed after Respawn")
end)

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_AFKSystem = {
    Enable = EnableAFK,
    Disable = DisableAFK,
    IsEnabled = function() return AFKEnabled end,
    FindMyPlotAndTreadmill = FindMyPlotAndTreadmill,
    WalkTP = WalkTP,
    FlyTP = WalkTP,
    JumpOutTreadmill = JumpOutTreadmill,
    GetMyTreadmillPos = function() return MyTreadmillPos end,
    GetMyTreadmill = function() return MyTreadmill end,
    GetMyPlot = function() return MyPlot end,
    IsFlying = function() return WalkConnection ~= nil end,
    SAFE_ZONE = SAFE_ZONE,
}

print("✅ AFKSystem Loaded (v3 FINAL — No Debug + Resume)")
