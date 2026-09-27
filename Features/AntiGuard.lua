-- ==================================================
-- YOKUDO HUB | FEATURE | Anti Guard
-- ✅ Anti Ragdoll + Anti Knockback + God Mode
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

local AntiGuardEnabled = false
local AntiGuardConnection = nil

-- ==================================================
-- GET HUMANOID
-- ==================================================
local function GetHumanoid()
    local Char = Player.Character
    if not Char then return nil, nil end
    return Char:FindFirstChildOfClass("Humanoid"), Char:FindFirstChild("HumanoidRootPart")
end

-- ==================================================
-- ENABLE
-- ==================================================
local function EnableAntiGuard()
    if AntiGuardEnabled then return end
    AntiGuardEnabled = true

    if AntiGuardConnection then AntiGuardConnection:Disconnect() end
    AntiGuardConnection = RunService.Heartbeat:Connect(function()
        if not AntiGuardEnabled then return end
        local Hum, Root = GetHumanoid()
        if not Hum or not Root then return end

        pcall(function()
            -- ✅ បិទ Ragdoll States
            Hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            Hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
            Hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            Hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

            -- ✅ Reset Health
            if Hum.Health < Hum.MaxHealth then
                Hum.Health = Hum.MaxHealth
            end

            -- ✅ Reset Velocity
            Root.AssemblyLinearVelocity = Vector3.zero
            Root.AssemblyAngularVelocity = Vector3.zero

            -- ✅ Reset PlatformStand
            Hum.PlatformStand = false
            Hum.Sit = false

            -- ✅ Disable BreakJoints
            Hum.BreakJointsOnDeath = false
            Hum.RequiresNeck = false
        end)
    end)

    print("[AntiGuard] ON")
end

-- ==================================================
-- DISABLE
-- ==================================================
local function DisableAntiGuard()
    if not AntiGuardEnabled then return end
    AntiGuardEnabled = false

    if AntiGuardConnection then
        AntiGuardConnection:Disconnect()
        AntiGuardConnection = nil
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

print("✅ AntiGuard Feature Loaded")
