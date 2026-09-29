--==================================================
-- YOKUDO HUB | TAB | Event
-- Feature: Auto Event New (គ្រប់គ្រងដោយ ManagerDrone)
-- ✅ User Toggle → Enable ManagerDrone (Full Control)
-- ✅ User ដកធិក → Stop All (ManagerDrone + AutoEventNew + AFKSystem)
--==================================================

local TabsManager = _G.YOKUDO_TabsManager
local TweenService = game:GetService("TweenService")

local EventTab, EventPage = TabsManager:RegisterTab("Event", 5, "EVENT")

--==================================================
-- CONTENT
--==================================================
CreateSectionTitle(EventPage, "Event", 1)

--==================================================
-- FEATURE: AUTO EVENT NEW
--==================================================
local EventHolder = Instance.new("Frame")
EventHolder.Size = UDim2.new(1, 0, 0, 52)
EventHolder.BackgroundTransparency = 1
EventHolder.LayoutOrder = 2
EventHolder.Parent = EventPage

local EventLabel = Instance.new("TextLabel")
EventLabel.Size = UDim2.new(1, -50, 0, 20)
EventLabel.Position = UDim2.new(0, 0, 0, 2)
EventLabel.BackgroundTransparency = 1
EventLabel.Text = "Auto Event New"
EventLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
EventLabel.TextSize = 13
EventLabel.TextXAlignment = Enum.TextXAlignment.Left
EventLabel.TextYAlignment = Enum.TextYAlignment.Center
EventLabel.Font = Enum.Font.GothamBold
EventLabel.Parent = EventHolder

local EventSub = Instance.new("TextLabel")
EventSub.Size = UDim2.new(1, -50, 0, 18)
EventSub.Position = UDim2.new(0, 0, 0, 24)
EventSub.BackgroundTransparency = 1
EventSub.Text = "Auto Farm Boss (Mech/Ball/Human)"
EventSub.TextColor3 = Color3.fromRGB(150, 150, 170)
EventSub.TextSize = 10
EventSub.TextXAlignment = Enum.TextXAlignment.Left
EventSub.Font = Enum.Font.Gotham
EventSub.Parent = EventHolder

local EventButton = Instance.new("TextButton")
EventButton.Size = UDim2.new(0, 26, 0, 26)
EventButton.Position = UDim2.new(1, -26, 0.5, -13)
EventButton.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
EventButton.BorderSizePixel = 0
EventButton.Text = ""
EventButton.AutoButtonColor = false
EventButton.Parent = EventHolder

local EventCorner = Instance.new("UICorner")
EventCorner.CornerRadius = UDim.new(0, 6)
EventCorner.Parent = EventButton

local EventStroke = Instance.new("UIStroke")
EventStroke.Color = Color3.fromRGB(200, 200, 220)
EventStroke.Thickness = 1.5
EventStroke.Parent = EventButton

local EventCheck = Instance.new("TextLabel")
EventCheck.Size = UDim2.new(1, 0, 1, 0)
EventCheck.BackgroundTransparency = 1
EventCheck.Text = "✓"
EventCheck.TextColor3 = Color3.fromRGB(255, 255, 255)
EventCheck.TextSize = 18
EventCheck.Font = Enum.Font.GothamBold
EventCheck.Visible = false
EventCheck.Parent = EventButton

--==================================================
-- UPDATE UI
--==================================================
local function UpdateEventUI(State)
    EventCheck.Visible = State
    if State then
        EventButton.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
        EventStroke.Color = Color3.fromRGB(135, 120, 225)
    else
        EventButton.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
        EventStroke.Color = Color3.fromRGB(200, 200, 220)
    end
end

--==================================================
-- STOP ALL (ពេល User ដកធិក)
--==================================================
local function StopAll()
    print("[YOKUDO] ================================")
    print("[YOKUDO] 🔄 Stop All Features + Full Reset...")
    print("[YOKUDO] ================================")

    -- ✅ 1. Stop ManagerDrone (វានឹង Stop AutoEventNew + AFK ដោយខ្លួនឯង)
    if _G.YOKUDO_ManagerDrone then
        pcall(function()
            _G.YOKUDO_ManagerDrone.Disable()
        end)
        print("[YOKUDO] ✅ ManagerDrone Stopped")
    end

    -- ✅ 2. Stop AutoEventNew (Safety)
    if _G.YOKUDO_AutoEventNew then
        pcall(function()
            if _G.YOKUDO_AutoEventNew.FullReset then
                _G.YOKUDO_AutoEventNew.FullReset()
            else
                _G.YOKUDO_AutoEventNew.Disable()
            end
        end)
        print("[YOKUDO] ✅ AutoEventNew Stopped + Reset")
    end

    -- ✅ 3. Stop AFKSystem (Safety)
    if _G.YOKUDO_AFKSystem then
        pcall(function()
            _G.YOKUDO_AFKSystem.Disable()
        end)
        print("[YOKUDO] ✅ AFKSystem Stopped")
    end

    -- ✅ 4. Stop AttackDrone (បើមាន)
    if _G.YOKUDO_AttackDrone then
        pcall(function()
            _G.YOKUDO_AttackDrone.Stop()
        end)
        print("[YOKUDO] ✅ AttackDrone Stopped")
    end

    -- ✅ 5. Reset UI
    UpdateEventUI(false)

    print("[YOKUDO] ================================")
    print("[YOKUDO] ✅ Stop All Complete")
    print("[YOKUDO] ================================")
end

--==================================================
-- TOGGLE — User ចុច → Enable ManagerDrone
--==================================================
EventButton.MouseButton1Click:Connect(function()
    if not _G.YOKUDO_ManagerDrone then
        warn("[YOKUDO] ManagerDrone not loaded!")
        return
    end

    local NewState = not _G.YOKUDO_ManagerDrone.IsEnabled()
    UpdateEventUI(NewState)
    _G.YOKUDO_AutoEventNewEnabled = NewState

    if NewState then
        -- ✅ Enable ManagerDrone (វានឹងគ្រប់គ្រង AutoEventNew + AFK)
        _G.YOKUDO_ManagerDrone.Enable()
        print("[YOKUDO] ✅ ManagerDrone Enabled (Full Control)")
    else
        -- ✅ Disable ManagerDrone + Stop All
        StopAll()
    end
end)

--==================================================
-- SYNC ON LOAD
--==================================================
task.spawn(function()
    task.wait(1)
    if _G.YOKUDO_ManagerDrone then
        UpdateEventUI(_G.YOKUDO_ManagerDrone.IsEnabled())
    elseif _G.YOKUDO_AutoEventNew then
        UpdateEventUI(_G.YOKUDO_AutoEventNew.IsEnabled())
    end
end)

--==================================================
-- REFRESH FUNCTION
--==================================================
_G.YOKUDO_RefreshEventUI = function()
    if _G.YOKUDO_ManagerDrone then
        UpdateEventUI(_G.YOKUDO_ManagerDrone.IsEnabled())
    elseif _G.YOKUDO_AutoEventNew then
        UpdateEventUI(_G.YOKUDO_AutoEventNew.IsEnabled())
    end
end

--==================================================
-- PERIODIC SYNC
--==================================================
task.spawn(function()
    while task.wait(1) do
        local Target = _G.YOKUDO_ManagerDrone or _G.YOKUDO_AutoEventNew
        if Target then
            local CurrentState = Target.IsEnabled()
            if CurrentState ~= EventCheck.Visible then
                UpdateEventUI(CurrentState)
            end
        end
    end
end)

print("✅ Event Tab Loaded (ManagerDrone Control)")f
