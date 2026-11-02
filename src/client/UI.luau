--[[
	UI - shared building blocks for Bunny 64's late-90s console look:
	chunky beveled panels with gold trim, gradient title lettering, a bouncing
	carrot cursor, and menu navigation that works with keyboard, gamepad,
	mouse and touch.
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local P = Config.Palette

local UI = {}

UI.TITLE = Enum.Font.LuckiestGuy
UI.BODY = Enum.Font.FredokaOne
UI.Cream = P.UiText
UI.Gold = Color3.fromRGB(246, 200, 86)
UI.Ink = Color3.fromRGB(20, 14, 18)
UI.Navy = Color3.fromRGB(30, 32, 60)

local rgb = Color3.fromRGB

function UI.stroke(inst, thickness, color, mode)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or UI.Ink
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = inst
	return s
end

function UI.corner(inst, px)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px or 10)
	c.Parent = inst
	return c
end

function UI.gradient(inst, colors, rotation)
	local g = Instance.new("UIGradient")
	local keys = {}
	for i, c in ipairs(colors) do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colors - 1), c))
	end
	g.Color = ColorSequence.new(keys)
	g.Rotation = rotation or 90
	g.Parent = inst
	return g
end

function UI.label(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = UI.BODY
	t.TextColor3 = UI.Cream
	t.TextSize = 22
	t.Size = UDim2.new(1, 0, 0, 30)
	local strokeSize = 3
	for k, v in pairs(props) do
		if k == "Stroke" then
			strokeSize = v
		else
			t[k] = v
		end
	end
	if strokeSize > 0 then
		UI.stroke(t, strokeSize)
	end
	t.Parent = parent
	return t
end

-- Big lettering with a gold-to-orange face and a chunky extruded shadow
function UI.title(parent, text, size, pos, anchor, colors)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, size + 16)
	holder.Position = pos or UDim2.new()
	holder.AnchorPoint = anchor or Vector2.new()
	holder.Parent = parent
	for i = 4, 1, -1 do
		local shadow = UI.label(holder, {
			Text = text, Font = UI.TITLE, TextSize = size, TextColor3 = rgb(40 + i * 6, 22 + i * 4, 30 + i * 4),
			Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(i * 1.5, i * 2), Stroke = 0,
		})
		shadow.ZIndex = 1
	end
	local face = UI.label(holder, {
		Text = text, Font = UI.TITLE, TextSize = size, TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1), Stroke = 4,
	})
	face.ZIndex = 2
	UI.gradient(face, colors or { rgb(255, 236, 140), rgb(246, 186, 70), rgb(214, 110, 46) }, 90)
	return holder, face
end

-- Beveled panel with gold trim and a drop shadow
function UI.panel(parent, size, pos, anchor)
	local shadow = Instance.new("Frame")
	shadow.Size = size
	shadow.Position = pos
	shadow.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.55
	shadow.BorderSizePixel = 0
	UI.corner(shadow, 16)
	shadow.Parent = parent
	local f = Instance.new("Frame")
	f.Name = "Panel"
	f.Size = UDim2.new(1, 0, 1, 0)
	f.Position = UDim2.fromOffset(-7, -7)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	UI.corner(f, 16)
	UI.gradient(f, { rgb(64, 70, 120), rgb(36, 38, 72), rgb(24, 24, 46) }, 90)
	UI.stroke(f, 4, UI.Gold, Enum.ApplyStrokeMode.Border)
	f.Parent = shadow
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.new(1, -12, 1, -12)
	inner.Position = UDim2.fromOffset(6, 6)
	UI.stroke(inner, 2, rgb(16, 14, 30), Enum.ApplyStrokeMode.Border)
	UI.corner(inner, 12)
	inner.Parent = f
	return f, shadow
end

-- Little carrot drawn with frames (icons, cursor)
function UI.carrot(parent, color, scale, pos, anchor)
	scale = scale or 1
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(22 * scale, 30 * scale)
	holder.Position = pos or UDim2.new()
	holder.AnchorPoint = anchor or Vector2.new()
	holder.Parent = parent
	local function bit(x, y, w, h, c)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = c
		f.Position = UDim2.fromOffset(x * scale, y * scale)
		f.Size = UDim2.fromOffset(w * scale, h * scale)
		UI.stroke(f, math.max(1, 2 * scale), UI.Ink, Enum.ApplyStrokeMode.Border)
		f.Parent = holder
		return f
	end
	for i, x in ipairs({ 4, 9, 14 }) do
		bit(x, i == 2 and 0 or 3, 4, i == 2 and 10 or 7, color == P.Gold and rgb(236, 222, 170) or P.CarrotLeaf)
	end
	local body = bit(5, 9, 12, 12, color)
	UI.corner(body, 3 * scale)
	bit(7, 20, 8, 6, color)
	bit(9, 25, 4, 4, color)
	return holder
end

-- Scrolling patterned backdrop (sits behind menus)
function UI.backdrop(parent, opacity)
	local bg = Instance.new("Frame")
	bg.Name = "Backdrop"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.new(1, 1, 1)
	bg.BackgroundTransparency = opacity or 0.15
	bg.BorderSizePixel = 0
	bg.ClipsDescendants = true
	bg.Parent = parent
	local grad = UI.gradient(bg, { rgb(46, 52, 104), rgb(70, 44, 92), rgb(38, 70, 96) }, 45)
	local tiles = Instance.new("Frame")
	tiles.BackgroundTransparency = 1
	tiles.Size = UDim2.new(1, 240, 1, 240)
	tiles.Parent = bg
	for gx = 0, 13 do
		for gy = 0, 9 do
			if (gx + gy) % 2 == 0 then
				local c = UI.carrot(tiles, rgb(255, 255, 255), 1, UDim2.fromOffset(gx * 120, gy * 120))
				c.Rotation = 25
				for _, d in ipairs(c:GetDescendants()) do
					if d:IsA("Frame") then
						d.BackgroundTransparency = 0.9
					elseif d:IsA("UIStroke") then
						d.Transparency = 1
					end
				end
			end
		end
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not bg.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock()
		local off = (t * 24) % 240
		tiles.Position = UDim2.fromOffset(-off, -off)
		grad.Rotation = 45 + math.sin(t * 0.2) * 20
	end)
	return bg
end

--------------------------------------------------------------------------------
-- Menu navigation
--------------------------------------------------------------------------------
-- entries: { button = GuiButton, select = fn, left = fn?, right = fn? }

local nav = { entries = {}, index = 1, back = nil, sound = nil }
UI.Sound = function() end

local function highlight()
	for i, e in ipairs(nav.entries) do
		local on = i == nav.index
		if e.button and e.button.Parent then
			e.button.TextColor3 = on and UI.Gold or UI.Cream
			local scale = e.button:FindFirstChildOfClass("UIScale")
			if scale then
				TweenService:Create(scale, TweenInfo.new(0.12), { Scale = on and 1.08 or 1 }):Play()
			end
			local cursor = e.button:FindFirstChild("Cursor")
			if cursor then
				cursor.Visible = on
			end
		end
		if e.focus then
			e.focus(on)
		end
	end
end

function UI.SetNav(entries, back, startIndex)
	nav.entries = entries or {}
	nav.back = back
	nav.index = math.clamp(startIndex or 1, 1, math.max(1, #nav.entries))
	for i, e in ipairs(nav.entries) do
		if e.button and not e.hooked then
			e.hooked = true
			e.button.MouseEnter:Connect(function()
				if nav.entries[i] == e and nav.index ~= i then
					nav.index = i
					UI.Sound("MenuMove", 1.3)
					highlight()
				end
			end)
			e.button.Activated:Connect(function()
				if nav.entries[i] == e then
					nav.index = i
					highlight()
					UI.Sound("MenuSelect", 1)
					if e.select then
						e.select()
					end
				end
			end)
		end
	end
	highlight()
end

function UI.ClearNav()
	nav.entries = {}
	nav.back = nil
end

function UI.NavActive()
	return #nav.entries > 0
end

local function moveSel(delta)
	if #nav.entries == 0 then
		return
	end
	nav.index = (nav.index - 1 + delta) % #nav.entries + 1
	UI.Sound("MenuMove", 1.3)
	highlight()
end

local function side(delta)
	local e = nav.entries[nav.index]
	if e then
		local fn = delta < 0 and e.left or e.right
		if fn then
			UI.Sound("MenuMove", delta < 0 and 1.1 or 1.5)
			fn()
			return true
		end
	end
	return false
end

local function activate()
	local e = nav.entries[nav.index]
	if e and e.select then
		UI.Sound("MenuSelect", 1)
		e.select()
	end
end

local KEYS_UP = { [Enum.KeyCode.Up] = true, [Enum.KeyCode.W] = true, [Enum.KeyCode.DPadUp] = true }
local KEYS_DOWN = { [Enum.KeyCode.Down] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.DPadDown] = true }
local KEYS_LEFT = { [Enum.KeyCode.Left] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.DPadLeft] = true }
local KEYS_RIGHT = { [Enum.KeyCode.Right] = true, [Enum.KeyCode.D] = true, [Enum.KeyCode.DPadRight] = true }
local KEYS_OK = { [Enum.KeyCode.Return] = true, [Enum.KeyCode.Space] = true, [Enum.KeyCode.ButtonA] = true, [Enum.KeyCode.KeypadEnter] = true }
local KEYS_BACK = { [Enum.KeyCode.Backspace] = true, [Enum.KeyCode.ButtonB] = true }

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or #nav.entries == 0 then
		return
	end
	local k = input.KeyCode
	if KEYS_UP[k] then
		moveSel(-1)
	elseif KEYS_DOWN[k] then
		moveSel(1)
	elseif KEYS_LEFT[k] then
		if not side(-1) then
			moveSel(-1)
		end
	elseif KEYS_RIGHT[k] then
		if not side(1) then
			moveSel(1)
		end
	elseif KEYS_OK[k] then
		activate()
	elseif KEYS_BACK[k] and nav.back then
		UI.Sound("MenuMove", 0.8)
		nav.back()
	end
end)

-- Thumbstick navigation with repeat
local stickReady = true
UserInputService.InputChanged:Connect(function(input)
	if input.KeyCode ~= Enum.KeyCode.Thumbstick1 or #nav.entries == 0 then
		return
	end
	local p = input.Position
	if math.abs(p.X) < 0.4 and math.abs(p.Y) < 0.4 then
		stickReady = true
		return
	end
	if not stickReady then
		return
	end
	stickReady = false
	if math.abs(p.Y) > math.abs(p.X) then
		moveSel(p.Y > 0 and -1 or 1)
	elseif not side(p.X > 0 and 1 or -1) then
		moveSel(p.X > 0 and 1 or -1)
	end
end)

-- A menu row: text button with a bouncing carrot cursor
function UI.item(parent, text, props)
	local b = Instance.new("TextButton")
	b.BackgroundTransparency = 1
	b.AutoButtonColor = false
	b.Font = UI.BODY
	b.Text = text
	b.TextSize = 28
	b.TextColor3 = UI.Cream
	b.Size = UDim2.new(1, 0, 0, 42)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	UI.stroke(b, 3)
	local scale = Instance.new("UIScale")
	scale.Parent = b
	local cursor = UI.carrot(b, P.Carrot, 1, UDim2.new(0, 6, 0.5, 0), Vector2.new(0, 0.5))
	cursor.Name = "Cursor"
	cursor.Rotation = 90
	cursor.Visible = false
	TweenService:Create(cursor, TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = UDim2.new(0, 14, 0.5, 0),
	}):Play()
	b.Parent = parent
	return b
end

function UI.list(parent, padding)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding or 4)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.Parent = parent
	return l
end

return UI
