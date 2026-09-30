-- ==================================================
-- YOKUDO HUB | FEATURE | AFK System (v5 FINAL)
-- ✅ Walk TP: Humanoid:MoveTo() + Speed ដើម
-- ✅ Save / Restore WalkSpeed (បញ្ហា Respawn)
-- ✅ Reset PlatformStand ពេល Arrived
-- ✅ Check Grounded ពេល Arrived
-- ✅ Character Respawn → Resume
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
local GROUND_CHECK_DISTANCE = 10

-- ==================================================
-- STATE
-- ==================================================
local AFKEnabled = false
local MyPlot = nil
local MyTreadmill = nil
local MyTreadmillPos = nil
local WalkConnection = nil
local DistCheckThread = nil
local SavedWalkSpeed = nil   -- ✅ Save WalkSpeed ដើម

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
-- ✅ SAVE / RESTORE WALK SPEED
-- ==================================================
local function SaveWalkSpeed()
    local Hum = GetHumanoid()
    if Hum and SavedWalkSpeed == nil then
        SavedWalkSpeed = Hum.WalkSpeed
        print("[AFK] 💾 Saved WalkSpeed:", SavedWalkSpeed)
    end
end

local function RestoreWalkSpeed()
    local Hum = GetHumanoid()
    if Hum and SavedWalkSpeed then
        Hum.WalkSpeed = SavedWalkSpeed
        print("[AFK] ✅ Restored WalkSpeed:", SavedWalkSpeed)
    end
end

-- ==================================================
-- CHECK GROUNDED
-- ==================================================
local function IsGrounded()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return false end

    local RaycastParams = RaycastParams.new()
    RaycastParams.FilterDescendantsInstances = { Player.Character }
    RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

    local Result = workspace:Raycast(
        Root.Position,
        Vector3.new(0, -GROUND_CHECK_DISTANCE, 0),
        RaycastParams
    )

    return Result ~= nil
end

-- ==================================================
-- RESET PLATFORMSTAND
-- ==================================================
local function ResetPlatformStand()
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

    -- ✅ Save WalkSpeed បើមិនទាន់
    SaveWalkSpeed()

    -- ✅ Restore WalkSpeed
    RestoreWalkSpeed()

    ResetPlatformStand()

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

        -- ✅ Ensure WalkSpeed ជាប់
        if SavedWalkSpeed and Hum2.WalkSpeed ~= SavedWalkSpeed then
            Hum2.WalkSpeed = SavedWalkSpeed
        end

        Hum2:MoveTo(Destination)

        if tick() - LastCheck > 0.05 then
            LastCheck = tick()

            local Dist = (Root2.Position - Destination).Magnitude
            if Dist <= 3 then
                CleanupMovers()
                ResetPlatformStand()

                task.wait(0.5)

                if IsGrounded() then
                    print("[AFK] ✅ Player Grounded")
                else
                    print("[AFK] ⚠️ Player NOT Grounded → Reset")
                    ResetPlatformStand()
                end

                if Callback then Callback() end
                return
            end

            if tick() - StartTime > ARRIVE_TIMEOUT then
                CleanupMovers()
                ResetPlatformStand()
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

    ResetPlatformStand()

    task.spawn(function()
        local Attempts = 0
        while AFKEnabled and Attempts < JUMP_MAX_ATTEMPTS do
            local Hum2, Root2 = GetHumanoid()
            if not Hum2 or not Root2 then break end
            if Hum2.Health <= 0 then break end

            local DistToTreadmill = math.floor((Root2.Position - TreadmillPos).Magnitude)

            if DistToTreadmill > JUMP_DISTANCE_THRESHOLD then
                ResetPlatformStand()
                if Callback then Callback() end
                return
            end

            pcall(function() Hum2.Jump = true end)
            Attempts = Attempts + 1
            task.wait(JUMP_ATTEMPT_WAIT)
        end

        ResetPlatformStand()
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
                ResetPlatformStand()
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

    -- ✅ Save WalkSpeed ដើម
    SaveWalkSpeed()

    MyPlot, MyTreadmill = FindMyPlotAndTreadmill()
    if MyTreadmill then
        MyTreadmillPos = MyTreadmill.Position
    else
        warn("[AFK] Treadmill not found!")
        AFKEnabled = false
        return
    end

    ResetPlatformStand()

    WalkTP(SAFE_ZONE, function()
        task.wait(SAFE_WAIT_TIME)
        WalkTP(MyTreadmillPos, function()
            ResetPlatformStand()
            task.wait(0.5)

            if IsGrounded() then
                print("[AFK] ✅ Player Grounded at Treadmill")
            else
                print("[AFK] ⚠️ Player NOT Grounded → Reset")
                ResetPlatformStand()
                task.wait(0.5)
            end

            StartDistanceCheck()
        end)
    end)

    print("[AFK] AFK System: ON (Walk TP + Save WalkSpeed)")
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
    ResetPlatformStand()
    MyPlot = nil
    MyTreadmill = nil
    MyTreadmillPos = nil
    -- ✅ មិន Reset SavedWalkSpeed ព្រោះត្រូវការ Resume

    print("[AFK] AFK System: OFF")
end

-- ==================================================
-- ✅ CHARACTER ADDED (Resume ពេល Respawn)
-- ==================================================
Player.CharacterAdded:Connect(function(Char)
    if not AFKEnabled then return end

    task.wait(3)  -- ✅ រង់ចាំ BypassAntiCheat បញ្ចប់ជាមុន

    CleanupMovers()

    -- ✅ Restore WalkSpeed បន្ទាប់ពី Bypass
    RestoreWalkSpeed()

    ResetPlatformStand()

    MyPlot, MyTreadmill = FindMyPlotAndTreadmill()
    if MyTreadmill then
        MyTreadmillPos = MyTreadmill.Position
    else
        warn("[AFK] Treadmill not found after Respawn!")
        AFKEnabled = false
        return
    end

    WalkTP(MyTreadmillPos, function()
        ResetPlatformStand()
        task.wait(0.5)

        if IsGrounded() then
            print("[AFK] ✅ Player Grounded after Respawn")
        else
            print("[AFK] ⚠️ NOT Grounded after Respawn → Reset")
            ResetPlatformStand()
            task.wait(0.5)
        end

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
    ResetPlatformStand = ResetPlatformStand,
    IsGrounded = IsGrounded,
    SaveWalkSpeed = SaveWalkSpeed,        -- ✅ Export
    RestoreWalkSpeed = RestoreWalkSpeed,  -- ✅ Export
    GetSavedWalkSpeed = function() return SavedWalkSpeed end,
    SAFE_ZONE = SAFE_ZONE,
}

print("✅ AFKSystem Loaded (v5 FINAL — Save/Restore WalkSpeed)")
