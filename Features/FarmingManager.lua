-- ==================================================
-- YOKUDO HUB | FEATURE | Farming Manager
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================
local CHECK_INTERVAL = 0.5

-- ==================================================
-- STATE
-- ==================================================
local FarmingEnabled = false
local CurrentState = "IDLE"
local SelectedRarities = {}
local FarmingThread = nil
local StopRequested = false

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
-- MAIN LOOP (Statemachine)
-- ==================================================
local function MainLoop()
    while FarmingEnabled and not StopRequested do
        -- ==========================================
        -- STATE: CHECK_TIME
        -- ==========================================
        if CurrentState == "CHECK_TIME" then
            local Text = GetNightTimerText()
            local Sec, IsValid = ParseNightTimer(Text)
            print("[FarmingManager] CHECK_TIME | Text: " .. tostring(Text) .. " | Sec: " .. tostring(Sec))
            if IsValid and Sec > 10 then
                CurrentState = "CHECK_EGG"
            else
                CurrentState = "AFK"
            end
        end

        -- ==========================================
        -- STATE: CHECK_EGG
        -- ==========================================
        if CurrentState == "CHECK_EGG" then
            local BestEgg = FindBestEgg()
            if BestEgg then
                print("[FarmingManager] CHECK_EGG | Found: " .. BestEgg.DisplayName .. " | Uid: " .. BestEgg.Uid)
                if _G.YOKUDO_TeleportAFKSystem then
                    _G.YOKUDO_TeleportAFKSystem.SetTargetId(BestEgg.Uid)
                    _G.YOKUDO_TeleportAFKSystem.Enable()
                end
                CurrentState = "WAIT_TELEPORT"
            else
                print("[FarmingManager] CHECK_EGG | No Egg → AFK")
                CurrentState = "AFK"
            end
        end

        -- ==========================================
        -- STATE: WAIT_TELEPORT
        -- ==========================================
        if CurrentState == "WAIT_TELEPORT" then
            local TeleportRunning = _G.YOKUDO_TeleportAFKSystem and _G.YOKUDO_TeleportAFKSystem.IsEnabled()
            if not TeleportRunning then
                print("[FarmingManager] WAIT_TELEPORT | Done → CHECK_EGG")
                CurrentState = "CHECK_EGG"
            end
        end

        -- ==========================================
        -- STATE: AFK
        -- ==========================================
        if CurrentState == "AFK" then
            -- ✅ Enable AFKSystem2 ភ្លាម
            if _G.YOKUDO_AFKSystem2 then
                if not _G.YOKUDO_AFKSystem2.IsEnabled() then
                    print("[FarmingManager] AFK | Starting AFKSystem2")
                    _G.YOKUDO_AFKSystem2.Enable()
                end
            else
                warn("[FarmingManager] AFKSystem2 not loaded!")
            end
            CurrentState = "WAIT_AFK"
        end

        -- ==========================================
        -- STATE: WAIT_AFK
        -- ==========================================
        if CurrentState == "WAIT_AFK" then
            local Text = GetNightTimerText()
            local Sec, IsValid = ParseNightTimer(Text)
            if IsValid and Sec > 10 then
                print("[FarmingManager] WAIT_AFK | Day → Stop AFK → CHECK_EGG")
                if _G.YOKUDO_AFKSystem2 then
                    _G.YOKUDO_AFKSystem2.Disable()
                end
                CurrentState = "CHECK_EGG"
            else
                -- ✅ Check Egg រាល់ 2s បើមាន → Stop AFK → Teleport
                task.wait(2)
                local BestEgg = FindBestEgg()
                if BestEgg then
                    print("[FarmingManager] WAIT_AFK | Egg Found → Stop AFK → CHECK_EGG")
                    if _G.YOKUDO_AFKSystem2 then
                        _G.YOKUDO_AFKSystem2.Disable()
                    end
                    CurrentState = "CHECK_EGG"
                end
            end
        end

        task.wait(CHECK_INTERVAL)
    end
    print("[FarmingManager] MainLoop Stopped")
end

-- ==================================================
-- ENABLE / DISABLE
-- ==================================================
local function Enable()
    if FarmingEnabled then return end
    FarmingEnabled = true
    StopRequested = false
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
    StopRequested = true

    if FarmingThread then
        pcall(function() task.cancel(FarmingThread) end)
        FarmingThread = nil
    end

    if _G.YOKUDO_TeleportAFKSystem and _G.YOKUDO_TeleportAFKSystem.IsEnabled() then
        _G.YOKUDO_TeleportAFKSystem.Disable()
    end
    if _G.YOKUDO_AFKSystem2 and _G.YOKUDO_AFKSystem2.IsEnabled() then
        _G.YOKUDO_AFKSystem2.Disable()
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

print("✅ FarmingManager Feature Loaded")
