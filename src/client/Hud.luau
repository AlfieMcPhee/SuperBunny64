--[[
	Hud - in-game overlay: hearts, golden carrot and carrot counters,
	region title cards, toasts, the boss health bar and the MENU button.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))
local P = Config.Palette

local player = Players.LocalPlayer
local Hud = {}

local gui, root
local hearts = {}
local staminaRow
local staminaPips = {}
local goldenLabel, carrotLabel, saveLabel, toastLabel, bannerHolder, bannerFace
local bossFrame, bossPips, bossName
local toastToken, bannerToken = 0, 0
local onMenu

-- Fade text in/out INCLUDING its outline (a UIStroke doesn't follow
-- TextTransparency on its own, which used to leave ghost outlines on screen),
-- then hide it completely once it's gone.
local fadeTokens = {}
local function fadeText(root, visible, time)
	fadeTokens[root] = (fadeTokens[root] or 0) + 1
	local token = fadeTokens[root]
	local goal = visible and 0 or 1
	local targets = { root }
	for _, d in ipairs(root:GetDescendants()) do
		table.insert(targets, d)
	end
	if visible then
		root.Visible = true
	end
	for _, t in ipairs(targets) do
		if t:IsA("TextLabel") then
			if time > 0 then
				TweenService:Create(t, TweenInfo.new(time), { TextTransparency = goal }):Play()
			else
				t.TextTransparency = goal
			end
		elseif t:IsA("UIStroke") then
			if time > 0 then
				TweenService:Create(t, TweenInfo.new(time), { Transparency = goal }):Play()
			else
				t.Transparency = goal
			end
		end
	end
	if not visible then
		task.delay(time + 0.05, function()
			if fadeTokens[root] == token then
				root.Visible = false
			end
		end)
	end
end

local function counter(parent, icon, y)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(220, 44)
	row.Position = UDim2.new(1, -220, 0, y)
	row.Parent = parent
	UI.carrot(row, icon, 1.3, UDim2.new(1, -150, 0.5, 0), Vector2.new(0, 0.5))
	UI.label(row, { Text = "x", Font = UI.TITLE, TextSize = 22, Size = UDim2.fromOffset(20, 44), Position = UDim2.new(1, -116, 0, 2) })
	local value = UI.label(row, {
		Text = "0", Font = UI.TITLE, TextSize = 38, Size = UDim2.fromOffset(100, 44), Position = UDim2.new(1, -96, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4,
	})
	return value
end

function Hud.Init(menuCallback)
	onMenu = menuCallback
	gui = Instance.new("ScreenGui")
	gui.Name = "Bunny64Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 1
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.new(1, -40, 1, -40)
	root.Position = UDim2.fromOffset(20, 20)
	root.Parent = gui

	-- hearts
	local heartRow = Instance.new("Frame")
	heartRow.BackgroundTransparency = 1
	heartRow.Size = UDim2.fromOffset(200, 52)
	heartRow.Position = UDim2.fromOffset(0, 36)
	heartRow.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 2)
	layout.Parent = heartRow
	for i = 1, math.max(Config.MaxHearts, Config.AssistHearts) do
		local h = UI.label(heartRow, {
			Text = "♥", Font = Enum.Font.SourceSansBold, TextSize = 58, Size = UDim2.fromOffset(46, 52),
			TextColor3 = Color3.fromRGB(214, 70, 70), Stroke = 4,
		})
		local shine = UI.label(h, {
			Text = "♥", Font = Enum.Font.SourceSansBold, TextSize = 22, Size = UDim2.fromOffset(20, 20),
			Position = UDim2.fromOffset(9, 8), TextColor3 = Color3.fromRGB(255, 190, 180), Stroke = 0,
		})
		shine.Name = "Shine"
		hearts[i] = h
	end

	-- stamina: green pips under the hearts (shown while not full)
	staminaRow = Instance.new("Frame")
	staminaRow.BackgroundTransparency = 1
	staminaRow.Size = UDim2.fromOffset(200, 18)
	staminaRow.Position = UDim2.fromOffset(6, 88)
	staminaRow.Parent = root
	local sLayout = Instance.new("UIListLayout")
	sLayout.FillDirection = Enum.FillDirection.Horizontal
	sLayout.Padding = UDim.new(0, 4)
	sLayout.Parent = staminaRow
	for i = 1, Config.Stamina.max do
		local back = Instance.new("Frame")
		back.Size = UDim2.fromOffset(28, 12)
		back.BackgroundColor3 = Color3.fromRGB(40, 46, 40)
		back.BorderSizePixel = 0
		UI.corner(back, 5)
		UI.stroke(back, 2, UI.Ink, Enum.ApplyStrokeMode.Border)
		back.Parent = staminaRow
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(134, 196, 96)
		fill.BorderSizePixel = 0
		UI.corner(fill, 5)
		fill.Parent = back
		staminaPips[i] = back
	end
	staminaRow.Visible = false

	goldenLabel = counter(root, P.Gold, 36)
	carrotLabel = counter(root, P.Carrot, 84)

	saveLabel = UI.label(root, {
		Text = "", TextSize = 14, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.fromOffset(420, 20), TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 0.25, Stroke = 2,
	})

	-- menu button (needed on touch screens, handy everywhere)
	local menu = Instance.new("TextButton")
	menu.Text = "MENU"
	menu.Font = UI.TITLE
	menu.TextSize = 20
	menu.TextColor3 = UI.Cream
	menu.BackgroundColor3 = UI.Navy
	menu.Size = UDim2.fromOffset(92, 34)
	menu.Position = UDim2.fromOffset(0, 112)
	UI.corner(menu, 8)
	UI.stroke(menu, 3, UI.Gold, Enum.ApplyStrokeMode.Border)
	UI.stroke(menu, 2)
	menu.Parent = root
	menu.Activated:Connect(function()
		if onMenu then
			onMenu()
		end
	end)
	UI.label(menu, { Text = "[M]", TextSize = 12, Size = UDim2.fromOffset(30, 14), Position = UDim2.new(1, 4, 0.5, -7), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2 })

	-- toast
	toastLabel = UI.label(gui, {
		Text = "", Font = UI.TITLE, TextSize = 34, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.26, 0), Size = UDim2.new(0.9, 0, 0, 90), TextWrapped = true,
		TextTransparency = 1, Stroke = 4,
	})
	fadeText(toastLabel, false, 0)

	-- region title card
	bannerHolder, bannerFace = UI.title(gui, "", 64, UDim2.new(0.5, 0, 0.14, 0), Vector2.new(0.5, 0.5))
	bannerHolder.Visible = false

	-- boss bar
	bossFrame = Instance.new("Frame")
	bossFrame.BackgroundTransparency = 1
	bossFrame.AnchorPoint = Vector2.new(0.5, 0)
	bossFrame.Position = UDim2.new(0.5, 0, 0, 18)
	bossFrame.Size = UDim2.fromOffset(360, 70)
	bossFrame.AutomaticSize = Enum.AutomaticSize.None
	bossFrame.Visible = false
	bossFrame.Parent = gui
	bossName = UI.label(bossFrame, { Text = "KING GRUMBLE", Font = UI.TITLE, TextSize = 30, Size = UDim2.new(1, 0, 0, 34), TextColor3 = Color3.fromRGB(240, 150, 90), Stroke = 4 })
	bossPips = {}
	for i = 1, 6 do
		local pip = Instance.new("Frame")
		pip.Size = UDim2.fromOffset(100, 18)
		pip.Position = UDim2.fromOffset(12 + (i - 1) * 114, 42)
		pip.BackgroundColor3 = Color3.fromRGB(220, 120, 50)
		pip.BorderSizePixel = 0
		UI.corner(pip, 6)
		UI.stroke(pip, 3, UI.Ink, Enum.ApplyStrokeMode.Border)
		pip.Parent = bossFrame
		bossPips[i] = pip
	end
end

--------------------------------------------------------------------------------
-- Iris wipe: the classic circle that closes to black and opens again
--------------------------------------------------------------------------------

local irisGui, irisHole, irisStroke
local irisToken = 0

local function irisSize()
	local v = workspace.CurrentCamera.ViewportSize
	return math.sqrt(v.X * v.X + v.Y * v.Y)
end

local function ensureIris()
	if irisGui then
		return
	end
	irisGui = Instance.new("ScreenGui")
	irisGui.Name = "Bunny64Iris"
	irisGui.IgnoreGuiInset = true
	irisGui.ResetOnSpawn = false
	irisGui.DisplayOrder = 30
	irisGui.Enabled = false
	irisGui.Parent = player:WaitForChild("PlayerGui")
	irisHole = Instance.new("Frame")
	irisHole.AnchorPoint = Vector2.new(0.5, 0.5)
	irisHole.Position = UDim2.fromScale(0.5, 0.5)
	irisHole.BackgroundTransparency = 1
	UI.corner(irisHole, 0)
	irisHole:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
	irisStroke = Instance.new("UIStroke")
	irisStroke.Color = Color3.new(0, 0, 0)
	irisStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	irisStroke.Parent = irisHole
	irisHole.Parent = irisGui
end

-- Close the iris to black over `time` seconds
function Hud.IrisClose(time)
	ensureIris()
	irisToken += 1
	local d = irisSize()
	irisStroke.Thickness = d
	irisGui.Enabled = true
	if irisHole.Size.X.Offset <= 0 or time <= 0 then
		irisHole.Size = UDim2.fromOffset(time <= 0 and 0 or d * 1.1, time <= 0 and 0 or d * 1.1)
	end
	if time > 0 then
		TweenService:Create(irisHole, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromOffset(0, 0) }):Play()
	end
end

-- Open the iris from black over `time` seconds
function Hud.IrisOpen(time)
	ensureIris()
	irisToken += 1
	local token = irisToken
	local d = irisSize()
	irisStroke.Thickness = d
	irisGui.Enabled = true
	TweenService:Create(irisHole, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(d * 1.1, d * 1.1) }):Play()
	task.delay(time + 0.05, function()
		if token == irisToken then
			irisGui.Enabled = false
		end
	end)
end

-- Quick close-then-open (warps)
function Hud.IrisBlink(closeTime, holdTime, openTime)
	Hud.IrisClose(closeTime)
	local token = irisToken
	task.delay(closeTime + holdTime, function()
		if token == irisToken then
			Hud.IrisOpen(openTime)
		end
	end)
end

--------------------------------------------------------------------------------
-- Tips: one-off hints shown in a box at the bottom of the screen
--------------------------------------------------------------------------------

local tipFrame, tipText
local tipToken = 0

function Hud.Tip(text)
	if not tipFrame then
		local frame, shadow = UI.panel(gui, UDim2.fromOffset(560, 92), UDim2.new(0.5, 0, 1, -90))
		tipFrame = shadow
		UI.label(frame, { Text = "TIP", Font = UI.TITLE, TextSize = 22, TextColor3 = UI.Gold, Size = UDim2.fromOffset(60, 26), Position = UDim2.fromOffset(14, 8), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3 })
		tipText = UI.label(frame, { Text = "", TextSize = 19, TextWrapped = true, Size = UDim2.new(1, -28, 1, -36), Position = UDim2.fromOffset(14, 30), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Stroke = 2 })
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = Vector2.new(560, 92)
		limit.Parent = tipFrame
	end
	tipToken += 1
	local token = tipToken
	tipText.Text = text
	tipFrame.Visible = true
	tipFrame.Position = UDim2.new(0.5, 0, 1, 60)
	TweenService:Create(tipFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 1, -90) }):Play()
	task.delay(7, function()
		if token == tipToken then
			TweenService:Create(tipFrame, TweenInfo.new(0.35), { Position = UDim2.new(0.5, 0, 1, 80) }):Play()
			task.delay(0.4, function()
				if token == tipToken then
					tipFrame.Visible = false
				end
			end)
		end
	end)
end

--------------------------------------------------------------------------------
-- Time-trial countdown and the little save icon
--------------------------------------------------------------------------------

local timerLabel, timerConn
function Hud.StartTimer(seconds, title)
	Hud.StopTimer()
	if not timerLabel then
		timerLabel = UI.label(gui, {
			Text = "", Font = UI.TITLE, TextSize = 48, AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 92), Size = UDim2.new(0, 300, 0, 54), Stroke = 4,
		})
	end
	local endAt = os.clock() + seconds
	timerLabel.Visible = true
	timerConn = RunService.RenderStepped:Connect(function()
		local left = math.max(0, endAt - os.clock())
		timerLabel.Text = string.format("%s  %d.%d", title or "", math.floor(left), math.floor((left % 1) * 10))
		timerLabel.TextColor3 = left < 5 and Color3.fromRGB(240, 110, 100) or UI.Cream
	end)
end

function Hud.StopTimer()
	if timerConn then
		timerConn:Disconnect()
		timerConn = nil
	end
	if timerLabel then
		timerLabel.Visible = false
	end
end

local savedIcon
function Hud.ShowSaved()
	if not savedIcon then
		savedIcon = Instance.new("Frame")
		savedIcon.BackgroundTransparency = 1
		savedIcon.AnchorPoint = Vector2.new(1, 1)
		savedIcon.Position = UDim2.new(1, -20, 1, -16)
		savedIcon.Size = UDim2.fromOffset(130, 34)
		savedIcon.Parent = gui
		UI.carrot(savedIcon, Config.Palette.Carrot, 1, UDim2.fromOffset(0, 2))
		UI.label(savedIcon, { Text = "SAVED", Font = UI.TITLE, TextSize = 22, Size = UDim2.fromOffset(100, 30), Position = UDim2.fromOffset(28, 2), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3 })
	end
	savedIcon.Visible = true
	local carrot = savedIcon:FindFirstChildOfClass("Frame")
	if carrot then
		carrot.Rotation = 0
		TweenService:Create(carrot, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Rotation = 360 }):Play()
	end
	task.delay(1.8, function()
		savedIcon.Visible = false
	end)
end

function Hud.SetVisible(on)
	gui.Enabled = on
end

local lowHealth = false
local onLowBeat = nil

function Hud.SetHearts(health, max)
	for i, h in ipairs(hearts) do
		local full = i <= math.ceil(health - 0.01)
		h.TextColor3 = full and Color3.fromRGB(214, 70, 70) or Color3.fromRGB(70, 56, 60)
		h.Shine.Visible = full
		h.Visible = i <= max
	end
	-- last heart: it beats, so you know you're in danger
	local low = health > 0 and health <= 1 and max > 1
	if low and not lowHealth then
		lowHealth = true
		task.spawn(function()
			while lowHealth do
				local h = hearts[1]
				if h then
					Hud.Pulse(h)
				end
				if onLowBeat and gui.Enabled then
					onLowBeat()
				end
				task.wait(1.1)
			end
		end)
	elseif not low then
		lowHealth = false
	end
end

function Hud.OnLowHealthBeat(fn)
	onLowBeat = fn
end

function Hud.Pulse(label)
	local scale = label:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = label
	scale.Scale = 1.35
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local staminaHideAt = 0
function Hud.SetStamina(cur, max)
	if not staminaRow then
		return
	end
	for i, pip in ipairs(staminaPips) do
		pip.Visible = i <= max
		local f = math.clamp(cur - (i - 1), 0, 1)
		pip.Fill.Size = UDim2.fromScale(f, 1)
		pip.Fill.BackgroundColor3 = f >= 1 and Color3.fromRGB(134, 196, 96) or Color3.fromRGB(196, 176, 90)
	end
	if cur < max - 0.001 then
		staminaRow.Visible = true
		staminaHideAt = math.huge
	elseif staminaHideAt == math.huge then
		-- linger a moment once full, then tuck away
		staminaHideAt = os.clock() + 1.2
		task.delay(1.25, function()
			if os.clock() >= staminaHideAt then
				staminaRow.Visible = false
			end
		end)
	end
end

-- Tried a move with no stamina left: the meter flashes red
function Hud.StaminaEmpty()
	if not staminaRow then
		return
	end
	staminaRow.Visible = true
	for _, pip in ipairs(staminaPips) do
		pip.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
		TweenService:Create(pip, TweenInfo.new(0.5), { BackgroundColor3 = Color3.fromRGB(40, 46, 40) }):Play()
	end
	Hud.Pulse(staminaRow)
end

function Hud.SetProgress(slot, canSave)
	if not slot then
		return
	end
	local g = string.format("%d", slot.goldenCount)
	local c = string.format("%03d", slot.carrotCount)
	if goldenLabel.Text ~= g then
		goldenLabel.Text = g
		Hud.Pulse(goldenLabel)
	end
	if carrotLabel.Text ~= c then
		carrotLabel.Text = c
		Hud.Pulse(carrotLabel)
	end
	saveLabel.Text = canSave and "" or "SAVING OFF (STUDIO OR DATASTORE UNAVAILABLE)"
end

function Hud.Toast(text, seconds, color)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toastLabel.TextColor3 = color or UI.Cream
	fadeText(toastLabel, true, 0)
	local scale = toastLabel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = toastLabel
	scale.Scale = 0.6
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(seconds or 2.5, function()
		if token == toastToken then
			fadeText(toastLabel, false, 0.4)
		end
	end)
end

function Hud.RegionBanner(text)
	bannerToken += 1
	local token = bannerToken
	for _, d in ipairs(bannerHolder:GetChildren()) do
		if d:IsA("TextLabel") then
			d.Text = text
		end
	end
	fadeText(bannerHolder, true, 0)
	bannerHolder.Position = UDim2.new(0.5, 0, 0.08, 0)
	TweenService:Create(bannerHolder, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0.14, 0) }):Play()
	task.delay(2.6, function()
		if token == bannerToken then
			fadeText(bannerHolder, false, 0.6)
		end
	end)
end

-- Boss bar: shows the boss whose arena you're in (name, one pip per hit left)
local pipCount = 0
local function layoutPips(n)
	if n == pipCount then
		return
	end
	pipCount = n
	local w = math.floor((336 - (n - 1) * 8) / n)
	for i, pip in ipairs(bossPips) do
		pip.Visible = i <= n
		pip.Size = UDim2.fromOffset(w, 18)
		pip.Position = UDim2.fromOffset(12 + (i - 1) * (w + 8), 42)
	end
end

function Hud.WatchBoss(arenaBossFn)
	RunService.RenderStepped:Connect(function()
		local boss = arenaBossFn()
		local state = boss and boss:GetAttribute("State")
		local show = boss ~= nil and boss.Parent ~= nil and gui.Enabled and state ~= "sleep" and state ~= "dead"
		bossFrame.Visible = show
		if show then
			local max = boss:GetAttribute("MaxHP") or 3
			local hp = boss:GetAttribute("HP") or max
			layoutPips(math.min(max, #bossPips))
			for i, pip in ipairs(bossPips) do
				pip.BackgroundColor3 = i <= hp and Color3.fromRGB(220, 120, 50) or Color3.fromRGB(50, 40, 44)
			end
			local name = boss:GetAttribute("BossName") or "BOSS"
			local exposed = boss:GetAttribute("Exposed")
			bossName.TextColor3 = exposed and Color3.fromRGB(255, 230, 120) or Color3.fromRGB(240, 150, 90)
			bossName.Text = exposed and (boss:GetAttribute("Hint") or name) or name
		end
	end)
end

return Hud
