local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local SETTINGS = {
    ESP = {
        Enabled = false,
        BoxColor = Color3.new(1, 0.3, 0.3),
        DistanceColor = Color3.new(1, 1, 1),
        HealthGradient = {
            Color3.new(0, 1, 0),
            Color3.new(1, 1, 0),
            Color3.new(1, 0, 0)
        },
        SnaplineEnabled = true,
        SnaplinePosition = "Center",
        RainbowEnabled = false
    },
    Aimbot = {
        Enabled = false,
        FOV = 30,
        MaxDistance = 200,
        ShowFOV = false,
        TargetPart = "Head"
    },
    Misc = {
        -- Здесь могут быть другие настройки в будущем
    }
}

local rainbowSpeed = 0.5
local espCache = {}

local function createESP(player)
    if player == LocalPlayer then return end
    local drawings = {
        Box = Drawing.new("Square"),
        HealthBar = Drawing.new("Square"),
        Distance = Drawing.new("Text"),
        Snapline = Drawing.new("Line")
    }
    for _, v in pairs(drawings) do
        v.Visible = false
        if v.Type == "Square" then
            v.Thickness = 2
            v.Filled = false
        end
    end
    drawings.Box.Color = SETTINGS.ESP.BoxColor
    drawings.HealthBar.Filled = true
    drawings.Distance.Size = 16
    drawings.Distance.Center = true
    drawings.Distance.Color = SETTINGS.ESP.DistanceColor
    drawings.Snapline.Color = SETTINGS.ESP.BoxColor
    espCache[player] = drawings
end

local function updateESP(player, drawings)
    if not SETTINGS.ESP.Enabled or not player.Character then
        for _, v in pairs(drawings) do v.Visible = false end
        return
    end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    local head = player.Character:FindFirstChild("Head")
    if not humanoid or humanoid.Health <= 0 or not head then
        for _, v in pairs(drawings) do v.Visible = false end
        return
    end
    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
    if not onScreen then
        for _, v in pairs(drawings) do v.Visible = false end
        return
    end
    local distance = (head.Position - Camera.CFrame.Position).Magnitude
    local size = 1000 / distance
    drawings.Box.Size = Vector2.new(size, size * 1.5)
    drawings.Box.Position = Vector2.new(screenPos.X - size/2, screenPos.Y - size * 0.75)
    drawings.Box.Visible = true
    local healthPercent = humanoid.Health / humanoid.MaxHealth
    local colorIndex = math.clamp(3 - healthPercent * 2, 1, 3)
    local color = SETTINGS.ESP.HealthGradient[math.floor(colorIndex)]:Lerp(
        SETTINGS.ESP.HealthGradient[math.ceil(colorIndex)],
        colorIndex % 1
    )
    drawings.HealthBar.Size = Vector2.new(4, size * 1.5 * healthPercent)
    drawings.HealthBar.Position = Vector2.new(screenPos.X + size/2 + 5, screenPos.Y - size * 0.75 + (size * 1.5 * (1 - healthPercent)))
    drawings.HealthBar.Color = color
    drawings.HealthBar.Visible = true
    drawings.Distance.Text = math.floor(distance) .. "m"
    drawings.Distance.Position = Vector2.new(screenPos.X, screenPos.Y + size * 0.75 + 10)
    drawings.Distance.Visible = true

    if SETTINGS.ESP.RainbowEnabled then
        local hue = (tick() * rainbowSpeed) % 1
        drawings.Snapline.Color = Color3.fromHSV(hue, 1, 1)
        drawings.Box.Color = Color3.fromHSV(hue, 1, 1)
    else
        drawings.Snapline.Color = SETTINGS.ESP.BoxColor
        drawings.Box.Color = SETTINGS.ESP.BoxColor
    end

    if SETTINGS.ESP.SnaplineEnabled then
        drawings.Snapline.From = Vector2.new(screenPos.X, screenPos.Y + size * 0.75)
        local snaplineY
        if SETTINGS.ESP.SnaplinePosition == "Bottom" then
            snaplineY = Camera.ViewportSize.Y
        elseif SETTINGS.ESP.SnaplinePosition == "Top" then
            snaplineY = 0
        else
            snaplineY = Camera.ViewportSize.Y / 2
        end
        drawings.Snapline.To = Vector2.new(Camera.ViewportSize.X / 2, snaplineY)
        drawings.Snapline.Visible = true
    else
        drawings.Snapline.Visible = false
    end
end

-- Aimbot function to find the closest player
local function getClosestPlayer()
    local closestPlayer = nil
    local minDist = math.huge
    local fov = SETTINGS.Aimbot.FOV or 70

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
            local head = player.Character.Head
            local vectorToPlayer = (head.Position - workspace.CurrentCamera.CFrame.Position).Unit
            local cameraDirection = workspace.CurrentCamera.CFrame.LookVector
            local angle = math.deg(math.acos(vectorToPlayer:Dot(cameraDirection)))

            if angle <= fov / 2 then
                local distance = (workspace.CurrentCamera.CFrame.Position - head.Position).Magnitude
                if distance <= SETTINGS.Aimbot.MaxDistance then
                    local ray = Ray.new(workspace.CurrentCamera.CFrame.Position, vectorToPlayer * 500)
                    local hit, pos = workspace:FindPartOnRay(ray, Players.LocalPlayer.Character)

                    if hit and hit:IsDescendantOf(player.Character) then
                        if distance < minDist then
                            minDist = distance
                            closestPlayer = player
                        end
                    end
                end
            end
        end
    end
    return closestPlayer
end

local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 2
fovCircle.NumSides = 100
fovCircle.Filled = false
fovCircle.Visible = SETTINGS.Aimbot.ShowFOV
fovCircle.Color = Color3.new(1, 1, 1)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScriptGUI"
screenGui.Parent = CoreGui
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 1000

local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.new(0, 600, 0, 300) -- Увеличим ширину для вкладок
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.new(0.05, 0.05, 0.05)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.ZIndex = 100
frame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 10)
frameCorner.Parent = frame

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.new(0.1, 0.1, 0.1)),
    ColorSequenceKeypoint.new(1, Color3.new(0.3, 0.3, 0.3))
})
gradient.Rotation = 90
gradient.Parent = frame

local shadow = Instance.new("ImageLabel")
shadow.Size = UDim2.new(1, 10, 1, 10)
shadow.Position = UDim2.new(0, -5, 0, -5)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://131604521"
shadow.ImageColor3 = Color3.new(0, 0, 0)
shadow.ImageTransparency = 0.5
shadow.ZIndex = 99
shadow.Parent = frame

local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 101
titleBar.Parent = frame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(0, 180, 0, 30)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.Text = "whoamhoam Client"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 16
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 102
titleLabel.Parent = titleBar

local minimizeButton = Instance.new("TextButton")
minimizeButton.Name = "MinimizeButton"
minimizeButton.Size = UDim2.new(0, 20, 0, 20)
minimizeButton.Position = UDim2.new(1, -25, 0, 5)
minimizeButton.BackgroundColor3 = Color3.new(1, 0, 0)
minimizeButton.TextColor3 = Color3.new(1, 1, 1)
minimizeButton.Text = "-"
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 14
minimizeButton.ZIndex = 102
minimizeButton.Parent = titleBar

local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(0, 5)
minimizeCorner.Parent = minimizeButton

-- Вкладки
local tabsFrame = Instance.new("Frame")
tabsFrame.Name = "TabsFrame"
tabsFrame.Size = UDim2.new(0, 150, 0, frame.Size.Y.Offset - titleBar.Size.Y.Offset)
tabsFrame.Position = UDim2.new(0, 0, 0, titleBar.Size.Y.Offset)
tabsFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
tabsFrame.BorderSizePixel = 0
tabsFrame.ZIndex = 101
tabsFrame.Parent = frame

local tabsCorner = Instance.new("UICorner")
tabsCorner.CornerRadius = UDim.new(0, 10)
tabsCorner.Parent = tabsFrame

local espTabButton = Instance.new("TextButton")
espTabButton.Name = "ESPTabButton"
espTabButton.Size = UDim2.new(1, -10, 0, 40)
espTabButton.Position = UDim2.new(0, 5, 0, 10)
espTabButton.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
espTabButton.TextColor3 = Color3.new(1, 1, 1)
espTabButton.Text = "ESP"
espTabButton.Font = Enum.Font.GothamBold
espTabButton.TextSize = 14
espTabButton.ZIndex = 102
espTabButton.Parent = tabsFrame
local espTabCorner = Instance.new("UICorner")
espTabCorner.CornerRadius = UDim.new(0, 5)
espTabCorner.Parent = espTabButton

local aimbotTabButton = Instance.new("TextButton")
aimbotTabButton.Name = "AimbotTabButton"
aimbotTabButton.Size = UDim2.new(1, -10, 0, 40)
aimbotTabButton.Position = UDim2.new(0, 5, 0, 60)
aimbotTabButton.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
aimbotTabButton.TextColor3 = Color3.new(1, 1, 1)
aimbotTabButton.Text = "Aimbot"
aimbotTabButton.Font = Enum.Font.GothamBold
aimbotTabButton.TextSize = 14
aimbotTabButton.ZIndex = 102
aimbotTabButton.Parent = tabsFrame
local aimbotTabCorner = Instance.new("UICorner")
aimbotTabCorner.CornerRadius = UDim.new(0, 5)
aimbotTabCorner.Parent = aimbotTabButton

local miscTabButton = Instance.new("TextButton")
miscTabButton.Name = "MiscTabButton"
miscTabButton.Size = UDim2.new(1, -10, 0, 40)
miscTabButton.Position = UDim2.new(0, 5, 0, 110)
miscTabButton.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
miscTabButton.TextColor3 = Color3.new(1, 1, 1)
miscTabButton.Text = "Misc"
miscTabButton.Font = Enum.Font.GothamBold
miscTabButton.TextSize = 14
miscTabButton.ZIndex = 102
miscTabButton.Parent = tabsFrame
local miscTabCorner = Instance.new("UICorner")
miscTabCorner.CornerRadius = UDim.new(0, 5)
miscTabCorner.Parent = miscTabButton

-- Контейнеры для контента вкладок
local espTabContent = Instance.new("Frame")
espTabContent.Name = "ESPTabContent"
espTabContent.Size = UDim2.new(0, frame.Size.X.Offset - tabsFrame.Size.X.Offset - 20, 0, frame.Size.Y.Offset - titleBar.Size.Y.Offset - 20)
espTabContent.Position = UDim2.new(0, tabsFrame.Size.X.Offset + 10, 0, titleBar.Size.Y.Offset + 10)
espTabContent.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
espTabContent.BorderSizePixel = 0
espTabContent.ZIndex = 101
espTabContent.Parent = frame

local aimbotTabContent = Instance.new("Frame")
aimbotTabContent.Name = "AimbotTabContent"
aimbotTabContent.Size = espTabContent.Size
aimbotTabContent.Position = espTabContent.Position
aimbotTabContent.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
aimbotTabContent.BorderSizePixel = 0
aimbotTabContent.ZIndex = 101
aimbotTabContent.Parent = frame
aimbotTabContent.Visible = false

local miscTabContent = Instance.new("Frame")
miscTabContent.Name = "MiscTabContent"
miscTabContent.Size = espTabContent.Size
miscTabContent.Position = espTabContent.Position
miscTabContent.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
miscTabContent.BorderSizePixel = 0
miscTabContent.ZIndex = 101
miscTabContent.Parent = frame
miscTabContent.Visible = false

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 10)
contentCorner.Parent = espTabContent
local contentCorner2 = contentCorner:Clone()
contentCorner2.Parent = aimbotTabContent
local contentCorner3 = contentCorner:Clone()
contentCorner3.Parent = miscTabContent

-- Размещение элементов UI по вкладкам
local leftColumnStart = 10
local leftButtonHeight = 30
local leftVerticalSpacing = 10
local currentLeftY = 10

local espButton = Instance.new("TextButton")
espButton.Name = "ESPButton"
espButton.Size = UDim2.new(0, 180, 0, leftButtonHeight)
espButton.Position = UDim2.new(0, leftColumnStart, 0, currentLeftY)
espButton.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
espButton.TextColor3 = Color3.new(1, 1, 1)
espButton.Text = "ESP"
espButton.Font = Enum.Font.GothamBold
espButton.TextSize = 14
espButton.ZIndex = 101
espButton.Parent = espTabContent -- Перемещено на вкладку ESP
local espCorner = Instance.new("UICorner")
espCorner.CornerRadius = UDim.new(0, 5)
espCorner.Parent = espButton
local espIndicator = Instance.new("Frame")
espIndicator.Name = "ESPIndicator"
espIndicator.Size = UDim2.new(0, 20, 0, 20)
espIndicator.Position = UDim2.new(1, -25, 0, 5)
espIndicator.BackgroundColor3 = SETTINGS.ESP.Enabled and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
espIndicator.BorderSizePixel = 0
espIndicator.ZIndex = 102
espIndicator.Parent = espButton
local espIndicatorCorner = Instance.new("UICorner")
espIndicatorCorner.CornerRadius = UDim.new(0, 5)
espIndicatorCorner.Parent = espIndicator
currentLeftY += leftButtonHeight + leftVerticalSpacing

local snaplineToggleButton = Instance.new("TextButton")
snaplineToggleButton.Name = "SnaplineToggleButton"
snaplineToggleButton.Size = UDim2.new(0, 180, 0, leftButtonHeight)
snaplineToggleButton.Position = UDim2.new(0, leftColumnStart, 0, currentLeftY)
snaplineToggleButton.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
snaplineToggleButton.TextColor3 = Color3.new(1, 1, 1)
snaplineToggleButton.Text = "Snapline"
snaplineToggleButton.Font = Enum.Font.GothamBold
snaplineToggleButton.TextSize = 14
snaplineToggleButton.ZIndex = 101
snaplineToggleButton.Parent = espTabContent -- Перемещено на вкладку ESP
local snaplineToggleCorner = Instance.new("UICorner")
snaplineToggleCorner.CornerRadius = UDim.new(0, 5)
snaplineToggleCorner.Parent = snaplineToggleButton
local snaplineToggleIndicator = Instance.new("Frame")
snaplineToggleIndicator.Name = "SnaplineToggleIndicator"
snaplineToggleIndicator.Size = UDim2.new(0, 20, 0, 20)
snaplineToggleIndicator.Position = UDim2.new(1, -25, 0, 5)
snaplineToggleIndicator.BackgroundColor3 = SETTINGS.ESP.SnaplineEnabled and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
snaplineToggleIndicator.BorderSizePixel = 0
snaplineToggleIndicator.ZIndex = 102
snaplineToggleIndicator.Parent = snaplineToggleButton
local snaplineToggleIndicatorCorner = Instance.new("UICorner")
snaplineToggleIndicatorCorner.CornerRadius = UDim.new(0, 5)
snaplineToggleIndicatorCorner.Parent = snaplineToggleIndicator
currentLeftY += leftButtonHeight + leftVerticalSpacing

local snaplinePositionLabel = Instance.new("TextLabel")
snaplinePositionLabel.Name = "SnaplinePositionLabel"
snaplinePositionLabel.Size = UDim2.new(0, 180, 0, 20)
snaplinePositionLabel.Position = UDim2.new(0, leftColumnStart, 0, currentLeftY)
snaplinePositionLabel.BackgroundTransparency = 1
snaplinePositionLabel.TextColor3 = Color3.new(1, 1, 1)
snaplinePositionLabel.Text = "Position:"
snaplinePositionLabel.Font = Enum.Font.GothamBold
snaplinePositionLabel.TextSize = 14
snaplinePositionLabel.TextXAlignment = Enum.TextXAlignment.Left
snaplinePositionLabel.ZIndex = 101
snaplinePositionLabel.Parent = espTabContent -- Перемещено на вкладку ESP
currentLeftY += 20

local snaplinePositionDropdown = Instance.new("TextButton")
snaplinePositionDropdown.Name = "SnaplinePositionDropdown"
snaplinePositionDropdown.Size = UDim2.new(0, 180, 0, leftButtonHeight)
snaplinePositionDropdown.Position = UDim2.new(0, leftColumnStart, 0, currentLeftY)
snaplinePositionDropdown.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
snaplinePositionDropdown.TextColor3 = Color3.new(1, 1, 1)
snaplinePositionDropdown.Text = SETTINGS.ESP.SnaplinePosition
snaplinePositionDropdown.Font = Enum.Font.GothamBold
snaplinePositionDropdown.TextSize = 14
snaplinePositionDropdown.TextXAlignment = Enum.TextXAlignment.Center
snaplinePositionDropdown.ZIndex = 101
snaplinePositionDropdown.Parent = espTabContent -- Перемещено на вкладку ESP
local snaplinePositionDropdownCorner = Instance.new("UICorner")
snaplinePositionDropdownCorner.CornerRadius = UDim.new(0, 5)
snaplinePositionDropdownCorner.Parent = snaplinePositionDropdown
currentLeftY += leftButtonHeight + leftVerticalSpacing

local rainbowButton = Instance.new("TextButton")
rainbowButton.Name = "RainbowButton"
rainbowButton.Size = UDim2.new(0, 180, 0, leftButtonHeight)
rainbowButton.Position = UDim2.new(0, leftColumnStart, 0, currentLeftY)
rainbowButton.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
rainbowButton.TextColor3 = Color3.new(1, 1, 1)
rainbowButton.Text = "Rainbow"
rainbowButton.Font = Enum.Font.GothamBold
rainbowButton.TextSize = 14
rainbowButton.ZIndex = 101
rainbowButton.Parent = espTabContent -- Перемещено на вкладку ESP
local rainbowCorner = Instance.new("UICorner")
rainbowCorner.CornerRadius = UDim.new(0, 5)
rainbowCorner.Parent = rainbowButton
local rainbowIndicator = Instance.new("Frame")
rainbowIndicator.Name = "RainbowIndicator"
rainbowIndicator.Size = UDim2.new(0, 20, 0, 20)
rainbowIndicator.Position = UDim2.new(1, -25, 0, 5)
rainbowIndicator.BackgroundColor3 = SETTINGS.ESP.RainbowEnabled and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
rainbowIndicator.BorderSizePixel = 0
rainbowIndicator.ZIndex = 102
rainbowIndicator.Parent = rainbowButton
local rainbowIndicatorCorner = Instance.new("UICorner")
rainbowIndicatorCorner.CornerRadius = UDim.new(0, 5)
rainbowIndicatorCorner.Parent = rainbowIndicator

local rightColumnStart = 10
local rightButtonHeight = 30
local rightVerticalSpacing = 10
local currentRightY = 10

local aimbotButton = Instance.new("TextButton")
aimbotButton.Name = "AimbotButton"
aimbotButton.Size = UDim2.new(0, 180, 0, rightButtonHeight)
aimbotButton.Position = UDim2.new(0, rightColumnStart, 0, currentRightY)
aimbotButton.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
aimbotButton.TextColor3 = Color3.new(1, 1, 1)
aimbotButton.Text = "Aimbot"
aimbotButton.Font = Enum.Font.GothamBold
aimbotButton.TextSize = 14
aimbotButton.ZIndex = 101
aimbotButton.Parent = aimbotTabContent -- Перемещено на вкладку Aimbot
local aimbotCorner = Instance.new("UICorner")
aimbotCorner.CornerRadius = UDim.new(0, 5)
aimbotCorner.Parent = aimbotButton
local aimbotIndicator = Instance.new("Frame")
aimbotIndicator.Name = "AimbotIndicator"
aimbotIndicator.Size = UDim2.new(0, 20, 0, 20)
aimbotIndicator.Position = UDim2.new(1, -25, 0, 5)
aimbotIndicator.BackgroundColor3 = SETTINGS.Aimbot.Enabled and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
aimbotIndicator.BorderSizePixel = 0
aimbotIndicator.ZIndex = 102
aimbotIndicator.Parent = aimbotButton
local aimbotIndicatorCorner = Instance.new("UICorner")
aimbotIndicatorCorner.CornerRadius = UDim.new(0, 5)
aimbotIndicatorCorner.Parent = aimbotIndicator
currentRightY += rightButtonHeight + rightVerticalSpacing

local fovToggleButton = Instance.new("TextButton")
fovToggleButton.Name = "FOVToggleButton"
fovToggleButton.Size = UDim2.new(0, 180, 0, rightButtonHeight)
fovToggleButton.Position = UDim2.new(0, rightColumnStart, 0, currentRightY)
fovToggleButton.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
fovToggleButton.TextColor3 = Color3.new(1, 1, 1)
fovToggleButton.Text = "FOV Circle"
fovToggleButton.Font = Enum.Font.GothamBold
fovToggleButton.TextSize = 14
fovToggleButton.ZIndex = 101
fovToggleButton.Parent = aimbotTabContent -- Перемещено на вкладку Aimbot
local fovToggleCorner = Instance.new("UICorner")
fovToggleCorner.CornerRadius = UDim.new(0, 5)
fovToggleCorner.Parent = fovToggleButton
local fovToggleIndicator = Instance.new("Frame")
fovToggleIndicator.Name = "FOVToggleIndicator"
fovToggleIndicator.Size = UDim2.new(0, 20, 0, 20)
fovToggleIndicator.Position = UDim2.new(1, -25, 0, 5)
fovToggleIndicator.BackgroundColor3 = SETTINGS.Aimbot.ShowFOV and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
fovToggleIndicator.BorderSizePixel = 0
fovToggleIndicator.ZIndex = 102
fovToggleIndicator.Parent = fovToggleButton
local fovToggleIndicatorCorner = Instance.new("UICorner")
fovToggleIndicatorCorner.CornerRadius = UDim.new(0, 5)
fovToggleIndicatorCorner.Parent = fovToggleIndicator
currentRightY += rightButtonHeight + rightVerticalSpacing

local fovLabel = Instance.new("TextLabel")
fovLabel.Name = "FOVLabel"
fovLabel.Size = UDim2.new(0, 180, 0, 20)
fovLabel.Position = UDim2.new(0, rightColumnStart, 0, currentRightY)
fovLabel.BackgroundTransparency = 1
fovLabel.TextColor3 = Color3.new(1, 1, 1)
fovLabel.Text = "FOV:"
fovLabel.Font = Enum.Font.GothamBold
fovLabel.TextSize = 14
fovLabel.ZIndex = 101
fovLabel.Parent = aimbotTabContent -- Перемещено на вкладку Aimbot
currentRightY += 20

local fovTextBox = Instance.new("TextBox")
fovTextBox.Name = "FOVTextBox"
fovTextBox.Size = UDim2.new(0, 180, 0, rightButtonHeight)
fovTextBox.Position = UDim2.new(0, rightColumnStart, 0, currentRightY)
fovTextBox.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
fovTextBox.TextColor3 = Color3.new(1, 1, 1)
fovTextBox.Text = tostring(SETTINGS.Aimbot.FOV)
fovTextBox.Font = Enum.Font.GothamBold
fovTextBox.TextSize = 14
fovTextBox.ZIndex = 101
fovTextBox.Parent = aimbotTabContent -- Перемещено на вкладку Aimbot
local fovTextBoxCorner = Instance.new("UICorner")
fovTextBoxCorner.CornerRadius = UDim.new(0, 5)
fovTextBoxCorner.Parent = fovTextBox
currentRightY += rightButtonHeight + rightVerticalSpacing

local distanceLabel = Instance.new("TextLabel")
distanceLabel.Name = "DistanceLabel"
distanceLabel.Size = UDim2.new(0, 180, 0, 20)
distanceLabel.Position = UDim2.new(0, rightColumnStart, 0, currentRightY)
distanceLabel.BackgroundTransparency = 1
distanceLabel.TextColor3 = Color3.new(1, 1, 1)
distanceLabel.Text = "Max Distance:"
distanceLabel.Font = Enum.Font.GothamBold
distanceLabel.TextSize = 14
distanceLabel.ZIndex = 101
distanceLabel.Parent = aimbotTabContent -- Перемещено на вкладку Aimbot
currentRightY += 20

local distanceTextBox = Instance.new("TextBox")
distanceTextBox.Name = "DistanceTextBox"
distanceTextBox.Size = UDim2.new(0, 180, 0, rightButtonHeight)
distanceTextBox.Position = UDim2.new(0, rightColumnStart, 0, currentRightY)
distanceTextBox.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
distanceTextBox.TextColor3 = Color3.new(1, 1, 1)
distanceTextBox.Text = tostring(SETTINGS.Aimbot.MaxDistance)
distanceTextBox.Font = Enum.Font.GothamBold
distanceTextBox.TextSize = 14
distanceTextBox.ZIndex = 101
distanceTextBox.Parent = aimbotTabContent -- Перемещено на вкладку Aimbot
local distanceTextBoxCorner = Instance.new("UICorner")
distanceTextBoxCorner.CornerRadius = UDim.new(0, 5)
distanceTextBoxCorner.Parent = distanceTextBox

local function styleButton(button)
    local originalSize = button.Size
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {Size = originalSize + UDim2.new(0, 5, 0, 5)}):Play()
        button.BackgroundColor3 = Color3.new(0.25, 0.25, 0.25)
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {Size = originalSize}):Play()
        button.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
    end)
end

styleButton(espTabButton)
styleButton(aimbotTabButton)
styleButton(miscTabButton)
styleButton(minimizeButton)

local minimized = false
local originalSize = frame.Size
local minimizedSize = UDim2.new(0, 400, 0, 30)

minimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        tabsFrame.Visible = false
        espTabContent.Visible = false
        aimbotTabContent.Visible = false
        miscTabContent.Visible = false
        local tween = TweenService:Create(frame, TweenInfo.new(0.3), {Size = minimizedSize})
        tween:Play()
        minimizeButton.Text = "+"
    else
        local tween = TweenService:Create(frame, TweenInfo.new(0.3), {Size = originalSize})
        tween:Play()
        tween.Completed:Connect(function()
            tabsFrame.Visible = true
            currentTab = currentTab or "ESP" -- Показываем первую вкладку после разворачивания
            if currentTab == "ESP" then
                espTabContent.Visible = true
                aimbotTabContent.Visible = false
                miscTabContent.Visible = false
            elseif currentTab == "Aimbot" then
                espTabContent.Visible = false
                aimbotTabContent.Visible = true
                miscTabContent.Visible = false
            elseif currentTab == "Misc" then
                espTabContent.Visible = false
                aimbotTabContent.Visible = false
                miscTabContent.Visible = true
            end
        end)
        minimizeButton.Text = "-"
    end
end)

local function animateIndicatorColor(indicator, enabled)
    local targetColor = enabled and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
    TweenService:Create(indicator, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
end

-- Логика переключения вкладок
local currentTab = "ESP"

local function switchTab(tabName)
    currentTab = tabName
    espTabContent.Visible = (tabName == "ESP")
    aimbotTabContent.Visible = (tabName == "Aimbot")
    miscTabContent.Visible = (tabName == "Misc")

    -- Обновление стиля кнопок вкладок (выделение активной)
    local tabs = {espTabButton, aimbotTabButton, miscTabButton}
    for _, tabButton in ipairs(tabs) do
        if tabButton.Name == tabName .. "TabButton" then
            tabButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
        else
            tabButton.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
        end
    end
end

espTabButton.MouseButton1Click:Connect(function()
    switchTab("ESP")
end)

aimbotTabButton.MouseButton1Click:Connect(function()
    switchTab("Aimbot")
end)

miscTabButton.MouseButton1Click:Connect(function()
    switchTab("Misc")
end)

-- Изначально показываем вкладку ESP
switchTab("ESP")

espButton.MouseButton1Click:Connect(function()
    SETTINGS.ESP.Enabled = not SETTINGS.ESP.Enabled
    animateIndicatorColor(espIndicator, SETTINGS.ESP.Enabled)
end)

aimbotButton.MouseButton1Click:Connect(function()
    SETTINGS.Aimbot.Enabled = not SETTINGS.Aimbot.Enabled
    animateIndicatorColor(aimbotIndicator, SETTINGS.Aimbot.Enabled)
end)

fovToggleButton.MouseButton1Click:Connect(function()
    SETTINGS.Aimbot.ShowFOV = not SETTINGS.Aimbot.ShowFOV
    fovCircle.Visible = SETTINGS.Aimbot.ShowFOV
    animateIndicatorColor(fovToggleIndicator, SETTINGS.Aimbot.ShowFOV)
end)

snaplineToggleButton.MouseButton1Click:Connect(function()
    SETTINGS.ESP.SnaplineEnabled = not SETTINGS.ESP.SnaplineEnabled
    animateIndicatorColor(snaplineToggleIndicator, SETTINGS.ESP.SnaplineEnabled)
end)

fovTextBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local newFOV = tonumber(fovTextBox.Text)
        if newFOV and newFOV >= 30 and newFOV <= 100 then
            SETTINGS.Aimbot.FOV = newFOV
        else
            fovTextBox.Text = tostring(SETTINGS.Aimbot.FOV)
        end
    end
end)

distanceTextBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local newDistance = tonumber(distanceTextBox.Text)
        if newDistance and newDistance > 0 and newDistance <= 1000 then
            SETTINGS.Aimbot.MaxDistance = newDistance
        else
            distanceTextBox.Text = tostring(SETTINGS.Aimbot.MaxDistance)
        end
    end
end)

local snaplinePositions = {"Center", "Bottom", "Top"}
local currentSnaplinePositionIndex = 1

snaplinePositionDropdown.MouseButton1Click:Connect(function()
    currentSnaplinePositionIndex = currentSnaplinePositionIndex + 1
    if currentSnaplinePositionIndex > #snaplinePositions then
        currentSnaplinePositionIndex = 1
    end
    SETTINGS.ESP.SnaplinePosition = snaplinePositions[currentSnaplinePositionIndex]
    snaplinePositionDropdown.Text = SETTINGS.ESP.SnaplinePosition
end)

rainbowButton.MouseButton1Click:Connect(function()
    SETTINGS.ESP.RainbowEnabled = not SETTINGS.ESP.RainbowEnabled
    animateIndicatorColor(rainbowIndicator, SETTINGS.ESP.RainbowEnabled)
end)

local guiVisible = true
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.RightShift then
        guiVisible = not guiVisible
        frame.Visible = guiVisible
    end
end)

local function showWelcomeNotification()
    local notification = Instance.new("ScreenGui")
    notification.Name = "WelcomeNotification"
    notification.Parent = CoreGui

    local nFrame = Instance.new("Frame")
    nFrame.Size = UDim2.new(0, 300, 0, 60)
    nFrame.Position = UDim2.new(0.5, -150, 1, 100)
    nFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    nFrame.BackgroundTransparency = 0.2
    nFrame.BorderSizePixel = 0
    nFrame.Parent = notification

    local nCorner = Instance.new("UICorner")
    nCorner.CornerRadius = UDim.new(0, 15)
    nCorner.Parent = nFrame

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(0.1, 0.5, 1)),
        ColorSequenceKeypoint.new(1, Color3.new(0.8, 0.2, 1))
    })
    gradient.Rotation = 45
    gradient.Parent = nFrame

    local shadow = Instance.new("ImageLabel")
    shadow.Size = UDim2.new(1, 10, 1, 10)
    shadow.Position = UDim2.new(0, -5, 0, -5)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://131604521"
    shadow.ImageColor3 = Color3.new(0, 0, 0)
    shadow.ImageTransparency = 0.5
    shadow.ZIndex = 99
    shadow.Parent = nFrame

    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.new(1, 1, 1)
    text.Text = "Welcome!"
    text.TextSize = 24
    text.Font = Enum.Font.GothamBold
    text.TextStrokeTransparency = 0.7
    text.TextStrokeColor3 = Color3.new(0, 0, 0)
    text.Parent = nFrame

    local tweenIn = TweenService:Create(nFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, -150, 1, -70)})
    tweenIn:Play()
    tweenIn.Completed:Wait()
    wait(2)
    local tweenOut = TweenService:Create(nFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5, -150, 1, 100)})
    tweenOut:Play()
    tweenOut.Completed:Wait()
    notification:Destroy()
end

RunService.RenderStepped:Connect(function()
    fovCircle.Radius = (SETTINGS.Aimbot.FOV / 2) * (Camera.ViewportSize.Y / 90)
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    fovCircle.Visible = SETTINGS.Aimbot.ShowFOV
    if SETTINGS.ESP.RainbowEnabled and SETTINGS.Aimbot.ShowFOV then
        local hue = (tick() * rainbowSpeed) % 1
        fovCircle.Color = Color3.fromHSV(hue, 1, 1)
    elseif SETTINGS.Aimbot.ShowFOV then
        fovCircle.Color = Color3.new(1, 1, 1)
    end

    for player, drawings in pairs(espCache) do
        updateESP(player, drawings)
    end

    if SETTINGS.Aimbot.Enabled then
        local target = getClosestPlayer()
        if target and target.Character and target.Character:FindFirstChild("Head") then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Character.Head.Position)
        end
    end
end)

-- Initialize ESP for existing players
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        createESP(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    createESP(player)
    player.CharacterAdded:Connect(function()
        if espCache[player] then
            for _, drawing in pairs(espCache[player]) do
                pcall(function() drawing:Remove() end)
            end
            espCache[player] = nil
        end
        createESP(player)
    end)
    player.CharacterRemoving:Connect(function()
        if espCache[player] then
            for _, drawing in pairs(espCache[player]) do
                pcall(function() drawing:Remove() end)
            end
            espCache[player] = nil
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    if espCache[player] then
        for _, drawing in pairs(espCache[player]) do
            pcall(function() drawing:Remove() end)
        end
        espCache[player] = nil
    end
end)

showWelcomeNotification()

warn("✅ Script successfully activated!")
