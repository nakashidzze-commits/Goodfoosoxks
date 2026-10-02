--============================================================
-- ItsWalker AutoFarm v2.0
-- AutoFarm + Coin Aura + Auto Reset + Фикс лобби + Anti-AFK
-- + Auto Fling Killer + Перезапуск при респавне
--
-- ЗАГРУЗИ ЭТОТ ФАЙЛ НА GITHUB КАК main.lua
-- Затем в Arceus X запусти:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/ТВОЙ_НИК/ТВОЙ_РЕПО/main/main.lua"))()
--============================================================

--============================================================
-- ПРОВЕРКА НА ПОВТОРНЫЙ ЗАПУСК
--============================================================

if _G.ItsWalkerFarmRunning then
	pcall(function()
		if _G.ItsWalkerFarmCleanup then
			_G.ItsWalkerFarmCleanup()
		end
	end)
	task.wait(0.5)
end

_G.ItsWalkerFarmRunning = true

--============================================================
-- СЕРВИСЫ
--============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

--============================================================
-- НАСТРОЙКИ
--============================================================

local FARM_SPEED = 25
local MIN_SPEED = 5
local MAX_SPEED = 30
local COIN_Y_OFFSET = -5.05
local MAX_TARGET_DISTANCE = 500
local COLLECT_DISTANCE = 6.5
local LOOP_DELAY = 0.02
local HRP_SIZE = Vector3.new(2, 12, 1)

local COIN_AURA_ENABLED = false
local COIN_AURA_RADIUS = 12

local AUTO_RESET_ENABLED = true
local BAG_MAX_DEFAULT = 50

local LOBBY_Y_THRESHOLD = 500
local NO_COIN_PAUSE_TIME = 2

local ANTI_AFK_ENABLED = true
local AUTO_FLING_ENABLED = true
local AUTO_RESTART_ON_RESPAWN = true

--============================================================
-- ПРОВЕРКА ИСПОЛНИТЕЛЯ
--============================================================

local HAS_FIRETOUCH = (type(firetouchinterest) == "function")

--============================================================
-- СОСТОЯНИЕ
--============================================================

local Running = false
local Character = nil
local Humanoid = nil
local HRP = nil

local Attachment = nil
local PositionAlign = nil
local UprightAlign = nil

local CurrentCoin = nil
local CurrentTouch = nil

local NoclipConnection = nil
local OriginalCollision = {}

local OriginalHRPSize = nil
local SizedHRP = nil

local SkippedCoins = setmetatable({}, {__mode = "k"})
local CoinAuraConnection = nil

local BagCount = 0
local BagMax = BAG_MAX_DEFAULT
local Resetting = false

local LastCoinTime = os.clock()
local Paused = false

local AntiAfkConnection = nil
local Minimized = false
local RespawnGuard = false

--============================================================
-- FLING KILLER
--============================================================

local FLING_VELOCITY = Vector3.new(9e7, 9e8, 9e7)
local FLING_ANGULAR = Vector3.new(9e8, 9e8, 9e8)

local function FlingTarget(targetCharacter)
	if not targetCharacter then return end
	local targetHRP = targetCharacter:FindFirstChild("HumanoidRootPart")
	if not targetHRP then return end
	pcall(function()
		targetHRP.AssemblyLinearVelocity = FLING_VELOCITY
		targetHRP.AssemblyAngularVelocity = FLING_ANGULAR
	end)
end

local function HookKillerFling(character)
	local hum = character:WaitForChild("Humanoid", 5)
	if not hum then return end
	hum.Died:Connect(function()
		if not AUTO_FLING_ENABLED then return end
		task.wait(0.1)
		local creatorTag = hum:FindFirstChild("creator")
		if not creatorTag or not creatorTag.Value then return end
		local killer = creatorTag.Value
		if killer and killer.Character then
			FlingTarget(killer.Character)
		end
	end)
end

--============================================================
-- GUI
--============================================================

local oldGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("ItsWalkerAutoFarm")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ItsWalkerAutoFarm"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 100
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local Panel = Instance.new("Frame")
Panel.Name = "Panel"
Panel.AnchorPoint = Vector2.new(0.5, 0.5)
Panel.Position = UDim2.new(0.5, 0, 0.5, 0)
Panel.Size = UDim2.fromOffset(260, 380)
Panel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
Panel.BackgroundTransparency = 0.05
Panel.BorderSizePixel = 0
Panel.Active = true
Panel.Draggable = true
Panel.Parent = ScreenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = Panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(80, 220, 255)
panelStroke.Thickness = 2
panelStroke.Transparency = 0.1
panelStroke.Parent = Panel

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.AnchorPoint = Vector2.new(1, 0)
MinimizeBtn.Position = UDim2.new(1, -8, 0, 8)
MinimizeBtn.Size = UDim2.fromOffset(28, 28)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
MinimizeBtn.BorderSizePixel = 0
MinimizeBtn.Text = "—"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.TextSize = 18
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.Parent = Panel
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 0, 30)
Title.Position = UDim2.fromOffset(10, 8)
Title.BackgroundTransparency = 1
Title.Text = "ItsWalker AutoFarm v2.0"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Panel

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -20, 0, 24)
Status.Position = UDim2.fromOffset(10, 42)
Status.BackgroundTransparency = 1
Status.Text = "Статус: Выключен"
Status.TextColor3 = Color3.fromRGB(180, 180, 190)
Status.TextSize = 12
Status.Font = Enum.Font.Gotham
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Parent = Panel

local ExecInfo = Instance.new("TextLabel")
ExecInfo.Size = UDim2.new(1, -20, 0, 20)
ExecInfo.Position = UDim2.fromOffset(10, 66)
ExecInfo.BackgroundTransparency = 1
ExecInfo.Text = HAS_FIRETOUCH and "firetouchinterest: ЕСТЬ" or "firetouchinterest: НЕТ"
ExecInfo.TextColor3 = HAS_FIRETOUCH and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 180, 80)
ExecInfo.TextSize = 11
ExecInfo.Font = Enum.Font.Gotham
ExecInfo.TextXAlignment = Enum.TextXAlignment.Left
ExecInfo.Parent = Panel

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.AnchorPoint = Vector2.new(0.5, 0.5)
ToggleBtn.Position = UDim2.new(0.5, 0, 0, 100)
ToggleBtn.Size = UDim2.fromOffset(220, 40)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Text = "ВКЛЮЧИТЬ ФАРМ"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = Panel
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 12)
local btnStroke = Instance.new("UIStroke", ToggleBtn)
btnStroke.Color = Color3.fromRGB(255, 80, 80)
btnStroke.Thickness = 2
btnStroke.Transparency = 0.1

local AuraBtn = Instance.new("TextButton")
AuraBtn.AnchorPoint = Vector2.new(0.5, 0.5)
AuraBtn.Position = UDim2.new(0.5, 0, 0, 148)
AuraBtn.Size = UDim2.fromOffset(220, 36)
AuraBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
AuraBtn.BorderSizePixel = 0
AuraBtn.Text = "COIN AURA: OFF"
AuraBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AuraBtn.TextSize = 13
AuraBtn.Font = Enum.Font.GothamBold
AuraBtn.Parent = Panel
Instance.new("UICorner", AuraBtn).CornerRadius = UDim.new(0, 10)
local auraStroke = Instance.new("UIStroke", AuraBtn)
auraStroke.Color = Color3.fromRGB(255, 150, 50)
auraStroke.Thickness = 2
auraStroke.Transparency = 0.3

local ResetBtn = Instance.new("TextButton")
ResetBtn.AnchorPoint = Vector2.new(0.5, 0.5)
ResetBtn.Position = UDim2.new(0.5, 0, 0, 192)
ResetBtn.Size = UDim2.fromOffset(220, 36)
ResetBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
ResetBtn.BorderSizePixel = 0
ResetBtn.Text = "AUTO RESET: ON"
ResetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ResetBtn.TextSize = 13
ResetBtn.Font = Enum.Font.GothamBold
ResetBtn.Parent = Panel
Instance.new("UICorner", ResetBtn).CornerRadius = UDim.new(0, 10)
local resetStroke = Instance.new("UIStroke", ResetBtn)
resetStroke.Color = Color3.fromRGB(80, 255, 120)
resetStroke.Thickness = 2
resetStroke.Transparency = 0.3

local AfkBtn = Instance.new("TextButton")
AfkBtn.AnchorPoint = Vector2.new(0.5, 0.5)
AfkBtn.Position = UDim2.new(0.5, 0, 0, 236)
AfkBtn.Size = UDim2.fromOffset(220, 36)
AfkBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
AfkBtn.BorderSizePixel = 0
AfkBtn.Text = "ANTI-AFK: ON"
AfkBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AfkBtn.TextSize = 13
AfkBtn.Font = Enum.Font.GothamBold
AfkBtn.Parent = Panel
Instance.new("UICorner", AfkBtn).CornerRadius = UDim.new(0, 10)
local afkStroke = Instance.new("UIStroke", AfkBtn)
afkStroke.Color = Color3.fromRGB(80, 255, 120)
afkStroke.Thickness = 2
afkStroke.Transparency = 0.3

local FlingBtn = Instance.new("TextButton")
FlingBtn.AnchorPoint = Vector2.new(0.5, 0.5)
FlingBtn.Position = UDim2.new(0.5, 0, 0, 280)
FlingBtn.Size = UDim2.fromOffset(220, 36)
FlingBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
FlingBtn.BorderSizePixel = 0
FlingBtn.Text = "AUTO FLING: ON"
FlingBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FlingBtn.TextSize = 13
FlingBtn.Font = Enum.Font.GothamBold
FlingBtn.Parent = Panel
Instance.new("UICorner", FlingBtn).CornerRadius = UDim.new(0, 10)
local flingStroke = Instance.new("UIStroke", FlingBtn)
flingStroke.Color = Color3.fromRGB(255, 80, 80)
flingStroke.Thickness = 2
flingStroke.Transparency = 0.3

local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(1, -20, 0, 18)
SpeedLabel.Position = UDim2.fromOffset(10, 306)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Text = "Скорость фарма (5-30):"
SpeedLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
SpeedLabel.TextSize = 12
SpeedLabel.Font = Enum.Font.Gotham
SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
SpeedLabel.Parent = Panel

local SpeedInput = Instance.new("TextBox")
SpeedInput.AnchorPoint = Vector2.new(0, 0.5)
SpeedInput.Position = UDim2.new(0, 10, 0, 339)
SpeedInput.Size = UDim2.new(1, -20, 0, 32)
SpeedInput.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
SpeedInput.BorderSizePixel = 0
SpeedInput.Text = tostring(FARM_SPEED)
SpeedInput.PlaceholderText = "5-30"
SpeedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedInput.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
SpeedInput.TextSize = 14
SpeedInput.Font = Enum.Font.GothamBold
SpeedInput.ClearTextOnFocus = false
SpeedInput.Parent = Panel
Instance.new("UICorner", SpeedInput).CornerRadius = UDim.new(0, 10)
local inputStroke = Instance.new("UIStroke", SpeedInput)
inputStroke.Color = Color3.fromRGB(80, 220, 255)
inputStroke.Thickness = 1.5
inputStroke.Transparency = 0.3

local BagInfo = Instance.new("TextLabel")
BagInfo.Size = UDim2.new(1, -20, 0, 18)
BagInfo.Position = UDim2.fromOffset(10, 358)
BagInfo.BackgroundTransparency = 1
BagInfo.Text = "Сумка: 0/" .. BagMax
BagInfo.TextColor3 = Color3.fromRGB(200, 200, 210)
BagInfo.TextSize = 11
BagInfo.Font = Enum.Font.Gotham
BagInfo.TextXAlignment = Enum.TextXAlignment.Left
BagInfo.Parent = Panel

local MiniTab = Instance.new("TextButton")
MiniTab.AnchorPoint = Vector2.new(0.5, 0.5)
MiniTab.Position = Panel.Position
MiniTab.Size = UDim2.fromOffset(120, 40)
MiniTab.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
MiniTab.BackgroundTransparency = 0.05
MiniTab.BorderSizePixel = 0
MiniTab.Text = "ItsWalker ▲"
MiniTab.TextColor3 = Color3.fromRGB(80, 220, 255)
MiniTab.TextSize = 13
MiniTab.Font = Enum.Font.GothamBold
MiniTab.Visible = false
MiniTab.Active = true
MiniTab.Draggable = true
MiniTab.Parent = ScreenGui
Instance.new("UICorner", MiniTab).CornerRadius = UDim.new(0, 12)
local miniStroke = Instance.new("UIStroke", MiniTab)
miniStroke.Color = Color3.fromRGB(80, 220, 255)
miniStroke.Thickness = 2
miniStroke.Transparency = 0.2

MinimizeBtn.MouseButton1Click:Connect(function()
	Minimized = true
	Panel.Visible = false
	MiniTab.Position = Panel.Position
	MiniTab.Visible = true
end)

MiniTab.MouseButton1Click:Connect(function()
	Minimized = false
	MiniTab.Visible = false
	Panel.Position = MiniTab.Position
	Panel.Visible = true
end)

--============================================================
-- ANTI-AFK
--============================================================

local function StartAntiAfk()
	if AntiAfkConnection then return end
	AntiAfkConnection = LocalPlayer.Idled:Connect(function()
		if not ANTI_AFK_ENABLED then return end
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new(0, 0))
		end)
	end)
end

local function StopAntiAfk()
	if AntiAfkConnection then
		AntiAfkConnection:Disconnect()
		AntiAfkConnection = nil
	end
end

--============================================================
-- ФУНКЦИИ
--============================================================

local function UpdateCharacter()
	Character = LocalPlayer.Character
	if not Character then
		Humanoid = nil
		HRP = nil
		return false
	end
	Humanoid = Character:FindFirstChildOfClass("Humanoid")
	HRP = Character:FindFirstChild("HumanoidRootPart")
	return Humanoid ~= nil and HRP ~= nil
end

local function RestoreHRPSize()
	if SizedHRP and SizedHRP.Parent and OriginalHRPSize then
		pcall(function() SizedHRP.Size = OriginalHRPSize end)
	end
	OriginalHRPSize = nil
	SizedHRP = nil
end

local function ApplyHRPSize()
	if not UpdateCharacter() then return end
	if SizedHRP and SizedHRP ~= HRP then RestoreHRPSize() end
	if SizedHRP ~= HRP then
		SizedHRP = HRP
		OriginalHRPSize = HRP.Size
	end
	pcall(function() HRP.Size = HRP_SIZE end)
end

local function IsCoin(obj)
	return obj and obj.Name == "Coin_Server" and (obj:IsA("BasePart") or obj:IsA("Model"))
end

local function GetPosition(obj)
	if not obj then return nil end
	if obj:IsA("BasePart") then return obj.Position end
	if obj:IsA("Model") then
		local ok, pivot = pcall(function() return obj:GetPivot() end)
		if ok then return pivot.Position end
	end
	return nil
end

local function GetTouch(coin)
	if not coin then return nil end
	local direct = coin:FindFirstChild("TouchInterest")
	if direct then return direct end
	for _, obj in ipairs(coin:GetDescendants()) do
		if obj.Name == "TouchInterest" or obj:IsA("TouchTransmitter") then return obj end
	end
	return nil
end

local function IsValidCoin(coin)
	return coin and IsCoin(coin) and coin:IsDescendantOf(workspace)
		and GetPosition(coin) ~= nil and GetTouch(coin) ~= nil
end

local function IsSkipped(coin)
	local t = SkippedCoins[coin]
	if not t then return false end
	if os.clock() >= t then SkippedCoins[coin] = nil; return false end
	return true
end

local function FindNearestCoin()
	if not HRP then return nil, math.huge end
	local best, bestDist = nil, math.huge
	for _, obj in ipairs(workspace:GetDescendants()) do
		if IsValidCoin(obj) and not IsSkipped(obj) then
			local pos = GetPosition(obj)
			if pos then
				local d = (HRP.Position - pos).Magnitude
				if d < bestDist then best, bestDist = obj, d end
			end
		end
	end
	return best, bestDist
end

local function DestroyMovement()
	if PositionAlign then pcall(function() PositionAlign:Destroy() end) end
	if UprightAlign then pcall(function() UprightAlign:Destroy() end) end
	if Attachment then pcall(function() Attachment:Destroy() end) end
	PositionAlign = nil
	UprightAlign = nil
	Attachment = nil
end

local function EnsureMovement()
	if not Running then return false end
	if not UpdateCharacter() then return false end

	ApplyHRPSize()

	if Attachment and Attachment.Parent == HRP
		and PositionAlign and PositionAlign.Parent == HRP
		and UprightAlign and UprightAlign.Parent == HRP then
		return true
	end

	DestroyMovement()

	Attachment = Instance.new("Attachment")
	Attachment.Name = "ItsWalkerFarmAttachment"
	Attachment.Parent = HRP

	PositionAlign = Instance.new("AlignPosition")
	PositionAlign.Name = "ItsWalkerFarmAlign"
	PositionAlign.Mode = Enum.PositionAlignmentMode.OneAttachment
	PositionAlign.Attachment0 = Attachment
	PositionAlign.MaxVelocity = FARM_SPEED
	PositionAlign.Responsiveness = 18
	PositionAlign.MaxForce = 500000
	PositionAlign.ApplyAtCenterOfMass = true
	PositionAlign.RigidityEnabled = false
	PositionAlign.Position = HRP.Position
	PositionAlign.Parent = HRP

	UprightAlign = Instance.new("AlignOrientation")
	UprightAlign.Name = "ItsWalkerFarmUpright"
	UprightAlign.Mode = Enum.OrientationAlignmentMode.OneAttachment
	UprightAlign.Attachment0 = Attachment
	UprightAlign.Responsiveness = 12
	UprightAlign.MaxTorque = 500000
	UprightAlign.MaxAngularVelocity = 10
	UprightAlign.RigidityEnabled = false
	UprightAlign.Parent = HRP

	return true
end

local function ApplyNoclip()
	if not Running then return end
	if not Character or not Humanoid then return end
	ApplyHRPSize()
	for _, obj in ipairs(Character:GetDescendants()) do
		if obj:IsA("BasePart") then
			if OriginalCollision[obj] == nil then
				OriginalCollision[obj] = obj.CanCollide
			end
			obj.CanCollide = false
		end
	end
	Humanoid.Sit = false
	local state = Humanoid:GetState()
	if state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Seated then
		Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

local function StartNoclip()
	if NoclipConnection then NoclipConnection:Disconnect(); NoclipConnection = nil end
	table.clear(OriginalCollision)
	ApplyNoclip()
	NoclipConnection = RunService.Stepped:Connect(function()
		if not Running or Paused then return end
		if UpdateCharacter() then ApplyNoclip() end
	end)
end

local function StopNoclip()
	if NoclipConnection then NoclipConnection:Disconnect(); NoclipConnection = nil end
	for part, oldState in pairs(OriginalCollision) do
		if part and part.Parent then
			pcall(function() part.CanCollide = oldState end)
		end
	end
	table.clear(OriginalCollision)
end

local function ReleaseTarget()
	CurrentCoin = nil
	CurrentTouch = nil
end

local function SelectTarget(coin)
	if not IsValidCoin(coin) or not EnsureMovement() then return false end
	local coinPos = GetPosition(coin)
	if not coinPos then return false end
	CurrentCoin = coin
	CurrentTouch = GetTouch(coin)
	if PositionAlign then
		PositionAlign.Position = Vector3.new(coinPos.X, coinPos.Y + COIN_Y_OFFSET, coinPos.Z)
	end
	return true
end

local function CheckCollection(coin, coinPos)
	local oldTouch = CurrentTouch
	local newTouch = GetTouch(coin)
	CurrentTouch = newTouch
	if oldTouch and not newTouch then
		local d = HRP and (HRP.Position - coinPos).Magnitude or math.huge
		if d <= COLLECT_DISTANCE then return true else return "invalid" end
	end
	return false
end

local function IsInLobby()
	if not HRP then return false end
	return HRP.Position.Y > LOBBY_Y_THRESHOLD
end

local function PauseFarm(reason)
	if Paused then return end
	Paused = true
	ReleaseTarget()
	DestroyMovement()
	RestoreHRPSize()
	Status.Text = "Статус: Пауза (" .. (reason or "?") .. ")"
end

local function ResumeFarm()
	if not Paused then return end
	Paused = false
	Status.Text = "Статус: Фарм работает"
end

--============================================================
-- AUTO RESET
--============================================================

local function DoReset()
	if Resetting then return end
	Resetting = true
	Status.Text = "Статус: Сумка полная! Ресет..."
	local wasRunning = Running
	Running = false
	ReleaseTarget()
	StopNoclip()
	DestroyMovement()
	RestoreHRPSize()
	task.wait(0.3)
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		pcall(function() hum.Health = 0 end)
	end
	task.wait(2)
	BagCount = 0
	BagInfo.Text = "Сумка: 0/" .. BagMax
	if wasRunning then
		task.wait(0.5)
		StartFarm()
	end
	Resetting = false
end

--============================================================
-- COIN AURA
--============================================================

local function StartCoinAura()
	if not HAS_FIRETOUCH then return end
	if CoinAuraConnection then return end
	CoinAuraConnection = RunService.Heartbeat:Connect(function()
		if not COIN_AURA_ENABLED then return end
		if Paused then return end
		if not UpdateCharacter() or not HRP then return end
		for _, obj in ipairs(workspace:GetDescendants()) do
			if IsValidCoin(obj) then
				local pos = GetPosition(obj)
				if pos then
					local d = (HRP.Position - pos).Magnitude
					if d <= COIN_AURA_RADIUS and not IsSkipped(obj) then
						pcall(function() firetouchinterest(obj, HRP, 0) end)
						task.wait(0.03)
						pcall(function() firetouchinterest(obj, HRP, 1) end)
					end
				end
			end
		end
	end)
end

local function StopCoinAura()
	if CoinAuraConnection then CoinAuraConnection:Disconnect(); CoinAuraConnection = nil end
end

--============================================================
-- ОТСЛЕЖИВАНИЕ СУМКИ
--============================================================

local function HookBagCounter()
	local RS = game:GetService("ReplicatedStorage")
	local remotes = RS:FindFirstChild("Remotes")
	local gameplay = remotes and remotes:FindFirstChild("Gameplay")
	local coinCollected = gameplay and gameplay:FindFirstChild("CoinCollected")
	if coinCollected and coinCollected:IsA("RemoteEvent") then
		coinCollected.OnClientEvent:Connect(function(...)
			local args = {...}
			local current = tonumber(args[2])
			local maximum = tonumber(args[3])
			if maximum and maximum > 0 then BagMax = maximum end
			if current then
				BagCount = current
				BagInfo.Text = "Сумка: " .. BagCount .. "/" .. BagMax
				if AUTO_RESET_ENABLED and BagCount >= BagMax and not Resetting then
					DoReset()
				end
			end
		end)
	end
end

--============================================================
-- ГЛАВНЫЙ ЦИКЛ
--============================================================

local function FarmLoop()
	while Running do
		if not UpdateCharacter() then task.wait(0.1); continue end
		if Humanoid.Health <= 0 then task.wait(0.1); continue end
		if IsInLobby() then PauseFarm("лобби"); task.wait(0.5); continue end
		if not CurrentCoin then
			local coin, dist = FindNearestCoin()
			if not coin then
				if os.clock() - LastCoinTime > NO_COIN_PAUSE_TIME then PauseFarm("нет монет") end
				task.wait(0.2)
				continue
			end
			LastCoinTime = os.clock()
			if dist > MAX_TARGET_DISTANCE then task.wait(0.1); continue end
			if Paused then ResumeFarm() end
			if not EnsureMovement() then task.wait(0.05); continue end
			SelectTarget(coin)
			Status.Text = "Статус: Летим к монете"
		end
		if not CurrentCoin then continue end
		if not CurrentCoin:IsDescendantOf(workspace) then ReleaseTarget(); continue end
		local coinPos = GetPosition(CurrentCoin)
		if not coinPos then ReleaseTarget(); continue end
		local d = (HRP.Position - coinPos).Magnitude
		if d > MAX_TARGET_DISTANCE then ReleaseTarget(); continue end
		local coll = CheckCollection(CurrentCoin, coinPos)
		if coll == true or coll == "invalid" then
			Status.Text = "Статус: Монета собрана"
			ReleaseTarget()
			continue
		end
		if PositionAlign then
			ApplyHRPSize()
			PositionAlign.Position = Vector3.new(coinPos.X, coinPos.Y + COIN_Y_OFFSET, coinPos.Z)
			PositionAlign.MaxVelocity = FARM_SPEED
		end
		task.wait(LOOP_DELAY)
	end
end

local function StartFarm()
	if Running then return end
	Running = true
	Paused = false
	LastCoinTime = os.clock()
	ReleaseTarget()
	table.clear(SkippedCoins)
	UpdateCharacter()
	ApplyHRPSize()
	StartNoclip()
	task.spawn(FarmLoop)
end

local function StopFarm()
	Running = false
	Paused = false
	ReleaseTarget()
	StopNoclip()
	DestroyMovement()
	RestoreHRPSize()
	if UpdateCharacter() then
		pcall(function()
			Humanoid.Sit = false
			Humanoid.PlatformStand = false
			HRP.AssemblyLinearVelocity = Vector3.zero
			HRP.AssemblyAngularVelocity = Vector3.zero
		end)
	end
	table.clear(SkippedCoins)
end

--============================================================
-- ПОЛЕ ВВОДА
--============================================================

SpeedInput.FocusLost:Connect(function()
	local value = tonumber(SpeedInput.Text)
	if not value then SpeedInput.Text = tostring(FARM_SPEED); return end
	value = math.clamp(math.floor(value), MIN_SPEED, MAX_SPEED)
	FARM_SPEED = value
	SpeedInput.Text = tostring(FARM_SPEED)
	if PositionAlign then PositionAlign.MaxVelocity = FARM_SPEED end
end)

--============================================================
-- КНОПКИ
--============================================================

ToggleBtn.MouseButton1Click:Connect(function()
	if Running then
		StopFarm()
		ToggleBtn.Text = "ВКЛЮЧИТЬ ФАРМ"
		btnStroke.Color = Color3.fromRGB(255, 80, 80)
		Status.Text = "Статус: Выключен"
	else
		StartFarm()
		ToggleBtn.Text = "ВЫКЛЮЧИТЬ ФАРМ"
		btnStroke.Color = Color3.fromRGB(80, 255, 120)
		Status.Text = "Статус: Включен"
	end
end)

AuraBtn.MouseButton1Click:Connect(function()
	if not HAS_FIRETOUCH then
		AuraBtn.Text = "COIN AURA: НЕДОСТУПНА"
		task.delay(2, function() AuraBtn.Text = "COIN AURA: OFF" end)
		return
	end
	COIN_AURA_ENABLED = not COIN_AURA_ENABLED
	if COIN_AURA_ENABLED then
		AuraBtn.Text = "COIN AURA: ON"
		auraStroke.Color = Color3.fromRGB(80, 255, 120)
		StartCoinAura()
	else
		AuraBtn.Text = "COIN AURA: OFF"
		auraStroke.Color = Color3.fromRGB(255, 150, 50)
		StopCoinAura()
	end
end)

ResetBtn.MouseButton1Click:Connect(function()
	AUTO_RESET_ENABLED = not AUTO_RESET_ENABLED
	if AUTO_RESET_ENABLED then
		ResetBtn.Text = "AUTO RESET: ON"
		resetStroke.Color = Color3.fromRGB(80, 255, 120)
	else
		ResetBtn.Text = "AUTO RESET: OFF"
		resetStroke.Color = Color3.fromRGB(255, 150, 50)
	end
end)

AfkBtn.MouseButton1Click:Connect(function()
	ANTI_AFK_ENABLED = not ANTI_AFK_ENABLED
	if ANTI_AFK_ENABLED then
		AfkBtn.Text = "ANTI-AFK: ON"
		afkStroke.Color = Color3.fromRGB(80, 255, 120)
		StartAntiAfk()
	else
		AfkBtn.Text = "ANTI-AFK: OFF"
		afkStroke.Color = Color3.fromRGB(255, 150, 50)
		StopAntiAfk()
	end
end)

FlingBtn.MouseButton1Click:Connect(function()
	AUTO_FLING_ENABLED = not AUTO_FLING_ENABLED
	if AUTO_FLING_ENABLED then
		FlingBtn.Text = "AUTO FLING: ON"
		flingStroke.Color = Color3.fromRGB(255, 80, 80)
	else
		FlingBtn.Text = "AUTO FLING: OFF"
		flingStroke.Color = Color3.fromRGB(100, 100, 110)
	end
end)

--============================================================
-- ФИКС РЕСПАВНА — АВТО-ПЕРЕЗАПУСК
--============================================================

_G.ItsWalkerFarmCleanup = function()
	pcall(function()
		Running = false
		StopNoclip()
		DestroyMovement()
		RestoreHRPSize()
		StopCoinAura()
		StopAntiAfk()
		if ScreenGui then ScreenGui:Destroy() end
	end)
end

LocalPlayer.CharacterAdded:Connect(function(newChar)
	if not AUTO_RESTART_ON_RESPAWN then return end
	if RespawnGuard then return end
	RespawnGuard = true

	task.wait(1.5)

	-- Перезапускаем скрипт с того же URL, откуда он был загружен
	local scriptUrl = "https://raw.githubusercontent.com/ТВОЙ_НИК/ТВОЙ_РЕПО/main/main.lua"

	pcall(function()
		loadstring(game:HttpGet(scriptUrl))()
	end)

	task.wait(0.5)
	RespawnGuard = false
end)

if LocalPlayer.Character then
	HookKillerFling(LocalPlayer.Character)
end

--============================================================
-- СТАРТ
--============================================================

HookBagCounter()
if ANTI_AFK_ENABLED then StartAntiAfk() end

print("[ItsWalker AutoFarm v2.0] Загружено!")
