-- ==================================================
-- YOKUDO HUB | FEATURE | Sound System (v3 — Play Once)
-- ✅ 1 Sound Only
-- ✅ Load ពេល Execute
-- ✅ លេងតែម្តង (No Loop)
-- ==================================================

local SoundService = game:GetService("SoundService")

-- ==================================================
-- CONFIG
-- ==================================================
local AUDIO_FOLDER = "YOKUDO-audio"
local AUDIO_FILE = AUDIO_FOLDER .. "/audio.mp3"
local AUDIO_LINK = "https://files.catbox.moe/yn5vzu.mp3"

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
-- DOWNLOAD AUDIO
-- ==================================================
if not isfile(AUDIO_FILE) then
    print("📥 កំពុងទាញយក Audio...")
    local ok, data = pcall(function() return game:HttpGet(AUDIO_LINK) end)
    if ok and data then
        writefile(AUDIO_FILE, data)
        print("✅ រក្សាទុក Audio រួច!")
    else
        warn("❌ ទាញយក Audio បរាជ័យ!")
    end
end

-- ==================================================
-- GET CUSTOM ASSET
-- ==================================================
local AudioAsset
pcall(function() AudioAsset = getcustomasset(AUDIO_FILE) end)

-- ==================================================
-- CREATE SOUND
-- ==================================================
pcall(function()
    local old = SoundService:FindFirstChild("YokudoAudio")
    if old then old:Destroy() end
end)

local Sound = Instance.new("Sound")
Sound.Name = "YokudoAudio"
Sound.SoundId = AudioAsset or ""
Sound.Volume = 1
Sound.Looped = false  -- ✅ លេងតែម្តង (No Loop)
Sound.Parent = SoundService

-- ==================================================
-- ✅ PLAY ONCE
-- ==================================================
local HasPlayed = false  -- ✅ Flag — Play Once

local function PlayAudio()
    -- ✅ បើលេងរួចហើយ → Skip
    if HasPlayed then
        print("⚠️ Audio លេងរួចហើយ (Play Once)")
        return
    end
    
    if Sound.SoundId and Sound.SoundId ~= "" then
        HasPlayed = true
        pcall(function() Sound:Play() end)
        print("🔊 Audio: PLAYING (Once)")
    end
end

local function StopAudio()
    if Sound.IsPlaying then
        pcall(function() Sound:Stop() end)
        print("🔇 Audio: STOPPED")
    end
end

-- ==================================================
-- ✅ EXPORT
-- ==================================================
_G.YOKUDO_Sound = {
    Play = PlayAudio,
    Stop = StopAudio,
    IsPlaying = function() return Sound.IsPlaying end,
    HasPlayed = function() return HasPlayed end,
    Sound = Sound,
    Folder = AUDIO_FOLDER,
    AudioFile = AUDIO_FILE,
}

print("✅ Sound Feature Loaded (Play Once)")
