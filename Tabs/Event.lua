--==================================================
-- YOKUDO HUB | TAB | Event
-- Feature: Auto Event New (គ្រប់គ្រងដោយ ManagerDrone)
-- ✅ Safe Check — គ្មាន Error Line 259
-- ✅ User Toggle → Enable ManagerDrone (Full Control)
-- ✅ User ដកធិក → Stop All
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
-- ✅ SAFE GET STATE (គ្មាន Error)
--==================================================
local function GetCurrentState()
    -- ✅ Try ManagerDrone first
    if _G.YOKUDO_ManagerDrone and type(_G.YOKUDO_ManagerDrone.IsEnabled) == "function" then
        local OK, State = pcall(function()
            return _G.YOKUDO_ManagerDrone.IsEnabled()
        end)
        if OK then return State end
    end

    -- ✅ Fallback AutoEventNew
    if _G.YOKUDO_AutoEventNew and type(_G.YOKUDO_AutoEventNew.IsEnabled) == "function" then
        local OK, State = pcall(function()
            return _G.YOKUDO_AutoEventNew.IsEnabled()
        end)
        if OK then return State end
    end

    return false
end

--==================================================
-- STOP ALL
--==================================================
local function StopAll()
    print("[YOKUDO] ================================")
    print("[YOKUDO] 🔄 Stop All Features + Full Reset...")
    print("[YOKUDO] ================================")

    -- ✅ 1. Stop ManagerDrone
    if _G.YOKUDO_ManagerDrone and _G.YOKUDO_ManagerDrone.Disable then
        pcall(function() _G.YOKUDO_ManagerDrone.Disable() end)
        print("[YOKUDO] ✅ ManagerDrone Stopped")
    end

    -- ✅ 2. Stop AutoEventNew
    if _G.YOKUDO_AutoEventNew then
        pcall(function()
            if _G.YOKUDO_AutoEventNew.FullReset then
                _G.YOKUDO_AutoEventNew.FullReset()
            elseif _G.YOKUDO_AutoEventNew.Disable then
                _G.YOKUDO_AutoEventNew.Disable()
            end
        end)
        print("[YOKUDO] ✅ AutoEventNew Stopped + Reset")
    end

    -- ✅ 3. Stop AFKSystem
    if _G.YOKUDO_AFKSystem and _G.YOKUDO_AFKSystem.Disable then
        pcall(function() _G.YOKUDO_AFKSystem.Disable() end)
        print("[YOKUDO] ✅ AFKSystem Stopped")
    end

    -- ✅ 4. Stop AttackDrone
    if _G.YOKUDO_AttackDrone and _G.YOKUDO_AttackDrone.Stop then
        pcall(function() _G.YOKUDO_AttackDrone.Stop() end)
        print("[YOKUDO] ✅ AttackDrone Stopped")
    end

    UpdateEventUI(false)

    print("[YOKUDO] ================================")
    print("[YOKUDO] ✅ Stop All Complete")
    print("[YOKUDO] ================================")
end

--==================================================
-- TOGGLE — Safe Check
--==================================================
EventButton.MouseButton1Click:Connect(function()
    -- ✅ Safe Check ManagerDrone
    if not _G.YOKUDO_ManagerDrone or type(_G.YOKUDO_ManagerDrone.IsEnabled) ~= "function" then
        warn("[YOKUDO] ManagerDrone not ready!")
        return
    end

    local CurrentState = GetCurrentState()
    local NewState = not CurrentState

    UpdateEventUI(NewState)
    _G.YOKUDO_AutoEventNewEnabled = NewState

    if NewState then
        -- ✅ Enable ManagerDrone
        if _G.YOKUDO_ManagerDrone.Enable then
            pcall(function() _G.YOKUDO_ManagerDrone.Enable() end)
            print("[YOKUDO] ✅ ManagerDrone Enabled (Full Control)")
        end
    else
        -- ✅ Stop All
        StopAll()
    end
end)

--==================================================
-- SYNC ON LOAD (Safe)
--==================================================
task.spawn(function()
    task.wait(1.5)
    local State = GetCurrentState()
    UpdateEventUI(State)
end)

--==================================================
-- REFRESH FUNCTION (Safe)
--==================================================
_G.YOKUDO_RefreshEventUI = function()
    local State = GetCurrentState()
    UpdateEventUI(State)
end

--==================================================
-- PERIODIC SYNC (Safe)
--==================================================
task.spawn(function()
    while task.wait(1) do
        local State = GetCurrentState()
        if State ~= EventCheck.Visible then
            UpdateEventUI(State)
        end
    end
end)

print("✅ Event Tab Loaded (Safe Check v4)")
