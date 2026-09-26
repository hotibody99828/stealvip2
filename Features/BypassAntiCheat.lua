-- ==================================================
-- YOKUDO HUB | FEATURE | Bypass Anti Cheat
-- Humanoid Replace + Anti Death
-- ✅ Re-apply ពេល Player Died + CharacterAdded
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

-- ==================================================
-- STATE
-- ==================================================
local BypassEnabled = true
local ReapplyThread = nil
local DiedConnection = nil
local CharacterConnection = nil

-- ==================================================
-- MAIN FUNCTION
-- ==================================================
local function RunBypassAntiCheat()
    local Character = Player.Character
    if not Character then return end

    local OldHumanoid = Character:FindFirstChildOfClass("Humanoid")
    if not OldHumanoid then
        warn("[YOKUDO] Humanoid not found")
        return
    end

    -- ✅ Check បើ Humanoid ត្រូវ Replace រួចហើយ
    local ExistingBypass = OldHumanoid:GetAttribute("YokudoBypass")
    if ExistingBypass then
        print("[YOKUDO] Bypass already applied → Skip")
        return
    end

    print("========================================")
    print("[YOKUDO] START HUMANOID REPLACE")
    print("========================================")

    -- ANTI DEATH SETTINGS
    local GodMode = true

    -- SAVE JUMP PROPERTIES
    local SavedJumpProperties = {}

    local function SaveJumpProperty(Property)
        local Success, Value = pcall(function()
            return OldHumanoid[Property]
        end)
        if Success then
            SavedJumpProperties[Property] = Value
        end
    end

    SaveJumpProperty("JumpPower")
    SaveJumpProperty("JumpHeight")
    SaveJumpProperty("UseJumpPower")

    -- SAVE STATE MACHINE
    local SavedEvaluateStateMachine
    pcall(function()
        SavedEvaluateStateMachine = OldHumanoid.EvaluateStateMachine
    end)

    -- SAVE ALL HUMANOID STATE SETTINGS
    local SavedStates = {}
    local States = {
        Enum.HumanoidStateType.FallingDown,
        Enum.HumanoidStateType.Running,
        Enum.HumanoidStateType.RunningNoPhysics,
        Enum.HumanoidStateType.Climbing,
        Enum.HumanoidStateType.StrafingNoPhysics,
        Enum.HumanoidStateType.Ragdoll,
        Enum.HumanoidStateType.GettingUp,
        Enum.HumanoidStateType.Jumping,
        Enum.HumanoidStateType.Landed,
        Enum.HumanoidStateType.Flying,
        Enum.HumanoidStateType.Freefall,
        Enum.HumanoidStateType.Seated,
        Enum.HumanoidStateType.PlatformStanding,
        Enum.HumanoidStateType.Dead,
        Enum.HumanoidStateType.Swimming,
        Enum.HumanoidStateType.Physics,
    }

    for _, State in ipairs(States) do
        local Success, Enabled = pcall(function()
            return OldHumanoid:GetStateEnabled(State)
        end)
        if Success then
            SavedStates[State] = Enabled
        end
    end

    -- CLONE HUMANOID
    local NewHumanoid = OldHumanoid:Clone()
    if not NewHumanoid then
        warn("[YOKUDO] Failed to clone Humanoid")
        return
    end
    NewHumanoid.Name = OldHumanoid.Name

    -- ✅ Set Attribute ដើម្បីកុំឲ្យ Re-apply ច្រើនដង
    NewHumanoid:SetAttribute("YokudoBypass", true)

    -- MOVE HUMANOID CHILDREN
    for _, Child in ipairs(OldHumanoid:GetChildren()) do
        local ExistingCloneChild = NewHumanoid:FindFirstChild(Child.Name)
        if ExistingCloneChild then
            pcall(function()
                ExistingCloneChild:Destroy()
            end)
        end
        pcall(function()
            Child.Parent = NewHumanoid
        end)
    end

    -- REPLACEMENT ORDER
    OldHumanoid:Destroy()
    task.wait()
    NewHumanoid.Parent = Character
    task.wait()

    if not NewHumanoid.Parent then
        warn("[YOKUDO] New Humanoid was removed")
        return
    end

    print("[YOKUDO] New Humanoid:", NewHumanoid)

    -- UPDATE CHARACTER SYSTEM
    if _G.YOKUDO_CharacterSystem then
        _G.YOKUDO_CharacterSystem.CurrentHumanoid = NewHumanoid
        _G.YOKUDO_CharacterSystem.CurrentRoot = Character:FindFirstChild("HumanoidRootPart")
        print("[YOKUDO] CharacterSystem Updated with New Humanoid")
    end

    -- RESTORE JUMP PROPERTIES
    pcall(function()
        NewHumanoid.UseJumpPower = SavedJumpProperties.UseJumpPower
    end)
    pcall(function()
        NewHumanoid.JumpPower = SavedJumpProperties.JumpPower
    end)
    pcall(function()
        NewHumanoid.JumpHeight = SavedJumpProperties.JumpHeight
    end)

    -- RESTORE EVALUATE STATE MACHINE
    pcall(function()
        if SavedEvaluateStateMachine ~= nil then
            NewHumanoid.EvaluateStateMachine = SavedEvaluateStateMachine
        end
    end)

    -- RESTORE HUMANOID STATE SETTINGS
    for State, Enabled in pairs(SavedStates) do
        pcall(function()
            NewHumanoid:SetStateEnabled(State, Enabled)
        end)
    end

    -- ENSURE ANIMATOR
    local Animator = NewHumanoid:FindFirstChildOfClass("Animator")
    if not Animator then
        Animator = Instance.new("Animator")
        Animator.Parent = NewHumanoid
    end

    -- RESTART ANIMATE
    local Animate = Character:FindFirstChild("Animate")
    if Animate then
        pcall(function()
            Animate.Disabled = true
        end)
        task.wait()
        pcall(function()
            Animate.Disabled = false
        end)
    end

    task.wait(0.1)

    -- ANTI DEATH FUNCTIONS
    local function LockHealth()
        if GodMode and NewHumanoid and NewHumanoid.Parent then
            pcall(function()
                NewHumanoid.MaxHealth = math.huge
                NewHumanoid.Health = math.huge
            end)
        end
    end

    local function BlockDeathState()
        if not NewHumanoid or not NewHumanoid.Parent then return end
        pcall(function()
            NewHumanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        end)
        pcall(function()
            NewHumanoid.BreakJointsOnDeath = false
        end)
        pcall(function()
            NewHumanoid.RequiresNeck = false
        end)
    end

    local function BindAntiDeath(Humanoid)
        if not Humanoid then return end
        Humanoid.HealthChanged:Connect(function(Health)
            if GodMode and Humanoid and Humanoid.Parent then
                if Health < Humanoid.MaxHealth then
                    pcall(function()
                        Humanoid.Health = Humanoid.MaxHealth
                    end)
                end
            end
        end)
        Humanoid.Died:Connect(function()
            if GodMode and Humanoid and Humanoid.Parent then
                pcall(function()
                    Humanoid.Health = Humanoid.MaxHealth
                end)
            end
        end)
    end

    LockHealth()
    BlockDeathState()
    BindAntiDeath(NewHumanoid)

    -- GOD MODE LOOP
    task.spawn(function()
        while BypassEnabled do
            task.wait(0.1)
            if GodMode and NewHumanoid and NewHumanoid.Parent then
                pcall(function()
                    if NewHumanoid.Health < NewHumanoid.MaxHealth then
                        NewHumanoid.Health = NewHumanoid.MaxHealth
                    end
                    NewHumanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
                end)
            end
        end
    end)

    -- CONTROL MODULE REFRESH
    local function RefreshControls()
        local PlayerScripts = Player:FindFirstChild("PlayerScripts")
        if not PlayerScripts then return end
        local PlayerModule = PlayerScripts:FindFirstChild("PlayerModule")
        if not PlayerModule then return end
        local Success, Module = pcall(function()
            return require(PlayerModule)
        end)
        if not Success or not Module then return end
        local Controls
        pcall(function()
            Controls = Module:GetControls()
        end)
        if not Controls then return end
        pcall(function()
            Controls:OnCharacterAdded(Character)
        end)
        task.wait()
        pcall(function()
            Controls:UpdateActiveControlModuleEnabled()
        end)
    end

    RefreshControls()

    -- CAMERA
    pcall(function()
        local Camera = workspace.CurrentCamera
        if Camera then
            Camera.CameraSubject = NewHumanoid
        end
    end)

    -- ✅ RESTART FEATURES តាមរយៈ CHARACTER SYSTEM
    if _G.YOKUDO_CharacterSystem then
        task.spawn(function()
            task.wait(0.3)
            _G.YOKUDO_CharacterSystem:RestartAllFeatures()
        end)
    end

    print("")
    print("========================================")
    print("[YOKUDO] HUMANOID REPLACE + ANTI DEATH COMPLETE")
    print("========================================")
end

-- ==================================================
-- ✅ SETUP DIED LISTENER (ភ្ជាប់ឡើងវិញពេល Player ស្លាប់)
-- ==================================================
local function SetupDiedListener(Humanoid)
    if not Humanoid then return end

    if DiedConnection then
        DiedConnection:Disconnect()
        DiedConnection = nil
    end

    DiedConnection = Humanoid.Died:Connect(function()
        print("[YOKUDO] ⚠️ Player Died → Re-apply Bypass")

        -- ✅ រង់ចាំ 0.5s ឲ្យ Character ថ្មី Load
        task.wait(0.5)

        -- ✅ Re-apply Bypass
        task.spawn(function()
            RunBypassAntiCheat()
        end)
    end)

    print("[YOKUDO] Died Listener Setup")
end

-- ==================================================
-- ✅ SETUP CHARACTER ADDED LISTENER
-- ==================================================
local function SetupCharacterListener()
    if CharacterConnection then
        CharacterConnection:Disconnect()
        CharacterConnection = nil
    end

    CharacterConnection = Player.CharacterAdded:Connect(function(Character)
        print("[YOKUDO] Character Added → Re-apply Bypass")

        task.wait(1)

        -- ✅ Setup Died Listener សម្រាប់ Humanoid ថ្មី
        local Hum = Character:FindFirstChildOfClass("Humanoid")
        if Hum then
            SetupDiedListener(Hum)
        end

        -- ✅ Re-apply Bypass
        RunBypassAntiCheat()
    end)
end

-- ==================================================
-- ✅ SETUP DEATH LISTENER (Player Died)
-- ==================================================
local function SetupHumanoidDiedCheck()
    task.spawn(function()
        while BypassEnabled do
            task.wait(1)

            local Char = Player.Character
            if Char then
                local Hum = Char:FindFirstChildOfClass("Humanoid")
                if Hum then
                    -- ✅ Check បើមិនទាន់ Setup Died Listener
                    if not DiedConnection or not DiedConnection.Connected then
                        SetupDiedListener(Hum)
                    end
                end
            end
        end
    end)
end

-- ==================================================
-- RUN IMMEDIATELY
-- ==================================================
task.spawn(function()
    task.wait(2)
    RunBypassAntiCheat()

    -- ✅ Setup Listeners
    SetupCharacterListener()
    SetupHumanoidDiedCheck()

    -- ✅ Setup Died Listener សម្រាប់ Humanoid បច្ចុប្បន្ន
    local Char = Player.Character
    if Char then
        local Hum = Char:FindFirstChildOfClass("Humanoid")
        if Hum then
            SetupDiedListener(Hum)
        end
    end
end)

print("✅ BypassAntiCheat Feature Loaded (Died Re-apply)")
