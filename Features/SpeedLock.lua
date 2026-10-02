-- ==================================================
-- YOKUDO HUB | FEATURE | Speed Lock System (v2)
-- ✅ Fix Syntax Error
-- ✅ Check តែម្តងពេល Execute
-- ✅ Speed >= 1B → Unlock
-- ✅ Speed < 1B → Lock + រូបសោ (🔒)
-- ✅ Safe Call (pcall)
-- ==================================================

local Players = game:GetService("Players")

local Player = Players.LocalPlayer

-- ==================================================
-- ✅ CONFIG
-- ==================================================
local CONFIG = {
    RequiredSpeed = 1000000000,  -- 1B
}

-- ==================================================
-- STATE
-- ==================================================
local IsUnlocked = false
local SpeedValue = nil
local LockedButtons = {}

-- ==================================================
-- ✅ SAFE CALL FUNCTION
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
    
    print("[SpeedLock] 📊 Current Speed:", CurrentSpeed, "(" .. FormatNumber(CurrentSpeed) .. ")")
    print("[SpeedLock] 📊 Required Speed:", RequiredSpeed, "(" .. FormatNumber(RequiredSpeed) .. ")")
    
    return CurrentSpeed >= RequiredSpeed
end

-- ==================================================
-- ✅ CREATE LOCK ICON
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
    
    if LockIcon.Parent then
        LockIcon.Visible = true
        Overlay.Visible = true
    end
    
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
-- ✅ APPLY LOCK
-- ==================================================
local function ApplyLockToAll()
    for _, data in ipairs(LockedButtons) do
        local Button = data.Button
        if Button and Button.Parent then
            CreateLockIcon(Button, UDim2.new(0, 26, 0, 26))
            Button.Active = false
            Button.Selectable = false
            
            Button.MouseButton1Click:Connect(function()
                warn("[SpeedLock] 🔒 Feature Locked! Required Speed: 1B+")
            end)
        end
    end
    
    print("[SpeedLock] 🔒 Applied Lock to", #LockedButtons, "buttons")
end

-- ==================================================
-- ✅ REMOVE LOCK
-- ==================================================
local function RemoveLockFromAll()
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
        print("[SpeedLock] 🎉 UNLOCKED! Speed >= 1B")
        
        RemoveLockFromAll()
        
        -- ✅ Safe Call — Enable Features
        if _G.YOKUDO_FarmingManager then
            SafeCall(_G.YOKUDO_FarmingManager.Enable)
        end
        if _G.YOKUDO_AutoFarm then
            SafeCall(_G.YOKUDO_AutoFarm.Enable)
        end
    else
        print("[SpeedLock] 🔒 LOCKED! Speed < 1B")
        
        ApplyLockToAll()
        
        -- ✅ Safe Call — Disable Features
        if _G.YOKUDO_FarmingManager then
            SafeCall(_G.YOKUDO_FarmingManager.Disable)
        end
        if _G.YOKUDO_AutoFarm then
            SafeCall(_G.YOKUDO_AutoFarm.Disable)
        end
    end
    
    print("[SpeedLock] ================================")
end

-- ==================================================
-- ✅ PUBLIC API
-- ==================================================
local SpeedLock = {}

SpeedLock.IsUnlocked = function()
    return IsUnlocked
end

SpeedLock.GetSpeed = function()
    if not SpeedValue then
        SpeedValue = GetSpeedValue()
    end
    return SpeedValue and math.floor(tonumber(SpeedValue.Value) or 0) or 0
end

SpeedLock.GetRequiredSpeed = function()
    return CONFIG.RequiredSpeed
end

SpeedLock.FormatNumber = function(num)
    return FormatNumber(num)
end

-- ✅ កែត្រង់នេះ — Syntax Error Fix
SpeedLock.RegisterLockable = RegisterLockableButton
SpeedLock.RunCheck = RunCheck
SpeedLock.ApplyLock = ApplyLockToAll
SpeedLock.RemoveLock = RemoveLockFromAll

-- ==================================================
-- ✅ EXPORT
-- ==================================================
_G.YOKUDO_SpeedLock = SpeedLock

print("✅ Speed Lock System Loaded (Check Once)")
