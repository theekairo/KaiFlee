-- KaiFlee + Infinite Yield | made by nexus | .gg/znwCgvzBgu
local function sharedEnvironment()
    if type(getgenv) == "function" then
        local ok, value = pcall(getgenv)
        if ok and type(value) == "table" then return value end
    end
    return _G
end
local environment = sharedEnvironment()
local runtimeKey = "__KaiFleeRuntime"
local startupState, startupCleanup, startInfiniteYield
local function startKaiFlee()
-- KaiFlee 3.6 | made by nexus | .gg/znwCgvzBgu
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
assert(player, "KaiFlee: нужен клиент Roblox")
local playerGui = player:WaitForChild("PlayerGui", 15)
assert(playerGui, "KaiFlee: интерфейс игрока не загрузился")
local previous = playerGui:FindFirstChild("KaiFlee")
if previous then
    print("KaiFlee уже запущен. Правый Shift — меню. Повторная инициализация отменена.")
    return
end

local config = {
    esp = true, names = false,
    computers = true, pods = true, throughWalls = true,
    fullbright = false,
    autoRescue = false, noFail = false, slowBeast = false, untie = false,
    dangerCue = false, dangerRadius = 60,
}
local defaults = table.clone(config)
local ESP_DISTANCE = 5000
local theme = {
    background = Color3.fromRGB(17, 18, 21),
    card = Color3.fromRGB(28, 29, 34), hover = Color3.fromRGB(35, 37, 43),
    line = Color3.fromRGB(45, 47, 55), text = Color3.fromRGB(239, 241, 245),
    muted = Color3.fromRGB(135, 141, 153), white = Color3.fromRGB(240, 243, 248),
    red = Color3.fromRGB(255, 74, 91), cyan = Color3.fromRGB(78, 207, 255),
    green = Color3.fromRGB(91, 221, 133), blue = Color3.fromRGB(70, 125, 255),
}
local fonts = {
    regular = Font.fromName("BuilderSans", Enum.FontWeight.Regular),
    medium = Font.fromName("BuilderSans", Enum.FontWeight.Medium),
    bold = Font.fromName("BuilderSans", Enum.FontWeight.Bold),
}
local WIDTH, HEIGHT = 640, 500
local connections, objects, records, pages, tabs, painters = {}, {}, {}, {}, {}, {}
local scanJobs, fadeGroups, fadeEntries = {}, {}, {}
local fadeDirty, markerBudget = false, 0
local function assign(object, key, value)
    if object[key] ~= value then object[key] = value end
end
local buttonMotions, toggleMotions = {}, {}
local optionCallbacks = {}
local alive, cleanup, activeSlider, drag = true, nil, nil, nil
local menuRequested, introDone, introAge = true, false, 0
local powerText
local selectedPage = "Visuals"
local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end
local function make(className, properties, parent)
    local opacity
    if className == "CanvasGroup" then
        className = "Frame"
        properties = table.clone(properties or {})
        opacity = 1 - (properties.GroupTransparency or 0)
        properties.GroupTransparency = nil
    end
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do object[key] = value end
    object.Parent = parent
    if opacity then fadeGroups[object] = opacity end
    return object
end
local function corner(object, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, object)
end
local function stroke(object)
    return make("UIStroke", {Color = theme.line, Thickness = 1}, object)
end
local function spring(value, frequency, damping)
    return {value = value, target = value, velocity = 0, frequency = frequency or 5, damping = damping or 0.72}
end
local function advance(state, delta)
    if delta <= 0 then return state.value end
    local omega = 2 * math.pi * state.frequency
    local decay = state.damping * omega
    local oscillation = omega * math.sqrt(1 - state.damping * state.damping)
    local offset = state.value - state.target
    local cosine, sine = math.cos(oscillation * delta), math.sin(oscillation * delta)
    local envelope = math.exp(-decay * delta)
    local velocity = state.velocity
    state.value = state.target + envelope * (offset * cosine + (velocity + decay * offset) / oscillation * sine)
    state.velocity = envelope * (velocity * cosine - (decay * velocity + omega * omega * offset) / oscillation * sine)
    if math.abs(state.value - state.target) < 0.0001 and math.abs(state.velocity) < 0.0001 then
        state.value, state.velocity = state.target, 0
    end
    return state.value
end
local function moving(state)
    return state.value ~= state.target or state.velocity ~= 0
end
local function setOpacity(group, opacity)
    opacity = math.clamp(opacity, 0, 1)
    if fadeGroups[group] ~= opacity then fadeGroups[group], fadeDirty = opacity, true end
end
local function prepareFades(rootGui)
    for _, object in ipairs(rootGui:GetDescendants()) do
        local groups, ancestor = {}, object
        while ancestor and ancestor ~= rootGui do
            if fadeGroups[ancestor] ~= nil then table.insert(groups, ancestor) end
            ancestor = ancestor.Parent
        end
        if #groups == 0 then continue end
        local properties = {}
        if object:IsA("GuiObject") then
            properties.BackgroundTransparency = object.BackgroundTransparency or 0
            if object:IsA("TextLabel") or object:IsA("TextButton") then
                properties.TextTransparency = object.TextTransparency or 0
                properties.TextStrokeTransparency = object.TextStrokeTransparency or 1
            elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
                properties.ImageTransparency = object.ImageTransparency or 0
            end
            if object:IsA("ScrollingFrame") then properties.ScrollBarImageTransparency = object.ScrollBarImageTransparency or 0 end
        elseif object:IsA("UIStroke") then properties.Transparency = object.Transparency or 0 end
        if next(properties) then table.insert(fadeEntries, {object = object, groups = groups, properties = properties}) end
    end
    fadeDirty = true
end
local function flushFades()
    if not fadeDirty then return end
    fadeDirty = false
    for _, entry in ipairs(fadeEntries) do
        if not entry.object.Parent then continue end
        local opacity = 1
        for _, group in ipairs(entry.groups) do opacity = opacity * (fadeGroups[group] or 0) end
        for property, base in pairs(entry.properties) do assign(entry.object, property, 1 - (1 - base) * opacity) end
    end
end
local function queueScan(rootObject, callback)
    table.insert(scanJobs, {root = rootObject, callback = callback, stack = {{object = rootObject, index = 0}}})
end
local function stepScans()
    local deadline, remaining = os.clock() + 0.001, 80
    for jobIndex = #scanJobs, 1, -1 do
        local job = scanJobs[jobIndex]
        while #job.stack > 0 and remaining > 0 and os.clock() < deadline do
            local frame = job.stack[#job.stack]
            if not frame.children then frame.children = frame.object:GetChildren() end
            frame.index = frame.index + 1
            local child = frame.children[frame.index]
            if not child then table.remove(job.stack)
            else
                remaining = remaining - 1
                if child:IsDescendantOf(job.root) and child.Name ~= "KaiFlee" and child.Name ~= "KaiFleeEffects" then
                    job.callback(child)
                    table.insert(job.stack, {object = child, index = 0})
                end
            end
        end
        if #job.stack == 0 then table.remove(scanJobs, jobIndex) end
        if remaining <= 0 or os.clock() >= deadline then break end
    end
end
local function label(parent, text, size, position, dimensions, color, bold)
    return make("TextLabel", {
        BackgroundTransparency = 1, Text = text, TextSize = (size or 15) + 3,
        Position = position or UDim2.new(), Size = dimensions or UDim2.fromScale(1, 1),
        FontFace = bold and fonts.bold or fonts.regular,
        TextColor3 = color or theme.text, TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0, RichText = false,
    }, parent)
end
local function button(parent, text, position, dimensions)
    local object = make("TextButton", {
        BackgroundColor3 = theme.card, TextColor3 = theme.text,
        Text = text, TextSize = 17, FontFace = fonts.medium,
        Position = position, Size = dimensions, BorderSizePixel = 0,
        AutoButtonColor = false,
    }, parent)
    corner(object, 7)
    local size = make("UIScale", {Scale = 1}, object)
    local motion = {object = object, scale = size, spring = spring(1, 6, 0.66), hover = false}
    table.insert(buttonMotions, motion)
    connect(object.MouseEnter, function() motion.hover = true; motion.spring.target = 1.015 end)
    connect(object.MouseLeave, function() motion.hover = false; motion.spring.target = 1 end)
    connect(object.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then motion.spring.target = 0.965 end
    end)
    connect(object.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then motion.spring.target = motion.hover and 1.015 or 1 end
    end)
    return object
end
local gui = make("ScreenGui", {
    Name = "KaiFlee", ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
startupCleanup = function()
    alive = false
    for _, connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
    table.clear(scanJobs)
    table.clear(fadeEntries)
    table.clear(fadeGroups)
    local partialEffects = Workspace:FindFirstChild("KaiFleeEffects")
    if partialEffects then partialEffects:Destroy() end
    gui:Destroy()
end
local shutdown = make("BindableEvent", {Name = "Shutdown"}, gui)
local effects = make("Folder", {Name = "KaiFleeEffects"}, Workspace)
local shell = make("Frame", {
    Name = "Menu", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(WIDTH, HEIGHT),
    Visible = false, BorderSizePixel = 0,
}, gui)
local fitScale = make("UIScale", {Scale = 1}, shell)
local window = make("CanvasGroup", {
    Name = "Window", BackgroundColor3 = theme.background,
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromScale(1, 1), GroupTransparency = 1, BorderSizePixel = 0,
}, shell)
corner(window, 12)
stroke(window)
local windowScale = make("UIScale", {Scale = 0.95}, window)
local windowSizeMotion, windowOpacity, windowOffset = spring(0.95, 4.5, 0.7), spring(0, 5, 0.9), spring(14, 4.5, 0.7)
local pageMotion, pageOpacity = spring(0, 5, 0.72), spring(1, 6, 0.9)
local tabMotion = spring(0, 5.5, 0.72)
local titlebar = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -58, 0, 62), Active = true}, window)
label(titlebar, "KaiFlee", 25, UDim2.fromOffset(24, 12), UDim2.fromOffset(160, 38), nil, true)
local avatar = make("ImageLabel", {
    BackgroundColor3 = theme.card, BorderSizePixel = 0, Image = "",
    Position = UDim2.new(1, -172, 0, 17), Size = UDim2.fromOffset(28, 28),
}, titlebar)
corner(avatar, 14)
local displayName = label(titlebar, player.DisplayName, 13, UDim2.new(1, -134, 0, 18), UDim2.fromOffset(126, 25), theme.muted)
displayName.TextTruncate = Enum.TextTruncate.AtEnd
local close = button(window, "×", UDim2.new(1, -48, 0, 20), UDim2.fromOffset(25, 25))
close.TextSize = 24
close.BackgroundTransparency = 1
local tabBar = make("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 70), Size = UDim2.fromOffset(WIDTH - 48, 33)}, window)
local selectedTab = make("Frame", {BackgroundColor3 = theme.card, BorderSizePixel = 0, Size = UDim2.fromOffset(142, 33)}, tabBar)
corner(selectedTab, 7)
label(window, "правый shift — меню", 11, UDim2.fromOffset(24, 466), UDim2.fromOffset(470, 20), theme.muted)
local version = label(window, "3.6", 11, UDim2.new(1, -70, 0, 466), UDim2.fromOffset(46, 20), theme.muted)
version.TextXAlignment = Enum.TextXAlignment.Right
local function selectPage(name)
    activeSlider = nil
    if selectedPage ~= name then
        pageMotion.value, pageMotion.velocity, pageMotion.target = 12, 0, 0
        pageOpacity.value, pageOpacity.velocity, pageOpacity.target = 0.2, 0, 1
    end
    selectedPage = name
    for key, item in pairs(pages) do
        item.group.Visible = key == name
        tabs[key].TextColor3 = key == name and theme.text or theme.muted
    end
    if pages[name] then tabMotion.target = pages[name].order * 150 end
end
local function page(name, order, title)
    local tab = button(tabBar, title, UDim2.fromOffset(order * 150, 0), UDim2.fromOffset(142, 33))
    tab.BackgroundTransparency = 1
    local group = make("CanvasGroup", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 120),
        Size = UDim2.fromOffset(WIDTH - 48, 326), Visible = false,
    }, window)
    local panel = make("ScrollingFrame", {
        Name = name, BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), ScrollBarThickness = 2,
        ScrollBarImageColor3 = theme.muted, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
    }, group)
    make("UIListLayout", {Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder}, panel)
    make("UIPadding", {PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4)}, panel)
    pages[name], tabs[name] = {group = group, panel = panel, order = order}, tab
    connect(tab.Activated, function() selectPage(name) end)
    return panel
end
local visuals = page("Visuals", 0, "ESP")
local automation = page("Automation", 1, "Автоматика")
local trolling = page("Trolling", 2, "Троллинг")
local settings = page("Settings", 3, "Настройки")
local function card(parent, height, order)
    local item = make("Frame", {BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, height), LayoutOrder = order}, parent)
    make("Frame", {BackgroundColor3 = theme.line, BackgroundTransparency = 0.5, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1)}, item)
    return item
end
local featureNotes = {
    slowBeast = "Не работает · отключено, надпись сохранена",
    untie = "Не работает · отключено, надпись сохранена",
    noFail = "Частично работает · возможны пропуски",
    autoRescue = "Не проверено в игре",
}
local featureLabels = {}
local function status(key, text)
    local item = featureLabels[key]
    if item then
        if item.Text ~= text then item.Text = text end
        if item.Visible ~= (text ~= "") then item.Visible = text ~= "" end
    end
end
local function setOption(key, value)
    if config[key] == nil or type(value) ~= type(config[key]) then return false, "Неверный параметр" end
    if type(value) == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return false, "Неверное число" end
        local bounds = {dangerRadius = {15, 150}}
        if bounds[key] then value = math.clamp(value, bounds[key][1], bounds[key][2]) end
    end
    if key == "slowBeast" or key == "untie" then
        return false, "Функция не работает и отключена"
    end
    if config[key] == value then return true end
    config[key] = value
    if optionCallbacks[key] then optionCallbacks[key](value) end
    if painters[key] then painters[key]() end
    return true
end
local function toggle(parent, key, title, order, changed, hasStatus)
    local note = featureNotes[key]
    local item = card(parent, note and 98 or (hasStatus and 76 or 56), order)
    local titleLabel = label(item, title, 15, UDim2.fromOffset(8, hasStatus and 6 or 0), UDim2.new(1, -82, 0, hasStatus and 32 or 56))
    titleLabel.FontFace = fonts.medium
    if note then
        local noteLabel = label(item, note, 11, UDim2.fromOffset(8, 39), UDim2.new(1, -82, 0, 21),
            key == "autoRescue" and theme.muted or ((key == "slowBeast" or key == "untie") and theme.red or Color3.fromRGB(223, 179, 104)))
        noteLabel.Name = "FeatureNote_" .. key
    end
    if hasStatus then
        featureLabels[key] = label(item, "", 11, UDim2.fromOffset(8, note and 64 or 40), UDim2.new(1, -82, 0, 24), theme.muted)
    end
    local switch = button(item, "", UDim2.new(1, -52, 0.5, -11), UDim2.fromOffset(42, 22))
    if key == "slowBeast" or key == "untie" then
        switch.Active, switch.Selectable = false, false
    end
    corner(switch, 11)
    local thumb = make("Frame", {BorderSizePixel = 0, Size = UDim2.fromOffset(14, 14)}, switch)
    corner(thumb, 7)
    local state = spring(config[key] and 1 or 0, 6, 0.68)
    table.insert(toggleMotions, {switch = switch, thumb = thumb, state = state})
    painters[key] = function()
        state.target = config[key] and 1 or 0
        if featureLabels[key] then
            featureLabels[key].Visible = config[key]
            if not config[key] then featureLabels[key].Text = "" end
        end
    end
    painters[key]()
    optionCallbacks[key] = changed
    connect(switch.Activated, function()
        setOption(key, not config[key])
    end)
end
local function slider(parent, key, title, low, high, step, suffix, order, changed)
    local item = card(parent, 72, order)
    label(item, title, 14, UDim2.fromOffset(8, 3), UDim2.new(1, -126, 0, 32))
    local readout = label(item, "", 12, UDim2.new(1, -119, 0, 3), UDim2.fromOffset(109, 32), theme.muted)
    readout.TextXAlignment = Enum.TextXAlignment.Right
    local track = make("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 40), Size = UDim2.new(1, -20, 0, 24)}, item)
    local bar = make("Frame", {BackgroundColor3 = theme.line, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0.5, -2), Size = UDim2.new(1, 0, 0, 4)}, track)
    corner(bar, 2)
    local fill = make("Frame", {BackgroundColor3 = theme.white, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1)}, bar)
    corner(fill, 2)
    local knob = make("Frame", {BackgroundColor3 = theme.white, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10)}, bar)
    corner(knob, 5)
    local function paint()
        local fraction = (config[key] - low) / (high - low)
        fill.Size = UDim2.fromScale(fraction, 1)
        knob.Position = UDim2.fromScale(fraction, 0.5)
        readout.Text = tostring(config[key]) .. suffix
    end
    painters[key] = paint
    optionCallbacks[key] = changed
    paint()
    local function setAt(x)
        if track.AbsoluteSize.X <= 0 then return end
        local fraction = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        config[key] = math.clamp(low + math.floor(fraction * (high - low) / step + 0.5) * step, low, high)
        paint()
        if changed then changed(config[key]) end
    end
    connect(track.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            activeSlider = {set = setAt, input = input, touch = input.UserInputType == Enum.UserInputType.Touch}
            setAt(input.Position.X)
        end
    end)
end

local splash = make("CanvasGroup", {
    Name = "Intro", BackgroundColor3 = theme.background, AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(320, 192),
    GroupTransparency = 1, BorderSizePixel = 0,
}, gui)
corner(splash, 14)
stroke(splash)
local splashScale = make("UIScale", {Scale = 0.8}, splash)
local introScale, introOpacity = spring(0.8, 3.6, 0.62), spring(0, 4, 0.9)
introScale.target, introOpacity.target = 1, 1
local logo = make("Frame", {
    BackgroundColor3 = theme.white, AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 25), Size = UDim2.fromOffset(56, 56), BorderSizePixel = 0,
}, splash)
corner(logo, 13)
local logoText = label(logo, "K", 34, UDim2.new(), UDim2.fromScale(1, 1), theme.background, true)
logoText.TextXAlignment = Enum.TextXAlignment.Center
local splashTitle = label(splash, "KaiFlee", 25, UDim2.fromOffset(0, 94), UDim2.new(1, 0, 0, 36), nil, true)
splashTitle.TextXAlignment = Enum.TextXAlignment.Center
local progress = make("Frame", {BackgroundColor3 = theme.line, BorderSizePixel = 0, Position = UDim2.fromOffset(48, 154), Size = UDim2.new(1, -96, 0, 3)}, splash)
corner(progress, 2)
local progressFill = make("Frame", {BackgroundColor3 = theme.white, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1)}, progress)
corner(progressFill, 2)
local function setVisible(visible)
    menuRequested = visible
    activeSlider, drag = nil, nil
    windowSizeMotion.target = visible and 1 or 0.95
    windowOpacity.target = visible and introDone and 1 or 0
    windowOffset.target = visible and 0 or 12
    if visible and introDone then shell.Visible = true end
    if not introDone and splash.Parent then splash.Visible = visible end
end
local dangerFrame = make("Frame", {
    Name = "DangerCue", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
    Visible = false, Active = false, BorderSizePixel = 0,
}, gui)
local dangerBars = {}
for _, point in ipairs({Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1)}) do
    for _, dimensions in ipairs({Vector2.new(90, 3), Vector2.new(3, 70)}) do
        table.insert(dangerBars, make("Frame", {
            AnchorPoint = point, Position = UDim2.fromScale(point.X, point.Y),
            Size = UDim2.fromOffset(dimensions.X, dimensions.Y), BackgroundColor3 = theme.red,
            BackgroundTransparency = 1, BorderSizePixel = 0,
        }, dangerFrame))
    end
end
local dangerMotion = spring(0, 4, 0.9)
connect(close.Activated, function() setVisible(false) end)
local function viewportSize()
    return Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
end
local function clampWindow()
    local viewport = viewportSize()
    local width, height = WIDTH * fitScale.Scale, HEIGHT * fitScale.Scale
    local x = shell.Position.X.Scale * viewport.X + shell.Position.X.Offset
    local y = shell.Position.Y.Scale * viewport.Y + shell.Position.Y.Offset
    shell.Position = UDim2.fromOffset(math.clamp(x, width / 2 + 8, math.max(width / 2 + 8, viewport.X - width / 2 - 8)), math.clamp(y, height / 2 + 8, math.max(height / 2 + 8, viewport.Y - height / 2 - 8)))
end
connect(titlebar.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        drag = {input = input, point = input.Position, origin = shell.Position, touch = input.UserInputType == Enum.UserInputType.Touch}
    end
end)
connect(Input.InputChanged, function(input)
    if activeSlider and ((activeSlider.touch and input == activeSlider.input) or (not activeSlider.touch and input.UserInputType == Enum.UserInputType.MouseMovement)) then activeSlider.set(input.Position.X) end
    if drag and ((drag.touch and input == drag.input) or (not drag.touch and input.UserInputType == Enum.UserInputType.MouseMovement)) then
        local delta = input.Position - drag.point
        shell.Position = UDim2.new(drag.origin.X.Scale, drag.origin.X.Offset + delta.X, drag.origin.Y.Scale, drag.origin.Y.Offset + delta.Y)
        clampWindow()
    end
end)
connect(Input.InputEnded, function(input)
    if activeSlider and (input == activeSlider.input or (not activeSlider.touch and input.UserInputType == Enum.UserInputType.MouseButton1)) then activeSlider = nil end
    if drag and (input == drag.input or (not drag.touch and input.UserInputType == Enum.UserInputType.MouseButton1)) then drag = nil end
end)
connect(Input.InputBegan, function(input, processed)
    if processed or Input:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.RightShift then setVisible(not menuRequested) end
end)
local lightingOriginal, lightingOverrides, changingLighting = {}, {
    Brightness = 2, ClockTime = 14, FogEnd = 100000,
    Ambient = Color3.fromRGB(180, 180, 180),
    OutdoorAmbient = Color3.fromRGB(180, 180, 180), GlobalShadows = false,
}, false
for key in pairs(lightingOverrides) do
    lightingOriginal[key] = Lighting[key]
    connect(Lighting:GetPropertyChangedSignal(key), function()
        if changingLighting then return end
        lightingOriginal[key] = Lighting[key]
        if config.fullbright then
            changingLighting = true
            Lighting[key] = lightingOverrides[key]
            changingLighting = false
        end
    end)
end
local function updateLighting()
    changingLighting = true
    for key, value in pairs(lightingOverrides) do
        if config.fullbright then
            Lighting[key] = value
        else
            Lighting[key] = lightingOriginal[key]
        end
    end
    changingLighting = false
end
toggle(visuals, "esp", "ESP игроков", 1)
toggle(visuals, "names", "Ники игроков", 2)
toggle(visuals, "computers", "Компьютеры", 3)
toggle(visuals, "pods", "Капсулы", 4)
toggle(automation, "autoRescue", "Автоспасение", 1, nil, true)
toggle(automation, "noFail", "Взлом без ошибок", 2, nil, true)
toggle(automation, "dangerCue", "Предупреждение об опасности", 3)
slider(automation, "dangerRadius", "Радиус предупреждения", 15, 150, 5, "", 4)
toggle(trolling, "slowBeast", "Замедление чудовища", 1, nil, true)
toggle(trolling, "untie", "Автоотвязка мирных", 2, nil, true)
local powerCard = card(trolling, 52, 3)
powerText = label(powerCard, "Ожидание способности чудовища", 12, UDim2.fromOffset(8, 0), UDim2.new(1, -16, 1, 0), theme.muted)
toggle(settings, "throughWalls", "ESP сквозь стены", 1)
toggle(settings, "fullbright", "Яркое освещение", 2, updateLighting)
local resetCard = card(settings, 56, 3)
local reset = button(resetCard, "Сбросить настройки", UDim2.fromOffset(8, 8), UDim2.new(1, -16, 0, 35))
local unloadCard = card(settings, 56, 4)
local unload = button(unloadCard, "Выгрузить KaiFlee", UDim2.fromOffset(8, 8), UDim2.new(1, -16, 0, 35))
connect(unload.Activated, function() if cleanup then cleanup() end end)
local yieldCard = card(settings, 80, 5)
local yieldButton = button(yieldCard, "Запустить Infinite Yield", UDim2.fromOffset(8, 6), UDim2.new(1, -16, 0, 35))
label(yieldCard, "Отдельный запуск снижает нагрузку при входе", 11, UDim2.fromOffset(8, 48), UDim2.new(1, -16, 0, 24), theme.muted)
connect(yieldButton.Activated, function()
    task.spawn(function()
        if not alive then return end
        yieldButton.Text = "Infinite Yield · загрузка"
        local ok, message = pcall(startInfiniteYield)
        if not alive then return end
        local state = environment.__KaiFleeInfiniteYieldLoader
        yieldButton.Text = environment.IY_LOADED and "Infinite Yield запущен" or "Запустить Infinite Yield"
        if not ok then warn("Infinite Yield: " .. tostring(message))
        elseif state and state.error then yieldButton.Text = "Infinite Yield · повторить загрузку" end
    end)
end)
local control = make("BindableFunction", {Name = "Control"}, gui)
control.OnInvoke = function(command, key, value)
    if command == "set" then return setOption(key, value) end
    if command == "get" then
        if key ~= nil then return config[key] end
        return table.clone(config)
    end
    if command == "show" then setVisible(key == true); return true end
    if command == "pause" or command == "paused" then return false end
    if command == "status" then
        local snapshot = {}
        for name, item in pairs(featureLabels) do snapshot[name] = item.Text end
        return key and snapshot[key] or snapshot
    end
    return false, "Неизвестная команда"
end
local function statsFor(target)
    return target:FindFirstChild("TempPlayerStatsModule") or target:FindFirstChild("PlayerStatsModule")
end
local function stat(target, name)
    local stats = statsFor(target)
    local value = stats and stats:FindFirstChild(name)
    if value and value:IsA("ValueBase") then return value.Value end
    return target:GetAttribute(name)
end
local function isBeast(target)
    local value = stat(target, "IsBeast")
    if type(value) == "boolean" then return value end
    if value == 1 then return true end
    local character = target.Character
    if character then
        local attribute = character:GetAttribute("IsBeast")
        if type(attribute) == "boolean" then return attribute end
        if character:FindFirstChild("Hammer") then return true end
    end
    return false
end

local function clearMarkers(record)
    if record.highlight then record.highlight:Destroy(); record.highlight = nil end
    if record.billboard then record.billboard:Destroy(); record.billboard = nil end
    record.nameTag, record.character = nil, nil
end
local function buildMarkers(record, character)
    clearMarkers(record)
    if markerBudget <= 0 then return false end
    markerBudget = markerBudget - 1
    record.character = character
    record.highlight = make("Highlight", {
        Name = "Player_" .. record.player.UserId, Adornee = character,
        FillTransparency = 1, OutlineTransparency = 0, Enabled = false,
    }, effects)
    return true
end
local function updateNameTag(record, anchor, color, visible)
    if not config.names or not visible then
        if record.billboard then record.billboard:Destroy(); record.billboard, record.nameTag = nil, nil end
        return
    end
    if not record.billboard then
        record.billboard = make("BillboardGui", {
            Name = "PlayerName_" .. record.player.UserId, Size = UDim2.fromOffset(200, 25),
            StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0), AlwaysOnTop = true,
            Enabled = false, LightInfluence = 0,
        }, gui)
        record.nameTag = label(record.billboard, record.player.DisplayName, 13, UDim2.new(), UDim2.fromScale(1, 1), color)
        record.nameTag.TextXAlignment = Enum.TextXAlignment.Center
        record.nameTag.TextStrokeColor3 = Color3.new(0, 0, 0)
        record.nameTag.TextStrokeTransparency = 0.35
    end
    assign(record.billboard, "Adornee", anchor)
    assign(record.billboard, "MaxDistance", ESP_DISTANCE)
    assign(record.billboard, "AlwaysOnTop", config.throughWalls)
    assign(record.billboard, "Enabled", true)
    assign(record.nameTag, "TextColor3", color)
end
local function addPlayer(target)
    if target ~= player and not records[target] then records[target] = {player = target} end
end
local function removePlayer(target)
    if records[target] then clearMarkers(records[target]); records[target] = nil end
end
connect(Players.PlayerAdded, addPlayer)
connect(Players.PlayerRemoving, removePlayer)
for _, target in ipairs(Players:GetPlayers()) do addPlayer(target) end
local objectSequence = 0
local function clearObjectMarkers(record)
    if record.highlight then record.highlight:Destroy(); record.highlight = nil end
end
local function registerObject(object)
    if objects[object] or not (object:IsA("Model") or object:IsA("BasePart")) then return end
    local name = string.lower(object.Name)
    local kind = name == "computertable" and "computer" or name == "freezepod" and "pod" or nil
    if not kind then return end
    objectSequence = objectSequence + 1
    objects[object] = {kind = kind, id = objectSequence}
end
local function removeObject(object)
    if objects[object] then clearObjectMarkers(objects[object]); objects[object] = nil end
end
connect(Workspace.DescendantAdded, registerObject)
connect(Workspace.DescendantRemoving, removeObject)
queueScan(Workspace, registerObject)
local function activeMap()
    local reference = ReplicatedStorage:FindFirstChild("CurrentMap")
    if reference and reference:IsA("ObjectValue") then
        local map = reference.Value
        return map and map:IsDescendantOf(Workspace) and map or nil, true
    elseif reference and reference:IsA("StringValue") then
        if reference.Value == "" then return nil, true end
        return Workspace:FindFirstChild(reference.Value), true
    end
    local map = Workspace:FindFirstChild("CurrentMap")
    if map and (map:IsA("Model") or map:IsA("Folder")) then return map, true end
    return nil, false
end
local function flagIs(object, names, expected)
    if not object then return false end
    for _, name in ipairs(names) do
        local attribute = object:GetAttribute(name)
        if type(attribute) == "boolean" and attribute == expected then return true end
        local value = object:FindFirstChild(name, true)
        if value and value:IsA("BoolValue") and value.Value == expected then return true end
    end
    return false
end
local function computerState(object)
    local screen = object:FindFirstChild("Screen", true)
    if flagIs(object, {"Hacked", "IsHacked", "Completed", "Complete"}, true) then
        return theme.green, "Компьютер · взломан", screen
    end
    if not (screen and screen:IsA("BasePart")) then return nil end
    local color = screen.Color
    local completed = color.G > 0.4 and color.G > color.R + 0.08 and color.G > color.B + 0.08
    if completed then return theme.green, "Компьютер · взломан", screen end
    return theme.cyan, "Компьютер · не взломан", screen
end
local function podState(object)
    local trigger = object:FindFirstChild("PodTrigger", true)
    local captured = trigger and trigger:FindFirstChild("CapturedTorso") or object:FindFirstChild("CapturedTorso", true)
    if (captured and captured:IsA("ObjectValue") and captured.Value ~= nil)
        or flagIs(object, {"Occupied", "IsOccupied"}, true) then
        return theme.red, "Капсула · занята"
    end
    if flagIs(object, {"Disabled", "Broken", "IsBroken", "Unavailable", "Unusable"}, true)
        or flagIs(object, {"Available", "Enabled", "Working", "Usable"}, false) then
        return theme.red, "Капсула · недоступна"
    end
    if captured and captured:IsA("ObjectValue") then return theme.blue, "Капсула · свободна" end
    if flagIs(object, {"Available", "Enabled", "Working", "Usable"}, true) then
        return theme.blue, "Капсула · свободна"
    end
    return nil
end
local function objectAnchor(object, preferred)
    if preferred and preferred:IsA("BasePart") then return preferred end
    if object:IsA("BasePart") then return object end
    local base = object:FindFirstChild("BasePart", true)
    if base and base:IsA("BasePart") then return base end
    return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
end

local function updateObjects(localRoot)
    local map, mapKnown = activeMap()
    for object, record in pairs(objects) do
        if not object:IsDescendantOf(Workspace) then removeObject(object)
        else
            local enabled = record.kind == "computer" and config.computers or record.kind == "pod" and config.pods
            local inMap = not mapKnown or (map ~= nil and object:IsDescendantOf(map))
            local color, _, preferred
            if enabled and inMap then
                if record.kind == "computer" then color, _, preferred = computerState(object)
                else color = podState(object) end
            end
            local anchor = color and objectAnchor(object, preferred)
            local distance = localRoot and anchor and (anchor.Position - localRoot.Position).Magnitude or nil
            if distance and distance <= ESP_DISTANCE then
                if not record.highlight then
                    if markerBudget <= 0 then continue end
                    markerBudget = markerBudget - 1
                    record.highlight = make("Highlight", {
                        Name = "Object_" .. record.id, Adornee = object, FillTransparency = 1,
                        OutlineTransparency = 0, Enabled = false,
                    }, effects)
                end
                assign(record.highlight, "Enabled", true)
                assign(record.highlight, "OutlineColor", color)
                assign(record.highlight, "DepthMode", config.throughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded)
            elseif record.highlight then assign(record.highlight, "Enabled", false) end
        end
    end
end
local function updatePlayers(localRoot)
    for target, record in pairs(records) do
        local character = target.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local beast = isBeast(target)
        local color = beast and theme.red or theme.white
        local distance = localRoot and root and (root.Position - localRoot.Position).Magnitude or nil
        local enabled = config.esp and humanoid ~= nil and humanoid.Health > 0 and distance ~= nil
            and distance <= ESP_DISTANCE
        if enabled then
            if record.character ~= character or not record.highlight then
                if not buildMarkers(record, character) then continue end
            end
            assign(record.highlight, "Enabled", true)
            assign(record.highlight, "OutlineColor", color)
            assign(record.highlight, "DepthMode", config.throughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded)
            updateNameTag(record, character:FindFirstChild("Head") or root, color, true)
        else
            if record.character ~= character then clearMarkers(record)
            elseif record.highlight then assign(record.highlight, "Enabled", false) end
            updateNameTag(record, nil, color, false)
        end
    end
end

local miniGames = {}
local function registerMinigame(object)
    if object:IsDescendantOf(gui) or not object:IsA("GuiObject") then return end
    local name = string.lower(object.Name)
    if string.find(name, "minigame", 1, true) or name == "computerhackframe" or name == "timingcircle" then miniGames[object] = true end
end
connect(playerGui.DescendantAdded, registerMinigame)
connect(playerGui.DescendantRemoving, function(object) miniGames[object] = nil end)
queueScan(playerGui, registerMinigame)
local function effectivelyVisible(object)
    local current = object
    while current and current ~= playerGui do
        if current:IsA("GuiObject") and not current.Visible then return false end
        if current:IsA("ScreenGui") and not current.Enabled then return false end
        current = current.Parent
    end
    return current == playerGui
end
local function minigameVisible()
    for object in pairs(miniGames) do
        if object.Parent and effectivelyVisible(object) then return true end
    end
    return false
end
local function hackingActive()
    if stat(player, "CurrentAnimation") == "Typing" then return true end
    local event = stat(player, "ActionEvent")
    if event ~= nil and typeof(event) == typeof(Workspace) then
        local ancestor = event
        while ancestor and ancestor ~= Workspace do
            if ancestor.Name == "ComputerTable" then return true end
            ancestor = ancestor.Parent
        end
    end
    return minigameVisible()
end
local function remoteEvent()
    local event = ReplicatedStorage:FindFirstChild("RemoteEvent")
    return event and event:IsA("RemoteEvent") and event or nil
end
local function send(event, ...)
    if not event or not event.Parent then return false end
    local arguments = table.pack(...)
    return pcall(function() event:FireServer(table.unpack(arguments, 1, arguments.n)) end)
end
local function disableFeature(key, message)
    config[key] = false
    if painters[key] then painters[key]() end
    status(key, message)
end
local function localReady()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local health = stat(player, "Health")
    return character ~= nil and humanoid ~= nil and root ~= nil and humanoid.Health > 0
        and (type(health) ~= "number" or health > 0) and not isBeast(player)
        and stat(player, "Captured") ~= true and stat(player, "Ragdoll") ~= true
end
local function currentBeast()
    local candidate
    for _, target in ipairs(Players:GetPlayers()) do
        if target ~= player and isBeast(target) and target.Character and target.Character:IsDescendantOf(Workspace) then
            local humanoid = target.Character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health > 0 then
                if target.Character:FindFirstChild("Hammer") then return target end
                candidate = candidate or target
            end
        end
    end
    return candidate
end
local rescueSession, rescueCooldowns = nil, setmetatable({}, {__mode = "k"})
local rescueNoticeUntil = 0
local function rescueNotice(text, now)
    rescueNoticeUntil = now + 4
    status("autoRescue", text)
    print("KaiFlee: спасение: " .. text)
end
local lastRescueSend, lastNoFailSend = -math.huge, -math.huge
local function stopRescue()
    if not rescueSession then return end
    local session = rescueSession
    rescueSession = nil
    send(session.remote, "Input", "Action", false)
    send(session.remote, "Input", "Trigger", false, session.event)
    if session.teleported and session.root and session.root.Parent then
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if root == session.root and humanoid and humanoid.Health > 0 and stat(player, "Captured") ~= true and stat(player, "Ragdoll") ~= true
            and (root.Position - session.destination.Position).Magnitude < 15 then
            root.CFrame = session.origin
        end
    end
    if session.resumeEvent and session.resumeEvent.Parent and session.root and session.root.Parent then
        task.delay(0.25, function()
            if not alive or rescueSession or not localReady() or not session.resumeEvent.Parent then return end
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if root ~= session.root or (root.Position - session.origin.Position).Magnitude >= 15 then return end
            if session.mapKnown then
                local map = activeMap()
                if map ~= session.map then return end
            end
            send(session.remote, "Input", "Trigger", true, session.resumeEvent)
            send(session.remote, "Input", "Action", true)
        end)
    end
end
local function rescueCandidate(now)
    local map, mapKnown = activeMap()
    local best, bestHealth
    for pod, record in pairs(objects) do
        if record.kind ~= "pod" or not pod:IsDescendantOf(Workspace) then continue end
        if mapKnown and (not map or not pod:IsDescendantOf(map)) then continue end
        local trigger = pod:FindFirstChild("PodTrigger", true)
        local captured = trigger and trigger:FindFirstChild("CapturedTorso")
        local event = trigger and trigger:FindFirstChild("Event")
        local torso = captured and captured:IsA("ObjectValue") and captured.Value
        if not torso or not torso.Parent or not event then continue end
        if rescueCooldowns[torso] and rescueCooldowns[torso] > now then continue end
        local victim = Players:GetPlayerFromCharacter(torso.Parent)
        if not victim or victim == player or isBeast(victim) or stat(victim, "Captured") ~= true then continue end
        local health = stat(victim, "Health")
        if type(health) ~= "number" or health <= 0 then continue end
        if not best or health < bestHealth then
            bestHealth = health
            best = {pod = pod, trigger = trigger, event = event, captured = captured, torso = torso, victim = victim, map = map, mapKnown = mapKnown}
        end
    end
    return best
end
local function updateRescue(now, ready, hacking)
    if not config.autoRescue then stopRescue(); return end
    if not ready then
        stopRescue()
        status("autoRescue", "Ожидание возможности спасти")
        return
    end
    if rescueSession then
        local session = rescueSession
        local map = activeMap()
        if not session.pod:IsDescendantOf(Workspace) or not session.captured.Parent or (session.mapKnown and map ~= session.map) then
            stopRescue(); status("autoRescue", "Ожидание пленника"); return
        end
        local health = stat(session.victim, "Health")
        if type(health) == "number" and health <= 0 then
            stopRescue(); rescueNotice("Пленник выбыл из раунда", now); return
        end
        if session.captured.Value ~= session.torso and stat(session.victim, "Captured") == false and type(health) == "number" and health > 0 then
            stopRescue(); rescueNotice("Спасение подтверждено", now); return
        end
        if now - session.started >= 6 then
            rescueCooldowns[session.torso] = now + 20
            stopRescue()
            rescueNotice("Сервер не подтвердил спасение", now)
            return
        end
    else
        local candidate = rescueCandidate(now)
        if not candidate then
            if now >= rescueNoticeUntil then status("autoRescue", "Ожидание пленника") end
            return
        end
        candidate.remote = remoteEvent()
        if not candidate.remote then status("autoRescue", "Ожидание игровых событий"); return end
        candidate.started = now
        print("KaiFlee: спасение: цель " .. candidate.victim.Name)
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        candidate.root, candidate.origin = root, root and root.CFrame
        if hacking then
            local prior = stat(player, "ActionEvent")
            if prior ~= nil and typeof(prior) == typeof(Workspace) then
                candidate.resumeEvent = prior
                send(candidate.remote, "Input", "Action", false)
                send(candidate.remote, "Input", "Trigger", false, prior)
            end
        end
        if root and candidate.trigger:IsA("BasePart") and (root.Position - candidate.trigger.Position).Magnitude > 7 then
            candidate.destination = candidate.trigger.CFrame * CFrame.new(0, 0, -3)
            candidate.teleported = true
            root.CFrame = candidate.destination
            candidate.sendAfter = now + 0.3
        end
        rescueSession = candidate
    end
    if rescueSession.sendAfter and now < rescueSession.sendAfter then status("autoRescue", "Перемещение к капсуле"); return end
    if now - lastRescueSend >= 0.05 then
        lastRescueSend = now
        local session = rescueSession
        local triggerSent = send(session.remote, "Input", "Trigger", true, session.event)
        local actionSent = triggerSent and send(session.remote, "Input", "Action", true)
        if not actionSent then
            stopRescue(); disableFeature("autoRescue", "Ошибка отправки действия"); return
        end
        status("autoRescue", "Спасение: " .. session.victim.DisplayName)
    end
end
local observedPowerName, observedPowerActive, lastPowerText
local powerNames = {Runner = "Бегун", Stalker = "Сталкер", Seer = "Провидец", Hacker = "Хакер"}
local function powerState()
    local name = ReplicatedStorage:FindFirstChild("CurrentPower")
    local active = ReplicatedStorage:FindFirstChild("PowerActive")
    return name and name:IsA("StringValue") and name.Value or "", active and active:IsA("BoolValue") and active.Value or false
end
local function updatePowerState()
    local name, active = powerState()
    local changed = observedPowerName ~= name or observedPowerActive ~= active
    if changed then
        observedPowerName, observedPowerActive = name, active
    end
    if powerText and (changed or not lastPowerText) then
        local text = name ~= "" and ("Способность: " .. (powerNames[name] or name) .. (active and " · активна" or "")) or "Способность ещё не выбрана"
        if text ~= lastPowerText then powerText.Text = text; lastPowerText = text end
    end
end
local function updateAutomation(now)
    local ready = localReady()
    local hacking = (config.noFail or config.autoRescue) and hackingActive() or false
    updateRescue(now, ready, hacking)
end
local noFailUntil, noFailStats, noFailMini = 0, nil, false
local noFailRetryAt, noFailErrorAt = 0, -math.huge
local function updateNoFail(now)
    if not config.noFail then noFailUntil, noFailStats, noFailMini, noFailRetryAt = 0, nil, false, 0; return end
    if now < noFailRetryAt then return end
    local stats = statsFor(player)
    if noFailStats ~= stats then
        noFailStats = stats
        noFailUntil, lastNoFailSend, noFailMini = 0, -math.huge, false
    end
    if not stats or not localReady() then
        noFailUntil, noFailMini = 0, false
        status("noFail", "Ожидание возможности взлома")
        return
    end
    local mini = minigameVisible()
    if hackingActive() then noFailUntil = now + 0.6 end
    if mini and not noFailMini then lastNoFailSend = -math.huge end
    noFailMini = mini
    if now > noFailUntil then status("noFail", "Ожидание взлома"); return end
    if now - lastNoFailSend < (mini and (1 / 30) or 0.075) then return end
    local event = remoteEvent()
    if not event then status("noFail", "Ожидание игровых событий"); return end
    lastNoFailSend = now
    if send(event, "SetPlayerMinigameResult", true) then status("noFail", "Автопроверка активна")
    else
        status("noFail", "Повторное подключение к мини-игре")
        noFailStats = nil
        noFailRetryAt = now + 0.5
    end
end

connect(reset.Activated, function()
    stopRescue()
    table.clear(rescueCooldowns)
    for key, value in pairs(defaults) do config[key] = value end
    for _, paint in pairs(painters) do paint() end
    updateLighting()
end)
cleanup = function()
    if not alive then return end
    alive = false
    stopRescue()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
    config.fullbright = false
    pcall(updateLighting)
    for _, record in pairs(records) do clearMarkers(record) end
    for _, record in pairs(objects) do clearObjectMarkers(record) end
    table.clear(records)
    table.clear(objects)
    table.clear(miniGames)
    table.clear(buttonMotions)
    table.clear(toggleMotions)
    table.clear(scanJobs)
    table.clear(fadeEntries)
    table.clear(fadeGroups)
    if environment[runtimeKey] == startupState then environment[runtimeKey] = nil end
    activeSlider, drag = nil, nil
    effects:Destroy()
    gui:Destroy()
end
startupCleanup = cleanup
connect(shutdown.Event, cleanup)
connect(gui.Destroying, cleanup)
task.spawn(function()
    local ok, thumbnail = pcall(function()
        return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
    end)
    if alive and ok then avatar.Image = thumbnail end
end)
local lastViewport, updateElapsed, automationElapsed, powerElapsed, errors = Vector2.new(), 0, 0, 0, 0
local function animate(delta)
    local viewport = viewportSize()
    if viewport.X ~= lastViewport.X or viewport.Y ~= lastViewport.Y then
        lastViewport = viewport
        fitScale.Scale = math.min(1, math.max(0.2, (viewport.X - 32) / WIDTH), math.max(0.2, (viewport.Y - 32) / HEIGHT))
        clampWindow()
    end
    if shell.Visible then
        for _, motion in ipairs(buttonMotions) do
            if moving(motion.spring) then motion.scale.Scale = advance(motion.spring, delta) end
        end
        for _, motion in ipairs(toggleMotions) do
            if moving(motion.state) or not motion.painted then
                local value = advance(motion.state, delta)
                motion.switch.BackgroundColor3 = theme.line:Lerp(theme.white, math.clamp(value, 0, 1))
                motion.thumb.BackgroundColor3 = theme.muted:Lerp(theme.background, math.clamp(value, 0, 1))
                motion.thumb.Position = UDim2.fromOffset(4 + 20 * value, 4)
                motion.painted = true
            end
        end
        if moving(tabMotion) then selectedTab.Position = UDim2.fromOffset(advance(tabMotion, delta), 0) end
        local active = pages[selectedPage]
        if active then
            if moving(pageMotion) then active.group.Position = UDim2.fromOffset(24 + advance(pageMotion, delta), 120) end
            if moving(pageOpacity) then setOpacity(active.group, advance(pageOpacity, delta)) end
        end
    end
    if not introDone then
        introAge = introAge + delta
        splashScale.Scale = advance(introScale, delta)
        setOpacity(splash, advance(introOpacity, delta))
        progressFill.Size = UDim2.fromScale(math.clamp(introAge / 2.25, 0, 1), 1)
        logo.Rotation = 6 * math.exp(-introAge * 3) * math.sin(introAge * 9)
        if introAge >= 2.25 then introScale.target, introOpacity.target = 1.045, 0 end
        if introAge >= 2.6 then
            introDone = true
            splash:Destroy()
            fadeGroups[splash] = nil
            for index = #fadeEntries, 1, -1 do
                if table.find(fadeEntries[index].groups, splash) then table.remove(fadeEntries, index) end
            end
            setVisible(menuRequested)
        end
    end
    if moving(windowSizeMotion) then windowScale.Scale = advance(windowSizeMotion, delta) end
    local opacity = math.clamp(advance(windowOpacity, delta), 0, 1)
    setOpacity(window, opacity)
    if moving(windowOffset) then window.Position = UDim2.new(0.5, 0, 0.5, advance(windowOffset, delta)) end
    if introDone and not menuRequested and opacity < 0.001 then assign(shell, "Visible", false) end
    local danger = math.clamp(advance(dangerMotion, delta), 0, 1)
    assign(dangerFrame, "Visible", danger > 0.003)
    if danger > 0.003 then
        local pulse = 0.82 + 0.18 * math.sin(os.clock() * 4)
        for _, bar in ipairs(dangerBars) do bar.BackgroundTransparency = 1 - danger * pulse end
    end
    flushFades()
end
prepareFades(gui)
flushFades()
connect(RunService.RenderStepped, function(delta)
    local ok, message = pcall(animate, delta)
    if not ok then warn("KaiFlee: анимация: " .. tostring(message)); cleanup() end
end)
connect(RunService.Heartbeat, function(delta)
    if not alive then return end
    local now = os.clock()
    if #scanJobs > 0 then
        local scanOk, scanError = pcall(stepScans)
        if not scanOk then warn("KaiFlee: поиск объектов: " .. tostring(scanError)); cleanup(); return end
    end
    if introDone and (config.noFail or noFailStats or noFailUntil ~= 0) then
        local hackOk, hackError = pcall(updateNoFail, now)
        if not hackOk then
            noFailStats = nil
            noFailUntil, noFailMini = 0, false
            noFailRetryAt = now + 0.5
            status("noFail", "Восстановление проверки")
            if now - noFailErrorAt > 2 then
                noFailErrorAt = now
                warn("KaiFlee: мини-игра: " .. tostring(hackError))
            end
        end
    end
    automationElapsed = automationElapsed + delta
    if introDone and automationElapsed >= 0.05 and (config.autoRescue or rescueSession) then
        automationElapsed = 0
        local autoOk, autoError = pcall(updateAutomation, now)
        if not autoOk then
            stopRescue()
            for _, key in ipairs({"autoRescue"}) do
                if config[key] then disableFeature(key, "Ошибка · см. консоль Xeno") end
            end
            warn("KaiFlee: автоматика: " .. tostring(autoError))
        end
    end
    powerElapsed = powerElapsed + delta
    if introDone and powerElapsed >= 0.2 then
        powerElapsed = 0
        local ok, message = pcall(updatePowerState)
        if not ok then warn("KaiFlee: способность чудовища: " .. tostring(message)) end
    end
    updateElapsed = updateElapsed + delta
    if updateElapsed < 0.1 then return end
    updateElapsed = 0
    local ok, message = pcall(function()
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        markerBudget = 4
        updatePlayers(root)
        updateObjects(root)
        dangerMotion.target = 0
        local health = stat(player, "Health")
        if config.dangerCue and root and not isBeast(player) and (type(health) ~= "number" or health > 0) then
            local beast = currentBeast()
            local otherRoot = beast and beast.Character and beast.Character:FindFirstChild("HumanoidRootPart")
            if otherRoot then
                local distance = (otherRoot.Position - root.Position).Magnitude
                if distance <= config.dangerRadius then dangerMotion.target = 0.2 + 0.55 * (1 - distance / config.dangerRadius) end
            end
        end
    end)
    if ok then errors = 0 else
        errors = errors + 1
        if errors == 1 then warn("KaiFlee: " .. tostring(message)) end
        if errors >= 5 then cleanup() end
    end
end)
selectPage("Visuals")
updateLighting()
print("KaiFlee 3.6 загружен. Правый Shift — меню. Настройки > Выгрузить KaiFlee — отключение.")
return true

end

startInfiniteYield = function()
    local key = "__KaiFleeInfiniteYieldLoader"
    local previous = environment[key]
    if type(previous) ~= "table" then previous = nil end
    if environment.IY_LOADED then
        if previous and previous.phase == "initialization_failed" then
            warn("Infinite Yield: предыдущая инициализация завершилась ошибкой: " .. tostring(previous.error))
        else
            print("Infinite Yield уже запущен.")
        end
        return
    end
    if previous and (previous.phase == "downloading" or previous.phase == "initializing") then
        print("Infinite Yield уже загружается.")
        return
    end
    local state = {phase = "downloading"}
    environment[key] = state
    local function fail(phase, message)
        state.phase, state.error = phase, tostring(message)
        warn("Infinite Yield: " .. state.error)
    end
    task.delay(20, function()
        if environment[key] == state and state.phase == "downloading" then
            fail("download_failed", "превышено время загрузки. KaiFlee продолжает работать.")
        end
    end)
    local ok, source = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source")
    end)
    if environment[key] ~= state or state.phase ~= "downloading" then return end
    if not ok then fail("download_failed", "ошибка загрузки: " .. tostring(source)); return end
    if type(source) ~= "string" or source == "" then fail("download_failed", "получен пустой исходник"); return end
    local compiler = environment.loadstring or loadstring
    if type(compiler) ~= "function" then fail("compile_failed", "в среде отсутствует loadstring"); return end
    local compiledOk, chunk, compileError = pcall(compiler, source, "InfiniteYield")
    if not compiledOk or type(chunk) ~= "function" then
        fail("compile_failed", "ошибка компиляции: " .. tostring(compileError or chunk))
        return
    end
    state.phase = "initializing"
    local started, message = pcall(chunk)
    if not started then fail("initialization_failed", "ошибка запуска: " .. tostring(message)); return end
    state.phase = "loaded"
    print("Infinite Yield загружен из официального EdgeIY/infiniteyield.")
end

local previousRuntime = environment[runtimeKey]
if type(previousRuntime) == "table" and (previousRuntime.phase == "starting" or previousRuntime.phase == "running") then
    print("KaiFlee уже запущен или загружается. Правый Shift — меню.")
    return
end
startupState = {phase = "starting"}
environment[runtimeKey] = startupState
task.spawn(function()
    print("KaiFlee 3.6: запуск интерфейса; Infinite Yield запускается отдельно в настройках.")
    local ok, message = pcall(startKaiFlee)
    if ok and message == true then startupState.phase = "running"
    elseif ok then
        if environment[runtimeKey] == startupState then environment[runtimeKey] = nil end
    else
        if startupCleanup then pcall(startupCleanup) end
        if environment[runtimeKey] == startupState then environment[runtimeKey] = nil end
        warn("KaiFlee: ошибка запуска: " .. tostring(message))
    end
end)
