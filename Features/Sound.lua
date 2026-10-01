-- ==================================================
-- YOKUDO HUB | FEATURE | Sound System
-- ✅ Folder: YOKUDO-audio
-- ✅ Audio 1: audio1.mp3 (Auto AFK Farming)
-- ✅ Audio 2: audio2.mp3 (Click Get Egg)
-- ✅ Auto Play / Stop ពេលធិក / ដកធិក
-- ==================================================

local SoundService = game:GetService("SoundService")

-- ==================================================
-- CONFIG
-- ==================================================
local AUDIO_FOLDER = "YOKUDO-audio"
local AUDIO1_FILE = AUDIO_FOLDER .. "/audio1.mp3"
local AUDIO2_FILE = AUDIO_FOLDER .. "/audio2.mp3"

local AUDIO1_LINK = "https://files.catbox.moe/yn5vzu.mp3"
local AUDIO2_LINK = "https://files.catbox.moe/awtf9v.mp3"

-- ==================================================
-- ENSURE FOLDER
-- ==================================================
pcall(function()
    if not isfolder(AUDIO_FOLDER) then
        makefolder(AUDIO_FOLDER)
        print("📁 Created folder: " .. AUDIO_FOLDER)
    end
end)

-- ==================================================
-- DOWNLOAD FUNCTION
-- ==================================================
local function DownloadAudio(FilePath, Link, Name)
    if not isfile(FilePath) then
        print("📥 កំពុងទាញយក " .. Name .. "...")
        local ok, data = pcall(function() return game:HttpGet(Link) end)
        if ok and data then
            writefile(FilePath, data)
            print("✅ រក្សាទុក " .. Name .. " រួច!")
            return true
        else
            warn("❌ ទាញយក " .. Name .. " បរាជ័យ!")
            return false
        end
    end
    return true
end

-- ✅ ទាញយក Audio 1 + 2
DownloadAudio(AUDIO1_FILE, AUDIO1_LINK, "Audio 1")
DownloadAudio(AUDIO2_FILE, AUDIO2_LINK, "Audio 2")

-- ==================================================
-- GET CUSTOM ASSET
-- ==================================================
local function GetAsset(FilePath)
    local Asset
    pcall(function() Asset = getcustomasset(FilePath) end)
    return Asset
end

local Audio1Asset = GetAsset(AUDIO1_FILE)
local Audio2Asset = GetAsset(AUDIO2_FILE)

-- ==================================================
-- CREATE SOUND OBJECTS
-- ==================================================
-- ✅ សម្អាតចាស់
pcall(function()
    local old1 = SoundService:FindFirstChild("YokudoAudio1")
    if old1 then old1:Destroy() end
    local old2 = SoundService:FindFirstChild("YokudoAudio2")
    if old2 then old2:Destroy() end
end)

-- Sound 1
local Sound1 = Instance.new("Sound")
Sound1.Name = "YokudoAudio1"
Sound1.SoundId = Audio1Asset or ""
Sound1.Volume = 1
Sound1.Looped = true
Sound1.Parent = SoundService

-- Sound 2
local Sound2 = Instance.new("Sound")
Sound2.Name = "YokudoAudio2"
Sound2.SoundId = Audio2Asset or ""
Sound2.Volume = 1
Sound2.Looped = true
Sound2.Parent = SoundService

-- ==================================================
-- PLAY / STOP FUNCTIONS
-- ==================================================
local function PlaySound1()
    if Sound1.SoundId and Sound1.SoundId ~= "" then
        if not Sound1.IsPlaying then
            pcall(function() Sound1:Play() end)
            print("🔊 Audio 1: PLAYING")
        end
    end
end

local function StopSound1()
    if Sound1.IsPlaying then
        pcall(function() Sound1:Stop() end)
        print("🔇 Audio 1: STOPPED")
    end
end

local function PlaySound2()
    if Sound2.SoundId and Sound2.SoundId ~= "" then
        if not Sound2.IsPlaying then
            pcall(function() Sound2:Play() end)
            print("🔊 Audio 2: PLAYING")
        end
    end
end

local function StopSound2()
    if Sound2.IsPlaying then
        pcall(function() Sound2:Stop() end)
        print("🔇 Audio 2: STOPPED")
    end
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_Sound = {
    -- Audio 1 (Auto AFK Farming)
    Play1 = PlaySound1,
    Stop1 = StopSound1,
    IsPlaying1 = function() return Sound1.IsPlaying end,

    -- Audio 2 (Click Get Egg)
    Play2 = PlaySound2,
    Stop2 = StopSound2,
    IsPlaying2 = function() return Sound2.IsPlaying end,

    -- Stop All
    StopAll = function()
        StopSound1()
        StopSound2()
    end,

    -- Sound Objects
    Sound1 = Sound1,
    Sound2 = Sound2,

    -- Folder Info
    Folder = AUDIO_FOLDER,
    Audio1File = AUDIO1_FILE,
    Audio2File = AUDIO2_FILE,
}

print("✅ Sound Feature Loaded")
print("📁 Folder: " .. AUDIO_FOLDER)
print("🎵 Audio 1: audio1.mp3")
print("🎵 Audio 2: audio2.mp3")
