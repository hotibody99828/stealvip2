-- ==================================================
-- YOKUDO HUB | FEATURE | Farming Manager
-- ប្រើ TeleportSystem (ដើម) ជាមួយ InstantTeleport
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================
local CHECK_INTERVAL = 1
local SAFE_ZONE = Vector3.new(533, 70, -366)

-- ==================================================
-- STATE
-- ==================================================
local FarmingEnabled = false
local CurrentState = "IDLE"
local SelectedRarities = {}
local FarmingThread = nil

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
-- CHECK EGG BY RARITY
-- ==================================================
local function GetPetData(AssetCategory)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local function BuildMeshIdMap()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Assets = ReplicatedStorage:FindFirstChild("Data")
    if not Assets then return {} end
    Assets = Assets:FindFirstChild("Assets")
    if not Assets then return {} end
    local Configs = Assets:FindFirstChild("Configs")
    local EggModels = ReplicatedStorage:FindFirstChild("Assets")
    if EggModels then EggModels = EggModels:FindFirstChild("Models") end
    if EggModels then EggModels = EggModels:FindFirstChild("Eggs") end
    if not Configs or not EggModels then return {} end

    local Map = {}
    for _, Config in ipairs(Configs:GetChildren()) do
        local Success, Module = pcall(function() return require(Config) end)
        if Success and Module and Module.Egg then
            local ModelName = Module.Egg.ModelName or Config.Name
            local Template = EggModels:FindFirstChild(ModelName)
            if Template then
                for _, Desc in ipairs(Template:GetDescendants()) do
                    if Desc:IsA("MeshPart") and Desc.MeshId ~= "" then
                        Map[Desc.MeshId] = Config.Name
                    end
                    if Desc:IsA("SpecialMesh") and Desc.MeshId ~= "" then
                        Map[Desc.MeshId] = Config.Name
                    end
                end
            end
        end
    end
    return Map
end

local MeshIdMap = BuildMeshIdMap()

local function FindAssetCategory(EggModel)
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
-- SORT EGG (Divine > Eternal > Secret > $/s)
-- ==================================================
local RARITY_PRIORITY = {
    Divine = 1,
    Eternal = 2,
    Secret = 3
}

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

-- ==================================================
-- STOP AFK (Jump Out + Fly to Safe Zone)
-- ==================================================
local function StopAFKAndGoSafe()
    if not _G.YOKUDO_AFKSystem then return end
    if not _G.YOKUDO_AFKSystem.IsEnabled() then return end

    print("[FarmingManager] Stop AFK → Jump Out → Safe Zone")

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
        local Hum, Root = GetHumanoid()
        if Root then
            _G.YOKUDO_AFKSystem.FlyTP(SAFE_ZONE, function()
                print("[FarmingManager] ✅ At Safe Zone")
            end)
        end
    end)
end

-- ==================================================
-- MAIN LOOP
-- ==================================================
local function MainLoop()
    print("[FarmingManager] MainLoop Started")

    while FarmingEnabled do
        local Text = GetNightTimerText()
        local Sec, IsValid = ParseNightTimer(Text)
        local BestEgg = FindBestEgg()

        print("[FarmingManager] Time: " .. tostring(Text) .. " | Sec: " .. tostring(Sec) .. " | Egg: " .. (BestEgg and BestEgg.DisplayName or "None"))

        if IsValid and Sec > 10 and BestEgg then
            print("[FarmingManager] ✅ Day + Egg → TeleportSystem (Instant)")

            StopAFKAndGoSafe()
            task.wait(1)

            -- ✅ ប្រើ TeleportSystem ដើម + InstantTeleport
            if _G.YOKUDO_TeleportSystem then
                _G.YOKUDO_TeleportSystem.SetMethod("InstantTeleport")
                _G.YOKUDO_TeleportSystem.SetTargetId(BestEgg.Uid)
                _G.YOKUDO_TeleportSystem.Enable()
            end

            while _G.YOKUDO_TeleportSystem and _G.YOKUDO_TeleportSystem.IsEnabled() do
                task.wait(0.5)
                if not FarmingEnabled then break end
            end

            print("[FarmingManager] TeleportSystem Done → Loop Again")
        else
            print("[FarmingManager] Night or No Egg → AFKSystem")

            if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
                _G.YOKUDO_AFKSystem.Enable()
            end

            task.wait(CHECK_INTERVAL)
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

    CurrentState = "IDLE"
    print("[YOKUDO] FarmingManager: OFF")
end

local function Toggle()
    if FarmingEnabled then Disable() else Enable() end
end

local function SetRarities(List)
    SelectedRarities = {}
    for _, r in ipairs(List) do
        SelectedRarities[r] = true
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
    GetState = function() return CurrentState end
}

print("✅ FarmingManager Feature Loaded (ប្រើ TeleportSystem ដើម)")
