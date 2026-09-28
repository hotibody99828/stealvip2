-- ==================================================
-- YOKUDO HUB | TAB | ESP (Mobile + PC Support)
-- ✅ ESP Name, Distance, Line, Box
-- ✅ ប្រើ BillboardGui ទាំងអស់ (No Drawing)
-- ✅ No Limit Distance
-- ✅ Box ដាក់ពីលើ Player
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
    Line = false,
    Distance = false,
    Box = false,
}

local ESPData = {}
local ActiveConns = {}

local COLORS = {
    Name = Color3.fromRGB(255, 255, 255),
    Distance = Color3.fromRGB(100, 255, 100),
    Box = Color3.fromRGB(255, 255, 255),
    Line = Color3.fromRGB(255, 50, 50),
}

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
-- CREATE BILLBOARD (Name + Distance + Box + Line)
-- ✅ ប្រើ BillboardGui ទាំងអស់
-- ==================================================
local function CreateBillboard(Player)
    local Head = GetHead(Player)
    if not Head then return nil end

    local BB = Instance.new("BillboardGui")
    BB.Name = "YokudoESP"
    BB.Size = UDim2.new(0, 200, 0, 50)
    BB.StudsOffset = Vector3.new(0, 3, 0)
    BB.AlwaysOnTop = true
    BB.Enabled = true
    BB.Parent = Head

    -- ✅ Name Label
    local NameL = Instance.new("TextLabel")
    NameL.Name = "NameL"
    NameL.Size = UDim2.new(1, 0, 0, 20)
    NameL.BackgroundTransparency = 1
    NameL.Text = Player.Name
    NameL.TextColor3 = COLORS.Name
    NameL.TextSize = 14
    NameL.Font = Enum.Font.GothamBold
    NameL.TextStrokeTransparency = 0
    NameL.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    NameL.Visible = Settings.Name
    NameL.Parent = BB

    -- ✅ Distance Label
    local DistL = Instance.new("TextLabel")
    DistL.Name = "DistL"
    DistL.Size = UDim2.new(1, 0, 0, 16)
    DistL.Position = UDim2.new(0, 0, 0, 20)
    DistL.BackgroundTransparency = 1
    DistL.Text = "..."
    DistL.TextColor3 = COLORS.Distance
    DistL.TextSize = 11
    DistL.Font = Enum.Font.Gotham
    DistL.TextStrokeTransparency = 0
    DistL.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    DistL.Visible = Settings.Distance
    DistL.Parent = BB

    -- ✅ Box (Frame ជុំវិញ Player)
    local BoxFrame = Instance.new("Frame")
    BoxFrame.Name = "BoxFrame"
    BoxFrame.Size = UDim2.new(1, 20, 1, 30)
    BoxFrame.Position = UDim2.new(0, -10, 0, -15)
    BoxFrame.BackgroundTransparency = 1
    BoxFrame.BorderSizePixel = 0
    BoxFrame.Visible = Settings.Box
    BoxFrame.ZIndex = 0
    BoxFrame.Parent = BB

    local BoxStroke = Instance.new("UIStroke")
    BoxStroke.Name = "BoxStroke"
    BoxStroke.Color = COLORS.Box
    BoxStroke.Thickness = 2
    BoxStroke.Transparency = 0
    BoxStroke.Parent = BoxFrame

    -- ✅ Line (Frame ពី Box ទៅក្រោម)
    local LineFrame = Instance.new("Frame")
    LineFrame.Name = "LineFrame"
    LineFrame.Size = UDim2.new(0, 2, 0, 0)
    LineFrame.Position = UDim2.new(0.5, -1, 0, 0)
    LineFrame.BackgroundColor3 = COLORS.Line
    LineFrame.BorderSizePixel = 0
    LineFrame.Visible = Settings.Line
    LineFrame.ZIndex = 1
    LineFrame.Parent = BB

    return BB, BoxFrame, LineFrame
end

-- ==================================================
-- ADD ESP
-- ==================================================
local function AddESP(Player)
    if ESPData[Player] then return end
    if not IsAlive(Player) then return end

    local BB, BoxFrame, LineFrame = CreateBillboard(Player)
    if not BB then return end

    ESPData[Player] = {
        Billboard = BB,
        BoxFrame = BoxFrame,
        LineFrame = LineFrame,
        Conn = nil,
    }

    local Conn = RunService.RenderStepped:Connect(function()
        if not (Settings.Name or Settings.Distance or Settings.Box or Settings.Line) then return end

        if not IsAlive(Player) then
            if BB then BB.Enabled = false end
            return
        end

        local Head = GetHead(Player)
        local Root = GetRoot(Player)
        if not Head or not Root then return end

        -- ✅ Billboard re-parent បើចាំបាច់
        if BB.Parent ~= Head then BB.Parent = Head end
        BB.Enabled = Settings.Name or Settings.Distance or Settings.Box or Settings.Line

        -- ✅ Name
        local NameL = BB:FindFirstChild("NameL")
        if NameL then
            NameL.Visible = Settings.Name
            NameL.Text = Player.Name
        end

        -- ✅ Distance (No Limit)
        local DistL = BB:FindFirstChild("DistL")
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

        -- ✅ Box (ដាក់ពីលើ Player)
        if BoxFrame then
            BoxFrame.Visible = Settings.Box
        end

        -- ✅ Line (ពី Box ទៅក្រោម — តាម Screen)
        if LineFrame then
            if Settings.Line then
                -- គណនា Screen Position
                local HeadPos, OnScreen = Camera:WorldToViewportPoint(Head.Position)
                if OnScreen then
                    -- គណនា Screen Height ពី Head ទៅ Bottom
                    local ScreenBottom = Camera.ViewportSize.Y
                    local LineLength = ScreenBottom - HeadPos.Y

                    LineFrame.Size = UDim2.new(0, 2, 0, LineLength)
                    LineFrame.Position = UDim2.new(0.5, -1, 1, 0)
                    LineFrame.Visible = true
                else
                    LineFrame.Visible = false
                end
            else
                LineFrame.Visible = false
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
    local Any = Settings.Name or Settings.Distance or Settings.Box or Settings.Line
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
        if Settings.Name or Settings.Distance or Settings.Box or Settings.Line then
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
-- FEATURES
-- ==================================================
CreateFeature("ESP Name", "Show player name above head", 2, function(s)
    Settings.Name = s
end)

CreateFeature("ESP Line", "Draw line from player to bottom", 3, function(s)
    Settings.Line = s
end)

CreateFeature("ESP Distance", "Show distance in studs (No Limit)", 4, function(s)
    Settings.Distance = s
end)

CreateFeature("ESP Box", "Draw box around player", 5, function(s)
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

print("✅ ESP Tab Loaded (Mobile + PC Support)")
