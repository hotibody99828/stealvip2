-- ==================================================
-- YOKUDO HUB | FEATURE | Farming Manager (FULL AUTO LOOP)
-- ✅ Top1 Divine → Top2 Eternal → Top3 Secret/Mythic → Top4 Legendary → Top5+
-- ✅ យក Top1 មុនឲ្យអស់សិន (តាម $/s ខ្ពស់ជាងគេមុន)
-- ✅ ចាំយក Top2 → Top3 → Top4 → Top5
-- ✅ Full Auto Loop (Start → Check Egg → Teleport → AFK → Loop)
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
-- SETTINGS
-- ==================================================
local NIGHT_CHECK_INTERVAL = 0.03
local DAY_CHECK_INTERVAL = 0.05
local SAFE_ZONE = Vector3.new(533, 70, -366)
local SAFE_ZONE_DIST = 5
local SAFE_WAIT_AFTER_REACH = 1
local WALK_TIMEOUT = 30
local LOOP_WAIT_AFTER_AFK = 2

-- ==================================================
-- CACHE SYSTEM
-- ==================================================
local Cache = {
    MeshIdMap = {},
    MeshIdMapBuilt = false,
    PetData = {},
    UidCategory = {},
}

-- ==================================================
-- RARITY PRIORITY (Top1-Top5)
-- Top1 Divine, Top2 Eternal, Top3 Secret/Mythic, Top4 Legendary, Top5+ (Epic, Rare, Uncommon, Common)
-- ==================================================
local RARITY_PRIORITY = {
    Divine = 1,
    Eternal = 2,
    Secret = 3,
    Mythic = 3,
    Legendary = 4,
    Epic = 5,
    Rare = 5,
    Uncommon = 5,
    Common = 5
}

-- ==================================================
-- SELECTED RARITIES (Default: Top1-Top5 Only)
-- ==================================================
local SelectedRarities = {
    Divine = true,
    Eternal = true,
    Secret = true,
    Mythic = true,
    Legendary = true,
    Epic = false,      -- ឲ្យ user select ខ្លួនឯង
    Rare = false,      -- ឲ្យ user select ខ្លួនឯង
    Uncommon = false,  -- ឲ្យ user select ខ្លួនឯង
    Common = false     -- ឲ្យ user select ខ្លួនឯង
}

-- ==================================================
-- BUILD MESHID MAP
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
-- GET PET DATA
-- ==================================================
local function GetPetData(AssetCategory)
    if not AssetCategory then return nil end

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

    Cache.PetData[AssetCategory] = Data
    return Data
end

-- ==================================================
-- FIND ASSET CATEGORY
-- ==================================================
local function FindAssetCategory(EggModel)
    if not EggModel then return nil end

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
-- SORT EGGS (តាម Rarity Priority មុន បន្ទាប់មក $/s)
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
-- FIND BEST EGG (Top1 មុនឲ្យអស់ → ចាំ Top2 → Top3 → Top4 → Top5)
-- ==================================================
local function FindBestEgg()
    local EggList = {}

    local Container = workspace:FindFirstChild("AreaEggSlotsClient")
    if Container then
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
    end

    if #EggList > 0 then
        SortEggs(EggList)
        return EggList[1]
    end

    for _, Obj in ipairs(workspace:GetChildren()) do
        if Obj:IsA("Model") and string.find(Obj.Name, "FirstAreaEgg") then
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
local WaitingForTeleport = false

local WalkConnection = nil

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
-- CLEANUP WALK
-- ==================================================
local function CleanupWalk()
    if WalkConnection then
        WalkConnection:Disconnect()
        WalkConnection = nil
    end

    local Hum = GetHum()
    local Root = GetRoot()
    if Hum then
        pcall(function()
            Hum:MoveTo(Root and Root.Position or Hum.Parent.HumanoidRootPart.Position)
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
    CleanupWalk()

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

    print(string.format("[FarmingManager] Walk TP → %s | Speed: %d", tostring(Destination), Hum.WalkSpeed))

    local StartTime = tick()
    local LastCheck = 0

    WalkConnection = RunService.Heartbeat:Connect(function()
        if not FarmingEnabled then
            CleanupWalk()
            return
        end

        local Hum2 = GetHum()
        local Root2 = GetRoot()
        if not Hum2 or not Root2 then
            CleanupWalk()
            return
        end
        if Hum2.Health <= 0 then
            CleanupWalk()
            return
        end

        Hum2:MoveTo(Destination)

        if tick() - LastCheck > 0.05 then
            LastCheck = tick()

            local Dist = (Root2.Position - Destination).Magnitude
            if Dist <= 3 then
                CleanupWalk()
                print(string.format("[FarmingManager] ✅ Walk TP Arrived | Dist: %.1f", Dist))
                if Callback then Callback() end
                return
            end

            if tick() - StartTime > WALK_TIMEOUT then
                CleanupWalk()
                print("[FarmingManager] Walk TP Timeout")
                if Callback then Callback() end
                return
            end
        end
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

    if _G.YOKUDO_TeleportSystem and _G.YOKUDO_TeleportSystem.IsEnabled() then
        _G.YOKUDO_TeleportSystem.Disable()
        print("[FarmingManager] ✅ TeleportSystem Stopped")
    end

    CleanupWalk()
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

    WalkTP(SAFE_ZONE)

    local WaitTime = 0
    while FarmingEnabled and WaitTime < 15 do
        local Root2 = GetRoot()
        if Root2 then
            local Dist = (Root2.Position - SAFE_ZONE).Magnitude
            if Dist <= SAFE_ZONE_DIST then return true end
        end
        task.wait(0.05)
        WaitTime = WaitTime + 0.05
    end

    return false
end

-- ==================================================
-- START TELEPORT SYSTEM
-- ==================================================
local function StartTeleportSystem(EggUid)
    if not _G.YOKUDO_TeleportSystem then
        warn("[FarmingManager] TeleportSystem not loaded!")
        return false
    end

    print("[FarmingManager] Starting TeleportSystem | UID:", EggUid)

    WaitingForTeleport = true
    _G.YOKUDO_TeleportSystem.SetTargetId(EggUid)
    _G.YOKUDO_TeleportSystem.Enable()
    return true
end

-- ==================================================
-- ENABLE AFK
-- ==================================================
local function EnableAFK()
    if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
        _G.YOKUDO_AFKSystem.Enable()
        AFKStarted = true
        print("[FarmingManager] ✅ AFKSystem Enabled")
    end
end

-- ==================================================
-- CALLBACK ពី TELEPORT SYSTEM
-- ==================================================
local function OnTeleportComplete()
    if not FarmingEnabled then
        print("[FarmingManager] OnTeleportComplete: Farming not enabled → Skip")
        return
    end
    if not WaitingForTeleport then
        print("[FarmingManager] OnTeleportComplete: Not waiting → Skip")
        return
    end

    WaitingForTeleport = false
    AFKStarted = false
    print("[FarmingManager] ✅ TeleportSystem Completed → Check New Egg")

    local BestEgg = FindBestEgg()

    if BestEgg then
        print("[FarmingManager] New Egg Found:", BestEgg.DisplayName, "| Rarity:", BestEgg.Rarity, "| Location:", BestEgg.Location)
        PendingEggUid = BestEgg.Uid

        task.spawn(function()
            local ReachedSafe = FlyToSafeZoneAndWait()
            if ReachedSafe and PendingEggUid then
                task.wait(SAFE_WAIT_AFTER_REACH)
                StartTeleportSystem(PendingEggUid)
                PendingEggUid = nil
            else
                print("[FarmingManager] ⚠️ Cannot reach Safe Zone → AFK")
                EnableAFK()
            end
        end)
    else
        print("[FarmingManager] ❌ No Egg → Enable AFK")
        EnableAFK()
    end
end

-- ==================================================
-- MAIN LOOP (FULL AUTO)
-- ==================================================
local function MainLoop()
    print("[FarmingManager] MainLoop Started (Full Auto)")

    while FarmingEnabled do
        local Phase = GetPhase()
        CurrentPhase = Phase

        -- Check Egg
        local BestEgg = FindBestEgg()

        if BestEgg then
            print("[FarmingManager] ✅ Egg Found:", BestEgg.DisplayName, "| Rarity:", BestEgg.Rarity, "| Location:", BestEgg.Location)
            PendingEggUid = BestEgg.Uid

            -- Stop AFK / Teleport ចាស់
            StopAll()
            task.wait(0.3)

            -- ទៅ Safe Zone មុន
            local ReachedSafe = FlyToSafeZoneAndWait()
            if ReachedSafe and PendingEggUid then
                task.wait(SAFE_WAIT_AFTER_REACH)
                -- Start Teleport System
                StartTeleportSystem(PendingEggUid)
                PendingEggUid = nil

                -- រង់ចាំ TeleportSystem បញ្ចប់
                while WaitingForTeleport and FarmingEnabled do
                    task.wait(0.2)
                end
            else
                print("[FarmingManager] ⚠️ Cannot reach Safe Zone → AFK")
                EnableAFK()
            end
        else
            print("[FarmingManager] ❌ No Egg → Enable AFK")
            EnableAFK()
        end

        -- រង់ចាំមុនពេល Loop បន្ត
        task.wait(LOOP_WAIT_AFTER_AFK)
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

    print("[YOKUDO] FarmingManager: ON (Full Auto Loop)")
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
        if InContainer then return "spawn" end
        local InWorkspace = workspace:FindFirstChild(Uid) ~= nil
        if InWorkspace then return "workspace" end
        return "none"
    end,

    NIGHT_CHECK_INTERVAL = NIGHT_CHECK_INTERVAL,
    DAY_CHECK_INTERVAL = DAY_CHECK_INTERVAL,
    WALK_TIMEOUT = WALK_TIMEOUT,
    OnVIPTPComplete = OnTeleportComplete,
    OnTeleportComplete = OnTeleportComplete,
    WalkTP = WalkTP,
}

-- ==================================================
-- BUILD CACHE ON LOAD
-- ==================================================
task.spawn(function()
    task.wait(1)
    BuildMeshIdMap()
    print("[FarmingManager] Cache Ready")
end)

-- ==================================================
-- PERIODIC CACHE CLEANUP (រាល់ 30s)
-- ==================================================
task.spawn(function()
    while task.wait(30) do
        Cache.UidCategory = {}
        print("[FarmingManager] Uid Cache Cleared")
    end
end)

print("✅ FarmingManager Loaded (Full Auto Loop — Top1-Top5)")
