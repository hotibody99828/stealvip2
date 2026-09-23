-- ==================================================
-- YOKUDO HUB | FEATURE | Farming Manager
-- ✅ ប្រើ AreaEggCycle សម្រាប់ Check Day/Night
-- ✅ បង្ហាញ Print តែពេលចាំបាច់
-- ✅ Night: Check Egg រាល់ 0.05s
-- ✅ Day: Check Egg រាល់ 0.5s
-- ✅ រង់ចាំ Fly TP ដល់ Safe Zone
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer

-- ==================================================
-- ✅ LOAD AREA EGG CYCLE
-- ==================================================
local AreaEggCycle = nil
pcall(function()
    AreaEggCycle = require(ReplicatedStorage.Shared.Util.AreaEggCycle)
end)

if AreaEggCycle then
    print("[FarmingManager] AreaEggCycle Loaded")
else
    warn("[FarmingManager] AreaEggCycle Not Found!")
end

-- ==================================================
-- ✅ FIXED SETTINGS
-- ==================================================
local NIGHT_CHECK_INTERVAL = 0.05
local DAY_CHECK_INTERVAL = 0.5
local PRINT_INTERVAL = 5  -- ✅ បង្ហាញ Print រាល់ 5s
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
local LastPrintTime = 0
local LastPhase = "UNKNOWN"

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
-- ✅ GET PHASE (ប្រើ AreaEggCycle)
-- ==================================================
local function GetPhase()
    if not AreaEggCycle then
        return "UNKNOWN", 0
    end

    local ServerTime = Workspace:GetServerTimeNow()
    local IsNight = AreaEggCycle.IsNightPhase(ServerTime)
    
    if IsNight then
        local SecUntilReset = AreaEggCycle.SecondsUntilReset(ServerTime)
        return "Night", SecUntilReset
    else
        local SecUntilPhaseEnd = AreaEggCycle.SecondsUntilPhaseEnd(ServerTime)
        return "Day", SecUntilPhaseEnd
    end
end

-- ==================================================
-- ✅ SHOULD PRINT
-- ==================================================
local function ShouldPrint(Phase)
    local Now = tick()
    
    -- ✅ Print ពេល Phase ផ្លាស់ប្តូរ
    if Phase ~= LastPhase then
        LastPhase = Phase
        LastPrintTime = Now
        return true
    end
    
    -- ✅ Print រាល់ 5s
    if Now - LastPrintTime >= PRINT_INTERVAL then
        LastPrintTime = Now
        return true
    end
    
    return false
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
-- FLY TO SAFE ZONE
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
-- START TELEPORT
-- ==================================================
local function StartTeleport(EggUid)
    if not _G.YOKUDO_TeleportSystem then
        warn("[FarmingManager] TeleportSystem not loaded!")
        return
    end

    print("[FarmingManager] Starting Teleport: " .. tostring(EggUid))

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
        local Phase, Sec = GetPhase()
        CurrentPhase = Phase

        -- ✅ Print តែពេលចាំបាច់
        if ShouldPrint(Phase) then
            print("[FarmingManager] " .. Phase .. " | Sec Until " .. (Phase == "Day" and "Night" or "Reset") .. ": " .. tostring(math.floor(Sec)))
        end

        -- ==========================================
        -- DAY: Check Egg រាល់ 0.5s
        -- ==========================================
        if Phase == "Day" then
            if WaitingForDay then
                WaitingForDay = false
                print("[FarmingManager] ✅ Day Started → Stop Waiting")
            end

            local BestEgg = FindBestEgg()

            if BestEgg then
                print("[FarmingManager] ✅ Day + Egg: " .. BestEgg.DisplayName)

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
                if not AFKStarted then
                    print("[FarmingManager] Day + No Egg → AFK")

                    if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
                        _G.YOKUDO_AFKSystem.Enable()
                        AFKStarted = true
                    end
                end
            end

            task.wait(DAY_CHECK_INTERVAL)

        -- ==========================================
        -- NIGHT: Check Egg រាល់ 0.05s
        -- ==========================================
        else
            local BestEgg = FindBestEgg()

            if BestEgg then
                print("[FarmingManager] ✅ Night + Egg: " .. BestEgg.DisplayName)

                if AFKStarted then
                    StopAFKOnly()
                    task.wait(0.5)
                end

                FlyToSafeZone()

                WaitingForDay = true
                print("[FarmingManager] Waiting at Safe Zone until Day...")

                while FarmingEnabled and WaitingForDay do
                    local Phase2, Sec2 = GetPhase()
                    CurrentPhase = Phase2

                    if Phase2 == "Day" then
                        print("[FarmingManager] Day Started → Break Wait")
                        WaitingForDay = false
                        break
                    end

                    task.wait(0.5)
                end
            else
                if not AFKStarted then
                    if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
                        _G.YOKUDO_AFKSystem.Enable()
                        AFKStarted = true
                        print("[FarmingManager] Night + No Egg → AFK")
                    end
                end
            end

            task.wait(NIGHT_CHECK_INTERVAL)
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
    LastPrintTime = 0
    LastPhase = "UNKNOWN"

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
    GetPhaseInfo = function() return GetPhase() end,
    FLY_SPEED = FLY_SPEED,
    RETURN_SPEED = RETURN_SPEED,
    FLY_OFFSET = FLY_OFFSET,
    METHOD = METHOD
}

print("✅ FarmingManager Feature Loaded (ប្រើ AreaEggCycle)")
