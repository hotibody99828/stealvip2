--==================================================
-- YOKUDO HUB - CONFIG SYSTEM (EMPTY)
-- ✅ ដក AttackDroneEnabled + SafeSpeedMode ចេញទាំងស្រុង
-- ✅ គ្មាន Save/Load អ្វីទេ
-- Folder: YOKUDO-SAE
-- File: yokudo.json
--==================================================

local HttpService = game:GetService("HttpService")

local CONFIG_FOLDER = "YOKUDO-SAE"
local CONFIG_FILE = CONFIG_FOLDER .. "/yokudo.json"

--==================================================
-- DEFAULT CONFIG (ទទេ)
--==================================================
local DefaultConfig = {}

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
-- LOAD CONFIG (ទទេ)
--==================================================
local function LoadConfig()
    EnsureFolder()
    print("[YOKUDO] Config Loaded (Empty)")
    return {}
end

--==================================================
-- SAVE CONFIG (ទទេ)
--==================================================
local function SaveConfig(Config)
    EnsureFolder()

    local DataToSave = {}

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
-- APPLY CONFIG (ទទេ)
--==================================================
local function ApplyConfig(Config)
    -- គ្មាន Apply អ្វីទេ
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
            pcall(function()
                if _G.YOKUDO_RefreshEventUI then
                    _G.YOKUDO_RefreshEventUI()
                end
            end)

            -- ✅ Update Setting Tab UI
            pcall(function()
                if _G.YOKUDO_RefreshSettingUI then
                    _G.YOKUDO_RefreshSettingUI()
                end
            end)
        end)

        return Config
    end,

    Save = function()
        return SaveConfig({})
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
