-- ==================================================
-- YOKUDO HUB | FEATURE | Farming Manager
-- ✅ ភ្ជាប់ជាមួយ EggCheckPremium
-- ✅ Night: AFK រហូតដល់ Egg Spawn
-- ✅ Egg Spawn ពេល Night: Stop AFK → Safe Zone → រង់ចាំ Day
-- ✅ Day: Fly TP ទៅ First Egg
-- ✅ Settings: Speed 1000, Return 800, Offset 10
-- ✅ Method: InstantTeleport
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================
local CHECK_INTERVAL = 1
local SAFE_ZONE = Vector3.new(533, 70, -366)

local FLY_SPEED = 1000
local RETURN_SPEED = 800
local FLY_OFFSET = 10

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
-- FIND BEST EGG (ប្រើ EggCheckPremium)
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
-- FLY TO SAFE ZONE
-- ==================================================
local function FlyToSafeZone()
    local Hum, Root = GetHumanoid()
    if not Root then return end

    local DistToSafe = (Root.Position - SAFE_ZONE).Magnitude
    if DistToSafe > 5 then
        print("[FarmingManager] Fly to Safe Zone...")
        if _G.YOKUDO_AFKSystem then
            _G.YOKUDO_AFKSystem.FlyTP(SAFE_ZONE, function()
                IsAtSafeZone = true
                print("[FarmingManager] ✅ At Safe Zone")
            end)
        end
    else
        IsAtSafeZone = true
        print("[FarmingManager] ✅ Already at Safe Zone")
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

        print("[FarmingManager] Time: " .. tostring(Text) .. " | Sec: " .. tostring(Sec) .. " | Phase: " .. Phase)

        -- ==========================================
        -- DAY: Sec > 10 → Check Egg + Teleport
        -- ==========================================
        if Phase == "Day" then
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
                task.wait(1)

                if _G.YOKUDO_TeleportSystem then
                    _G.YOKUDO_TeleportSystem.SetMethod("InstantTeleport")
                    _G.YOKUDO_TeleportSystem.SetSpeed(FLY_SPEED)
                    _G.YOKUDO_TeleportSystem.SetTargetId(BestEgg.Uid)
                    _G.YOKUDO_TeleportSystem.Enable()
                end

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

                task.wait(CHECK_INTERVAL)
            end

        -- ==========================================
        -- NIGHT: Sec <= 10
        -- ==========================================
        else
            print("[FarmingManager] Night (Sec: " .. tostring(Sec) .. ")")

            local BestEgg = FindBestEgg()

            if BestEgg then
                print("[FarmingManager] ✅ Night + Egg Spawn: " .. BestEgg.DisplayName .. " → Stop AFK → Safe Zone")

                if AFKStarted then
                    StopAFKOnly()
                    task.wait(0.5)
                end

                FlyToSafeZone()

                WaitingForDay = true
                print("[FarmingManager] Waiting at Safe Zone until Day...")

                while FarmingEnabled and WaitingForDay do
                    local Text2 = GetNightTimerText()
                    local Phase2, Sec2 = GetPhase(Text2)
                    CurrentPhase = Phase2

                    print("[FarmingManager] Waiting | Time: " .. tostring(Text2) .. " | Sec: " .. tostring(Sec2) .. " | Phase: " .. Phase2)

                    if Phase2 == "Day" then
                        print("[FarmingManager] Day Started → Break Wait")
                        WaitingForDay = false
                        break
                    end

                    task.wait(1)
                end
            else
                print("[FarmingManager] Night + No Egg → Continue AFK")

                if not AFKStarted then
                    if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
                        _G.YOKUDO_AFKSystem.Enable()
                        AFKStarted = true
                        print("[FarmingManager] AFK Started")
                    end
                end

                task.wait(CHECK_INTERVAL)
            end
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
    GetPhase = function() return CurrentPhase end
}

print("✅ FarmingManager Feature Loaded (ប្រើ EggCheckPremium)")
