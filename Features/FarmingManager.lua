-- ==================================================
-- YOKUDO HUB | FEATURE | Farming Manager
-- ✅ Night: Check 0.05s
-- ✅ Day: Check 0.5s
-- ✅ រង់ចាំដល់ Safe Zone ពិតប្រាកដ មុននឹង Day
-- ✅ Stop TeleportSystem ពេល Night + Egg
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

-- ==================================================
-- FIXED SETTINGS
-- ==================================================
local NIGHT_CHECK_INTERVAL = 0.05
local DAY_CHECK_INTERVAL = 0.5
local SAFE_ZONE = Vector3.new(533, 70, -366)
local SAFE_ZONE_DIST = 5

local FLY_SPEED = 1000
local RETURN_SPEED = 800
local FLY_OFFSET = 10
local METHOD = "InstantTeleport"

-- ==================================================
-- STATE
-- ==================================================
local FarmingEnabled = false
local CurrentState = "IDLE"
local CurrentPhase = "UNKNOWN"
local FarmingThread = nil
local IsAtSafeZone = false
local WaitingForDay = false
local AFKStarted = false

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
-- GET NIGHT TIMER
-- ==================================================
local function GetNightTimerText()
    local Success, Text = pcall(function()
        return Player.PlayerGui.HUD.GameHUD.BottomRight.NightTimer.Value.Text
    end)
    if Success and Text then
        return tostring(Text)
    end
    return nil
end

local function ParseNightTimer(Text)
    if not Text then return 0, false end
    local M = tonumber(string.match(Text, "(%d+)m")) or 0
    local S = tonumber(string.match(Text, "(%d+)s")) or 0
    return M * 60 + S, true
end

local function GetPhase(Text)
    local Sec, IsValid = ParseNightTimer(Text)
    if not IsValid then return "UNKNOWN", 0 end
    if Sec > 10 then
        return "Day", Sec
    else
        return "Night", Sec
    end
end

-- ==================================================
-- FIND BEST EGG
-- ==================================================
local function FindBestEgg()
    if _G.YOKUDO_EggCheckPremium then
        return _G.YOKUDO_EggCheckPremium.FindBestEgg()
    end
    return nil
end

-- ==================================================
-- ✅ STOP ALL (AFK + TeleportSystem)
-- ==================================================
local function StopAll()
    -- Stop AFK
    if _G.YOKUDO_AFKSystem and _G.YOKUDO_AFKSystem.IsEnabled() then
        local TreadmillPos = _G.YOKUDO_AFKSystem.GetMyTreadmillPos()
        if not TreadmillPos then
            local _, Treadmill = _G.YOKUDO_AFKSystem.FindMyPlotAndTreadmill()
            if Treadmill then
                TreadmillPos = Treadmill.Position
            end
        end

        if TreadmillPos then
            _G.YOKUDO_AFKSystem.JumpOutTreadmill(TreadmillPos, function()
                _G.YOKUDO_AFKSystem.Disable()
                AFKStarted = false
                print("[FarmingManager] ✅ AFK Stopped + Jumped out!")
            end)
        else
            _G.YOKUDO_AFKSystem.Disable()
            AFKStarted = false
        end
    end

    -- ✅ Stop TeleportSystem (បើកំពុងដើរ)
    if _G.YOKUDO_TeleportSystem and _G.YOKUDO_TeleportSystem.IsEnabled() then
        _G.YOKUDO_TeleportSystem.Disable()
        print("[FarmingManager] ✅ TeleportSystem Stopped")
    end
end

-- ==================================================
-- ✅ FLY TO SAFE ZONE AND WAIT
-- ==================================================
local function FlyToSafeZoneAndWait()
    local Hum, Root = GetHumanoid()
    if not Root then return false end

    local DistToSafe = (Root.Position - SAFE_ZONE).Magnitude

    if DistToSafe <= SAFE_ZONE_DIST then
        IsAtSafeZone = true
        print("[FarmingManager] ✅ Already at Safe Zone")
        return true
    end

    print("[FarmingManager] Fly to Safe Zone...")

    if _G.YOKUDO_AFKSystem then
        _G.YOKUDO_AFKSystem.FlyTP(SAFE_ZONE, function()
            IsAtSafeZone = true
            print("[FarmingManager] ✅ At Safe Zone")
        end)
    end

    -- រង់ចាំដល់ Safe Zone ពិតប្រាកដ
    local WaitTime = 0
    while FarmingEnabled and WaitTime < 10 do
        local Hum2, Root2 = GetHumanoid()
        if Root2 then
            local Dist = (Root2.Position - SAFE_ZONE).Magnitude
            if Dist <= SAFE_ZONE_DIST then
                IsAtSafeZone = true
                print("[FarmingManager] ✅ Reached Safe Zone (Dist: " .. math.floor(Dist) .. ")")
                return true
            end
        end
        task.wait(0.1)
        WaitTime = WaitTime + 0.1
    end

    print("[FarmingManager] ⚠️ Safe Zone Wait Timeout")
    return false
end

-- ==================================================
-- START TELEPORT
-- ==================================================
local function StartTeleport(EggUid)
    if not _G.YOKUDO_TeleportSystem then
        warn("[FarmingManager] TeleportSystem not loaded!")
        return
    end

    print("[FarmingManager] Starting Teleport:")
    print("  - Target UID: " .. tostring(EggUid))
    print("  - Method: " .. METHOD)
    print("  - Fly Speed: " .. FLY_SPEED)
    print("  - Return Speed: " .. RETURN_SPEED)
    print("  - Fly Offset: " .. FLY_OFFSET)

    _G.YOKUDO_TeleportSystem.SetMethod(METHOD)
    _G.YOKUDO_TeleportSystem.SetSpeed(FLY_SPEED)
    _G.YOKUDO_TeleportSystem.SetTargetId(EggUid)
    _G.YOKUDO_TeleportSystem.Enable()
end

-- ==================================================
-- NIGHT LOOP (Check រាល់ 0.05s)
-- ==================================================
local function NightLoop()
    print("[FarmingManager] NightLoop Started (0.05s)")

    while FarmingEnabled do
        local Text = GetNightTimerText()
        local Phase, Sec = GetPhase(Text)
        CurrentPhase = Phase

        if Phase == "Day" then
            print("[FarmingManager] Day Started → Break NightLoop")
            return
        end

        local BestEgg = FindBestEgg()

        if BestEgg then
            print("[FarmingManager] ✅ Night + Egg Spawn: " .. BestEgg.DisplayName .. " → Stop All → Safe Zone")

            -- 1. Stop All (AFK + TeleportSystem)
            StopAll()
            task.wait(0.5)

            -- 2. Fly TP ទៅ Safe Zone + រង់ចាំ
            local ReachedSafe = FlyToSafeZoneAndWait()

            if ReachedSafe then
                -- 3. រង់ចាំ Day (Check 0.5s)
                print("[FarmingManager] At Safe Zone → Waiting for Day (0.5s check)")
                WaitingForDay = true

                while FarmingEnabled and WaitingForDay do
                    local Text2 = GetNightTimerText()
                    local Phase2, Sec2 = GetPhase(Text2)
                    CurrentPhase = Phase2

                    print("[FarmingManager] Waiting | Time: " .. tostring(Text2) .. " | Sec: " .. tostring(Sec2) .. " | Phase: " .. Phase2)

                    if Phase2 == "Day" then
                        print("[FarmingManager] Day Started → Break Wait")
                        WaitingForDay = false
                        return
                    end

                    task.wait(DAY_CHECK_INTERVAL)
                end
            else
                print("[FarmingManager] ⚠️ Failed to reach Safe Zone")
            end

            return
        else
            if not AFKStarted then
                if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
                    _G.YOKUDO_AFKSystem.Enable()
                    AFKStarted = true
                    print("[FarmingManager] AFK Started")
                end
            end
        end

        task.wait(NIGHT_CHECK_INTERVAL)
    end
end

-- ==================================================
-- DAY LOOP (Check រាល់ 0.5s)
-- ==================================================
local function DayLoop()
    print("[FarmingManager] DayLoop Started (0.5s)")

    while FarmingEnabled do
        local Text = GetNightTimerText()
        local Phase, Sec = GetPhase(Text)
        CurrentPhase = Phase

        if Phase == "Night" then
            print("[FarmingManager] Night Started → Break DayLoop")
            return
        end

        local BestEgg = FindBestEgg()

        if BestEgg then
            print("[FarmingManager] ✅ Day + Egg: " .. BestEgg.DisplayName .. " → TeleportSystem")

            -- 1. Stop All (AFK + TeleportSystem)
            StopAll()
            task.wait(0.5)

            -- 2. Fly TP ទៅ Safe Zone + រង់ចាំ
            FlyToSafeZoneAndWait()
            task.wait(1)

            -- 3. Start Teleport
            StartTeleport(BestEgg.Uid)

            -- 4. រង់ចាំ TeleportSystem បញ្ចប់
            while _G.YOKUDO_TeleportSystem and _G.YOKUDO_TeleportSystem.IsEnabled() do
                task.wait(0.5)
                if not FarmingEnabled then break end
            end

            print("[FarmingManager] TeleportSystem Done → Loop Again")
        else
            print("[FarmingManager] Day but No Egg → AFK")

            if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
                _G.YOKUDO_AFKSystem.Enable()
                AFKStarted = true
            end
        end

        task.wait(DAY_CHECK_INTERVAL)
    end
end

-- ==================================================
-- MAIN LOOP
-- ==================================================
local function MainLoop()
    print("[FarmingManager] MainLoop Started")

    while FarmingEnabled do
        local Text = GetNightTimerText()
        local Phase, Sec = GetPhase(Text)
        CurrentPhase = Phase

        print("[FarmingManager] Phase: " .. Phase .. " | Sec: " .. tostring(Sec))

        if Phase == "Day" then
            DayLoop()
        else
            NightLoop()
        end

        task.wait(0.1)
    end
    print("[FarmingManager] MainLoop Stopped")
end

-- ==================================================
-- ENABLE / DISABLE
-- ==================================================
local function Enable()
    if FarmingEnabled then return end
    FarmingEnabled = true
    CurrentState = "CHECK_TIME"
    AFKStarted = false

    if FarmingThread then
        pcall(function() task.cancel(FarmingThread) end)
        FarmingThread = nil
    end
    FarmingThread = task.spawn(function() MainLoop() end)

    print("[YOKUDO] FarmingManager: ON")
end

local function Disable()
    if not FarmingEnabled then return end
    FarmingEnabled = false

    if FarmingThread then
        pcall(function() task.cancel(FarmingThread) end)
        FarmingThread = nil
    end

    StopAll()

    IsAtSafeZone = false
    WaitingForDay = false
    AFKStarted = false
    CurrentState = "IDLE"
    CurrentPhase = "UNKNOWN"
    print("[YOKUDO] FarmingManager: OFF")
end

local function Toggle()
    if FarmingEnabled then Disable() else Enable() end
end

local function SetRarities(List)
    if _G.YOKUDO_EggCheckPremium then
        _G.YOKUDO_EggCheckPremium.SetRarities(List)
    end
    print("[YOKUDO] FarmingManager Rarities: " .. table.concat(List, ", "))
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_FarmingManager = {
    Enable = Enable,
    Disable = Disable,
    Toggle = Toggle,
    IsEnabled = function() return FarmingEnabled end,
    SetRarities = SetRarities,
    GetState = function() return CurrentState end,
    GetPhase = function() return CurrentPhase end,
    NIGHT_CHECK_INTERVAL = NIGHT_CHECK_INTERVAL,
    DAY_CHECK_INTERVAL = DAY_CHECK_INTERVAL,
    FLY_SPEED = FLY_SPEED,
    RETURN_SPEED = RETURN_SPEED,
    FLY_OFFSET = FLY_OFFSET,
    METHOD = METHOD
}

-- ==================================================
-- REGISTER WITH CHARACTER SYSTEM
-- ==================================================
if _G.YOKUDO_CharacterSystem then
    _G.YOKUDO_CharacterSystem:RegisterFeature({
        Name = "FarmingManager",
        Enable = Enable,
        Disable = Disable,
        IsEnabled = function() return FarmingEnabled end,
        OnCharacterAdded = function(Char, Hum, Root)
            if FarmingEnabled then
                task.wait(1)
                -- Restart MainLoop
                if FarmingThread then
                    pcall(function() task.cancel(FarmingThread) end)
                end
                FarmingThread = task.spawn(function() MainLoop() end)
            end
        end
    })
end

print("✅ FarmingManager Feature Loaded (Fixed Safe Zone Logic)")
