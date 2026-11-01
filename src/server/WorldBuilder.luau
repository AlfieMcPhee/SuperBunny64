--[[
	WorldBuilder - builds Carrot Meadow out of chunky low-poly parts at runtime.

	Coordinates are in studs. The main island's grass is at Y = 0 and the sea
	sits at Config.WaterLevel. Returns a table describing spawn, collectibles
	and enemy homes.
]]

local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local P = Config.Palette
local WATER = Config.WaterLevel
local SMOOTH = Enum.Material.SmoothPlastic

local WorldBuilder = {}

local world -- Folder for solid level geometry
local decor -- Folder for non-colliding decoration
local collectFolder -- Folder for carrots
local movers = {}

local info = {
	carrots = {}, -- [id] = Vector3
	goldens = {}, -- [id] = Vector3
	bugs = {}, -- { Vector3 }
	spawn = nil,
}

--------------------------------------------------------------------------------
-- Part helpers
--------------------------------------------------------------------------------

local function make(className, props, parent)
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
	inst.Parent = parent or world
	return inst
end

local function block(cf, size, color, material, parent)
	return make("Part", { CFrame = cf, Size = size, Color = color, Material = material or SMOOTH }, parent)
end

-- Vertical cylinder sitting on `bottom` (its base) at x,z.
local function cyl(x, bottom, z, radius, height, color, material, parent)
	return make("Part", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(x, bottom + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or SMOOTH,
	}, parent)
end

-- Ellipsoid "blob" (decoration by default).
local function blob(pos, size, color, material, parent, collide)
	local p = make("Part", {
		Size = size,
		CFrame = CFrame.new(pos),
		Color = color,
		Material = material or SMOOTH,
		CanCollide = collide == true,
		CanQuery = collide == true,
	}, parent or decor)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function wedge(cf, size, color, material)
	return make("WedgePart", { CFrame = cf, Size = size, Color = color, Material = material or SMOOTH })
end

-- Grass-capped earthy pillar: dirt sides with a grass lid, very N64.
local function mound(x, z, radius, top, grassColor, base)
	base = base or -20
	cyl(x, base, z, radius, top - base - 0.6, P.Dirt)
	cyl(x, top - 1, z, radius + 0.4, 1, grassColor or P.Grass)
end

local function terrace(x, z, tiers)
	for _, t in ipairs(tiers) do
		mound(x, z, t[1], t[2], t[3] or P.Grass, 0)
	end
end

local function path(from, to, width)
	local a = Vector3.new(from.X, 0.12, from.Z)
	local b = Vector3.new(to.X, 0.12, to.Z)
	local len = (b - a).Magnitude
	make("Part", {
		Size = Vector3.new(width, 0.25, len),
		CFrame = CFrame.lookAt((a + b) / 2, b),
		Color = P.Path,
		CanCollide = false,
		CanQuery = false,
	}, decor)
end

-- Physics-driven moving platform: unanchored, steered by AlignPosition /
-- AlignOrientation so standing players ride along. fn(t) returns a CFrame.
local function mover(part, fn)
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

--------------------------------------------------------------------------------
-- Collectibles
--------------------------------------------------------------------------------

local function carrotModel(pos, golden)
	local model = Instance.new("Model")
	model.Name = golden and "GoldenCarrot" or "Carrot"
	local body = golden and P.Gold or P.Carrot
	local dark = golden and P.GoldDark or P.CarrotDark
	local leaf = golden and P.Cream or P.CarrotLeaf
	local s = golden and 1.8 or 1
	local function piece(offset, size, color, isBall)
		local p = make("Part", {
			Size = size * s,
			CFrame = CFrame.new(pos + offset * s),
			Color = color,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = true,
		}, model)
		if isBall then
			local m = Instance.new("SpecialMesh")
			m.MeshType = Enum.MeshType.Sphere
			m.Parent = p
		end
		return p
	end
	-- Stacked tapering body
	local root = piece(Vector3.new(0, 0.5, 0), Vector3.new(1.4, 1.2, 1.4), body)
	piece(Vector3.new(0, -0.5, 0), Vector3.new(1.05, 1, 1.05), dark)
	piece(Vector3.new(0, -1.3, 0), Vector3.new(0.7, 0.8, 0.7), body)
	piece(Vector3.new(0, -1.9, 0), Vector3.new(0.35, 0.5, 0.35), dark)
	for i = -1, 1 do
		local l = piece(Vector3.new(i * 0.25, 1.75, 0), Vector3.new(0.22, 1.5, 0.45), leaf)
		l.CFrame = CFrame.new(pos + Vector3.new(i * 0.3, 1.75, 0) * s) * CFrame.Angles(0, i * 0.6, -i * 0.35)
	end
	model.PrimaryPart = root
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	if golden then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 214, 140)
		light.Range = 14
		light.Brightness = 1.2
		light.Parent = root
		-- A faint shaft of light so golden carrots can be spotted from afar
		make("Part", {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(160, 3, 3),
			CFrame = CFrame.new(pos + Vector3.new(0, 82, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(230, 206, 140),
			Transparency = 0.82,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		}, model).Name = "Beam"
	end
	model.Parent = collectFolder
	return model
end

local function carrot(pos)
	local id = string.format("c_%d_%d_%d", math.round(pos.X), math.round(pos.Y), math.round(pos.Z))
	if info.carrots[id] then
		return
	end
	info.carrots[id] = pos
	local m = carrotModel(pos, false)
	m:SetAttribute("CollectId", id)
	m:SetAttribute("Kind", "carrot")
end

local function golden(id, pos)
	info.goldens[id] = pos
	local m = carrotModel(pos, true)
	m:SetAttribute("CollectId", id)
	m:SetAttribute("Kind", "golden")
end

--------------------------------------------------------------------------------
-- Decoration
--------------------------------------------------------------------------------

local rng = Random.new(6464)

local function roundTree(x, y, z, s)
	cyl(x, y - 1, z, 0.9 * s, 9 * s, P.Wood, Enum.Material.Wood)
	blob(Vector3.new(x, y + 10 * s, z), Vector3.new(9, 7, 9) * s, P.Leaf)
	blob(Vector3.new(x + 2 * s, y + 8.5 * s, z + 1 * s), Vector3.new(6, 5, 6) * s, P.LeafDark)
	blob(Vector3.new(x - 1.5 * s, y + 13 * s, z - 0.5 * s), Vector3.new(5.5, 4.5, 5.5) * s, P.Leaf)
end

local function pineTree(x, y, z, s)
	cyl(x, y - 1, z, 0.7 * s, 5 * s, P.Wood, Enum.Material.Wood)
	-- stepped "cone" of cylinders, decorative except the trunk
	cyl(x, y + 3 * s, z, 4.2 * s, 3 * s, P.Pine, nil, decor)
	cyl(x, y + 6 * s, z, 3.2 * s, 3 * s, P.Pine, nil, decor)
	cyl(x, y + 9 * s, z, 2.1 * s, 3 * s, P.Pine, nil, decor)
	cyl(x, y + 12 * s, z, 1 * s, 2.5 * s, P.Pine, nil, decor)
end

local function rock(x, y, z, s)
	make("Part", {
		Size = Vector3.new(4, 3, 3.5) * s,
		CFrame = CFrame.new(x, y + 1 * s, z) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4)),
		Color = rng:NextNumber() < 0.5 and P.Stone or P.StoneDark,
		Material = Enum.Material.Slate,
	})
end

local function flower(x, y, z)
	local colors = { Color3.fromRGB(196, 170, 96), Color3.fromRGB(176, 120, 132), Color3.fromRGB(214, 206, 186), Color3.fromRGB(140, 120, 160) }
	make("Part", {
		Size = Vector3.new(0.25, 1.2, 0.25),
		CFrame = CFrame.new(x, y + 0.6, z),
		Color = P.CarrotLeaf,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	}, decor)
	blob(Vector3.new(x, y + 1.3, z), Vector3.new(0.9, 0.5, 0.9), colors[rng:NextInteger(1, #colors)])
end

local function fence(from, to)
	local dir = to - from
	local n = math.max(1, math.floor(dir.Magnitude / 6))
	for i = 0, n do
		local p = from + dir * (i / n)
		block(CFrame.new(p.X, 1.6, p.Z), Vector3.new(0.7, 3.2, 0.7), P.Wood, Enum.Material.Wood)
	end
	for _, h in ipairs({ 1.2, 2.5 }) do
		local a = Vector3.new(from.X, h, from.Z)
		local b = Vector3.new(to.X, h, to.Z)
		make("Part", {
			Size = Vector3.new(0.35, 0.45, (b - a).Magnitude),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = P.WoodLight,
			Material = Enum.Material.Wood,
		})
	end
end

local function sign(pos, facing, title, subtitle)
	block(CFrame.new(pos + Vector3.new(0, 2.5, 0)), Vector3.new(0.8, 5, 0.8), P.Wood, Enum.Material.Wood)
	local board = block(
		CFrame.lookAt(pos + Vector3.new(0, 5, 0), pos + Vector3.new(0, 5, 0) + facing) * CFrame.new(0, 0, -0.5),
		Vector3.new(9, 3.6, 0.5),
		P.WoodLight,
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
		t.TextColor3 = Color3.fromRGB(50, 34, 24)
		t.Parent = gui
	end
	label(title, 0.08, 0.5, 64)
	label(subtitle, 0.55, 0.35, 36)
end

--------------------------------------------------------------------------------
-- Areas
--------------------------------------------------------------------------------

local function buildIsland()
	-- Sea
	for _, off in ipairs({ Vector3.new(-1000, 0, -1000), Vector3.new(1000, 0, -1000), Vector3.new(-1000, 0, 1000), Vector3.new(1000, 0, 1000) }) do
		local w = make("Part", {
			Name = "Water",
			Size = Vector3.new(2000, 1, 2000),
			CFrame = CFrame.new(off.X, WATER - 0.5, off.Z),
			Color = P.Water,
			Transparency = 0.15,
			Reflectance = 0.05,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		}, decor)
		w.Material = Enum.Material.Glass
	end
	-- Sea floor so the water looks deep
	block(CFrame.new(0, WATER - 40, 0), Vector3.new(2048, 2, 2048), Color3.fromRGB(40, 66, 70), nil, decor)

	-- Beach ring and main island
	cyl(0, -30, 0, 246, 27, P.Sand)
	mound(0, 0, 230, 0, P.Grass, -30)
	-- Irregular shoreline bulges
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local r = rng:NextNumber(205, 225)
		local rad = rng:NextNumber(26, 40)
		cyl(math.cos(a) * r, -30, math.sin(a) * r, rad + 14, 27, P.Sand)
		mound(math.cos(a) * r, math.sin(a) * r, rad, 0, P.Grass, -30)
	end
	-- Gentle rises across the meadow
	for _ = 1, 9 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(40, 180)
		local x, z = math.cos(a) * r, math.sin(a) * r
		if (Vector3.new(x, 0, z) - Vector3.new(-130, 0, -120)).Magnitude > 70 and (Vector3.new(x, 0, z) - Vector3.new(140, 0, -90)).Magnitude > 80 then
			mound(x, z, rng:NextNumber(14, 24), rng:NextNumber(1.5, 3), P.GrassLight, -2)
		end
	end
end

local function buildSpawn()
	local spawnPos = Vector3.new(0, 0, 60)
	local sp = make("SpawnLocation", {
		Size = Vector3.new(10, 1, 10),
		CFrame = CFrame.new(spawnPos + Vector3.new(0, 0.3, 0)),
		Color = P.Stone,
		Material = Enum.Material.Slate,
		Neutral = true,
		Duration = 0,
		CanCollide = true,
	})
	sp.Name = "BunnySpawn"
	info.spawn = sp.CFrame + Vector3.new(0, 4, 0)

	sign(Vector3.new(12, 0, 40), Vector3.new(-0.5, 0, 0.85).Unit, "CARROT MEADOW", "Find the 7 golden carrots")

	-- carrot ring
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		carrot(spawnPos + Vector3.new(math.cos(a) * 22, 3, math.sin(a) * 22))
	end
	-- fence corner
	fence(Vector3.new(-30, 0, 90), Vector3.new(-10, 0, 98))
	fence(Vector3.new(-10, 0, 98), Vector3.new(12, 0, 98))
	fence(Vector3.new(12, 0, 98), Vector3.new(30, 0, 90))

	-- paths from spawn
	path(spawnPos, Vector3.new(-60, 0, -28), 7)
	path(spawnPos, Vector3.new(-105, 0, -95), 7)
	path(spawnPos, Vector3.new(100, 0, 120), 7)
	path(spawnPos, Vector3.new(100, 0, -55), 7)
	path(spawnPos, Vector3.new(-225, 0, 40), 7)
end

local function buildCottage()
	local x, z = -60, -40
	local wallTop = 12
	block(CFrame.new(x, wallTop / 2, z), Vector3.new(22, wallTop, 16), P.Plaster)
	-- timber frame
	for _, dx in ipairs({ -10.6, 10.6 }) do
		for _, dz in ipairs({ -7.6, 7.6 }) do
			block(CFrame.new(x + dx, wallTop / 2, z + dz), Vector3.new(1.2, wallTop, 1.2), P.Wood, Enum.Material.Wood)
		end
	end
	block(CFrame.new(x, wallTop - 0.5, z), Vector3.new(22.4, 1, 16.4), P.Wood, Enum.Material.Wood)
	-- door and windows on the +Z side (facing the spawn)
	block(CFrame.new(x, 3.5, z + 8.05), Vector3.new(4, 7, 0.3), P.Wood, Enum.Material.Wood)
	for _, dx in ipairs({ -6, 6 }) do
		block(CFrame.new(x + dx, 6.5, z + 8.05), Vector3.new(3.4, 3, 0.3), Color3.fromRGB(70, 82, 86), Enum.Material.Glass)
	end
	-- gable roof (two wedges meeting at the ridge)
	wedge(CFrame.new(x, wallTop + 3.5, z - 4.5), Vector3.new(25, 7, 9), P.Roof, Enum.Material.Slate)
	wedge(CFrame.new(x, wallTop + 3.5, z + 4.5) * CFrame.Angles(0, math.pi, 0), Vector3.new(25, 7, 9), P.Roof, Enum.Material.Slate)
	block(CFrame.new(x + 6, wallTop + 7, z - 2), Vector3.new(2.6, 6, 2.6), P.StoneDark, Enum.Material.Brick)
	-- crates to climb
	block(CFrame.new(x - 6, 3, z + 13), Vector3.new(6, 6, 6), P.WoodLight, Enum.Material.WoodPlanks)
	block(CFrame.new(x + 2, 6, z + 13), Vector3.new(6, 12, 6), P.WoodLight, Enum.Material.WoodPlanks)
	carrot(Vector3.new(x - 6, 9, z + 13))
	carrot(Vector3.new(x + 2, 15, z + 13))
	golden("burrow", Vector3.new(x - 4, wallTop + 11, z))
	for i = 0, 3 do
		carrot(Vector3.new(x - 15 + i * 10, 3, z + 22))
	end
	-- garden
	for i = 0, 4 do
		block(CFrame.new(x - 18, 0.4, z - 6 + i * 4), Vector3.new(6, 0.8, 2.4), P.DirtDark)
		blob(Vector3.new(x - 18, 1.2, z - 6 + i * 4), Vector3.new(1.4, 1, 1.4), P.CarrotLeaf)
	end
end

local function buildTower()
	local cx, cz = -130, -120
	terrace(cx, cz, { { 50, 7 }, { 38, 14, P.GrassLight }, { 28, 21 } })
	cyl(cx, 21, cz, 10, 82, P.Stone, Enum.Material.Slate)
	for y = 35, 95, 15 do
		cyl(cx, y, cz, 10.7, 1.4, P.StoneDark, Enum.Material.Slate)
	end
	cyl(cx, 103, cz, 14, 3, P.StoneDark, Enum.Material.Slate)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		block(CFrame.new(cx + math.cos(a) * 13, 107.5, cz + math.sin(a) * 13) * CFrame.Angles(0, -a, 0), Vector3.new(2.5, 3, 2.5), P.Stone, Enum.Material.Slate)
	end
	block(CFrame.new(cx + 4, 112, cz), Vector3.new(0.6, 12, 0.6), P.Wood, Enum.Material.Wood)
	block(CFrame.new(cx + 6.5, 116, cz), Vector3.new(4.5, 3, 0.2), P.Bow, Enum.Material.Fabric)
	golden("tower", Vector3.new(cx - 3, 111, cz))

	for i = 0, 12 do
		local a = i * 0.62 + 0.3
		local x, z = cx + math.cos(a) * 18, cz + math.sin(a) * 18
		local top = 27 + i * 6.5
		local step = cyl(x, top - 2, z, 5, 2, i % 2 == 0 and P.WoodLight or P.Stone, i % 2 == 0 and Enum.Material.WoodPlanks or Enum.Material.Slate)
		if i == 4 or i == 9 then
			local baseCF = step.CFrame
			mover(step, function(t)
				return baseCF + Vector3.new(0, math.sin(t * 1.4 + i) * 2.5, 0)
			end)
		end
		if i % 2 == 0 then
			carrot(Vector3.new(x, top + 3.5, z))
		end
	end
end

local function buildOak()
	local cx, cz = 110, 140
	local canopyTop = 93
	cyl(cx, -1, cz, 8, canopyTop - 2, P.Wood, Enum.Material.Wood)
	-- roots
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + 0.4
		block(CFrame.new(cx + math.cos(a) * 9, 1.5, cz + math.sin(a) * 9) * CFrame.Angles(0, -a, 0.5), Vector3.new(8, 3, 3), P.Wood, Enum.Material.Wood)
	end
	cyl(cx, canopyTop - 3, cz, 16, 3, P.LeafDark, Enum.Material.Grass)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		blob(Vector3.new(cx + math.cos(a) * 15, canopyTop + 1, cz + math.sin(a) * 15), Vector3.new(12, 7, 12), i % 2 == 0 and P.Leaf or P.LeafDark)
		blob(Vector3.new(cx + math.cos(a) * 12, canopyTop - 5, cz + math.sin(a) * 12), Vector3.new(14, 8, 14), i % 2 == 0 and P.LeafDark or P.Leaf)
	end
	golden("oak", Vector3.new(cx, canopyTop + 5, cz))

	for i = 0, 10 do
		local a = i * 0.6
		local top = 7 + i * 7.5
		local x, z = cx + math.cos(a) * 20, cz + math.sin(a) * 20
		cyl(x, top - 1.5, z, 5, 1.5, P.Leaf, Enum.Material.Grass)
		-- branch from trunk to pad
		local mid = Vector3.new(cx + math.cos(a) * 12, top - 2, cz + math.sin(a) * 12)
		make("Part", {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(14, 1.6, 1.6),
			CFrame = CFrame.new(mid) * CFrame.Angles(0, -a, 0),
			Color = P.Wood,
			Material = Enum.Material.Wood,
		})
		if i % 2 == 1 then
			carrot(Vector3.new(x, top + 3.5, z))
		end
	end
end

local function buildSkyGarden()
	local hx, hz = 140, -90
	terrace(hx, hz, { { 60, 7 }, { 45, 14, P.GrassLight }, { 32, 21 }, { 20, 28, P.GrassLight } })
	-- carrots up the terraces
	for i, r in ipairs({ 54, 41, 27 }) do
		carrot(Vector3.new(hx - r, 7 * i + 3, hz + 8))
		carrot(Vector3.new(hx - r + 2, 7 * i + 3, hz - 8))
	end

	-- Bouncy mushroom
	cyl(hx, 28, hz, 2.6, 4, P.MushroomStem)
	local cap = blob(Vector3.new(hx, 32.5, hz), Vector3.new(13, 5, 13), P.Mushroom, nil, world, true)
	cap:SetAttribute("Bounce", Config.MushroomBounce)
	cap.Name = "BounceMushroom"
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		blob(Vector3.new(hx + math.cos(a) * 3.8, 34.4, hz + math.sin(a) * 3.8), Vector3.new(1.8, 0.6, 1.8), P.MushroomStem)
	end

	local function skyIsland(x, top, z, r)
		cyl(x, top - 3, z, r, 3, P.Dirt)
		cyl(x, top - 1, z, r + 0.4, 1, P.Grass)
		cyl(x, top - 6, z, r * 0.75, 3, P.DirtDark, nil, decor)
		cyl(x, top - 9, z, r * 0.45, 3, P.DirtDark, nil, decor)
		cyl(x, top - 11, z, r * 0.2, 2, P.DirtDark, nil, decor)
	end

	skyIsland(125, 95, -62, 12)
	carrot(Vector3.new(125, 98.5, -62))

	local slider = block(CFrame.new(100, 96, -40), Vector3.new(14, 2, 14), P.WoodLight, Enum.Material.WoodPlanks)
	mover(slider, function(t)
		return CFrame.new(86 + math.sin(t * 0.7) * 14, 96, -40)
	end)

	skyIsland(45, 99, -25, 11)
	carrot(Vector3.new(45, 102.5, -25))

	local disc = cyl(15, 99, 0, 13, 2, P.Plaster)
	for i = 0, 3 do
		local stripe = make("Part", {
			Size = Vector3.new(26.2, 2.1, 2.4),
			CFrame = CFrame.new(15, 100, 0) * CFrame.Angles(0, i * math.pi / 4, 0),
			Color = P.Roof,
			Anchored = false,
			Massless = true,
		})
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = disc
		weld.Part1 = stripe
		weld.Parent = stripe
	end
	local discBase = disc.CFrame
	mover(disc, function(t)
		return CFrame.new(discBase.Position) * CFrame.Angles(0, t * 0.6, 0) * (discBase - discBase.Position)
	end)
	carrot(Vector3.new(15, 104.5, 0))

	skyIsland(-15, 104, 25, 15)
	golden("sky", Vector3.new(-15, 109, 25))
	for i = 0, 5 do
		local a = i * 1.1
		flower(-15 + math.cos(a) * 9, 104, 25 + math.sin(a) * 9)
	end
end

local function buildIslet()
	local ix, iz = -330, 40
	cyl(ix, -30, iz, 37, 27, P.Sand)
	mound(ix, iz, 32, 2, P.Grass, -30)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		cyl(ix + math.cos(a) * 9, 2, iz + math.sin(a) * 9, 1.4, 11, P.Plaster)
	end
	block(CFrame.new(ix, 13.5, iz), Vector3.new(18, 1.5, 18), P.Roof, Enum.Material.Slate)
	cyl(ix, 2, iz, 3, 3, P.Stone, Enum.Material.Slate)
	golden("islet", Vector3.new(ix, 8.5, iz))
	pineTree(ix + 18, 2, iz - 14, 1)
	pineTree(ix - 16, 2, iz + 17, 0.9)
	carrot(Vector3.new(ix + 14, 5, iz + 12))
	carrot(Vector3.new(ix - 14, 5, iz - 10))
	table.insert(info.bugs, Vector3.new(ix + 16, 2, iz + 2))

	-- Stepping stones (two sink below the waves, one drifts sideways)
	local xs = { -253, -265, -277, -289 }
	for i, x in ipairs(xs) do
		local z = iz + math.sin(i * 1.7) * 5
		local stone = cyl(x, WATER - 6, z, 4, 9, P.Stone, Enum.Material.Slate)
		local base = stone.CFrame
		if i == 2 or i == 4 then
			mover(stone, function(t)
				return base + Vector3.new(0, math.sin(t * 1.1 + i) * 4 - 1.5, 0)
			end)
		elseif i == 3 then
			mover(stone, function(t)
				return base + Vector3.new(0, 0, math.sin(t * 0.9) * 10)
			end)
		end
		carrot(Vector3.new(x, 1, z))
	end
end

local function scatter()
	local avoid = {
		{ Vector3.new(0, 0, 60), 30 },
		{ Vector3.new(-60, 0, -40), 26 },
		{ Vector3.new(-130, 0, -120), 56 },
		{ Vector3.new(110, 0, 140), 28 },
		{ Vector3.new(140, 0, -90), 64 },
		{ Vector3.new(12, 0, 40), 8 },
	}
	local function ok(p, extra)
		if p.Magnitude > 205 then
			return false
		end
		for _, a in ipairs(avoid) do
			if (p - a[1]).Magnitude < a[2] + extra then
				return false
			end
		end
		return true
	end
	local placed = 0
	for _ = 1, 600 do
		if placed >= 70 then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(35, 205)
		local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if ok(p, 6) then
			local s = rng:NextNumber(0.8, 1.4)
			if rng:NextNumber() < 0.45 then
				pineTree(p.X, 0, p.Z, s)
			else
				roundTree(p.X, 0, p.Z, s)
			end
			table.insert(avoid, { p, 8 })
			placed += 1
		end
	end
	placed = 0
	for _ = 1, 300 do
		if placed >= 30 then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(30, 205)
		local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if ok(p, 2) then
			rock(p.X, 0, p.Z, rng:NextNumber(0.8, 2.2))
			table.insert(avoid, { p, 5 })
			placed += 1
		end
	end
	placed = 0
	for _ = 1, 600 do
		if placed >= 24 then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(35, 190)
		local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if ok(p, 3) then
			carrot(p + Vector3.new(0, 3, 0))
			table.insert(avoid, { p, 10 })
			placed += 1
		end
	end
	for _ = 1, 220 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(10, 210)
		local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if ok(p, 0) then
			flower(p.X, 0, p.Z)
		end
	end
end

local function buildBugHomes()
	local homes = {
		Vector3.new(40, 0, 25), Vector3.new(-40, 0, 10), Vector3.new(60, 0, -30),
		Vector3.new(-20, 0, 120), Vector3.new(70, 0, 80), Vector3.new(-100, 0, -30),
		Vector3.new(-150, 7, -70), Vector3.new(185, 7, -70), Vector3.new(45, 0, 160),
		Vector3.new(-70, 0, 130), Vector3.new(120, 0, 30), Vector3.new(-180, 0, 60),
	}
	for _, h in ipairs(homes) do
		table.insert(info.bugs, h)
	end
end

--------------------------------------------------------------------------------

local function setupLighting()
	local Lighting = game:GetService("Lighting")
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Atmosphere") or child:IsA("Sky") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end
	Lighting.ClockTime = 16.3
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(96, 90, 84)
	Lighting.OutdoorAmbient = Color3.fromRGB(132, 124, 112)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 232, 196)
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 0.2
	Lighting.EnvironmentSpecularScale = 0
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.6
	-- Classic distance fog
	Lighting.FogColor = Color3.fromRGB(176, 182, 172)
	Lighting.FogStart = 140
	Lighting.FogEnd = 720

	local sky = Instance.new("Sky")
	sky.CelestialBodiesShown = true
	sky.SunAngularSize = 14
	sky.StarCount = 0
	sky.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = -0.18
	cc.Contrast = 0.06
	cc.Brightness = -0.02
	cc.TintColor = Color3.fromRGB(255, 244, 228)
	cc.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.15
	bloom.Size = 20
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
end

function WorldBuilder.Build()
	local old = workspace:FindFirstChild("Baseplate")
	if old then
		old:Destroy()
	end
	workspace.Gravity = Config.Gravity

	local root = Instance.new("Folder")
	root.Name = "Bunny64World"
	world = Instance.new("Folder")
	world.Name = "Solid"
	world.Parent = root
	decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = root
	collectFolder = Instance.new("Folder")
	collectFolder.Name = "Collectibles"
	collectFolder.Parent = root

	setupLighting()
	buildIsland()
	buildSpawn()
	buildCottage()
	buildTower()
	buildOak()
	buildSkyGarden()
	buildIslet()
	buildBugHomes()
	scatter()

	-- Reward goldens appear near the start (only visible once earned)
	golden("collector", Vector3.new(-14, 4, 72))
	golden("buster", Vector3.new(14, 4, 72))

	root.Parent = workspace

	-- Movers need to be in the workspace before they can be server-owned
	for _, m in ipairs(movers) do
		pcall(function()
			m.part:SetNetworkOwner(nil)
		end)
	end
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, m in ipairs(movers) do
			local cf = m.fn(t)
			m.ap.Position = cf.Position
			m.ao.CFrame = cf
		end
	end)

	info.solidFolder = world
	info.collectFolder = collectFolder
	return info
end

return WorldBuilder
