--==================================================
-- YOKUDO HUB | FEATURE | Auto Farm
-- Check Egg + Display Card + Select + Send to Teleport
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Container = workspace:WaitForChild("AreaEggSlotsClient")

--==================================================
-- VARIABLES
--==================================================
local AutoFarmEnabled = false
local SelectedEgg = nil
local EggList = {}

--==================================================
-- ASSETS
--==================================================
local Assets = ReplicatedStorage:WaitForChild("Data"):WaitForChild("Assets")
local Configs = Assets:WaitForChild("Configs")
local EggModels = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Models"):WaitForChild("Eggs")

--==================================================
-- MESHID MAP
--==================================================
local MeshIdToCategory = {}

local function BuildMeshIdMap()
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
                        MeshIdToCategory[descendant.MeshId] = Config.Name
                    end
                    if descendant:IsA("SpecialMesh") and descendant.MeshId ~= "" then
                        MeshIdToCategory[descendant.MeshId] = Config.Name
                    end
                end
            end
        end
    end
end

BuildMeshIdMap()

--==================================================
-- GET PET DATA
--==================================================
local function GetPetData(AssetCategory)
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
    
    return Data
end

--==================================================
-- FORMAT MONEY
--==================================================
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

--==================================================
-- CALCULATE REAL RATE
--==================================================
local function CalculateRatePerSecond(EarningRate, Scale, Mutations)
    local PayoutFactor
    if Scale <= 5 then
        PayoutFactor = Scale ^ 1.85
    else
        PayoutFactor =
