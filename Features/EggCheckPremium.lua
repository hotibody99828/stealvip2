-- ==================================================
-- YOKUDO HUB | FEATURE | Egg Check Premium
-- ✅ ប្រើ RarityNumber ពី Module ពិតប្រាកដ
-- ✅ Check Name Pet + $/s + Type
-- ✅ RarityNumber ខ្ពស់ = កម្រជាង
-- ==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

-- ==================================================
-- STATE
-- ==================================================
local SelectedRarities = {}
local RarityCache = {}

-- ==================================================
-- MESHID MAP
-- ==================================================
local MeshIdMap = {}
local MeshIdMapBuilt = false

-- ==================================================
-- PARSE RARITY VALUE (1 in X)
-- ==================================================
local function ParseRarityValue(ValueStr)
    if not ValueStr then return 0 end
    local NumStr = string.match(ValueStr, "1 in ([%d,]+)")
    if not NumStr then return 0 end
    NumStr = string.gsub(NumStr, ",", "")
    return tonumber(NumStr) or 0
end

-- ==================================================
-- BUILD MESHID MAP
-- ==================================================
local function BuildMeshIdMap()
    if MeshIdMapBuilt then return end

    -- ✅ Rarity Configs Path ពិតប្រាកដ
    local Rarity = ReplicatedStorage:FindFirstChild("Data")
    if Rarity then Rarity = Rarity:FindFirstChild("Rarity") end
    if Rarity then Rarity = Rarity:FindFirstChild("Configs") end
    if not Rarity then
        warn("[EggCheckPremium] Rarity Configs not found")
        return
    end

    -- ✅ Egg Models Path ពិតប្រាកដ
    local EggModels = ReplicatedStorage:FindFirstChild("Assets")
    if EggModels then EggModels = EggModels:FindFirstChild("Models") end
    if EggModels then EggModels = EggModels:FindFirstChild("Eggs") end

    for _, Config in ipairs(Rarity:GetChildren()) do
        local Success, Module = pcall(function() return require(Config) end)
        if Success and Module and Module.Egg then
            local ModelName = Module.Egg.ModelName or Config.Name
            local Template = EggModels and EggModels:FindFirstChild(ModelName)
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

            -- ✅ Cache Rarity Data
            local RarityId = Module._id or Config.Name
            RarityCache[RarityId] = {
                Id = RarityId,
                DisplayName = Module.DisplayName,
                RarityNumber = Module.RarityNumber or 0,
                RarityValue = ParseRarityValue(Module.DefaultRarityValue),
                Color = Module.Color,
                Announce = Module.Announce
            }
        end
    end

    MeshIdMapBuilt = true
    print("[EggCheckPremium] MeshId Map Built: " .. tostring(#Rarity:GetChildren()) .. " Configs")
end

-- ==================================================
-- GET PET DATA
-- ==================================================
local function GetPetData(AssetCategory)
    if RarityCache[AssetCategory] then
        local Data = RarityCache[AssetCategory]
        return {
            Rarity = Data.Id,
            RarityNumber = Data.RarityNumber,
            RarityValue = Data.RarityValue,
            DisplayName = Data.DisplayName,
            Color = Data.Color
        }
    end

    local Rarity = ReplicatedStorage:FindFirstChild("Data")
    if Rarity then Rarity = Rarity:FindFirstChild("Rarity") end
    if Rarity then Rarity = Rarity:FindFirstChild("Configs") end
    if not Rarity then return nil end

    local Config = Rarity:FindFirstChild(AssetCategory)
    if not Config then return nil end

    local Success, Module = pcall(function() return require(Config) end)
    if not Success or not Module then return nil end

    return {
        Rarity = Module._id or AssetCategory,
        RarityNumber = Module.RarityNumber or 0,
        RarityValue = ParseRarityValue(Module.DefaultRarityValue),
        DisplayName = Module.DisplayName,
        Color = Module.Color
    }
end

-- ==================================================
-- FIND ASSET CATEGORY
-- ==================================================
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

-- ==================================================
-- SORT EGG (RarityNumber ខ្ពស់ = កម្រជាង)
-- ==================================================
local function SortEggs(EggList)
    table.sort(EggList, function(a, b)
        local Pa = a.RarityNumber or 0
        local Pb = b.RarityNumber or 0
        if Pa ~= Pb then return Pa > Pb end
        return a.EarningRate > b.EarningRate
    end)
end

-- ==================================================
-- FIND BEST EGG
-- ==================================================
local function FindBestEgg()
    local Container = workspace:FindFirstChild("AreaEggSlotsClient")
    if not Container then return nil end

    local EggList = {}

    for _, Slot in ipairs(Container:GetChildren()) do
        if Slot:IsA("Model") then
            local Category = FindAssetCategory(Slot)
            if Category then
                local Data = GetPetData(Category)
                if Data and (next(SelectedRarities) == nil or SelectedRarities[Data.Rarity]) then
                    table.insert(EggList, {
                        Slot = Slot,
                        Uid = Slot.Name,
                        Rarity = Data.Rarity,
                        RarityNumber = Data.RarityNumber,
                        RarityValue = Data.RarityValue,
                        DisplayName = Data.DisplayName,
                        EarningRate = Data.EarningRate or 0,
                        Color = Data.Color
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
-- FIND ALL EGGS
-- ==================================================
local function FindAllEggs()
    local Container = workspace:FindFirstChild("AreaEggSlotsClient")
    if not Container then return {} end

    local EggList = {}

    for _, Slot in ipairs(Container:GetChildren()) do
        if Slot:IsA("Model") then
            local Category = FindAssetCategory(Slot)
            if Category then
                local Data = GetPetData(Category)
                if Data and (next(SelectedRarities) == nil or SelectedRarities[Data.Rarity]) then
                    table.insert(EggList, {
                        Slot = Slot,
                        Uid = Slot.Name,
                        Rarity = Data.Rarity,
                        RarityNumber = Data.RarityNumber,
                        RarityValue = Data.RarityValue,
                        DisplayName = Data.DisplayName,
                        EarningRate = Data.EarningRate or 0,
                        Color = Data.Color
                    })
                end
            end
        end
    end

    SortEggs(EggList)
    return EggList
end

-- ==================================================
-- GET EGGS BY RARITY
-- ==================================================
local function GetEggsByRarity(Rarity)
    local AllEggs = FindAllEggs()
    local Filtered = {}

    for _, Egg in ipairs(AllEggs) do
        if Egg.Rarity == Rarity then
            table.insert(Filtered, Egg)
        end
    end

    return Filtered
end

-- ==================================================
-- SET RARITIES
-- ==================================================
local function SetRarities(List)
    SelectedRarities = {}
    for _, r in ipairs(List) do
        SelectedRarities[r] = true
    end
    print("[EggCheckPremium] Rarities: " .. table.concat(List, ", "))
end

local function GetRarities()
    local List = {}
    for r, _ in pairs(SelectedRarities) do
        table.insert(List, r)
    end
    return List
end

-- ==================================================
-- GET ALL RARITY NAMES
-- ==================================================
local function GetAllRarityNames()
    if not MeshIdMapBuilt then BuildMeshIdMap() end
    local List = {}
    for name, _ in pairs(RarityCache) do
        table.insert(List, name)
    end
    return List
end

-- ==================================================
-- BUILD MESHID MAP ON LOAD
-- ==================================================
task.spawn(function()
    task.wait(1)
    BuildMeshIdMap()
end)

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_EggCheckPremium = {
    SetRarities = SetRarities,
    GetRarities = GetRarities,
    GetAllRarityNames = GetAllRarityNames,
    FindBestEgg = FindBestEgg,
    FindAllEggs = FindAllEggs,
    GetEggsByRarity = GetEggsByRarity,
    SortEggs = SortEggs,
    GetPetData = GetPetData,
    FindAssetCategory = FindAssetCategory,
    BuildMeshIdMap = BuildMeshIdMap,
    RarityCache = RarityCache
}

print("✅ EggCheckPremium Feature Loaded (RarityNumber ពិតប្រាកដ)")
