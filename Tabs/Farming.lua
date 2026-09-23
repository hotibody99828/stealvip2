-- ==================================================
-- YOKUDO HUB | TAB | Farming (Auto AFK Farming Steal Egg)
-- ✅ Logic ចាស់ — ហៅ Features ចាស់ៗ
-- ✅ Title: Auto AFK Farming Steal Egg
-- ✅ Feature: Auto Farm Steal Egg
-- ✅ មិនមាន Select Egg Type
-- ==================================================

local TabsManager = _G.YOKUDO_TabsManager
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

local FarmingTab, FarmingPage = TabsManager:RegisterTab("Farming", 2, "FARMING")

-- ==================================================
-- STATE
-- ==================================================
local AutoFarmEnabled = false
local AutoFarmThread = nil
local IsProcessing = false

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
-- MAIN AUTO FARM LOOP
-- ==================================================
local function AutoFarmLoop()
    print("[AutoFarm] MainLoop Started")

    while AutoFarmEnabled do
        -- ✅ 1. Check Best Egg ពី EggCheckPremium
        local BestEgg = nil
        if _G.YOKUDO_EggCheckPremium then
            BestEgg = _G.YOKUDO_EggCheckPremium.FindBestEgg()
        end

        if BestEgg then
            print("[AutoFarm] Found Egg: " .. BestEgg.DisplayName)

            -- ✅ 2. Stop AFK (បើកំពុង AFK)
            if _G.YOKUDO_AFKSystem and _G.YOKUDO_AFKSystem.IsEnabled() then
                print("[AutoFarm] Stop AFK → Jump Out")

                local TreadmillPos = _G.YOKUDO_AFKSystem.GetMyTreadmillPos()
                if not TreadmillPos then
                    local _, Treadmill = _G.YOKUDO_AFKSystem.FindMyPlotAndTreadmill()
                    if Treadmill then
                        TreadmillPos = Treadmill.Position
                    end
                end

                if TreadmillPos then
                    _G.YOKUDO_AFKSystem.JumpOutTreadmill(TreadmillPos, function()
                        _G.YOKUDO_AFKSystem.Disable()
                    end)
                    task.wait(1)
                else
                    _G.YOKUDO_AFKSystem.Disable()
                end
            end

            -- ✅ 3. Fly to Safe Zone
            if _G.YOKUDO_AFKSystem then
                local FlyDone = false
                _G.YOKUDO_AFKSystem.FlyTP(Vector3.new(533, 70, -366), function()
                    FlyDone = true
                end)

                local WaitTime = 0
                while not FlyDone and WaitTime < 10 do
                    task.wait(0.05)
                    WaitTime = WaitTime + 0.05
                    if not AutoFarmEnabled then break end
                end
            end

            -- ✅ 4. Start Teleport to Egg
            if _G.YOKUDO_TeleportSystem and BestEgg then
                print("[AutoFarm] Start Teleport to: " .. BestEgg.Uid)

                _G.YOKUDO_TeleportSystem.SetMethod("InstantTeleport")
                _G.YOKUDO_TeleportSystem.SetSpeed(1000)
                _G.YOKUDO_TeleportSystem.SetTargetId(BestEgg.Uid)
                _G.YOKUDO_TeleportSystem.Enable()

                -- ✅ 5. រង់ចាំ Teleport បញ្ចប់
                while _G.YOKUDO_TeleportSystem and _G.YOKUDO_TeleportSystem.IsEnabled() do
                    task.wait(0.5)
                    if not AutoFarmEnabled then break end
                end

                print("[AutoFarm] Teleport Done")
            end
        else
            print("[AutoFarm] No Egg → AFK")

            -- ✅ 6. គ្មាន Egg → AFK
            if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
                _G.YOKUDO_AFKSystem.Enable()
            end
        end

        task.wait(0.5)
    end
    print("[AutoFarm] MainLoop Stopped")
end

-- ==================================================
-- ENABLE / DISABLE
-- ==================================================
local function EnableAutoFarm()
    if AutoFarmEnabled then return end
    AutoFarmEnabled = true

    if AutoFarmThread then
        pcall(function() task.cancel(AutoFarmThread) end)
        AutoFarmThread = nil
    end
    AutoFarmThread = task.spawn(function() AutoFarmLoop() end)

    print("[YOKUDO] Auto Farm Steal Egg: ON")
end

local function DisableAutoFarm()
    if not AutoFarmEnabled then return end
    AutoFarmEnabled = false

    if AutoFarmThread then
        pcall(function() task.cancel(AutoFarmThread) end)
        AutoFarmThread = nil
    end

    if _G.YOKUDO_TeleportSystem and _G.YOKUDO_TeleportSystem.IsEnabled() then
        _G.YOKUDO_TeleportSystem.Disable()
    end
    if _G.YOKUDO_AFKSystem and _G.YOKUDO_AFKSystem.IsEnabled() then
        _G.YOKUDO_AFKSystem.Disable()
    end

    print("[YOKUDO] Auto Farm Steal Egg: OFF")
end

local function ToggleAutoFarm()
    if AutoFarmEnabled then DisableAutoFarm() else EnableAutoFarm() end
end

-- ==================================================
-- UI
-- ==================================================
CreateSectionTitle(FarmingPage, "Auto AFK Farming Steal Egg", 1)

-- Toggle Holder
local FarmHolder = Instance.new("Frame")
FarmHolder.Size = UDim2.new(1, 0, 0, 52)
FarmHolder.BackgroundTransparency = 1
FarmHolder.LayoutOrder = 2
FarmHolder.Parent = FarmingPage

local FarmLabel = Instance.new("TextLabel")
FarmLabel.Size = UDim2.new(1, -50, 0, 20)
FarmLabel.Position = UDim2.new(0, 0, 0, 2)
FarmLabel.BackgroundTransparency = 1
FarmLabel.Text = "Auto Farm Steal Egg"
FarmLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
FarmLabel.TextSize = 13
FarmLabel.TextXAlignment = Enum.TextXAlignment.Left
FarmLabel.TextYAlignment = Enum.TextYAlignment.Center
FarmLabel.Font = Enum.Font.GothamBold
FarmLabel.Parent = FarmHolder

local FarmSub = Instance.new("TextLabel")
FarmSub.Size = UDim2.new(1, -50, 0, 18)
FarmSub.Position = UDim2.new(0, 0, 0, 24)
FarmSub.BackgroundTransparency = 1
FarmSub.Text = "Auto Check Egg + Teleport + AFK"
FarmSub.TextColor3 = Color3.fromRGB(150, 150, 170)
FarmSub.TextSize = 10
FarmSub.TextXAlignment = Enum.TextXAlignment.Left
FarmSub.Font = Enum.Font.Gotham
FarmSub.Parent = FarmHolder

local FarmButton = Instance.new("TextButton")
FarmButton.Size = UDim2.new(0, 26, 0, 26)
FarmButton.Position = UDim2.new(1, -26, 0.5, -13)
FarmButton.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
FarmButton.BorderSizePixel = 0
FarmButton.Text = ""
FarmButton.AutoButtonColor = false
FarmButton.Parent = FarmHolder

local FarmCorner = Instance.new("UICorner")
FarmCorner.CornerRadius = UDim.new(0, 6)
FarmCorner.Parent = FarmButton

local FarmStroke = Instance.new("UIStroke")
FarmStroke.Color = Color3.fromRGB(200, 200, 220)
FarmStroke.Thickness = 1.5
FarmStroke.Parent = FarmButton

local FarmCheck = Instance.new("TextLabel")
FarmCheck.Size = UDim2.new(1, 0, 1, 0)
FarmCheck.BackgroundTransparency = 1
FarmCheck.Text = "✓"
FarmCheck.TextColor3 = Color3.fromRGB(255, 255, 255)
FarmCheck.TextSize = 18
FarmCheck.Font = Enum.Font.GothamBold
FarmCheck.Visible = false
FarmCheck.Parent = FarmButton

FarmButton.MouseButton1Click:Connect(function()
    if AutoFarmEnabled then
        DisableAutoFarm()
        FarmCheck.Visible = false
        FarmButton.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
        FarmStroke.Color = Color3.fromRGB(200, 200, 220)
    else
        EnableAutoFarm()
        FarmCheck.Visible = true
        FarmButton.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
        FarmStroke.Color = Color3.fromRGB(135, 120, 225)
    end
end)

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_AutoFarmStealEgg = {
    Enable = EnableAutoFarm,
    Disable = DisableAutoFarm,
    Toggle = ToggleAutoFarm,
    IsEnabled = function() return AutoFarmEnabled end,
    GetHumanoid = GetHumanoid
}

-- ==================================================
-- REGISTER WITH CHARACTER SYSTEM
-- ==================================================
if _G.YOKUDO_CharacterSystem then
    _G.YOKUDO_CharacterSystem:RegisterFeature({
        Name = "AutoFarmStealEgg",
        Enable = EnableAutoFarm,
        Disable = DisableAutoFarm,
        IsEnabled = function() return AutoFarmEnabled end,
        OnCharacterAdded = function(Char, Hum, Root)
            if AutoFarmEnabled then
                task.wait(1)
                if AutoFarmThread then
                    pcall(function() task.cancel(AutoFarmThread) end)
                    AutoFarmThread = nil
                end
                AutoFarmThread = task.spawn(function() AutoFarmLoop() end)
                print("[AutoFarm] Restarted on new Character")
            end
        end
    })
end

print("✅ Farming Tab (Auto AFK Farming Steal Egg) Loaded")
