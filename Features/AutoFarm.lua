-- ==================================================
-- YOKUDO HUB | FEATURE | Auto Farm (FAST)
-- ✅ Update ឲ្យត្រូវនឹង TeleportSystem v22
-- ✅ Cache PetData + UidCategory → លឿន
-- ✅ Auto Stop ពេល Egg បាត់
-- ==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local Container = workspace:WaitForChild("AreaEggSlotsClient")

-- ==================================================
-- CACHE SYSTEM
-- ==================================================
local Cache = {
    MeshIdMap = {},
    MeshIdMapBuilt = false,
    PetData = {},
    UidCategory = {},
}

local AutoFarmEnabled = false
local SelectedEgg = nil
local EggList = {}

-- ==================================================
-- ASSETS
-- ==================================================
local Assets = ReplicatedStorage:WaitForChild("Data"):WaitForChild("Assets")
local Configs = Assets:WaitForChild("Configs")
local EggModels = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Models"):WaitForChild("Eggs")

-- ==================================================
-- MUTATIONS MODULE (CACHE)
-- ==================================================
local MutationsModule = nil
pcall(function()
    MutationsModule = require(ReplicatedStorage.Shared.Modules.Mutations)
end)

-- ==================================================
-- BUILD MESHID MAP (ម្ដងគត់)
-- ==================================================
local function BuildMeshIdMap()
    if Cache.MeshIdMapBuilt then return end

    for _, Config in ipairs(Configs:GetChildren()) do
        local Success, Module = pcall(function()
            return require(Config)
        end)
        if Success and Module and Module.Egg then
            local ModelName = Module.Egg.ModelName or Config.Name
            local EggTemplate = EggModels:FindFirstChild(ModelName)
            if EggTemplate then
                for _, descendant in ipairs(EggTemplate:GetDescendants()) do
                    if descendant:IsA("MeshPart") and descendant.MeshId ~= "" then
                        Cache.MeshIdMap[descendant.MeshId] = Config.Name
                    end
                    if descendant:IsA("SpecialMesh") and descendant.MeshId ~= "" then
                        Cache.MeshIdMap[descendant.MeshId] = Config.Name
                    end
                end
            end
        end
    end

    Cache.MeshIdMapBuilt = true
    print("[AutoFarm] MeshId Map Built (Cache)")
end

BuildMeshIdMap()

-- ==================================================
-- GET PET DATA (CACHE)
-- ==================================================
local function GetPetData(AssetCategory)
    if not AssetCategory then return nil end

    if Cache.PetData[AssetCategory] then
        return Cache.PetData[AssetCategory]
    end

    local Config = Configs:FindFirstChild(AssetCategory)
    if not Config then return nil end

    local Data = {
        Name = AssetCategory,
        DisplayName = AssetCategory,
        EarningRate = 0,
        Icon = nil
    }

    local Success, Module = pcall(function()
        return require(Config)
    end)

    if Success and Module then
        Data.DisplayName = Module.DisplayName or AssetCategory
        Data.EarningRate = Module.EarningRate or 0
        Data.Icon = Module.Icon
    end

    Cache.PetData[AssetCategory] = Data
    return Data
end

-- ==================================================
-- FORMAT MONEY
-- ==================================================
local function FormatMoney(Amount)
    if type(Amount) ~= "number" then return tostring(Amount) end
    if Amount >= 1e12 then
        return string.format("%.2fT", Amount / 1e12)
    elseif Amount >= 1e9 then
        return string.format("%.2fB", Amount / 1e9)
    elseif Amount >= 1e6 then
        return string.format("%.2fM", Amount / 1e6)
    elseif Amount >= 1e3 then
        return string.format("%.2fK", Amount / 1e3)
    else
        return tostring(math.floor(Amount))
    end
end

-- ==================================================
-- CALCULATE REAL RATE (CACHE MUTATIONS)
-- ==================================================
local function CalculateRatePerSecond(EarningRate, Scale, Mutations)
    local PayoutFactor
    if Scale <= 5 then
        PayoutFactor = Scale ^ 1.85
    else
        PayoutFactor = (Scale / 5) ^ 1.2 * 19.637875755794113
    end

    local MutationMultiplier = 1
    if Mutations and #Mutations > 0 and MutationsModule then
        local Success, Result = pcall(function()
            return MutationsModule.EarningsFor(Mutations)
        end)
        if Success then
            MutationMultiplier = Result
        end
    end

    return math.round(EarningRate * PayoutFactor * MutationMultiplier)
end

-- ==================================================
-- FIND ASSET CATEGORY (CACHE Uid)
-- ==================================================
local function FindAssetCategory(EggModel)
    if not EggModel then return nil end

    local Uid = EggModel.Name
    if Cache.UidCategory[Uid] then
        return Cache.UidCategory[Uid]
    end

    for _, descendant in ipairs(EggModel:GetDescendants()) do
        if descendant:IsA("MeshPart") and descendant.MeshId ~= "" then
            local Category = Cache.MeshIdMap[descendant.MeshId]
            if Category then
                Cache.UidCategory[Uid] = Category
                return Category
            end
        end
        if descendant:IsA("SpecialMesh") and descendant.MeshId ~= "" then
            local Category = Cache.MeshIdMap[descendant.MeshId]
            if Category then
                Cache.UidCategory[Uid] = Category
                return Category
            end
        end
    end
    return nil
end

-- ==================================================
-- SCAN EGGS (FAST)
-- ==================================================
local function ScanEggs()
    EggList = {}

    for _, child in ipairs(Container:GetChildren()) do
        if child:IsA("Model") and not string.find(child.Name, "FirstAreaEgg") then
            local AssetCategory = FindAssetCategory(child)
            if AssetCategory then
                local Data = GetPetData(AssetCategory)
                if Data then
                    local Scale = child:GetAttribute("AssetScale") or 1
                    local Mutations = child:GetAttribute("Mutations") or {}
                    local RealRate = CalculateRatePerSecond(Data.EarningRate, Scale, Mutations)

                    table.insert(EggList, {
                        Id = child.Name,
                        Category = AssetCategory,
                        DisplayName = Data.DisplayName,
                        Icon = Data.Icon,
                        EarningRate = RealRate,
                        Model = child
                    })
                end
            end
        end
    end

    table.sort(EggList, function(a, b)
        return a.EarningRate > b.EarningRate
    end)

    return EggList
end

-- ==================================================
-- ✅ CHECK EGG GONE
-- ==================================================
local function IsEggGone(Uid)
    if not Uid then return true end
    local InWorkspace = workspace:FindFirstChild(Uid) ~= nil
    local InContainer = Container and Container:FindFirstChild(Uid) ~= nil
    if not InWorkspace and not InContainer then
        return true
    end
    return false
end

-- ==================================================
-- ENABLE / DISABLE
-- ==================================================
local function EnableAutoFarm()
    AutoFarmEnabled = true
    print("[YOKUDO] Auto Farm: ON")
end

local function DisableAutoFarm()
    AutoFarmEnabled = false
    print("[YOKUDO] Auto Farm: OFF")
end

-- ==================================================
-- SELECT EGG
-- ==================================================
local function SelectEgg(EggData)
    SelectedEgg = EggData
    print("[YOKUDO] Selected Egg: " .. EggData.DisplayName .. " ($" .. FormatMoney(EggData.EarningRate) .. "/s)")

    -- ✅ Update TeleportSystem Target
    if _G.YOKUDO_TeleportSystem then
        _G.YOKUDO_TeleportSystem.SetTargetId(EggData.Id)
        print("[YOKUDO] TeleportSystem Target: " .. EggData.Id)
    end
end

-- ==================================================
-- START TELEPORT (v22)
-- ==================================================
local function StartTeleport()
    if not SelectedEgg then
        warn("[YOKUDO] No Egg Selected")
        return
    end

    print("[YOKUDO] Start Teleport | UID: " .. SelectedEgg.Id)

    if _G.YOKUDO_TeleportSystem then
        _G.YOKUDO_TeleportSystem.SetTargetId(SelectedEgg.Id)
        _G.YOKUDO_TeleportSystem.SetSpeed(200)
        _G.YOKUDO_TeleportSystem.Enable()
    else
        warn("[YOKUDO] TeleportSystem not loaded!")
    end
end

-- ==================================================
-- STOP TELEPORT
-- ==================================================
local function StopTeleport()
    if _G.YOKUDO_TeleportSystem then
        _G.YOKUDO_TeleportSystem.Disable()
    end
    print("[YOKUDO] Stop Teleport")
end

-- ==================================================
-- ✅ AUTO STOP CHECK THREAD
-- ==================================================
local CheckThread = nil

local function StartCheckThread()
    if CheckThread then
        pcall(function() task.cancel(CheckThread) end)
        CheckThread = nil
    end

    CheckThread = task.spawn(function()
        while AutoFarmEnabled do
            task.wait(0.5)

            -- ✅ Check Selected Egg Gone
            if SelectedEgg and SelectedEgg.Id then
                if IsEggGone(SelectedEgg.Id) then
                    print("[AutoFarm] ⚠️ Selected Egg Gone → Auto Stop")
                    DisableAutoFarm()
                    StopTeleport()
                    return
                end
            end
        end
    end)
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_AutoFarm = {
    Enable = EnableAutoFarm,
    Disable = DisableAutoFarm,
    IsEnabled = function() return AutoFarmEnabled end,
    ScanEggs = ScanEggs,
    GetEggList = function() return EggList end,
    SelectEgg = SelectEgg,
    StartTeleport = StartTeleport,
    StopTeleport = StopTeleport,
    GetSelectedEgg = function() return SelectedEgg end,
    FormatMoney = FormatMoney,
    IsEggGone = IsEggGone,

    -- ✅ Start Auto Farm + Check
    StartAuto = function(EggData)
        SelectEgg(EggData)
        EnableAutoFarm()
        StartTeleport()
        StartCheckThread()
    end,

    -- ✅ Stop Auto Farm
    StopAuto = function()
        DisableAutoFarm()
        StopTeleport()
        if CheckThread then
            pcall(function() task.cancel(CheckThread) end)
            CheckThread = nil
        end
    end,

    -- ✅ Clear Cache
    ClearCache = function()
        Cache.UidCategory = {}
        print("[AutoFarm] Uid Cache Cleared")
    end,
}

-- ==================================================
-- REGISTER
-- ==================================================
if _G.YOKUDO_CharacterSystem then
    _G.YOKUDO_CharacterSystem:RegisterFeature({
        Name = "AutoFarm",
        Enable = EnableAutoFarm,
        Disable = DisableAutoFarm,
        IsEnabled = function() return AutoFarmEnabled end,
        OnCharacterAdded = function(Char, Hum, Root)
            if AutoFarmEnabled and SelectedEgg then
                task.wait(2)
                pcall(function()
                    if _G.YOKUDO_TeleportSystem and _G.YOKUDO_TeleportSystem.IsEnabled() then
                        StartTeleport()
                    end
                end)
            end
        end
    })
end

print("✅ AutoFarm Feature Loaded (v22 - Update for TeleportSystem)")
