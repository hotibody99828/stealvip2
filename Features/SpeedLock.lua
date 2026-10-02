-- ==================================================
-- YOKUDO HUB | FEATURE | Speed Lock System (v6 FINAL)
-- ✅ Emoji 🔒 លើ Button ពេល Speed < 1B
-- ✅ ដក 🔒 ចេញ ពេល Speed ≥ 1B
-- ✅ Show Message
-- ✅ Safe Call
-- ==================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer

-- ==================================================
-- CONFIG
-- ==================================================
local CONFIG = {
    RequiredSpeed = 1000000000,  -- 1B
    MessageDuration = 5,
}

-- ==================================================
-- STATE
-- ==================================================
local IsUnlocked = false
local SpeedValue = nil
local LockedButtons = {}
local OriginalButtonData = {}  -- ✅ Store Original Data

-- ==================================================
-- SAFE CALL
-- ==================================================
local function SafeCall(func, ...)
    if not func then return false end
    local args = {...}
    local Success, Err = pcall(function()
        func(table.unpack(args))
    end)
    if not Success then
        warn("[SpeedLock] Error:", Err)
    end
    return Success
end

-- ==================================================
-- GET SPEED VALUE
-- ==================================================
local function GetSpeedValue()
    local Leaderstats = Player:FindFirstChild("leaderstats")
    if Leaderstats then
        local Speed = Leaderstats:FindFirstChild("Speed")
        if Speed then return Speed end
    end
    
    local PlayerGui = Player:FindFirstChild("PlayerGui")
    if PlayerGui then
        for _, descendant in ipairs(PlayerGui:GetDescendants()) do
            if descendant.Name == "Speed" and 
               (descendant:IsA("NumberValue") or descendant:IsA("IntValue")) then
                return descendant
            end
        end
    end
    
    return nil
end

-- ==================================================
-- FORMAT NUMBER
-- ==================================================
local function FormatNumber(num)
    if type(num) ~= "number" then return tostring(num) end
    
    if num >= 1e12 then
        return string.format("%.2fT", num / 1e12)
    elseif num >= 1e9 then
        return string.format("%.2fB", num / 1e9)
    elseif num >= 1e6 then
        return string.format("%.2fM", num / 1e6)
    elseif num >= 1e3 then
        return string.format("%.2fK", num / 1e3)
    else
        return tostring(math.floor(num))
    end
end

-- ==================================================
-- CHECK SPEED
-- ==================================================
local function CheckSpeed()
    SpeedValue = GetSpeedValue()
    
    if not SpeedValue then
        warn("[SpeedLock] ⚠️ Speed Value not found!")
        return false
    end
    
    local CurrentSpeed = math.floor(tonumber(SpeedValue.Value) or 0)
    local RequiredSpeed = math.floor(CONFIG.RequiredSpeed)
    
    print("[SpeedLock] 📊 Current:", FormatNumber(CurrentSpeed))
    print("[SpeedLock] 📊 Required:", FormatNumber(RequiredSpeed))
    
    return CurrentSpeed >= RequiredSpeed
end

-- ==================================================
-- SHOW MESSAGE
-- ==================================================
local function ShowMessage(Text, Duration)
    pcall(function()
        local Old = CoreGui:FindFirstChild("SpeedLockMessage")
        if Old then Old:Destroy() end
    end)
    
    local MessageGui = Instance.new("ScreenGui")
    MessageGui.Name = "SpeedLockMessage"
    MessageGui.ResetOnSpawn = false
    MessageGui.IgnoreGuiInset = true
    MessageGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    MessageGui.DisplayOrder = 99999
    MessageGui.Parent = CoreGui
    
    local Container = Instance.new("Frame")
    Container.Name = "Container"
    Container.Size = UDim2.new(0, 420, 0, 75)
    Container.Position = UDim2.new(0.5, -210, 0, -95)
    Container.BackgroundColor3 = Color3.fromRGB(20, 21, 30)
    Container.BackgroundTransparency = 0.05
    Container.BorderSizePixel = 0
    Container.Parent = MessageGui
    
    local ContainerCorner = Instance.new("UICorner")
    ContainerCorner.CornerRadius = UDim.new(0, 12)
    ContainerCorner.Parent = Container
    
    local ContainerStroke = Instance.new("UIStroke")
    ContainerStroke.Color = Color3.fromRGB(255, 80, 80)
    ContainerStroke.Thickness = 2
    ContainerStroke.Transparency = 0.2
    ContainerStroke.Parent = Container
    
    local LockIcon = Instance.new("ImageLabel")
    LockIcon.Size = UDim2.new(0, 38, 0, 38)
    LockIcon.Position = UDim2.new(0, 14, 0.5, -19)
    LockIcon.BackgroundTransparency = 1
    LockIcon.Image = "rbxassetid://6031090990"
    LockIcon.ImageColor3 = Color3.fromRGB(255, 80, 80)
    LockIcon.Parent = Container
    
    local TextLabel = Instance.new("TextLabel")
    TextLabel.Size = UDim2.new(1, -64, 1, 0)
    TextLabel.Position = UDim2.new(0, 60, 0, 0)
    TextLabel.BackgroundTransparency = 1
    TextLabel.Text = Text
    TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextLabel.TextSize = 13
    TextLabel.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel.TextYAlignment = Enum.TextYAlignment.Center
    TextLabel.Font = Enum.Font.GothamBold
    TextLabel.TextWrapped = true
    TextLabel.Parent = Container
    
    TweenService:Create(Container, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -210, 0, 80)
    }):Play()
    
    task.delay(Duration or CONFIG.MessageDuration, function()
        if Container and Container.Parent then
            TweenService:Create(Container, TweenInfo.new(0.3), {
                Position = UDim2.new(0.5, -210, 0, -95),
                BackgroundTransparency = 1
            }):Play()
            TweenService:Create(TextLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
            TweenService:Create(LockIcon, TweenInfo.new(0.3), {ImageTransparency = 1}):Play()
            TweenService:Create(ContainerStroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
            
            task.delay(0.35, function()
                if MessageGui then MessageGui:Destroy() end
            end)
        end
    end)
end

-- ==================================================
-- REGISTER LOCKABLE BUTTON
-- ==================================================
local function RegisterLockableButton(Button, Name)
    if not Button then return end
    
    -- ✅ Store Original Data
    table.insert(OriginalButtonData, {
        Button = Button,
        OriginalText = Button.Text,
        OriginalTextSize = Button.TextSize,
        OriginalTextColor3 = Button.TextColor3,
        OriginalFont = Button.Font,
        OriginalBackgroundColor3 = Button.BackgroundColor3,
        OriginalBackgroundTransparency = Button.BackgroundTransparency,
    })
    
    table.insert(LockedButtons, {
        Button = Button,
        Name = Name or Button.Name,
    })
    
    print("[SpeedLock] 📝 Registered:", Name or Button.Name)
end

-- ==================================================
-- ✅ APPLY LOCK (ដាក់ Emoji 🔒)
-- ==================================================
local function ApplyLockToAll()
    for _, data in ipairs(LockedButtons) do
        local Button = data.Button
        if Button and Button.Parent then
            -- ✅ ដាក់ Emoji 🔒 លើ Button
            Button.Text = "🔒"
            Button.TextSize = 20
            Button.TextColor3 = Color3.fromRGB(255, 80, 80)
            Button.Font = Enum.Font.GothamBold
            
            -- ✅ Background ក្រហមស្រាល
            Button.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
            Button.BackgroundTransparency = 0.3
            
            -- ✅ Stroke ក្រហម
            local Stroke = Button:FindFirstChildOfClass("UIStroke")
            if Stroke then
                Stroke.Color = Color3.fromRGB(255, 80, 80)
                Stroke.Thickness = 2
                Stroke.Transparency = 0.2
            end
            
            -- ✅ Disable Button
            Button.Active = false
            Button.Selectable = false
        end
    end
    
    print("[SpeedLock] 🔒 Applied Lock to", #LockedButtons, "buttons")
end

-- ==================================================
-- ✅ REMOVE LOCK (ដក Emoji 🔒 ចេញ)
-- ==================================================
local function RemoveLockFromAll()
    -- ✅ Restore Original Data
    for _, data in ipairs(OriginalButtonData) do
        local Button = data.Button
        if Button and Button.Parent then
            Button.Text = data.OriginalText or ""
            Button.TextSize = data.OriginalTextSize or 14
            Button.TextColor3 = data.OriginalTextColor3 or Color3.fromRGB(255, 255, 255)
            Button.Font = data.OriginalFont or Enum.Font.GothamBold
            
            Button.BackgroundColor3 = data.OriginalBackgroundColor3 or Color3.fromRGB(28, 29, 39)
            Button.BackgroundTransparency = data.OriginalBackgroundTransparency or 0
            
            -- ✅ Stroke ត្រលប់ដើម
            local Stroke = Button:FindFirstChildOfClass("UIStroke")
            if Stroke then
                Stroke.Color = Color3.fromRGB(200, 200, 220)
                Stroke.Thickness = 1.5
                Stroke.Transparency = 0
            end
            
            Button.Active = true
            Button.Selectable = true
        end
    end
    
    print("[SpeedLock] 🔓 Removed Lock from", #LockedButtons, "buttons")
end

-- ==================================================
-- MAIN CHECK
-- ==================================================
local function RunCheck()
    print("[SpeedLock] ================================")
    print("[SpeedLock] 🔍 Checking Speed...")
    print("[SpeedLock] ================================")
    
    IsUnlocked = CheckSpeed()
    
    if IsUnlocked then
        print("[SpeedLock] 🎉 UNLOCKED!")
        RemoveLockFromAll()
    else
        print("[SpeedLock] 🔒 LOCKED!")
        ApplyLockToAll()
    end
    
    print("[SpeedLock] ================================")
end

-- ==================================================
-- PUBLIC API
-- ==================================================
local SpeedLock = {}

SpeedLock.IsUnlocked = function() return IsUnlocked end
SpeedLock.GetSpeed = function()
    if not SpeedValue then SpeedValue = GetSpeedValue() end
    return SpeedValue and math.floor(tonumber(SpeedValue.Value) or 0) or 0
end
SpeedLock.GetRequiredSpeed = function() return CONFIG.RequiredSpeed end
SpeedLock.FormatNumber = function(num) return FormatNumber(num) end
SpeedLock.ShowMessage = ShowMessage

SpeedLock.RegisterLockable = RegisterLockableButton
SpeedLock.RunCheck = RunCheck
SpeedLock.ApplyLock = ApplyLockToAll
SpeedLock.RemoveLock = RemoveLockFromAll

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_SpeedLock = SpeedLock

print("✅ Speed Lock System Loaded (v6 — Emoji 🔒)")
