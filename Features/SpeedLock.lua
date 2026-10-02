-- ==================================================
-- YOKUDO HUB | FEATURE | Speed Lock System (v3)
-- ✅ Block Click ពេល Speed < 1B
-- ✅ Show Message: "To Get Speed 1B UP"
-- ✅ Fix Syntax Error
-- ✅ Safe Call (pcall)
-- ==================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer

-- ==================================================
-- ✅ CONFIG
-- ==================================================
local CONFIG = {
    RequiredSpeed = 1000000000,  -- 1B
    MessageDuration = 5,  -- វិនាទី
}

-- ==================================================
-- STATE
-- ==================================================
local IsUnlocked = false
local SpeedValue = nil
local LockedButtons = {}
local BlockedConnections = {}

-- ==================================================
-- ✅ SAFE CALL
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
-- ✅ GET SPEED VALUE
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
-- ✅ FORMAT NUMBER
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
-- ✅ CHECK SPEED
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
-- ✅ SHOW NOTIFICATION (Top Center)
-- ==================================================
local function ShowMessage(Text, Duration)
    -- ✅ សម្អាតចាស់
    pcall(function()
        local Old = CoreGui:FindFirstChild("SpeedLockMessage")
        if Old then Old:Destroy() end
    end)
    
    local MessageGui = Instance.new("ScreenGui")
    MessageGui.Name = "SpeedLockMessage"
    MessageGui.ResetOnSpawn = false
    MessageGui.IgnoreGuiInset = true
    MessageGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    MessageGui.DisplayOrder = 9999
    MessageGui.Parent = CoreGui
    
    local Container = Instance.new("Frame")
    Container.Name = "Container"
    Container.Size = UDim2.new(0, 380, 0, 60)
    Container.Position = UDim2.new(0.5, -190, 0, 80)
    Container.BackgroundColor3 = Color3.fromRGB(20, 21, 30)
    Container.BackgroundTransparency = 0.05
    Container.BorderSizePixel = 0
    Container.Parent = MessageGui
    
    local ContainerCorner = Instance.new("UICorner")
    ContainerCorner.CornerRadius = UDim.new(0, 10)
    ContainerCorner.Parent = Container
    
    local ContainerStroke = Instance.new("UIStroke")
    ContainerStroke.Color = Color3.fromRGB(255, 80, 80)
    ContainerStroke.Thickness = 2
    ContainerStroke.Transparency = 0.2
    ContainerStroke.Parent = Container
    
    -- ✅ Lock Icon
    local LockIcon = Instance.new("ImageLabel")
    LockIcon.Size = UDim2.new(0, 32, 0, 32)
    LockIcon.Position = UDim2.new(0, 12, 0.5, -16)
    LockIcon.BackgroundTransparency = 1
    LockIcon.Image = "rbxassetid://6031090990"
    LockIcon.ImageColor3 = Color3.fromRGB(255, 80, 80)
    LockIcon.Parent = Container
    
    -- ✅ Text
    local TextLabel = Instance.new("TextLabel")
    TextLabel.Size = UDim2.new(1, -60, 1, 0)
    TextLabel.Position = UDim2.new(0, 52, 0, 0)
    TextLabel.BackgroundTransparency = 1
    TextLabel.Text = Text
    TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextLabel.TextSize = 13
    TextLabel.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel.TextYAlignment = Enum.TextYAlignment.Center
    TextLabel.Font = Enum.Font.GothamBold
    TextLabel.TextWrapped = true
    TextLabel.Parent = Container
    
    -- ✅ Slide In Animation
    Container.Position = UDim2.new(0.5, -190, 0, -80)
    TweenService:Create(Container, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -190, 0, 80)
    }):Play()
    
    -- ✅ Auto Remove
    task.delay(Duration or CONFIG.MessageDuration, function()
        if Container and Container.Parent then
            TweenService:Create(Container, TweenInfo.new(0.3), {
                Position = UDim2.new(0.5, -190, 0, -80),
                BackgroundTransparency = 1
            }):Play()
            TweenService:Create(TextLabel, TweenInfo.new(0.3), {
                TextTransparency = 1
            }):Play()
            TweenService:Create(LockIcon, TweenInfo.new(0.3), {
                ImageTransparency = 1
            }):Play()
            TweenService:Create(ContainerStroke, TweenInfo.new(0.3), {
                Transparency = 1
            }):Play()
            
            task.delay(0.35, function()
                if MessageGui then MessageGui:Destroy() end
            end)
        end
    end)
end

-- ==================================================
-- ✅ CREATE LOCK ICON (On Button)
-- ==================================================
local function CreateLockIcon(Parent, Size)
    local OldLock = Parent:FindFirstChild("SpeedLockIcon")
    if OldLock then OldLock:Destroy() end
    
    local LockIcon = Instance.new("ImageLabel")
    LockIcon.Name = "SpeedLockIcon"
    LockIcon.Size = Size or UDim2.new(1, 0, 1, 0)
    LockIcon.Position = UDim2.new(0, 0, 0, 0)
    LockIcon.BackgroundTransparency = 1
    LockIcon.Image = "rbxassetid://6031090990"
    LockIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
    LockIcon.ImageTransparency = 0.2
    LockIcon.ZIndex = 100
    LockIcon.Parent = Parent
    
    local Overlay = Instance.new("Frame")
    Overlay.Name = "LockOverlay"
    Overlay.Size = UDim2.new(1, 0, 1, 0)
    Overlay.Position = UDim2.new(0, 0, 0, 0)
    Overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Overlay.BackgroundTransparency = 0.5
    Overlay.BorderSizePixel = 0
    Overlay.ZIndex = 99
    Overlay.Parent = Parent
    
    local OverlayCorner = Instance.new("UICorner")
    OverlayCorner.CornerRadius = UDim.new(0, 6)
    OverlayCorner.Parent = Overlay
    
    return LockIcon, Overlay
end

-- ==================================================
-- ✅ REMOVE LOCK ICON
-- ==================================================
local function RemoveLockIcon(Parent)
    local LockIcon = Parent:FindFirstChild("SpeedLockIcon")
    if LockIcon then LockIcon:Destroy() end
    
    local Overlay = Parent:FindFirstChild("LockOverlay")
    if Overlay then Overlay:Destroy() end
end

-- ==================================================
-- ✅ REGISTER LOCKABLE BUTTON
-- ==================================================
local function RegisterLockableButton(Button, Name)
    if not Button then return end
    
    table.insert(LockedButtons, {
        Button = Button,
        Name = Name or Button.Name,
    })
    
    print("[SpeedLock] 📝 Registered:", Name or Button.Name)
end

-- ==================================================
-- ✅ APPLY LOCK (Block Click + Show Message)
-- ==================================================
local function ApplyLockToAll()
    for _, data in ipairs(LockedButtons) do
        local Button = data.Button
        if Button and Button.Parent then
            -- ✅ Lock Icon
            CreateLockIcon(Button, UDim2.new(0, 26, 0, 26))
            
            -- ✅ Disable Button
            Button.Active = false
            Button.Selectable = false
            
            -- ✅ Block Click + Show Message
            local Conn = Button.MouseButton1Click:Connect(function()
                -- ✅ Show Message
                ShowMessage(
                    "🔒 To Get Speed 1B UP\nWhen 1B Done, Please Exit Game and Join Again",
                    CONFIG.MessageDuration
                )
                warn("[SpeedLock] 🔒 Feature Locked! Required Speed: 1B+")
            end)
            
            -- ✅ Store Connection
            table.insert(BlockedConnections, Conn)
        end
    end
    
    print("[SpeedLock] 🔒 Applied Lock to", #LockedButtons, "buttons")
end

-- ==================================================
-- ✅ REMOVE LOCK
-- ==================================================
local function RemoveLockFromAll()
    -- ✅ Disconnect Blocked Connections
    for _, Conn in ipairs(BlockedConnections) do
        pcall(function() Conn:Disconnect() end)
    end
    BlockedConnections = {}
    
    for _, data in ipairs(LockedButtons) do
        local Button = data.Button
        if Button and Button.Parent then
            RemoveLockIcon(Button)
            Button.Active = true
            Button.Selectable = true
        end
    end
    
    print("[SpeedLock] 🔓 Removed Lock from", #LockedButtons, "buttons")
end

-- ==================================================
-- ✅ MAIN CHECK
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
-- ✅ PUBLIC API
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

-- ✅ កែត្រង់នេះ — Syntax Fix
SpeedLock.RegisterLockable = RegisterLockableButton
SpeedLock.RunCheck = RunCheck
SpeedLock.ApplyLock = ApplyLockToAll
SpeedLock.RemoveLock = RemoveLockFromAll

-- ==================================================
-- ✅ EXPORT
-- ==================================================
_G.YOKUDO_SpeedLock = SpeedLock

print("✅ Speed Lock System Loaded (v3 — Block Click + Message)")
