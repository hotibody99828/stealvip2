--==================================================
-- YOKUDO HUB | FEATURE | Anti AFK
-- Prevent AFK Kick/Hop using 3 Methods
-- ✅ GetHumanoid() ថ្មីរាល់ពេល → មិនត្រូវការ Re-Bind
--==================================================

local Players = game:GetService("Players")

local Player = Players.LocalPlayer

--==================================================
-- GET HUMANOID (ថ្មីរាល់ពេល)
--==================================================
local function GetHumanoid()
    local Char = Player.Character
    if not Char then return nil, nil end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    local Root = Char:FindFirstChild("HumanoidRootPart")
    return Hum, Root
end

--==================================================
-- SETTINGS
--==================================================
local MOUSE_INTERVAL_MIN = 45
local MOUSE_INTERVAL_MAX = 120
local CAMERA_INTERVAL_MIN = 60
local CAMERA_INTERVAL_MAX = 180
local ZOOM_INTERVAL_MIN = 90
local ZOOM_INTERVAL_MAX = 240

--==================================================
-- STATE
--==================================================
local AntiAFKEnabled = false
local MouseThread = nil
local CameraThread = nil
local ZoomThread = nil

--==================================================
-- METHODS
--==================================================
local function DoMouseMove()
    pcall(function()
        mousemoverel(math.random(-15, 15), math.random(-15, 15))
    end)
end

local function DoCameraRotation()
    pcall(function()
        local Camera = workspace.CurrentCamera
        if Camera then
            Camera.CFrame = Camera.CFrame * CFrame.Angles(
                math.rad(math.random(-2, 2)),
                math.rad(math.random(-3, 3)),
                0
            )
        end
    end)
end

local function DoCameraZoom()
    pcall(function()
        local Camera = workspace.CurrentCamera
        if Camera then
            local Original = Camera.FieldOfView
            Camera.FieldOfView = Original + math.random(-5, 5)
            task.wait(0.3)
            Camera.FieldOfView = Original
        end
    end)
end

--==================================================
-- ENABLE / DISABLE
--==================================================
local function EnableAntiAFK()
    if AntiAFKEnabled then return end
    AntiAFKEnabled = true

    MouseThread = task.spawn(function()
        while AntiAFKEnabled do
            task.wait(math.random(MOUSE_INTERVAL_MIN, MOUSE_INTERVAL_MAX))
            if not AntiAFKEnabled then break end
            DoMouseMove()
        end
    end)

    CameraThread = task.spawn(function()
        while AntiAFKEnabled do
            task.wait(math.random(CAMERA_INTERVAL_MIN, CAMERA_INTERVAL_MAX))
            if not AntiAFKEnabled then break end
            DoCameraRotation()
        end
    end)

    ZoomThread = task.spawn(function()
        while AntiAFKEnabled do
            task.wait(math.random(ZOOM_INTERVAL_MIN, ZOOM_INTERVAL_MAX))
            if not AntiAFKEnabled then break end
            DoCameraZoom()
        end
    end)

    print("[YOKUDO] Anti AFK: ON")
end

local function DisableAntiAFK()
    if not AntiAFKEnabled then return end
    AntiAFKEnabled = false

    if MouseThread then pcall(function() task.cancel(MouseThread) end) MouseThread = nil end
    if CameraThread then pcall(function() task.cancel(CameraThread) end) CameraThread = nil end
    if ZoomThread then pcall(function() task.cancel(ZoomThread) end) ZoomThread = nil end

    print("[YOKUDO] Anti AFK: OFF")
end

local function ToggleAntiAFK()
    if AntiAFKEnabled then DisableAntiAFK() else EnableAntiAFK() end
end

--==================================================
-- EXPORT
--==================================================
_G.YOKUDO_AntiAFK = {
    Enable = EnableAntiAFK,
    Disable = DisableAntiAFK,
    Toggle = ToggleAntiAFK,
    IsEnabled = function() return AntiAFKEnabled end,
    GetHumanoid = GetHumanoid
}

print("✅ AntiAFK Feature Loaded")
