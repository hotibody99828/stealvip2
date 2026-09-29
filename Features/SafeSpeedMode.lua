-- ==================================================
-- YOKUDO HUB | FEATURE | Safe Speed Mode
-- ✅ ON: Speed 265 | OFF: Player Speed (Save ដើម)
-- ✅ Register ជាមួយ CharacterSystem
-- ==================================================

local Players = game:GetService("Players")

local Player = Players.LocalPlayer

-- ==================================================
-- CONFIG
-- ==================================================
local SAFE_SPEED = 250

-- ==================================================
-- STATE
-- ==================================================
local SafeSpeedEnabled = false
local SavedWalkSpeed = nil

-- ==================================================
-- GET HUMANOID
-- ==================================================
local function GetHumanoid()
    local Char = Player.Character
    if not Char then return nil end
    return Char:FindFirstChildOfClass("Humanoid")
end

-- ==================================================
-- SAVE ORIGINAL SPEED
-- ==================================================
local function SaveOriginalSpeed()
    local Hum = GetHumanoid()
    if not Hum then return end
    if SavedWalkSpeed == nil then
        SavedWalkSpeed = Hum.WalkSpeed
        print("[SafeSpeedMode] Saved WalkSpeed ដើម:", SavedWalkSpeed)
    end
end

-- ==================================================
-- APPLY SPEED
-- ==================================================
local function ApplySpeed()
    local Hum = GetHumanoid()
    if not Hum then return end

    if SafeSpeedEnabled then
        Hum.WalkSpeed = SAFE_SPEED
    else
        Hum.WalkSpeed = SavedWalkSpeed or Hum.WalkSpeed
    end
end

-- ==================================================
-- ENABLE
-- ==================================================
local function EnableSafeSpeed()
    if SafeSpeedEnabled then return end

    SaveOriginalSpeed()
    SafeSpeedEnabled = true

    ApplySpeed()
    print("[SafeSpeedMode] ON | Speed:", SAFE_SPEED)
end

-- ==================================================
-- DISABLE
-- ==================================================
local function DisableSafeSpeed()
    if not SafeSpeedEnabled then return end
    SafeSpeedEnabled = false

    ApplySpeed()
    print("[SafeSpeedMode] OFF | Speed:", SavedWalkSpeed)
end

-- ==================================================
-- TOGGLE
-- ==================================================
local function ToggleSafeSpeed()
    if SafeSpeedEnabled then
        DisableSafeSpeed()
    else
        EnableSafeSpeed()
    end
end

-- ==================================================
-- GET CURRENT SPEED
-- ==================================================
local function GetCurrentSpeed()
    if SafeSpeedEnabled then
        return SAFE_SPEED
    else
        return SavedWalkSpeed
    end
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_SafeSpeedMode = {
    Enable = EnableSafeSpeed,
    Disable = DisableSafeSpeed,
    Toggle = ToggleSafeSpeed,
    IsEnabled = function() return SafeSpeedEnabled end,
    GetCurrentSpeed = GetCurrentSpeed,
    GetSavedSpeed = function() return SavedWalkSpeed end,
    SetSavedSpeed = function(Value)
        SavedWalkSpeed = Value
        print("[SafeSpeedMode] Saved WalkSpeed Updated:", Value)
    end,
    SAFE_SPEED = SAFE_SPEED,
}

-- ==================================================
-- REGISTER WITH CHARACTER SYSTEM
-- ==================================================
if _G.YOKUDO_CharacterSystem then
    _G.YOKUDO_CharacterSystem:RegisterFeature({
        Name = "SafeSpeedMode",
        Enable = EnableSafeSpeed,
        Disable = DisableSafeSpeed,
        IsEnabled = function() return SafeSpeedEnabled end,
        OnCharacterAdded = function(Char, Hum, Root)
            if SafeSpeedEnabled then
                task.wait(0.5)
                ApplySpeed()
            end
        end
    })
end

print("✅ SafeSpeedMode Feature Loaded (Safe Speed: " .. SAFE_SPEED .. ")")
