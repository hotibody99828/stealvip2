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
-- 1. SELECT EGG TYPE (DROPDOWN)
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
RaritySub.Text = "Select Rarity to Farm"
RaritySub.TextColor3 = Color3.fromRGB(150, 150, 170)
RaritySub.TextSize = 10
RaritySub.TextXAlignment = Enum.TextXAlignment.Left
RaritySub.Font = Enum.Font.Gotham
RaritySub.ZIndex = 101
RaritySub.Parent = RarityHolder

-- Dropdown Button
local DropdownBtn = Instance.new("TextButton")
DropdownBtn.Size = UDim2.new(0, 220, 0, 28)
DropdownBtn.Position = UDim2.new(1, -230, 0.5, -14)
DropdownBtn.BackgroundColor3 = Color3.fromRGB(30, 31, 45)
DropdownBtn.BorderSizePixel = 0
DropdownBtn.Text = GetSelectedText() .. " ▼"
DropdownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DropdownBtn.TextSize = 10
DropdownBtn.Font = Enum.Font.GothamBold
DropdownBtn.AutoButtonColor = false
DropdownBtn.ZIndex = 101
DropdownBtn.Parent = RarityHolder

local DdCorner = Instance.new("UICorner")
DdCorner.CornerRadius = UDim.new(0, 6)
DdCorner.Parent = DropdownBtn

local DdStroke = Instance.new("UIStroke")
DdStroke.Color = Color3.fromRGB(200, 200, 220)
DdStroke.Thickness = 1
DdStroke.Transparency = 0.3
DdStroke.Parent = DropdownBtn

-- Dropdown List
local DropdownList = Instance.new("Frame")
DropdownList.Size = UDim2.new(0, 220, 0, 90)
DropdownList.Position = UDim2.new(1, -230, 1, 4)
DropdownList.BackgroundColor3 = Color3.fromRGB(25, 26, 38)
DropdownList.BorderSizePixel = 0
DropdownList.Visible = false
DropdownList.ZIndex = 999
DropdownList.Parent = RarityHolder

local DlCorner = Instance.new("UICorner")
DlCorner.CornerRadius = UDim.new(0, 6)
DlCorner.Parent = DropdownList

local DlStroke = Instance.new("UIStroke")
DlStroke.Color = Color3.fromRGB(200, 200, 220)
DlStroke.Thickness = 1
DlStroke.Transparency = 0.3
DlStroke.Parent = DropdownList

local DlLayout = Instance.new("UIListLayout")
DlLayout.Padding = UDim.new(0, 2)
DlLayout.SortOrder = Enum.SortOrder.LayoutOrder
DlLayout.Parent = DropdownList

local DlPadding = Instance.new("UIPadding")
DlPadding.PaddingTop = UDim.new(0, 4)
DlPadding.PaddingBottom = UDim.new(0, 4)
DlPadding.PaddingLeft = UDim.new(0, 4)
DlPadding.PaddingRight = UDim.new(0, 4)
DlPadding.Parent = DropdownList

-- Dropdown Options
local function CreateDropdownOption(Name, Order)
    local Option = Instance.new("TextButton")
    Option.Size = UDim2.new(1, 0, 0, 24)
    Option.BackgroundColor3 = Color3.fromRGB(30, 31, 45)
    Option.BorderSizePixel = 0
    Option.Text = Name
    Option.TextColor3 = Color3.fromRGB(255, 255, 255)
    Option.TextSize = 11
    Option.Font = Enum.Font.GothamMedium
    Option.AutoButtonColor = false
    Option.LayoutOrder = Order
    Option.ZIndex = 1000
    Option.Parent = DropdownList

    local OptCorner = Instance.new("UICorner")
    OptCorner.CornerRadius = UDim.new(0, 4)
    OptCorner.Parent = Option

    local OptStroke = Instance.new("UIStroke")
    OptStroke.Color = Color3.fromRGB(200, 200, 220)
    OptStroke.Thickness = 1
    OptStroke.Transparency = 0.5
    OptStroke.Parent = Option

    local function UpdateVisual()
        if SelectedRarities[Name] then
            Option.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
            OptStroke.Color = Color3.fromRGB(135, 120, 225)
            Option.Text = "✓ " .. Name
        else
            Option.BackgroundColor3 = Color3.fromRGB(30, 31, 45)
            OptStroke.Color = Color3.fromRGB(200, 200, 220)
            Option.Text = Name
        end
    end

    Option.MouseButton1Click:Connect(function()
        SelectedRarities[Name] = not SelectedRarities[Name]
        UpdateVisual()
        DropdownBtn.Text = GetSelectedText() .. " ▼"

        if _G.YOKUDO_FarmingManager then
            local List = {}
            if SelectedRarities.Secret then table.insert(List, "Secret") end
            if SelectedRarities.Eternal then table.insert(List, "Eternal") end
            if SelectedRarities.Divine then table.insert(List, "Divine") end
            _G.YOKUDO_FarmingManager.SetRarities(List)
        end
    end)

    UpdateVisual()
end

CreateDropdownOption("Secret", 1)
CreateDropdownOption("Eternal", 2)
CreateDropdownOption("Divine", 3)

DropdownBtn.MouseButton1Click:Connect(function()
    DropdownList.Visible = not DropdownList.Visible
end)

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

-- ==================================================
-- AUTO UPDATE DROPDOWN TEXT
-- ==================================================
task.spawn(function()
    while task.wait(0.5) do
        if DropdownBtn then
            DropdownBtn.Text = GetSelectedText() .. " ▼"
        end
    end
end)

print("✅ Farming Tab Loaded (Dropdown + Feature on Bottom)")
