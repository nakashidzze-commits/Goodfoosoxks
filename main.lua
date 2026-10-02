--============================================================
-- ItsWalker AutoFarm v3.0 (One Button)
-- FARM (авто-старт) + Coin Aura + Auto Reset + Anti-AFK + Auto Fling
-- Скорость сразу 22
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

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

--============================================================
-- НАСТРОЙКИ (всё включено сразу)
--============================================================

local FARM_SPEED = 23
local COIN_Y_OFFSET = -5.05
local MAX_TARGET_DISTANCE = 500
local COLLECT_DISTANCE = 6.5
local LOOP_DELAY = 0.02
local HRP_SIZE = Vector3.new(2, 12, 1)

local COIN_AURA_ENABLED = true
local COIN_AURA_RADIUS = 12

local AUTO_RESET_ENABLED = true
local BAG_MAX_DEFAULT = 50

local LOBBY_Y_THRESHOLD = 500
local NO_COIN_PAUSE_TIME = 2

local ANTI_AFK_ENABLED = true
local AUTO_FLING_ENABLED = true

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
-- GUI — ОДНА КНОПКА
--============================================================

local oldGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("ItsWalkerFarmGui")
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ItsWalkerFarmGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 100
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local FarmBtn = Instance.new("TextButton")
FarmBtn.Name = "FarmBtn"
FarmBtn.AnchorPoint = Vector2.new(0.5, 0.5)
FarmBtn.Position = UDim2.new(0.15, 0, 0.5, 0)
FarmBtn.Size = UDim2.fromOffset(130, 55)
FarmBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
FarmBtn.BackgroundTransparency = 0.05
FarmBtn.BorderSizePixel = 0
FarmBtn.Text = "FARM: ON"
FarmBtn.TextColor3 = Color3.fromRGB(80, 255, 120)
FarmBtn.TextSize = 16
FarmBtn.Font = Enum.Font.GothamBold
FarmBtn.Active = true
FarmBtn.Draggable = true
FarmBtn.Parent = ScreenGui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 14)
btnCorner.Parent = FarmBtn

local btnStroke = Instance.new("UIStroke")
btnStroke.Color = Color3.fromRGB(80, 255, 120)
btnStroke.Thickness = 2
btnStroke.Transparency = 0.1
btnStroke.Parent = FarmBtn

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

local function PauseFarm()
	if Paused then return end
	Paused = true
	ReleaseTarget()
	DestroyMovement()
	RestoreHRPSize()
end

local function ResumeFarm()
	if not Paused then return end
	Paused = false
end

--============================================================
-- AUTO RESET
--============================================================

local function DoReset()
	if Resetting then return end
	Resetting = true
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
		if IsInLobby() then PauseFarm(); task.wait(0.5); continue end
		if not CurrentCoin then
			local coin, dist = FindNearestCoin()
			if not coin then
				if os.clock() - LastCoinTime > NO_COIN_PAUSE_TIME then PauseFarm() end
				task.wait(0.2)
				continue
			end
			LastCoinTime = os.clock()
			if dist > MAX_TARGET_DISTANCE then task.wait(0.1); continue end
			if Paused then ResumeFarm() end
			if not EnsureMovement() then task.wait(0.05); continue end
			SelectTarget(coin)
		end
		if not CurrentCoin then continue end
		if not CurrentCoin:IsDescendantOf(workspace) then ReleaseTarget(); continue end
		local coinPos = GetPosition(CurrentCoin)
		if not coinPos then ReleaseTarget(); continue end
		local d = (HRP.Position - coinPos).Magnitude
		if d > MAX_TARGET_DISTANCE then ReleaseTarget(); continue end
		local coll = CheckCollection(CurrentCoin, coinPos)
		if coll == true or coll == "invalid" then
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

function StartFarm()
	if Running then return end
	Running = true
	Paused = false
	LastCoinTime = os.clock()
	ReleaseTarget()
	table.clear(SkippedCoins)
	UpdateCharacter()
	ApplyHRPSize()
	StartNoclip()
	if COIN_AURA_ENABLED and HAS_FIRETOUCH then StartCoinAura() end
	task.spawn(FarmLoop)
	FarmBtn.Text = "FARM: ON"
	FarmBtn.TextColor3 = Color3.fromRGB(80, 255, 120)
	btnStroke.Color = Color3.fromRGB(80, 255, 120)
end

function StopFarm()
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
	FarmBtn.Text = "FARM: OFF"
	FarmBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
	btnStroke.Color = Color3.fromRGB(255, 80, 80)
end

--============================================================
-- КНОПКА
--============================================================

FarmBtn.MouseButton1Click:Connect(function()
	if Running then
		StopFarm()
	else
		StartFarm()
	end
end)

--============================================================
-- ПЕРЕЗАПУСК ПРИ РЕСПАВНЕ
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
	if RespawnGuard then return end
	RespawnGuard = true

	task.wait(1.5)

	local scriptUrl = "https://raw.githubusercontent.com/nakashidzze-commits/Goodfoosoxks/refs/heads/main/main.lua"

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
-- АВТО-СТАРТ
--============================================================

HookBagCounter()
if ANTI_AFK_ENABLED then StartAntiAfk() end

-- Включаем фарм сразу при загрузке
task.wait(1)
StartFarm()

print("[ItsWalker AutoFarm v3.0] Загружено! Фарм запущен автоматически.")
