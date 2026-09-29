--==================================================
-- YOKUDO HUB - CONFIG SYSTEM
-- ✅ ដក AttackDroneEnabled + SafeSpeedMode ចេញ
-- Folder: YOKUDO-SAE
-- File: yokudo.json
--==================================================

local HttpService = game:GetService("HttpService")

local CONFIG_FOLDER = "YOKUDO-SAE"
local CONFIG_FILE = CONFIG_FOLDER .. "/yokudo.json"

--==================================================
-- DEFAULT CONFIG (ទទេ)
--==================================================
local DefaultConfig = {
    -- ✅ ទទេ — គ្មាន Save
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

    -- ✅ គ្មាន Load អ្វីទេ

    print("[YOKUDO] Config Loaded (Empty)")

    return Config
end

--==================================================
-- SAVE CONFIG
--==================================================
local function SaveConfig(Config)
    EnsureFolder()

    local DataToSave = {
        -- ✅ ទទេ — គ្មាន Save
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
        print("[YOKUDO] Config Saved (Empty)")
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
    -- ✅ គ្មាន Apply អ្វីទេ
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
        local Config = {}
        return SaveConfig(Config)
    end,

    Get = function()
        return {}
    end,

    Reset = function()
        ApplyConfig(DefaultConfig)
        return SaveConfig(DefaultConfig)
    end
}

print("✅ ConfigSystem Loaded (Empty — No AttackDrone/SafeSpeedMode)")
