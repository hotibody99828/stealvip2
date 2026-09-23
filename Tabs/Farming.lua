-- ==================================================
-- YOKUDO HUB | TAB | Farming
-- ==================================================

local TabsManager = _G.YOKUDO_TabsManager
local TweenService = game:GetService("TweenService")

local FarmingTab, FarmingPage = TabsManager:RegisterTab("Farming", 2, "FARMING")

-- ==================================================
-- CONTENT
-- ==================================================
CreateSectionTitle(FarmingPage, "Farming", 1)

-- ==================================================
-- 1. SELECT EGG TYPE (ដាក់ខាងលើ)
-- ==================================================
local RarityHolder = Instance.new("Frame")
RarityHolder.Size = UDim2.new(1, 0, 0, 52)
RarityHolder.BackgroundColor3 = Color3.fromRGB(28, 29, 42)
RarityHolder.BorderSizePixel = 0
RarityHolder.LayoutOrder = 2
RarityHolder.ZIndex = 100
RarityHolder.Parent = FarmingPage

local RarityCorner = Instance.new("UICorner")
RarityCorner.CornerRadius = UDim.new(0, 8)
RarityCorner.Parent = RarityHolder

local RarityStroke = Instance.new("UIStroke")
RarityStroke.Color = Color3.fromRGB(105, 90, 190)
RarityStroke.Thickness = 1.5
RarityStroke.Transparency = 0.4
RarityStroke.Parent = RarityHolder

local RarityLabel = Instance.new("TextLabel")
RarityLabel.Size = UDim2.new(1, -120, 0, 20)
RarityLabel.Position = UDim2.new(0, 10, 0, 4)
RarityLabel.BackgroundTransparency = 1
RarityLabel.Text = "Select Egg Type"
RarityLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
RarityLabel.TextSize = 13
RarityLabel.TextXAlignment = Enum.TextXAlignment.Left
RarityLabel.TextYAlignment = Enum.TextYAlignment.Center
RarityLabel.Font = Enum.Font.GothamBold
RarityLabel.ZIndex = 101
RarityLabel.Parent = RarityHolder

local RaritySub = Instance.new("TextLabel")
RaritySub.Size = UDim2.new(1, -120, 0, 16)
RaritySub.Position = UDim2.new(0, 10, 0, 24)
RaritySub.BackgroundTransparency = 1
RaritySub.Text = "Check/Uncheck to Select"
RaritySub.TextColor3 = Color3.fromRGB(150, 150, 170)
RaritySub.TextSize = 10
RaritySub.TextXAlignment = Enum.TextXAlignment.Left
RaritySub.Font = Enum.Font.Gotham
RaritySub.ZIndex = 101
RaritySub.Parent = RarityHolder

-- ==================================================
-- CHECKBOX: SECRET
-- ==================================================
local SelectedRarities = { Secret = true, Eternal = true, Divine = true }

local function GetSelectedText()
    local List = {}
    if SelectedRarities.Secret then table.insert(List, "Secret") end
    if SelectedRarities.Eternal then table.insert(List, "Eternal") end
    if SelectedRarities.Divine then table.insert(List, "Divine") end
    if #List == 0 then return "None" end
    return table.concat(List, ", ")
end

-- ==================================================
-- RARITY CHECKBOX (Secret)
-- ==================================================
local function CreateRarityCheckbox(Name, PosX, Order)
    local Holder = Instance.new("Frame")
    Holder.Size = UDim2.new(0, 65, 0, 22)
    Holder.Position = UDim2.new(0, PosX, 1, 4)
    Holder.BackgroundColor3 = Color3.fromRGB(30, 31, 45)
    Holder.BorderSizePixel = 0
    Holder.LayoutOrder = Order
    Holder.ZIndex = 102
    Holder.Parent = RarityHolder

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 4)
    Corner.Parent = Holder

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(200, 200, 220)
    Stroke.Thickness = 1
    Stroke.Transparency = 0.5
    Stroke.Parent = Holder

    local Check = Instance.new("TextLabel")
    Check.Size = UDim2.new(0, 16, 1, 0)
    Check.Position = UDim2.new(0, 4, 0, 0)
    Check.BackgroundTransparency = 1
    Check.Text = "✓"
    Check.TextColor3 = Color3.fromRGB(255, 255, 255)
    Check.TextSize = 12
    Check.Font = Enum.Font.GothamBold
    Check.Visible = SelectedRarities[Name]
    Check.ZIndex = 103
    Check.Parent = Holder

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -22, 1, 0)
    Label.Position = UDim2.new(0, 20, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = Name
    Label.TextColor3 = Color3.fromRGB(220, 220, 235)
    Label.TextSize = 10
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.TextYAlignment = Enum.TextYAlignment.Center
    Label.Font = Enum.Font.GothamMedium
    Label.ZIndex = 103
    Label.Parent = Holder

    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, 0, 1, 0)
    Button.BackgroundTransparency = 1
    Button.Text = ""
    Button.ZIndex = 104
    Button.Parent = Holder

    local function UpdateVisual()
        if SelectedRarities[Name] then
            Holder.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
            Stroke.Color = Color3.fromRGB(135, 120, 225)
            Check.Visible = true
        else
            Holder.BackgroundColor3 = Color3.fromRGB(30, 31, 45)
            Stroke.Color = Color3.fromRGB(200, 200, 220)
            Check.Visible = false
        end
    end

    Button.MouseButton1Click:Connect(function()
        SelectedRarities[Name] = not SelectedRarities[Name]
        UpdateVisual()

        -- ✅ Auto Update Value
        if _G.YOKUDO_FarmingManager then
            local List = {}
            if SelectedRarities.Secret then table.insert(List, "Secret") end
            if SelectedRarities.Eternal then table.insert(List, "Eternal") end
            if SelectedRarities.Divine then table.insert(List, "Divine") end
            _G.YOKUDO_FarmingManager.SetRarities(List)
        end

        -- ✅ Update TextBox
        if RarityTextBox then
            RarityTextBox.Text = GetSelectedText()
        end
    end)

    UpdateVisual()
    return Holder
end

CreateRarityCheckbox("Secret", 10, 1)
CreateRarityCheckbox("Eternal", 80, 2)
CreateRarityCheckbox("Divine", 150, 3)

-- ==================================================
-- TEXTBOX: SELECTED RARITIES (Auto Update)
-- ==================================================
local RarityTextBox = Instance.new("TextBox")
RarityTextBox.Size = UDim2.new(0, 220, 0, 24)
RarityTextBox.Position = UDim2.new(1, -230, 1, 4)
RarityTextBox.BackgroundColor3 = Color3.fromRGB(30, 31, 45)
RarityTextBox.BorderSizePixel = 0
RarityTextBox.Text = GetSelectedText()
RarityTextBox.TextColor3 = Color3.fromRGB(100, 255, 100)
RarityTextBox.TextSize = 10
RarityTextBox.TextXAlignment = Enum.TextXAlignment.Center
RarityTextBox.Font = Enum.Font.GothamBold
RarityTextBox.ZIndex = 102
RarityTextBox.Parent = RarityHolder

local TextBoxCorner = Instance.new("UICorner")
TextBoxCorner.CornerRadius = UDim.new(0, 4)
TextBoxCorner.Parent = RarityTextBox

local TextBoxStroke = Instance.new("UIStroke")
TextBoxStroke.Color = Color3.fromRGB(100, 255, 100)
TextBoxStroke.Thickness = 1
TextBoxStroke.Transparency = 0.5
TextBoxStroke.Parent = RarityTextBox

-- ==================================================
-- 2. FEATURE: AUTO AFK FARMING EGG (ដាក់ខាងក្រោម)
-- ==================================================
local FarmHolder = Instance.new("Frame")
FarmHolder.Size = UDim2.new(1, 0, 0, 52)
FarmHolder.BackgroundColor3 = Color3.fromRGB(28, 29, 42)
FarmHolder.BorderSizePixel = 0
FarmHolder.LayoutOrder = 3
FarmHolder.Parent = FarmingPage

local FarmCorner = Instance.new("UICorner")
FarmCorner.CornerRadius = UDim.new(0, 8)
FarmCorner.Parent = FarmHolder

local FarmStroke = Instance.new("UIStroke")
FarmStroke.Color = Color3.fromRGB(105, 90, 190)
FarmStroke.Thickness = 1.5
FarmStroke.Transparency = 0.4
FarmStroke.Parent = FarmHolder

local FarmLabel = Instance.new("TextLabel")
FarmLabel.Size = UDim2.new(1, -60, 0, 20)
FarmLabel.Position = UDim2.new(0, 10, 0, 4)
FarmLabel.BackgroundTransparency = 1
FarmLabel.Text = "Auto AFK Farming Egg"
FarmLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
FarmLabel.TextSize = 13
FarmLabel.TextXAlignment = Enum.TextXAlignment.Left
FarmLabel.TextYAlignment = Enum.TextYAlignment.Center
FarmLabel.Font = Enum.Font.GothamBold
FarmLabel.Parent = FarmHolder

local FarmSub = Instance.new("TextLabel")
FarmSub.Size = UDim2.new(1, -60, 0, 16)
FarmSub.Position = UDim2.new(0, 10, 0, 24)
FarmSub.BackgroundTransparency = 1
FarmSub.Text = "Auto Select + Teleport + Collect + AFK"
FarmSub.TextColor3 = Color3.fromRGB(150, 150, 170)
FarmSub.TextSize = 10
FarmSub.TextXAlignment = Enum.TextXAlignment.Left
FarmSub.Font = Enum.Font.Gotham
FarmSub.Parent = FarmHolder

local FarmButton = Instance.new("TextButton")
FarmButton.Size = UDim2.new(0, 34, 0, 34)
FarmButton.Position = UDim2.new(1, -44, 0.5, -17)
FarmButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
FarmButton.BackgroundTransparency = 0.85
FarmButton.BorderSizePixel = 0
FarmButton.Text = ""
FarmButton.AutoButtonColor = false
FarmButton.Parent = FarmHolder

local FarmButtonCorner = Instance.new("UICorner")
FarmButtonCorner.CornerRadius = UDim.new(0, 8)
FarmButtonCorner.Parent = FarmButton

local FarmButtonStroke = Instance.new("UIStroke")
FarmButtonStroke.Color = Color3.fromRGB(255, 255, 255)
FarmButtonStroke.Thickness = 2
FarmButtonStroke.Parent = FarmButton

local FarmCheck = Instance.new("TextLabel")
FarmCheck.Size = UDim2.new(1, 0, 1, 0)
FarmCheck.BackgroundTransparency = 1
FarmCheck.Text = "✓"
FarmCheck.TextColor3 = Color3.fromRGB(255, 255, 255)
FarmCheck.TextSize = 20
FarmCheck.Font = Enum.Font.GothamBold
FarmCheck.Visible = false
FarmCheck.Parent = FarmButton

-- ==================================================
-- CHECKBOX TOGGLE
-- ==================================================
local FarmEnabled = false

local function ToggleFarm()
    if not _G.YOKUDO_FarmingManager then
        warn("[YOKUDO] FarmingManager not loaded!")
        return
    end

    FarmEnabled = not FarmEnabled
    FarmCheck.Visible = FarmEnabled

    if FarmEnabled then
        FarmButton.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
        FarmButton.BackgroundTransparency = 0
        FarmButtonStroke.Color = Color3.fromRGB(135, 120, 225)

        -- ✅ Set Rarities
        local List = {}
        if SelectedRarities.Secret then table.insert(List, "Secret") end
        if SelectedRarities.Eternal then table.insert(List, "Eternal") end
        if SelectedRarities.Divine then table.insert(List, "Divine") end
        _G.YOKUDO_FarmingManager.SetRarities(List)

        _G.YOKUDO_FarmingManager.Enable()
    else
        FarmButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        FarmButton.BackgroundTransparency = 0.85
        FarmButtonStroke.Color = Color3.fromRGB(255, 255, 255)
        _G.YOKUDO_FarmingManager.Disable()
    end
end

FarmButton.MouseButton1Click:Connect(function()
    ToggleFarm()
end)

-- ==================================================
-- SYNC ON LOAD
-- ==================================================
task.spawn(function()
    task.wait(1)
    if _G.YOKUDO_FarmingManager then
        local State = _G.YOKUDO_FarmingManager.IsEnabled()
        FarmEnabled = State
        FarmCheck.Visible = State
        if State then
            FarmButton.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
            FarmButton.BackgroundTransparency = 0
            FarmButtonStroke.Color = Color3.fromRGB(135, 120, 225)
        end
    end
end)

-- ✅ Sync TextBox រាល់ 0.5s
task.spawn(function()
    while task.wait(0.5) do
        if RarityTextBox then
            RarityTextBox.Text = GetSelectedText()
        end
    end
end)

print("✅ Farming Tab Loaded (Select on Top + Feature on Bottom)")
