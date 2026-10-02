-- ==================================================
-- YOKUDO HUB | FEATURE | Farming Manager (v5 FULL)
-- ✅ Divine Priority
-- ✅ Filter Character + Player + First Egg
-- ✅ Prevent Loop Reset (LastTargetUid)
-- ✅ Character Respawn → Restart
-- ✅ WalkSpeed ផ្ទាល់
-- ✅ Distance < 5 → Jump Out AFK
-- ✅ Check Egg Alive
-- ✅ Call UID ថ្មី ពេល Complete
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
local JUMP_OUT_DISTANCE = 5

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
-- RARITY PRIORITY
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
-- SELECTED RARITIES (Default: Top1-Top5)
-- ==================================================
local SelectedRarities = {
    Divine = true, Eternal = true, Secret = true,
    Mythic = true, Legendary = true,
    Epic = false, Rare = false, Uncommon = false, Common = false
}

-- ==================================================
-- FILTER FUNCTIONS
-- ==================================================
local function IsPlayerCharacter(Obj)
    if not Obj then return false end
    
    if Obj:FindFirstChildOfClass("Humanoid") then return true end
    if Obj:FindFirstChild("HumanoidRootPart") then return true end
    
    for _, P in ipairs(Players:GetPlayers()) do
        if P.Name == Obj.Name or P.DisplayName == Obj.Name then
            return true
        end
    end
    
    for _, P in ipairs(Players:GetPlayers()) do
        if P.Character == Obj then return true end
    end
    
    return false
end

local function IsValidEgg(Obj)
    if not Obj then return false end
    if not Obj:IsA("Model") then return false end
    
    if string.find(Obj.Name, "FirstAreaEgg") then return false end
    if IsPlayerCharacter(Obj) then return false end
    
    for _, P in ipairs(Players:GetPlayers()) do
        if P.Name == Obj.Name or P.DisplayName == Obj.Name then
            return false
        end
    end
    
    return true
end

local function CheckEggAlive(Uid)
    if not Uid then return false end
    
    local Container = workspace:FindFirstChild("AreaEggSlotsClient")
    local InContainer = Container and Container:FindFirstChild(Uid)
    local InWorkspace = workspace:FindFirstChild(Uid)
    
    local Egg = InContainer or InWorkspace
    if not Egg then return false end
    if not Egg:FindFirstChildWhichIsA("BasePart") then return false end
    
    return true
end

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
    print("[FarmingManager] MeshId Map Built")
end

-- ==================================================
-- GET PET DATA
-- ==================================================
local function GetPetData(AssetCategory)
    if not AssetCategory then return nil end
    if Cache.PetData[AssetCategory] then return Cache.PetData[AssetCategory] end

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
    if Cache.UidCategory[Uid] then return Cache.UidCategory[Uid] end

    if not Cache.MeshIdMapBuilt then BuildMeshIdMap() end

    for _, Desc in ipairs(EggModel:GetDescendants()) do
        if Desc:IsA("MeshPart") and Desc.MeshId ~= "" then
            local Cat = Cache.MeshIdMap[Desc.MeshId]
            if Cat then Cache.UidCategory[Uid] = Cat return Cat end
        end
        if Desc:IsA("SpecialMesh") and Desc.MeshId ~= "" then
            local Cat = Cache.MeshIdMap[Desc.MeshId]
            if Cat then Cache.UidCategory[Uid] = Cat return Cat end
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
-- FIND BEST EGG (Divine Priority)
-- ==================================================
local function FindBestEgg()
    local EggList = {}
    local DivineEgg = nil
    local DivineEarningRate = 0

    local Container = workspace:FindFirstChild("AreaEggSlotsClient")
    if Container then
        for _, Slot in ipairs(Container:GetChildren()) do
            if Slot:IsA("Model") then
                if not IsValidEgg(Slot) then continue end
                if not Slot.Parent then continue end
                if not Slot:FindFirstChildWhichIsA("BasePart") then continue end
                
                local Category = FindAssetCategory(Slot)
                if Category then
                    local Data = GetPetData(Category)
                    if Data and SelectedRarities[Data.Rarity] then
                        if Data.Rarity == "Divine" then
                            if Data.EarningRate > DivineEarningRate then
                                DivineEarningRate = Data.EarningRate
                                DivineEgg = {
                                    Slot = Slot, Uid = Slot.Name, Rarity = "Divine",
                                    EarningRate = Data.EarningRate, DisplayName = Data.DisplayName,
                                    Location = "spawn"
                                }
                            end
                        end
                        
                        table.insert(EggList, {
                            Slot = Slot, Uid = Slot.Name, Rarity = Data.Rarity,
                            EarningRate = Data.EarningRate, DisplayName = Data.DisplayName,
                            Location = "spawn"
                        })
                    end
                end
            end
        end
    end

    if DivineEgg then
        print("[FarmingManager] ✨ Divine Egg (Priority):", DivineEgg.DisplayName)
        return DivineEgg
    end

    if #EggList > 0 then SortEggs(EggList) return EggList[1] end

    -- Workspace Backup
    local WsDivineEgg = nil
    local WsDivineEarningRate = 0

    for _, Obj in ipairs(workspace:GetChildren()) do
        if Obj:IsA("Model") then
            if not IsValidEgg(Obj) then continue end
            if not Obj.Parent then continue end
            if not Obj:FindFirstChildWhichIsA("BasePart") then continue end
            
            local Category = FindAssetCategory(Obj)
            if Category then
                local Data = GetPetData(Category)
                if Data and SelectedRarities[Data.Rarity] then
                    if Data.Rarity == "Divine" then
                        if Data.EarningRate > WsDivineEarningRate then
                            WsDivineEarningRate = Data.EarningRate
                            WsDivineEgg = {
                                Slot = Obj, Uid = Obj.Name, Rarity = "Divine",
                                EarningRate = Data.EarningRate, DisplayName = Data.DisplayName,
                                Location = "workspace"
                            }
                        end
                    end
                    
                    table.insert(EggList, {
                        Slot = Obj, Uid = Obj.Name, Rarity = Data.Rarity,
                        EarningRate = Data.EarningRate, DisplayName = Data.DisplayName,
                        Location = "workspace"
                    })
                end
            end
        end
    end

    if WsDivineEgg then
        print("[FarmingManager] ✨ Divine Egg (Workspace):", WsDivineEgg.DisplayName)
        return WsDivineEgg
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
local LastTargetUid = nil
local WalkConnection = nil

-- ==================================================
-- GET CHAR / ROOT / HUM
-- ==================================================
local function GetChar() return Player.Character end
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
    if WalkConnection then WalkConnection:Disconnect() WalkConnection = nil end

    local Hum = GetHum()
    local Root = GetRoot()
    if Hum then
        pcall(function() Hum:MoveTo(Root and Root.Position or Hum.Parent.HumanoidRootPart.Position) end)
    end
    if Root then
        pcall(function()
            Root.AssemblyLinearVelocity = Vector3.zero
            Root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

-- ==================================================
-- WALK TP (WalkSpeed ផ្ទាល់)
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

    local PlayerSpeed = Hum.WalkSpeed
    print(string.format("[FarmingManager] 🚶 Walk TP → %s | Speed: %.1f", tostring(Destination), PlayerSpeed))

    local StartTime = tick()
    local LastCheck = 0

    WalkConnection = RunService.Heartbeat:Connect(function()
        if not FarmingEnabled then CleanupWalk() return end

        local Hum2 = GetHum()
        local Root2 = GetRoot()
        if not Hum2 or not Root2 then CleanupWalk() return end
        if Hum2.Health <= 0 then CleanupWalk() return end

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
        local Success, IsNight = pcall(function() return AreaEggCycle.IsNightPhase(Workspace:GetServerTimeNow()) end)
        if Success then return IsNight and "Night" or "Day" end
    end

    local Success, Text = pcall(function() return Player.PlayerGui.HUD.GameHUD.BottomRight.NightTimer.Value.Text end)
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
    end

    CleanupWalk()
end

-- ==================================================
-- FLY TO SAFE ZONE
-- ==================================================
local function FlyToSafeZoneAndWait()
    local Root = GetRoot()
    if not Root then return false end

    local DistToSafe = (Root.Position - SAFE_ZONE).Magnitude
    if DistToSafe <= SAFE_ZONE_DIST then return true end

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
-- ON TELEPORT COMPLETE
-- ==================================================
local function OnTeleportComplete()
    if not FarmingEnabled then return end
    if not WaitingForTeleport then return end

    WaitingForTeleport = false
    AFKStarted = false
    print("[FarmingManager] ✅ TeleportSystem Completed → Check New Egg")

    local BestEgg = FindBestEgg()

    if BestEgg then
        if not CheckEggAlive(BestEgg.Uid) then
            warn("[FarmingManager] ⚠️ Egg Target Gone → AFK")
            task.wait(1)
            EnableAFK()
            return
        end
        
        if BestEgg.Uid == LastTargetUid then
            warn("[FarmingManager] ⚠️ Same Target → Skip Loop")
            task.wait(1)
            EnableAFK()
            return
        end
        
        LastTargetUid = BestEgg.Uid
        print("[FarmingManager] New Egg Found:", BestEgg.DisplayName, "| Rarity:", BestEgg.Rarity)
        PendingEggUid = BestEgg.Uid

        task.spawn(function()
            local ReachedSafe = FlyToSafeZoneAndWait()
            if ReachedSafe and PendingEggUid then
                task.wait(SAFE_WAIT_AFTER_REACH)
                StartTeleportSystem(PendingEggUid)
                PendingEggUid = nil
            else
                EnableAFK()
            end
        end)
    else
        print("[FarmingManager] ❌ No Egg → Enable AFK")
        EnableAFK()
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
            if CheckEggAlive(BestEgg.Uid) then
                print("[FarmingManager] ✅ Egg Found:", BestEgg.DisplayName, "| Rarity:", BestEgg.Rarity, "| $/s:", BestEgg.EarningRate)
                PendingEggUid = BestEgg.Uid
                LastTargetUid = BestEgg.Uid

                StopAll()
                task.wait(0.3)

                local ReachedSafe = FlyToSafeZoneAndWait()
                if ReachedSafe and PendingEggUid then
                    task.wait(SAFE_WAIT_AFTER_REACH)
                    StartTeleportSystem(PendingEggUid)
                    PendingEggUid = nil

                    while WaitingForTeleport and FarmingEnabled do
                        task.wait(0.2)
                    end
                else
                    print("[FarmingManager] ⚠️ Cannot reach Safe Zone → AFK")
                    EnableAFK()
                end
            else
                warn("[FarmingManager] ⚠️ Egg Target Gone → AFK")
                task.wait(1)
                EnableAFK()
            end
        else
            print("[FarmingManager] ❌ No Egg → Enable AFK")
            EnableAFK()
        end

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
    LastTargetUid = nil

    if _G.YOKUDO_AFKSystem and _G.YOKUDO_AFKSystem.IsEnabled() then
        local MyTreadmillPos = _G.YOKUDO_AFKSystem.GetMyTreadmillPos()
        local Root = GetRoot()
        
        if MyTreadmillPos and Root then
            local Dist = (Root.Position - MyTreadmillPos).Magnitude
            
            if Dist < JUMP_OUT_DISTANCE then
                print(string.format("[FarmingManager] 🦘 Distance: %.1f (< %d) → Jump Out", Dist, JUMP_OUT_DISTANCE))
                
                _G.YOKUDO_AFKSystem.JumpOutTreadmill(MyTreadmillPos, function()
                    _G.YOKUDO_AFKSystem.Disable()
                    AFKStarted = false
                    print("[FarmingManager] ✅ Jumped Out")
                end)
                
                task.wait(1.5)
            else
                _G.YOKUDO_AFKSystem.Disable()
                task.wait(0.5)
            end
        else
            _G.YOKUDO_AFKSystem.Disable()
            task.wait(0.5)
        end
    end

    if FarmingThread then
        pcall(function() task.cancel(FarmingThread) end)
        FarmingThread = nil
    end
    
    task.wait(0.5)
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
    LastTargetUid = nil
    CurrentState = "IDLE"
    CurrentPhase = "UNKNOWN"
    print("[YOKUDO] FarmingManager: OFF")
end

local function Toggle()
    if FarmingEnabled then Disable() else Enable() end
end

-- ==================================================
-- CHARACTER RESPAWN
-- ==================================================
local function SetupDeathListener(Char)
    if not Char then return end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    if not Hum then return end
    
    Hum.Died:Connect(function()
        print("[FarmingManager] ☠️ Player Died")
        if FarmingEnabled then
            if _G.YOKUDO_TeleportSystem and _G.YOKUDO_TeleportSystem.IsEnabled() then
                _G.YOKUDO_TeleportSystem.Disable()
            end
            if _G.YOKUDO_AFKSystem and _G.YOKUDO_AFKSystem.IsEnabled() then
                _G.YOKUDO_AFKSystem.Disable()
            end
            CleanupWalk()
            WaitingForTeleport = false
        end
    end)
end

Player.CharacterAdded:Connect(function(Char)
    if not FarmingEnabled then return end
    print("[FarmingManager] 🔄 Character Respawned → Restart")
    task.wait(3)
    
    if FarmingThread then
        pcall(function() task.cancel(FarmingThread) end)
        FarmingThread = nil
    end
    
    WaitingForTeleport = false
    AFKStarted = false
    PendingEggUid = nil
    LastTargetUid = nil
    
    task.wait(2)
    FarmingThread = task.spawn(function() MainLoop() end)
    
    print("[FarmingManager] ✅ Farming Restarted")
    SetupDeathListener(Char)
end)

if Player.Character then SetupDeathListener(Player.Character) end

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
    CheckEggAlive = CheckEggAlive,

    GetEggData = function(Uid)
        if not Uid then return nil end
        local Container = workspace:FindFirstChild("AreaEggSlotsClient")
        local Slot = (Container and Container:FindFirstChild(Uid)) or workspace:FindFirstChild(Uid)
        if not Slot then return nil end
        local Category = FindAssetCategory(Slot)
        if not Category then return nil end
        return GetPetData(Category)
    end,

    JUMP_OUT_DISTANCE = JUMP_OUT_DISTANCE,
    OnTeleportComplete = OnTeleportComplete,
    WalkTP = WalkTP,
}

task.spawn(function()
    task.wait(1)
    BuildMeshIdMap()
    print("[FarmingManager] Cache Ready")
end)

task.spawn(function()
    while task.wait(30) do
        Cache.UidCategory = {}
        print("[FarmingManager] Uid Cache Cleared")
    end
end)

print("✅ FarmingManager Loaded (v5 FINAL)")
