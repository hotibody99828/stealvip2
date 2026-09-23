-- ==================================================
-- YOKUDO HUB | FEATURE | Farming Manager
-- ✅ Night: Check Egg រាល់ 0.05s
-- ✅ Day: Check Egg រាល់ 0.5s
-- ✅ រង់ចាំ Fly TP ដល់ Safe Zone មុននឹងបន្ត
-- ✅ Fixed Settings
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

-- ==================================================
-- ✅ FIXED SETTINGS
-- ==================================================
local NIGHT_CHECK_INTERVAL = 0.05  -- ✅ លឿន
local DAY_CHECK_INTERVAL = 0.5     -- ✅ យឺត
local SAFE_ZONE = Vector3.new(533, 70, -366)

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

-- ==================================================
-- GET PHASE
-- ==================================================
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
-- STOP AFK (Jump Out)
-- ==================================================
local function StopAFKOnly()
    if not _G.YOKUDO_AFKSystem then return end
    if not _G.YOKUDO_AFKSystem.IsEnabled() then return end

    print("[FarmingManager] Stop AFK → Jump Out")

    local TreadmillPos = _G.YOKUDO_AFKSystem.GetMyTreadmillPos()
    if not TreadmillPos then
        local _, Treadmill = _G.YOKUDO_AFKSystem.FindMyPlotAndTreadmill()
        if Treadmill then
            TreadmillPos = Treadmill.Position
        end
    end

    if not TreadmillPos then
        _G.YOKUDO_AFKSystem.Disable()
        return
    end

    _G.YOKUDO_AFKSystem.JumpOutTreadmill(TreadmillPos, function()
        _G.YOKUDO_AFKSystem.Disable()
        AFKStarted = false
        print("[FarmingManager] ✅ Jumped out!")
    end)
end

-- ==================================================
-- ✅ FLY TO SAFE ZONE (រង់ចាំដល់ Safe Zone)
-- ==================================================
local function FlyToSafeZone()
    local Hum, Root = GetHumanoid()
    if not Root then return end

    local DistToSafe = (Root.Position - SAFE_ZONE).Magnitude
    if DistToSafe > 5 then
        print("[FarmingManager] Fly to Safe Zone...")
        
        local FlyDone = false
        if _G.YOKUDO_AFKSystem then
            _G.YOKUDO_AFKSystem.FlyTP(SAFE_ZONE, function()
                FlyDone = true
                IsAtSafeZone = true
                print("[FarmingManager] ✅ At Safe Zone")
            end)
        end
        
        -- ✅ រង់ចាំដល់ Fly TP បញ្ចប់ (មិនលើស 10s)
        local WaitTime = 0
        while not FlyDone and WaitTime < 10 do
            task.wait(0.05)
            WaitTime = WaitTime + 0.05
            if not FarmingEnabled then break end
        end
    else
        IsAtSafeZone = true
        print("[FarmingManager] ✅ Already at Safe Zone")
    end
end

-- ==================================================
-- ✅ START TELEPORT
-- ==================================================
local function StartTeleport(EggUid)
    if not _G.YOKUDO_TeleportSystem then
        warn("[FarmingManager] TeleportSystem not loaded!")
        return
    end

    print("[FarmingManager] Starting Teleport:")
    print("  - Target UID: " .. tostring(EggUid))
    print("  - Method: " .. METHOD)

    _G.YOKUDO_TeleportSystem.SetMethod(METHOD)
    _G.YOKUDO_TeleportSystem.SetSpeed(FLY_SPEED)
    _G.YOKUDO_TeleportSystem.SetTargetId(EggUid)
    _G.YOKUDO_TeleportSystem.Enable()
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

        -- ==========================================
        -- DAY: Sec > 10 → Check Egg រាល់ 0.5s
        -- ==========================================
        if Phase == "Day" then
            print("[FarmingManager] Day | Time: " .. tostring(Text) .. " | Sec: " .. tostring(Sec))

            if WaitingForDay then
                WaitingForDay = false
                print("[FarmingManager] ✅ Day Started → Stop Waiting")
            end

            local BestEgg = FindBestEgg()

            if BestEgg then
                print("[FarmingManager] ✅ Day + Egg: " .. BestEgg.DisplayName .. " → TeleportSystem")

                StopAFKOnly()
                task.wait(0.5)
                FlyToSafeZone()
                task.wait(0.5)

                StartTeleport(BestEgg.Uid)

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

            task.wait(DAY_CHECK_INTERVAL)  -- ✅ 0.5s

        -- ==========================================
        -- NIGHT: Sec <= 10 → Check Egg រាល់ 0.05s
        -- ==========================================
        else
            -- ✅ បង្ហាញតែពេលចាំបាច់ (កុំ Spam)
            -- print("[FarmingManager] Night | Time: " .. tostring(Text) .. " | Sec: " .. tostring(Sec))

            local BestEgg = FindBestEgg()

            if BestEgg then
                print("[FarmingManager] ✅ Night + Egg Spawn: " .. BestEgg.DisplayName .. " → Stop AFK → Safe Zone")

                if AFKStarted then
                    StopAFKOnly()
                    task.wait(0.5)
                end

                -- ✅ Fly TP ទៅ Safe Zone + រង់ចាំដល់
                FlyToSafeZone()

                WaitingForDay = true
                print("[FarmingManager] Waiting at Safe Zone until Day...")

                while FarmingEnabled and WaitingForDay do
                    local Text2 = GetNightTimerText()
                    local Phase2, Sec2 = GetPhase(Text2)
                    CurrentPhase = Phase2

                    if Phase2 == "Day" then
                        print("[FarmingManager] Day Started → Break Wait")
                        WaitingForDay = false
                        break
                    end

                    task.wait(0.5)  -- ✅ Check Day/Night រាល់ 0.5s
                end
            else
                -- ✅ គ្មាន Egg → បន្ត AFK
                if not AFKStarted then
                    if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
                        _G.YOKUDO_AFKSystem.Enable()
                        AFKStarted = true
                        print("[FarmingManager] AFK Started")
                    end
                end
            end

            task.wait(NIGHT_CHECK_INTERVAL)  -- ✅ 0.05s
        end
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

    if _G.YOKUDO_TeleportSystem and _G.YOKUDO_TeleportSystem.IsEnabled() then
        _G.YOKUDO_TeleportSystem.Disable()
    end
    if _G.YOKUDO_AFKSystem and _G.YOKUDO_AFKSystem.IsEnabled() then
        _G.YOKUDO_AFKSystem.Disable()
    end

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
    FLY_SPEED = FLY_SPEED,
    RETURN_SPEED = RETURN_SPEED,
    FLY_OFFSET = FLY_OFFSET,
    METHOD = METHOD
}

-- ==================================================
-- ✅ REGISTER WITH CHARACTER SYSTEM
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
                if FarmingThread then
                    pcall(function() task.cancel(FarmingThread) end)
                    FarmingThread = nil
                end
                FarmingThread = task.spawn(function() MainLoop() end)
                print("[FarmingManager] Restarted on new Character")
            end
        end
    })
end

print("✅ FarmingManager Feature Loaded (Night 0.05s | Day 0.5s + Register)")
