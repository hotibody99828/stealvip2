-- ==================================================
-- YOKUDO HUB | TAB | ESP
-- Features: ESP Name, ESP Line, ESP Distance, ESP Box
-- ✅ No Limit Distance
-- ✅ No ConfigSystem
-- ==================================================

local TabsManager = _G.YOKUDO_TabsManager
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local ESPTab, ESPPage = TabsManager:RegisterTab("ESP", 9, "ESP")

-- ==================================================
-- CONTENT
-- ==================================================
CreateSectionTitle(ESPPage, "ESP", 1)

-- ==================================================
-- STATE
-- ==================================================
local ESPData = {}          -- [Player] = { Billboard, Highlight, Drawings, Conn }
local ActiveConnections = {}

local Settings = {
    Name = false,
    Line = false,
    Distance = false,
    Box = false,
}

local COLORS = {
    Name = Color3.fromRGB(255, 255, 255),
    Distance = Color3.fromRGB(100, 255, 100),
    Box = Color3.fromRGB(255, 255, 255),
    Line = Color3.fromRGB(255, 50, 50),
    Fill = Color3.fromRGB(255, 0, 0),
}

-- ==================================================
-- UTILS
-- ==================================================
local function IsValid(Player)
    if Player == LocalPlayer then return false end
    local Char = Player.Character
    if not Char then return false end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    local Root = Char:FindFirstChild("HumanoidRootPart")
    if not Hum or not Root then return false end
    if Hum.Health <= 0 then return false end
    return true
end

local function GetRoot(Player)
    local Char = Player.Character
    if not Char then return nil end
    return Char:FindFirstChild("HumanoidRootPart")
end

local function GetLocalRoot()
    local Char = LocalPlayer.Character
    if not Char then return nil end
    return Char:FindFirstChild("HumanoidRootPart")
end

-- ==================================================
-- CREATE BILLBOARD (Name + Distance)
-- ==================================================
local function CreateBillboard(Player)
    local Root = GetRoot(Player)
    if not Root then return nil end

    local Billboard = Instance.new("BillboardGui")
    Billboard.Name = "YokudoESP_BB"
    Billboard.Size = UDim2.new(0, 200, 0, 44)
    Billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    Billboard.AlwaysOnTop = true
    Billboard.Parent = Root

    local NameLabel = Instance.new("TextLabel")
    NameLabel.Name = "NameLabel"
    NameLabel.Size = UDim2.new(1, 0, 0, 20)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = Player.Name
    NameLabel.TextColor3 = COLORS.Name
    NameLabel.TextSize = 14
    NameLabel.Font = Enum.Font.GothamBold
    NameLabel.TextStrokeTransparency = 0
    NameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    NameLabel.Visible = Settings.Name
    NameLabel.Parent = Billboard

    local DistanceLabel = Instance.new("TextLabel")
    DistanceLabel.Name = "DistanceLabel"
    DistanceLabel.Size = UDim2.new(1, 0, 0, 16)
    DistanceLabel.Position = UDim2.new(0, 0, 0, 20)
    DistanceLabel.BackgroundTransparency = 1
    DistanceLabel.Text = "0 studs"
    DistanceLabel.TextColor3 = COLORS.Distance
    DistanceLabel.TextSize = 11
    DistanceLabel.Font = Enum.Font.Gotham
    DistanceLabel.TextStrokeTransparency = 0
    DistanceLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    DistanceLabel.Visible = Settings.Distance
    DistanceLabel.Parent = Billboard

    return Billboard
end

-- ==================================================
-- CREATE DRAWINGS (Box + Line)
-- ==================================================
local function CreateDrawings()
    local DrawingsTable = {}

    if Drawing then
        local Box = Drawing.new("Square")
        Box.Visible = false
        Box.Color = COLORS.Box
        Box.Thickness = 1.5
        Box.Filled = false
        Box.Transparency = 1
        DrawingsTable.Box = Box

        local Fill = Drawing.new("Square")
        Fill.Visible = false
        Fill.Color = COLORS.Fill
        Fill.Thickness = 0
        Fill.Filled = true
        Fill.Transparency = 0.7
        DrawingsTable.Fill = Fill

        local Line = Drawing.new("Line")
        Line.Visible = false
        Line.Color = COLORS.Line
        Line.Thickness = 1.5
        Line.Transparency = 1
        DrawingsTable.Line = Line
    end

    return DrawingsTable
end

-- ==================================================
-- ADD ESP FOR PLAYER
-- ==================================================
local function AddESP(Player)
    if ESPData[Player] then return end
    if not IsValid(Player) then return end

    local Billboard = CreateBillboard(Player)
    local DrawingsTable = CreateDrawings()

    local Highlight = Instance.new("Highlight")
    Highlight.Name = "YokudoESP_HL"
    Highlight.FillColor = COLORS.Fill
    Highlight.OutlineColor = COLORS.Box
    Highlight.FillTransparency = 0.7
    Highlight.OutlineTransparency = 0
    Highlight.Visible = Settings.Box
    Highlight.Parent = Player.Character

    ESPData[Player] = {
        Billboard = Billboard,
        Highlight = Highlight,
        Drawings = DrawingsTable,
        Conn = nil,
    }

    -- ✅ Update Loop (No Limit Distance)
    local Conn = RunService.RenderStepped:Connect(function()
        if not (Settings.Name or Settings.Distance or Settings.Box or Settings.Line) then
            return
        end

        if not IsValid(Player) then
            if DrawingsTable then
                if DrawingsTable.Box then DrawingsTable.Box.Visible = false end
                if DrawingsTable.Fill then DrawingsTable.Fill.Visible = false end
                if DrawingsTable.Line then DrawingsTable.Line.Visible = false end
            end
            if Billboard then Billboard.Enabled = false end
            if Highlight then Highlight.Visible = false end
            return
        end

        local TheirRoot = GetRoot(Player)
        if not TheirRoot then return end

        -- ✅ Billboard
        if Billboard then
            Billboard.Enabled = Settings.Name or Settings.Distance
            local NameL = Billboard:FindFirstChild("NameLabel")
            local DistL = Billboard:FindFirstChild("DistanceLabel")
            if NameL then NameL.Visible = Settings.Name end
            if DistL then DistL.Visible = Settings.Distance end

            -- ✅ Distance (No Limit)
            local MyRoot = GetLocalRoot()
            if MyRoot and DistL then
                local Dist = math.floor((MyRoot.Position - TheirRoot.Position).Magnitude)
                DistL.Text = Dist .. " studs"
            end
        end

        -- ✅ Highlight (Box)
        if Highlight then
            Highlight.Visible = Settings.Box
        end

        -- ✅ Drawings
        if Drawing and DrawingsTable then
            local Char = Player.Character
            local Head = Char and Char:FindFirstChild("Head")

            if not Head then return end

            local HeadPos, HeadOnScreen = Camera:WorldToViewportPoint(Head.Position)
            local RootPos, RootOnScreen = Camera:WorldToViewportPoint(TheirRoot.Position)

            -- ✅ ESP Box
            if Settings.Box and HeadOnScreen and RootOnScreen then
                local Height = math.abs(HeadPos.Y - RootPos.Y) * 1.6
                local Width = Height * 0.6
                local CenterX = HeadPos.X
                local CenterY = HeadPos.Y + (RootPos.Y - HeadPos.Y) / 2

                local Box = DrawingsTable.Box
                if Box then
                    Box.Size = Vector2.new(Width, Height)
                    Box.Position = Vector2.new(CenterX - Width / 2, CenterY - Height / 2)
                    Box.Visible = true
                end

                local Fill = DrawingsTable.Fill
                if Fill then
                    Fill.Size = Vector2.new(Width, Height)
                    Fill.Position = Vector2.new(CenterX - Width / 2, CenterY - Height / 2)
                    Fill.Visible = true
                end
            else
                if DrawingsTable.Box then DrawingsTable.Box.Visible = false end
                if DrawingsTable.Fill then DrawingsTable.Fill.Visible = false end
            end

            -- ✅ ESP Line
            if Settings.Line then
                local ViewportSize = Camera.ViewportSize
                local Line = DrawingsTable.Line
                if Line and HeadOnScreen then
                    Line.From = Vector2.new(ViewportSize.X / 2, ViewportSize.Y)
                    Line.To = Vector2.new(HeadPos.X, HeadPos.Y)
                    Line.Visible = true
                else
                    if Line then Line.Visible = false end
                end
            else
                if DrawingsTable.Line then DrawingsTable.Line.Visible = false end
            end
        end
    end)

    ESPData[Player].Conn = Conn
    table.insert(ActiveConnections, Conn)
end

-- ==================================================
-- REMOVE ESP
-- ==================================================
local function RemoveESP(Player)
    local Data = ESPData[Player]
    if not Data then return end

    if Data.Billboard then Data.Billboard:Destroy() end
    if Data.Highlight then Data.Highlight:Destroy() end
    if Data.Drawings then
        for _, obj in pairs(Data.Drawings) do
            pcall(function() obj:Remove() end)
        end
    end
    if Data.Conn then
        pcall(function() Data.Conn:Disconnect() end)
    end

    ESPData[Player] = nil
end

-- ==================================================
-- CLEAR ALL
-- ==================================================
local function ClearAllESP()
    for Player, _ in pairs(ESPData) do
        RemoveESP(Player)
    end
    for _, Conn in ipairs(ActiveConnections) do
        pcall(function() Conn:Disconnect() end)
    end
    ActiveConnections = {}
    ESPData = {}
end

-- ==================================================
-- REFRESH ALL
-- ==================================================
local function RefreshESP()
    local AnyEnabled = Settings.Name or Settings.Distance or Settings.Box or Settings.Line

    if not AnyEnabled then
        ClearAllESP()
        return
    end

    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer and IsValid(Player) then
            AddESP(Player)
        end
    end
end

-- ==================================================
-- PLAYER TRACKING
-- ==================================================
Players.PlayerAdded:Connect(function(Player)
    Player.CharacterAdded:Connect(function()
        task.wait(0.5)
        if Settings.Name or Settings.Distance or Settings.Box or Settings.Line then
            AddESP(Player)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(Player)
    RemoveESP(Player)
end)

-- ==================================================
-- UI HELPER (Checkbox)
-- ==================================================
local function CreateESPFeature(LabelText, SubText, Order, OnToggle)
    local Holder = Instance.new("Frame")
    Holder.Size = UDim2.new(1, 0, 0, 52)
    Holder.BackgroundTransparency = 1
    Holder.LayoutOrder = Order
    Holder.Parent = ESPPage

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -50, 0, 20)
    Label.Position = UDim2.new(0, 0, 0, 2)
    Label.BackgroundTransparency = 1
    Label.Text = LabelText
    Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Font = Enum.Font.GothamBold
    Label.Parent = Holder

    local Sub = Instance.new("TextLabel")
    Sub.Size = UDim2.new(1, -50, 0, 16)
    Sub.Position = UDim2.new(0, 0, 0, 24)
    Sub.BackgroundTransparency = 1
    Sub.Text = SubText
    Sub.TextColor3 = Color3.fromRGB(150, 150, 170)
    Sub.TextSize = 10
    Sub.TextXAlignment = Enum.TextXAlignment.Left
    Sub.Font = Enum.Font.Gotham
    Sub.Parent = Holder

    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(0, 26, 0, 26)
    Button.Position = UDim2.new(1, -26, 0.5, -13)
    Button.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
    Button.BorderSizePixel = 0
    Button.Text = ""
    Button.AutoButtonColor = false
    Button.Parent = Holder

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = Button

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(200, 200, 220)
    Stroke.Thickness = 1.5
    Stroke.Parent = Button

    local Check = Instance.new("TextLabel")
    Check.Size = UDim2.new(1, 0, 1, 0)
    Check.BackgroundTransparency = 1
    Check.Text = "✓"
    Check.TextColor3 = Color3.fromRGB(255, 255, 255)
    Check.TextSize = 18
    Check.Font = Enum.Font.GothamBold
    Check.Visible = false
    Check.Parent = Button

    local Enabled = false

    Button.MouseButton1Click:Connect(function()
        Enabled = not Enabled
        Check.Visible = Enabled

        if Enabled then
            Button.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
            Stroke.Color = Color3.fromRGB(135, 120, 225)
        else
            Button.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
            Stroke.Color = Color3.fromRGB(200, 200, 220)
        end

        OnToggle(Enabled)
        RefreshESP()
    end)

    return Holder, Button, Check
end

-- ==================================================
-- FEATURE 1: ESP Name
-- ==================================================
CreateESPFeature("ESP Name", "Show player name above head", 2, function(state)
    Settings.Name = state
    print("[ESP] Name:", state)
end)

-- ==================================================
-- FEATURE 2: ESP Line
-- ==================================================
CreateESPFeature("ESP Line", "Draw line from bottom to player", 3, function(state)
    Settings.Line = state
    print("[ESP] Line:", state)
end)

-- ==================================================
-- FEATURE 3: ESP Distance
-- ==================================================
CreateESPFeature("ESP Distance", "Show distance in studs (No Limit)", 4, function(state)
    Settings.Distance = state
    print("[ESP] Distance:", state)
end)

-- ==================================================
-- FEATURE 4: ESP Box
-- ==================================================
CreateESPFeature("ESP Box", "Draw box + highlight around player", 5, function(state)
    Settings.Box = state
    print("[ESP] Box:", state)
end)

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_ESP = {
    Settings = Settings,
    Refresh = RefreshESP,
    Clear = ClearAllESP,
    Add = AddESP,
    Remove = RemoveESP,
    GetSettings = function() return Settings end,
    IsAnyEnabled = function()
        return Settings.Name or Settings.Line or Settings.Distance or Settings.Box
    end,
}

-- ==================================================
-- SYNC ON LOAD
-- ==================================================
task.spawn(function()
    task.wait(1)
    RefreshESP()
end)

print("✅ ESP Tab Loaded (Name + Line + Distance + Box | No Limit)")
