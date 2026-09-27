-- ==================================================
-- YOKUDO HUB | FEATURE | Anti Guard
-- ✅ Check DropHeldEgg.Enabled
-- ✅ True → Lock Camera → CFrame Safe Zone → Wait 1s → Return → Unlock Camera
-- ✅ False → Reset
-- ✅ Loop ដដែល
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================
local SAFE_ZONE = Vector3.new(550, 70, -431)
local CHECK_INTERVAL = 0.01
local WAIT_AT_SAFE = 1

-- ==================================================
-- STATE
-- ==================================================
local AntiGuardEnabled = false
local CheckThread = nil
local FastClickConnection = nil
local FastClickHeartbeat = nil
local FastClickCounter = 0
local LastState = false
local OriginalCFrame = nil

-- ✅ Camera Lock State
local CameraLockConnection = nil
local LockedCameraCFrame = nil

-- ==================================================
-- GET HUMANOID
-- ==================================================
local function GetHumanoid()
    local Char = Player.Character
    if not Char then return nil, nil end
    return Char:FindFirstChildOfClass("Humanoid"), Char:FindFirstChild("HumanoidRootPart")
end

-- ==================================================
-- GET DROP HELD EGG
-- ==================================================
local function GetDropHeldEgg()
    local PG = Player:FindFirstChild("PlayerGui")
    if not PG then return nil end
    return PG:FindFirstChild("DropHeldEgg", true)
end

-- ==================================================
-- CAMERA LOCK
-- ==================================================
local function LockCamera()
    local Camera = Workspace.CurrentCamera
    if not Camera then return end

    -- ✅ Save Camera CFrame
    LockedCameraCFrame = Camera.CFrame

    -- ✅ Lock Camera រាល់ Frame
    if CameraLockConnection then CameraLockConnection:Disconnect() end
    CameraLockConnection = RunService.RenderStepped:Connect(function()
        if not LockedCameraCFrame then return end
        local Cam = Workspace.CurrentCamera
        if Cam then
            Cam.CFrame = LockedCameraCFrame
            Cam.Focus = LockedCameraCFrame
        end
    end)

    print("[AntiGuard] 🔒 Camera Locked:", LockedCameraCFrame.Position)
end

local function UnlockCamera()
    if CameraLockConnection then
        CameraLockConnection:Disconnect()
        CameraLockConnection = nil
    end
    LockedCameraCFrame = nil
    print("[AntiGuard] 🔓 Camera Unlocked")
end

-- ==================================================
-- CLICK FAST
-- ==================================================
local function ApplyHoldDuration(prompt)
    if not prompt then return end
    pcall(function() prompt.HoldDuration = 0 end)
end

local function ScanAllPrompts()
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then ApplyHoldDuration(d) end
    end
    local PG = Player:FindFirstChild("PlayerGui")
    if PG then
        for _, d in ipairs(PG:GetDescendants()) do
            if d:IsA("ProximityPrompt") then ApplyHoldDuration(d) end
        end
    end
end

local function StartFastClick()
    ScanAllPrompts()
    if FastClickConnection then FastClickConnection:Disconnect() end
    FastClickConnection = ProximityPromptService.PromptShown:Connect(function(prompt)
        if not AntiGuardEnabled then return end
        ApplyHoldDuration(prompt)
    end)
    if FastClickHeartbeat then FastClickHeartbeat:Disconnect() end
    FastClickCounter = 0
    FastClickHeartbeat = RunService.Heartbeat:Connect(function()
        if not AntiGuardEnabled then return end
        FastClickCounter = FastClickCounter + 1
        if FastClickCounter >= 30 then
            FastClickCounter = 0
            ScanAllPrompts()
        end
    end)
    print("[AntiGuard] Fast Click: ON")
end

local function StopFastClick()
    if FastClickConnection then FastClickConnection:Disconnect() FastClickConnection = nil end
    if FastClickHeartbeat then FastClickHeartbeat:Disconnect() FastClickHeartbeat = nil end
    print("[AntiGuard] Fast Click: OFF")
end

-- ==================================================
-- CFrame + Return (Anti Guard Protection + Camera Lock)
-- ==================================================
local function CFrameAndReturn()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root then
        print("[AntiGuard] ⚠️ Humanoid or Root not found!")
        return
    end

    OriginalCFrame = Root.CFrame
    print("[AntiGuard] 📍 Original Position:", OriginalCFrame.Position)

    -- ✅ Lock Camera
    LockCamera()

    -- ✅ CFrame ទៅ Safe Zone
    pcall(function()
        Root.CFrame = CFrame.new(SAFE_ZONE)
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end)
    print("[AntiGuard] ✅ CFrame → Safe Zone:", SAFE_ZONE)

    -- ✅ Wait 1s
    task.wait(WAIT_AT_SAFE)

    -- ✅ Return មក Position ដើម
    if OriginalCFrame then
        pcall(function()
            Root.CFrame = OriginalCFrame
            Root.AssemblyLinearVelocity = Vector3.zero
            Root.AssemblyAngularVelocity = Vector3.zero
        end)
        print("[AntiGuard] ✅ Return → Original Position")
    end

    -- ✅ Unlock Camera
    UnlockCamera()
end

-- ==================================================
-- CHECK LOOP (True/False Loop)
-- ==================================================
local function CheckLoop()
    print("[AntiGuard] CheckLoop Started")
    local DropHeldEgg = nil

    while AntiGuardEnabled do
        task.wait(CHECK_INTERVAL)
        if not AntiGuardEnabled then break end

        if not DropHeldEgg or not DropHeldEgg.Parent then
            DropHeldEgg = GetDropHeldEgg()
        end

        if DropHeldEgg then
            local CurrentState = DropHeldEgg.Enabled == true

            -- ✅ True → CFrame Safe Zone + Camera Lock
            if CurrentState and not LastState then
                print("[AntiGuard] ✅ Egg Collect = TRUE → CFrame Safe Zone")
                LastState = true
                CFrameAndReturn()
            end

            -- ✅ False → Reset
            if not CurrentState and LastState then
                print("[AntiGuard] ❌ Egg Collect = FALSE → Reset")
                LastState = false
            end
        end
    end

    print("[AntiGuard] CheckLoop Stopped")
end

-- ==================================================
-- ENABLE
-- ==================================================
local function EnableAntiGuard()
    if AntiGuardEnabled then return end
    AntiGuardEnabled = true
    LastState = false

    StartFastClick()

    if CheckThread then
        pcall(function() task.cancel(CheckThread) end)
        CheckThread = nil
    end
    CheckThread = task.spawn(CheckLoop)

    print("[AntiGuard] ON")
end

-- ==================================================
-- DISABLE
-- ==================================================
local function DisableAntiGuard()
    if not AntiGuardEnabled then return end
    AntiGuardEnabled = false
    LastState = false

    if CheckThread then
        pcall(function() task.cancel(CheckThread) end)
        CheckThread = nil
    end

    StopFastClick()
    UnlockCamera()

    print("[AntiGuard] OFF")
end

-- ==================================================
-- TOGGLE
-- ==================================================
local function ToggleAntiGuard()
    if AntiGuardEnabled then DisableAntiGuard() else EnableAntiGuard() end
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_AntiGuard = {
    Enable = EnableAntiGuard,
    Disable = DisableAntiGuard,
    Toggle = ToggleAntiGuard,
    IsEnabled = function() return AntiGuardEnabled end,
    SAFE_ZONE = SAFE_ZONE,
    WAIT_AT_SAFE = WAIT_AT_SAFE,
    LockCamera = LockCamera,
    UnlockCamera = UnlockCamera,
}

-- ==================================================
-- REGISTER WITH CHARACTER SYSTEM
-- ==================================================
if _G.YOKUDO_CharacterSystem then
    _G.YOKUDO_CharacterSystem:RegisterFeature({
        Name = "AntiGuard",
        Enable = EnableAntiGuard,
        Disable = DisableAntiGuard,
        IsEnabled = function() return AntiGuardEnabled end,
        OnCharacterAdded = function(Char, Hum, Root)
            if AntiGuardEnabled then
                task.wait(1)
                EnableAntiGuard()
            end
        end
    })
end

print("✅ AntiGuard Feature Loaded (With Camera Lock)")
print("   Safe Zone:", SAFE_ZONE)
print("   Wait:", WAIT_AT_SAFE .. "s")
print("   Camera: Lock → CFrame → Return → Unlock")
