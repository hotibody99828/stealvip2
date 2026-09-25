-- ==================================================
-- YOKUDO HUB | FEATURE | Farming Manager (NEW)
-- ប្រើ TeleportSystem + AFK Mode (ដាច់ដោយឡែក)
-- ✅ Callback ពី TeleportSystem ពេល AutoStop
-- ✅ StopAll() រង់ចាំ JumpOutTreadmill ចប់
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer

-- ==================================================
-- AREA EGG CYCLE
-- ==================================================
local AreaEggCycle = nil

pcall(function()
    AreaEggCycle = require(ReplicatedStorage.Shared.Util.AreaEggCycle)
end)

if not AreaEggCycle then
    warn("[FarmingManager] AreaEggCycle not found! Using fallback.")
end

-- ==================================================
-- SETTINGS
-- ==================================================
local EGG_CHECK_INTERVAL = 0.05
local DAY_CHECK_INTERVAL = 0.5
local SAFE_ZONE = Vector3.new(533, 70, -366)
local SAFE_ZONE_DIST = 5
local SAFE_WAIT_AFTER_REACH = 0.1
local FLY_SPEED = 1000
local SAFE_FLY_SPEED = 1000

-- ==================================================
-- EGG CHECK PREMIUM
-- ==================================================
local SelectedRarities = { Divine = true, Eternal = true, Secret = true }

local MeshIdMap = {}
local MeshIdMapBuilt = false

local RARITY_PRIORITY = {
    Divine = 1,
    Eternal = 2,
    Secret = 3
}

local function BuildMeshIdMap()
    if MeshIdMapBuilt then return end

    local Assets = ReplicatedStorage:FindFirstChild("Data")
    if not Assets then return end
    Assets = Assets:FindFirstChild("Assets")
    if not Assets then return end
    local Configs = Assets:FindFirstChild("Configs")
    local EggModels = ReplicatedStorage:FindFirstChild("Assets")
    if EggModels then EggModels = EggModels:FindFirstChild("Models") end
    if EggModels then EggModels = EggModels:FindFirstChild("Eggs") end
    if not Configs or not EggModels then return end

    for _, Config in ipairs(Configs:GetChildren()) do
        local Success, Module = pcall(function() return require(Config) end)
        if Success and Module and Module.Egg then
            local ModelName = Module.Egg.ModelName or Config.Name
            local Template = EggModels:FindFirstChild(ModelName)
            if Template then
                for _, Desc in ipairs(Template:GetDescendants()) do
                    if Desc:IsA("MeshPart") and Desc.MeshId ~= "" then
                        MeshIdMap[Desc.MeshId] = Config.Name
                    end
                    if Desc:IsA("SpecialMesh") and Desc.MeshId ~= "" then
                        MeshIdMap[Desc.MeshId] = Config.Name
                    end
                end
            end
        end
    end

    MeshIdMapBuilt = true
    print("[FarmingManager] MeshId Map Built: " .. tostring(#Configs:GetChildren()) .. " Configs")
end

local function GetPetData(AssetCategory)
    local Assets = ReplicatedStorage:FindFirstChild("Data")
    if not Assets then return nil end
    Assets = Assets:FindFirstChild("Assets")
    if not Assets then return nil end
    local Configs = Assets:FindFirstChild("Configs")
    if not Configs then return nil end

    local Config = Configs:FindFirstChild(AssetCategory)
    if not Config then return nil end

    local Success, Module = pcall(function() return require(Config) end)
    if not Success or not Module then return nil end

    return {
        Rarity = Module.Rarity and (Module.Rarity._id or Module.Rarity.RarityId) or nil,
        EarningRate = Module.EarningRate or 0,
        DisplayName = Module.DisplayName or AssetCategory
    }
end

local function FindAssetCategory(EggModel)
    if not MeshIdMapBuilt then BuildMeshIdMap() end

    for _, Desc in ipairs(EggModel:GetDescendants()) do
        if Desc:IsA("MeshPart") and Desc.MeshId ~= "" then
            local Cat = MeshIdMap[Desc.MeshId]
            if Cat then return Cat end
        end
        if Desc:IsA("SpecialMesh") and Desc.MeshId ~= "" then
            local Cat = MeshIdMap[Desc.MeshId]
            if Cat then return Cat end
        end
    end
    return nil
end

local function SortEggs(EggList)
    table.sort(EggList, function(a, b)
        local Pa = RARITY_PRIORITY[a.Rarity] or 999
        local Pb = RARITY_PRIORITY[b.Rarity] or 999
        if Pa ~= Pb then return Pa < Pb end
        return a.EarningRate > b.EarningRate
    end)
end

local function FindBestEgg()
    local Container = workspace:FindFirstChild("AreaEggSlotsClient")
    if not Container then return nil end

    local EggList = {}

    for _, Slot in ipairs(Container:GetChildren()) do
        if Slot:IsA("Model") then
            local Category = FindAssetCategory(Slot)
            if Category then
                local Data = GetPetData(Category)
                if Data and SelectedRarities[Data.Rarity] then
                    table.insert(EggList, {
                        Slot = Slot,
                        Uid = Slot.Name,
                        Rarity = Data.Rarity,
                        EarningRate = Data.EarningRate,
                        DisplayName = Data.DisplayName
                    })
                end
            end
        end
    end

    if #EggList == 0 then return nil end
    SortEggs(EggList)
    return EggList[1]
end

local function SetRarities(List)
    SelectedRarities = {}
    for _, r in ipairs(List) do
        SelectedRarities[r] = true
    end
    print("[FarmingManager] Rarities: " .. table.concat(List, ", "))
end

-- ==================================================
-- STATE
-- ==================================================
local FarmingEnabled = false
local CurrentState = "IDLE"
local CurrentPhase = "UNKNOWN"
local FarmingThread = nil
local AFKStarted = false
local PendingEggUid = nil
local WaitingForTeleport = false

local FlyConnection = nil
local BodyVelocity = nil
local BodyGyro = nil

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
-- CLEANUP FLY
-- ==================================================
local function CleanupFly()
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
-- SELF FLY TP
-- ==================================================
local function SelfFlyTP(Destination, Speed, Callback)
    CleanupFly()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root then
        if Callback then Callback() end
        return
    end
    if Hum.Health <= 0 then
        if Callback then Callback() end
        return
    end

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

    FlyConnection = RunService.Heartbeat:Connect(function()
        if not FarmingEnabled then
            CleanupFly()
            return
        end

        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 then
            CleanupFly()
            return
        end
        if Hum2.Health <= 0 then return end
        if not BodyVelocity or not BodyGyro then CleanupFly() return end

        local CurrentPos = Root2.Position
        local Direction = Destination - CurrentPos
        local TotalDist = Direction.Magnitude

        if TotalDist <= 5 then
            CleanupFly()
            Root2.CFrame = CFrame.new(Destination)
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero
            if Callback then Callback() end
            return
        end

        if tick() - StartTime > 15 then
            CleanupFly()
            if Callback then Callback() end
            return
        end

        BodyVelocity.Velocity = Direction.Unit * Speed
        BodyGyro.CFrame = CFrame.new(CurrentPos, Destination)
    end)
end

-- ==================================================
-- GET PHASE
-- ==================================================
local function GetPhase()
    if AreaEggCycle then
        local Success, IsNight = pcall(function()
            return AreaEggCycle.IsNightPhase(Workspace:GetServerTimeNow())
        end)

        if Success then
            if IsNight then
                return "Night"
            else
                return "Day"
            end
        end
    end

    local Success, Text = pcall(function()
        return Player.PlayerGui.HUD.GameHUD.BottomRight.NightTimer.Value.Text
    end)

    if Success and Text then
        local M = tonumber(string.match(Text, "(%d+)m")) or 0
        local S = tonumber(string.match(Text, "(%d+)s")) or 0
        local Sec = M * 60 + S
        if Sec > 10 then
            return "Day"
        else
            return "Night"
        end
    end

    return "UNKNOWN"
end

-- ==================================================
-- STOP ALL (✅ កែ — រង់ចាំ JumpOutTreadmill ចប់)
-- ==================================================
local function StopAll()
    if _G.YOKUDO_AFKSystem and _G.YOKUDO_AFKSystem.IsEnabled() then
        local TreadmillPos = _G.YOKUDO_AFKSystem.GetMyTreadmillPos()
        if not TreadmillPos then
            local _, Treadmill = _G.YOKUDO_AFKSystem.FindMyPlotAndTreadmill()
            if Treadmill then
                TreadmillPos = Treadmill.Position
            end
        end

        if TreadmillPos then
            -- ✅ រង់ចាំ JumpOutTreadmill ចប់
            local JumpDone = false
            _G.YOKUDO_AFKSystem.JumpOutTreadmill(TreadmillPos, function()
                _G.YOKUDO_AFKSystem.Disable()
                AFKStarted = false
                JumpDone = true
                print("[FarmingManager] ✅ AFK Stopped + Jumped out!")
            end)
            
            -- ✅ រង់ចាំរហូតដល់ JumpOut ចប់ (ឬ 5s timeout)
            local WaitTime = 0
            while not JumpDone and WaitTime < 5 do
                task.wait(0.1)
                WaitTime = WaitTime + 0.1
            end
            
            if not JumpDone then
                print("[FarmingManager] ⚠️ JumpOut Timeout → Force Disable")
                _G.YOKUDO_AFKSystem.Disable()
                AFKStarted = false
            end
        else
            _G.YOKUDO_AFKSystem.Disable()
            AFKStarted = false
        end
    end

    if _G.YOKUDO_TeleportSystem and _G.YOKUDO_TeleportSystem.IsEnabled() then
        _G.YOKUDO_TeleportSystem.Disable()
        print("[FarmingManager] ✅ TeleportSystem Stopped")
    end

    CleanupFly()
end

-- ==================================================
-- FLY TO SAFE ZONE AND WAIT
-- ==================================================
local function FlyToSafeZoneAndWait()
    local Hum, Root = GetHumanoid()
    if not Root then return false end

    local DistToSafe = (Root.Position - SAFE_ZONE).Magnitude

    if DistToSafe <= SAFE_ZONE_DIST then
        print("[FarmingManager] ✅ Already at Safe Zone")
        return true
    end

    print("[FarmingManager] Fly to Safe Zone (Speed: " .. SAFE_FLY_SPEED .. ")...")

    SelfFlyTP(SAFE_ZONE, SAFE_FLY_SPEED, function()
        print("[FarmingManager] ✅ At Safe Zone")
    end)

    local WaitTime = 0
    while FarmingEnabled and WaitTime < 10 do
        local Hum2, Root2 = GetHumanoid()
        if Root2 then
            local Dist = (Root2.Position - SAFE_ZONE).Magnitude
            if Dist <= SAFE_ZONE_DIST then
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
-- WAIT FOR DAY
-- ==================================================
local function WaitForDay()
    print("[FarmingManager] Waiting for Day...")

    while FarmingEnabled do
        local Phase = GetPhase()
        CurrentPhase = Phase

        if Phase == "Day" then
            print("[FarmingManager] ✅ Day Started!")
            return true
        end

        task.wait(DAY_CHECK_INTERVAL)
    end

    return false
end

-- ==================================================
-- START TELEPORT SYSTEM (AFK Mode)
-- ==================================================
local function StartTeleportSystem(EggUid)
    if not _G.YOKUDO_TeleportSystem then
        warn("[FarmingManager] TeleportSystem not loaded!")
        return
    end

    print("[FarmingManager] Starting TeleportSystem (AFK Mode):")
    print("  - Target UID: " .. tostring(EggUid))

    WaitingForTeleport = true
    _G.YOKUDO_TeleportSystem.EnableAFKMode()
    _G.YOKUDO_TeleportSystem.SetTargetId(EggUid)
    _G.YOKUDO_TeleportSystem.Enable()
end

-- ==================================================
-- ✅ CALLBACK ពី TeleportSystem
-- ==================================================
local function OnTeleportComplete()
    if not FarmingEnabled then return end
    if not WaitingForTeleport then return end

    WaitingForTeleport = false
    print("[FarmingManager] ✅ TeleportSystem Completed → Check New Egg")

    local BestEgg = FindBestEgg()

    if BestEgg then
        print("[FarmingManager] New Egg Found: " .. BestEgg.DisplayName)
        PendingEggUid = BestEgg.Uid

        local Phase = GetPhase()
        CurrentPhase = Phase

        task.spawn(function()
            local ReachedSafe = FlyToSafeZoneAndWait()
            if ReachedSafe and PendingEggUid then
                task.wait(SAFE_WAIT_AFTER_REACH)

                if Phase == "Day" then
                    print("[FarmingManager] ✅ Day → Start TeleportSystem Immediately")
                    StartTeleportSystem(PendingEggUid)
                    PendingEggUid = nil
                else
                    print("[FarmingManager] Night → Wait for Day")
                    local IsDay = WaitForDay()
                    if IsDay and PendingEggUid then
                        print("[FarmingManager] ✅ Day Reached → Start TeleportSystem")
                        StartTeleportSystem(PendingEggUid)
                        PendingEggUid = nil
                    end
                end
            end
        end)
    else
        print("[FarmingManager] No New Egg → AFK")
        if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
            _G.YOKUDO_AFKSystem.Enable()
            AFKStarted = true
        end
    end
end

-- ==================================================
-- MAIN LOOP
-- ==================================================
local function MainLoop()
    print("[FarmingManager] MainLoop Started")

    while FarmingEnabled do
        local Phase = GetPhase()
        CurrentPhase = Phase

        local BestEgg = FindBestEgg()

        if BestEgg then
            print("[FarmingManager] ✅ Egg Found: " .. BestEgg.DisplayName .. " | Phase: " .. Phase)

            PendingEggUid = BestEgg.Uid

            -- ✅ StopAll() រង់ចាំ JumpOut ចប់
            StopAll()
            task.wait(1)  -- ← បង្កើនពី 0.5 → 1

            local ReachedSafe = FlyToSafeZoneAndWait()

            if ReachedSafe then
                task.wait(SAFE_WAIT_AFTER_REACH)

                if Phase == "Day" then
                    print("[FarmingManager] ✅ Day → Start TeleportSystem Immediately")
                    StartTeleportSystem(PendingEggUid)
                    PendingEggUid = nil
                else
                    print("[FarmingManager] Night → Wait for Day")
                    local IsDay = WaitForDay()
                    if IsDay and PendingEggUid then
                        print("[FarmingManager] ✅ Day Reached → Start TeleportSystem")
                        StartTeleportSystem(PendingEggUid)
                        PendingEggUid = nil
                    end
                end
            end
        else
            if not AFKStarted then
                if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
                    _G.YOKUDO_AFKSystem.Enable()
                    AFKStarted = true
                    print("[FarmingManager] AFK Started (No Egg)")
                end
            end
        end

        task.wait(EGG_CHECK_INTERVAL)
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
    PendingEggUid = nil
    WaitingForTeleport = false

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

    AFKStarted = false
    PendingEggUid = nil
    WaitingForTeleport = false
    CurrentState = "IDLE"
    CurrentPhase = "UNKNOWN"
    print("[YOKUDO] FarmingManager: OFF")
end

local function Toggle()
    if FarmingEnabled then Disable() else Enable() end
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
    FindBestEgg = FindBestEgg,
    EGG_CHECK_INTERVAL = EGG_CHECK_INTERVAL,
    DAY_CHECK_INTERVAL = DAY_CHECK_INTERVAL,
    FLY_SPEED = FLY_SPEED,
    SAFE_FLY_SPEED = SAFE_FLY_SPEED,
    -- ✅ Callback សម្រាប់ TeleportSystem
    OnTeleportComplete = OnTeleportComplete,
}

-- ==================================================
-- BUILD MESHID MAP ON LOAD
-- ==================================================
task.spawn(function()
    task.wait(2)
    BuildMeshIdMap()
end)

print("✅ FarmingManager Loaded (Egg Check + Day/Night + AFK + TeleportSystem + Callback + StopAll Fixed)")
