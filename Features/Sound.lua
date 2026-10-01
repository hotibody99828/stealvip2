-- ==================================================
-- YOKUDO HUB | FEATURE | Sound System + Background
-- ✅ Background DisplayOrder = 1 (ទាបជាង Icon/UI)
-- ✅ Icon + UI DisplayOrder = 999/9999 (ខ្ពស់)
-- ✅ User នៅតែឃើញ Icon + UI
-- ==================================================

local SoundService = game:GetService("SoundService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

-- ==================================================
-- CONFIG
-- ==================================================
local AUDIO_FOLDER = "YOKUDO-audio"
local AUDIO1_FILE = AUDIO_FOLDER .. "/audio1.mp3"
local AUDIO2_FILE = AUDIO_FOLDER .. "/audio2.mp3"

local AUDIO1_LINK = "https://files.catbox.moe/yn5vzu.mp3"
local AUDIO2_LINK = "https://files.catbox.moe/awtf9v.mp3"

pcall(function()
    if not isfolder(AUDIO_FOLDER) then
        makefolder(AUDIO_FOLDER)
        print("📁 Created folder: " .. AUDIO_FOLDER)
    end
end)

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

DownloadAudio(AUDIO1_FILE, AUDIO1_LINK, "Audio 1")
DownloadAudio(AUDIO2_FILE, AUDIO2_LINK, "Audio 2")

local function GetAsset(FilePath)
    local Asset
    pcall(function() Asset = getcustomasset(FilePath) end)
    return Asset
end

local Audio1Asset = GetAsset(AUDIO1_FILE)
local Audio2Asset = GetAsset(AUDIO2_FILE)

pcall(function()
    local old1 = SoundService:FindFirstChild("YokudoAudio1")
    if old1 then old1:Destroy() end
    local old2 = SoundService:FindFirstChild("YokudoAudio2")
    if old2 then old2:Destroy() end
end)

local Sound1 = Instance.new("Sound")
Sound1.Name = "YokudoAudio1"
Sound1.SoundId = Audio1Asset or ""
Sound1.Volume = 1
Sound1.Looped = true
Sound1.Parent = SoundService

local Sound2 = Instance.new("Sound")
Sound2.Name = "YokudoAudio2"
Sound2.SoundId = Audio2Asset or ""
Sound2.Volume = 1
Sound2.Looped = true
Sound2.Parent = SoundService

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
-- ✅ BACKGROUND (DisplayOrder = 1 — ទាបជាង Icon/UI)
-- ==================================================
local CurrentBG = nil

local function CreateBackground(SubtitleText)
    pcall(function()
        local old = CoreGui:FindFirstChild("YokudoAudioBG")
        if old then old:Destroy() end
    end)

    local BG = Instance.new("ScreenGui")
    BG.Name = "YokudoAudioBG"
    BG.ResetOnSpawn = false
    BG.IgnoreGuiInset = true
    BG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    BG.DisplayOrder = 1  -- ✅ ទាបជាង Icon (9999) និង UI (999)
    BG.Parent = CoreGui

    local BGFrame = Instance.new("Frame")
    BGFrame.Name = "BgFrame"
    BGFrame.Size = UDim2.new(1, 0, 1, 0)
    BGFrame.Position = UDim2.new(0, 0, 0, 0)
    BGFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    BGFrame.BackgroundTransparency = 0
    BGFrame.BorderSizePixel = 0
    BGFrame.ZIndex = 1
    BGFrame.Parent = BG

    -- ✅ អក្សរ YOKUDO HUB
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, 0, 0, 70)
    Title.Position = UDim2.new(0, 0, 0.5, -80)
    Title.BackgroundTransparency = 1
    Title.Text = "YOKUDO HUB"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 56
    Title.Font = Enum.Font.GothamBold
    Title.TextStrokeTransparency = 0.3
    Title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    Title.ZIndex = 2
    Title.Parent = BGFrame

    local Sub = Instance.new("TextLabel")
    Sub.Name = "Sub"
    Sub.Size = UDim2.new(1, 0, 0, 30)
    Sub.Position = UDim2.new(0, 0, 0.5, 10)
    Sub.BackgroundTransparency = 1
    Sub.Text = SubtitleText or "Loading..."
    Sub.TextColor3 = Color3.fromRGB(150, 150, 170)
    Sub.TextSize = 20
    Sub.Font = Enum.Font.GothamMedium
    Sub.ZIndex = 2
    Sub.Parent = BGFrame

    local Note = Instance.new("TextLabel")
    Note.Name = "Note"
    Note.Size = UDim2.new(1, 0, 0, 20)
    Note.Position = UDim2.new(0, 0, 0.5, 55)
    Note.BackgroundTransparency = 1
    Note.Text = "Click Icon to Show UI | Uncheck to Stop"
    Note.TextColor3 = Color3.fromRGB(100, 100, 120)
    Note.TextSize = 13
    Note.Font = Enum.Font.Gotham
    Note.ZIndex = 2
    Note.Parent = BGFrame

    task.spawn(function()
        while BG.Parent do
            TweenService:Create(Sub, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
                TextTransparency = 0.7
            }):Play()
            task.wait(1)
            if not BG.Parent then break end
            TweenService:Create(Sub, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
                TextTransparency = 0
            }):Play()
            task.wait(1)
        end
    end)

    print("🖤 Background: Created (DisplayOrder=1)")
    return BG
end

local function RemoveBackground()
    local BG = CoreGui:FindFirstChild("YokudoAudioBG")
    if BG then
        local BGFrame = BG:FindFirstChild("BgFrame")
        if BGFrame then
            TweenService:Create(BGFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundTransparency = 1
            }):Play()
            for _, child in ipairs(BGFrame:GetDescendants()) do
                if child:IsA("TextLabel") then
                    TweenService:Create(child, TweenInfo.new(0.3), {
                        TextTransparency = 1
                    }):Play()
                end
            end
            task.delay(0.35, function()
                if BG then BG:Destroy() end
                print("🔓 Background: Removed")
            end)
        else
            BG:Destroy()
        end
    end
end

-- ==================================================
-- COMBINED FUNCTIONS
-- ==================================================
local function StartFarming()
    PlaySound1()
    CreateBackground("Auto AFK Farming...")
end

local function StopFarming()
    StopSound1()
    RemoveBackground()
end

local function StartGetEgg()
    PlaySound2()
    CreateBackground("Auto Farming...")
end

local function StopGetEgg()
    StopSound2()
    RemoveBackground()
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_Sound = {
    Play1 = PlaySound1,
    Stop1 = StopSound1,
    IsPlaying1 = function() return Sound1.IsPlaying end,

    Play2 = PlaySound2,
    Stop2 = StopSound2,
    IsPlaying2 = function() return Sound2.IsPlaying end,

    StartFarming = StartFarming,
    StopFarming = StopFarming,
    StartGetEgg = StartGetEgg,
    StopGetEgg = StopGetEgg,

    CreateBackground = CreateBackground,
    RemoveBackground = RemoveBackground,

    StopAll = function()
        StopSound1()
        StopSound2()
        RemoveBackground()
    end,

    Sound1 = Sound1,
    Sound2 = Sound2,

    Folder = AUDIO_FOLDER,
    Audio1File = AUDIO1_FILE,
    Audio2File = AUDIO2_FILE,
}

print("✅ Sound + Background Feature Loaded")
print("🎯 Background DisplayOrder = 1")
print("🎯 Icon DisplayOrder = 9999 (ឃើញលើ BG)")
print("🎯 UI DisplayOrder = 999 (ឃើញលើ BG)")
