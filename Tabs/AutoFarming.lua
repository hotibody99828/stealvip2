--==================================================
-- YOKUDO HUB | TAB | Auto Farming
--==================================================

local TabsManager = _G.YOKUDO_TabsManager
local TweenService = game:GetService("TweenService")

local AutoFarmingTab, AutoFarmingPage = TabsManager:RegisterTab("Auto Farming", 4, "AUTO_FARMING")

--==================================================
-- CONTENT
--==================================================
CreateSectionTitle(AutoFarmingPage, "Auto Farming", 1)

--==================================================
-- FEATURE 1: Click Get Egg
--==================================================
local GetEggBox = Instance.new("Frame")
GetEggBox.Size = UDim2.new(1, 0, 0, 60)
GetEggBox.BackgroundColor3 = Color3.fromRGB(28, 29, 42)
GetEggBox.BorderSizePixel = 0
GetEggBox.LayoutOrder = 2
GetEggBox.Parent = AutoFarmingPage

local GetEggBoxCorner = Instance.new("UICorner")
GetEggBoxCorner.CornerRadius = UDim.new(0, 8)
GetEggBoxCorner.Parent = GetEggBox

local GetEggBoxStroke = Instance.new("UIStroke")
GetEggBoxStroke.Color = Color3.fromRGB(105, 90, 190)
GetEggBoxStroke.Thickness = 1.5
GetEggBoxStroke.Transparency = 0.4
GetEggBoxStroke.Parent = GetEggBox

local GetEggIcon = Instance.new("ImageLabel")
GetEggIcon.Size = UDim2.new(0, 40, 0, 40)
GetEggIcon.Position = UDim2.new(0, 10, 0.5, -20)
GetEggIcon.BackgroundColor3 = Color3.fromRGB(40, 42, 58)
GetEggIcon.BorderSizePixel = 0
GetEggIcon.Image = ""
GetEggIcon.Parent = GetEggBox

local GetEggIconCorner = Instance.new("UICorner")
GetEggIconCorner.CornerRadius = UDim.new(0, 6)
GetEggIconCorner.Parent = GetEggIcon

local GetEggName = Instance.new("TextLabel")
GetEggName.Size = UDim2.new(1, -140, 0, 16)
GetEggName.Position = UDim2.new(0, 58, 0, 10)
GetEggName.BackgroundTransparency = 1
GetEggName.Text = "No Egg Selected"
GetEggName.TextColor3 = Color3.fromRGB(255, 255, 255)
GetEggName.TextSize = 12
GetEggName.TextXAlignment = Enum.TextXAlignment.Left
GetEggName.Font = Enum.Font.GothamBold
GetEggName.Parent = GetEggBox

local GetEggRate = Instance.new("TextLabel")
GetEggRate.Size = UDim2.new(1, -140, 0, 16)
GetEggRate.Position = UDim2.new(0, 58, 0, 30)
GetEggRate.BackgroundTransparency = 1
GetEggRate.Text = "$0/s"
GetEggRate.TextColor3 = Color3.fromRGB(100, 255, 100)
GetEggRate.TextSize = 11
GetEggRate.TextXAlignment = Enum.TextXAlignment.Left
GetEggRate.Font = Enum.Font.Gotham
GetEggRate.Parent = GetEggBox

local GetEggCheckButton = Instance.new("TextButton")
GetEggCheckButton.Size = UDim2.new(0, 34, 0, 34)
GetEggCheckButton.Position = UDim2.new(1, -44, 0.5, -17)
GetEggCheckButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
GetEggCheckButton.BackgroundTransparency = 0.85
GetEggCheckButton.BorderSizePixel = 0
GetEggCheckButton.Text = ""
GetEggCheckButton.AutoButtonColor = false
GetEggCheckButton.Parent = GetEggBox

local GetEggCheckCorner = Instance.new("UICorner")
GetEggCheckCorner.CornerRadius = UDim.new(0, 8)
GetEggCheckCorner.Parent = GetEggCheckButton

local GetEggCheckStroke = Instance.new("UIStroke")
GetEggCheckStroke.Color = Color3.fromRGB(255, 255, 255)
GetEggCheckStroke.Thickness = 2
GetEggCheckStroke.Parent = GetEggCheckButton

local GetEggCheck = Instance.new("TextLabel")
GetEggCheck.Size = UDim2.new(1, 0, 1, 0)
GetEggCheck.BackgroundTransparency = 1
GetEggCheck.Text = "✓"
GetEggCheck.TextColor3 = Color3.fromRGB(255, 255, 255)
GetEggCheck.TextSize = 20
GetEggCheck.Font = Enum.Font.GothamBold
GetEggCheck.Visible = false
GetEggCheck.Parent = GetEggCheckButton

local SelectedEggId = nil
local GetEggEnabled = false

local function UpdateGetEggBox(Icon, Name, Rate, EggId)
    GetEggIcon.Image = Icon or ""
    GetEggName.Text = Name or "No Egg Selected"
    GetEggRate.Text = "$" .. (_G.YOKUDO_AutoFarm and _G.YOKUDO_AutoFarm.FormatMoney(Rate or 0) or tostring(Rate or 0)) .. "/s"
    SelectedEggId = EggId

    GetEggIcon.ImageTransparency = 1
    GetEggName.TextTransparency = 1
    GetEggRate.TextTransparency = 1

    TweenService:Create(GetEggIcon, TweenInfo.new(0.2), {ImageTransparency = 0}):Play()
    TweenService:Create(GetEggName, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
    TweenService:Create(GetEggRate, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
end

local function ToggleGetEgg()
    GetEggEnabled = not GetEggEnabled
    GetEggCheck.Visible = GetEggEnabled
    if GetEggEnabled then
        GetEggCheckButton.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
        GetEggCheckButton.BackgroundTransparency = 0
        GetEggCheckStroke.Color = Color3.fromRGB(135, 120, 225)
        if SelectedEggId and _G.YOKUDO_AutoFarm then
            -- ✅ ហៅ SelectEgg ដែលនឹងអាន Method និង Speed ពី _G
            local EggData = { Id = SelectedEggId }
            _G.YOKUDO_AutoFarm.SelectEgg(EggData)
        end
    else
        GetEggCheckButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        GetEggCheckButton.BackgroundTransparency = 0.85
        GetEggCheckStroke.Color = Color3.fromRGB(255, 255, 255)
        if _G.YOKUDO_TeleportFly then _G.YOKUDO_TeleportFly.Disable() end
        if _G.YOKUDO_InstantTeleport then _G.YOKUDO_InstantTeleport.Disable() end
    end
end

GetEggCheckButton.MouseButton1Click:Connect(function()
    ToggleGetEgg()
end)

-- ... (ដែលនៅសល់ដូចដើម)
