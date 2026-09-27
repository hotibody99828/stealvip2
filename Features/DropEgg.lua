-- ==================================================
-- YOKUDO HUB | FEATURE | For Event Drop Egg
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

local DropEggEnabled = false
local DropEggConnection = nil

-- ==================================================
-- FIND REMOTE
-- ==================================================
local Remotes = nil
local DropEggRemote = nil

pcall(function()
    Remotes = require(ReplicatedStorage.Shared.Remotes)
    DropEggRemote = Remotes.EggWorld.AskFieldEggDrop
end)

-- ==================================================
-- ENABLE
-- ==================================================
local function EnableDropEgg()
    if DropEggEnabled then return end
    DropEggEnabled = true

    if DropEggConnection then DropEggConnection:Disconnect() end
    DropEggConnection = RunService.Heartbeat:Connect(function()
        if not DropEggEnabled then return end

        pcall(function()
            if DropEggRemote then
                DropEggRemote:FireServer({ Reason = "External" })
            end
        end)
    end)

    print("[DropEgg] ON")
end

-- ==================================================
-- DISABLE
-- ==================================================
local function DisableDropEgg()
    if not DropEggEnabled then return end
    DropEggEnabled = false

    if DropEggConnection then
        DropEggConnection:Disconnect()
        DropEggConnection = nil
    end

    print("[DropEgg] OFF")
end

-- ==================================================
-- TOGGLE
-- ==================================================
local function ToggleDropEgg()
    if DropEggEnabled then DisableDropEgg() else EnableDropEgg() end
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_DropEgg = {
    Enable = EnableDropEgg,
    Disable = DisableDropEgg,
    Toggle = ToggleDropEgg,
    IsEnabled = function() return DropEggEnabled end,
}

-- ==================================================
-- REGISTER WITH CHARACTER SYSTEM
-- ==================================================
if _G.YOKUDO_CharacterSystem then
    _G.YOKUDO_CharacterSystem:RegisterFeature({
        Name = "DropEgg",
        Enable = EnableDropEgg,
        Disable = DisableDropEgg,
        IsEnabled = function() return DropEggEnabled end,
    })
end

print("✅ DropEgg Feature Loaded")
