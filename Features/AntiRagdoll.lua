--==================================================
-- YOKUDO HUB | FEATURE | Anti Ragdoll
-- Prevent Character from Ragdoll / Knockback
-- Remove Ragdoll Constraints + Force Up
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

--==================================================
-- SETTINGS
--==================================================

local CHECK_INTERVAL = 0.1        -- Check រាល់ 0.1 វិនាទី
local FORCE_UP_INTERVAL = 0.5     -- Force Up រាល់ 0.5 វិនាទី

--==================================================
-- STATE
--==================================================

local AntiRagdollEnabled = false
local HeartbeatConnection = nil
local ForceUpThread = nil

--==================================================
-- GET HUMANOID
--==================================================

local function GetHumanoid()
    local Char = Player.Character
    if not Char then return nil, nil end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    local Root = Char:FindFirstChild("HumanoidRootPart")
    return Hum, Root
end

--==================================================
-- FORCE UP (Anti Ragdoll State)
--==================================================

local function ForceUp()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return end

    pcall(function()
        -- ✅ Force GettingUp state if Physics
        if Hum:GetState() == Enum.HumanoidStateType.Physics then
            Hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end

        -- ✅ Disable Ragdoll States
        Hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        Hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        Hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        Hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

        -- ✅ Disable PlatformStand
        Hum.PlatformStand = false
        Hum.Sit = false

        -- ✅ Reset Velocity
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero

        -- ✅ Reset Collision
        Root.CanCollide = true

        -- ✅ Disable BreakJointsOnDeath
        Hum.BreakJointsOnDeath = false
        Hum.RequiresNeck = false
    end)
end

--==================================================
-- CLEANUP RAGDOLL CONSTRAINTS
--==================================================

local function CleanupRagdollConstraints()
    local Char = Player.Character
    if not Char then return end

    pcall(function()
        -- ✅ Remove Ragdoll Constraints
        for _, descendant in ipairs(Char:GetDescendants()) do
            if descendant.Name:find("RagdollConstraint") then
                descendant:Destroy()
            end
            if descendant.Name:find("RagdollAttachment") then
                descendant:Destroy()
            end
        end

        -- ✅ Re-enable Motor6D
        for _, descendant in ipairs(Char:GetDescendants()) do
            if descendant:IsA("Motor6D") then
                descendant.Enabled = true
            end
        end

        -- ✅ Remove BallSocketConstraint / HingeConstraint
        for _, descendant in ipairs(Char:GetDescendants()) do
            if descendant:IsA("BallSocketConstraint") then
                if descendant.Name:find("Ragdoll") then
                    descendant:Destroy()
                end
            end
            if descendant:IsA("HingeConstraint") then
                if descendant.Name:find("Ragdoll") then
                    descendant:Destroy()
                end
            end
        end
    end)
end

--==================================================
-- ENABLE / DISABLE
--==================================================

local function EnableAntiRagdoll()
    if AntiRagdollEnabled then return end
    AntiRagdollEnabled = true

    -- ✅ Loop រាល់ Heartbeat
    HeartbeatConnection = RunService.Heartbeat:Connect(function()
        if not AntiRagdollEnabled then return end
        ForceUp()
    end)

    -- ✅ Loop រាល់ 0.5 វិនាទី (Cleanup + Force Up)
    ForceUpThread = task.spawn(function()
        while AntiRagdollEnabled do
            task.wait(FORCE_UP_INTERVAL)
            if AntiRagdollEnabled then
                ForceUp()
                CleanupRagdollConstraints()
            end
        end
    end)

    print("[YOKUDO] Anti Ragdoll: ON")
end

local function DisableAntiRagdoll()
    if not AntiRagdollEnabled then return end
    AntiRagdollEnabled = false

    if HeartbeatConnection then
        HeartbeatConnection:Disconnect()
        HeartbeatConnection = nil
    end

    print("[YOKUDO] Anti Ragdoll: OFF")
end

local function ToggleAntiRagdoll()
    if AntiRagdollEnabled then
        DisableAntiRagdoll()
    else
        EnableAntiRagdoll()
    end
end

--==================================================
-- AUTO RE-APPLY ON CHARACTER ADDED
--==================================================

Player.CharacterAdded:Connect(function(Char)
    if AntiRagdollEnabled then
        task.wait(1)
        ForceUp()
        CleanupRagdollConstraints()
        print("[YOKUDO] Anti Ragdoll: Re-applied on Character")
    end
end)

--==================================================
-- EXPORT
--==================================================

_G.YOKUDO_AntiRagdoll = {
    Enable = EnableAntiRagdoll,
    Disable = DisableAntiRagdoll,
    Toggle = ToggleAntiRagdoll,
    IsEnabled = function() return AntiRagdollEnabled end,
    ForceUp = ForceUp,
    CleanupRagdollConstraints = CleanupRagdollConstraints
}

print("✅ AntiRagdoll Feature Loaded")
