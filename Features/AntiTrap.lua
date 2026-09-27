-- ==================================================
-- YOKUDO HUB | FEATURE | Anti Trap (REVONE)
-- ✅ Remove ALL Children in workspace.Transient
-- ✅ Remove Children in workspace.__DEBRIS (Backup)
-- ✅ Loop រាល់ 0.5s
-- ==================================================

local AntiTrapEnabled = false
local RemoveThread = nil

-- ==================================================
-- REMOVE TRANSIENT CHILDREN
-- ==================================================
local function RemoveTransientChildren()
    local Transient = workspace:FindFirstChild("Transient")
    if not Transient then return 0 end

    local Count = 0
    for _, child in ipairs(Transient:GetChildren()) do
        pcall(function()
            child:Destroy()
            Count = Count + 1
        end)
    end

    return Count
end

-- ==================================================
-- REMOVE DEBRIS CHILDREN (BACKUP)
-- ==================================================
local function RemoveDebrisChildren()
    local Debris = workspace:FindFirstChild("__DEBRIS")
    if not Debris then return 0 end

    local Count = 0
    for _, child in ipairs(Debris:GetChildren()) do
        pcall(function()
            child:Destroy()
            Count = Count + 1
        end)
    end

    return Count
end

-- ==================================================
-- REMOVE ALL (TRANSIENT + DEBRIS)
-- ==================================================
local function RemoveAll()
    local TransientCount = RemoveTransientChildren()
    local DebrisCount = RemoveDebrisChildren()

    return TransientCount, DebrisCount
end

-- ==================================================
-- ENABLE
-- ==================================================
local function EnableAntiTrap()
    if AntiTrapEnabled then return end
    AntiTrapEnabled = true

    -- ✅ លុបភ្លាមម្តង
    RemoveAll()

    -- ✅ Loop រាល់ 0.5s
    if RemoveThread then
        pcall(function() task.cancel(RemoveThread) end)
        RemoveThread = nil
    end

    RemoveThread = task.spawn(function()
        while AntiTrapEnabled do
            task.wait(0.5)
            if AntiTrapEnabled then
                local T, D = RemoveAll()
                if T > 0 or D > 0 then
                    print("[AntiTrap] Removed Transient:", T, "| Debris:", D)
                end
            end
        end
    end)

    print("[AntiTrap] ON")
end

-- ==================================================
-- DISABLE
-- ==================================================
local function DisableAntiTrap()
    if not AntiTrapEnabled then return end
    AntiTrapEnabled = false

    if RemoveThread then
        pcall(function() task.cancel(RemoveThread) end)
        RemoveThread = nil
    end

    print("[AntiTrap] OFF")
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
    RemoveAll = RemoveAll,
    RemoveTransientChildren = RemoveTransientChildren,
    RemoveDebrisChildren = RemoveDebrisChildren,
}

print("✅ AntiTrap Feature Loaded (REVONE)")
