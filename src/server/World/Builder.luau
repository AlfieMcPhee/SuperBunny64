--[[
	Builder - shared helpers for constructing the world out of chunky parts,
	plus the registry of collectibles, enemies, hazards and checkpoints that
	the rest of the server reads.
]]

local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local P = Config.Palette
local SMOOTH = Enum.Material.SmoothPlastic

local B = {}
B.P = P
B.rng = Random.new(6464)

B.info = {
	carrots = {}, -- [id] = Vector3
	goldens = {}, -- [id] = Vector3
	bugs = {}, -- { pos = Vector3, skin = string }
	firebars = {}, -- { pivot, length, speed, phase }
	crushers = {}, -- { base = CFrame, size, drop, period, offset }
	boulderSpawns = {}, -- { from = Vector3, dir = Vector3 }
}

local movers = {}

function B.Init(root)
	local function folder(name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = root
		return f
	end
	B.root = root
	B.solid = folder("Solid")
	B.decor = folder("Decor")
	B.collect = folder("Collectibles")
	B.hazards = folder("Hazards")
	B.info.solidFolder = B.solid
	B.info.collectFolder = B.collect
	B.info.hazardFolder = B.hazards
end

--------------------------------------------------------------------------------
-- Primitive helpers
--------------------------------------------------------------------------------

function B.make(className, props, parent)
	local inst = Instance.new(className)
	if inst:IsA("BasePart") then
		inst.Anchored = true
		inst.TopSurface = Enum.SurfaceType.Smooth
		inst.BottomSurface = Enum.SurfaceType.Smooth
		inst.Material = SMOOTH
	end
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent or B.solid
	return inst
end

function B.block(cf, size, color, material, parent)
	return B.make("Part", { CFrame = cf, Size = size, Color = color, Material = material or SMOOTH }, parent)
end

-- Vertical cylinder with its base at `bottom`
function B.cyl(x, bottom, z, radius, height, color, material, parent)
	return B.make("Part", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(x, bottom + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or SMOOTH,
	}, parent)
end

-- Ellipsoid (decoration unless collide = true)
function B.blob(pos, size, color, material, parent, collide)
	local p = B.make("Part", {
		Size = size,
		CFrame = typeof(pos) == "CFrame" and pos or CFrame.new(pos),
		Color = color,
		Material = material or SMOOTH,
		CanCollide = collide == true,
		CanQuery = collide == true,
	}, parent or B.decor)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

function B.ball(pos, radius, color, material, parent)
	return B.make("Part", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * radius * 2,
		CFrame = CFrame.new(pos),
		Color = color,
		Material = material or SMOOTH,
	}, parent)
end

function B.wedge(cf, size, color, material, parent)
	return B.make("WedgePart", { CFrame = cf, Size = size, Color = color, Material = material or SMOOTH }, parent)
end

-- Ramp that climbs from `low` to `high` (both are top-surface centre points).
-- Built as a tilted slab so it can't end up facing the wrong way.
function B.ramp(low, high, width, color, material)
	local dir = (high - low).Unit
	-- tuck the low end into the ground; keep the top end flush with the landing
	return B.plank(low - dir * 2, high, width, 3, color, material)
end

-- A beam/plank between two points (top surface passes through them)
function B.plank(a, b, width, thickness, color, material, parent)
	local len = (b - a).Magnitude
	return B.make("Part", {
		Size = Vector3.new(width, thickness, len),
		CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -thickness / 2, 0),
		Color = color,
		Material = material or SMOOTH,
	}, parent)
end

-- Earthy pillar: side colour with a top cap
function B.mound(x, z, radius, top, capColor, base, sideColor, capMat, sideMat)
	base = base or -20
	B.cyl(x, base, z, radius, top - base - 0.6, sideColor or P.Dirt, sideMat)
	return B.cyl(x, top - 1, z, radius + 0.4, 1, capColor or P.Grass, capMat)
end

function B.terrace(x, z, tiers, sideColor, capMat, sideMat)
	for _, t in ipairs(tiers) do
		B.mound(x, z, t[1], t[2], t[3] or P.Grass, 0, sideColor, capMat, sideMat)
	end
end

function B.path(from, to, width, color, y)
	y = y or 0.12
	local a = Vector3.new(from.X, y, from.Z)
	local b = Vector3.new(to.X, y, to.Z)
	B.make("Part", {
		Size = Vector3.new(width, 0.25, (b - a).Magnitude),
		CFrame = CFrame.lookAt((a + b) / 2, b),
		Color = color or P.Path,
		CanCollide = false,
		CanQuery = false,
	}, B.decor)
end

-- An island: ground disc with a beach ring
function B.island(cx, cz, radius, top, groundColor, beachColor, groundMat, sideColor)
	B.cyl(cx, -30, cz, radius + 16, 27, beachColor or P.Sand, Enum.Material.Sand)
	B.mound(cx, cz, radius, top or 0, groundColor or P.Grass, -30, sideColor, groundMat)
end

--------------------------------------------------------------------------------
-- Moving platforms (physics-driven so riders are carried)
--------------------------------------------------------------------------------

function B.mover(part, fn)
	part.Anchored = false
	part.CustomPhysicalProperties = PhysicalProperties.new(50, 1, 0, 100, 1)
	part:SetAttribute("Moving", true)
	local att = Instance.new("Attachment")
	att.Parent = part
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.RigidityEnabled = true
	ap.Position = part.Position
	ap.Parent = part
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.RigidityEnabled = true
	ao.CFrame = part.CFrame
	ao.Parent = part
	table.insert(movers, { part = part, fn = fn, ap = ap, ao = ao })
	return part
end

-- Bob up and down
function B.bobber(part, amplitude, speed, phase)
	local base = part.CFrame
	return B.mover(part, function(t)
		return base + Vector3.new(0, math.sin(t * speed + phase) * amplitude, 0)
	end)
end

-- Slide back and forth along an offset
function B.slider(part, offset, speed, phase)
	local base = part.CFrame
	return B.mover(part, function(t)
		return base + offset * math.sin(t * speed + (phase or 0))
	end)
end

-- Spin about the vertical axis
function B.spinner(part, speed)
	local base = part.CFrame
	local rot = base - base.Position
	return B.mover(part, function(t)
		return CFrame.new(base.Position) * CFrame.Angles(0, t * speed, 0) * rot
	end)
end

-- Orbit around a centre point
function B.orbiter(part, center, radius, speed, phase)
	local rot = part.CFrame - part.Position
	local y = part.Position.Y
	return B.mover(part, function(t)
		local a = t * speed + phase
		return CFrame.new(center.X + math.cos(a) * radius, y, center.Z + math.sin(a) * radius) * rot
	end)
end

function B.Finish()
	for _, m in ipairs(movers) do
		pcall(function()
			m.part:SetNetworkOwner(nil)
		end)
	end
	RunService.Heartbeat:Connect(function()
		local t = workspace:GetServerTimeNow()
		for _, m in ipairs(movers) do
			local cf = m.fn(t)
			m.ap.Position = cf.Position
			m.ao.CFrame = cf
		end
	end)
end

--------------------------------------------------------------------------------
-- Collectibles
--------------------------------------------------------------------------------

local function carrotModel(pos, golden)
	local model = Instance.new("Model")
	model.Name = golden and "GoldenCarrot" or "Carrot"
	local body = golden and P.Gold or P.Carrot
	local dark = golden and P.GoldDark or P.CarrotDark
	local leaf = golden and Color3.fromRGB(236, 222, 170) or P.CarrotLeaf
	local s = golden and 1.8 or 1
	local function piece(offset, size, color)
		return B.make("Part", {
			Size = size * s,
			CFrame = CFrame.new(pos + offset * s),
			Color = color,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Material = golden and Enum.Material.Metal or SMOOTH,
		}, model)
	end
	local root = piece(Vector3.new(0, 0.5, 0), Vector3.new(1.4, 1.2, 1.4), body)
	piece(Vector3.new(0, -0.5, 0), Vector3.new(1.05, 1, 1.05), dark)
	piece(Vector3.new(0, -1.3, 0), Vector3.new(0.7, 0.8, 0.7), body)
	piece(Vector3.new(0, -1.9, 0), Vector3.new(0.35, 0.5, 0.35), dark)
	for i = -1, 1 do
		local l = piece(Vector3.new(0, 1.75, 0), Vector3.new(0.22, 1.5, 0.45), leaf)
		l.Material = SMOOTH
		l.CFrame = CFrame.new(pos + Vector3.new(i * 0.3, 1.75, 0) * s) * CFrame.Angles(0, i * 0.6, -i * 0.35)
	end
	model.PrimaryPart = root
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	if golden then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 214, 140)
		light.Range = 16
		light.Brightness = 1.3
		light.Parent = root
		B.make("Part", {
			Name = "Beam",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(180, 3, 3),
			CFrame = CFrame.new(pos + Vector3.new(0, 92, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(230, 206, 140),
			Transparency = 0.84,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		}, model)
	end
	model.Parent = B.collect
	return model
end

function B.carrot(pos)
	local id = string.format("c_%d_%d_%d", math.round(pos.X), math.round(pos.Y), math.round(pos.Z))
	if B.info.carrots[id] then
		return
	end
	B.info.carrots[id] = pos
	local m = carrotModel(pos, false)
	m:SetAttribute("CollectId", id)
	m:SetAttribute("Kind", "carrot")
end

-- A line of carrots between two points
function B.carrotLine(a, b, n)
	for i = 0, n - 1 do
		B.carrot(a:Lerp(b, n == 1 and 0 or i / (n - 1)))
	end
end

function B.carrotRing(center, radius, n)
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		B.carrot(center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius))
	end
end

function B.golden(id, pos)
	B.info.goldens[id] = pos
	local m = carrotModel(pos, true)
	m:SetAttribute("CollectId", id)
	m:SetAttribute("Kind", "golden")
end

function B.bug(pos, skin)
	table.insert(B.info.bugs, { pos = pos, skin = skin or "meadow" })
end

--------------------------------------------------------------------------------
-- Scenery
--------------------------------------------------------------------------------

function B.roundTree(x, y, z, s, leaf, leafDark)
	local rng = B.rng
	B.cyl(x, y - 1, z, 0.9 * s, 9 * s, P.Wood, Enum.Material.Wood)
	B.blob(Vector3.new(x, y + 10 * s, z), Vector3.new(9, 7, 9) * s, leaf or P.Leaf)
	B.blob(Vector3.new(x + 2 * s, y + 8.5 * s, z + 1 * s), Vector3.new(6, 5, 6) * s, leafDark or P.LeafDark)
	B.blob(Vector3.new(x - 1.5 * s, y + 13 * s, z - 0.5 * s), Vector3.new(5.5, 4.5, 5.5) * s, leaf or P.Leaf)
	if rng:NextNumber() < 0.3 then
		B.blob(Vector3.new(x + 0.5 * s, y + 7 * s, z - 3 * s), Vector3.new(4, 3.5, 4) * s, leafDark or P.LeafDark)
	end
end

function B.pineTree(x, y, z, s, color, snow)
	B.cyl(x, y - 1, z, 0.7 * s, 5 * s, P.Wood, Enum.Material.Wood)
	local c = color or P.Pine
	for i, r in ipairs({ 4.2, 3.2, 2.1, 1.0 }) do
		B.cyl(x, y + (i * 3) * s, z, r * s, (i == 4 and 2.5 or 3) * s, c, nil, B.decor)
		if snow then
			B.cyl(x, y + (i * 3 + (i == 4 and 2.5 or 3)) * s - 0.3, z, r * s * 0.8, 0.5, P.Snow, Enum.Material.Snow, B.decor)
		end
	end
end

function B.rock(x, y, z, s, color)
	local rng = B.rng
	B.make("Part", {
		Size = Vector3.new(4, 3, 3.5) * s,
		CFrame = CFrame.new(x, y + 1 * s, z) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4)),
		Color = color or (rng:NextNumber() < 0.5 and P.Stone or P.StoneDark),
		Material = Enum.Material.Slate,
	})
end

function B.flower(x, y, z)
	local colors = { Color3.fromRGB(196, 170, 96), Color3.fromRGB(176, 120, 132), Color3.fromRGB(214, 206, 186), Color3.fromRGB(140, 120, 160) }
	B.make("Part", {
		Size = Vector3.new(0.25, 1.2, 0.25),
		CFrame = CFrame.new(x, y + 0.6, z),
		Color = P.CarrotLeaf,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	}, B.decor)
	B.blob(Vector3.new(x, y + 1.3, z), Vector3.new(0.9, 0.5, 0.9), colors[B.rng:NextInteger(1, #colors)])
end

function B.cactus(x, y, z, s)
	local c = P.Cactus
	B.cyl(x, y - 1, z, 1.1 * s, 11 * s, c)
	B.blob(Vector3.new(x, y + 10 * s, z), Vector3.new(2.2, 1.4, 2.2) * s, c)
	for _, side in ipairs({ -1, 1 }) do
		local h = (side > 0 and 4 or 6) * s
		B.block(CFrame.new(x + side * 1.9 * s, y + h, z), Vector3.new(2.6 * s, 1.2 * s, 1.2 * s), c)
		B.cyl(x + side * 2.8 * s, y + h, z, 0.6 * s, 3.5 * s, c)
	end
end

function B.fence(from, to, y)
	y = y or 0
	local dir = to - from
	local n = math.max(1, math.floor(dir.Magnitude / 6))
	for i = 0, n do
		local p = from + dir * (i / n)
		B.block(CFrame.new(p.X, y + 1.6, p.Z), Vector3.new(0.7, 3.2, 0.7), P.Wood, Enum.Material.Wood)
	end
	for _, h in ipairs({ 1.2, 2.5 }) do
		local a = Vector3.new(from.X, y + h, from.Z)
		local b = Vector3.new(to.X, y + h, to.Z)
		B.make("Part", {
			Size = Vector3.new(0.35, 0.45, (b - a).Magnitude),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = P.WoodLight,
			Material = Enum.Material.Wood,
		})
	end
end

function B.sign(pos, facing, title, subtitle, boardColor, textColor)
	B.block(CFrame.new(pos + Vector3.new(0, 2.5, 0)), Vector3.new(0.8, 5, 0.8), P.Wood, Enum.Material.Wood)
	local board = B.block(
		CFrame.lookAt(pos + Vector3.new(0, 5, 0), pos + Vector3.new(0, 5, 0) + facing) * CFrame.new(0, 0, -0.5),
		Vector3.new(10, 3.8, 0.5),
		boardColor or P.WoodLight,
		Enum.Material.Wood
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.Parent = board
	local function label(text, y, h, size)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, -20, h, 0)
		t.Position = UDim2.new(0, 10, y, 0)
		t.Font = Enum.Font.Antique
		t.Text = text
		t.TextSize = size
		t.TextScaled = true
		t.TextColor3 = textColor or Color3.fromRGB(50, 34, 24)
		t.Parent = gui
	end
	label(title, 0.08, 0.48, 64)
	label(subtitle, 0.56, 0.34, 36)
	return board
end

function B.torch(pos)
	B.block(CFrame.new(pos), Vector3.new(0.6, 2.4, 0.6), P.Wood, Enum.Material.Wood)
	local flame = B.blob(pos + Vector3.new(0, 1.7, 0), Vector3.new(0.9, 1.3, 0.9), P.Ember, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 80)
	light.Range = 22
	light.Brightness = 1.6
	light.Shadows = false
	light.Parent = flame
	return flame
end

--------------------------------------------------------------------------------
-- Gameplay objects
--------------------------------------------------------------------------------

function B.lava(cf, size, parent)
	local p = B.make("Part", {
		Name = "Lava",
		CFrame = cf,
		Size = size,
		Color = P.Lava,
		Material = Enum.Material.Neon,
		CastShadow = false,
	}, parent)
	p:SetAttribute("Lava", true)
	return p
end

-- Hazard water (freezing pond etc.): touching it resets you like the sea
function B.hazardWater(cf, size, color)
	local p = B.make("Part", {
		Name = "HazardWater",
		CFrame = cf,
		Size = size,
		Color = color or P.Water,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		CastShadow = false,
	})
	p:SetAttribute("Water", true)
	return p
end

function B.firebar(pivot, length, speed, phase, noPost)
	local model = Instance.new("Model")
	model.Name = "Firebar"
	local count = math.max(3, math.floor(length / 1.8))
	local center
	for i = 0, count do
		local p = B.make("Part", {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (i == 0 and 1.6 or 1.5),
			CFrame = CFrame.new(pivot + Vector3.new(i * length / count, 0, 0)),
			Color = i == 0 and P.CastleDark or P.Ember,
			Material = i == 0 and SMOOTH or Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		}, model)
		if i == 0 then
			center = p
		end
	end
	model.PrimaryPart = center
	model:SetAttribute("Kind", "firebar")
	model:SetAttribute("Pivot", pivot)
	model:SetAttribute("Speed", speed)
	model:SetAttribute("Phase", phase or 0)
	model.Parent = B.hazards
	table.insert(B.info.firebars, { pivot = pivot, length = length, speed = speed, phase = phase or 0 })
	if not noPost then
		-- a little post under the pivot
		B.cyl(pivot.X, pivot.Y - 2.5, pivot.Z, 0.6, 2.5, P.CastleDark)
	end
	return model
end

-- Crusher: a stone block that drops by `drop` studs on a cycle
function B.crusher(cf, size, drop, period, offset)
	local model = Instance.new("Model")
	model.Name = "Crusher"
	local body = B.make("Part", {
		CFrame = cf,
		Size = size,
		Color = P.CastleStone,
		Material = Enum.Material.Slate,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, model)
	-- angry face on both long sides
	for _, side in ipairs({ -1, 1 }) do
		for _, ex in ipairs({ -1, 1 }) do
			B.make("Part", {
				CFrame = cf * CFrame.new(ex * size.X * 0.22, size.Y * 0.1, side * (size.Z / 2 + 0.05)),
				Size = Vector3.new(size.X * 0.16, size.Y * 0.14, 0.2),
				Color = P.Ember,
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
			}, model)
			B.make("Part", {
				CFrame = cf * CFrame.new(ex * size.X * 0.2, size.Y * 0.26, side * (size.Z / 2 + 0.06)) * CFrame.Angles(0, 0, ex * 0.4),
				Size = Vector3.new(size.X * 0.24, size.Y * 0.05, 0.2),
				Color = P.Ink,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
			}, model)
		end
	end
	model.PrimaryPart = body
	model:SetAttribute("Kind", "crusher")
	model:SetAttribute("Base", cf)
	model:SetAttribute("Drop", drop)
	model:SetAttribute("Period", period)
	model:SetAttribute("Offset", offset)
	model.Parent = B.hazards
	table.insert(B.info.crushers, { base = cf, size = size, drop = drop, period = period, offset = offset })
	return model
end

-- Golden-carrot gate: solid for players who haven't collected `need` goldens
function B.gate(cf, size, need, color)
	local p = B.make("Part", {
		Name = "GoldenGate",
		CFrame = cf,
		Size = size,
		Color = color or P.Gold,
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
		CastShadow = false,
	})
	p:SetAttribute("GoldenGate", need)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.Parent = p
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.LuckiestGuy
		t.TextScaled = true
		t.Text = string.format("%d GOLDEN CARROTS", need)
		t.TextColor3 = Color3.fromRGB(255, 236, 180)
		t.TextStrokeTransparency = 0
		t.Parent = gui
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = 60
		c.Parent = t
	end
	return p
end

-- A prompt that sends the player to a checkpoint (e.g. leaving a dungeon)
function B.exitPrompt(pos, checkpointId, text)
	local pad = B.cyl(pos.X, pos.Y - 0.5, pos.Z, 3, 0.8, Color3.fromRGB(70, 60, 90), Enum.Material.Slate)
	pad.Name = "ExitPad"
	pad:SetAttribute("ExitTo", checkpointId)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ExitPrompt"
	prompt.ActionText = text or "Leave"
	prompt.ObjectText = "Exit"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	return pad
end

function B.checkpointFlag(id)
	local def = Config.Checkpoints[id]
	local base = def.pos - Vector3.new(0, 4, 0)
	local pos = base + Vector3.new(7, 0, 0)
	B.block(CFrame.new(pos + Vector3.new(0, 5, 0)), Vector3.new(0.5, 10, 0.5), P.Stone, Enum.Material.Metal)
	local flag = B.block(CFrame.new(pos + Vector3.new(1.6, 8.6, 0)), Vector3.new(3, 2, 0.15), P.Roof, Enum.Material.Fabric)
	flag.Name = "CheckpointFlag"
	flag:SetAttribute("Checkpoint", id)
	flag.CanCollide = false
	B.cyl(pos.X, base.Y - 0.5, pos.Z, 1.6, 0.8, P.StoneDark)
end

function B.warpBurrow(def)
	local pos = def.pos
	local y = pos.Y
	B.cyl(pos.X, y - 0.5, pos.Z, 5.5, 1.3, P.DirtDark)
	local hole = B.cyl(pos.X, y + 0.5, pos.Z, 3.6, 0.4, Color3.fromRGB(26, 20, 16), nil, B.solid)
	hole.Name = "WarpBurrow"
	hole:SetAttribute("Warp", def.id)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		B.blob(Vector3.new(pos.X + math.cos(a) * 4.8, y + 1, pos.Z + math.sin(a) * 4.8), Vector3.new(2.6, 1.6, 2.6), P.Dirt, nil, B.decor)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WarpPrompt"
	prompt.ActionText = "Hop in"
	prompt.ObjectText = "Burrow Warp"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = hole
	B.sign(pos + Vector3.new(0, 0, 8), Vector3.new(0, 0, 1), "BURROW WARP", def.name)
	return hole, prompt
end

return B
