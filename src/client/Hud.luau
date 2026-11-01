--[[
	Hud - chunky late-90s interface: title screen, hearts, counters, toasts,
	the Carrot Log (golden carrot checklist) and the ending card.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local P = Config.Palette

local player = Players.LocalPlayer
local Hud = {}

local gui, heartsFrame, carrotLabel, goldenLabel, toastLabel, saveLabel
local titleFrame, journalFrame, journalList, endFrame
local hearts = {}
local profile = nil
local toastToken = 0

local FONT = Enum.Font.Arcade

local function label(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = FONT
	t.TextColor3 = P.UiText
	t.TextStrokeTransparency = 1
	t.TextScaled = false
	for k, v in pairs(props) do
		if k ~= "StrokeThickness" then
			t[k] = v
		end
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = P.Ink
	stroke.Thickness = props.StrokeThickness or 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = t
	t.Parent = parent
	return t
end

local function panel(parent, size, pos)
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = Color3.fromRGB(46, 36, 30)
	f.BackgroundTransparency = 0.08
	f.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(150, 120, 84)
	stroke.Thickness = 4
	stroke.Parent = f
	f.Parent = parent
	return f
end

local function formatTime(seconds)
	seconds = math.floor(seconds or 0)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end
Hud.FormatTime = formatTime

local function countKeys(t)
	local n = 0
	for _ in pairs(t or {}) do
		n += 1
	end
	return n
end

-- Little carrot icon drawn with frames
local function carrotIcon(parent, color, pos)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(22, 30)
	holder.Position = pos
	holder.Parent = parent
	local body = Instance.new("Frame")
	body.BorderSizePixel = 0
	body.BackgroundColor3 = color
	body.Size = UDim2.fromOffset(10, 18)
	body.Position = UDim2.fromOffset(6, 10)
	body.Parent = holder
	local tip = Instance.new("Frame")
	tip.BorderSizePixel = 0
	tip.BackgroundColor3 = color
	tip.Size = UDim2.fromOffset(4, 4)
	tip.Position = UDim2.fromOffset(9, 27)
	tip.Parent = holder
	for i, x in ipairs({ 4, 9, 14 }) do
		local leaf = Instance.new("Frame")
		leaf.BorderSizePixel = 0
		leaf.BackgroundColor3 = P.CarrotLeaf
		leaf.Size = UDim2.fromOffset(4, i == 2 and 10 or 7)
		leaf.Position = UDim2.fromOffset(x, i == 2 and 0 or 3)
		leaf.Parent = holder
	end
	for _, f in ipairs(holder:GetChildren()) do
		local s = Instance.new("UIStroke")
		s.Color = P.Ink
		s.Thickness = 2
		s.Parent = f
	end
	return holder
end

--------------------------------------------------------------------------------

function Hud.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Bunny64Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Hearts
	heartsFrame = Instance.new("Frame")
	heartsFrame.BackgroundTransparency = 1
	heartsFrame.Position = UDim2.fromOffset(20, 56)
	heartsFrame.Size = UDim2.fromOffset(200, 44)
	heartsFrame.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.Parent = heartsFrame
	for i = 1, Config.MaxHearts do
		hearts[i] = label(heartsFrame, {
			Text = "♥",
			Font = Enum.Font.SourceSansBold,
			TextSize = 46,
			Size = UDim2.fromOffset(40, 44),
			TextColor3 = Color3.fromRGB(176, 64, 60),
			StrokeThickness = 3,
		})
	end

	-- Counters (top right)
	local counters = Instance.new("Frame")
	counters.BackgroundTransparency = 1
	counters.AnchorPoint = Vector2.new(1, 0)
	counters.Position = UDim2.new(1, -20, 0, 56)
	counters.Size = UDim2.fromOffset(240, 80)
	counters.Parent = gui
	carrotIcon(counters, P.Carrot, UDim2.fromOffset(40, 2))
	carrotLabel = label(counters, {
		Text = "000",
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(170, 34),
		Position = UDim2.fromOffset(70, 0),
		StrokeThickness = 3,
	})
	carrotIcon(counters, P.Gold, UDim2.fromOffset(40, 42))
	goldenLabel = label(counters, {
		Text = "0/7",
		TextSize = 30,
		TextColor3 = P.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(170, 34),
		Position = UDim2.fromOffset(70, 40),
		StrokeThickness = 3,
	})

	saveLabel = label(gui, {
		Text = "",
		TextSize = 14,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -16),
		Size = UDim2.fromOffset(400, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 0.3,
	})

	-- Log button
	local logButton = Instance.new("TextButton")
	logButton.Text = "LOG [J]"
	logButton.Font = FONT
	logButton.TextSize = 18
	logButton.TextColor3 = P.UiText
	logButton.BackgroundColor3 = Color3.fromRGB(46, 36, 30)
	logButton.AnchorPoint = Vector2.new(1, 0)
	logButton.Position = UDim2.new(1, -20, 0, 140)
	logButton.Size = UDim2.fromOffset(110, 32)
	logButton.Parent = gui
	local lbStroke = Instance.new("UIStroke")
	lbStroke.Color = Color3.fromRGB(150, 120, 84)
	lbStroke.Thickness = 3
	lbStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	lbStroke.Parent = logButton
	logButton.Activated:Connect(function()
		Hud.ToggleJournal()
	end)

	-- Toast
	toastLabel = label(gui, {
		Text = "",
		TextSize = 34,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.24, 0),
		Size = UDim2.new(0.9, 0, 0, 90),
		TextWrapped = true,
		TextTransparency = 1,
		StrokeThickness = 3,
	})

	-- Carrot Log
	journalFrame = panel(gui, UDim2.fromOffset(520, 430), UDim2.fromScale(0.5, 0.5))
	journalFrame.Visible = false
	label(journalFrame, { Text = "CARROT LOG", TextSize = 36, TextColor3 = P.Gold, Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 10), StrokeThickness = 3 })
	journalList = Instance.new("Frame")
	journalList.BackgroundTransparency = 1
	journalList.Position = UDim2.fromOffset(24, 66)
	journalList.Size = UDim2.new(1, -48, 1, -80)
	journalList.Parent = journalFrame
	local jl = Instance.new("UIListLayout")
	jl.Padding = UDim.new(0, 6)
	jl.Parent = journalList
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(520, 430)
	sizeLimit.Parent = journalFrame
	journalFrame.Size = UDim2.new(0.92, 0, 0, 430)

	ContextActionService:BindAction("Bunny64Log", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			Hud.ToggleJournal()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.J, Enum.KeyCode.ButtonY)
end

function Hud.SetHearts(health, max)
	for i, h in ipairs(hearts) do
		local full = i <= math.ceil(health - 0.01)
		h.TextColor3 = full and Color3.fromRGB(176, 64, 60) or Color3.fromRGB(70, 56, 50)
		h.Visible = i <= max
	end
end

function Hud.Toast(text, seconds, color)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toastLabel.TextColor3 = color or P.UiText
	toastLabel.TextTransparency = 0
	toastLabel.Position = UDim2.new(0.5, 0, 0.22, 0)
	TweenService:Create(toastLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0.24, 0) }):Play()
	task.delay(seconds or 2.5, function()
		if token == toastToken then
			TweenService:Create(toastLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end

local function refreshJournal()
	for _, c in ipairs(journalList:GetChildren()) do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	for _, g in ipairs(Config.Goldens) do
		local got = profile and profile.goldens[g.id]
		label(journalList, {
			Text = got and ("* " .. string.upper(g.name)) or ("- ??? : " .. g.hint),
			TextSize = got and 22 or 16,
			TextColor3 = got and P.Gold or P.UiText,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 38),
		})
	end
	if profile then
		label(journalList, {
			Text = string.format("CARROTS %d/%d   BUGS BOPPED %d   TIME %s", profile.carrotCount, profile.totalCarrots or 0, profile.bugs, formatTime(profile.playTime)),
			TextSize = 16,
			TextTransparency = 0.2,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 30),
		})
	end
end

function Hud.ToggleJournal()
	journalFrame.Visible = not journalFrame.Visible
	if journalFrame.Visible then
		refreshJournal()
	end
end

function Hud.SetProfile(snap)
	profile = snap
	if not snap then
		return
	end
	carrotLabel.Text = string.format("%03d/%03d", snap.carrotCount, snap.totalCarrots or 0)
	goldenLabel.Text = string.format("%d/%d", snap.goldenCount, #Config.Goldens)
	saveLabel.Text = snap.canSave and "PROGRESS SAVES AUTOMATICALLY" or "SAVING OFF (STUDIO / DATASTORE UNAVAILABLE)"
	if journalFrame.Visible then
		refreshJournal()
	end
end

-- Title screen ------------------------------------------------------------------------
function Hud.ShowTitle(snap, onStart)
	titleFrame = Instance.new("Frame")
	titleFrame.Size = UDim2.fromScale(1, 1)
	titleFrame.BackgroundColor3 = Color3.fromRGB(22, 18, 16)
	titleFrame.BackgroundTransparency = 0.35
	titleFrame.BorderSizePixel = 0
	titleFrame.ZIndex = 10
	titleFrame.Parent = gui

	-- letterbox bars
	for _, y in ipairs({ 0, 1 }) do
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = Color3.fromRGB(10, 8, 8)
		bar.AnchorPoint = Vector2.new(0, y)
		bar.Position = UDim2.fromScale(0, y)
		bar.Size = UDim2.new(1, 0, 0.12, 0)
		bar.ZIndex = 11
		bar.Parent = titleFrame
	end

	local logo = label(titleFrame, {
		Text = "BUNNY 64",
		TextSize = 96,
		TextColor3 = P.Carrot,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.33),
		Size = UDim2.new(1, 0, 0, 110),
		StrokeThickness = 6,
		ZIndex = 12,
	})
	local sizer = Instance.new("UITextSizeConstraint")
	sizer.MaxTextSize = 96
	sizer.Parent = logo
	logo.TextScaled = true

	label(titleFrame, {
		Text = "A PLUSH TEDDY ADVENTURE",
		TextSize = 22,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(1, 0, 0, 30),
		ZIndex = 12,
	})

	local progress = "NEW GAME"
	if snap and (snap.carrotCount > 0 or snap.goldenCount > 0) then
		progress = string.format("CONTINUE   CARROTS %d   GOLDEN %d/%d", snap.carrotCount, snap.goldenCount, #Config.Goldens)
	end
	label(titleFrame, {
		Text = progress,
		TextSize = 20,
		TextColor3 = P.Gold,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = 12,
	})

	local press = label(titleFrame, {
		Text = "PRESS START",
		TextSize = 34,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.64),
		Size = UDim2.new(1, 0, 0, 40),
		StrokeThickness = 3,
		ZIndex = 12,
	})

	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	label(titleFrame, {
		Text = touch and "STICK MOVE   JUMP TWICE TO DOUBLE JUMP   POUND IN THE AIR TO GROUND POUND"
			or "WASD MOVE   SPACE JUMP (AGAIN IN AIR = DOUBLE JUMP)   E / CTRL GROUND POUND   J CARROT LOG",
		TextSize = 14,
		TextWrapped = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.78),
		Size = UDim2.new(0.9, 0, 0, 40),
		TextTransparency = 0.15,
		ZIndex = 12,
	})

	local started = false
	task.spawn(function()
		while not started do
			press.Visible = not press.Visible
			task.wait(0.5)
		end
	end)

	local conn
	local function start()
		if started then
			return
		end
		started = true
		conn:Disconnect()
		press.Visible = true
		TweenService:Create(titleFrame, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		for _, d in ipairs(titleFrame:GetDescendants()) do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			elseif d:IsA("Frame") then
				TweenService:Create(d, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end
		task.delay(0.6, function()
			titleFrame:Destroy()
		end)
		onStart()
	end
	conn = UserInputService.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.Keyboard or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
			or t == Enum.UserInputType.Gamepad1 then
			start()
		end
	end)
end

-- Ending card ------------------------------------------------------------------------------
function Hud.ShowEnding(snap)
	if endFrame then
		endFrame:Destroy()
	end
	endFrame = panel(gui, UDim2.new(0.92, 0, 0, 300), UDim2.fromScale(0.5, 0.5))
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 300)
	limit.Parent = endFrame
	label(endFrame, { Text = "THE END?", TextSize = 48, TextColor3 = P.Gold, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 20), StrokeThickness = 4 })
	label(endFrame, {
		Text = "EVERY GOLDEN CARROT IS BACK IN THE BURROW.\nTHANKS FOR PLAYING!",
		TextSize = 18,
		TextWrapped = true,
		Size = UDim2.new(1, -40, 0, 60),
		Position = UDim2.fromOffset(20, 90),
	})
	label(endFrame, {
		Text = string.format("CLEAR TIME %s   CARROTS %d/%d", formatTime(snap.completedTime), snap.carrotCount, snap.totalCarrots or 0),
		TextSize = 20,
		TextColor3 = P.Gold,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 170),
	})
	local close = Instance.new("TextButton")
	close.Text = "KEEP EXPLORING"
	close.Font = FONT
	close.TextSize = 22
	close.TextColor3 = P.UiText
	close.BackgroundColor3 = P.Bow
	close.AnchorPoint = Vector2.new(0.5, 0)
	close.Position = UDim2.new(0.5, 0, 0, 225)
	close.Size = UDim2.fromOffset(240, 44)
	close.Parent = endFrame
	close.Activated:Connect(function()
		endFrame:Destroy()
		endFrame = nil
	end)
end

return Hud
