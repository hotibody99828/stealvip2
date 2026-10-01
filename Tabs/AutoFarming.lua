-- ==================================================
-- YOKUDO HUB | TAB | Auto Farming (FAST)
-- ✅ Update ឲ្យត្រូវនឹង TeleportSystem v22
-- ✅ Select UID → Walk TP + Fly TP + Lock
-- ✅ AutoStop ពេល Egg បាត់
-- ==================================================

local TabsManager = _G.YOKUDO_TabsManager
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local AutoFarmingTab, AutoFarmingPage = TabsManager:RegisterTab("Auto Farming", 4, "AUTO_FARMING")

-- ==================================================
-- CONTENT
-- ==================================================
CreateSectionTitle(AutoFarmingPage, "Auto Farming", 1)

-- ==================================================
-- STATE
-- ==================================================
local SelectedUid = nil
local SelectedEggData = nil
local IsRunning = false
local UidList = {}
local UidEntries = {}

-- ==================================================
-- ✅ FEATURE 1: Select UID + Start
-- ==================================================
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

-- ✅ Update Egg Box Function
local function UpdateGetEggBox(Data)
    GetEggIcon.Image = Data.Icon or ""
    GetEggName.Text = Data.DisplayName or "Unknown"
    GetEggRate.Text = "$" .. (_G.YOKUDO_AutoFarm and _G.YOKUDO_AutoFarm.FormatMoney(Data.EarningRate or 0) or tostring(Data.EarningRate or 0)) .. "/s"
    SelectedUid = Data.Uid
    SelectedEggData = Data

    print("[AutoFarming] Selected UID:", SelectedUid)
end

-- ✅ Toggle Get Egg (Start/Stop)
local function ToggleGetEgg()
    if IsRunning then
        -- ✅ Stop
        IsRunning = false
        GetEggCheck.Visible = false
        GetEggCheckButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        GetEggCheckButton.BackgroundTransparency = 0.85
        GetEggCheckStroke.Color = Color3.fromRGB(255, 255, 255)

        if _G.YOKUDO_TeleportSystem then
            _G.YOKUDO_TeleportSystem.Disable()
        end
        print("[AutoFarming] STOP")
    else
        -- ✅ Start
        if not SelectedUid then
            warn("[AutoFarming] No UID selected")
            return
        end

        IsRunning = true
        GetEggCheck.Visible = true
        GetEggCheckButton.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
        GetEggCheckButton.BackgroundTransparency = 0
        GetEggCheckStroke.Color = Color3.fromRGB(135, 120, 225)

        if _G.YOKUDO_TeleportSystem then
            _G.YOKUDO_TeleportSystem.SetTargetId(SelectedUid)
            _G.YOKUDO_TeleportSystem.SetSpeed(200)
            _G.YOKUDO_TeleportSystem.Enable()
        else
            warn("[AutoFarming] TeleportSystem not loaded!")
        end
        print("[AutoFarming] START | UID:", SelectedUid)
    end
end

GetEggCheckButton.MouseButton1Click:Connect(function()
    ToggleGetEgg()
end)

-- ==================================================
-- ✅ FEATURE 2: Refresh UID List
-- ==================================================
local CheckEggHolder = Instance.new("Frame")
CheckEggHolder.Size = UDim2.new(1, 0, 0, 44)
CheckEggHolder.BackgroundColor3 = Color3.fromRGB(28, 29, 42)
CheckEggHolder.BorderSizePixel = 0
CheckEggHolder.LayoutOrder = 3
CheckEggHolder.Parent = AutoFarmingPage

local CheckEggHolderCorner = Instance.new("UICorner")
CheckEggHolderCorner.CornerRadius = UDim.new(0, 8)
CheckEggHolderCorner.Parent = CheckEggHolder

local CheckEggHolderStroke = Instance.new("UIStroke")
CheckEggHolderStroke.Color = Color3.fromRGB(105, 90, 190)
CheckEggHolderStroke.Thickness = 1.5
CheckEggHolderStroke.Transparency = 0.4
CheckEggHolderStroke.Parent = CheckEggHolder

local CheckEggLabel = Instance.new("TextLabel")
CheckEggLabel.Size = UDim2.new(1, -140, 1, 0)
CheckEggLabel.Position = UDim2.new(0, 12, 0, 0)
CheckEggLabel.BackgroundTransparency = 1
CheckEggLabel.Text = "Refresh UID List"
CheckEggLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
CheckEggLabel.TextSize = 13
CheckEggLabel.TextXAlignment = Enum.TextXAlignment.Left
CheckEggLabel.TextYAlignment = Enum.TextYAlignment.Center
CheckEggLabel.Font = Enum.Font.GothamBold
CheckEggLabel.Parent = CheckEggHolder

local CheckEggCount = Instance.new("TextLabel")
CheckEggCount.Size = UDim2.new(0, 80, 1, 0)
CheckEggCount.Position = UDim2.new(1, -150, 0, 0)
CheckEggCount.BackgroundTransparency = 1
CheckEggCount.Text = "Egg: 0"
CheckEggCount.TextColor3 = Color3.fromRGB(100, 255, 100)
CheckEggCount.TextSize = 10
CheckEggCount.TextXAlignment = Enum.TextXAlignment.Right
CheckEggCount.TextYAlignment = Enum.TextYAlignment.Center
CheckEggCount.Font = Enum.Font.Gotham
CheckEggCount.Parent = CheckEggHolder

local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Size = UDim2.new(0, 70, 0, 30)
RefreshBtn.Position = UDim2.new(1, -78, 0.5, -15)
RefreshBtn.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
RefreshBtn.BorderSizePixel = 0
RefreshBtn.Text = "Refresh"
RefreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RefreshBtn.TextSize = 11
RefreshBtn.Font = Enum.Font.GothamBold
RefreshBtn.AutoButtonColor = false
RefreshBtn.Parent = CheckEggHolder

local RefreshCorner = Instance.new("UICorner")
RefreshCorner.CornerRadius = UDim.new(0, 6)
RefreshCorner.Parent = RefreshBtn

-- ==================================================
-- ✅ EGG LIST (Scroll)
-- ==================================================
local EggScrollFrame = Instance.new("ScrollingFrame")
EggScrollFrame.Size = UDim2.new(1, 0, 0, 220)
EggScrollFrame.BackgroundTransparency = 1
EggScrollFrame.BorderSizePixel = 0
EggScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
EggScrollFrame.ScrollBarThickness = 4
EggScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(200, 200, 220)
EggScrollFrame.LayoutOrder = 4
EggScrollFrame.Parent = AutoFarmingPage

local EggListLayout = Instance.new("UIListLayout")
EggListLayout.Padding = UDim.new(0, 4)
EggListLayout.SortOrder = Enum.SortOrder.LayoutOrder
EggListLayout.Parent = EggScrollFrame

-- ✅ Clear List
local function ClearList()
    for _, child in ipairs(EggScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    UidEntries = {}
end

-- ✅ Create UID Entry
local function CreateEntry(Data, Index)
    local Entry = Instance.new("Frame")
    Entry.Size = UDim2.new(1, -4, 0, 50)
    Entry.BackgroundColor3 = Color3.fromRGB(30, 31, 45)
    Entry.BorderSizePixel = 0
    Entry.LayoutOrder = Index
    Entry.Parent = EggScrollFrame

    local EntryCorner = Instance.new("UICorner")
    EntryCorner.CornerRadius = UDim.new(0, 6)
    EntryCorner.Parent = Entry

    local EntryStroke = Instance.new("UIStroke")
    EntryStroke.Color = Color3.fromRGB(105, 90, 190)
    EntryStroke.Thickness = 1
    EntryStroke.Transparency = 0.6
    EntryStroke.Parent = Entry

    local IconFrame = Instance.new("Frame")
    IconFrame.Size = UDim2.new(0, 34, 0, 34)
    IconFrame.Position = UDim2.new(0, 6, 0.5, -17)
    IconFrame.BackgroundColor3 = Color3.fromRGB(40, 42, 58)
    IconFrame.BorderSizePixel = 0
    IconFrame.Parent = Entry

    local IconCorner = Instance.new("UICorner")
    IconCorner.CornerRadius = UDim.new(0, 6)
    IconCorner.Parent = IconFrame

    local IconImage = Instance.new("ImageLabel")
    IconImage.Size = UDim2.new(1, -4, 1, -4)
    IconImage.Position = UDim2.new(0, 2, 0, 2)
    IconImage.BackgroundTransparency = 1
    IconImage.Image = Data.Icon or ""
    IconImage.Parent = IconFrame

    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(1, -160, 0, 16)
    NameLabel.Position = UDim2.new(0, 48, 0, 6)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = Data.DisplayName or "Unknown"
    NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    NameLabel.TextSize = 11
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    NameLabel.Font = Enum.Font.GothamBold
    NameLabel.Parent = Entry

    local UidLabel = Instance.new("TextLabel")
    UidLabel.Size = UDim2.new(1, -160, 0, 14)
    UidLabel.Position = UDim2.new(0, 48, 0, 24)
    UidLabel.BackgroundTransparency = 1
    UidLabel.Text = Data.Uid
    UidLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
    UidLabel.TextSize = 9
    UidLabel.TextXAlignment = Enum.TextXAlignment.Left
    UidLabel.Font = Enum.Font.Gotham
    UidLabel.TextTruncate = Enum.TextTruncate.AtEnd
    UidLabel.Parent = Entry

    local SelectBtn = Instance.new("TextButton")
    SelectBtn.Size = UDim2.new(0, 70, 0, 26)
    SelectBtn.Position = UDim2.new(1, -76, 0.5, -13)
    SelectBtn.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
    SelectBtn.BorderSizePixel = 0
    SelectBtn.Text = "Select"
    SelectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    SelectBtn.TextSize = 11
    SelectBtn.Font = Enum.Font.GothamBold
    SelectBtn.AutoButtonColor = false
    SelectBtn.Parent = Entry

    local SelectCorner = Instance.new("UICorner")
    SelectCorner.CornerRadius = UDim.new(0, 6)
    SelectCorner.Parent = SelectBtn

    SelectBtn.MouseButton1Click:Connect(function()
        UpdateGetEggBox(Data)
        print("[AutoFarming] Selected:", Data.DisplayName, "| UID:", Data.Uid)
    end)

    return Entry
end

-- ✅ Refresh UID List
local function RefreshUidList()
    ClearList()

    local Container = workspace:FindFirstChild("AreaEggSlotsClient")
    if not Container then
        CheckEggCount.Text = "Egg: 0"
        return
    end

    local Eggs = {}
    for _, child in ipairs(Container:GetChildren()) do
        if child:IsA("Model") and not string.find(child.Name, "FirstAreaEgg") then
            -- ✅ Get Data from AutoFarm
            if _G.YOKUDO_AutoFarm then
                local AssetCategory = nil
                -- Use AutoFarm's FindAssetCategory
                local List = _G.YOKUDO_AutoFarm.ScanEggs and _G.YOKUDO_AutoFarm.ScanEggs() or {}
                for _, EggData in ipairs(List) do
                    if EggData.Id == child.Name then
                        table.insert(Eggs, EggData)
                        break
                    end
                end
            end
        end
    end

    for i, Data in ipairs(Eggs) do
        CreateEntry({
            Uid = Data.Id,
            DisplayName = Data.DisplayName,
            Icon = Data.Icon,
            EarningRate = Data.EarningRate,
        }, i)
    end

    CheckEggCount.Text = "Egg: " .. #Eggs
    print("[AutoFarming] Found " .. #Eggs .. " UIDs")
end

RefreshBtn.MouseButton1Click:Connect(function()
    RefreshUidList()
end)

-- ✅ Auto Refresh រាល់ 2s
task.spawn(function()
    while task.wait(2) do
        pcall(function()
            RefreshUidList()
        end)
    end
end)

-- ✅ Initial Refresh
task.wait(1)
RefreshUidList()

print("✅ Auto Farming Tab Loaded (v22 - Update for TeleportSystem)")
