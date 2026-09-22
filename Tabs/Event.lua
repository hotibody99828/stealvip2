-- ==================================================
-- YOKUDO HUB | TAB | Event
-- Feature: Manager Drone (Event + AFK + Attack)
-- ==================================================

local TabsManager = _G.YOKUDO_TabsManager
local TweenService = game:GetService("TweenService")

local EventTab, EventPage = TabsManager:RegisterTab("Event", 5, "EVENT")

-- ==================================================
-- CONTENT
-- ==================================================
CreateSectionTitle(EventPage, "Event", 1)

-- ==================================================
-- FEATURE: MANAGER DRONE (Checkbox)
-- ==================================================
local ManagerDroneHolder = Instance.new("Frame")
ManagerDroneHolder.Size = UDim2.new(1, 0, 0, 52)
ManagerDroneHolder.BackgroundTransparency = 1
ManagerDroneHolder.LayoutOrder = 2
ManagerDroneHolder.Parent = EventPage

local ManagerDroneLabel = Instance.new("TextLabel")
ManagerDroneLabel.Size = UDim2.new(1, -50, 0, 20)
ManagerDroneLabel.Position = UDim2.new(0, 0, 0, 2)
ManagerDroneLabel.BackgroundTransparency = 1
ManagerDroneLabel.Text = "Manager Drone"
ManagerDroneLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
ManagerDroneLabel.TextSize = 13
ManagerDroneLabel.TextXAlignment = Enum.TextXAlignment.Left
ManagerDroneLabel.TextYAlignment = Enum.TextYAlignment.Center
ManagerDroneLabel.Font = Enum.Font.GothamBold
ManagerDroneLabel.Parent = ManagerDroneHolder

local ManagerDroneSub = Instance.new("TextLabel")
ManagerDroneSub.Size = UDim2.new(1, -50, 0, 18)
ManagerDroneSub.Position = UDim2.new(0, 0, 0, 24)
ManagerDroneSub.BackgroundTransparency = 1
ManagerDroneSub.Text = "Event Auto → Attack / AFK Treadmill"
ManagerDroneSub.TextColor3 = Color3.fromRGB(150, 150, 170)
ManagerDroneSub.TextSize = 10
ManagerDroneSub.TextXAlignment = Enum.TextXAlignment.Left
ManagerDroneSub.Font = Enum.Font.Gotham
ManagerDroneSub.Parent = ManagerDroneHolder

local ManagerDroneCheckButton = Instance.new("TextButton")
ManagerDroneCheckButton.Size = UDim2.new(0, 26, 0, 26)
ManagerDroneCheckButton.Position = UDim2.new(1, -26, 0.5, -13)
ManagerDroneCheckButton.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
ManagerDroneCheckButton.BorderSizePixel = 0
ManagerDroneCheckButton.Text = ""
ManagerDroneCheckButton.AutoButtonColor = false
ManagerDroneCheckButton.Parent = ManagerDroneHolder

local ManagerDroneCorner = Instance.new("UICorner")
ManagerDroneCorner.CornerRadius = UDim.new(0, 6)
ManagerDroneCorner.Parent = ManagerDroneCheckButton

local ManagerDroneStroke = Instance.new("UIStroke")
ManagerDroneStroke.Color = Color3.fromRGB(200, 200, 220)
ManagerDroneStroke.Thickness = 1.5
ManagerDroneStroke.Parent = ManagerDroneCheckButton

local ManagerDroneCheck = Instance.new("TextLabel")
ManagerDroneCheck.Size = UDim2.new(1, 0, 1, 0)
ManagerDroneCheck.BackgroundTransparency = 1
ManagerDroneCheck.Text = "✓"
ManagerDroneCheck.TextColor3 = Color3.fromRGB(255, 255, 255)
ManagerDroneCheck.TextSize = 18
ManagerDroneCheck.Font = Enum.Font.GothamBold
ManagerDroneCheck.Visible = false
ManagerDroneCheck.Parent = ManagerDroneCheckButton

-- ==================================================
-- TOGGLE LOGIC
-- ==================================================
ManagerDroneCheckButton.MouseButton1Click:Connect(function()
    if not _G.YOKUDO_ManagerDrone then
        warn("[YOKUDO] ManagerDrone not loaded!")
        return
    end

    local NewState = not _G.YOKUDO_ManagerDrone.IsEnabled()
    ManagerDroneCheck.Visible = NewState
    if NewState then
        ManagerDroneCheckButton.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
        ManagerDroneStroke.Color = Color3.fromRGB(135, 120, 225)
        _G.YOKUDO_ManagerDrone.Enable()
    else
        ManagerDroneCheckButton.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
        ManagerDroneStroke.Color = Color3.fromRGB(200, 200, 220)
        _G.YOKUDO_ManagerDrone.Disable()
    end
end)

-- ==================================================
-- SYNC STATE ON LOAD
-- ==================================================
task.spawn(function()
    task.wait(0.5)
    if _G.YOKUDO_ManagerDrone then
        local State = _G.YOKUDO_ManagerDrone.IsEnabled()
        ManagerDroneCheck.Visible = State
        if State then
            ManagerDroneCheckButton.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
            ManagerDroneStroke.Color = Color3.fromRGB(135, 120, 225)
        end
    end
end)

print("✅ Event Tab Loaded")
