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

	local left = UI.panel(layer, UDim2.fromOffset(330, 400), UDim2.new(0.5, -215, 0.53, 0))
	local vp, model = bunnyViewport(left, UDim2.new(1, -20, 1, -20), UDim2.fromScale(0.5, 0.5), custom)
	vp.ZIndex = 3
	local right = UI.panel(layer, UDim2.fromOffset(440, 400), UDim2.new(0.5, 200, 0.53, 0))
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
					text = item.boss and (item.name .. " (BEAT THE KING)") or string.format("%s (%d GOLDEN)", item.name, item.need)
				end
			else
				text = d.list[custom[d.key]].name
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
	local panel = UI.panel(layer, UDim2.fromOffset(520, 380), UDim2.fromScale(0.5, 0.53))
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
	local function refresh()
		sfx.Text = "SOUND  < " .. bar(o.sfx) .. " >"
		music.Text = "MUSIC  < " .. bar(o.music) .. " >"
		shake.Text = "SCREEN SHAKE  < " .. (o.shake and "ON" or "OFF") .. " >"
		deps.Effects.SetOptions(o)
	end
	refresh()
	local function finish()
		deps.Remotes.SetOptions:FireServer(o)
		back()
	end
	local controlsButton = UI.item(list, "CONTROLS", { LayoutOrder = 4 })
	local backButton = UI.item(list, "BACK", { LayoutOrder = 6 })
	UI.label(list, { Text = "8-bit music is built in. Add uploaded track ids in Config.Music to replace it.", TextSize = 14, TextWrapped = true, LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 34), Stroke = 2, TextTransparency = 0.3 })
	UI.SetNav({
		{ button = sfx, left = function() o.sfx = math.max(0, o.sfx - 1); refresh() end, right = function() o.sfx = math.min(10, o.sfx + 1); refresh() end, select = function() o.sfx = (o.sfx + 1) % 11; refresh() end },
		{ button = music, left = function() o.music = math.max(0, o.music - 1); refresh() end, right = function() o.music = math.min(10, o.music + 1); refresh() end, select = function() o.music = (o.music + 1) % 11; refresh() end },
		{ button = shake, left = function() o.shake = not o.shake; refresh() end, right = function() o.shake = not o.shake; refresh() end, select = function() o.shake = not o.shake; refresh() end },
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
		UI.label(scroll, { Text = string.format("%s   %d/%d", region.name, got, total), Font = UI.TITLE, TextSize = 26, TextColor3 = UI.Gold, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = order, Stroke = 3 })
		for _, g in ipairs(Config.Goldens) do
			if g.region == region.id then
				order += 1
				local have = slot and slot.goldens[g.id]
				local b = UI.item(scroll, have and string.upper(g.name) or ("???  " .. g.hint), {
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
	local panel = UI.panel(layer, UDim2.fromOffset(460, 330), UDim2.fromScale(0.5, 0.56))
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, -30, 1, -30)
	list.Position = UDim2.fromOffset(15, 15)
	list.Parent = panel
	UI.list(list, 8)
	local resume = UI.item(list, "RESUME", { LayoutOrder = 1 })
	local log = UI.item(list, "CARROT LOG", { LayoutOrder = 2 })
	local custom = UI.item(list, "CUSTOMISE", { LayoutOrder = 3 })
	local options = UI.item(list, "OPTIONS", { LayoutOrder = 4 })
	local quit = UI.item(list, "SAVE & QUIT", { LayoutOrder = 5 })
	local backToPause = function()
		showPause()
	end
	UI.SetNav({
		{ button = resume, select = Menus.Close },
		{ button = log, select = function() showLog(backToPause) end },
		{ button = custom, select = function() showCustomise(backToPause) end },
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

function Menus.ShowEnding(s)
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
	UI.SetNav({ { button = keep, select = Menus.Close } }, Menus.Close)
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
