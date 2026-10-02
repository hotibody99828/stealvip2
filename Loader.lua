-- ==================================================
-- YOKUDO HUB | STEAL AN EGG | Loader (UPDATED v13)
-- ✅ SpeedLock Check លូតមុនគេ
-- ✅ MapSettings (Tab Only — All In One)
-- ✅ Sound (Play Once at 50%)
-- ✅ Load Features + Tabs
-- ✅ Register + RunCheck
-- ==================================================

local BASE_URL = "https://raw.githubusercontent.com/hotibody99828/stealvip2/main/"

_G.YOKUDO_EnablePrint = true

local oldPrint = print
print = function(...)
    if _G.YOKUDO_EnablePrint then
        oldPrint(...)
    end
end

print("🔵 Loading YOKUDO HUB...")

-- ==================================================
-- CACHE SYSTEM
-- ==================================================
_G.YOKUDO_Cache = _G.YOKUDO_Cache or {}

local function GetScript(path)
    local fullPath = BASE_URL .. path
    if _G.YOKUDO_Cache[fullPath] then
        return _G.YOKUDO_Cache[fullPath]
    end
    local script = game:HttpGet(fullPath)
    _G.YOKUDO_Cache[fullPath] = script
    return script
end

-- ==================================================
-- WAIT UNTIL GAME IS LOADED
-- ==================================================
repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

local Player = game.Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")

print("✅ Game loaded, Player: " .. Player.Name)

-- ==================================================
-- CREATE LOADING SCREEN
-- ==================================================
local function CreateLoadingScreen()
    local LoadingGui = Instance.new("ScreenGui")
    LoadingGui.Name = "LoadingScreen"
    LoadingGui.ResetOnSpawn = false
    LoadingGui.IgnoreGuiInset = true
    LoadingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    LoadingGui.DisplayOrder = 9999
    LoadingGui.Parent = CoreGui

    local Container = Instance.new("Frame")
    Container.Name = "Container"
    Container.Size = UDim2.new(0, 280, 0, 110)
    Container.Position = UDim2.new(0.5, -140, 0.5, -55)
    Container.BackgroundColor3 = Color3.fromRGB(16, 17, 23)
    Container.BackgroundTransparency = 0.1
    Container.BorderSizePixel = 0
    Container.ClipsDescendants = true
    Container.Parent = LoadingGui

    local ContainerCorner = Instance.new("UICorner")
    ContainerCorner.CornerRadius = UDim.new(0, 14)
    ContainerCorner.Parent = Container

    local ContainerBorder = Instance.new("UIStroke")
    ContainerBorder.Color = Color3.fromRGB(105, 90, 190)
    ContainerBorder.Thickness = 2
    ContainerBorder.Transparency = 0.2
    ContainerBorder.Parent = Container

    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, -30, 0, 28)
    Title.Position = UDim2.new(0, 15, 0, 8)
    Title.BackgroundTransparency = 1
    Title.Text = "YOKUDO HUB"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 20
    Title.TextXAlignment = Enum.TextXAlignment.Center
    Title.TextYAlignment = Enum.TextYAlignment.Center
    Title.Font = Enum.Font.GothamBold
    Title.Parent = Container

    local Subtitle = Instance.new("TextLabel")
    Subtitle.Name = "Subtitle"
    Subtitle.Size = UDim2.new(1, -30, 0, 14)
    Subtitle.Position = UDim2.new(0, 15, 0, 36)
    Subtitle.BackgroundTransparency = 1
    Subtitle.Text = "Steal An Egg"
    Subtitle.TextColor3 = Color3.fromRGB(145, 145, 175)
    Subtitle.TextSize = 9
    Subtitle.TextXAlignment = Enum.TextXAlignment.Center
    Subtitle.TextYAlignment = Enum.TextYAlignment.Center
    Subtitle.Font = Enum.Font.GothamMedium
    Subtitle.Parent = Container

    local BarBg = Instance.new("Frame")
    BarBg.Name = "BarBg"
    BarBg.Size = UDim2.new(0.75, 0, 0, 4)
    BarBg.Position = UDim2.new(0.125, 0, 0.5, 0)
    BarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    BarBg.BorderSizePixel = 0
    BarBg.Parent = Container

    local BarBgCorner = Instance.new("UICorner")
    BarBgCorner.CornerRadius = UDim.new(1, 0)
    BarBgCorner.Parent = BarBg

    local Bar = Instance.new("Frame")
    Bar.Name = "Bar"
    Bar.Size = UDim2.new(0, 0, 1, 0)
    Bar.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
    Bar.BorderSizePixel = 0
    Bar.Parent = BarBg

    local BarCorner = Instance.new("UICorner")
    BarCorner.CornerRadius = UDim.new(1, 0)
    BarCorner.Parent = Bar

    local Percent = Instance.new("TextLabel")
    Percent.Name = "Percent"
    Percent.Size = UDim2.new(1, -30, 0, 22)
    Percent.Position = UDim2.new(0, 15, 0.7, 0)
    Percent.BackgroundTransparency = 1
    Percent.Text = "0%"
    Percent.TextColor3 = Color3.fromRGB(105, 90, 190)
    Percent.TextSize = 18
    Percent.TextXAlignment = Enum.TextXAlignment.Center
    Percent.TextYAlignment = Enum.TextYAlignment.Center
    Percent.Font = Enum.Font.GothamBold
    Percent.Parent = Container

    local function UpdateProgress(percent)
        percent = math.clamp(percent, 0, 100)
        Bar.Size = UDim2.new(percent / 100, 0, 1, 0)
        Percent.Text = math.floor(percent) .. "%"
    end

    return {
        Gui = LoadingGui,
        Update = UpdateProgress,
        Destroy = function()
            LoadingGui:Destroy()
        end
    }
end

local Loading = CreateLoadingScreen()
Loading.Update(5)

-- ==================================================
-- LOAD CORE FILES
-- ==================================================
Loading.Update(8)
loadstring(GetScript("Config.lua"))()

Loading.Update(10)
loadstring(GetScript("UI.lua"))()

Loading.Update(12)
loadstring(GetScript("Components.lua"))()

-- ==================================================
-- ✅ LOAD SPEED LOCK (លូតមុនគេ)
-- ==================================================
Loading.Update(15)
loadstring(GetScript("Features/SpeedLock.lua"))()

-- ==================================================
-- ✅ RUN SPEED CHECK
-- ==================================================
Loading.Update(18)
print("🔍 Running Speed Check...")
task.wait(1.5)

if _G.YOKUDO_SpeedLock then
    _G.YOKUDO_SpeedLock.RunCheck()
    _G.YOKUDO_IsSpeedUnlocked = _G.YOKUDO_SpeedLock.IsUnlocked()
end

-- ==================================================
-- LOAD TABS MANAGER
-- ==================================================
Loading.Update(25)
loadstring(GetScript("Tabs/Init.lua"))()

-- ==================================================
-- LOAD FEATURES
-- ==================================================
Loading.Update(28)
loadstring(GetScript("Features/AntiAFK.lua"))()


Loading.Update(33)
loadstring(GetScript("Features/AntiTrap.lua"))()

Loading.Update(36)
loadstring(GetScript("Features/GodMode.lua"))()

-- ✅ TeleportSystem
Loading.Update(39)
loadstring(GetScript("Features/TeleportSystem.lua"))()

Loading.Update(42)
loadstring(GetScript("Features/AutoFarm.lua"))()

Loading.Update(45)
loadstring(GetScript("Features/AutoAttack.lua"))()

Loading.Update(48)
loadstring(GetScript("Features/AFKSystem.lua"))()

-- ==================================================
-- ✅ LOAD SOUND (Loading 50% — Play Once)
-- ==================================================
Loading.Update(50)
loadstring(GetScript("Features/Sound.lua"))()

-- ✅ លេង Audio ភ្លាម (តែម្តង)
if _G.YOKUDO_Sound then
    _G.YOKUDO_Sound.Play()
    print("🎵 Sound Played at Loading 50%")
end

-- ==================================================
-- LOAD FEATURES (បន្ត)
-- ==================================================
Loading.Update(52)
loadstring(GetScript("Features/FarmingManager.lua"))()

Loading.Update(56)
loadstring(GetScript("Features/AutoEventNew.lua"))()

Loading.Update(58)
loadstring(GetScript("Features/ManagerDrone.lua"))()

Loading.Update(60)
loadstring(GetScript("Features/ManualFastClick.lua"))()

Loading.Update(61)
loadstring(GetScript("Features/DropEgg.lua"))()

Loading.Update(62)
loadstring(GetScript("Features/AntiGuard.lua"))()

Loading.Update(63)
loadstring(GetScript("Features/ConfigSystem.lua"))()

-- ==================================================
-- LOAD TABS
-- ==================================================
Loading.Update(65)
loadstring(GetScript("Tabs/Info.lua"))()

Loading.Update(68)
loadstring(GetScript("Tabs/Farming.lua"))()

Loading.Update(70)
loadstring(GetScript("Tabs/Combat.lua"))()

Loading.Update(73)
loadstring(GetScript("Tabs/AutoFarming.lua"))()

Loading.Update(76)
loadstring(GetScript("Tabs/Event.lua"))()

Loading.Update(80)
loadstring(GetScript("Tabs/HopServer.lua"))()

Loading.Update(85)
loadstring(GetScript("Tabs/Setting.lua"))()

Loading.Update(88)
loadstring(GetScript("Tabs/CollectEggNew.lua"))()

Loading.Update(90)
loadstring(GetScript("Tabs/ESP.lua"))()

-- ==================================================
-- ✅ LOAD MAP SETTINGS TAB
-- ==================================================
Loading.Update(91)
loadstring(GetScript("Tabs/MapSettings.lua"))()

-- ==================================================
-- ✅ REGISTER LOCKABLE BUTTONS
-- ==================================================
Loading.Update(92)
task.spawn(function()
    task.wait(0.5)
    
    if _G.YOKUDO_SpeedLock then
        if _G.YOKUDO_FarmButton then
            _G.YOKUDO_SpeedLock.RegisterLockable(_G.YOKUDO_FarmButton, "Farm")
            print("✅ Registered FarmButton")
        else
            warn("⚠️ _G.YOKUDO_FarmButton not found!")
        end
        
        if _G.YOKUDO_GetEggCheckButton then
            _G.YOKUDO_SpeedLock.RegisterLockable(_G.YOKUDO_GetEggCheckButton, "GetEgg")
            print("✅ Registered GetEggCheckButton")
        else
            warn("⚠️ _G.YOKUDO_GetEggCheckButton not found!")
        end
        
        task.wait(0.3)
        if not _G.YOKUDO_SpeedLock.IsUnlocked() then
            _G.YOKUDO_SpeedLock.ApplyLock()
            print("🔒 Re-applied Lock")
        end
    end
end)

-- ==================================================
-- SELECT DEFAULT TAB
-- ==================================================
Loading.Update(94)
if _G.YOKUDO_TabsManager then
    _G.YOKUDO_TabsManager:SelectTabByName("Info")
end

Loading.Update(95)

-- ==================================================
-- LOAD ANTI CHEAT
-- ==================================================
Loading.Update(96)
loadstring(GetScript("Features/BypassAntiCheat.lua"))()

-- ==================================================
-- APPLY CONFIG
-- ==================================================
Loading.Update(98)
if _G.YOKUDO_ConfigSystem then
    _G.YOKUDO_ConfigSystem.Load()
end

Loading.Update(100)

task.wait(0.3)
Loading.Destroy()
print("✅ Loading Screen Closed!")
print("🚀 YOKUDO HUB | Ready!")
print("🎯 Speed:", _G.YOKUDO_IsSpeedUnlocked and "✅ UNLOCKED" or "🔒 LOCKED")
print("🗺️ MapSettings:", _G.YOKUDO_MapSettings and "✅ LOADED" or "❌ NOT LOADED")
print("🔊 Sound:", _G.YOKUDO_Sound and "✅ LOADED" or "❌ NOT LOADED")
