-- ==================================================
-- YOKUDO HUB | TAB | ESP (v3 - MOBILE SUPPORT)
-- ✅ ESP Name + Distance (BillboardGui)
-- ✅ ESP Box (Frame, Mobile Support)
-- ✅ ESP Line (Frame, Mobile Support)
-- ✅ No Limit Distance
-- ✅ Humanoid-based Box Size
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

local function GetHumanoid(Player)
    local Char = Player.Character
    if not Char then return nil end
    return Char:FindFirstChildOfClass("Humanoid")
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
-- CREATE ESP GUI (Name + Distance)
-- ==================================================
local function CreateESPBillboard(Player)
    local Head = GetHead(Player)
    if not Head then return nil end

    local BB = Instance.new("BillboardGui")
    BB.Name = "YokudoESP_BB"
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
-- CREATE ESP BOX GUI (Mobile Support)
-- ==================================================
local function CreateESPBoxGui(Player)
    local Char = Player.Character
    if not Char then return nil end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    if not Hum then return nil end

    -- ✅ Box ដាក់នៅក្រោម Humanoid (មិនមែន Head ឬ Root)
    local BoxGui = Instance.new("BillboardGui")
    BoxGui.Name = "YokudoESP_Box"
    BoxGui.Size = UDim2.new(0, 100, 0, 100)
    BoxGui.StudsOffset = Vector3.new(0, 0, 0)
    BoxGui.AlwaysOnTop = true
    BoxGui.Enabled = true
    BoxGui.Parent = Hum

    local Box = Instance.new("Frame")
    Box.Name = "Box"
    Box.Size = UDim2.new(1, 0, 1, 0)
    Box.BackgroundTransparency = 1
    Box.BorderSizePixel = 0
    Box.Visible = Settings.Box
    Box.Parent = BoxGui

    local Stroke = Instance.new("UIStroke")
    Stroke.Name = "Stroke"
    Stroke.Color = Color3.fromRGB(255, 255, 255)
    Stroke.Thickness = 1.5
    Stroke.Transparency = 0
    Stroke.Parent = Box

    return BoxGui
end

-- ==================================================
-- CREATE ESP LINE GUI (Mobile Support)
-- ==================================================
local function CreateESPLineGui()
    -- ✅ Line GUI ដាក់ក្នុង ScreenGui (តាម screen)
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "YokudoESP_Line"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 999
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local Line = Instance.new("Frame")
    Line.Name = "Line"
    Line.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    Line.BorderSizePixel = 0
    Line.Visible = Settings.Line
    Line.ZIndex = 999
    Line.Parent = ScreenGui

    return ScreenGui, Line
end

-- ==================================================
-- ROTATE LINE FRAME
-- ==================================================
local function UpdateLineFrame(LineFrame, From, To)
    local Delta = To - From
    local Length = Delta.Magnitude
    if Length <= 0 then return end

    LineFrame.Size = UDim2.new(0, Length, 0, 2)
    LineFrame.Position = UDim2.new(0, From.X, 0, From.Y - 1)
    LineFrame.Rotation = math.deg(math.atan2(Delta.Y, Delta.X))
end

-- ==================================================
-- ADD ESP
-- ==================================================
local function AddESP(Player)
    if ESPData[Player] then return end
    if not IsAlive(Player) then return end

    local BB = CreateESPBillboard(Player)
    local BoxGui = CreateESPBoxGui(Player)
    local LineGui, LineFrame = CreateESPLineGui()

    ESPData[Player] = {
        Billboard = BB,
        BoxGui = BoxGui,
        LineGui = LineGui,
        LineFrame = LineFrame,
        Conn = nil,
    }

    local Conn = RunService.RenderStepped:Connect(function()
        if not (Settings.Name or Settings.Distance or Settings.Box or Settings.Line) then
            return
        end

        if not IsAlive(Player) then
            if BB then BB.Enabled = false end
            if BoxGui then BoxGui.Enabled = false end
            if LineFrame then LineFrame.Visible = false end
            return
        end

        local Head = GetHead(Player)
        local Root = GetRoot(Player)
        local Hum = GetHumanoid(Player)
        if not Head or not Root or not Hum then return end

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

        -- ✅ Box (Humanoid-based)
        if BoxGui then
            if BoxGui.Parent ~= Hum then BoxGui.Parent = Hum end
            BoxGui.Enabled = Settings.Box

            local Box = BoxGui:FindFirstChild("Box")
            if Box then
                Box.Visible = Settings.Box

                -- ✅ Box Size តាម Humanoid (HipHeight + Head)
                local HeadPos = Head.Position
                local RootPos = Root.Position
                local Height = math.abs(HeadPos.Y - RootPos.Y) * 2 + 1
                local Width = Height * 0.6

                BoxGui.Size = UDim2.new(0, Width * 30, 0, Height * 30)
            end
        end

        -- ✅ Line (Top Screen → Head)
        if LineFrame then
            if Settings.Line then
                local HeadPos, HeadOn = Camera:WorldToViewportPoint(Head.Position)
                if HeadOn then
                    local VS = Camera.ViewportSize
                    local From = Vector2.new(VS.X / 2, 0)
                    local To = Vector2.new(HeadPos.X, HeadPos.Y)
                    UpdateLineFrame(LineFrame, From, To)
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
    if Data.BoxGui then Data.BoxGui:Destroy() end
    if Data.LineGui then Data.LineGui:Destroy() end
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

CreateFeature("ESP Line", "Draw line from Top screen to player (Mobile OK)", 3, function(s)
    Settings.Line = s
end)

CreateFeature("ESP Distance", "Show distance in studs (No Limit)", 4, function(s)
    Settings.Distance = s
end)

CreateFeature("ESP Box", "Draw box around player (Humanoid)", 5, function(s)
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

print("✅ ESP Tab Loaded (v3 - Mobile Support)")
