-- ==================================================
-- YOKUDO HUB | TAB | Farming (Tap Farming)
-- ✅ Tap Farming — ចុចស្វ័យប្រវត្តិលើ Egg
-- ✅ Title: Auto AFK Farming Steal Egg
-- ✅ Feature: Auto Farm Steal Egg
-- ==================================================

local TabsManager = _G.YOKUDO_TabsManager
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Container = workspace:WaitForChild("AreaEggSlotsClient")

local FarmingTab, FarmingPage = TabsManager:RegisterTab("Farming", 2, "FARMING")

-- ==================================================
-- REMOTES
-- ==================================================
local CollectEvent = nil
pcall(function()
    CollectEvent = ReplicatedStorage.Packages.Networking["RF/EggWorld/AskFieldEggCarry"]
end)

-- ==================================================
-- SETTINGS
-- ==================================================
local TAP_INTERVAL = 0.05
local TAP_RANGE = 50
local SEARCH_PREFIX = "FirstAreaEgg"

-- ==================================================
-- STATE
-- ==================================================
local TapEnabled = false
local TapThread = nil
local TapCount = 0
local LastTapTime = 0

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
-- GET POSITION
-- ==================================================
local function GetPosition(Object)
    if not Object then return nil end
    if Object:IsA("Model") then
        if Object.PrimaryPart then return Object.PrimaryPart.Position end
        local Part = Object:FindFirstChildWhichIsA("BasePart")
        if Part then return Part.Position end
        for _, Desc in ipairs(Object:GetDescendants()) do
            if Desc:IsA("BasePart") then return Desc.Position end
        end
    elseif Object:IsA("BasePart") then
        return Object.Position
    end
    return nil
end

-- ==================================================
-- FIND NEAREST EGG
-- ==================================================
local function FindNearestEgg()
    local Hum, Root = GetHumanoid()
    if not Root then return nil end

    local Nearest = nil
    local NearestDist = TAP_RANGE

    for _, Slot in ipairs(Container:GetChildren()) do
        if string.find(Slot.Name, SEARCH_PREFIX) then
            local Pos = GetPosition(Slot)
            if Pos then
                local Dist = (Pos - Root.Position).Magnitude
                if Dist < NearestDist then
                    NearestDist = Dist
                    Nearest = Slot
                end
            end
        end
    end

    return Nearest
end

-- ==================================================
-- FIRE TAP REMOTE
-- ==================================================
local function FireTap(Egg)
    if not Egg or not CollectEvent then return end

    local SlotNum = string.match(Egg.Name, "Slot_(%d+)")
    if not SlotNum then return end

    local SlotKey = "Forest:Slot_" .. SlotNum
    local Uid = Egg.Name

    pcall(function()
        CollectEvent:InvokeServer({
            FirstAreaSlotKey = SlotKey,
            Uid = Uid
        })
    end)

    TapCount = TapCount + 1
end

-- ==================================================
-- TAP LOOP
-- ==================================================
local function StartTapLoop()
    if TapThread then
        pcall(function() task.cancel(TapThread) end)
        TapThread = nil
    end

    TapThread = task.spawn(function()
        while TapEnabled do
            local now = tick()
            if now - LastTapTime >= TAP_INTERVAL then
                LastTapTime = now

                local Egg = FindNearestEgg()
                if Egg then
                    FireTap(Egg)
                end
            end
            task.wait()
        end
    end)
end

-- ==================================================
-- ENABLE / DISABLE
-- ==================================================
local function EnableTap()
    if TapEnabled then return end
    TapEnabled = true
    TapCount = 0
    StartTapLoop()
    print("[YOKUDO] Auto Farm Steal Egg: ON")
end

local function DisableTap()
    if not TapEnabled then return end
    TapEnabled = false

    if TapThread then
        pcall(function() task.cancel(TapThread) end)
        TapThread = nil
    end

    print("[YOKUDO] Auto Farm Steal Egg: OFF")
end

local function ToggleTap()
    if TapEnabled then DisableTap() else EnableTap() end
end

-- ==================================================
-- UI
-- ==================================================
CreateSectionTitle(FarmingPage, "Auto AFK Farming Steal Egg", 1)

local TapHolder = Instance.new("Frame")
TapHolder.Size = UDim2.new(1, 0, 0, 52)
TapHolder.BackgroundTransparency = 1
TapHolder.LayoutOrder = 2
TapHolder.Parent = FarmingPage

local TapLabel = Instance.new("TextLabel")
TapLabel.Size = UDim2.new(1, -50, 0, 20)
TapLabel.Position = UDim2.new(0, 0, 0, 2)
TapLabel.BackgroundTransparency = 1
TapLabel.Text = "Auto Farm Steal Egg"
TapLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
TapLabel.TextSize = 13
TapLabel.TextXAlignment = Enum.TextXAlignment.Left
TapLabel.TextYAlignment = Enum.TextYAlignment.Center
TapLabel.Font = Enum.Font.GothamBold
TapLabel.Parent = TapHolder

local TapSub = Instance.new("TextLabel")
TapSub.Size = UDim2.new(1, -50, 0, 18)
TapSub.Position = UDim2.new(0, 0, 0, 24)
TapSub.BackgroundTransparency = 1
TapSub.Text = "Tap: 0"
TapSub.TextColor3 = Color3.fromRGB(150, 150, 170)
TapSub.TextSize = 10
TapSub.TextXAlignment = Enum.TextXAlignment.Left
TapSub.Font = Enum.Font.Gotham
TapSub.Parent = TapHolder

local TapButton = Instance.new("TextButton")
TapButton.Size = UDim2.new(0, 26, 0, 26)
TapButton.Position = UDim2.new(1, -26, 0.5, -13)
TapButton.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
TapButton.BorderSizePixel = 0
TapButton.Text = ""
TapButton.AutoButtonColor = false
TapButton.Parent = TapHolder

local TapCorner = Instance.new("UICorner")
TapCorner.CornerRadius = UDim.new(0, 6)
TapCorner.Parent = TapButton

local TapStroke = Instance.new("UIStroke")
TapStroke.Color = Color3.fromRGB(200, 200, 220)
TapStroke.Thickness = 1.5
TapStroke.Parent = TapButton

local TapCheck = Instance.new("TextLabel")
TapCheck.Size = UDim2.new(1, 0, 1, 0)
TapCheck.BackgroundTransparency = 1
TapCheck.Text = "✓"
TapCheck.TextColor3 = Color3.fromRGB(255, 255, 255)
TapCheck.TextSize = 18
TapCheck.Font = Enum.Font.GothamBold
TapCheck.Visible = false
TapCheck.Parent = TapButton

TapButton.MouseButton1Click:Connect(function()
    if TapEnabled then
        DisableTap()
        TapCheck.Visible = false
        TapButton.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
        TapStroke.Color = Color3.fromRGB(200, 200, 220)
    else
        EnableTap()
        TapCheck.Visible = true
        TapButton.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
        TapStroke.Color = Color3.fromRGB(135, 120, 225)
    end
end)

-- Update Tap Count
task.spawn(function()
    while task.wait(0.5) do
        if TapEnabled then
            TapSub.Text = "Tap: " .. TapCount
        end
    end
end)

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_TapFarming = {
    Enable = EnableTap,
    Disable = DisableTap,
    Toggle = ToggleTap,
    IsEnabled = function() return TapEnabled end,
    GetTapCount = function() return TapCount end,
    SetTapSpeed = function(v) TAP_INTERVAL = math.clamp(v, 0.01, 1) end,
    SetTapRange = function(v) TAP_RANGE = math.clamp(v, 5, 200) end,
    FindNearestEgg = FindNearestEgg,
    GetHumanoid = GetHumanoid
}

print("✅ Farming Tab (Auto Farm Steal Egg — Tap Farming) Loaded")
