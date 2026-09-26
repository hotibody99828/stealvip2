-- ==================================================
-- YOKUDO HUB | TAB | Don't Use It
-- ✅ CheckBox → Show/Hide Floating Toggle
-- ✅ Floating Toggle ចុច ON/OFF → Feature Enable/Disable
-- ==================================================

local TabsManager = _G.YOKUDO_TabsManager
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local DontUseItTab, DontUseItPage = TabsManager:RegisterTab("Don't Use It", 8, "DONT_USE_IT")

-- ==================================================
-- CONTENT
-- ==================================================
CreateSectionTitle(DontUseItPage, "Don't Use It", 1)

-- ==================================================
-- FEATURE: Show Floating Toggle (CheckBox)
-- ==================================================
local ShowHolder = Instance.new("Frame")
ShowHolder.Size = UDim2.new(1, 0, 0, 52)
ShowHolder.BackgroundTransparency = 1
ShowHolder.LayoutOrder = 2
ShowHolder.Parent = DontUseItPage

local ShowLabel = Instance.new("TextLabel")
ShowLabel.Size = UDim2.new(1, -50, 0, 20)
ShowLabel.Position = UDim2.new(0, 0, 0, 2)
ShowLabel.BackgroundTransparency = 1
ShowLabel.Text = "Show Floating Toggle"
ShowLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
ShowLabel.TextSize = 13
ShowLabel.TextXAlignment = Enum.TextXAlignment.Left
ShowLabel.TextYAlignment = Enum.TextYAlignment.Center
ShowLabel.Font = Enum.Font.GothamBold
ShowLabel.Parent = ShowHolder

local ShowSub = Instance.new("TextLabel")
ShowSub.Size = UDim2.new(1, -50, 0, 18)
ShowSub.Position = UDim2.new(0, 0, 0, 24)
ShowSub.BackgroundTransparency = 1
ShowSub.Text = "Check to show floating toggle"
ShowSub.TextColor3 = Color3.fromRGB(150, 150, 170)
ShowSub.TextSize = 10
ShowSub.TextXAlignment = Enum.TextXAlignment.Left
ShowSub.Font = Enum.Font.Gotham
ShowSub.Parent = ShowHolder

local ShowButton = Instance.new("TextButton")
ShowButton.Size = UDim2.new(0, 26, 0, 26)
ShowButton.Position = UDim2.new(1, -26, 0.5, -13)
ShowButton.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
ShowButton.BorderSizePixel = 0
ShowButton.Text = ""
ShowButton.AutoButtonColor = false
ShowButton.Parent = ShowHolder

local ShowCorner = Instance.new("UICorner")
ShowCorner.CornerRadius = UDim.new(0, 6)
ShowCorner.Parent = ShowButton

local ShowStroke = Instance.new("UIStroke")
ShowStroke.Color = Color3.fromRGB(200, 200, 220)
ShowStroke.Thickness = 1.5
ShowStroke.Parent = ShowButton

local ShowCheck = Instance.new("TextLabel")
ShowCheck.Size = UDim2.new(1, 0, 1, 0)
ShowCheck.BackgroundTransparency = 1
ShowCheck.Text = "✓"
ShowCheck.TextColor3 = Color3.fromRGB(255, 255, 255)
ShowCheck.TextSize = 18
ShowCheck.Font = Enum.Font.GothamBold
ShowCheck.Visible = false
ShowCheck.Parent = ShowButton

-- ==================================================
-- FLOATING TOGGLE
-- ==================================================
local FloatingGui = nil
local FloatingFrame = nil
local FloatingLabel = nil
local FloatingEnabled = false

local function CreateFloatingToggle()
    if FloatingGui then return end

    FloatingGui = Instance.new("ScreenGui")
    FloatingGui.Name = "YokudoFloatingToggle"
    FloatingGui.ResetOnSpawn = false
    FloatingGui.IgnoreGuiInset = true
    FloatingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    FloatingGui.DisplayOrder = 9999
    FloatingGui.Parent = CoreGui

    FloatingFrame = Instance.new("TextButton")
    FloatingFrame.Name = "Toggle"
    FloatingFrame.Size = UDim2.new(0, 160, 0, 44)
    FloatingFrame.Position = UDim2.new(0, 20, 0.5, -22)
    FloatingFrame.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
    FloatingFrame.BorderSizePixel = 0
    FloatingFrame.Text = ""
    FloatingFrame.AutoButtonColor = false
    FloatingFrame.Active = true
    FloatingFrame.Parent = FloatingGui

    local FrameCorner = Instance.new("UICorner")
    FrameCorner.CornerRadius = UDim.new(0, 8)
    FrameCorner.Parent = FloatingFrame

    local FrameStroke = Instance.new("UIStroke")
    FrameStroke.Name = "Stroke"
    FrameStroke.Color = Color3.fromRGB(200, 200, 220)
    FrameStroke.Thickness = 1.5
    FrameStroke.Parent = FloatingFrame

    FloatingLabel = Instance.new("TextLabel")
    FloatingLabel.Name = "Label"
    FloatingLabel.Size = UDim2.new(1, -20, 1, 0)
    FloatingLabel.Position = UDim2.new(0, 10, 0, 0)
    FloatingLabel.BackgroundTransparency = 1
    FloatingLabel.Text = "Don't use it : OFF"
    FloatingLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
    FloatingLabel.TextSize = 12
    FloatingLabel.TextXAlignment = Enum.TextXAlignment.Center
    FloatingLabel.TextYAlignment = Enum.TextYAlignment.Center
    FloatingLabel.Font = Enum.Font.GothamBold
    FloatingLabel.Active = false
    FloatingLabel.Parent = FloatingFrame

    -- ==================================================
    -- CLICK TOGGLE ON/OFF
    -- ==================================================
    FloatingFrame.MouseButton1Click:Connect(function()
        FloatingEnabled = not FloatingEnabled

        if FloatingEnabled then
            FloatingFrame.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
            FloatingFrame.Stroke.Color = Color3.fromRGB(135, 120, 225)
            FloatingLabel.Text = "Don't use it : ON"

            -- ✅ Enable Feature
            if _G.YOKUDO_DontUseIt then
                _G.YOKUDO_DontUseIt.Enable()
            end

            print("[Don't Use It] Toggle: ON")
        else
            FloatingFrame.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
            FloatingFrame.Stroke.Color = Color3.fromRGB(200, 200, 220)
            FloatingLabel.Text = "Don't use it : OFF"

            -- ✅ Disable Feature
            if _G.YOKUDO_DontUseIt then
                _G.YOKUDO_DontUseIt.Disable()
            end

            print("[Don't Use It] Toggle: OFF")
        end
    end)

    -- ==================================================
    -- DRAG SYSTEM
    -- ==================================================
    local Dragging = false
    local DragStart = nil
    local StartPos = nil
    local ActiveTouch = nil

    FloatingFrame.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1
        or Input.UserInputType == Enum.UserInputType.Touch then
            if Dragging then return end
            if Input.UserInputType == Enum.UserInputType.Touch then
                ActiveTouch = Input
            end
            Dragging = true
            DragStart = Input.Position
            StartPos = FloatingFrame.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(Input)
        if not Dragging then return end
        if Input.UserInputType == Enum.UserInputType.Touch then
            if ActiveTouch and Input ~= ActiveTouch then return end
        end
        if not DragStart or not StartPos then return end
        if Input.UserInputType ~= Enum.UserInputType.MouseMovement
        and Input.UserInputType ~= Enum.UserInputType.Touch then return end

        local Delta = Input.Position - DragStart
        FloatingFrame.Position = UDim2.new(
            StartPos.X.Scale,
            StartPos.X.Offset + Delta.X,
            StartPos.Y.Scale,
            StartPos.Y.Offset + Delta.Y
        )
    end)

    UserInputService.InputEnded:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.Touch then
            if ActiveTouch and Input == ActiveTouch then
                Dragging = false
                ActiveTouch = nil
                DragStart = nil
                StartPos = nil
            end
            return
        end
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            if Dragging then
                Dragging = false
                DragStart = nil
                StartPos = nil
            end
        end
    end)

    print("[Don't Use It] Floating Toggle Created")
end

local function ShowFloatingToggle()
    CreateFloatingToggle()
    if FloatingGui then
        FloatingGui.Enabled = true
    end
end

local function HideFloatingToggle()
    if FloatingGui then
        FloatingGui.Enabled = false
    end
end

-- ==================================================
-- CHECKBOX TOGGLE
-- ==================================================
local ShowEnabled = false

local function ToggleShow()
    ShowEnabled = not ShowEnabled
    ShowCheck.Visible = ShowEnabled

    if ShowEnabled then
        ShowButton.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
        ShowStroke.Color = Color3.fromRGB(135, 120, 225)
        ShowFloatingToggle()
        print("[Don't Use It] Floating Toggle: SHOWN")
    else
        ShowButton.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
        ShowStroke.Color = Color3.fromRGB(200, 200, 220)
        HideFloatingToggle()
        print("[Don't Use It] Floating Toggle: HIDDEN")
    end
end

ShowButton.MouseButton1Click:Connect(function()
    ToggleShow()
end)

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_FloatingToggle = {
    Show = ShowFloatingToggle,
    Hide = HideFloatingToggle,
    IsVisible = function() return ShowEnabled end,
    IsToggled = function() return FloatingEnabled end,
}

print("✅ Don't Use It Tab Loaded")
