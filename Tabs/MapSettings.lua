-- ==================================================
-- YOKUDO HUB | TAB | Map Settings (v2 FINAL)
-- ✅ Map Name + TextBox
-- ✅ User Input Value
-- ✅ Default Value
-- ✅ Reset Button
-- ✅ Save/Load Config
-- ==================================================

local TabsManager = _G.YOKUDO_TabsManager
local TweenService = game:GetService("TweenService")

local MapSettingsTab, MapSettingsPage = TabsManager:RegisterTab("Map Settings", 10, "MAP_SETTINGS")

CreateSectionTitle(MapSettingsPage, "Map Settings", 1)

-- ==================================================
-- CHECK MAPSETTINGS LOADED
-- ==================================================
if not _G.YOKUDO_MapSettings then
    warn("[MapSettings] Feature not loaded!")
    return
end

local MapData = _G.YOKUDO_MapSettings.Data
local CreatedEntries = {}

-- ==================================================
-- CREATE MAP ENTRY
-- ==================================================
local function CreateMapEntry(MapId, MapInfo)
    local Entry = Instance.new("Frame")
    Entry.Name = "Map_" .. MapId
    Entry.Size = UDim2.new(1, 0, 0, 52)
    Entry.BackgroundColor3 = Color3.fromRGB(28, 29, 42)
    Entry.BorderSizePixel = 0
    Entry.LayoutOrder = MapId + 1
    Entry.Parent = MapSettingsPage

    local EntryCorner = Instance.new("UICorner")
    EntryCorner.CornerRadius = UDim.new(0, 8)
    EntryCorner.Parent = Entry

    local EntryStroke = Instance.new("UIStroke")
    EntryStroke.Color = Color3.fromRGB(105, 90, 190)
    EntryStroke.Thickness = 1.5
    EntryStroke.Transparency = 0.4
    EntryStroke.Parent = Entry

    -- Map ID Badge
    local IdBadge = Instance.new("Frame")
    IdBadge.Size = UDim2.new(0, 32, 0, 32)
    IdBadge.Position = UDim2.new(0, 8, 0.5, -16)
    IdBadge.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
    IdBadge.BorderSizePixel = 0
    IdBadge.Parent = Entry

    local IdCorner = Instance.new("UICorner")
    IdCorner.CornerRadius = UDim.new(0, 6)
    IdCorner.Parent = IdBadge

    local IdLabel = Instance.new("TextLabel")
    IdLabel.Size = UDim2.new(1, 0, 1, 0)
    IdLabel.BackgroundTransparency = 1
    IdLabel.Text = tostring(MapId)
    IdLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    IdLabel.TextSize = 14
    IdLabel.Font = Enum.Font.GothamBold
    IdLabel.Parent = IdBadge

    -- Map Name
    local NameLabel = Instance.new("TextLabel")
    NameLabel.Size = UDim2.new(1, -170, 0, 18)
    NameLabel.Position = UDim2.new(0, 48, 0, 8)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = MapInfo.Name
    NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    NameLabel.TextSize = 13
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    NameLabel.Font = Enum.Font.GothamBold
    NameLabel.Parent = Entry

    -- Default Value Sub
    local DefaultSub = Instance.new("TextLabel")
    DefaultSub.Size = UDim2.new(1, -170, 0, 14)
    DefaultSub.Position = UDim2.new(0, 48, 0, 28)
    DefaultSub.BackgroundTransparency = 1
    DefaultSub.Text = "Default: " .. tostring(MapInfo.DefaultWait) .. "s"
    DefaultSub.TextColor3 = Color3.fromRGB(150, 150, 170)
    DefaultSub.TextSize = 10
    DefaultSub.TextXAlignment = Enum.TextXAlignment.Left
    DefaultSub.Font = Enum.Font.Gotham
    DefaultSub.Parent = Entry

    -- TextBox
    local TextBox = Instance.new("TextBox")
    TextBox.Name = "ValueBox"
    TextBox.Size = UDim2.new(0, 80, 0, 32)
    TextBox.Position = UDim2.new(1, -90, 0.5, -16)
    TextBox.BackgroundColor3 = Color3.fromRGB(30, 31, 45)
    TextBox.BorderSizePixel = 0
    TextBox.Text = tostring(_G.YOKUDO_MapSettings.GetMapWait(MapId))
    TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextBox.TextSize = 13
    TextBox.TextXAlignment = Enum.TextXAlignment.Center
    TextBox.Font = Enum.Font.GothamBold
    TextBox.PlaceholderText = "Wait..."
    TextBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 140)
    TextBox.ClearTextOnFocus = false
    TextBox.Parent = Entry

    local TextBoxCorner = Instance.new("UICorner")
    TextBoxCorner.CornerRadius = UDim.new(0, 6)
    TextBoxCorner.Parent = TextBox

    local TextBoxStroke = Instance.new("UIStroke")
    TextBoxStroke.Color = Color3.fromRGB(105, 90, 190)
    TextBoxStroke.Thickness = 1.5
    TextBoxStroke.Transparency = 0.3
    TextBoxStroke.Parent = TextBox

    -- Focus Visual
    TextBox.Focused:Connect(function()
        TweenService:Create(TextBoxStroke, TweenInfo.new(0.15), {
            Color = Color3.fromRGB(135, 120, 225),
            Transparency = 0
        }):Play()
    end)

    TextBox.FocusLost:Connect(function(EnterPressed)
        TweenService:Create(TextBoxStroke, TweenInfo.new(0.15), {
            Color = Color3.fromRGB(105, 90, 190),
            Transparency = 0.3
        }):Play()

        local NewValue = tonumber(TextBox.Text)

        if NewValue and NewValue >= 0 then
            _G.YOKUDO_MapSettings.SetMapWait(MapId, NewValue)
            TextBox.Text = tostring(NewValue)

            -- Green Flash
            TweenService:Create(TextBoxStroke, TweenInfo.new(0.2), {
                Color = Color3.fromRGB(80, 255, 80)
            }):Play()
            task.wait(0.3)
            TweenService:Create(TextBoxStroke, TweenInfo.new(0.2), {
                Color = Color3.fromRGB(105, 90, 190)
            }):Play()
        else
            TextBox.Text = tostring(_G.YOKUDO_MapSettings.GetMapWait(MapId))

            -- Red Flash
            TweenService:Create(TextBoxStroke, TweenInfo.new(0.2), {
                Color = Color3.fromRGB(255, 80, 80)
            }):Play()
            task.wait(0.3)
            TweenService:Create(TextBoxStroke, TweenInfo.new(0.2), {
                Color = Color3.fromRGB(105, 90, 190)
            }):Play()
        end
    end)

    table.insert(CreatedEntries, {
        MapId = MapId,
        Entry = Entry,
        TextBox = TextBox,
    })

    return Entry
end

-- ==================================================
-- CREATE ALL MAP ENTRIES
-- ==================================================
for MapId = 1, 10 do
    local MapInfo = MapData[MapId]
    if MapInfo then
        CreateMapEntry(MapId, MapInfo)
    end
end

-- ==================================================
-- RESET BUTTON
-- ==================================================
local ResetBtn = Instance.new("TextButton")
ResetBtn.Size = UDim2.new(1, 0, 0, 36)
ResetBtn.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
ResetBtn.BorderSizePixel = 0
ResetBtn.Text = "Reset All to Default"
ResetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ResetBtn.TextSize = 13
ResetBtn.Font = Enum.Font.GothamBold
ResetBtn.AutoButtonColor = false
ResetBtn.LayoutOrder = 100
ResetBtn.Parent = MapSettingsPage

local ResetCorner = Instance.new("UICorner")
ResetCorner.CornerRadius = UDim.new(0, 8)
ResetCorner.Parent = ResetBtn

local ResetStroke = Instance.new("UIStroke")
ResetStroke.Color = Color3.fromRGB(135, 120, 225)
ResetStroke.Thickness = 1.5
ResetStroke.Transparency = 0.3
ResetStroke.Parent = ResetBtn

ResetBtn.MouseEnter:Connect(function()
    TweenService:Create(ResetBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(125, 110, 220)
    }):Play()
end)

ResetBtn.MouseLeave:Connect(function()
    TweenService:Create(ResetBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(105, 90, 190)
    }):Play()
end)

ResetBtn.MouseButton1Click:Connect(function()
    for _, data in ipairs(CreatedEntries) do
        _G.YOKUDO_MapSettings.ResetMapWait(data.MapId)

        if data.TextBox and MapData[data.MapId] then
            data.TextBox.Text = tostring(MapData[data.MapId].DefaultWait)
        end
    end
    print("[MapSettings] 🔄 All Maps Reset to Default")

    -- ✅ Green Flash Reset Button
    TweenService:Create(ResetStroke, TweenInfo.new(0.2), {
        Color = Color3.fromRGB(80, 255, 80)
    }):Play()
    task.wait(0.3)
    TweenService:Create(ResetStroke, TweenInfo.new(0.2), {
        Color = Color3.fromRGB(135, 120, 225)
    }):Play()
end)

-- ==================================================
-- REFRESH FUNCTION (សម្រាប់ ConfigSystem)
-- ==================================================
_G.YOKUDO_RefreshMapSettingsUI = function()
    for _, data in ipairs(CreatedEntries) do
        if data.TextBox then
            data.TextBox.Text = tostring(_G.YOKUDO_MapSettings.GetMapWait(data.MapId))
        end
    end
    print("[MapSettings] 🔄 UI Refreshed")
end

print("✅ Map Settings Tab Loaded (v2 FINAL)")
