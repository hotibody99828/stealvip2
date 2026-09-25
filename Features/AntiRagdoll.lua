--==================================================
-- YOKUDO HUB | FEATURE | Anti Ragdoll
-- Prevent Character from Ragdoll / Knockback
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

--==================================================
-- SETTINGS
--==================================================

local CHECK_INTERVAL = 0.1

--==================================================
-- STATE
--==================================================

local AntiRagdollEnabled = false
local HeartbeatConnection = nil
local CleanupThread = nil
local LastForceUp = 0

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
-- FORCE UP (Only if Ragdoll/Physics)
--==================================================

local function ForceUp()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return end

    -- ✅ Only Force Up if currently Physics/Ragdoll
    local CurrentState = Hum:GetState()
    if CurrentState ~= Enum.HumanoidStateType.Physics
       and CurrentState ~= Enum.HumanoidStateType.Ragdoll
       and CurrentState ~= Enum.HumanoidStateType.FallingDown then
        return
    end

    pcall(function()
        -- ✅ Force GettingUp
        Hum:ChangeState(Enum.HumanoidStateType.GettingUp)

        -- ✅ Reset Velocity
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero

        -- ✅ Reset Collision
        Root.CanCollide = true

        -- ✅ Disable BreakJointsOnDeath
        Hum.BreakJointsOnDeath = false
        Hum.RequiresNeck = false
    end)

    print("[YOKUDO] Anti Ragdoll: Force Up")
end

--==================================================
-- CLEANUP RAGDOLL CONSTRAINTS
--==================================================

local function CleanupRagdollConstraints()
    local Char = Player.Character
    if not Char then return end

    pcall(function()
        for _, descendant in ipairs(Char:GetDescendants()) do
            if descendant.Name:find("RagdollConstraint") then
                descendant:Destroy()
            end
            if descendant.Name:find("RagdollAttachment") then
                descendant:Destroy()
            end
        end

        for _, descendant in ipairs(Char:GetDescendants()) do
            if descendant:IsA("Motor6D") then
                descendant.Enabled = true
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

    -- ✅ Check រាល់ Heartbeat (មិន ForceUp ជាប់ៗ)
    HeartbeatConnection = RunService.Heartbeat:Connect(function()
        if not AntiRagdollEnabled then return end
        ForceUp()
    end)

    -- ✅ Cleanup រាល់ 0.5 វិនាទី
    CleanupThread = task.spawn(function()
        while AntiRagdollEnabled do
            task.wait(0.5)
            if AntiRagdollEnabled then
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
        CleanupRagdollConstraints()
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
