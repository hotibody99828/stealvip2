-- ==================================================
-- YOKUDO HUB | TAB | ESP (FIXED v2)
-- ✅ ESP Name + ESP Distance (BillboardGui)
-- ✅ ESP Box (Drawing) + ESP Line (Drawing)
-- ✅ No Limit Distance
-- ✅ Fix: Highlight.Enabled (not Visible)
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
-- CREATE BILLBOARD (Name + Distance)
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

    local NameL = Instance.new("TextLabel")
    NameL.Name = "NameL"
    NameL.Size = UDim2.new(1, 0, 0, 20)
    NameL.BackgroundTransparency = 1
    NameL.Text = Player.Name
    NameL.TextColor3 = Color3.fromRGB(255, 255, 255)
    NameL.TextSize = 14
    NameL.Font = Enum.Font.GothamBold
    NameL.TextStrokeTransparency = 0
    NameL.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    NameL.Visible = Settings.Name
    NameL.Parent = BB

    local DistL = Instance.new("TextLabel")
    DistL.Name = "DistL"
    DistL.Size = UDim2.new(1, 0, 0, 16)
    DistL.Position = UDim2.new(0, 0, 0, 20)
    DistL.BackgroundTransparency = 1
    DistL.Text = "..."
    DistL.TextColor3 = Color3.fromRGB(100, 255, 100)
    DistL.TextSize = 11
    DistL.Font = Enum.Font.Gotham
    DistL.TextStrokeTransparency = 0
    DistL.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    DistL.Visible = Settings.Distance
    DistL.Parent = BB

    return BB
end

-- ==================================================
-- CREATE DRAWINGS
-- ==================================================
local function CreateDrawings()
    local D = {}
    if Drawing then
        D.Box = Drawing.new("Square")
        D.Box.Visible = false
        D.Box.Color = Color3.fromRGB(255, 255, 255)
        D.Box.Thickness = 1.5
        D.Box.Filled = false
        D.Box.Transparency = 1

        D.Line = Drawing.new("Line")
        D.Line.Visible = false
        D.Line.Color = Color3.fromRGB(255, 50, 50)
        D.Line.Thickness = 1.5
        D.Line.Transparency = 1
    end
    return D
end

-- ==================================================
-- ADD ESP
-- ==================================================
local function AddESP(Player)
    if ESPData[Player] then return end
    if not IsAlive(Player) then return end

    local BB = CreateBillboard(Player)
    local D = CreateDrawings()

    ESPData[Player] = { Billboard = BB, Drawings = D, Conn = nil }

    local Conn = RunService.RenderStepped:Connect(function()
        if not (Settings.Name or Settings.Distance or Settings.Box or Settings.Line) then return end

        if not IsAlive(Player) then
            if BB then BB.Enabled = false end
            if Drawing and D then
                if D.Box then D.Box.Visible = false end
                if D.Line then D.Line.Visible = false end
            end
            return
        end

        local Head = GetHead(Player)
        local Root = GetRoot(Player)
        if not Head or not Root then return end

        -- ✅ Billboard
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

        -- ✅ Drawings
        if Drawing and D then
            local HeadPos, HeadOn = Camera:WorldToViewportPoint(Head.Position)
            local RootPos, RootOn = Camera:WorldToViewportPoint(Root.Position)

            -- Box
            if Settings.Box and HeadOn and RootOn then
                local H = math.abs(HeadPos.Y - RootPos.Y) * 1.6
                local W = H * 0.6
                local CX = HeadPos.X
                local CY = HeadPos.Y + (RootPos.Y - HeadPos.Y) / 2

                D.Box.Size = Vector2.new(W, H)
                D.Box.Position = Vector2.new(CX - W / 2, CY - H / 2)
                D.Box.Visible = true
            else
                D.Box.Visible = false
            end

            -- Line (Top Screen → Head)
            if Settings.Line and HeadOn then
                local VS = Camera.ViewportSize
                D.Line.From = Vector2.new(VS.X / 2, 0)
                D.Line.To = Vector2.new(HeadPos.X, HeadPos.Y)
                D.Line.Visible = true
            else
                D.Line.Visible = false
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
    if Data.Drawings then
        if Data.Drawings.Box then pcall(function() Data.Drawings.Box:Remove() end) end
        if Data.Drawings.Line then pcall(function() Data.Drawings.Line:Remove() end) end
    end
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

CreateFeature("ESP Line", "Draw line from Top screen to player", 3, function(s)
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

print("✅ ESP Tab Loaded (FIXED v2 - No Highlight)")
