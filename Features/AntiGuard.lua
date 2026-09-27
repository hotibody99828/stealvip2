-- ==================================================
-- YOKUDO HUB | FEATURE | Anti Guard (Black Screen)
-- ✅ Check DropHeldEgg.Enabled
-- ✅ True → Black Screen + CFrame Safe Zone → Wait 1s → Return + Unblack
-- ✅ False → Reset
-- ✅ Loop ដដែល
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

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
local BlackScreenGui = nil

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
-- BLACK SCREEN
-- ==================================================
local function ShowBlackScreen()
    if BlackScreenGui then
        BlackScreenGui.Enabled = true
        return
    end

    BlackScreenGui = Instance.new("ScreenGui")
    BlackScreenGui.Name = "YokudoBlackScreen"
    BlackScreenGui.ResetOnSpawn = false
    BlackScreenGui.IgnoreGuiInset = true
    BlackScreenGui.DisplayOrder = 99999
    BlackScreenGui.Parent = CoreGui

    local Frame = Instance.new("Frame")
    Frame.Name = "BlackFrame"
    Frame.Size = UDim2.new(1, 0, 1, 0)
    Frame.Position = UDim2.new(0, 0, 0, 0)
    Frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Frame.BackgroundTransparency = 1
    Frame.BorderSizePixel = 0
    Frame.Parent = BlackScreenGui

    -- ✅ Fade In
    TweenService:Create(Frame, TweenInfo.new(0.2), {
        BackgroundTransparency = 0
    }):Play()

    print("[AntiGuard] Black Screen: ON")
end

local function HideBlackScreen()
    if not BlackScreenGui then return end

    local Frame = BlackScreenGui:FindFirstChild("BlackFrame")
    if Frame then
        local Tween = TweenService:Create(Frame, TweenInfo.new(0.2), {
            BackgroundTransparency = 1
        })
        Tween:Play()
        Tween.Completed:Connect(function()
            if BlackScreenGui then
                BlackScreenGui.Enabled = false
            end
        end)
    else
        BlackScreenGui.Enabled = false
    end

    print("[AntiGuard] Black Screen: OFF")
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
-- CFrame + Black Screen + Return
-- ==================================================
local function CFrameAndReturn()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root then
        print("[AntiGuard] ⚠️ Humanoid or Root not found!")
        return
    end

    -- ✅ Save Position ដើម
    OriginalCFrame = Root.CFrame
    print("[AntiGuard] 📍 Original Position:", OriginalCFrame.Position)

    -- ✅ Black Screen ភ្លាម
    ShowBlackScreen()

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

    -- ✅ Unblack Screen
    task.wait(0.1)
    HideBlackScreen()
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

            -- ✅ True → Black Screen + CFrame Safe Zone
            if CurrentState and not LastState then
                print("[AntiGuard] ✅ Egg Collect = TRUE → Black Screen + CFrame")
                LastState = true
                task.spawn(CFrameAndReturn)
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

    -- ✅ Hide Black Screen បើនៅមាន
    if BlackScreenGui then
        BlackScreenGui.Enabled = false
        BlackScreenGui:Destroy()
        BlackScreenGui = nil
    end

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
    ShowBlackScreen = ShowBlackScreen,
    HideBlackScreen = HideBlackScreen,
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

print("✅ AntiGuard Feature Loaded (Black Screen)")
print("   True → Black Screen + CFrame Safe Zone → Wait 1s → Return + Unblack")
print("   False → Reset → Loop")
