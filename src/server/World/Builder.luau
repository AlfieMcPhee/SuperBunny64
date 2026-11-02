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
	enemies = {}, -- { kind = string, pos = Vector3, skin = string, range?, axis? }
	crates = {}, -- Parts: breakable heart crates
	npcs = {}, -- { id = string, pos = Vector3, facing = Vector3 }
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

--------------------------------------------------------------------------------
-- Terrain (natural ground is Roblox smooth terrain; built things are parts)
--------------------------------------------------------------------------------

local Terrain = workspace.Terrain
local M = Enum.Material
B.Terrain = Terrain

local function capMaterial(capColor, capMat)
	if capMat == M.Snow then
		return M.Snow
	elseif capMat == M.Sand then
		return M.Sand
	elseif capMat == M.Basalt then
		return M.Basalt
	elseif capMat == M.Sandstone then
		return M.Sandstone
	elseif capColor == P.GrassLight then
		return M.LeafyGrass
	end
	return M.Grass
end

local function sideMaterial(sideColor, sideMat)
	if sideMat == M.Slate or sideColor == P.Rock then
		return M.Rock
	elseif sideMat == M.Basalt or sideColor == P.BasaltLight then
		return M.Basalt
	elseif sideMat == M.Sandstone or sideColor == P.SandstoneDark then
		return M.Sandstone
	end
	return M.Ground
end

function B.SetupTerrain()
	local colors = {
		[M.Grass] = Color3.fromRGB(98, 128, 64),
		[M.LeafyGrass] = Color3.fromRGB(112, 138, 70),
		[M.Ground] = Color3.fromRGB(118, 92, 66),
		[M.Mud] = Color3.fromRGB(96, 76, 58),
		[M.Rock] = Color3.fromRGB(118, 116, 112),
		[M.Sand] = Color3.fromRGB(194, 178, 134),
		[M.Snow] = Color3.fromRGB(228, 232, 236),
		[M.Glacier] = Color3.fromRGB(156, 196, 214),
		[M.Sandstone] = Color3.fromRGB(176, 126, 86),
		[M.Basalt] = Color3.fromRGB(58, 52, 54),
		[M.CrackedLava] = Color3.fromRGB(176, 84, 42),
		[M.Slate] = Color3.fromRGB(96, 92, 88),
	}
	for mat, color in pairs(colors) do
		pcall(function()
			Terrain:SetMaterialColor(mat, color)
		end)
	end
	-- animated grass blades on Grass terrain (also settable in Studio: Workspace > Terrain > Decoration)
	pcall(function()
		Terrain.Decoration = true
	end)
end

-- Earthy pillar of terrain: side material with a grassy (or snowy...) top
function B.mound(x, z, radius, top, capColor, base, sideColor, capMat, sideMat)
	base = base or -20
	local h = top - base
	Terrain:FillCylinder(CFrame.new(x, base + h / 2, z), h, radius, sideMaterial(sideColor, sideMat))
	local capH = math.min(3, h)
	Terrain:FillCylinder(CFrame.new(x, top - capH / 2, z), capH, radius, capMaterial(capColor, capMat))
end

function B.terrace(x, z, tiers, sideColor, capMat, sideMat)
	for _, t in ipairs(tiers) do
		B.mound(x, z, t[1], t[2], t[3] or P.Grass, 0, sideColor, capMat, sideMat)
	end
end

-- A smooth rounded hill rising `height` above y = 0
function B.hill(x, z, radius, height, material, y0)
	-- a sphere cap; the sphere is capped in size so flat hills stay cheap and local
	local r = math.min((radius * radius + height * height) / (2 * height), radius * 1.6)
	Terrain:FillBall(Vector3.new(x, (y0 or 0) + height - r, z), r, material or M.Grass)
end

-- A lump of rock/snow/etc poking out of the ground
function B.outcrop(pos, radius, material)
	Terrain:FillBall(pos, radius, material or M.Rock)
end

-- Repaint the ground surface along a line (dirt paths, scorched earth...)
function B.paint(from, to, width, toMaterial, fromMaterials)
	fromMaterials = fromMaterials or { M.Grass, M.LeafyGrass }
	local a = Vector3.new(from.X, 0, from.Z)
	local b = Vector3.new(to.X, 0, to.Z)
	local len = (b - a).Magnitude
	local steps = math.max(1, math.floor(len / 4))
	for i = 0, steps do
		local p = a:Lerp(b, i / steps)
		local region = Region3.new(p - Vector3.new(width / 2, 6, width / 2), p + Vector3.new(width / 2, 6, width / 2)):ExpandToGrid(4)
		for _, mat in ipairs(fromMaterials) do
			Terrain:ReplaceMaterial(region, 4, mat, toMaterial)
		end
	end
end

function B.path(from, to, width)
	B.paint(from, to, width, M.Ground)
end

-- Carve a shallow pond and fill it with (harmless) water
function B.pond(x, z, radius, depth)
	-- remove a shallow bowl: a big sphere of air whose bottom dips `depth` below the ground
	local r = (radius * radius + depth * depth) / (2 * depth)
	Terrain:FillBall(Vector3.new(x, r - depth, z), r, M.Air)
	Terrain:FillCylinder(CFrame.new(x, -depth - 1.5, z), 3, radius * 0.9, M.Mud)
	local w = B.cyl(x, -1.4, z, radius * 0.95, 1, P.Water, M.Glass, B.decor)
	w.Transparency = 0.25
	w.CanCollide = false
	w.CanQuery = false
	w.CastShadow = false
	for i = 1, 5 do
		local a = i * 1.3
		local pad = B.cyl(x + math.cos(a) * radius * 0.5, -0.45, z + math.sin(a) * radius * 0.5, 1.4, 0.15, P.Leaf, nil, B.decor)
		pad.CanCollide = false
	end
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + 0.2
		B.make("Part", {
			Size = Vector3.new(0.3, 4 + (i % 3), 0.3),
			CFrame = CFrame.new(x + math.cos(a) * radius, 1.5, z + math.sin(a) * radius) * CFrame.Angles(0.1, 0, (i % 2) * 0.2 - 0.1),
			Color = Color3.fromRGB(110, 120, 60),
			CanCollide = false,
			CanQuery = false,
		}, B.decor)
	end
end

-- An island: terrain ground on a sandy shelf that slopes into the sea
function B.island(cx, cz, radius, top, groundColor, beachColor, groundMat, sideColor)
	top = top or 0
	local beach = (beachColor == P.Sand or beachColor == nil) and M.Sand or (groundMat == M.Snow and M.Snow or (groundMat == M.Basalt and M.Basalt or M.Sand))
	Terrain:FillCylinder(CFrame.new(cx, -16.5, cz), 27, radius + 14, beach)
	-- soft slope from the shelf down into the water
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local r = radius + 14
		Terrain:FillBall(Vector3.new(cx + math.cos(a) * r, -13, cz + math.sin(a) * r), 9, beach)
	end
	B.mound(cx, cz, radius, top, groundColor, -30, sideColor, groundMat)
end

--------------------------------------------------------------------------------
-- Ground queries
--------------------------------------------------------------------------------

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

-- Height of the ground (terrain or solid parts) under x, z
function B.groundY(x, z, fromY)
	groundParams.FilterDescendantsInstances = { Terrain, B.solid }
	local hit = workspace:Raycast(Vector3.new(x, fromY or 400, z), Vector3.new(0, -(fromY or 400) - 60, 0), groundParams)
	return hit and hit.Position.Y or 0
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

local function carrotModel(pos, golden, silver)
	local model = Instance.new("Model")
	model.Name = golden and "GoldenCarrot" or (silver and "SilverCarrot" or "Carrot")
	local body = golden and P.Gold or (silver and Color3.fromRGB(206, 212, 222) or P.Carrot)
	local dark = golden and P.GoldDark or (silver and Color3.fromRGB(150, 158, 172) or P.CarrotDark)
	local leaf = golden and Color3.fromRGB(236, 222, 170) or (silver and Color3.fromRGB(226, 232, 240) or P.CarrotLeaf)
	local s = golden and 1.8 or (silver and 1.3 or 1)
	local function piece(offset, size, color)
		return B.make("Part", {
			Size = size * s,
			CFrame = CFrame.new(pos + offset * s),
			Color = color,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Material = (golden or silver) and Enum.Material.Metal or SMOOTH,
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

-- `pos` names the carrot (its save id); `actual` is where it really floats
-- (e.g. lifted onto a hill), so ids stay stable when the ground changes.
function B.carrot(pos, actual)
	local id = string.format("c_%d_%d_%d", math.round(pos.X), math.round(pos.Y), math.round(pos.Z))
	if B.info.carrots[id] then
		return
	end
	actual = actual or pos
	B.info.carrots[id] = actual
	local m = carrotModel(actual, false)
	m:SetAttribute("CollectId", id)
	m:SetAttribute("Kind", "carrot")
end

-- A line of carrots between two points
-- A carrot hovering 3 studs above whatever ground is at (x, z)
function B.carrotOnGround(x, z, nominalY)
	-- cast from just above head height so floating platforms overhead don't count
	B.carrot(Vector3.new(x, nominalY or 3, z), Vector3.new(x, B.groundY(x, z, 60) + 3, z))
end

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

-- Silver carrots: five per hunt; the golden reward appears once you have them all
function B.silver(setId, index, pos)
	local id = string.format("s_%s_%d", setId, index)
	B.info.silvers = B.info.silvers or {}
	B.info.silvers[id] = { pos = pos, set = setId }
	local m = carrotModel(pos, false, true)
	m:SetAttribute("CollectId", id)
	m:SetAttribute("Kind", "silver")
	m:SetAttribute("SilverSet", setId)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(210, 226, 255)
	light.Range = 10
	light.Brightness = 1
	light.Parent = m.PrimaryPart
end

-- A glowing start pad for a time trial
function B.trialPad(id, def)
	local y = B.groundY(def.start.X, def.start.Z, def.start.Y + 20)
	local pad = B.cyl(def.start.X, y - 0.3, def.start.Z, 6, 0.6, Color3.fromRGB(110, 190, 220), Enum.Material.Neon)
	pad.Name = "TrialPad"
	pad:SetAttribute("Trial", id)
	pad.CanCollide = false
	B.cyl(def.start.X, y - 0.5, def.start.Z, 7, 0.6, P.StoneDark, Enum.Material.Slate)
	B.sign(Vector3.new(def.start.X + 9, y, def.start.Z), Vector3.new(-1, 0, 0), def.name, string.format("Step on the pad: %d seconds!", def.time))
	-- a ring marking the finish line
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local p = def.finish + Vector3.new(math.cos(a) * def.finishRadius, 0.6, math.sin(a) * def.finishRadius)
		B.make("Part", {
			Size = Vector3.new(0.6, 1.2, 0.6),
			CFrame = CFrame.new(p),
			Color = Color3.fromRGB(110, 190, 220),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		}, B.decor)
	end
end

function B.golden(id, pos)
	B.info.goldens[id] = pos
	local m = carrotModel(pos, true)
	m:SetAttribute("CollectId", id)
	m:SetAttribute("Kind", "golden")
end

-- A wooden heart crate sitting on the ground at (x, z). Break it (roll, slide,
-- long jump, ground pound or stomp) for a heart; it comes back later.
function B.crate(x, z, fromY)
	local y = B.groundY(x, z, fromY or 60)
	local crate = B.make("Part", {
		Name = "HeartCrate",
		Size = Vector3.new(4, 4, 4),
		CFrame = CFrame.new(x, y + 2, z) * CFrame.Angles(0, B.rng:NextNumber(0, math.pi), 0),
		Color = P.WoodLight,
		Material = Enum.Material.WoodPlanks,
	})
	crate:SetAttribute("Crate", true)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Top }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 1
		gui.Parent = crate
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.SourceSansBold
		t.Text = "♥"
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(196, 64, 64)
		t.TextStrokeTransparency = 0.4
		t.Parent = gui
	end
	table.insert(B.info.crates, crate)
	return crate
end

-- A friendly character to talk to (see client/Dialogue and Config.NPCs)
function B.npc(id, x, z, facing)
	table.insert(B.info.npcs, { id = id, pos = Vector3.new(x, B.groundY(x, z, 60), z), facing = facing or Vector3.new(0, 0, 1) })
end

function B.bug(pos, skin)
	table.insert(B.info.enemies, { kind = "bug", pos = pos, skin = skin or "meadow" })
end

-- kind: toad, bat, thornhog, puffshroom (bats hover at `pos`; others sit on the ground)
function B.enemy(kind, pos, skin, range, axis)
	table.insert(B.info.enemies, { kind = kind, pos = pos, skin = skin, range = range, axis = axis })
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
	-- foliage is walk-through (like the round trees); only the trunk is solid
	for i, r in ipairs({ 4.2, 3.2, 2.1, 1.0 }) do
		local layer = B.cyl(x, y + (i * 3) * s, z, r * s, (i == 4 and 2.5 or 3) * s, c, nil, B.decor)
		layer.CanCollide = false
		layer.CanQuery = false
		if snow then
			local cap = B.cyl(x, y + (i * 3 + (i == 4 and 2.5 or 3)) * s - 0.3, z, r * s * 0.8, 0.5, P.Snow, Enum.Material.Snow, B.decor)
			cap.CanCollide = false
			cap.CanQuery = false
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

function B.bush(x, y, z, s, color)
	local c = color or P.LeafDark
	B.blob(Vector3.new(x, y + 1.2 * s, z), Vector3.new(4.5, 3, 4) * s, c)
	B.blob(Vector3.new(x + 1.6 * s, y + 1.0 * s, z + 0.8 * s), Vector3.new(3, 2.4, 3) * s, P.Leaf)
	B.blob(Vector3.new(x - 1.4 * s, y + 0.9 * s, z - 0.6 * s), Vector3.new(2.8, 2.2, 2.8) * s, P.Leaf)
	if B.rng:NextNumber() < 0.4 then
		for i = 1, 4 do
			local a = i * 1.7
			B.blob(Vector3.new(x + math.cos(a) * 1.6 * s, y + 2.3 * s, z + math.sin(a) * 1.4 * s), Vector3.new(0.45, 0.45, 0.45), Color3.fromRGB(168, 58, 60))
		end
	end
end

function B.log(x, y, z, angle, s)
	local cf = CFrame.new(x, y + 0.9 * s, z) * CFrame.Angles(0, angle, 0)
	B.make("Part", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(9 * s, 1.9 * s, 1.9 * s),
		CFrame = cf,
		Color = P.Wood,
		Material = Enum.Material.Wood,
	})
	for _, e in ipairs({ -1, 1 }) do
		B.make("Part", {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, 1.6 * s, 1.6 * s),
			CFrame = cf * CFrame.new(e * 4.52 * s, 0, 0),
			Color = P.WoodLight,
			CanCollide = false,
		}, B.decor)
	end
	B.blob(cf.Position + Vector3.new(0, 0.9 * s, 0), Vector3.new(2.2, 0.4, 1.4) * s, Color3.fromRGB(96, 124, 70))
end

function B.mushrooms(x, y, z)
	for i = 1, B.rng:NextInteger(3, 5) do
		local a = i * 2.1
		local px, pz = x + math.cos(a) * 1.4, z + math.sin(a) * 1.4
		local h = 0.6 + (i % 3) * 0.35
		B.make("Part", {
			Size = Vector3.new(0.3, h, 0.3),
			CFrame = CFrame.new(px, y + h / 2, pz),
			Color = P.MushroomStem,
			CanCollide = false,
			CanQuery = false,
		}, B.decor)
		B.blob(Vector3.new(px, y + h, pz), Vector3.new(0.9, 0.45, 0.9), i % 2 == 0 and P.Mushroom or Color3.fromRGB(176, 140, 96))
	end
end

-- A clump of tall grass blades (extra detail on top of the terrain grass)
function B.tuft(x, y, z)
	local colors = { Color3.fromRGB(96, 130, 60), Color3.fromRGB(116, 146, 70), Color3.fromRGB(84, 114, 54) }
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2 + B.rng:NextNumber(0, 1)
		local h = B.rng:NextNumber(1.4, 2.6)
		B.make("WedgePart", {
			Size = Vector3.new(0.12, h, 0.5),
			CFrame = CFrame.new(x + math.cos(a) * 0.35, y + h / 2 - 0.1, z + math.sin(a) * 0.35) * CFrame.Angles(0, a, B.rng:NextNumber(-0.25, 0.25)),
			Color = colors[B.rng:NextInteger(1, #colors)],
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		}, B.decor)
	end
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
	light.Color = Color3.fromRGB(255, 160, 96)
	light.Range = 30
	light.Brightness = 2.2
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

-- Checkpoint flag beside the respawn point, standing on whatever ground is there.
-- The flag cloth turns gold on the client when it's your active checkpoint.
function B.checkpointFlag(id, offset)
	local def = Config.Checkpoints[id]
	offset = offset or Vector3.new(-7, 0, 0)
	local x, z = def.pos.X + offset.X, def.pos.Z + offset.Z
	local y = B.groundY(x, z, def.pos.Y + 3)
	local pos = Vector3.new(x, y, z)
	B.cyl(x, y - 0.6, z, 1.6, 1, P.StoneDark, Enum.Material.Slate)
	local pole = B.block(CFrame.new(pos + Vector3.new(0, 5, 0)), Vector3.new(0.5, 10, 0.5), P.Stone, Enum.Material.Metal)
	pole.Name = "CheckpointPole"
	B.blob(pos + Vector3.new(0, 10.2, 0), Vector3.new(0.8, 0.8, 0.8), P.Gold, Enum.Material.Metal)
	local flag = B.block(CFrame.new(pos + Vector3.new(1.75, 8.7, 0)), Vector3.new(3, 2, 0.15), P.Roof, Enum.Material.Fabric)
	flag.Name = "CheckpointFlag"
	flag:SetAttribute("Checkpoint", id)
	flag.CanCollide = false
	flag.CanQuery = false
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
