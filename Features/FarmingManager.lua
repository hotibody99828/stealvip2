-- ==================================================
-- YOKUDO HUB | FEATURE | Farming Manager (FAST + CLEAR)
-- ✅ Cache System → លឿន
-- ✅ Fast Check → Night 0.03s / Day 0.05s
-- ✅ Uid Cache → មិន Loop MeshId រាល់ដង
-- ✅ PetData Cache → មិន Require រាល់ដង
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

-- ==================================================
-- SETTINGS (FAST)
-- ==================================================
local NIGHT_CHECK_INTERVAL = 0.03      -- ✅ លឿន
local DAY_CHECK_INTERVAL = 0.05        -- ✅ លឿន
local SAFE_ZONE = Vector3.new(533, 70, -366)
local SAFE_ZONE_DIST = 5
local SAFE_WAIT_AFTER_REACH = 1
local FLY_SPEED = 1000
local SAFE_FLY_SPEED = 500
local RETURN_SPEED = 800
local FLY_OFFSET = 15
local METHOD = "InstantTeleport"

-- ==================================================
-- CACHE SYSTEM
-- ==================================================
local Cache = {
    MeshIdMap = {},          -- MeshId → Category
    MeshIdMapBuilt = false,
    PetData = {},            -- Category → { Rarity, EarningRate, DisplayName }
    UidCategory = {},        -- Uid → Category
}

local SelectedRarities = { Divine = true, Eternal = true, Secret = true }

local RARITY_PRIORITY = {
    Divine = 1,
    Eternal = 2,
    Secret = 3
}

-- ==================================================
-- BUILD MESHID MAP (ម្ដងគត់)
-- ==================================================
local function BuildMeshIdMap()
    if Cache.MeshIdMapBuilt then return end

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
                        Cache.MeshIdMap[Desc.MeshId] = Config.Name
                    end
                    if Desc:IsA("SpecialMesh") and Desc.MeshId ~= "" then
                        Cache.MeshIdMap[Desc.MeshId] = Config.Name
                    end
                end
            end
        end
    end

    Cache.MeshIdMapBuilt = true
    print("[FarmingManager] MeshId Map Built (Cache)")
end

-- ==================================================
-- GET PET DATA (CACHE)
-- ==================================================
local function GetPetData(AssetCategory)
    if not AssetCategory then return nil end

    -- ✅ Cache Hit
    if Cache.PetData[AssetCategory] then
        return Cache.PetData[AssetCategory]
    end

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

    local Data = {
        Rarity = Module.Rarity and (Module.Rarity._id or Module.Rarity.RarityId) or nil,
        EarningRate = Module.EarningRate or 0,
        DisplayName = Module.DisplayName or AssetCategory
    }

    -- ✅ Save Cache
    Cache.PetData[AssetCategory] = Data
    return Data
end

-- ==================================================
-- FIND ASSET CATEGORY (CACHE Uid)
-- ==================================================
local function FindAssetCategory(EggModel)
    if not EggModel then return nil end

    -- ✅ Cache Hit តាម Uid
    local Uid = EggModel.Name
    if Cache.UidCategory[Uid] then
        return Cache.UidCategory[Uid]
    end

    if not Cache.MeshIdMapBuilt then BuildMeshIdMap() end

    for _, Desc in ipairs(EggModel:GetDescendants()) do
        if Desc:IsA("MeshPart") and Desc.MeshId ~= "" then
            local Cat = Cache.MeshIdMap[Desc.MeshId]
            if Cat then
                Cache.UidCategory[Uid] = Cat
                return Cat
            end
        end
        if Desc:IsA("SpecialMesh") and Desc.MeshId ~= "" then
            local Cat = Cache.MeshIdMap[Desc.MeshId]
            if Cat then
                Cache.UidCategory[Uid] = Cat
                return Cat
            end
        end
    end

    return nil
end

-- ==================================================
-- SORT EGGS
-- ==================================================
local function SortEggs(EggList)
    table.sort(EggList, function(a, b)
        local Pa = RARITY_PRIORITY[a.Rarity] or 999
        local Pb = RARITY_PRIORITY[b.Rarity] or 999
        if Pa ~= Pb then return Pa < Pb end
        return a.EarningRate > b.EarningRate
    end)
end

-- ==================================================
-- FIND BEST EGG (FAST)
-- ==================================================
local function FindBestEgg()
    local Container = workspace:FindFirstChild("AreaEggSlotsClient")
    if not Container then return nil end

    local EggList = {}

    -- ✅ Check Container (Spawn)
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
                        DisplayName = Data.DisplayName,
                        Location = "spawn"
                    })
                end
            end
        end
    end

    -- ✅ Check Workspace (Egg ធ្លាក់)
    for _, Obj in ipairs(workspace:GetChildren()) do
        if Obj:IsA("Model") and string.find(Obj.Name, "FirstAreaEgg") then
            local IsInContainer = Container:FindFirstChild(Obj.Name)
            if not IsInContainer then
                local Category = FindAssetCategory(Obj)
                if Category then
                    local Data = GetPetData(Category)
                    if Data and SelectedRarities[Data.Rarity] then
                        table.insert(EggList, {
                            Slot = Obj,
                            Uid = Obj.Name,
                            Rarity = Data.Rarity,
                            EarningRate = Data.EarningRate,
                            DisplayName = Data.DisplayName,
                            Location = "workspace"
                        })
                    end
                end
            end
        end
    end

    if #EggList == 0 then return nil end
    SortEggs(EggList)
    return EggList[1]
end

-- ==================================================
-- SET RARITIES
-- ==================================================
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
local WaitingForVIPTP = false

local FlyConnection = nil
local BodyVelocity = nil
local BodyGyro = nil

-- ==================================================
-- GET CHAR / ROOT / HUM
-- ==================================================
local function GetChar()
    return Player.Character
end

local function GetRoot()
    local Char = GetChar()
    if not Char then return nil end
    return Char:FindFirstChild("HumanoidRootPart")
end

local function GetHum()
    local Char = GetChar()
    if not Char then return nil end
    return Char:FindFirstChildOfClass("Humanoid")
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
    local Hum = GetHum()
    local Root = GetRoot()
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

    local Hum = GetHum()
    local Root = GetRoot()
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

        local Hum2 = GetHum()
        local Root2 = GetRoot()
        if not Hum2 or not Root2 then
            CleanupFly()
            return
        end
        if Hum2.Health <= 0 then return end
        if not BodyVelocity or not BodyGyro then CleanupFly() return end

        local CurrentPos = Root2.Position
        local Direction = Destination - CurrentPos
        local TotalDist = Direction.Magnitude

        if TotalDist <= 3 then
            CleanupFly()
            Root2.CFrame = CFrame.new(Destination)
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero
            if Callback then Callback() end
            return
        end

        if tick() - StartTime > 30 then
            CleanupFly()
            if Callback then Callback() end
            return
        end

        BodyVelocity.Velocity = Direction.Unit * Speed
        BodyGyro.CFrame = CFrame.new(CurrentPos, Destination)
    end)
end

-- ==================================================
-- GET PHASE (FAST)
-- ==================================================
local function GetPhase()
    if AreaEggCycle then
        local Success, IsNight = pcall(function()
            return AreaEggCycle.IsNightPhase(Workspace:GetServerTimeNow())
        end)
        if Success then
            return IsNight and "Night" or "Day"
        end
    end

    local Success, Text = pcall(function()
        return Player.PlayerGui.HUD.GameHUD.BottomRight.NightTimer.Value.Text
    end)
    if Success and Text then
        local M = tonumber(string.match(Text, "(%d+)m")) or 0
        local S = tonumber(string.match(Text, "(%d+)s")) or 0
        local Sec = M * 60 + S
        return Sec > 10 and "Day" or "Night"
    end

    return "UNKNOWN"
end

-- ==================================================
-- STOP ALL
-- ==================================================
local function StopAll()
    if _G.YOKUDO_AFKSystem and _G.YOKUDO_AFKSystem.IsEnabled() then
        local TreadmillPos = _G.YOKUDO_AFKSystem.GetMyTreadmillPos()
        if not TreadmillPos then
            local _, Treadmill = _G.YOKUDO_AFKSystem.FindMyPlotAndTreadmill()
            if Treadmill then TreadmillPos = Treadmill.Position end
        end
        if TreadmillPos then
            _G.YOKUDO_AFKSystem.JumpOutTreadmill(TreadmillPos, function()
                _G.YOKUDO_AFKSystem.Disable()
                AFKStarted = false
            end)
        else
            _G.YOKUDO_AFKSystem.Disable()
            AFKStarted = false
        end
    end

    if _G.YOKUDO_VIPTP and _G.YOKUDO_VIPTP.IsEnabled() then
        _G.YOKUDO_VIPTP.Disable()
    end
    if _G.YOKUDO_TeleportSystem and _G.YOKUDO_TeleportSystem.IsEnabled() then
        _G.YOKUDO_TeleportSystem.Disable()
    end

    CleanupFly()
end

-- ==================================================
-- FLY TO SAFE ZONE AND WAIT
-- ==================================================
local function FlyToSafeZoneAndWait()
    local Root = GetRoot()
    if not Root then return false end

    local DistToSafe = (Root.Position - SAFE_ZONE).Magnitude
    if DistToSafe <= SAFE_ZONE_DIST then
        return true
    end

    SelfFlyTP(SAFE_ZONE, SAFE_FLY_SPEED)

    local WaitTime = 0
    while FarmingEnabled and WaitTime < 10 do
        local Root2 = GetRoot()
        if Root2 then
            local Dist = (Root2.Position - SAFE_ZONE).Magnitude
            if Dist <= SAFE_ZONE_DIST then return true end
        end
        task.wait(0.05)  -- ✅ លឿន
        WaitTime = WaitTime + 0.05
    end

    return false
end

-- ==================================================
-- START VIPTP
-- ==================================================
local function StartVIPTP(EggUid)
    if not _G.YOKUDO_VIPTP then
        warn("[FarmingManager] VIPTP not loaded!")
        return
    end

    print("[FarmingManager] Starting VIPTP | UID:", EggUid)

    WaitingForVIPTP = true
    _G.YOKUDO_VIPTP.SetTargetId(EggUid)
    _G.YOKUDO_VIPTP.Enable()
end

-- ==================================================
-- CALLBACK ពី VIPTP
-- ==================================================
local function OnVIPTPComplete()
    if not FarmingEnabled then return end
    if not WaitingForVIPTP then return end

    WaitingForVIPTP = false
    AFKStarted = false
    print("[FarmingManager] ✅ VIPTP Completed → Check New Egg")

    local BestEgg = FindBestEgg()

    if BestEgg then
        print("[FarmingManager] New Egg:", BestEgg.DisplayName, "|", BestEgg.Location)
        PendingEggUid = BestEgg.Uid

        task.spawn(function()
            local ReachedSafe = FlyToSafeZoneAndWait()
            if ReachedSafe and PendingEggUid then
                task.wait(SAFE_WAIT_AFTER_REACH)
                StartVIPTP(PendingEggUid)
                PendingEggUid = nil
            end
        end)
    else
        print("[FarmingManager] No Egg → AFK")
        if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
            _G.YOKUDO_AFKSystem.Enable()
            AFKStarted = true
        end
    end
end

-- ==================================================
-- WAIT FOR DAY
-- ==================================================
local function WaitForDay()
    while FarmingEnabled do
        local Phase = GetPhase()
        CurrentPhase = Phase
        if Phase == "Day" then return true end
        task.wait(DAY_CHECK_INTERVAL)
    end
    return false
end

-- ==================================================
-- NIGHT LOOP (FAST)
-- ==================================================
local function NightLoop()
    print("[FarmingManager] NightLoop (0.03s)")

    while FarmingEnabled do
        local Phase = GetPhase()
        CurrentPhase = Phase

        if Phase == "Day" then return end

        local BestEgg = FindBestEgg()

        if BestEgg then
            print("[FarmingManager] ✅ Night + Egg:", BestEgg.DisplayName, "|", BestEgg.Location)
            PendingEggUid = BestEgg.Uid

            StopAll()
            task.wait(0.3)  -- ✅ លឿន

            local ReachedSafe = FlyToSafeZoneAndWait()
            if ReachedSafe then
                task.wait(SAFE_WAIT_AFTER_REACH)
                local IsDay = WaitForDay()
                if IsDay and PendingEggUid then
                    StartVIPTP(PendingEggUid)
                    PendingEggUid = nil
                    while WaitingForVIPTP and FarmingEnabled do
                        task.wait(0.2)  -- ✅ លឿន
                    end
                end
            end
            return
        else
            if not AFKStarted then
                if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
                    _G.YOKUDO_AFKSystem.Enable()
                    AFKStarted = true
                end
            end
        end

        task.wait(NIGHT_CHECK_INTERVAL)
    end
end

-- ==================================================
-- DAY LOOP (FAST)
-- ==================================================
local function DayLoop()
    print("[FarmingManager] DayLoop (0.05s)")

    while FarmingEnabled do
        local Phase = GetPhase()
        CurrentPhase = Phase

        if Phase == "Night" then return end

        local BestEgg = FindBestEgg()

        if BestEgg then
            print("[FarmingManager] ✅ Day + Egg:", BestEgg.DisplayName, "|", BestEgg.Location)

            StopAll()
            task.wait(0.3)

            FlyToSafeZoneAndWait()
            task.wait(0.5)

            StartVIPTP(BestEgg.Uid)

            while WaitingForVIPTP and FarmingEnabled do
                task.wait(0.2)
            end
        else
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
        local Phase = GetPhase()
        CurrentPhase = Phase

        if Phase == "Day" then
            DayLoop()
        else
            NightLoop()
        end

        task.wait(0.05)  -- ✅ លឿន
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
    WaitingForVIPTP = false

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
    WaitingForVIPTP = false
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

    -- ✅ ផ្ដល់ Egg Data តាម UID
    GetEggData = function(Uid)
        if not Uid then return nil end
        local Container = workspace:FindFirstChild("AreaEggSlotsClient")
        local Slot = (Container and Container:FindFirstChild(Uid)) or workspace:FindFirstChild(Uid)
        if not Slot then return nil end
        local Category = FindAssetCategory(Slot)
        if not Category then return nil end
        return GetPetData(Category)
    end,

    GetUidLocation = function(Uid)
        if not Uid then return "none" end
        local Container = workspace:FindFirstChild("AreaEggSlotsClient")
        local InContainer = Container and Container:FindFirstChild(Uid) ~= nil
        local InWorkspace = workspace:FindFirstChild(Uid) ~= nil
        if InContainer and InWorkspace then return "both"
        elseif InContainer then return "spawn"
        elseif InWorkspace then return "workspace"
        else return "none" end
    end,

    NIGHT_CHECK_INTERVAL = NIGHT_CHECK_INTERVAL,
    DAY_CHECK_INTERVAL = DAY_CHECK_INTERVAL,
    FLY_SPEED = FLY_SPEED,
    SAFE_FLY_SPEED = SAFE_FLY_SPEED,
    RETURN_SPEED = RETURN_SPEED,
    FLY_OFFSET = FLY_OFFSET,
    METHOD = METHOD,
    OnVIPTPComplete = OnVIPTPComplete,
}

-- ==================================================
-- BUILD CACHE ON LOAD
-- ==================================================
task.spawn(function()
    task.wait(1)
    BuildMeshIdMap()
    print("[FarmingManager] Cache Ready")
end)

print("✅ FarmingManager Loaded (FAST + CLEAR + CACHE)")
