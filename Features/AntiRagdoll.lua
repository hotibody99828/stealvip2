--==================================================
-- YOKUDO HUB | FEATURE | Anti Ragdoll (Guard + Boss Only)
-- Prevent Ragdoll Only When Guard/Boss Attack
-- Player Can Walk, Run, Jump Normally
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

--==================================================
-- SETTINGS
--==================================================

local CHECK_INTERVAL = 0.05        -- Check រាល់ 0.05 វិនាទី
local RAGDOLL_TIMEOUT = 1.5        -- Force Up រយៈពេល 1.5 វិនាទី

--==================================================
-- STATE
--==================================================

local AntiRagdollEnabled = false
local HeartbeatConnection = nil
local RagdollThread = nil
local IsBeingAttacked = false

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

    -- ✅ Only Force Up if currently Physics/Ragdoll/FallingDown
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
-- DETECT GUARD / BOSS ATTACK
--==================================================

local function IsGuardOrBossNearby()
    local Hum, Root = GetHumanoid()
    if not Root then return false end

    -- ✅ Check Guard Areas
    local GuardAreas = workspace:FindFirstChild("__OBJECTS")
    if not GuardAreas then return false end
    GuardAreas = GuardAreas:FindFirstChild("Areas")
    if not GuardAreas then return false end
    GuardAreas = GuardAreas:FindFirstChild("GuardAreas")
    if not GuardAreas then return false end

    -- ✅ Check Forest Guard
    local Forest = GuardAreas:FindFirstChild("Forest")
    if Forest then
        local Guard = Forest:FindFirstChild("Guard")
        if Guard then
            local GuardPos = GetPosition(Guard)
            if GuardPos then
                local Dist = (GuardPos - Root.Position).Magnitude
                if Dist < 30 then  -- ✅ Guard នៅជិត < 30 studs
                    return true
                end
            end
        end
    end

    -- ✅ Check Boss (Scan workspace for Boss)
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name:find("Boss") or obj.Name:find("Monster") then
            local BossPos = GetPosition(obj)
            if BossPos then
                local Dist = (BossPos - Root.Position).Magnitude
                if Dist < 30 then
                    return true
                end
            end
        end
    end

    return false
end

--==================================================
-- GET POSITION
--==================================================

function GetPosition(Object)
    if not Object then return nil end
    if Object:IsA("Model") then
        if Object.PrimaryPart then return Object.PrimaryPart.Position end
        local Part = Object:FindFirstChildWhichIsA("BasePart")
        if Part then return Part.Position end
        for _, Desc in ipairs(Object:GetDescendants()) do
            if Desc:IsA("BasePart") then return Desc.Position end
        end
    elseif Object:IsA("BasePart") then
        return Object.Position
    end
    return nil
end

--==================================================
-- ENABLE / DISABLE
--==================================================

local function EnableAntiRagdoll()
    if AntiRagdollEnabled then return end
    AntiRagdollEnabled = true

    -- ✅ Check រាល់ 0.05 វិនាទី
    HeartbeatConnection = RunService.Heartbeat:Connect(function()
        if not AntiRagdollEnabled then return end

        -- ✅ Only Force Up if Guard/Boss nearby
        if IsGuardOrBossNearby() then
            ForceUp()
            CleanupRagdollConstraints()
        end
    end)

    print("[YOKUDO] Anti Ragdoll: ON (Guard + Boss Only)")
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
    CleanupRagdollConstraints = CleanupRagdollConstraints,
    IsGuardOrBossNearby = IsGuardOrBossNearby
}

print("✅ AntiRagdoll Feature Loaded (Guard + Boss Only)")
