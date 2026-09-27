-- ==================================================
-- YOKUDO HUB | FEATURE | Anti Trap (UPDATED)
-- ✅ Remove workspace.Transient.PlayerTrap Children
-- ✅ Remove workspace.Transient:GetChildren()[2]
-- ✅ Remove workspace.Transient:GetChildren()[3]
-- ✅ Loop រាល់ 1s
-- ==================================================

local Workspace = game:GetService("Workspace")

-- ==================================================
-- SETTINGS
-- ==================================================
local CHECK_INTERVAL = 1  -- ✅ លុបរាល់ 1 វិនាទី

-- Transient Children Indexes to Remove
local TRANSIENT_INDEXES = { 2, 3 }

-- ==================================================
-- STATE
-- ==================================================
local AntiTrapEnabled = false
local LoopThread = nil

-- ==================================================
-- REMOVE TRANSIENT TRAPS
-- ==================================================
local function RemoveTransientTraps()
    local Transient = Workspace:FindFirstChild("Transient")
    if not Transient then return end

    -- ✅ Remove PlayerTrap Children
    local PlayerTrap = Transient:FindFirstChild("PlayerTrap")
    if PlayerTrap then
        for _, child in ipairs(PlayerTrap:GetChildren()) do
            pcall(function()
                child:Destroy()
            end)
        end
    end

    -- ✅ Remove Transient Children by Index
    for _, index in ipairs(TRANSIENT_INDEXES) do
        local child = Transient:GetChildren()[index]
        if child then
            pcall(function()
                child:Destroy()
            end)
        end
    end
end

-- ==================================================
-- MAIN LOOP
-- ==================================================
local function MainLoop()
    while AntiTrapEnabled do
        task.wait(CHECK_INTERVAL)
        if not AntiTrapEnabled then break end

        RemoveTransientTraps()
    end
end

-- ==================================================
-- ENABLE
-- ==================================================
local function EnableAntiTrap()
    if AntiTrapEnabled then return end
    AntiTrapEnabled = true

    -- ✅ លុបភ្លាមម្តង
    RemoveTransientTraps()

    -- ✅ Loop រាល់ 1s
    if LoopThread then
        pcall(function() task.cancel(LoopThread) end)
        LoopThread = nil
    end
    LoopThread = task.spawn(MainLoop)

    print("[YOKUDO] Anti Trap: ON (1s Loop)")
end

-- ==================================================
-- DISABLE
-- ==================================================
local function DisableAntiTrap()
    if not AntiTrapEnabled then return end
    AntiTrapEnabled = false

    if LoopThread then
        pcall(function() task.cancel(LoopThread) end)
        LoopThread = nil
    end

    print("[YOKUDO] Anti Trap: OFF")
end

-- ==================================================
-- TOGGLE
-- ==================================================
local function ToggleAntiTrap()
    if AntiTrapEnabled then
        DisableAntiTrap()
    else
        EnableAntiTrap()
    end
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_AntiTrap = {
    Toggle = ToggleAntiTrap,
    Enable = EnableAntiTrap,
    Disable = DisableAntiTrap,
    IsEnabled = function() return AntiTrapEnabled end,
    RemoveTransientTraps = RemoveTransientTraps,
}

print("✅ AntiTrap Feature Loaded (Transient + PlayerTrap + 1s Loop)")
