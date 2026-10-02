-- ==================================================
-- YOKUDO HUB | TAB | Farming (v2 — Lock Support)
-- ✅ Check SpeedLock Inside ToggleFarm
-- ✅ Lock Icon
-- ✅ Show Message
-- ✅ Export Button
-- ✅ គ្មាន Audio
-- ==================================================

local TabsManager = _G.YOKUDO_TabsManager
local TweenService = game:GetService("TweenService")

local FarmingTab, FarmingPage = TabsManager:RegisterTab("Farming", 2, "FARMING")

CreateSectionTitle(FarmingPage, "Farming", 1)

-- ==================================================
-- RARITY COLORS
-- ==================================================
local RarityColors = {
    Divine = Color3.fromRGB(255, 215, 0),
    Eternal = Color3.fromRGB(0, 255, 255),
    Secret = Color3.fromRGB(255, 50, 200),
    Mythic = Color3.fromRGB(255, 100, 100),
    Legendary = Color3.fromRGB(255, 0, 0),
    Epic = Color3.fromRGB(200, 100, 255),
    Rare = Color3.fromRGB(100, 150, 255),
    Uncommon = Color3.fromRGB(100, 255, 100),
    Common = Color3.fromRGB(200, 200, 200)
}

local RarityOrder = {
    "Divine", "Eternal", "Secret", "Mythic", "Legendary",
    "Epic", "Rare", "Uncommon", "Common"
}

-- ==================================================
-- DROPDOWN
-- ==================================================
local RarityHolder = Instance.new("Frame")
RarityHolder.Size = UDim2.new(1, 0, 0, 52)
RarityHolder.BackgroundTransparency = 1
RarityHolder.LayoutOrder = 2
RarityHolder.ZIndex = 100
RarityHolder.Parent = FarmingPage

local RarityLabel = Instance.new("TextLabel")
RarityLabel.Size = UDim2.new(1, -120, 0, 20)
RarityLabel.Position = UDim2.new(0, 0, 0, 2)
RarityLabel.BackgroundTransparency = 1
RarityLabel.Text = "Select Egg Type"
RarityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
RarityLabel.TextSize = 13
RarityLabel.TextXAlignment = Enum.TextXAlignment.Left
RarityLabel.Font = Enum.Font.GothamBold
RarityLabel.ZIndex = 101
RarityLabel.Parent = RarityHolder

local RarityTitle = Instance.new("TextLabel")
RarityTitle.Size = UDim2.new(1, -120, 0, 18)
RarityTitle.Position = UDim2.new(0, 0, 0, 24)
RarityTitle.BackgroundTransparency = 1
RarityTitle.Text = "Select Rarity to Farm"
RarityTitle.TextColor3 = Color3.fromRGB(180, 180, 180)
RarityTitle.TextSize = 10
RarityTitle.TextXAlignment = Enum.TextXAlignment.Left
RarityTitle.Font = Enum.Font.Gotham
RarityTitle.ZIndex = 101
RarityTitle.Parent = RarityHolder

local SelectedRarities = {
    Divine = true, Eternal = true, Secret = true,
    Mythic = true, Legendary = true,
    Epic = false, Rare = false, Uncommon = false, Common = false
}

local function GetSelectedText()
    local List = {}
    for _, rarity in ipairs(RarityOrder) do
        if SelectedRarities[rarity] then
            table.insert(List, rarity)
        end
    end
    if #List == 0 then return "None" end
    if #List == #RarityOrder then return "All" end
    return table.concat(List, ", ")
end

local DropdownBtn = Instance.new("TextButton")
DropdownBtn.Size = UDim2.new(0, 120, 0, 28)
DropdownBtn.Position = UDim2.new(1, -120, 0.5, -14)
DropdownBtn.BackgroundColor3 = Color3.fromRGB(30, 31, 45)
DropdownBtn.BorderSizePixel = 0
DropdownBtn.Text = GetSelectedText() .. " ▼"
DropdownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DropdownBtn.TextSize = 11
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

local DropdownScroll = Instance.new("ScrollingFrame")
DropdownScroll.Size = UDim2.new(0, 120, 0, 200)
DropdownScroll.Position = UDim2.new(1, -120, 1, 2)
DropdownScroll.BackgroundColor3 = Color3.fromRGB(25, 26, 38)
DropdownScroll.BorderSizePixel = 0
DropdownScroll.Visible = false
DropdownScroll.ZIndex = 200
DropdownScroll.ScrollBarThickness = 4
DropdownScroll.ScrollBarImageColor3 = Color3.fromRGB(105, 90, 190)
DropdownScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
DropdownScroll.Parent = RarityHolder

local DlCorner = Instance.new("UICorner")
DlCorner.CornerRadius = UDim.new(0, 6)
DlCorner.Parent = DropdownScroll

local DlStroke = Instance.new("UIStroke")
DlStroke.Color = Color3.fromRGB(200, 200, 220)
DlStroke.Thickness = 1
DlStroke.Transparency = 0.3
DlStroke.Parent = DropdownScroll

local DlLayout = Instance.new("UIListLayout")
DlLayout.Padding = UDim.new(0, 2)
DlLayout.SortOrder = Enum.SortOrder.LayoutOrder
DlLayout.Parent = DropdownScroll

local DlPadding = Instance.new("UIPadding")
DlPadding.PaddingTop = UDim.new(0, 4)
DlPadding.PaddingBottom = UDim.new(0, 4)
DlPadding.PaddingLeft = UDim.new(0, 4)
DlPadding.PaddingRight = UDim.new(0, 4)
DlPadding.Parent = DropdownScroll

local OptionButtons = {}

local function UpdateOptionVisual(Name)
    local Option = OptionButtons[Name]
    if not Option then return end

    if SelectedRarities[Name] then
        Option.BackgroundColor3 = RarityColors[Name] or Color3.fromRGB(105, 90, 190)
        Option.Text = "✓ " .. Name
        if Name == "Divine" or Name == "Eternal" or Name == "Uncommon" or Name == "Common" then
            Option.TextColor3 = Color3.fromRGB(0, 0, 0)
        else
            Option.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    else
        Option.BackgroundColor3 = Color3.fromRGB(30, 31, 45)
        Option.Text = Name
        Option.TextColor3 = RarityColors[Name] or Color3.fromRGB(255, 255, 255)
    end
end

local function CreateDropdownOption(Name, Order)
    local Option = Instance.new("TextButton")
    Option.Size = UDim2.new(1, 0, 0, 22)
    Option.BackgroundColor3 = Color3.fromRGB(30, 31, 45)
    Option.BorderSizePixel = 0
    Option.Text = Name
    Option.TextColor3 = RarityColors[Name] or Color3.fromRGB(255, 255, 255)
    Option.TextSize = 11
    Option.Font = Enum.Font.GothamMedium
    Option.AutoButtonColor = false
    Option.LayoutOrder = Order
    Option.ZIndex = 201
    Option.Parent = DropdownScroll

    local OptCorner = Instance.new("UICorner")
    OptCorner.CornerRadius = UDim.new(0, 4)
    OptCorner.Parent = Option

    OptionButtons[Name] = Option

    Option.MouseButton1Click:Connect(function()
        SelectedRarities[Name] = not SelectedRarities[Name]
        UpdateOptionVisual(Name)
        DropdownBtn.Text = GetSelectedText() .. " ▼"

        if _G.YOKUDO_FarmingManager then
            local List = {}
            for _, rarity in ipairs(RarityOrder) do
                if SelectedRarities[rarity] then
                    table.insert(List, rarity)
                end
            end
            _G.YOKUDO_FarmingManager.SetRarities(List)
        end
    end)

    Option.MouseEnter:Connect(function()
        if not SelectedRarities[Name] then
            Option.BackgroundColor3 = Color3.fromRGB(45, 46, 60)
        end
    end)

    Option.MouseLeave:Connect(function()
        UpdateOptionVisual(Name)
    end)

    UpdateOptionVisual(Name)
end

for i, rarity in ipairs(RarityOrder) do
    CreateDropdownOption(rarity, i)
end

DropdownScroll.CanvasSize = UDim2.new(0, 0, 0, #RarityOrder * 24 + 8)

DropdownBtn.MouseButton1Click:Connect(function()
    DropdownScroll.Visible = not DropdownScroll.Visible
end)

-- ==================================================
-- FEATURE: AUTO AFK FARMING EGG
-- ==================================================
local FarmHolder = Instance.new("Frame")
FarmHolder.Size = UDim2.new(1, 0, 0, 52)
FarmHolder.BackgroundTransparency = 1
FarmHolder.LayoutOrder = 3
FarmHolder.Parent = FarmingPage

local FarmLabel = Instance.new("TextLabel")
FarmLabel.Size = UDim2.new(1, -50, 0, 20)
FarmLabel.Position = UDim2.new(0, 0, 0, 2)
FarmLabel.BackgroundTransparency = 1
FarmLabel.Text = "Auto AFK Farming Egg"
FarmLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
FarmLabel.TextSize = 13
FarmLabel.TextXAlignment = Enum.TextXAlignment.Left
FarmLabel.TextYAlignment = Enum.TextYAlignment.Center
FarmLabel.Font = Enum.Font.GothamBold
FarmLabel.Parent = FarmHolder

local FarmSub = Instance.new("TextLabel")
FarmSub.Size = UDim2.new(1, -50, 0, 18)
FarmSub.Position = UDim2.new(0, 0, 0, 24)
FarmSub.BackgroundTransparency = 1
FarmSub.Text = "Auto farm selected rarity"
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

-- ==================================================
-- ✅ TOGGLE FARM (កែ — Check SpeedLock Inside)
-- ==================================================
local FarmEnabled = false

local function ToggleFarm()
    -- ✅ Check SpeedLock ខាងក្នុង
    if _G.YOKUDO_SpeedLock and not _G.YOKUDO_SpeedLock.IsUnlocked() then
        _G.YOKUDO_SpeedLock.ShowMessage(
            "🔒 To Get Speed 1B UP\nWhen 1B Done, Please Exit Game and Join Again",
            5
        )
        return
    end
    
    if not _G.YOKUDO_FarmingManager then
        warn("[YOKUDO] FarmingManager not loaded!")
        return
    end

    FarmEnabled = not FarmEnabled
    FarmCheck.Visible = FarmEnabled

    if FarmEnabled then
        FarmButton.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
        FarmStroke.Color = Color3.fromRGB(135, 120, 225)

        local List = {}
        for _, rarity in ipairs(RarityOrder) do
            if SelectedRarities[rarity] then
                table.insert(List, rarity)
            end
        end
        _G.YOKUDO_FarmingManager.SetRarities(List)
        _G.YOKUDO_FarmingManager.Enable()
    else
        FarmButton.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
        FarmStroke.Color = Color3.fromRGB(200, 200, 220)
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
            FarmStroke.Color = Color3.fromRGB(135, 120, 225)
        end
    end
end)

-- ==================================================
-- PERIODIC SYNC
-- ==================================================
task.spawn(function()
    while task.wait(1) do
        if _G.YOKUDO_FarmingManager then
            local CurrentState = _G.YOKUDO_FarmingManager.IsEnabled()
            local UIState = FarmCheck.Visible

            if CurrentState ~= UIState then
                FarmEnabled = CurrentState
                FarmCheck.Visible = CurrentState

                if CurrentState then
                    FarmButton.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
                    FarmStroke.Color = Color3.fromRGB(135, 120, 225)
                else
                    FarmButton.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
                    FarmStroke.Color = Color3.fromRGB(200, 200, 220)
                end
            end
        end
    end
end)

-- ==================================================
-- REFRESH FUNCTION
-- ==================================================
_G.YOKUDO_RefreshFarmingUI = function()
    if _G.YOKUDO_FarmingManager then
        local State = _G.YOKUDO_FarmingManager.IsEnabled()
        FarmEnabled = State
        FarmCheck.Visible = State

        if State then
            FarmButton.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
            FarmStroke.Color = Color3.fromRGB(135, 120, 225)
        else
            FarmButton.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
            FarmStroke.Color = Color3.fromRGB(200, 200, 220)
        end
    end
end

-- ==================================================
-- ✅ EXPORT BUTTON
-- ==================================================
_G.YOKUDO_FarmButton = FarmButton

print("✅ Farming Tab Loaded (v2 — Lock Support)")
