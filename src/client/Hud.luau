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
local goldenLabel, carrotLabel, saveLabel, toastLabel, bannerHolder, bannerFace
local bossFrame, bossPips, bossName
local toastToken, bannerToken = 0, 0
local onMenu

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
	for i = 1, Config.MaxHearts do
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
	menu.Position = UDim2.fromOffset(0, 96)
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

	-- region title card
	bannerHolder, bannerFace = UI.title(gui, "", 64, UDim2.new(0.5, 0, 0.14, 0), Vector2.new(0.5, 0.5))
	bannerHolder.Visible = false

	-- boss bar
	bossFrame = Instance.new("Frame")
	bossFrame.BackgroundTransparency = 1
	bossFrame.AnchorPoint = Vector2.new(0.5, 0)
	bossFrame.Position = UDim2.new(0.5, 0, 0, 18)
	bossFrame.Size = UDim2.fromOffset(360, 70)
	bossFrame.Visible = false
	bossFrame.Parent = gui
	bossName = UI.label(bossFrame, { Text = "KING GRUMBLE", Font = UI.TITLE, TextSize = 30, Size = UDim2.new(1, 0, 0, 34), TextColor3 = Color3.fromRGB(240, 150, 90), Stroke = 4 })
	bossPips = {}
	for i = 1, 3 do
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

function Hud.SetVisible(on)
	gui.Enabled = on
end

function Hud.SetHearts(health, max)
	for i, h in ipairs(hearts) do
		local full = i <= math.ceil(health - 0.01)
		h.TextColor3 = full and Color3.fromRGB(214, 70, 70) or Color3.fromRGB(70, 56, 60)
		h.Shine.Visible = full
		h.Visible = i <= max
	end
end

function Hud.Pulse(label)
	local scale = label:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = label
	scale.Scale = 1.35
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
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
	toastLabel.TextTransparency = 0
	local scale = toastLabel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = toastLabel
	scale.Scale = 0.6
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(seconds or 2.5, function()
		if token == toastToken then
			TweenService:Create(toastLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end

function Hud.RegionBanner(text)
	bannerToken += 1
	local token = bannerToken
	for _, d in ipairs(bannerHolder:GetChildren()) do
		if d:IsA("TextLabel") then
			d.Text = text
			d.TextTransparency = 0
		end
	end
	bannerHolder.Visible = true
	bannerHolder.Position = UDim2.new(0.5, 0, 0.08, 0)
	TweenService:Create(bannerHolder, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0.14, 0) }):Play()
	task.delay(2.6, function()
		if token ~= bannerToken then
			return
		end
		for _, d in ipairs(bannerHolder:GetChildren()) do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
			end
		end
		task.delay(0.7, function()
			if token == bannerToken then
				bannerHolder.Visible = false
			end
		end)
	end)
end

-- Boss bar follows King Grumble's attributes while you're in the arena
function Hud.WatchBoss(inArenaFn)
	RunService.RenderStepped:Connect(function()
		local folder = workspace:FindFirstChild("Boss")
		local boss = folder and folder:FindFirstChild("KingGrumble")
		local show = boss ~= nil and gui.Enabled and inArenaFn() and boss:GetAttribute("State") ~= "sleep"
		bossFrame.Visible = show
		if show then
			local hp = boss:GetAttribute("HP") or 3
			for i, pip in ipairs(bossPips) do
				pip.BackgroundColor3 = i <= hp and Color3.fromRGB(220, 120, 50) or Color3.fromRGB(50, 40, 44)
			end
			local exposed = boss:GetAttribute("Exposed")
			bossName.TextColor3 = exposed and Color3.fromRGB(255, 230, 120) or Color3.fromRGB(240, 150, 90)
			bossName.Text = exposed and "KING GRUMBLE - JUMP ON HIS BACK!" or "KING GRUMBLE"
		end
	end)
end

return Hud
