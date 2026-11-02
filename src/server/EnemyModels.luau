--[[
	EnemyModels - builds the non-beetle baddies. Each builder returns
	(model, extras) with the model's PrimaryPart at the enemy's centre;
	front is -Z. Everything is anchored and non-colliding (the server moves
	them and does its own contact checks).

	  toad        Hopscotch Toad    hops after you in big arcs       stomp it
	  bat         Flitbat           circles, then swoops at you      stomp / roll into it
	  thornhog    Thornhog          rolls back and forth, all spikes ground pound it
	  puffshroom  Puffshroom        puffs a ring of spores           stomp it between puffs
]]

local EnemyModels = {}

local SMOOTH = Enum.Material.SmoothPlastic
local rgb = Color3.fromRGB
local CF, V, R = CFrame.new, Vector3.new, CFrame.Angles

local SKINS = {
	toad = {
		meadow = { body = rgb(96, 128, 70), belly = rgb(214, 204, 160), spot = rgb(70, 96, 52), eye = rgb(214, 180, 70) },
		canyon = { body = rgb(170, 130, 82), belly = rgb(226, 206, 166), spot = rgb(132, 96, 60), eye = rgb(226, 160, 60) },
		peaks = { body = rgb(120, 140, 156), belly = rgb(226, 230, 232), spot = rgb(92, 108, 124), eye = rgb(150, 210, 230) },
	},
	bat = {
		castle = { body = rgb(62, 44, 54), wing = rgb(92, 56, 66), eye = rgb(240, 120, 50) },
		peaks = { body = rgb(86, 100, 120), wing = rgb(120, 140, 160), eye = rgb(160, 220, 240) },
		meadow = { body = rgb(70, 56, 66), wing = rgb(104, 80, 92), eye = rgb(230, 200, 90) },
	},
	thornhog = {
		canyon = { body = rgb(112, 84, 60), spike = rgb(226, 214, 186), face = rgb(196, 160, 120), tip = rgb(226, 214, 186) },
		castle = { body = rgb(48, 40, 40), spike = rgb(80, 70, 70), face = rgb(120, 96, 86), tip = rgb(232, 120, 50) },
		meadow = { body = rgb(100, 84, 70), spike = rgb(214, 204, 180), face = rgb(190, 160, 128), tip = rgb(214, 204, 180) },
	},
	puffshroom = {
		meadow = { cap = rgb(120, 82, 132), spot = rgb(222, 210, 190), stem = rgb(220, 208, 182) },
		peaks = { cap = rgb(90, 120, 150), spot = rgb(232, 236, 240), stem = rgb(220, 224, 228) },
		castle = { cap = rgb(150, 56, 46), spot = rgb(240, 170, 90), stem = rgb(170, 150, 136) },
		canyon = { cap = rgb(176, 120, 70), spot = rgb(232, 214, 170), stem = rgb(214, 196, 160) },
	},
}

local function skinFor(kind, name)
	local set = SKINS[kind]
	return set[name] or set[next(set)]
end

local function newPart(model, origin, cf, size, color, ball, material, name)
	local p = Instance.new("Part")
	p.Name = name or "Part"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = origin * cf
	p.Color = color
	p.Material = material or SMOOTH
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if ball then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	end
	p.Parent = model
	return p
end

local function rootPart(model, origin, size)
	local r = newPart(model, origin, CF(), size, Color3.new(), false, nil, "Root")
	r.Transparency = 1
	model.PrimaryPart = r
	return r
end

local function eyes(model, origin, y, z, spread, size, glint, angry, browColor)
	for _, sx in ipairs({ -1, 1 }) do
		newPart(model, origin, CF(sx * spread, y, z), V(size, size * 1.1, size * 0.7), rgb(236, 230, 214), true)
		local pupil = newPart(model, origin, CF(sx * spread * 0.95, y - size * 0.05, z - size * 0.3), V(size * 0.5, size * 0.6, size * 0.3), rgb(24, 20, 22), true)
		pupil.Reflectance = 0.2
		if glint then
			newPart(model, origin, CF(sx * spread * 0.9, y + size * 0.12, z - size * 0.42), V(size * 0.16, size * 0.16, size * 0.08), glint, true, Enum.Material.Neon)
		end
		if angry then
			newPart(model, origin, CF(sx * spread, y + size * 0.62, z - size * 0.2) * R(0, 0, sx * 0.4), V(size * 1.1, size * 0.22, size * 0.3), browColor or rgb(30, 24, 24))
		end
	end
end

-- Hopscotch Toad --------------------------------------------------------------------
function EnemyModels.toad(skinName, origin)
	local s = skinFor("toad", skinName)
	local model = Instance.new("Model")
	model.Name = "HopscotchToad"
	rootPart(model, origin, V(4, 3, 4))
	newPart(model, origin, CF(0, -0.1, 0.2), V(4.2, 2.6, 4.6), s.body, true, nil, "Body")
	newPart(model, origin, CF(0, -0.55, -0.7), V(3.2, 1.6, 2.6), s.belly, true)
	for _, sp in ipairs({ { -0.9, 1.0, 0.8 }, { 1.0, 0.95, 1.4 }, { 0.2, 1.1, 0.2 } }) do
		newPart(model, origin, CF(sp[1], sp[2], sp[3]), V(0.9, 0.3, 0.9), s.spot, true)
	end
	-- bulging eyes on top
	for _, sx in ipairs({ -1, 1 }) do
		newPart(model, origin, CF(sx * 1.05, 1.15, -1.3), V(1.3, 1.3, 1.3), s.body, true)
	end
	eyes(model, origin, 1.35, -1.75, 1.05, 0.95, s.eye, false)
	newPart(model, origin, CF(0, -0.25, -2.25) * R(0, 0, 0), V(2.6, 0.12, 0.2), rgb(40, 30, 30))
	-- folded back legs and little front feet
	local legs = {}
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(legs, newPart(model, origin, CF(sx * 2.05, -0.6, 1.3), V(1.4, 1.6, 2.6), s.body, true, nil, "BackLeg"))
		newPart(model, origin, CF(sx * 2.3, -1.3, 0.2), V(1.3, 0.4, 2.0), s.belly, true)
		newPart(model, origin, CF(sx * 1.3, -1.3, -1.8), V(0.8, 0.35, 1.0), s.belly, true)
	end
	model:SetAttribute("Kind", "toad")
	return model, { legs = legs }
end

-- Flitbat ---------------------------------------------------------------------------------
function EnemyModels.bat(skinName, origin)
	local s = skinFor("bat", skinName)
	local model = Instance.new("Model")
	model.Name = "Flitbat"
	rootPart(model, origin, V(2, 2, 2))
	newPart(model, origin, CF(0, 0, 0), V(2.2, 2.4, 2.0), s.body, true, nil, "Body")
	newPart(model, origin, CF(0, -0.3, -0.75), V(1.3, 1.0, 0.6), s.wing, true)
	for _, sx in ipairs({ -1, 1 }) do
		newPart(model, origin, CF(sx * 0.6, 1.45, 0) * R(0, 0, sx * -0.3), V(0.5, 1.2, 0.3), s.body)
	end
	eyes(model, origin, 0.35, -0.85, 0.42, 0.5, s.eye, true)
	for _, sx in ipairs({ -1, 1 }) do
		newPart(model, origin, CF(sx * 0.2, -0.55, -0.95), V(0.14, 0.3, 0.1), rgb(236, 230, 214))
	end
	local wings = {}
	for _, sx in ipairs({ -1, 1 }) do
		local offset = CF(sx * 1.0, 0.3, 0.1)
		local wing = newPart(model, origin, offset * CF(sx * 1.9, 0, 0), V(3.8, 0.18, 2.2), s.wing, false, nil, "Wing")
		local tip = newPart(model, origin, offset * CF(sx * 3.4, -0.1, 0.6) * R(0, sx * 0.4, 0), V(1.6, 0.16, 1.4), s.wing, false, nil, "WingTip")
		table.insert(wings, { part = wing, offset = offset, local1 = CF(sx * 1.9, 0, 0), side = sx, tip = tip, local2 = CF(sx * 3.4, -0.1, 0.6) * R(0, sx * 0.4, 0) })
	end
	model:SetAttribute("Kind", "bat")
	return model, { wings = wings }
end

-- Thornhog ---------------------------------------------------------------------------------
function EnemyModels.thornhog(skinName, origin)
	local s = skinFor("thornhog", skinName)
	local model = Instance.new("Model")
	model.Name = "Thornhog"
	rootPart(model, origin, V(4, 4, 4))
	newPart(model, origin, CF(), V(4.4, 4.0, 4.6), s.body, true, nil, "Body")
	-- spikes all over the back
	local n = 0
	for ring = 0, 3 do
		local pitch = -0.2 + ring * 0.55
		local count = 7 - math.abs(ring - 1)
		for i = 0, count - 1 do
			local yaw = i / count * math.pi * 2 + ring * 0.3
			local dir = (CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)).LookVector
			if dir.Z > -0.55 or dir.Y > 0.35 then
				local base = dir * 1.9
				local cf = CFrame.lookAt(base, base + dir) * CF(0, 0, -0.9)
				newPart(model, origin, cf, V(0.35, 0.35, 1.9), s.spike)
				newPart(model, origin, cf * CF(0, 0, -1.0), V(0.2, 0.2, 0.5), s.tip, false, s.tip == rgb(232, 120, 50) and Enum.Material.Neon or SMOOTH)
				n += 1
			end
		end
	end
	newPart(model, origin, CF(0, -0.4, -2.0), V(2.4, 2.0, 1.6), s.face, true)
	newPart(model, origin, CF(0, -0.55, -2.85), V(0.6, 0.5, 0.5), rgb(30, 24, 24), true)
	eyes(model, origin, 0.15, -2.45, 0.6, 0.48, nil, true)
	model:SetAttribute("Kind", "thornhog")
	return model, {}
end

-- Puffshroom -------------------------------------------------------------------------------
function EnemyModels.puffshroom(skinName, origin)
	local s = skinFor("puffshroom", skinName)
	local model = Instance.new("Model")
	model.Name = "Puffshroom"
	rootPart(model, origin, V(3, 3, 3))
	local stem = newPart(model, origin, CF(0, -0.4, 0), V(2.6, 3.2, 2.6), s.stem, true, nil, "Stem")
	local cap = newPart(model, origin, CF(0, 1.6, 0), V(6.2, 3.0, 6.2), s.cap, true, nil, "Cap")
	local spots = {}
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		table.insert(spots, newPart(model, origin, CF(math.cos(a) * 2.1, 2.45, math.sin(a) * 2.1), V(1.0, 0.4, 1.0), s.spot, true))
	end
	newPart(model, origin, CF(0, 3.05, 0), V(1.2, 0.4, 1.2), s.spot, true)
	eyes(model, origin, 0.0, -1.1, 0.5, 0.55, nil, true)
	newPart(model, origin, CF(0, -0.75, -1.25), V(0.7, 0.18, 0.1), rgb(40, 30, 30))
	model:SetAttribute("Kind", "puffshroom")
	return model, { cap = cap, stem = stem, spots = spots }
end

return EnemyModels
