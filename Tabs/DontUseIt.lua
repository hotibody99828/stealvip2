-- ==================================================
-- YOKUDO HUB | TAB | Don't Use It
-- ==================================================

local TabsManager = _G.YOKUDO_TabsManager
local TweenService = game:GetService("TweenService")

local DontUseItTab, DontUseItPage = TabsManager:RegisterTab("Don't Use It", 8, "DONT_USE_IT")

-- ==================================================
-- CONTENT
-- ==================================================
CreateSectionTitle(DontUseItPage, "Don't Use It", 1)

-- ==================================================
-- FEATURE: Don't use it
-- ==================================================
local Holder = Instance.new("Frame")
Holder.Size = UDim2.new(1, 0, 0, 60)
Holder.BackgroundTransparency = 1
Holder.LayoutOrder = 2
Holder.Parent = DontUseItPage

local Label = Instance.new("TextLabel")
Label.Size = UDim2.new(1, -50, 0, 20)
Label.Position = UDim2.new(0, 0, 0, 2)
Label.BackgroundTransparency = 1
Label.Text = "Don't use it"
Label.TextColor3 = Color3.fromRGB(255, 255, 255)
Label.TextSize = 13
Label.TextXAlignment = Enum.TextXAlignment.Left
Label.TextYAlignment = Enum.TextYAlignment.Center
Label.Font = Enum.Font.GothamBold
Label.Parent = Holder

local Sub = Instance.new("TextLabel")
Sub.Size = UDim2.new(1, -50, 0, 16)
Sub.Position = UDim2.new(0, 0, 0, 22)
Sub.BackgroundTransparency = 1
Sub.Text = "WalkSpeed 800 + Fast Click + Check Egg"
Sub.TextColor3 = Color3.fromRGB(150, 150, 170)
Sub.TextSize = 10
Sub.TextXAlignment = Enum.TextXAlignment.Left
Sub.Font = Enum.Font.Gotham
Sub.Parent = Holder

local Warn = Instance.new("TextLabel")
Warn.Size = UDim2.new(1, -50, 0, 14)
Warn.Position = UDim2.new(0, 0, 0, 38)
Warn.BackgroundTransparency = 1
Warn.Text = "⚠ Use at your own risk"
Warn.TextColor3 = Color3.fromRGB(255, 80, 80)
Warn.TextSize = 9
Warn.TextXAlignment = Enum.TextXAlignment.Left
Warn.Font = Enum.Font.Gotham
Warn.Parent = Holder

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

-- ==================================================
-- TOGGLE
-- ==================================================
local Enabled = false

local function Toggle()
    if not _G.YOKUDO_DontUseIt then
        warn("[YOKUDO] DontUseIt feature not loaded!")
        return
    end

    Enabled = not Enabled
    Check.Visible = Enabled

    if Enabled then
        Button.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
        Stroke.Color = Color3.fromRGB(135, 120, 225)
        _G.YOKUDO_DontUseIt.Enable()
    else
        Button.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
        Stroke.Color = Color3.fromRGB(200, 200, 220)
        _G.YOKUDO_DontUseIt.Disable()
    end

    if _G.YOKUDO_ConfigSystem then
        _G.YOKUDO_ConfigSystem.Save()
    end
end

Button.MouseButton1Click:Connect(function()
    Toggle()
end)

-- ==================================================
-- SYNC ON LOAD
-- ==================================================
task.spawn(function()
    task.wait(1)
    if _G.YOKUDO_DontUseIt then
        local State = _G.YOKUDO_DontUseIt.IsEnabled()
        Enabled = State
        Check.Visible = State
        if State then
            Button.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
            Stroke.Color = Color3.fromRGB(135, 120, 225)
        end
    end
end)

-- ==================================================
-- REFRESH FUNCTION
-- ==================================================
_G.YOKUDO_RefreshDontUseItUI = function()
    if _G.YOKUDO_DontUseIt then
        local State = _G.YOKUDO_DontUseIt.IsEnabled()
        Enabled = State
        Check.Visible = State
        if State then
            Button.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
            Stroke.Color = Color3.fromRGB(135, 120, 225)
        else
            Button.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
            Stroke.Color = Color3.fromRGB(200, 200, 220)
        end
        print("[YOKUDO] Don't Use It Tab UI Refreshed | State: " .. tostring(State))
    end
end

print("✅ Don't Use It Tab Loaded")
