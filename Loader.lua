-- ==================================================
-- YOKUDO HUB | STEAL AN EGG | Loader
-- ==================================================

local BASE_URL = "https://raw.githubusercontent.com/betdoyvaka/stealanegg/main/"

_G.YOKUDO_EnablePrint = false

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
-- SAFE LOAD
-- ==================================================
local function SafeLoad(path)
    local ok, script = pcall(function()
        return GetScript(path)
    end)
    if not ok or not script then
        warn("[YOKUDO] ❌ Failed to fetch: " .. path)
        return false
    end

    local ok2, err = pcall(function()
        loadstring(script)()
    end)
    if not ok2 then
        warn("[YOKUDO] ❌ Error in " .. path .. ": " .. tostring(err))
        return false
    end
    return true
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
-- (រក្សា Loading Screen ដូចដើម)

-- ==================================================
-- LOAD CORE FILES
-- ==================================================
Loading.Update(10)
SafeLoad("Config.lua")

Loading.Update(15)
SafeLoad("UI.lua")

Loading.Update(20)
SafeLoad("Components.lua")

Loading.Update(25)
SafeLoad("Tabs/Init.lua")

-- ==================================================
-- LOAD FEATURES
-- ==================================================
Loading.Update(30)
SafeLoad("Features/WalkSpeed.lua")

Loading.Update(33)
SafeLoad("Features/AntiTrap.lua")

Loading.Update(36)
SafeLoad("Features/GodMode.lua")

Loading.Update(39)
SafeLoad("Features/TeleportSystem.lua")

Loading.Update(42)
SafeLoad("Features/AutoFarm.lua")

Loading.Update(45)
SafeLoad("Features/AutoAttack.lua")

-- ✅ AFK System (មុន AttackDrone)
Loading.Update(48)
SafeLoad("Features/AFKSystem.lua")

-- ✅ AttackDrone (កែរួច — ដក MainLoop ចេញ)
Loading.Update(51)
SafeLoad("Features/AttackDrone.lua")

-- ✅ ManagerDrone (ក្រោយ AFK + Attack)
Loading.Update(54)
SafeLoad("Features/ManagerDrone.lua")

Loading.Update(57)
SafeLoad("Features/ManualFastClick.lua")

-- ==================================================
-- LOAD TABS
-- ==================================================
Loading.Update(60)
SafeLoad("Tabs/Info.lua")

Loading.Update(65)
SafeLoad("Tabs/Farming.lua")

Loading.Update(70)
SafeLoad("Tabs/Combat.lua")

Loading.Update(75)
SafeLoad("Tabs/AutoFarming.lua")

Loading.Update(80)
SafeLoad("Tabs/Event.lua")

Loading.Update(85)
SafeLoad("Tabs/HopServer.lua")

Loading.Update(90)
SafeLoad("Tabs/Setting.lua")

-- ==================================================
-- SELECT DEFAULT TAB
-- ==================================================
Loading.Update(92)
if _G.YOKUDO_TabsManager then
    pcall(function()
        _G.YOKUDO_TabsManager:SelectTabByName("Info")
    end)
end

Loading.Update(95)

-- ==================================================
-- LOAD ANTI CHEAT
-- ==================================================
Loading.Update(98)
SafeLoad("Features/BypassAntiCheat.lua")

Loading.Update(100)

task.wait(0.3)
Loading.Destroy()
print("✅ Loading Screen Closed!")
print("🚀 YOKUDO HUB | Ready!")
