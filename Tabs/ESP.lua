-- ==================================================
-- YOKUDO HUB | TAB | ESP (v8 - No ESP Line)
-- ✅ ESP Name (BillboardGui)
-- ✅ ESP Distance (ធំ ច្បាស់)
-- ✅ ESP Box (Scale with Distance)
-- ❌ ESP Line (REMOVED)
-- ✅ No Limit Distance
-- ✅ Mobile + PC Support
-- ==================================================

local TabsManager = _G.YOKUDO_TabsManager
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local ESPTab, ESPPage = TabsManager:RegisterTab("ESP", 9, "ESP")

CreateSectionTitle(ESPPage, "ESP", 1)

-- ==================================================
-- STATE
-- ==================================================
local Settings = {
    Name = false,
    Distance = false,
    Box = false,
}

local ESPData = {}
local ActiveConns = {}

-- ==================================================
-- HELPERS
-- ==================================================
local function GetRoot(Player)
    local Char = Player.Character
    if not Char then return nil end
    return Char:FindFirstChild("HumanoidRootPart")
end

local function GetHead(Player)
    local Char = Player.Character
    if not Char then return nil end
    return Char:FindFirstChild("Head")
end

local function IsAlive(Player)
    if Player == LocalPlayer then return false end
    local Char = Player.Character
    if not Char then return false end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    if not Hum or Hum.Health <= 0 then return false end
    if not Char:FindFirstChild("HumanoidRootPart") then return false end
    return true
end

-- ==================================================
-- BILLBOARD (Name + Distance)
-- ==================================================
local function CreateESPBillboard(Player)
    local Head = GetHead(Player)
    if not Head then return nil end

    local BB = Instance.new("BillboardGui")
    BB.Name = "YokudoESP_BB"
    BB.Size = UDim2.new(0, 220, 0, 60)
    BB.StudsOffset = Vector3.new(0, 3, 0)
    BB.AlwaysOnTop = true
    BB.Enabled = true
    BB.Parent = Head

    local NameL = Instance.new("TextLabel")
    NameL.Name = "NameL"
    NameL.Size = UDim2.new(1, 0, 0, 24)
    NameL.Position = UDim2.new(0, 0, 0, 0)
    NameL.BackgroundTransparency = 1
    NameL.Text = Player.Name
    NameL.TextColor3 = Color3.fromRGB(255, 255, 255)
    NameL.TextSize = 16
    NameL.Font = Enum.Font.GothamBold
    NameL.TextStrokeTransparency = 0.3
    NameL.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    NameL.Visible = Settings.Name
    NameL.Parent = BB

    local DistL = Instance.new("TextLabel")
    DistL.Name = "DistL"
    DistL.Size = UDim2.new(1, 0, 0, 20)
    DistL.Position = UDim2.new(0, 0, 0, 24)
    DistL.BackgroundTransparency = 1
    DistL.Text = "..."
    DistL.TextColor3 = Color3.fromRGB(100, 255, 100)
    DistL.TextSize = 14
    DistL.Font = Enum.Font.GothamBold
    DistL.TextStrokeTransparency = 0.3
    DistL.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    DistL.Visible = Settings.Distance
    DistL.Parent = BB

    return BB
end

-- ==================================================
-- BOX SCREEN GUI
-- ==================================================
local function CreateScreenGui()
    local SG = Instance.new("ScreenGui")
    SG.Name = "YokudoESP_Screen"
    SG.ResetOnSpawn = false
    SG.IgnoreGuiInset = true
    SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    SG.DisplayOrder = 999
    SG.Parent = LocalPlayer:WaitForChild("PlayerGui")
    return SG
end

local function CreateBoxFrame(Parent)
    local Box = Instance.new("Frame")
    Box.Name = "ESP_Box"
    Box.AnchorPoint = Vector2.new(0.5, 0.5)
    Box.BackgroundTransparency = 1
    Box.BorderSizePixel = 0
    Box.Visible = false
    Box.ZIndex = 999
    Box.Parent = Parent

    local Stroke = Instance.new("UIStroke")
    Stroke.Name = "Stroke"
    Stroke.Color = Color3.fromRGB(255, 255, 255)
    Stroke.Thickness = 1.5
    Stroke.Transparency = 0
    Stroke.Parent = Box

    return Box
end

-- ==================================================
-- UPDATE BOX (Scale with Distance)
-- ==================================================
local function UpdateBox(Box, Head, Root)
    local HeadPos, HeadOn = Camera:WorldToViewportPoint(Head.Position)
    local RootPos, RootOn = Camera:WorldToViewportPoint(Root.Position)

    if not HeadOn or not RootOn then
        Box.Visible = false
        return
    end

    local ScreenHeight = math.abs(HeadPos.Y - RootPos.Y)
    local BoxHeight = ScreenHeight * 1.8
    local BoxWidth = BoxHeight * 0.6

    BoxHeight = math.clamp(BoxHeight, 25, 600)
    BoxWidth = math.clamp(BoxWidth, 15, 400)

    local CenterX = HeadPos.X
    local CenterY = HeadPos.Y + (RootPos.Y - HeadPos.Y) / 2

    Box.Size = UDim2.new(0, BoxWidth, 0, BoxHeight)
    Box.Position = UDim2.new(0, CenterX, 0, CenterY)
    Box.Visible = true
end

-- ==================================================
-- ADD ESP
-- ==================================================
local function AddESP(Player)
    if ESPData[Player] then return end
    if not IsAlive(Player) then return end

    local SG = CreateScreenGui()
    local BB = CreateESPBillboard(Player)
    local BoxFrame = CreateBoxFrame(SG)

    ESPData[Player] = {
        ScreenGui = SG,
        Billboard = BB,
        BoxFrame = BoxFrame,
        Conn = nil,
    }

    local Conn = RunService.RenderStepped:Connect(function()
        if not (Settings.Name or Settings.Distance or Settings.Box) then
            return
        end

        if not IsAlive(Player) then
            if BB then BB.Enabled = false end
            if BoxFrame then BoxFrame.Visible = false end
            return
        end

        local Head = GetHead(Player)
        local Root = GetRoot(Player)
        if not Head or not Root then return end

        -- ✅ Billboard (Name + Distance)
        if BB then
            if BB.Parent ~= Head then BB.Parent = Head end
            BB.Enabled = Settings.Name or Settings.Distance
            local NameL = BB:FindFirstChild("NameL")
            local DistL = BB:FindFirstChild("DistL")
            if NameL then
                NameL.Visible = Settings.Name
                NameL.Text = Player.Name
            end
            if DistL then
                DistL.Visible = Settings.Distance
                if Settings.Distance then
                    local MyRoot = GetRoot(LocalPlayer)
                    if MyRoot then
                        local Dist = math.floor((MyRoot.Position - Root.Position).Magnitude)
                        DistL.Text = Dist .. " studs"
                    else
                        DistL.Text = "? studs"
                    end
                end
            end
        end

        -- ✅ Box (Scale with Distance)
        if BoxFrame then
            if Settings.Box then
                UpdateBox(BoxFrame, Head, Root)
            else
                BoxFrame.Visible = false
            end
        end
    end)

    ESPData[Player].Conn = Conn
    table.insert(ActiveConns, Conn)
end

-- ==================================================
-- REMOVE ESP
-- ==================================================
local function RemoveESP(Player)
    local Data = ESPData[Player]
    if not Data then return end
    if Data.Billboard then Data.Billboard:Destroy() end
    if Data.ScreenGui then Data.ScreenGui:Destroy() end
    if Data.Conn then pcall(function() Data.Conn:Disconnect() end) end
    ESPData[Player] = nil
end

-- ==================================================
-- CLEAR ALL
-- ==================================================
local function ClearAll()
    for P, _ in pairs(ESPData) do RemoveESP(P) end
    for _, C in ipairs(ActiveConns) do pcall(function() C:Disconnect() end) end
    ActiveConns = {}
    ESPData = {}
end

-- ==================================================
-- REFRESH
-- ==================================================
local function Refresh()
    local Any = Settings.Name or Settings.Distance or Settings.Box
    if not Any then ClearAll() return end
    for _, P in ipairs(Players:GetPlayers()) do
        if P ~= LocalPlayer and IsAlive(P) then
            AddESP(P)
        end
    end
end

-- ==================================================
-- PLAYER TRACKING
-- ==================================================
Players.PlayerAdded:Connect(function(P)
    P.CharacterAdded:Connect(function()
        task.wait(0.5)
        if Settings.Name or Settings.Distance or Settings.Box then
            AddESP(P)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(P)
    RemoveESP(P)
end)

-- ==================================================
-- UI CHECKBOX HELPER
-- ==================================================
local function CreateFeature(LabelText, SubText, Order, OnToggle)
    local Holder = Instance.new("Frame")
    Holder.Size = UDim2.new(1, 0, 0, 52)
    Holder.BackgroundTransparency = 1
    Holder.LayoutOrder = Order
    Holder.Parent = ESPPage

    local L = Instance.new("TextLabel")
    L.Size = UDim2.new(1, -50, 0, 20)
    L.Position = UDim2.new(0, 0, 0, 2)
    L.BackgroundTransparency = 1
    L.Text = LabelText
    L.TextColor3 = Color3.fromRGB(255, 255, 255)
    L.TextSize = 13
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.Font = Enum.Font.GothamBold
    L.Parent = Holder

    local S = Instance.new("TextLabel")
    S.Size = UDim2.new(1, -50, 0, 16)
    S.Position = UDim2.new(0, 0, 0, 24)
    S.BackgroundTransparency = 1
    S.Text = SubText
    S.TextColor3 = Color3.fromRGB(150, 150, 170)
    S.TextSize = 10
    S.TextXAlignment = Enum.TextXAlignment.Left
    S.Font = Enum.Font.Gotham
    S.Parent = Holder

    local B = Instance.new("TextButton")
    B.Size = UDim2.new(0, 26, 0, 26)
    B.Position = UDim2.new(1, -26, 0.5, -13)
    B.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
    B.BorderSizePixel = 0
    B.Text = ""
    B.AutoButtonColor = false
    B.Parent = Holder

    local C = Instance.new("UICorner")
    C.CornerRadius = UDim.new(0, 6)
    C.Parent = B

    local St = Instance.new("UIStroke")
    St.Color = Color3.fromRGB(200, 200, 220)
    St.Thickness = 1.5
    St.Parent = B

    local Chk = Instance.new("TextLabel")
    Chk.Size = UDim2.new(1, 0, 1, 0)
    Chk.BackgroundTransparency = 1
    Chk.Text = "✓"
    Chk.TextColor3 = Color3.fromRGB(255, 255, 255)
    Chk.TextSize = 18
    Chk.Font = Enum.Font.GothamBold
    Chk.Visible = false
    Chk.Parent = B

    local Enabled = false
    B.MouseButton1Click:Connect(function()
        Enabled = not Enabled
        Chk.Visible = Enabled
        if Enabled then
            B.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
            St.Color = Color3.fromRGB(135, 120, 225)
        else
            B.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
            St.Color = Color3.fromRGB(200, 200, 220)
        end
        OnToggle(Enabled)
        Refresh()
    end)
end

-- ==================================================
-- FEATURES (No ESP Line)
-- ==================================================
CreateFeature("ESP Name", "Show player name above head", 2, function(s)
    Settings.Name = s
end)

CreateFeature("ESP Distance", "Show distance in studs (No Limit)", 3, function(s)
    Settings.Distance = s
end)

CreateFeature("ESP Box", "Draw box (Small far, Big close)", 4, function(s)
    Settings.Box = s
end)

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_ESP = {
    Settings = Settings,
    Refresh = Refresh,
    Clear = ClearAll,
    Add = AddESP,
    Remove = RemoveESP,
}

-- ==================================================
-- SYNC ON LOAD
-- ==================================================
task.spawn(function()
    task.wait(1)
    Refresh()
end)

print("✅ ESP Tab Loaded (v8 - No ESP Line)")
