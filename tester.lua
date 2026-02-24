-- Linoria First-Person BOT
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local Camera = workspace.CurrentCamera

local function getCamera()
    local cam = workspace.CurrentCamera
    if cam and cam:IsA("Camera") then
        Camera = cam
        return cam
    end
    if Camera and Camera:IsA("Camera") then
        return Camera
    end
    return nil
end

local function safeWorldToViewportPoint(position)
    local cam = getCamera()
    if not cam then
        return nil, false
    end

    local ok, point, onScreen = pcall(function()
        return cam:WorldToViewportPoint(position)
    end)
    if not ok then
        return nil, false
    end

    return point, onScreen
end

local LocalPlayer = Players.LocalPlayer

local repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"

local Library
local ThemeManager
local SaveManager
local ok, err = pcall(function()
    Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
    ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
    SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
end)
if not ok or not Library or not ThemeManager or not SaveManager then
    warn("[Aimbot] Linoria failed to load: " .. tostring(err))
    return
end

local Window = Library:CreateWindow({
    Title = "R.A.T. | really accesible truth.",
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,
})

local function enumToName(bind)
    if typeof(bind) == "EnumItem" then
        return bind.Name
    end
    return tostring(bind or "Q")
end

local function parseLinoriaKeybind(value, fallback)
    if typeof(value) == "EnumItem" then
        if value.EnumType == Enum.KeyCode or value.EnumType == Enum.UserInputType then
            return value
        end
        return fallback
    end

    if type(value) == "string" then
        local cleaned = value:gsub("Enum%.KeyCode%.", ""):gsub("Enum%.UserInputType%.", "")
        return Enum.KeyCode[cleaned] or Enum.UserInputType[cleaned] or fallback
    end

    return fallback
end

local function parseLinoriaMode(value, fallback)
    if type(value) == "string" then
        local lower = string.lower(value)
        if lower == "hold" then
            return "Hold"
        end
        if lower == "toggle" or lower == "always" then
            return "Toggle"
        end
    end

    if type(value) == "table" then
        return parseLinoriaMode(value.Mode or value.mode or value.State, fallback)
    end

    return fallback
end

local uid = 0
local function nextId(prefix)
    uid = uid + 1
    return string.format("%s_%d", prefix, uid)
end

local function getOptionsTable()
    local okGenv, genv = pcall(getgenv)
    if okGenv and type(genv) == "table" and type(genv.Options) == "table" then
        return genv.Options
    end
    if type(_G) == "table" and type(_G.Options) == "table" then
        return _G.Options
    end
    if type(Options) == "table" then
        return Options
    end
    return nil
end

local function buildTabAdapter(name)
    local tab = Window:AddTab(name)
    local group = tab:AddLeftGroupbox(name .. " Controls")

    local adapter = {}

    function adapter:Dropdown(args)
        local id = nextId("Dropdown")
        group:AddDropdown(id, {
            Text = args.Name,
            Values = args.Items or {},
            Default = args.StartingText,
            Multi = false,
            Callback = args.Callback,
        })
    end

    function adapter:Toggle(args)
        local id = nextId("Toggle")
        group:AddToggle(id, {
            Text = args.Name,
            Default = args.StartingState,
            Callback = args.Callback,
        })
    end

    function adapter:Slider(args)
        local id = nextId("Slider")
        group:AddSlider(id, {
            Text = args.Name,
            Default = args.Default,
            Min = args.Min,
            Max = args.Max,
            Rounding = args.Precision or 0,
            Compact = false,
            Callback = args.Callback,
        })
    end

    function adapter:Button(args)
        group:AddButton(args.Name, args.Callback)
    end

    function adapter:Keybind(args)
        local id = nextId("Keybind")
        local label = group:AddLabel(args.Name)
        local currentBind = parseLinoriaKeybind(args.Keybind, Enum.KeyCode.Q)
        local currentMode = parseLinoriaMode(args.Mode, "Toggle")
        local isActive = false

        label:AddKeyPicker(id, {
            Default = enumToName(currentBind),
            SyncToggleState = false,
            Mode = currentMode,
            Text = args.Description or args.Name,
            NoUI = false,
            Callback = function(value)
                local parsedBind = parseLinoriaKeybind(value, nil)
                if parsedBind then
                    currentBind = parsedBind
                    if args.Callback then
                        args.Callback(currentBind, isActive, currentMode)
                    end
                    return
                end

                if currentMode == "Hold" then
                    if type(value) == "boolean" then
                        isActive = value
                    else
                        isActive = not isActive
                    end
                else
                    if value == false then
                        return
                    end
                    isActive = not isActive
                end

                if args.Callback then
                    args.Callback(currentBind, isActive, currentMode)
                end
            end,
            ChangedCallback = function(new)
                local parsedBind = parseLinoriaKeybind(new, nil)
                if parsedBind then
                    currentBind = parsedBind
                end
                currentMode = parseLinoriaMode(new, currentMode)
                if currentMode ~= "Hold" then
                    isActive = false
                end

                if args.ChangedCallback then
                    args.ChangedCallback(currentBind, currentMode)
                end
            end,
        })
        return label
    end

    adapter._tab = tab
    return adapter
end

local CombatTab = buildTabAdapter("Combat")
local SettingsTab = buildTabAdapter("Settings")
local MiscTab = buildTabAdapter("Misc")

local Settings = {
    Enabled = false,
    Mode = "Hold", -- Toggle / Hold
    AimKey = Enum.UserInputType.MouseButton2,
    LockPart = "Head",
    Sensitivity = 0.1,
    TeamCheck = false,
    AliveCheck = true,
    WallCheck = true,
    Prediction = 0.08,
    FOV = 220,
    ShowFOV = true,
    AimbotType = "Camera", -- Camera / Silent


    ESPEnabled = true,
    ESPTeamCheck = false,
    ESPUseTeamColor = false,
    ESPMaxDistance = 3000,
    ESPThickness = 2,
    ESPTextSize = 13,
    ESPBoxes = true,
    ESPTracers = true,
    ESPNames = true,
    ESPDistance = true,
    ESPHealthBar = true,
    ESPStyle = "Classic",
    ESPFont = "Plex",

    SpeedhackEnabled = false,
    SpeedhackSpeed = 16,

    OreESPEnabled = false,
    OreIron = true,
    OreStone = true,
    OreSulfur = true,

    ArrowESP = true,
    ArrowCount = 12,
    ArrowRadiusOffset = 24,

    NoRecoil = false,
    Jumpshoot = false,
    NoFallDamage = false,
    NoRadiation = false,

    AutoReload = false,
    AutoReloadCooldown = 0.35,

    GunNoSpread = false,
    GunGodMode = false,
    GunFireDelay = 0.01,
    Wall = false,
    ManipEnabled = false,
    ManipMode = "classic",

    BulletTracerEnabled = true,
    BulletTracerLifetime = 0.35,
    BulletTracerThickness = 2,

    HitSoundEnabled = false,
    HitSound = "Neverlose",
    HitSoundVolume = 0.5,

    NoFog = false,
    SkyboxEnabled = false,
    SkyboxPreset = "Purple",
}



local holding = false
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = false

local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 2
fovCircle.NumSides = 360
fovCircle.Filled = false
fovCircle.Transparency = 0.75
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Radius = Settings.FOV
fovCircle.Visible = Settings.ShowFOV

local espObjects = {}
local arrowObjects = {}
local gameHooks = { installed = false, warned = false, originals = {}, refs = {} }
local noRadHook = { installed = false, original = nil }
local gunClientNewHook = { installed = false, original = nil }
local lastReloadAt = 0
local bulletTracers = {}
local function asNum(value, fallback)
    local n = tonumber(value)
    if n ~= nil then return n end
    return fallback
end

local hitSoundIds = {
    Neverlose = "rbxassetid://8726881116",
    Bell = "rbxassetid://6534947240",
    Bubble = "rbxassetid://821439273",
    Minecraft = "rbxassetid://4018616850",
}

local originalFog = {
    FogStart = Lighting.FogStart,
    FogEnd = Lighting.FogEnd,
    FogColor = Lighting.FogColor,
}

local skyboxPresets = {
    Purple = {
        SkyboxBk = "rbxassetid://159454299",
        SkyboxDn = "rbxassetid://159454296",
        SkyboxFt = "rbxassetid://159454293",
        SkyboxLf = "rbxassetid://159454286",
        SkyboxRt = "rbxassetid://159454300",
        SkyboxUp = "rbxassetid://159454288",
    },
    Galaxy = {
        SkyboxBk = "rbxassetid://149397692",
        SkyboxDn = "rbxassetid://149397686",
        SkyboxFt = "rbxassetid://149397697",
        SkyboxLf = "rbxassetid://149397684",
        SkyboxRt = "rbxassetid://149397688",
        SkyboxUp = "rbxassetid://149397702",
    },
    Vibe = {
        SkyboxBk = "rbxassetid://1417494030",
        SkyboxDn = "rbxassetid://1417494146",
        SkyboxFt = "rbxassetid://1417494253",
        SkyboxLf = "rbxassetid://1417494402",
        SkyboxRt = "rbxassetid://1417494499",
        SkyboxUp = "rbxassetid://1417494643",
    },
}

local function applyWorldVisuals()
    if Settings.NoFog then
        Lighting.FogStart = 0
        Lighting.FogEnd = 1e10
        Lighting.FogColor = Color3.new(1, 1, 1)
    else
        Lighting.FogStart = originalFog.FogStart
        Lighting.FogEnd = originalFog.FogEnd
        Lighting.FogColor = originalFog.FogColor
    end

    local existingSky = Lighting:FindFirstChild("__linoriaSkybox")
    if not Settings.SkyboxEnabled then
        if existingSky then
            existingSky:Destroy()
        end
        return
    end

    local preset = skyboxPresets[Settings.SkyboxPreset] or skyboxPresets.Purple
    local sky = existingSky
    if not sky then
        sky = Instance.new("Sky")
        sky.Name = "__linoriaSkybox"
        sky.Parent = Lighting
    end

    for prop, id in pairs(preset) do
        sky[prop] = id
    end
end

local function playHitSound()
    if not Settings.HitSoundEnabled then return end
    local soundId = hitSoundIds[Settings.HitSound] or hitSoundIds.Neverlose
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = math.clamp(asNum(Settings.HitSoundVolume, 0.5), 0, 5)
    sound.PlayOnRemove = false
    sound.Parent = SoundService
    sound:Play()
    task.delay(1.5, function()
        if sound then
            sound:Destroy()
        end
    end)
end

local function addBulletTracer(fromPos, toPos)
    if not Settings.BulletTracerEnabled then return end
    local ok, line = pcall(Drawing.new, "Line")
    if not ok or not line then return end
    line.Visible = false
    line.Thickness = math.clamp(asNum(Settings.BulletTracerThickness, 2), 1, 6)
    line.Transparency = 1
    line.Color = Color3.fromRGB(255, 210, 90)

    bulletTracers[#bulletTracers + 1] = {
        fromPos = fromPos,
        toPos = toPos,
        createdAt = tick(),
        line = line,
    }
end

local function clearBulletTracers()
    for i = #bulletTracers, 1, -1 do
        local tr = bulletTracers[i]
        if tr and tr.line then
            tr.line:Remove()
        end
        bulletTracers[i] = nil
    end
end

local function updateBulletTracers()
    local now = tick()
    local life = math.clamp(asNum(Settings.BulletTracerLifetime, 0.35), 0.05, 1)

    for i = #bulletTracers, 1, -1 do
        local tr = bulletTracers[i]
        local age = now - tr.createdAt
        local line = tr.line

        if (not Settings.BulletTracerEnabled) or age > life or not line then
            if line then
                line:Remove()
            end
            table.remove(bulletTracers, i)
        else
            local fromScreen, fromOn = safeWorldToViewportPoint(tr.fromPos)
            local toScreen, toOn = safeWorldToViewportPoint(tr.toPos)

            if fromScreen and toScreen and fromOn and toOn and fromScreen.Z > 0 and toScreen.Z > 0 then
                line.From = Vector2.new(fromScreen.X, fromScreen.Y)
                line.To = Vector2.new(toScreen.X, toScreen.Y)
                line.Thickness = math.clamp(asNum(Settings.BulletTracerThickness, 2), 1, 6)
                line.Transparency = math.clamp(1 - (age / life), 0.08, 1)
                line.Visible = true
            else
                line.Visible = false
            end
        end
    end
end

local function newESPObject()
    local obj = {
        Box = Drawing.new("Square"),
        BoxOutline = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        Tracer = Drawing.new("Line"),
        HealthBar = Drawing.new("Line"),
        HealthOutline = Drawing.new("Line"),
        Orbit = Drawing.new("Circle"),
        OrbitDot = Drawing.new("Circle"),
        CornerTL = Drawing.new("Line"),
        CornerTR = Drawing.new("Line"),
        CornerBL = Drawing.new("Line"),
        CornerBR = Drawing.new("Line"),
    }

    obj.Box.Filled = false
    obj.Box.Visible = false

    obj.BoxOutline.Filled = false
    obj.BoxOutline.Visible = false
    obj.BoxOutline.Color = Color3.fromRGB(15, 15, 15)

    obj.Name.Center = true
    obj.Name.Outline = true
    obj.Name.Visible = false
    obj.Name.Font = 2

    obj.Distance.Center = true
    obj.Distance.Outline = true
    obj.Distance.Visible = false
    obj.Distance.Font = 2

    obj.Tracer.Visible = false

    obj.HealthBar.Visible = false
    obj.HealthOutline.Visible = false
    obj.HealthOutline.Color = Color3.fromRGB(15, 15, 15)

    obj.Orbit.Filled = false
    obj.Orbit.Visible = false
    obj.Orbit.Transparency = 0.9

    obj.OrbitDot.Filled = true
    obj.OrbitDot.Visible = false
    obj.OrbitDot.Radius = 2

    obj.CornerTL.Visible = false
    obj.CornerTR.Visible = false
    obj.CornerBL.Visible = false
    obj.CornerBR.Visible = false

    return obj
end

local function hideESPObject(obj)
    obj.Box.Visible = false
    obj.BoxOutline.Visible = false
    obj.Name.Visible = false
    obj.Distance.Visible = false
    obj.Tracer.Visible = false
    obj.HealthBar.Visible = false
    obj.HealthOutline.Visible = false
    obj.Orbit.Visible = false
    obj.OrbitDot.Visible = false
    obj.CornerTL.Visible = false
    obj.CornerTR.Visible = false
    obj.CornerBL.Visible = false
    obj.CornerBR.Visible = false
end

local function removeESPObject(player)
    local obj = espObjects[player]
    if not obj then return end
    for _, draw in pairs(obj) do
        draw:Remove()
    end
    espObjects[player] = nil
end

local function getESPObject(player)
    if not espObjects[player] then
        espObjects[player] = newESPObject()
    end
    return espObjects[player]
end

local function notify(text)
    pcall(function()
        Library:Notify(text, 2)
    end)
end

local function toNumber(value, fallback)
    if type(value) == "number" then
        return value
    end
    if type(value) == "string" then
        local n = tonumber(value)
        if n then return n end
    end
    if type(value) == "table" then
        local candidates = { value.Value, value.value, value.Current, value.current, value[1] }
        for _, v in ipairs(candidates) do
            local n = tonumber(v)
            if n then return n end
        end
    end
    return fallback
end

local function isAlive(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    return humanoid.Health > 0
end

local function isVisible(targetPart)
    if not Settings.WallCheck then
        return true
    end

    local myChar = LocalPlayer.Character
    if not myChar then
        return false
    end

    rayParams.FilterDescendantsInstances = { myChar }

    local cam = getCamera()
    if not cam then return false end
    local origin = cam.CFrame.Position
    local direction = targetPart.Position - origin
    local hit = workspace:Raycast(origin, direction, rayParams)

    if hit == nil then
        return true
    end

    local targetChar = targetPart.Parent
    return targetChar and hit.Instance and hit.Instance:IsDescendantOf(targetChar)
end

local function getPredictedPosition(part)
    local velocity = part.AssemblyLinearVelocity or Vector3.zero
    return part.Position + velocity * Settings.Prediction
end

-- Closest target to crosshair inside FOV (first-person feel)
local function getClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge

    local cam = getCamera()
    if not cam then return nil end
    local center = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            if Settings.TeamCheck and player.Team == LocalPlayer.Team then
                continue
            end

            local character = player.Character
            local part = character:FindFirstChild(Settings.LockPart)
            if part and part:IsA("BasePart") then
                if Settings.AliveCheck and not isAlive(character) then
                    continue
                end

                if not isVisible(part) then
                    continue
                end

                local viewportPoint, onScreen = safeWorldToViewportPoint(part.Position)
                if not viewportPoint then continue end
                if onScreen and viewportPoint.Z > 0 then
                    local screenDistance = (Vector2.new(viewportPoint.X, viewportPoint.Y) - center).Magnitude
                    if screenDistance <= Settings.FOV and screenDistance < shortestDistance then
                        shortestDistance = screenDistance
                        closestPlayer = player
                    end
                end
            end
        end
    end

    return closestPlayer
end

local function getPlayerColor(player)
    if Settings.ESPUseTeamColor and player.TeamColor then
        return player.TeamColor.Color
    end
    return Color3.fromRGB(255, 255, 255)
end


local fontMap = {
    UI = 0,
    System = 1,
    Plex = 2,
    Monospace = 3,
}

local function getESPFontIndex()
    return fontMap[Settings.ESPFont] or 2
end

local oreEspObjects = {}
local function parseBindEnum(value)
    if typeof(value) == "EnumItem" then
        if value.EnumType == Enum.KeyCode or value.EnumType == Enum.UserInputType then
            return value
        end
        return nil
    end

    if type(value) == "string" then
        local clean = value:gsub("Enum%.KeyCode%.", ""):gsub("Enum%.UserInputType%.", "")
        local asKeyCode = Enum.KeyCode[clean]
        if asKeyCode then return asKeyCode end
        local asInputType = Enum.UserInputType[clean]
        if asInputType then return asInputType end
    end

    if type(value) == "table" then
        local keys = {
            value.KeyCode,
            value.UserInputType,
            value.Key,
            value.Bind,
            value.Value,
            value.value,
            value.New,
            value.new,
            value.Selected,
            value.selected,
            value[1],
        }
        for _, candidate in ipairs(keys) do
            local parsed = parseBindEnum(candidate)
            if parsed then return parsed end
        end
    end

    return nil
end

local function formatBind(bind)
    local parsed = parseBindEnum(bind)
    if parsed then
        return parsed.Name
    end
    return tostring(bind)
end

local function setAimKey(value)
    local parsed = parseBindEnum(value)
    if parsed then
        Settings.AimKey = parsed
        notify("Aimbot key: " .. formatBind(parsed))
        return true
    end
    return false
end

local function inputMatchesBind(input, bind)
    local parsed = parseBindEnum(bind)
    if not parsed then return false end
    if parsed.EnumType == Enum.KeyCode then
        return input.KeyCode == parsed
    end
    if parsed.EnumType == Enum.UserInputType then
        return input.UserInputType == parsed
    end
    return false
end

local function shouldShowOre(name)
    local n = string.lower(name)
    if n == "iron" then return Settings.OreIron end
    if n == "stone" then return Settings.OreStone end
    if n == "sulfur" then return Settings.OreSulfur end
    return false
end

local function clearOreESP()
    for inst, draw in pairs(oreEspObjects) do
        if draw then draw:Remove() end
        oreEspObjects[inst] = nil
    end
end

local function updateOreESP()
    if not Settings.OreESPEnabled then
        for _, draw in pairs(oreEspObjects) do
            draw.Visible = false
        end
        return
    end

    local oresFolder = workspace:FindFirstChild("ores")
    if not oresFolder then return end

    local seen = {}
    for _, ore in ipairs(oresFolder:GetChildren()) do
        local oreName = string.lower(ore.Name)
        if (oreName == "iron" or oreName == "stone" or oreName == "sulfur") and shouldShowOre(ore.Name) then
            local part = ore:IsA("BasePart") and ore or ore:FindFirstChildWhichIsA("BasePart")
            if part then
                local pos, onScreen = safeWorldToViewportPoint(part.Position + Vector3.new(0, 2, 0))
                if not pos then continue end
                local txt = oreEspObjects[ore]
                if not txt then
                    txt = Drawing.new("Text")
                    txt.Center = true
                    txt.Outline = true
                    txt.Size = 14
                    txt.Color = Color3.fromRGB(255, 230, 120)
                    oreEspObjects[ore] = txt
                end
                txt.Font = getESPFontIndex()
                txt.Text = ore.Name
                txt.Position = Vector2.new(pos.X, pos.Y)
                txt.Visible = onScreen and pos.Z > 0
                seen[ore] = true
            end
        end
    end

    for ore, draw in pairs(oreEspObjects) do
        if not seen[ore] then
            draw.Visible = false
        end
    end
end

local function updateESPForPlayer(player)
    local obj = getESPObject(player)

    if not Settings.ESPEnabled or player == LocalPlayer then
        hideESPObject(obj)
        return
    end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local head = character and character:FindFirstChild("Head")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not (character and root and head and humanoid) then
        hideESPObject(obj)
        return
    end

    if Settings.AliveCheck and humanoid.Health <= 0 then
        hideESPObject(obj)
        return
    end

    if Settings.ESPTeamCheck and player.Team == LocalPlayer.Team then
        hideESPObject(obj)
        return
    end

    local cam = getCamera()
    if not cam then
        hideESPObject(obj)
        return
    end

    local rootPos, onScreen = safeWorldToViewportPoint(root.Position)
    if not rootPos then
        hideESPObject(obj)
        return
    end
    if not onScreen or rootPos.Z <= 0 then
        hideESPObject(obj)
        return
    end

    local distance = (cam.CFrame.Position - root.Position).Magnitude
    if distance > Settings.ESPMaxDistance then
        hideESPObject(obj)
        return
    end

    local topPos = ({safeWorldToViewportPoint(head.Position + Vector3.new(0, 0.45, 0))})[1]
    local bottomPos = ({safeWorldToViewportPoint(root.Position - Vector3.new(0, 3.2, 0))})[1]
    if not (topPos and bottomPos) then
        hideESPObject(obj)
        return
    end

    local height = math.max(bottomPos.Y - topPos.Y, 12)
    local width = math.max(height / 2.05, 8)

    local x = rootPos.X - width / 2
    local y = topPos.Y
    local color = getPlayerColor(player)
    local thickness = math.clamp(Settings.ESPThickness, 1, 4)
    local textSize = math.clamp(Settings.ESPTextSize, 12, 18)
    local fontIndex = getESPFontIndex()
    local planetary = Settings.ESPStyle == "Planetary"

    obj.Box.Size = Vector2.new(width, height)
    obj.Box.Position = Vector2.new(x, y)
    obj.Box.Color = color
    obj.Box.Thickness = thickness
    obj.Box.Visible = Settings.ESPBoxes and not planetary

    obj.BoxOutline.Size = Vector2.new(width, height)
    obj.BoxOutline.Position = Vector2.new(x, y)
    obj.BoxOutline.Thickness = thickness + 2
    obj.BoxOutline.Visible = Settings.ESPBoxes and not planetary

    obj.Name.Size = textSize
    obj.Name.Color = color
    obj.Name.Text = player.Name
    obj.Name.Font = fontIndex
    obj.Name.Position = Vector2.new(rootPos.X, y - textSize - 2)
    obj.Name.Visible = Settings.ESPNames

    obj.Distance.Size = textSize - 1
    obj.Distance.Color = Color3.fromRGB(220, 220, 220)
    obj.Distance.Text = string.format("%dm", math.floor(distance / 3))
    obj.Distance.Font = fontIndex
    obj.Distance.Position = Vector2.new(rootPos.X, y + height + 2)
    obj.Distance.Visible = Settings.ESPDistance

    obj.Tracer.From = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y - 30)
    obj.Tracer.To = Vector2.new(rootPos.X, y + height)
    obj.Tracer.Color = color
    obj.Tracer.Thickness = thickness
    obj.Tracer.Visible = Settings.ESPTracers

    local healthPct = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
    local healthX = x - 7
    local hbTop = y + height
    local hbBottom = y
    local hbCurrent = hbTop - (height * healthPct)

    obj.HealthOutline.From = Vector2.new(healthX, hbTop + 1)
    obj.HealthOutline.To = Vector2.new(healthX, hbBottom - 1)
    obj.HealthOutline.Thickness = thickness + 1
    obj.HealthOutline.Visible = Settings.ESPHealthBar

    obj.HealthBar.From = Vector2.new(healthX, hbTop)
    obj.HealthBar.To = Vector2.new(healthX, hbCurrent)
    obj.HealthBar.Thickness = thickness
    obj.HealthBar.Color = Color3.fromRGB(255 - (255 * healthPct), 255 * healthPct, 70)
    obj.HealthBar.Visible = Settings.ESPHealthBar

    if planetary and Settings.ESPBoxes then
        local cornerLen = math.max(math.floor(width * 0.28), 5)

        obj.CornerTL.From = Vector2.new(x, y + cornerLen)
        obj.CornerTL.To = Vector2.new(x, y)
        obj.CornerTL.Thickness = thickness
        obj.CornerTL.Color = color

        obj.CornerTR.From = Vector2.new(x + width, y + cornerLen)
        obj.CornerTR.To = Vector2.new(x + width, y)
        obj.CornerTR.Thickness = thickness
        obj.CornerTR.Color = color

        obj.CornerBL.From = Vector2.new(x, y + height - cornerLen)
        obj.CornerBL.To = Vector2.new(x, y + height)
        obj.CornerBL.Thickness = thickness
        obj.CornerBL.Color = color

        obj.CornerBR.From = Vector2.new(x + width, y + height - cornerLen)
        obj.CornerBR.To = Vector2.new(x + width, y + height)
        obj.CornerBR.Thickness = thickness
        obj.CornerBR.Color = color

        obj.CornerTL.Visible = true
        obj.CornerTR.Visible = true
        obj.CornerBL.Visible = true
        obj.CornerBR.Visible = true

        local orbitRadius = math.max(width * 0.65, 10)
        local t = tick() * 2.2
        local orbitCenter = Vector2.new(rootPos.X, y + height * 0.5)
        local dotPos = orbitCenter + Vector2.new(math.cos(t) * orbitRadius, math.sin(t) * orbitRadius)

        obj.Orbit.Position = orbitCenter
        obj.Orbit.Radius = orbitRadius
        obj.Orbit.NumSides = 64
        obj.Orbit.Color = Color3.fromRGB(180, 220, 255)
        obj.Orbit.Thickness = 1
        obj.Orbit.Visible = true

        obj.OrbitDot.Position = dotPos
        obj.OrbitDot.Color = color
        obj.OrbitDot.Visible = true
    else
        obj.CornerTL.Visible = false
        obj.CornerTR.Visible = false
        obj.CornerBL.Visible = false
        obj.CornerBR.Visible = false
        obj.Orbit.Visible = false
        obj.OrbitDot.Visible = false
    end
end

local function updateAllESP()
    for _, player in ipairs(Players:GetPlayers()) do
        updateESPForPlayer(player)
    end
end

local function removeArrowObject(player)
    local tri = arrowObjects[player]
    if tri then
        tri:Remove()
        arrowObjects[player] = nil
    end
end

local function clearArrowESP()
    for player in pairs(arrowObjects) do
        removeArrowObject(player)
    end
end

local function getArrowObject(player)
    if not arrowObjects[player] then
        local tri = Drawing.new("Triangle")
        tri.Filled = true
        tri.Visible = false
        tri.Transparency = 0.95
        arrowObjects[player] = tri
    end
    return arrowObjects[player]
end

local function updateArrowESP()
    if not Settings.ArrowESP then
        for _, tri in pairs(arrowObjects) do
            tri.Visible = false
        end
        return
    end

    local cam = getCamera()
    if not cam then return end
    local vp = cam.ViewportSize
    local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    local baseRadius = Settings.FOV + Settings.ArrowRadiusOffset
    local used = {}
    local i = 0

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local part = player.Character:FindFirstChild(Settings.LockPart) or player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if part and humanoid and humanoid.Health > 0 then
                local screenPos, onScreen = safeWorldToViewportPoint(part.Position)
                if not screenPos then continue end
                local tri = getArrowObject(player)
                local dir = Vector2.new(screenPos.X, screenPos.Y) - center
                if screenPos.Z <= 0 then
                    dir = -dir
                    onScreen = false
                end
                if dir.Magnitude > 1 then
                    dir = dir.Unit
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        if dist < Settings.FOV * 0.85 then
                            tri.Visible = false
                        else
                            i = i + 1
                            local radius = baseRadius + ((i % math.max(Settings.ArrowCount, 1)) * 1.5)
                            local pos = center + dir * radius
                            local perp = Vector2.new(-dir.Y, dir.X)
                            local len = 13
                            tri.PointA = pos + dir * len
                            tri.PointB = pos - dir * (len * 0.7) + perp * (len * 0.58)
                            tri.PointC = pos - dir * (len * 0.7) - perp * (len * 0.58)
                            local hue = (tick() * 0.22 + (i * 0.07)) % 1
                            tri.Color = Color3.fromHSV(hue, 0.85, 1)
                            tri.Visible = true
                            used[player] = true
                        end
                    else
                        i = i + 1
                        local radius = baseRadius + ((i % math.max(Settings.ArrowCount, 1)) * 1.5)
                        local spin = tick() * 0.8
                        local ang = math.atan2(dir.Y, dir.X) + (math.sin(spin + i) * 0.08)
                        local rdir = Vector2.new(math.cos(ang), math.sin(ang))
                        local pos = center + rdir * radius
                        local perp = Vector2.new(-rdir.Y, rdir.X)
                        local len = 13
                        tri.PointA = pos + rdir * len
                        tri.PointB = pos - rdir * (len * 0.7) + perp * (len * 0.58)
                        tri.PointC = pos - rdir * (len * 0.7) - perp * (len * 0.58)
                        local hue = (tick() * 0.35 + (i * 0.08)) % 1
                        tri.Color = Color3.fromHSV(hue, 0.9, 1)
                        tri.Visible = true
                        used[player] = true
                    end
                else
                    tri.Visible = false
                end
            end
        end
    end

    for player, tri in pairs(arrowObjects) do
        if not used[player] then
            tri.Visible = false
        end
    end
end

local function getHeldTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            return child
        end
    end
    return nil
end

local function getStorageItemForHeldTool()
    local heldTool = getHeldTool()
    if not heldTool then return nil end

    local rs = game:GetService("ReplicatedStorage")
    local storage = rs:FindFirstChild("StorageItems")
    if not storage then return nil end

    return storage:FindFirstChild(heldTool.Name)
        or storage:FindFirstChild(heldTool.Name:gsub(" Tool", ""))
        or storage:FindFirstChild(heldTool.Name:gsub("%s*%b[]", ""))
end

local function tryAutoReloadFromHookState()
    if not Settings.AutoReload then return end
    local now = tick()
    if now - lastReloadAt < Settings.AutoReloadCooldown then return end

    local refs = gameHooks.refs
    local gunBase = refs and refs.gunBase
    if type(gunBase) ~= "table" then return end

    local ammo = tonumber(gunBase.CurrentAmmo)
    if ammo == nil or ammo > 0 then return end

    local rs = game:GetService("ReplicatedStorage")
    local gunFolder = rs:FindFirstChild("Gun")
    local remotes = gunFolder and gunFolder:FindFirstChild("Remotes")
    local reloadRemote = remotes and remotes:FindFirstChild("Reload")
    if not reloadRemote then return end

    local storageItem = getStorageItemForHeldTool()
    if not storageItem then return end

    lastReloadAt = now
    pcall(function()
        reloadRemote:FireServer(storageItem, nil)
    end)
end

local function getSilentTargetPart(origin)
    local cam = getCamera()
    local originPos = typeof(origin) == "Vector3" and origin or (cam and cam.CFrame.Position) or Vector3.zero
    local bestPart = nil
    local bestScore = math.huge
    local cam = getCamera()
    if not cam then return nil end
    local center = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            if Settings.TeamCheck and player.Team == LocalPlayer.Team then
                continue
            end

            local char = player.Character
            if Settings.AliveCheck and not isAlive(char) then
                continue
            end

            local part = char:FindFirstChild(Settings.LockPart) or char:FindFirstChild("HumanoidRootPart")
            if part and part:IsA("BasePart") then
                local screenPos, onScreen = safeWorldToViewportPoint(part.Position)
                if not screenPos then continue end
                if onScreen and screenPos.Z > 0 then
                    if isVisible(part) then
                        local toTarget = (part.Position - originPos)
                        local mag = toTarget.Magnitude
                        if mag > 0.001 then
                            local dir = toTarget / mag
                            local forward = cam.CFrame.LookVector:Dot(dir)
                            if forward > 0.05 then
                                local crossDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                                if crossDist <= Settings.FOV then
                                    local score = crossDist + (1 - forward) * 30
                                    if score < bestScore then
                                        bestScore = score
                                        bestPart = part
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return bestPart
end

local function getClosestHead()
    local cam = getCamera()
    if not cam then return nil end

    local center = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5)
    local closest = nil
    local closestDist = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            if Settings.TeamCheck and player.Team == LocalPlayer.Team then
                continue
            end

            local head = player.Character:FindFirstChild("Head")
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if head and humanoid and humanoid.Health > 0 then
                local screenPos, onScreen = safeWorldToViewportPoint(head.Position)
                if screenPos and onScreen and screenPos.Z > 0 then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                    if dist < closestDist and dist <= Settings.FOV then
                        closestDist = dist
                        closest = head
                    end
                end
            end
        end
    end

    return closest
end

local function applyGunClientMods(gun)
    if type(gun) ~= "table" then return end

    if Settings.GunNoSpread then
        gun.BulletSpreadMult = 0
        gun.BaseBulletSpread = 0
        gun.MovementBulletSpreadMult = 0
        gun.AimSpreadMult = 0

        if type(gun.TotalAttachmentStats) == "table" then
            gun.TotalAttachmentStats.SpreadMult = 0
            gun.TotalAttachmentStats.AimSpreadMult = 0
        end
    end

    if Settings.GunGodMode then
        if type(gun.Animations) == "table" then
            gun.Animations.Equip = nil
        end
        if type(gun.AnimationHandler) == "table" then
            gun.AnimationHandler.playTrack = function() end
        end

        gun.FireDelay = math.clamp(toNumber(Settings.GunFireDelay, 0.01), 0.01, 0.05)
        gun.Range = math.huge
        if gun.MaxAmmo ~= nil then
            gun.CurrentAmmo = gun.MaxAmmo
        end

        if type(gun.RecoilHandler) == "table" then
            gun.RecoilHandler.RecoilMultiplier = 0
        end

        if type(gun.TotalAttachmentStats) == "table" then
            gun.TotalAttachmentStats.RecoilMult = 0.1
            gun.TotalAttachmentStats.SpreadMult = 0.1
        end
    end

    if type(gun.fire) == "function" and not gun.__linoriaManipWrapped then
        gun.__linoriaManipWrapped = true
        local oldFire = gun.fire

        gun.fire = function(self, first_shot, ...)
            local cam = getCamera()
            local targetHead = getClosestHead()
            local originalPos = nil
            local tracerFrom = (cam and cam.CFrame and cam.CFrame.Position) or nil
            local manipActive = Settings.ManipEnabled

            if manipActive and cam and targetHead and self.FireOriginPart then
                originalPos = self.FireOriginPart.Position
                local originPos = cam.CFrame.Position

                if Settings.ManipMode == "crazy" then
                    originPos = targetHead.Position + Vector3.new(math.random(-10, 10) / 100, 0.1, math.random(-10, 10) / 100)
                elseif Settings.ManipMode == "god" then
                    originPos = targetHead.Position - targetHead.CFrame.LookVector * 2.5
                elseif Settings.ManipMode == "tp" then
                    local char = LocalPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root then
                        local oldCF = root.CFrame
                        local behind = targetHead.Position - targetHead.CFrame.LookVector * 3 + Vector3.new(0, 2, 0)
                        root.CFrame = CFrame.new(behind)
                        task.delay(0.08, function()
                            if root.Parent then
                                root.CFrame = oldCF
                            end
                        end)
                    end
                end

                self.FireOriginPart.Position = originPos
                tracerFrom = originPos
            end

            local results = { oldFire(self, first_shot, ...) }

            if targetHead and tracerFrom then
                addBulletTracer(tracerFrom, targetHead.Position)
                playHitSound()
            end

            if self.FireOriginPart then
                local resetPos = originalPos or ((cam and cam.CFrame and cam.CFrame.Position) or self.FireOriginPart.Position)
                task.delay(0.001, function()
                    if self.FireOriginPart then
                        self.FireOriginPart.Position = resetPos
                    end
                end)
            end

            return (unpack or table.unpack)(results)
        end
    end
end

local function installGunClientNewHook(gunClient)
    if gunClientNewHook.installed or type(gunClient) ~= "table" or type(gunClient.new) ~= "function" then
        return
    end

    gunClientNewHook.original = gunClient.new
    gunClient.new = function(...)
        local gun = gunClientNewHook.original(...)
        if gun then
            RunService.Heartbeat:Wait()
            applyGunClientMods(gun)
        end
        return gun
    end
    gunClientNewHook.installed = true
end

local function installGameHooks()
    if gameHooks.installed then return true end

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ok, recoilHandler, gunClient, gunBase, viewModel = pcall(function()
        return require(ReplicatedStorage.Gun.Scripts.RecoilHandler),
            require(ReplicatedStorage.Gun.Scripts.GunClient),
            require(ReplicatedStorage.Gun.Scripts.GunBase),
            require(ReplicatedStorage.Gun.Scripts.ViewModel)
    end)

    if not ok then
        if not gameHooks.warned then
            warn("[Aimbot] Module hooks unavailable in this game")
            gameHooks.warned = true
        end
        return false
    end

    gameHooks.refs = {
        recoilHandler = recoilHandler,
        gunClient = gunClient,
        gunBase = gunBase,
        viewModel = viewModel,
    }

    gameHooks.originals.nextStep = recoilHandler.nextStep
    gameHooks.originals.createFireOffset = viewModel.createFireOffset
    gameHooks.originals.canFire = gunBase.canFire
    gameHooks.originals.getFireDirection = gunClient.getfireDirection

    recoilHandler.nextStep = function(self, ...)
        if Settings.NoRecoil then
            return
        end
        return gameHooks.originals.nextStep(self, ...)
    end

    viewModel.createFireOffset = function(self, ...)
        if Settings.NoRecoil then
            return
        end
        return gameHooks.originals.createFireOffset(self, ...)
    end

    gunBase.canFire = function(self, ...)
        if Settings.Jumpshoot then
            local ammo = self.CurrentAmmo > 0 or self.CurrentAmmo == -1
            local notEquipping = not self.Equipping
            local cooldown = not self.FiringOnCooldown
            local equipped = self.IsEquipped
            if ammo and notEquipping and cooldown and equipped then
                return true
            end
        end
        return gameHooks.originals.canFire(self, ...)
    end

    gunClient.getfireDirection = function(self, origin, mouse_hit, ...)
        local cam = getCamera()
        local originPos = typeof(origin) == "Vector3" and origin or (typeof(origin) == "CFrame" and origin.Position) or (cam and cam.CFrame.Position) or Vector3.zero

        if Settings.Wall then
            local Trgtt = nil
            local targetHead = getClosestHead()
            if targetHead then
                Trgtt = targetHead.Position
            elseif type(mouse_hit) == "table" and mouse_hit.Position then
                Trgtt = mouse_hit.Position
            elseif cam and cam.CFrame then
                Trgtt = cam.CFrame.Position + cam.CFrame.LookVector * (self.Range or 1000)
            end

            if Trgtt then
                local dirspf = Trgtt - originPos
                if dirspf.Magnitude > 0.001 then
                    return dirspf.Unit + Vector3.new(100, 0, 0)
                end
            end
        end

        if Settings.Enabled and Settings.AimbotType == "Silent" then
            local targetHead = getClosestHead()
            if targetHead then
                local perfectDir = (targetHead.Position - originPos)
                if perfectDir.Magnitude > 0.001 then
                    return perfectDir.Unit + Vector3.new(100, 0, 0)
                end
            end
        end
        return gameHooks.originals.getFireDirection(self, origin, mouse_hit, ...)
    end

    installGunClientNewHook(gunClient)

    gameHooks.installed = true
    notify("Gun module hooks installed")
    return true
end

local function installNoRadiationHook()
    if noRadHook.installed or not hookmetamethod then return end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod and getnamecallmethod()
        if Settings.NoRadiation and method == "FireServer" and tostring(self.Name) == "EnteredRadiationZone" then
            return task.wait(9e9)
        end
        return old(self, ...)
    end)
    noRadHook.original = old
    noRadHook.installed = true
end

RunService.RenderStepped:Connect(function()
    local cam = getCamera()
    if not cam then return end
    local vp = cam.ViewportSize
    fovCircle.Position = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    fovCircle.Radius = Settings.FOV
    fovCircle.Visible = Settings.ShowFOV

    -- ESP must update every frame independently of aimbot state.
    updateAllESP()
    updateOreESP()
    updateArrowESP()
    updateBulletTracers()
    applyWorldVisuals()

    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        if Settings.SpeedhackEnabled then
            humanoid.WalkSpeed = Settings.SpeedhackSpeed
        elseif humanoid.WalkSpeed ~= 16 then
            humanoid.WalkSpeed = 16
        end
    end

    if not Settings.Enabled then return end
    if Settings.Mode == "Hold" and not holding then return end

    if Settings.AimbotType ~= "Camera" then return end

    local target = getClosestPlayer()
    if target and target.Character then
        local targetPart = target.Character:FindFirstChild(Settings.LockPart)
        if targetPart then
            local targetPosition = getPredictedPosition(targetPart)
            local cameraPosition = cam.CFrame.Position

            -- IMPORTANT: true first-person lock (do not offset camera position)
            local newCFrame = CFrame.lookAt(cameraPosition, targetPosition)

            if Settings.Sensitivity > 0 then
                cam.CFrame = cam.CFrame:Lerp(newCFrame, Settings.Sensitivity)
            else
                cam.CFrame = newCFrame
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    installGameHooks()
    installNoRadiationHook()
    tryAutoReloadFromHookState()

    if Settings.NoFallDamage then
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if root and humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Climbing then
            local vel = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.zero
            RunService.RenderStepped:Wait()
            root.AssemblyLinearVelocity = vel
        end
    end
end)

CombatTab:Dropdown({
    Name = "Aimbot Type",
    StartingText = "Camera",
    Description = "Camera lock or Silent",
    Items = { "Camera", "Silent" },
    Callback = function(value)
        Settings.AimbotType = (value == "Silent") and "Silent" or "Camera"
        if Settings.AimbotType == "Silent" then
            installGameHooks()
        end
    end
})

CombatTab:Dropdown({
    Name = "Aim Part",
    StartingText = "Head",
    Description = "Target body part",
    Items = { "Head", "HumanoidRootPart" },
    Callback = function(value)
        Settings.LockPart = (value == "HumanoidRootPart") and "HumanoidRootPart" or "Head"
    end
})

local AimbotBind = CombatTab:Keybind({
    Name = "Aimbot Key",
    Keybind = Enum.KeyCode.Q,
    Mode = "Hold",
    Description = "Activation key (default: Hold + MB2; right-click to switch Toggle/Hold)",
    Callback = function(aimbot, active, mode)
        setAimKey(aimbot)

        Settings.Mode = (mode == "Hold") and "Hold" or "Toggle"
        if Settings.Mode == "Hold" then
            holding = active == true
            Settings.Enabled = active == true
            return
        end

        holding = false
        Settings.Enabled = active == true
        notify(Settings.Enabled and "Enabled" or "Disabled")
    end,
    ChangedCallback = function(_, mode)
        Settings.Mode = (mode == "Hold") and "Hold" or "Toggle"
        if Settings.Mode ~= "Hold" then
            holding = false
        end
    end,
})

CombatTab:Toggle({
    Name = "Team Check",
    StartingState = false,
    Description = "Ignore teammates",
    Callback = function(state)
        Settings.TeamCheck = state
    end
})

CombatTab:Toggle({
    Name = "Alive Check",
    StartingState = true,
    Description = "Only target alive players",
    Callback = function(state)
        Settings.AliveCheck = state
    end
})

CombatTab:Toggle({
    Name = "Wall Check",
    StartingState = true,
    Description = "Only visible targets",
    Callback = function(state)
        Settings.WallCheck = state
    end
})

CombatTab:Toggle({
    Name = "Show FOV Circle",
    StartingState = true,
    Description = "Draw FOV indicator",
    Callback = function(state)
        Settings.ShowFOV = state
    end
})

CombatTab:Slider({
    Name = "Smoothness",
    Default = 10,
    Min = 0,
    Max = 50,
    Precision = 0,
    Description = "0 = instant (scaled /100)",
    Callback = function(value)
        local raw = toNumber(value, 10)
        Settings.Sensitivity = math.clamp(raw / 100, 0, 0.50)
    end
})

CombatTab:Slider({
    Name = "Prediction",
    Default = 8,
    Min = 0,
    Max = 30,
    Precision = 0,
    Description = "Lead moving targets (scaled /100)",
    Callback = function(value)
        local raw = toNumber(value, 8)
        Settings.Prediction = math.clamp(raw / 100, 0, 0.30)
    end
})

CombatTab:Slider({
    Name = "FOV Radius",
    Default = 220,
    Min = 50,
    Max = 700,
    Precision = 0,
    Description = "Targeting radius",
    Callback = function(value)
        Settings.FOV = math.clamp(toNumber(value, 220), 50, 700)
    end
})

CombatTab:Toggle({
    Name = "ESP Enabled",
    StartingState = true,
    Description = "Master ESP toggle",
    Callback = function(state)
        Settings.ESPEnabled = state
    end
})

CombatTab:Toggle({
    Name = "ESP Team Check",
    StartingState = false,
    Description = "Hide teammates in ESP",
    Callback = function(state)
        Settings.ESPTeamCheck = state
    end
})

CombatTab:Toggle({
    Name = "ESP Team Color",
    StartingState = false,
    Description = "Color by team",
    Callback = function(state)
        Settings.ESPUseTeamColor = state
    end
})

CombatTab:Toggle({
    Name = "ESP Boxes",
    StartingState = true,
    Description = "2D player boxes",
    Callback = function(state)
        Settings.ESPBoxes = state
    end
})

CombatTab:Toggle({
    Name = "ESP Tracers",
    StartingState = true,
    Description = "Bottom tracers",
    Callback = function(state)
        Settings.ESPTracers = state
    end
})

CombatTab:Toggle({
    Name = "ESP Names",
    StartingState = true,
    Description = "Draw player names",
    Callback = function(state)
        Settings.ESPNames = state
    end
})

CombatTab:Toggle({
    Name = "ESP Distance",
    StartingState = true,
    Description = "Draw player distance",
    Callback = function(state)
        Settings.ESPDistance = state
    end
})

CombatTab:Toggle({
    Name = "ESP Health Bar",
    StartingState = true,
    Description = "Draw health bar",
    Callback = function(state)
        Settings.ESPHealthBar = state
    end
})

CombatTab:Slider({
    Name = "ESP Max Distance",
    Default = 3000,
    Min = 150,
    Max = 6000,
    Precision = 0,
    Description = "Cull distant players",
    Callback = function(value)
        Settings.ESPMaxDistance = math.clamp(toNumber(value, 3000), 150, 6000)
    end
})

CombatTab:Slider({
    Name = "ESP Thickness",
    Default = 2,
    Min = 1,
    Max = 4,
    Precision = 0,
    Description = "Line thickness",
    Callback = function(value)
        Settings.ESPThickness = math.clamp(toNumber(value, 2), 1, 4)
    end
})

CombatTab:Slider({
    Name = "ESP Text Size",
    Default = 13,
    Min = 12,
    Max = 18,
    Precision = 0,
    Description = "Name/distance text size",
    Callback = function(value)
        Settings.ESPTextSize = math.clamp(toNumber(value, 13), 12, 18)
    end
})


SettingsTab:Dropdown({
    Name = "ESP Style",
    StartingText = "Classic",
    Description = "Classic box or Planetary style",
    Items = { "Classic", "Planetary" },
    Callback = function(value)
        Settings.ESPStyle = (value == "Planetary") and "Planetary" or "Classic"
    end
})

SettingsTab:Dropdown({
    Name = "ESP Font",
    StartingText = "Plex",
    Description = "Text font for ESP labels",
    Items = { "UI", "System", "Plex", "Monospace" },
    Callback = function(value)
        if fontMap[value] then
            Settings.ESPFont = value
        end
    end
})



SettingsTab:Toggle({
    Name = "FOV Player Arrows",
    StartingState = true,
    Description = "Arrows around FOV circle",
    Callback = function(state)
        Settings.ArrowESP = state
    end
})

SettingsTab:Slider({
    Name = "Arrow Radius Offset",
    Default = 24,
    Min = 0,
    Max = 80,
    Precision = 0,
    Description = "Distance from FOV ring",
    Callback = function(value)
        Settings.ArrowRadiusOffset = math.clamp(toNumber(value, 24), 0, 80)
    end
})

SettingsTab:Button({
    Name = "Show Active Keybinds",
    Description = "Show current aimbot bind and mode",
    Callback = function()
        notify(string.format("Aimbot: %s | Mode: %s", formatBind(Settings.AimKey), Settings.Mode))
    end
})

MiscTab:Toggle({
    Name = "Speedhack Enabled",
    StartingState = false,
    Description = "Set WalkSpeed from slider",
    Callback = function(state)
        Settings.SpeedhackEnabled = state
    end
})

MiscTab:Slider({
    Name = "Speedhack Speed",
    Default = 16,
    Min = 0,
    Max = 40,
    Precision = 0,
    Description = "WalkSpeed value",
    Callback = function(value)
        Settings.SpeedhackSpeed = math.clamp(toNumber(value, 16), 0, 40)
    end
})

MiscTab:Toggle({
    Name = "Ore ESP Enabled",
    StartingState = false,
    Description = "Show ores in workspace.ores",
    Callback = function(state)
        Settings.OreESPEnabled = state
    end
})

MiscTab:Toggle({
    Name = "Iron ESP",
    StartingState = true,
    Description = "Show iron nodes",
    Callback = function(state)
        Settings.OreIron = state
    end
})

MiscTab:Toggle({
    Name = "Stone ESP",
    StartingState = true,
    Description = "Show stone nodes",
    Callback = function(state)
        Settings.OreStone = state
    end
})

MiscTab:Toggle({
    Name = "Sulfur ESP",
    StartingState = true,
    Description = "Show sulfur nodes",
    Callback = function(state)
        Settings.OreSulfur = state
    end
})

MiscTab:Toggle({
    Name = "Auto Reload",
    StartingState = false,
    Description = "Reload current held gun when ammo is empty",
    Callback = function(state)
        Settings.AutoReload = state
    end
})

MiscTab:Slider({
    Name = "Reload Cooldown",
    Default = 35,
    Min = 10,
    Max = 150,
    Precision = 0,
    Description = "Auto reload delay (scaled /100)",
    Callback = function(value)
        Settings.AutoReloadCooldown = math.clamp(toNumber(value, 35) / 100, 0.10, 1.50)
    end
})

MiscTab:Toggle({
    Name = "Gun No Spread",
    StartingState = false,
    Description = "Set gun spread multipliers to zero",
    Callback = function(state)
        Settings.GunNoSpread = state
    end
})

MiscTab:Toggle({
    Name = "Gun God Mode",
    StartingState = false,
    Description = "Apply fast fire/range/ammo/recoil gun mods",
    Callback = function(state)
        Settings.GunGodMode = state
    end
})

MiscTab:Slider({
    Name = "Gun Fire Delay",
    Default = 1,
    Min = 1,
    Max = 5,
    Precision = 0,
    Description = "God mode fire delay (scaled /100, 0.01 - 0.05)",
    Callback = function(value)
        Settings.GunFireDelay = math.clamp(toNumber(value, 1) / 100, 0.01, 0.05)
    end
})

MiscTab:Toggle({
    Name = "Bullet Tracers",
    StartingState = true,
    Description = "Draw short-lived bullet tracer lines",
    Callback = function(state)
        Settings.BulletTracerEnabled = state
    end
})

MiscTab:Slider({
    Name = "Tracer Lifetime",
    Default = 35,
    Min = 5,
    Max = 100,
    Precision = 0,
    Description = "Tracer life (scaled /100)",
    Callback = function(value)
        Settings.BulletTracerLifetime = math.clamp(toNumber(value, 35) / 100, 0.05, 1)
    end
})

MiscTab:Slider({
    Name = "Tracer Thickness",
    Default = 2,
    Min = 1,
    Max = 6,
    Precision = 0,
    Description = "Bullet tracer line thickness",
    Callback = function(value)
        Settings.BulletTracerThickness = math.clamp(toNumber(value, 2), 1, 6)
    end
})

MiscTab:Toggle({
    Name = "Hit Sound",
    StartingState = false,
    Description = "Play sound when a traced shot is fired",
    Callback = function(state)
        Settings.HitSoundEnabled = state
    end
})

MiscTab:Dropdown({
    Name = "Hit Sound Type",
    StartingText = "Neverlose",
    Description = "Choose hit sound",
    Items = { "Neverlose", "Bell", "Bubble", "Minecraft" },
    Callback = function(value)
        if hitSoundIds[value] then
            Settings.HitSound = value
        end
    end
})

MiscTab:Slider({
    Name = "Hit Sound Volume",
    Default = 5,
    Min = 0,
    Max = 10,
    Precision = 0,
    Description = "Volume (scaled /10)",
    Callback = function(value)
        Settings.HitSoundVolume = math.clamp(toNumber(value, 5) / 10, 0, 1)
    end
})

MiscTab:Toggle({
    Name = "No Fog",
    StartingState = false,
    Description = "Disable map fog",
    Callback = function(state)
        Settings.NoFog = state
    end
})

MiscTab:Toggle({
    Name = "Custom Skybox",
    StartingState = false,
    Description = "Enable custom skybox",
    Callback = function(state)
        Settings.SkyboxEnabled = state
    end
})

MiscTab:Dropdown({
    Name = "Skybox Preset",
    StartingText = "Purple",
    Description = "Custom skybox preset",
    Items = { "Purple", "Galaxy", "Vibe" },
    Callback = function(value)
        if skyboxPresets[value] then
            Settings.SkyboxPreset = value
        end
    end
})

MiscTab:Toggle({
    Name = "Wall",
    StartingState = false,
    Description = "nice",
    Callback = function(state)
        Settings.Wall = state
        if state then
            installGameHooks()
        end
    end
})

MiscTab:Toggle({
    Name = "Manip Enabled",
    StartingState = false,
    Description = "Enable fire origin manipulation",
    Callback = function(state)
        Settings.ManipEnabled = state
    end
})

MiscTab:Dropdown({
    Name = "Manip Mode",
    StartingText = "classic",
    Description = "classic / crazy / god / tp",
    Items = { "classic", "crazy", "god", "tp" },
    Callback = function(value)
        Settings.ManipMode = value
    end
})

MiscTab:Toggle({
    Name = "No Recoil",
    StartingState = false,
    Description = "Disables recoil handler step",
    Callback = function(state)
        Settings.NoRecoil = state
    end
})

MiscTab:Toggle({
    Name = "Jumpshoot",
    StartingState = false,
    Description = "Allow firing while jumping",
    Callback = function(state)
        Settings.Jumpshoot = state
    end
})

MiscTab:Toggle({
    Name = "No Radiation",
    StartingState = false,
    Description = "Blocks EnteredRadiationZone remote",
    Callback = function(state)
        Settings.NoRadiation = state
    end
})

MiscTab:Toggle({
    Name = "No Fall Damage",
    StartingState = false,
    Description = "Velocity null on heartbeat",
    Callback = function(state)
        Settings.NoFallDamage = state
    end
})

LocalPlayer.CharacterRemoving:Connect(function()
    Settings.Enabled = false
    holding = false
    clearOreESP()
    clearArrowESP()
    clearBulletTracers()
end)

Players.PlayerRemoving:Connect(function(player)
    removeESPObject(player)
    if player ~= LocalPlayer then return end
    if fovCircle then
        fovCircle:Remove()
    end
    for trackedPlayer in pairs(espObjects) do
        removeESPObject(trackedPlayer)
    end
    clearOreESP()
    clearArrowESP()
    clearBulletTracers()
end)

Players.PlayerAdded:Connect(function(player)
    player.CharacterRemoving:Connect(function()
        local obj = espObjects[player]
        if obj then
            hideESPObject(obj)
        end
    end)
end)


local ConfigTab = Window:AddTab("UI Settings")
local MenuGroup = ConfigTab:AddLeftGroupbox("Menu")

MenuGroup:AddButton("Unload", function()
    Library:Unload()
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
if Library.KeybindFrame then
    Library.KeybindFrame.Visible = true
end
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
ThemeManager:SetFolder("Merucury")
SaveManager:SetFolder("Merucury/configs")
SaveManager:BuildConfigSection(ConfigTab)
ThemeManager:ApplyToTab(ConfigTab)
SaveManager:LoadAutoloadConfig()

print("[Aimbot] Linoria UI + SaveManager/ThemeManager config extension ready")
