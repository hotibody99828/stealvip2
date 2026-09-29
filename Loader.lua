--==================================================
-- YOKUDO HUB - CONFIG SYSTEM
-- Save/Load: SelectedMethod + TeleportSpeed + AttackDroneEnabled + SafeSpeedMode
-- Folder: YOKUDO-SAE
-- File: yokudo.json
--==================================================

local HttpService = game:GetService("HttpService")

local CONFIG_FOLDER = "YOKUDO-SAE"
local CONFIG_FILE = CONFIG_FOLDER .. "/yokudo.json"

--==================================================
-- DEFAULT CONFIG
--==================================================
local DefaultConfig = {
    AttackDroneEnabled = false,
    SafeSpeedMode = false,     -- ✅ Safe Speed Mode
}

--==================================================
-- FILE HELPERS
--==================================================
local function EnsureFolder()
    pcall(function()
        if not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
    end)
end

local function FileExists(Path)
    local Exists = false
    pcall(function()
        Exists = isfile(Path)
    end)
    return Exists
end

--==================================================
-- LOAD CONFIG
--==================================================
local function LoadConfig()
    EnsureFolder()

    local Config = table.clone(DefaultConfig)

    if not FileExists(CONFIG_FILE) then
        print("[YOKUDO] Config not found. Using default.")
        return Config
    end

    local Success, RawData = pcall(function()
        return readfile(CONFIG_FILE)
    end)

    if not Success or not RawData or RawData == "" then
        print("[YOKUDO] Failed to read config. Using default.")
        return Config
    end

    local DecodeSuccess, DecodedData = pcall(function()
        return HttpService:JSONDecode(RawData)
    end)

    if not DecodeSuccess or type(DecodedData) ~= "table" then
        print("[YOKUDO] Failed to decode config. Using default.")
        return Config
    end

    if type(DecodedData.AttackDroneEnabled) == "boolean" then
        Config.AttackDroneEnabled = DecodedData.AttackDroneEnabled
    end

    if type(DecodedData.SafeSpeedMode) == "boolean" then
        Config.SafeSpeedMode = DecodedData.SafeSpeedMode
    end

    print("[YOKUDO] Config Loaded | Drone: " .. tostring(Config.AttackDroneEnabled) .. " | SafeSpeed: " .. tostring(Config.SafeSpeedMode))

    return Config
end

--==================================================
-- SAVE CONFIG
--==================================================
local function SaveConfig(Config)
    EnsureFolder()

    local DataToSave = {
        AttackDroneEnabled = Config.AttackDroneEnabled or DefaultConfig.AttackDroneEnabled,
        SafeSpeedMode = Config.SafeSpeedMode or DefaultConfig.SafeSpeedMode,
    }

    local EncodeSuccess, EncodedData = pcall(function()
        return HttpService:JSONEncode(DataToSave)
    end)

    if not EncodeSuccess then
        warn("[YOKUDO] Failed to encode config")
        return false
    end

    local WriteSuccess = pcall(function()
        writefile(CONFIG_FILE, EncodedData)
    end)

    if WriteSuccess then
        print("[YOKUDO] Config Saved | Drone: " .. tostring(DataToSave.AttackDroneEnabled) .. " | SafeSpeed: " .. tostring(DataToSave.SafeSpeedMode))
        return true
    else
        warn("[YOKUDO] Failed to write config")
        return false
    end
end

--==================================================
-- APPLY CONFIG (TO _G)
--==================================================
local function ApplyConfig(Config)
    _G.YOKUDO_AttackDroneEnabled = Config.AttackDroneEnabled
    _G.YOKUDO_SafeSpeedMode = Config.SafeSpeedMode
end

--==================================================
-- INITIAL LOAD
--==================================================
local LoadedConfig = LoadConfig()
ApplyConfig(LoadedConfig)

--==================================================
-- EXPORT
--==================================================
_G.YOKUDO_ConfigSystem = {
    Folder = CONFIG_FOLDER,
    File = CONFIG_FILE,
    Default = DefaultConfig,

    Load = function()
        local Config = LoadConfig()
        ApplyConfig(Config)

        task.spawn(function()
            task.wait(0.5)

            -- ✅ Auto Enable Attack Drone
            if Config.AttackDroneEnabled == true then
                if _G.YOKUDO_ManagerDrone then
                    print("[YOKUDO] Auto Enable Attack Drone from Config")
                    pcall(function()
                        _G.YOKUDO_ManagerDrone.Enable()
                    end)
                end
            end

            task.wait(0.5)

            -- ✅ Auto Enable Safe Speed Mode
            if Config.SafeSpeedMode == true then
                if _G.YOKUDO_SafeSpeedMode then
                    print("[YOKUDO] Auto Enable Safe Speed Mode from Config")
                    pcall(function()
                        _G.YOKUDO_SafeSpeedMode.Enable()
                    end)
                end
            end

            task.wait(0.5)

            -- ✅ Update Event Tab UI
            if _G.YOKUDO_RefreshEventUI then
                _G.YOKUDO_RefreshEventUI()
            end

            -- ✅ Update Setting Tab UI
            if _G.YOKUDO_RefreshSettingUI then
                _G.YOKUDO_RefreshSettingUI()
            end
        end)

        return Config
    end,

    Save = function()
        local Config = {
            AttackDroneEnabled = _G.YOKUDO_AttackDroneEnabled or DefaultConfig.AttackDroneEnabled,
            SafeSpeedMode = _G.YOKUDO_SafeSpeedMode or DefaultConfig.SafeSpeedMode,
        }
        return SaveConfig(Config)
    end,

    Get = function()
        return {
            AttackDroneEnabled = _G.YOKUDO_AttackDroneEnabled or DefaultConfig.AttackDroneEnabled,
            SafeSpeedMode = _G.YOKUDO_SafeSpeedMode or DefaultConfig.SafeSpeedMode,
        }
    end,

    Reset = function()
        ApplyConfig(DefaultConfig)
        return SaveConfig(DefaultConfig)
    end
}

print("✅ ConfigSystem Loaded (SafeSpeedMode)")
