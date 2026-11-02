--[[
	Menus - every full-screen menu:
	  Title (PRESS START) -> File Select (File A/B/C, erase) -> game
	  Customise (fur, accent colour, hat, neckwear with a live 3D preview)
	  Options, Pause, Carrot Log, Burrow Warp list, the ending card.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local BunnyModel = require(Shared:WaitForChild("BunnyModel"))
local UI = require(script.Parent:WaitForChild("UI"))
local P = Config.Palette

local player = Players.LocalPlayer
local Menus = {}

local gui, layer, scaler
local deps -- { Effects, Remotes, Movement, Hud, WorldFX, onPlay, onQuit }
local snap = nil
local screen = nil -- current screen name, nil while playing
local orbit = 0

local FILE_LETTERS = { "A", "B", "C" }

local function fmtTime(seconds)
	seconds = math.floor(seconds or 0)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end
Menus.FormatTime = fmtTime

local function clear()
	layer:ClearAllChildren()
	UI.ClearNav()
end

-- 3D bunny preview in a ViewportFrame
local function bunnyViewport(parent, size, pos, custom, anchor)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = size
	vp.Position = pos
	vp.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
	vp.Ambient = Color3.fromRGB(170, 160, 150)
	vp.LightColor = Color3.fromRGB(255, 240, 220)
	vp.LightDirection = Vector3.new(-1, -1.2, 1.2)
	vp.Parent = parent
	local cam = Instance.new("Camera")
	cam.FieldOfView = 32
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 5, -15), Vector3.new(0, 3.6, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	local model = BunnyModel.BuildPreview(custom)
	model.Parent = vp
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not vp.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock()
		model:PivotTo(CFrame.new(0, 2.6 + math.abs(math.sin(t * 2.4)) * 0.35, 0) * CFrame.Angles(0, math.sin(t * 0.7) * 0.9, 0))
	end)
	return vp, model
end

--------------------------------------------------------------------------------
-- Title
--------------------------------------------------------------------------------

local showFiles

local function showTitle()
	screen = "title"
	clear()
	UI.backdrop(layer, 0.55)
	local logo = Instance.new("Frame")
	logo.BackgroundTransparency = 1
	logo.Size = UDim2.fromOffset(820, 300)
	logo.AnchorPoint = Vector2.new(0.5, 0.5)
	logo.Position = UDim2.fromScale(0.5, 0.27)
	logo.Parent = layer
	UI.title(logo, "BUNNY", 130, UDim2.fromOffset(0, 0))
	local _, face64 = UI.title(logo, "64", 170, UDim2.fromOffset(0, 120), nil, {
		Color3.fromRGB(150, 230, 210), Color3.fromRGB(70, 160, 200), Color3.fromRGB(60, 80, 170),
	})
	local scale = Instance.new("UIScale")
	scale.Parent = logo
	scale.Scale = 0.2
	TweenService:Create(scale, TweenInfo.new(0.7, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.spawn(function()
		while logo.Parent do
			logo.Rotation = math.sin(os.clock() * 1.3) * 2
			face64.Rotation = math.sin(os.clock() * 2.1) * 4
			task.wait()
		end
	end)

	bunnyViewport(layer, UDim2.fromOffset(300, 300), UDim2.fromScale(0.5, 0.66), snap and snap.menu.custom)

	local press = UI.label(layer, {
		Text = "PRESS START", Font = UI.TITLE, TextSize = 44, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.89), Size = UDim2.new(1, 0, 0, 50), Stroke = 4,
	})
	task.spawn(function()
		while press.Parent do
			press.Visible = not press.Visible
			task.wait(0.55)
		end
	end)
	UI.label(layer, {
		Text = "v" .. Config.Version, TextSize = 14, AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -8), Size = UDim2.fromOffset(100, 18), TextXAlignment = Enum.TextXAlignment.Right, Stroke = 2,
	})

	local conn
	conn = UserInputService.InputBegan:Connect(function(input, processed)
		if screen ~= "title" then
			conn:Disconnect()
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.Keyboard or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
			or t == Enum.UserInputType.Gamepad1 then
			if not snap then
				return -- still loading the save; wait for the next press
			end
			conn:Disconnect()
			deps.Effects.Play("MenuSelect", 0.8)
			showFiles(false)
		end
	end)
end

--------------------------------------------------------------------------------
-- File select
--------------------------------------------------------------------------------

local showCustomise, showOptions

local function confirm(question, onYes, onNo)
	clear()
	UI.backdrop(layer, 0.1)
	local panel = UI.panel(layer, UDim2.fromOffset(560, 260), UDim2.fromScale(0.5, 0.5))
	UI.label(panel, { Text = question, Font = UI.TITLE, TextSize = 34, Size = UDim2.new(1, -40, 0, 110), Position = UDim2.fromOffset(20, 20), TextWrapped = true, Stroke = 4 })
	local yes = UI.item(panel, "YES", { Size = UDim2.fromOffset(200, 50), Position = UDim2.new(0.25, -100, 1, -80) })
	local no = UI.item(panel, "NO", { Size = UDim2.fromOffset(200, 50), Position = UDim2.new(0.75, -100, 1, -80) })
	UI.SetNav({ { button = yes, select = onYes }, { button = no, select = onNo } }, onNo, 2)
end

function showFiles(eraseMode)
	screen = eraseMode and "erase" or "files"
	clear()
	UI.backdrop(layer, 0.05)
	UI.title(layer, eraseMode and "ERASE WHICH FILE?" or "SELECT FILE", 64, UDim2.new(0.5, 0, 0, 30), Vector2.new(0.5, 0), eraseMode and {
		Color3.fromRGB(255, 190, 170), Color3.fromRGB(230, 110, 90), Color3.fromRGB(170, 50, 50),
	} or nil)

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(820, 280)
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.47)
	row.Parent = layer

	local entries = {}
	local slots = snap.menu.slots
	for i = 1, Config.SaveSlots do
		local s = slots[i]
		local x = (i - 2) * 275
		local panel, shadow = UI.panel(row, UDim2.fromOffset(250, 260), UDim2.new(0.5, x, 0.5, 0))
		UI.label(panel, { Text = "FILE " .. FILE_LETTERS[i], Font = UI.TITLE, TextSize = 46, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 16), Stroke = 4, TextColor3 = UI.Gold })
		if s.exists then
			UI.carrot(panel, P.Gold, 1.4, UDim2.fromOffset(40, 88))
			UI.label(panel, { Text = string.format("x %d / %d", s.goldens, #Config.Goldens), Font = UI.TITLE, TextSize = 30, Size = UDim2.fromOffset(150, 40), Position = UDim2.fromOffset(78, 88), TextXAlignment = Enum.TextXAlignment.Left })
			UI.carrot(panel, P.Carrot, 1.4, UDim2.fromOffset(40, 136))
			UI.label(panel, { Text = string.format("x %03d", s.carrots), Font = UI.TITLE, TextSize = 30, Size = UDim2.fromOffset(150, 40), Position = UDim2.fromOffset(78, 136), TextXAlignment = Enum.TextXAlignment.Left })
			UI.label(panel, { Text = "TIME " .. fmtTime(s.playTime), TextSize = 20, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 186) })
			if s.completed then
				UI.label(panel, { Text = "* COMPLETE *", Font = UI.TITLE, TextSize = 22, TextColor3 = UI.Gold, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 216) })
			end
		else
			UI.label(panel, { Text = "NEW GAME", Font = UI.TITLE, TextSize = 34, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 120), TextColor3 = Color3.fromRGB(190, 210, 240) })
		end
		local button = UI.item(panel, "", { Size = UDim2.fromScale(1, 1) })
		local stroke = panel:FindFirstChildOfClass("UIStroke")
		local index = i
		table.insert(entries, {
			button = button,
			focus = function(on)
				if stroke then
					stroke.Color = on and Color3.fromRGB(255, 244, 200) or UI.Gold
					stroke.Thickness = on and 6 or 4
				end
				TweenService:Create(shadow, TweenInfo.new(0.15), { Position = UDim2.new(0.5, x, 0.5, on and -10 or 0) }):Play()
			end,
			select = function()
				if eraseMode then
					if not s.exists then
						return
					end
					confirm("ERASE FILE " .. FILE_LETTERS[index] .. "?\nTHIS CAN'T BE UNDONE!", function()
						local ok = deps.Remotes.EraseSlot:InvokeServer(index)
						if ok then
							snap.menu.slots[index] = { exists = false, goldens = 0, carrots = 0, playTime = 0, completed = false }
						end
						showFiles(false)
					end, function()
						showFiles(true)
					end)
				else
					Menus.StartFile(index)
				end
			end,
		})
	end

	local bottom = Instance.new("Frame")
	bottom.BackgroundTransparency = 1
	bottom.Size = UDim2.fromOffset(820, 50)
	bottom.AnchorPoint = Vector2.new(0.5, 0)
	bottom.Position = UDim2.new(0.5, 0, 0.47, 170)
	bottom.Parent = layer
	if eraseMode then
		local cancel = UI.item(bottom, "CANCEL", { Size = UDim2.fromOffset(260, 46), Position = UDim2.new(0.5, -130, 0, 0) })
		table.insert(entries, { button = cancel, select = function()
			showFiles(false)
		end })
		UI.SetNav(entries, function()
			showFiles(false)
		end)
	else
		local labels = { "CUSTOMISE", "OPTIONS", "ERASE" }
		local actions = {
			function()
				showCustomise(function()
					showFiles(false)
				end)
			end,
			function()
				showOptions(function()
					showFiles(false)
				end)
			end,
			function()
				showFiles(true)
			end,
		}
		for i, text in ipairs(labels) do
			local b = UI.item(bottom, text, { Size = UDim2.fromOffset(250, 46), Position = UDim2.new(0.5, (i - 2) * 275 - 125, 0, 0) })
			table.insert(entries, { button = b, select = actions[i] })
		end
		UI.SetNav(entries, function()
			showTitle()
		end)
	end
	if not snap.canSave then
		UI.label(layer, {
			Text = "SAVING IS OFF: publish the game and enable API services to keep progress", TextSize = 16,
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, 0, 0, 20), Stroke = 2,
		})
	end
end

--------------------------------------------------------------------------------
-- Customise
--------------------------------------------------------------------------------

local function findIndex(list, id)
	for i, e in ipairs(list) do
		if e.id == id then
			return i
		end
	end
	return 1
end

function showCustomise(back)
	local inGame = snap.slot ~= nil
	screen = "custom"
	clear()
	UI.backdrop(layer, inGame and 0.3 or 0.05)
	UI.title(layer, "CUSTOMISE", 60, UDim2.new(0.5, 0, 0, 24), Vector2.new(0.5, 0))
	local custom = table.clone(snap.menu.custom)
	local progress = snap.menu.progress

	local left = UI.panel(layer, UDim2.fromOffset(330, 470), UDim2.new(0.5, -215, 0.55, 0))
	local vp, model = bunnyViewport(left, UDim2.new(1, -20, 1, -20), UDim2.fromScale(0.5, 0.5), custom)
	vp.ZIndex = 3
	local right = UI.panel(layer, UDim2.fromOffset(440, 470), UDim2.new(0.5, 200, 0.55, 0))
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, -30, 1, -30)
	list.Position = UDim2.fromOffset(15, 15)
	list.Parent = right
	UI.list(list, 6)

	local function refreshModel()
		BunnyModel.Apply(model, custom)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
	end

	local rows = {}
	local function makeRow(title, order)
		UI.label(list, { Text = title, Font = UI.TITLE, TextSize = 18, TextColor3 = Color3.fromRGB(190, 200, 236), Size = UDim2.new(1, 0, 0, 20), LayoutOrder = order * 2 - 1, Stroke = 2 })
		local b = UI.item(list, "", { Size = UDim2.new(1, 0, 0, 38), LayoutOrder = order * 2, TextSize = 26 })
		return b
	end

	local function cycler(list2, key, isIdList, colorKey)
		return function(delta)
			if isIdList then
				local i = findIndex(list2, custom[key])
				i = (i - 1 + delta) % #list2 + 1
				custom[key] = list2[i].id
			else
				custom[key] = (custom[key] - 1 + delta) % #list2 + 1
			end
			refreshModel()
		end
	end

	local defs = {
		{ title = "FUR", list = Config.FurColors, key = "fur", ids = false },
		{ title = "ACCENT COLOUR", list = Config.AccentColors, key = "accent", ids = false },
		{ title = "HAT", list = Config.Hats, key = "hat", ids = true },
		{ title = "NECK", list = Config.Necks, key = "neck", ids = true },
		{ title = "TRAIL", list = Config.Trails, key = "trail", ids = true },
	}
	local entries = {}
	local function refreshTexts()
		for _, r in ipairs(rows) do
			local d = r.def
			local text, locked = "", false
			if d.ids then
				local item = d.list[findIndex(d.list, custom[d.key])]
				locked = not BunnyModel.IsUnlocked(d.list, item.id, progress)
				text = item.name
				if locked then
					text = string.format("%s (%s)", item.name, BunnyModel.LockReason(item))
				end
			else
				local item = d.list[custom[d.key]]
				text = item.name
				if not BunnyModel.EntryUnlocked(item, progress) then
					locked = true
					text = string.format("%s (%s)", item.name, BunnyModel.LockReason(item))
				end
			end
			r.button.Text = "<  " .. text .. "  >"
			r.locked = locked
			r.button:SetAttribute("Locked", locked)
		end
	end
	for i, d in ipairs(defs) do
		local b = makeRow(d.title, i)
		local cyc = cycler(d.list, d.key, d.ids)
		local r = { button = b, def = d }
		table.insert(rows, r)
		table.insert(entries, {
			button = b,
			left = function()
				cyc(-1)
				refreshTexts()
			end,
			right = function()
				cyc(1)
				refreshTexts()
			end,
			select = function()
				cyc(1)
				refreshTexts()
			end,
		})
	end
	refreshTexts()

	local status = UI.label(list, { Text = "", TextSize = 16, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 20, TextColor3 = Color3.fromRGB(240, 170, 150), Stroke = 2 })
	local done = UI.item(list, "SAVE LOOK", { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 21 })
	local cancel = UI.item(list, "BACK", { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 22 })
	table.insert(entries, {
		button = done,
		select = function()
			for _, r in ipairs(rows) do
				if r.locked then
					status.Text = "THAT ONE IS STILL LOCKED - KEEP COLLECTING!"
					return
				end
			end
			status.Text = "SAVING..."
			local result = deps.Remotes.Customise:InvokeServer(custom)
			if result then
				snap.menu.custom = result
				status.Text = "LOOKING GOOD!"
				task.delay(0.5, function()
					if screen == "custom" then
						back()
					end
				end)
			else
				status.Text = "COULDN'T SAVE - TRY AGAIN"
			end
		end,
	})
	table.insert(entries, { button = cancel, select = back })
	UI.SetNav(entries, back)
end

--------------------------------------------------------------------------------
-- Options
--------------------------------------------------------------------------------

function showOptions(back)
	screen = "options"
	clear()
	UI.backdrop(layer, snap.slot and 0.3 or 0.05)
	UI.title(layer, "OPTIONS", 60, UDim2.new(0.5, 0, 0, 24), Vector2.new(0.5, 0))
	local panel = UI.panel(layer, UDim2.fromOffset(560, 500), UDim2.fromScale(0.5, 0.56))
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, -40, 1, -40)
	list.Position = UDim2.fromOffset(20, 20)
	list.Parent = panel
	UI.list(list, 10)
	local o = snap.menu.options
	local function bar(v)
		return string.rep("|", v) .. string.rep(".", 10 - v)
	end
	local sfx = UI.item(list, "", { LayoutOrder = 1 })
	local music = UI.item(list, "", { LayoutOrder = 2 })
	local shake = UI.item(list, "", { LayoutOrder = 3 })
	local tipsRow = UI.item(list, "", { LayoutOrder = 4 })
	local assistRow = UI.item(list, "", { LayoutOrder = 5 })
	local function refresh()
		sfx.Text = "SOUND  < " .. bar(o.sfx) .. " >"
		music.Text = "MUSIC  < " .. bar(o.music) .. " >"
		shake.Text = "SCREEN SHAKE  < " .. (o.shake and "ON" or "OFF") .. " >"
		tipsRow.Text = "TIPS  < " .. (o.tips ~= false and "ON" or "OFF") .. " >"
		assistRow.Text = "ASSIST MODE  < " .. (o.assist and "ON - 5 HEARTS" or "OFF") .. " >"
		deps.Effects.SetOptions(o)
	end
	refresh()
	local function finish()
		deps.Remotes.SetOptions:FireServer(o)
		back()
	end
	local controlsButton = UI.item(list, "CONTROLS", { LayoutOrder = 6 })
	local backButton = UI.item(list, "BACK", { LayoutOrder = 8 })
	UI.label(list, { Text = "8-bit music is built in. Add uploaded track ids in Config.Music to replace it.", TextSize = 14, TextWrapped = true, LayoutOrder = 7, Size = UDim2.new(1, 0, 0, 34), Stroke = 2, TextTransparency = 0.3 })
	UI.SetNav({
		{ button = sfx, left = function() o.sfx = math.max(0, o.sfx - 1); refresh() end, right = function() o.sfx = math.min(10, o.sfx + 1); refresh() end, select = function() o.sfx = (o.sfx + 1) % 11; refresh() end },
		{ button = music, left = function() o.music = math.max(0, o.music - 1); refresh() end, right = function() o.music = math.min(10, o.music + 1); refresh() end, select = function() o.music = (o.music + 1) % 11; refresh() end },
		{ button = shake, left = function() o.shake = not o.shake; refresh() end, right = function() o.shake = not o.shake; refresh() end, select = function() o.shake = not o.shake; refresh() end },
		{ button = tipsRow, left = function() o.tips = o.tips == false; refresh() end, right = function() o.tips = o.tips == false; refresh() end, select = function() o.tips = o.tips == false; refresh() end },
		{ button = assistRow, left = function() o.assist = not o.assist; refresh() end, right = function() o.assist = not o.assist; refresh() end, select = function() o.assist = not o.assist; refresh() end },
		{ button = controlsButton, select = function()
			deps.Remotes.SetOptions:FireServer(o)
			Menus.ShowControls(function()
				showOptions(back)
			end)
		end },
		{ button = backButton, select = finish },
	}, finish)
end

--------------------------------------------------------------------------------
-- Controls (rebinding)
--------------------------------------------------------------------------------

local function prettyKey(name)
	if not name then
		return "-"
	end
	local pads = {
		ButtonA = "A", ButtonB = "B", ButtonX = "X", ButtonY = "Y", ButtonL1 = "LB", ButtonR1 = "RB",
		ButtonL2 = "LT", ButtonR2 = "RT", ButtonL3 = "L-STICK", ButtonR3 = "R-STICK", ButtonSelect = "SELECT",
		ButtonStart = "START", DPadUp = "D-UP", DPadDown = "D-DOWN", DPadLeft = "D-LEFT", DPadRight = "D-RIGHT",
	}
	if pads[name] then
		return pads[name]
	end
	local spaced = string.gsub(name, "(%l)(%u)", "%1 %2")
	return string.upper(spaced)
end

Menus.PrettyKey = prettyKey

function Menus.CurrentControls()
	local o = snap and snap.menu.options or {}
	local out = {}
	for _, def in ipairs(Config.Controls) do
		local c = (o.controls or {})[def.id] or {}
		out[def.id] = { key = c.key or def.key, pad = c.pad or def.pad }
	end
	return out
end

function Menus.ApplyControls()
	local controls = Menus.CurrentControls()
	deps.Movement.ApplyControls(controls)
	ContextActionService:UnbindAction("Bunny64Menu")
	local function code(name, fallback)
		local ok, c = pcall(function()
			return Enum.KeyCode[name]
		end)
		return (ok and c) or Enum.KeyCode[fallback]
	end
	ContextActionService:BindAction("Bunny64Menu", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			Menus.TogglePause()
		end
		return Enum.ContextActionResult.Pass
	end, false, code(controls.menu.key, "M"), code(controls.menu.pad, "ButtonSelect"))
end

function Menus.ShowControls(back)
	screen = "controls"
	clear()
	UI.backdrop(layer, snap.slot and 0.3 or 0.05)
	UI.title(layer, "CONTROLS", 60, UDim2.new(0.5, 0, 0, 24), Vector2.new(0.5, 0))
	local panel = UI.panel(layer, UDim2.fromOffset(640, 420), UDim2.fromScale(0.5, 0.55))
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, -40, 1, -40)
	list.Position = UDim2.fromOffset(20, 20)
	list.Parent = panel
	UI.list(list, 8)
	local controls = Menus.CurrentControls()
	local status = UI.label(list, {
		Text = "Pick an action, then press the key or gamepad button you want.", TextSize = 16, TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 0, Stroke = 2,
	})
	local rows = {}
	local entries = {}
	local function refresh()
		for _, r in ipairs(rows) do
			local c = controls[r.def.id]
			r.button.Text = string.format("%s   [%s]  [%s]", r.def.name, prettyKey(c.key), prettyKey(c.pad))
		end
	end
	local function save()
		snap.menu.options.controls = controls
		deps.Remotes.SetOptions:FireServer({ controls = controls })
		Menus.ApplyControls()
	end
	local listening = nil
	local function listen(def)
		if listening then
			return
		end
		status.Text = "PRESS A KEY OR BUTTON FOR " .. def.name .. "   (BACKSPACE TO CANCEL)"
		status.TextColor3 = UI.Gold
		local savedEntries, savedIndex = entries, nil
		UI.ClearNav()
		-- start listening a moment later so the press that chose this row isn't captured
		task.wait(0.15)
		if screen ~= "controls" then
			return
		end
		listening = UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			local kc = input.KeyCode
			local isPad = string.find(input.UserInputType.Name, "Gamepad") ~= nil
			if input.UserInputType ~= Enum.UserInputType.Keyboard and not isPad then
				return
			end
			if kc == Enum.KeyCode.Unknown or kc == Enum.KeyCode.Thumbstick1 or kc == Enum.KeyCode.Thumbstick2 then
				return
			end
			listening:Disconnect()
			listening = nil
			status.TextColor3 = UI.Cream
			if kc == Enum.KeyCode.Backspace then
				status.Text = "Cancelled."
			elseif not isPad and Config.ReservedKeys[kc.Name] then
				status.Text = prettyKey(kc.Name) .. " is reserved (movement, chat or Roblox menus). Try another key."
			else
				local slotName = isPad and "pad" or "key"
				-- if another action already uses it, swap them
				for _, other in ipairs(Config.Controls) do
					if other.id ~= def.id and controls[other.id][slotName] == kc.Name then
						controls[other.id][slotName] = controls[def.id][slotName]
					end
				end
				controls[def.id][slotName] = kc.Name
				status.Text = def.name .. " is now " .. prettyKey(kc.Name)
				refresh()
				save()
			end
			task.defer(function()
				if screen == "controls" then
					UI.SetNav(savedEntries, back, savedIndex)
				end
			end)
		end)
	end
	for i, def in ipairs(Config.Controls) do
		local b = UI.item(list, "", { LayoutOrder = i, TextSize = 22 })
		table.insert(rows, { button = b, def = def })
		table.insert(entries, { button = b, select = function()
			listen(def)
		end })
	end
	refresh()
	local reset = UI.item(list, "RESET TO DEFAULTS", { LayoutOrder = 20 })
	local done = UI.item(list, "BACK", { LayoutOrder = 21 })
	table.insert(entries, { button = reset, select = function()
		for _, def in ipairs(Config.Controls) do
			controls[def.id] = { key = def.key, pad = def.pad }
		end
		refresh()
		save()
		status.Text = "Controls reset."
	end })
	table.insert(entries, { button = done, select = function()
		if listening then
			listening:Disconnect()
			listening = nil
		end
		back()
	end })
	UI.SetNav(entries, back)
end

--------------------------------------------------------------------------------
-- Carrot Log
--------------------------------------------------------------------------------

local function showLog(back)
	screen = "log"
	clear()
	UI.backdrop(layer, 0.3)
	UI.title(layer, "CARROT LOG", 56, UDim2.new(0.5, 0, 0, 18), Vector2.new(0.5, 0))
	local panel = UI.panel(layer, UDim2.fromOffset(640, 470), UDim2.fromScale(0.5, 0.55))
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, -30, 1, -80)
	scroll.Position = UDim2.fromOffset(15, 15)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = UI.Gold
	scroll.Parent = panel
	UI.list(scroll, 2)
	local slot = snap.slot
	local order = 0
	local entries = {}
	for _, region in ipairs(Config.Regions) do
		order += 1
		local got, total = 0, 0
		for _, g in ipairs(Config.Goldens) do
			if g.region == region.id then
				total += 1
				if slot and slot.goldens[g.id] then
					got += 1
				end
			end
		end
		-- a hidden land stays a mystery until you've set foot in it
		local secret = region.hidden and not (slot and slot.regions and slot.regions[region.id])
		UI.label(scroll, { Text = string.format("%s   %d/%d", secret and "? ? ?" or region.name, got, total), Font = UI.TITLE, TextSize = 26, TextColor3 = UI.Gold, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = order, Stroke = 3 })
		for _, g in ipairs(Config.Goldens) do
			if g.region == region.id then
				order += 1
				local have = slot and slot.goldens[g.id]
				local b = UI.item(scroll, have and string.upper(g.name) or (secret and "???  Somewhere, something is hidden..." or ("???  " .. g.hint)), {
					LayoutOrder = order, TextSize = have and 22 or 16, TextWrapped = true, Size = UDim2.new(1, -12, 0, 40),
					TextColor3 = have and Color3.fromRGB(255, 226, 140) or UI.Cream,
				})
				table.insert(entries, {
					button = b,
					focus = function(on)
						if on then
							local y = b.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y
							scroll.CanvasPosition = Vector2.new(0, math.max(0, y - scroll.AbsoluteSize.Y / 2))
						end
						if have then
							b.TextColor3 = on and UI.Gold or Color3.fromRGB(255, 226, 140)
						end
					end,
				})
			end
		end
	end
	if slot then
		UI.label(panel, {
			Text = string.format("CARROTS %d/%d    BADDIES BOPPED %d    TIME %s", slot.carrotCount, snap.totalCarrots or 0, slot.bugs, fmtTime(slot.playTime)),
			TextSize = 18, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -42), Size = UDim2.new(1, 0, 0, 22), Stroke = 2,
		})
	end
	local backButton = UI.item(panel, "BACK", { Size = UDim2.fromOffset(200, 36), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6) })
	table.insert(entries, { button = backButton, select = back })
	UI.SetNav(entries, back, #entries)
end

--------------------------------------------------------------------------------
-- Shop: spend carrot coins on looks (and the optional Robux supporter items)
--------------------------------------------------------------------------------

local SHOP_SECTIONS = {
	{ title = "HATS", list = "Hats", key = "hat" },
	{ title = "FUR", list = "FurColors", key = "fur", byIndex = true },
	{ title = "NECK", list = "Necks", key = "neck" },
	{ title = "TRAILS", list = "Trails", key = "trail" },
}

function Menus.ShowShop(back)
	screen = "shop"
	clear()
	UI.backdrop(layer, 0.3)
	UI.title(layer, "SHOP", 60, UDim2.new(0.5, 0, 0, 18), Vector2.new(0.5, 0))
	local progress = snap.menu.progress
	local preview = table.clone(snap.menu.custom)
	local coinText = UI.label(layer, {
		Text = "", Font = UI.TITLE, TextSize = 26, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 86),
		Size = UDim2.fromOffset(500, 30), TextColor3 = Color3.fromRGB(236, 190, 90), Stroke = 3,
	})
	local function showCoins()
		coinText.Text = string.format("CARROT COINS: %d", snap.coins or 0)
	end
	showCoins()

	local left = UI.panel(layer, UDim2.fromOffset(300, 430), UDim2.new(0.5, -250, 0.58, 0))
	local _, model = bunnyViewport(left, UDim2.new(1, -20, 1, -20), UDim2.fromScale(0.5, 0.5), preview)
	local function refreshModel()
		BunnyModel.Apply(model, preview)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
	end
	local right = UI.panel(layer, UDim2.fromOffset(470, 430), UDim2.new(0.5, 150, 0.58, 0))
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, -24, 1, -70)
	scroll.Position = UDim2.fromOffset(12, 12)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = UI.Gold
	scroll.Parent = right
	UI.list(scroll, 3)
	local status = UI.label(right, {
		Text = "Coins come from carrots, silver and golden carrots, bosses and ore-carrot rocks.", TextSize = 14, TextWrapped = true,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -24, 0, 40), Stroke = 2,
	})

	local entries = {}
	local order = 0
	local function focusScroll(b)
		local y = b.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y
		scroll.CanvasPosition = Vector2.new(0, math.max(0, y - scroll.AbsoluteSize.Y / 2))
	end
	local function label(item)
		local unlocked = BunnyModel.EntryUnlocked(item, progress)
		if unlocked then
			return item.name .. "   -   OWNED", true
		elseif item.pass then
			return item.name .. "   -   SUPPORTER PACK", false
		end
		return string.format("%s   -   %d COINS", item.name, item.price), false
	end

	for _, sec in ipairs(SHOP_SECTIONS) do
		order += 1
		UI.label(scroll, { Text = sec.title, Font = UI.TITLE, TextSize = 22, TextColor3 = UI.Gold, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = order, Stroke = 3 })
		for index, item in ipairs(Config[sec.list]) do
			if item.price or item.pass then
				order += 1
				local text = label(item)
				local b = UI.item(scroll, text, { LayoutOrder = order, TextSize = 18, Size = UDim2.new(1, -12, 0, 34) })
				local value = sec.byIndex and index or item.id
				table.insert(entries, {
					button = b,
					focus = function(on)
						if on then
							focusScroll(b)
							preview = table.clone(snap.menu.custom)
							preview[sec.key] = value
							refreshModel()
						end
					end,
					select = function()
						local _, owned = label(item)
						if owned then
							status.Text = "ALREADY YOURS! WEAR IT FROM CUSTOMISE."
							return
						end
						if item.pass then
							local pass = Config.GamePasses[item.pass]
							if pass and pass.id > 0 then
								pcall(function()
									game:GetService("MarketplaceService"):PromptGamePassPurchase(player, pass.id)
								end)
							else
								status.Text = "THE SUPPORTER PACK IS COMING SOON!"
							end
							return
						end
						if (snap.coins or 0) < item.price then
							status.Text = string.format("YOU NEED %d MORE COINS. SMASH SOME ORE ROCKS!", item.price - (snap.coins or 0))
							return
						end
						if not deps.Remotes.ShopBuy then
							status.Text = "THE SHOP IS CLOSED RIGHT NOW."
							return
						end
						status.Text = "..."
						local ok, msg = deps.Remotes.ShopBuy:InvokeServer(sec.list, item.id or item.name)
						status.Text = tostring(msg or "")
						if ok then
							deps.Effects.Play("Coin", 1.2)
							task.wait(0.2) -- the server's update brings the new coin total
							showCoins()
							progress = snap.menu.progress
							b.Text = (label(item))
							status.Text = string.format("%s IS YOURS! WEAR IT FROM CUSTOMISE.", item.name)
						end
					end,
				})
			end
		end
	end

	-- Robux extras (only active once their ids are set in Config)
	order += 1
	UI.label(scroll, { Text = "SUPPORT BUNNY 64", Font = UI.TITLE, TextSize = 22, TextColor3 = UI.Gold, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = order, Stroke = 3 })
	for key, pass in pairs(Config.GamePasses) do
		order += 1
		local owned = progress.passes and progress.passes[key]
		local b = UI.item(scroll, pass.name .. (owned and "   -   OWNED" or (pass.id > 0 and "   -   R$" or "   -   SOON")), {
			LayoutOrder = order, TextSize = 18, Size = UDim2.new(1, -12, 0, 34),
		})
		table.insert(entries, {
			button = b,
			focus = function(on)
				if on then
					focusScroll(b)
					status.Text = pass.desc
				end
			end,
			select = function()
				if owned then
					status.Text = "YOU HAVE IT - THANK YOU SO MUCH!"
				elseif pass.id > 0 then
					pcall(function()
						game:GetService("MarketplaceService"):PromptGamePassPurchase(player, pass.id)
					end)
				else
					status.Text = "COMING SOON!"
				end
			end,
		})
	end
	for _, product in pairs(Config.Products) do
		order += 1
		local b = UI.item(scroll, product.name .. (product.id > 0 and "   -   R$" or "   -   SOON"), {
			LayoutOrder = order, TextSize = 18, Size = UDim2.new(1, -12, 0, 34),
		})
		table.insert(entries, {
			button = b,
			focus = function(on)
				if on then
					focusScroll(b)
					status.Text = product.desc
				end
			end,
			select = function()
				if product.id > 0 then
					pcall(function()
						game:GetService("MarketplaceService"):PromptProductPurchase(player, product.id)
					end)
				else
					status.Text = "COMING SOON!"
				end
			end,
		})
	end
	if player.MembershipType == Enum.MembershipType.Premium then
		order += 1
		UI.label(scroll, { Text = "PREMIUM BONUS: YOU EARN 1.5x CARROT COINS!", TextSize = 16, TextColor3 = Color3.fromRGB(150, 210, 255), Size = UDim2.new(1, 0, 0, 24), LayoutOrder = order, Stroke = 2 })
	end

	local backButton = UI.item(layer, "BACK", { Size = UDim2.fromOffset(200, 38), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16) })
	table.insert(entries, { button = backButton, select = back })
	UI.SetNav(entries, back)
end

--------------------------------------------------------------------------------
-- Map
--------------------------------------------------------------------------------

-- The world from above: islands, routes, golden carrots (gold = found),
-- discovered warps, checkpoints and you.
local MAP_ISLANDS = {
	{ x = 0, z = 0, r = 246, color = Color3.fromRGB(104, 136, 72), name = "CARROT MEADOW", region = "meadow" },
	{ x = 0, z = -720, r = 246, color = Color3.fromRGB(214, 220, 226), name = "FROSTBITE PEAKS", region = "peaks" },
	{ x = 720, z = 0, r = 226, color = Color3.fromRGB(184, 134, 92), name = "DUSTBOWL CANYON", region = "canyon" },
	{ x = 0, z = 800, r = 276, color = Color3.fromRGB(78, 64, 64), name = "INFERNAL CASTLE", region = "castle" },
	{ x = -780, z = 60, r = 234, color = Color3.fromRGB(70, 98, 60), name = "WHISPERWOOD", region = "forest" },
	{ x = -330, z = 40, r = 48, color = Color3.fromRGB(104, 136, 72) },
	{ x = -460, z = 40, r = 12, color = Color3.fromRGB(104, 136, 72) },
	-- Cloudtop Heights floats high above the meadow, so it's drawn see-through on top
	{ x = 110, z = -150, r = 130, color = Color3.fromRGB(236, 240, 248), name = "CLOUDTOP HEIGHTS", region = "sky", see = 0.55 },
}
local MAP_ROUTES = { -- straight links between islands: { x1, z1, x2, z2, width }
	{ 0, -222, 0, -522, 44 }, { 222, 0, 522, 0, 14 }, { 0, 222, 0, 552, 24 }, { -362, 40, -566, 40, 8 },
}
local MAP_MIN = Vector2.new(-1040, -1000)
local MAP_MAX = Vector2.new(980, 1100)

function Menus.ShowMap(back)
	screen = "map"
	clear()
	UI.backdrop(layer, 0.25)
	UI.title(layer, "MAP", 56, UDim2.new(0.5, 0, 0, 14), Vector2.new(0.5, 0))
	local panel = UI.panel(layer, UDim2.fromOffset(560, 560), UDim2.fromScale(0.5, 0.56))
	local canvas = Instance.new("Frame")
	canvas.BackgroundColor3 = Color3.fromRGB(46, 84, 100) -- the sea
	canvas.BorderSizePixel = 0
	canvas.Size = UDim2.new(1, -30, 1, -80)
	canvas.Position = UDim2.fromOffset(15, 15)
	canvas.ClipsDescendants = true
	UI.corner(canvas, 10)
	canvas.Parent = panel
	local W, H = 530, 480
	local span = MAP_MAX - MAP_MIN
	local scale = math.min(W / span.X, H / span.Y)
	local offX = (W - span.X * scale) / 2
	local offY = (H - span.Y * scale) / 2
	local function toMap(x, z)
		return UDim2.fromOffset(offX + (x - MAP_MIN.X) * scale, offY + (z - MAP_MIN.Y) * scale)
	end
	for _, r in ipairs(MAP_ROUTES) do
		local a, b = Vector2.new(r[1], r[2]), Vector2.new(r[3], r[4])
		local mid = (a + b) / 2
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = toMap(mid.X, mid.Y)
		local len = (b - a).Magnitude * scale
		local w = math.max(3, r[5] * scale)
		f.Size = (a.X == b.X) and UDim2.fromOffset(w, len) or UDim2.fromOffset(len, w)
		f.BackgroundColor3 = Color3.fromRGB(150, 124, 92)
		f.BorderSizePixel = 0
		f.Parent = canvas
	end
	for _, isl in ipairs(MAP_ISLANDS) do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = toMap(isl.x, isl.z)
		f.Size = UDim2.fromOffset(isl.r * 2 * scale, isl.r * 2 * scale)
		f.BackgroundColor3 = isl.color
		f.BackgroundTransparency = isl.see or 0
		f.BorderSizePixel = 0
		UI.corner(f, 999)
		UI.stroke(f, 2, Color3.fromRGB(220, 206, 160), Enum.ApplyStrokeMode.Border)
		f.Parent = canvas
		if isl.name then
			local got, total = 0, 0
			for _, g in ipairs(Config.Goldens) do
				if g.region == isl.region then
					total += 1
					if snap.slot and snap.slot.goldens[g.id] then
						got += 1
					end
				end
			end
			UI.label(canvas, {
				Text = string.format("%s  %d/%d", isl.name, got, total), TextSize = 13, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = toMap(isl.x, isl.z - isl.r * 0.55), Size = UDim2.fromOffset(200, 16), Stroke = 2,
			})
		end
	end
	local function dot(pos, size, color, shape)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = toMap(pos.X, pos.Z)
		f.Size = UDim2.fromOffset(size, size)
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		if shape ~= "square" then
			UI.corner(f, 999)
		end
		UI.stroke(f, 1.5, UI.Ink, Enum.ApplyStrokeMode.Border)
		f.Parent = canvas
		return f
	end
	-- golden carrots
	for id, pos in pairs(deps.GoldenPositions()) do
		local got = snap.slot and snap.slot.goldens[id]
		dot(pos, got and 9 or 7, got and UI.Gold or Color3.fromRGB(150, 150, 160))
	end
	-- warps & checkpoints
	for _, w in ipairs(Config.Warps) do
		if snap.slot and snap.slot.warps and snap.slot.warps[w.id] then
			dot(w.pos, 8, Color3.fromRGB(110, 80, 54), "square")
		end
	end
	local cp = snap.slot and Config.Checkpoints[snap.slot.checkpoint]
	if cp then
		dot(cp.pos, 8, Color3.fromRGB(226, 182, 74), "square").Rotation = 45
	end
	-- you
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		local you = dot(root.Position, 13, Color3.fromRGB(240, 120, 110))
		task.spawn(function()
			while you.Parent do
				you.BackgroundTransparency = (math.floor(os.clock() * 3) % 2 == 0) and 0 or 0.5
				task.wait(0.1)
			end
		end)
	end
	UI.label(panel, {
		Text = "GOLD = FOUND   GREY = STILL OUT THERE   SQUARE = WARP   DIAMOND = CHECKPOINT   RED = YOU",
		TextSize = 12, TextWrapped = true, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.new(1, -20, 0, 26), Stroke = 2,
	})
	local backButton = UI.item(panel, "BACK", { Size = UDim2.fromOffset(200, 34), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4) })
	UI.SetNav({ { button = backButton, select = back } }, back)
end

--------------------------------------------------------------------------------
-- Stamps
--------------------------------------------------------------------------------

function Menus.ShowStamps(back)
	screen = "stamps"
	clear()
	UI.backdrop(layer, 0.3)
	local got = 0
	local have = (snap.slot and snap.slot.stamps) or {}
	for _, st in ipairs(Config.Stamps) do
		if have[st.id] then
			got += 1
		end
	end
	UI.title(layer, string.format("STAMPS  %d/%d", got, #Config.Stamps), 50, UDim2.new(0.5, 0, 0, 16), Vector2.new(0.5, 0))
	local panel = UI.panel(layer, UDim2.fromOffset(660, 480), UDim2.fromScale(0.5, 0.56))
	local grid = Instance.new("ScrollingFrame")
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Size = UDim2.new(1, -24, 1, -64)
	grid.Position = UDim2.fromOffset(12, 12)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = UI.Gold
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.5, -6, 0, 66)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.Parent = grid
	for _, st in ipairs(Config.Stamps) do
		local on = have[st.id]
		local card = Instance.new("Frame")
		card.BackgroundColor3 = on and Color3.fromRGB(96, 80, 40) or Color3.fromRGB(40, 40, 64)
		card.BorderSizePixel = 0
		UI.corner(card, 8)
		UI.stroke(card, 2, on and UI.Gold or Color3.fromRGB(80, 80, 110), Enum.ApplyStrokeMode.Border)
		card.Parent = grid
		UI.label(card, { Text = on and st.name or "? ? ?", Font = UI.TITLE, TextSize = 19, TextColor3 = on and UI.Gold or Color3.fromRGB(170, 170, 190), Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 6), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2 })
		UI.label(card, { Text = st.desc, TextSize = 14, TextWrapped = true, Size = UDim2.new(1, -16, 0, 32), Position = UDim2.fromOffset(8, 30), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Stroke = 2, TextTransparency = on and 0 or 0.3 })
	end
	local backButton = UI.item(panel, "BACK", { Size = UDim2.fromOffset(200, 36), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8) })
	UI.SetNav({ { button = backButton, select = back } }, back)
end

--------------------------------------------------------------------------------
-- Photo mode
--------------------------------------------------------------------------------

function Menus.StartPhoto(back)
	screen = "photo"
	clear()
	deps.Hud.SetVisible(false)
	deps.SetOverlaysVisible(false)
	UI.label(layer, {
		Text = "PHOTO MODE   WASD / stick: move   hold right mouse / right stick: look   Q E: down / up   Shift: fast   BACKSPACE / B: done",
		TextSize = 14, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, 0, 0, 18), Stroke = 2, TextTransparency = 0.25,
	})
	deps.PhotoMode.Start(function()
		deps.Hud.SetVisible(true)
		deps.SetOverlaysVisible(true)
		back()
	end)
end

--------------------------------------------------------------------------------
-- Pause, warp, ending
--------------------------------------------------------------------------------

local function regionName()
	local id = deps.WorldFX.Region()
	for _, r in ipairs(Config.Regions) do
		if r.id == id then
			return r.name
		end
	end
	return ""
end

function Menus.Close()
	screen = nil
	clear()
	gui.Enabled = false
	deps.Hud.SetVisible(true)
	deps.Movement.SetEnabled(true)
end

local function showPause()
	screen = "pause"
	clear()
	gui.Enabled = true
	deps.Movement.SetEnabled(false)
	UI.backdrop(layer, 0.35)
	UI.title(layer, "PAUSED", 72, UDim2.new(0.5, 0, 0, 30), Vector2.new(0.5, 0))
	local slot = snap.slot
	if slot then
		UI.label(layer, {
			Text = string.format("FILE %s   -   %s   -   %d GOLDEN   -   %d CARROTS", FILE_LETTERS[snap.active or 1], regionName(), slot.goldenCount, slot.carrotCount),
			TextSize = 20, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.new(1, 0, 0, 24), Stroke = 2,
		})
	end
	local panel = UI.panel(layer, UDim2.fromOffset(460, 520), UDim2.fromScale(0.5, 0.6))
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, -30, 1, -30)
	list.Position = UDim2.fromOffset(15, 15)
	list.Parent = panel
	UI.list(list, 4)
	local resume = UI.item(list, "RESUME", { LayoutOrder = 1 })
	local map = UI.item(list, "MAP", { LayoutOrder = 2 })
	local log = UI.item(list, "CARROT LOG", { LayoutOrder = 3 })
	local stamps = UI.item(list, "STAMPS", { LayoutOrder = 4 })
	local custom = UI.item(list, "CUSTOMISE", { LayoutOrder = 5 })
	local shop = UI.item(list, "SHOP", { LayoutOrder = 6 })
	local photo = UI.item(list, "PHOTO MODE", { LayoutOrder = 7 })
	local options = UI.item(list, "OPTIONS", { LayoutOrder = 8 })
	local quit = UI.item(list, "SAVE & QUIT", { LayoutOrder = 9 })
	local backToPause = function()
		showPause()
	end
	UI.SetNav({
		{ button = resume, select = Menus.Close },
		{ button = map, select = function() Menus.ShowMap(backToPause) end },
		{ button = log, select = function() showLog(backToPause) end },
		{ button = stamps, select = function() Menus.ShowStamps(backToPause) end },
		{ button = custom, select = function() showCustomise(backToPause) end },
		{ button = shop, select = function() Menus.ShowShop(backToPause) end },
		{ button = photo, select = function() Menus.StartPhoto(backToPause) end },
		{ button = options, select = function() showOptions(backToPause) end },
		{ button = quit, select = function()
			confirm("SAVE AND QUIT TO THE TITLE SCREEN?", function()
				deps.onQuit()
			end, backToPause)
		end },
	}, Menus.Close)
end

function Menus.TogglePause()
	if screen == nil and snap and snap.slot then
		deps.Effects.Play("MenuSelect", 0.9)
		showPause()
	elseif screen == "pause" then
		Menus.Close()
	end
end

function Menus.ShowWarp(ids)
	if screen ~= nil then
		return
	end
	screen = "warp"
	clear()
	gui.Enabled = true
	deps.Movement.SetEnabled(false)
	UI.backdrop(layer, 0.4)
	UI.title(layer, "BURROW WARP", 60, UDim2.new(0.5, 0, 0, 40), Vector2.new(0.5, 0))
	local panel = UI.panel(layer, UDim2.fromOffset(460, 80 + 50 * (#ids + 1)), UDim2.fromScale(0.5, 0.55))
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, -30, 1, -30)
	list.Position = UDim2.fromOffset(15, 15)
	list.Parent = panel
	UI.list(list, 6)
	UI.label(list, { Text = "Where to, little bunny?", TextSize = 18, LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 30), Stroke = 2 })
	local entries = {}
	for i, id in ipairs(ids) do
		local name = id
		for _, w in ipairs(Config.Warps) do
			if w.id == id then
				name = w.name
			end
		end
		local b = UI.item(list, name, { LayoutOrder = i })
		table.insert(entries, { button = b, select = function()
			deps.Remotes.Warp:FireServer(id)
			Menus.Close()
		end })
	end
	local cancel = UI.item(list, "STAY HERE", { LayoutOrder = 100 })
	table.insert(entries, { button = cancel, select = Menus.Close })
	UI.SetNav(entries, Menus.Close)
end

local CREDITS = {
	{ "BUNNY 64", true },
	{ "" },
	{ "STARRING", true }, { "A plush bunny with a patched ear" },
	{ "" },
	{ "FRIENDS", true }, { "Elder Shellby" }, { "Granny Clover" }, { "Pip" }, { "Prospector Digby" }, { "Guard Nibbles" }, { "Sir Ember" },
	{ "" },
	{ "BADDIES", true }, { "Grumblebugs" }, { "Hopscotch Toads" }, { "Flitbats" }, { "Thornhogs" }, { "Puffshrooms" },
	{ "and King Grumble as himself" },
	{ "" },
	{ "MUSIC", true }, { "Bunny's Theme and its many moods" },
	{ "" },
	{ "PLACES", true }, { "Carrot Meadow" }, { "Frostbite Peaks" }, { "Dustbowl Canyon" }, { "The Infernal Castle" },
	{ "" },
	{ "FOR", true }, { "everyone who ever chased" }, { "one more golden carrot" },
	{ "" }, { "" },
	{ "THANK YOU FOR PLAYING", true },
}

local function rollCredits(done)
	screen = "credits"
	clear()
	gui.Enabled = true
	UI.backdrop(layer, 0.05)
	bunnyViewport(layer, UDim2.fromOffset(220, 220), UDim2.new(0.82, 0, 0.5, 0), snap.menu.custom)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Size = UDim2.new(0.6, 0, 0, #CREDITS * 40)
	holder.Position = UDim2.new(0.42, 0, 1, 20)
	holder.Parent = layer
	for i, line in ipairs(CREDITS) do
		UI.label(holder, {
			Text = line[1], Font = line[2] and UI.TITLE or UI.BODY, TextSize = line[2] and 34 or 24,
			TextColor3 = line[2] and UI.Gold or UI.Cream, Size = UDim2.new(1, 0, 0, 38),
			Position = UDim2.fromOffset(0, (i - 1) * 40), Stroke = line[2] and 4 or 3,
		})
	end
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		done()
	end
	local roll = TweenService:Create(holder, TweenInfo.new(32, Enum.EasingStyle.Linear), { Position = UDim2.new(0.42, 0, 0, -#CREDITS * 40 - 20) })
	roll:Play()
	roll.Completed:Connect(finish)
	local skip = UI.item(layer, "SKIP", { Size = UDim2.fromOffset(140, 36), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -12), TextSize = 20 })
	UI.SetNav({ { button = skip, select = function()
		roll:Cancel()
		finish()
	end } })
end

function Menus.ShowEnding(s)
	gui.Enabled = true
	deps.Movement.SetEnabled(false)
	deps.Effects.SetMusic("ending") -- "Home Again": the full reprise of Bunny's Theme
	rollCredits(function()
		Menus.ShowEndingCard(s)
	end)
end

function Menus.ShowEndingCard(s)
	screen = "ending"
	clear()
	gui.Enabled = true
	deps.Movement.SetEnabled(false)
	UI.backdrop(layer, 0.2)
	UI.title(layer, "CONGRATULATIONS!", 76, UDim2.new(0.5, 0, 0, 40), Vector2.new(0.5, 0))
	bunnyViewport(layer, UDim2.fromOffset(260, 260), UDim2.fromScale(0.5, 0.42), snap.menu.custom)
	local panel = UI.panel(layer, UDim2.fromOffset(640, 210), UDim2.fromScale(0.5, 0.76))
	UI.label(panel, { Text = "Every golden carrot is home and King Grumble has learned his manners.\nThanks for playing BUNNY 64!", TextSize = 20, TextWrapped = true, Size = UDim2.new(1, -40, 0, 70), Position = UDim2.fromOffset(20, 16) })
	UI.label(panel, {
		Text = string.format("CLEAR TIME %s     CARROTS %d/%d", fmtTime(s.slot.completedTime), s.slot.carrotCount, s.totalCarrots or 0),
		Font = UI.TITLE, TextSize = 26, TextColor3 = UI.Gold, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 96),
	})
	local keep = UI.item(panel, "KEEP EXPLORING", { Size = UDim2.fromOffset(300, 44), Position = UDim2.new(0.5, -150, 1, -58) })
	local function finish()
		deps.WorldFX.ResetRegion() -- back to the area's own music and lighting
		Menus.Close()
	end
	UI.SetNav({ { button = keep, select = finish } }, finish)
end

--------------------------------------------------------------------------------
-- Starting / quitting a file
--------------------------------------------------------------------------------

function Menus.StartFile(index)
	if screen ~= "files" then
		return
	end
	screen = "loading"
	clear()
	UI.backdrop(layer, 0)
	UI.title(layer, "LOADING FILE " .. FILE_LETTERS[index] .. "...", 48, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	local ok = deps.Remotes.SelectSlot:InvokeServer(index)
	if not ok then
		screen = "files"
		showFiles(false)
		return
	end
	local char = player.Character or player.CharacterAdded:Wait()
	char:WaitForChild("Humanoid", 10)
	task.wait(0.3)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		cam.CameraSubject = hum
	end
	deps.onPlay()
	Menus.Close()
end

function Menus.BackToTitle()
	screen = "files"
	gui.Enabled = true
	deps.Hud.SetVisible(false)
	deps.Movement.SetEnabled(false)
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	deps.Effects.SetMusic("title")
	showFiles(false)
end

function Menus.SetSnapshot(s)
	local first = snap == nil
	snap = s
	if first and deps then
		Menus.ApplyControls() -- the player's saved key bindings
	end
end

function Menus.Screen()
	return screen
end

function Menus.Init(dependencies)
	deps = dependencies
	UI.Sound = function(name, speed)
		deps.Effects.Play(name, speed)
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "Bunny64Menus"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	layer = Instance.new("Frame")
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.Parent = gui
	scaler = Instance.new("UIScale")
	scaler.Parent = layer

	-- shrink menus to fit small screens
	local function rescale()
		local size = workspace.CurrentCamera.ViewportSize
		local s = math.min(1, size.X / 900, size.Y / 640)
		scaler.Scale = s
		layer.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	-- attract-mode camera while on the title / file screens
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	RunService.RenderStepped:Connect(function(dt)
		if screen ~= nil and not snap or (screen ~= nil and not (snap and snap.slot)) then
			orbit += dt * 0.06
			local pos = Vector3.new(math.cos(orbit) * 190, 75 + math.sin(orbit * 1.7) * 15, 60 + math.sin(orbit) * 190)
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = CFrame.lookAt(pos, Vector3.new(0, 25, 0))
		end
	end)

	Menus.ApplyControls()

	showTitle()
end

return Menus
