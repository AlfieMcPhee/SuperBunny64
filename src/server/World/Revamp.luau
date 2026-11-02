--[[
	Revamp - new landscape and traversal circuits layered onto the four
	original lands, so getting around is half the fun.

	  Carrot Meadow   Willow Falls (a cliff to climb, a waterfall and a secret
	                  grotto behind it), the Windmill and its mill-wheel ride,
	                  the Slide on the big hill, ziplines from the Lookout Tower
	                  and the Old Oak, spring pads, Carrot Henge, a shipwreck and
	                  the Old Stone Bunny
	  Frostbite Peaks the Chairlift up the mountain, a zipline from the summit,
	                  a healing hot spring
	  Dustbowl Canyon Geyser Gulch (steam vents fling you up the pillars), a
	                  zipline off Eagle's Mesa, a giant fossil
	  Infernal Castle the Magma Wheel over a lava lake, the King's toppled statue

	Traversal toys (B.zipline, B.springPad, B.wheel, B.slideRun) live in Builder
	and are ridden by client/Movement.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local BunnyModel = require(Shared:WaitForChild("BunnyModel"))

local Revamp = {}

local V = Vector3.new
local M = Enum.Material

-- A velocity that throws you from `from` to land on `to` (with the game's
-- heavier falling), peaking `extra` studs above the higher of the two
local function throwTo(from, to, extra)
	local g = Config.Gravity
	local gFall = g * Config.FallGravityMult
	local apex = math.max(from.Y, to.Y) + (extra or 8)
	local up = apex - from.Y
	local down = apex - to.Y
	local vy = math.sqrt(2 * g * up)
	local t = vy / g + math.sqrt(2 * down / gFall)
	local flat = V(to.X - from.X, 0, to.Z - from.Z)
	return flat / t + V(0, vy, 0)
end
Revamp.throwTo = throwTo

local function steam(part, rate)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = rate or 8
	e.Lifetime = NumberRange.new(1.5, 2.5)
	e.Speed = NumberRange.new(4, 8)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(Color3.fromRGB(240, 240, 236))
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = part
	return e
end

--------------------------------------------------------------------------------
-- Carrot Meadow
--------------------------------------------------------------------------------

local function meadow(B)
	local P = B.P
	local T = B.Terrain
	local rng = B.rng

	----------------------------------------------------------------- Willow Falls
	do
		local fx, fz, top, r = -80, 175, 32, 24
		-- a rocky plateau with a grassy top, bulging rock at its foot
		T:FillCylinder(CFrame.new(fx, top / 2 - 2, fz), top + 4, r, M.Rock)
		T:FillCylinder(CFrame.new(fx, top - 1.5, fz), 3, r, M.LeafyGrass)
		for i = 1, 9 do -- (not on the east face: that's where the grotto opens)
			local a = i / 10 * math.pi * 2
			T:FillBall(V(fx + math.cos(a) * (r - 2), rng:NextNumber(4, 18), fz + math.sin(a) * (r - 2)), rng:NextNumber(5, 8), M.Rock)
		end
		-- the grotto: a cave behind where the waterfall pours down the east face
		T:FillBall(V(fx + 18, 7, fz), 8, M.Air)
		T:FillBlock(CFrame.new(fx + 18, -1, fz), V(16, 2, 16), M.Ground)
		-- the waterfall (walk-through) and the pool it fills
		local fallX = fx + r + 1
		local fall = B.make("Part", {
			Name = "Waterfall",
			Size = V(1.2, top + 2, 10),
			CFrame = CFrame.new(fallX, top / 2, fz),
			Color = Color3.fromRGB(150, 196, 214),
			Material = M.Glass,
			Transparency = 0.35,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		}, B.decor)
		local spray = Instance.new("ParticleEmitter")
		spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
		spray.Rate = 14
		spray.Lifetime = NumberRange.new(1, 1.6)
		spray.Speed = NumberRange.new(2, 4)
		spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
		spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		spray.Color = ColorSequence.new(Color3.fromRGB(230, 240, 245))
		spray.Parent = fall
		B.pond(fallX + 10, fz, 9, 3)
		-- the secret grotto
		B.golden("grotto", V(fx + 15, 6, fz))
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			local c = B.make("Part", {
				Size = V(1, 2.6, 1),
				CFrame = CFrame.new(fx + 17 + math.cos(a) * 5.5, 1.3, fz + math.sin(a) * 5.5) * CFrame.Angles(0.2, a, 0.15),
				Color = Color3.fromRGB(140, 200, 230),
				Material = M.Neon,
				CanCollide = false,
				CanQuery = false,
			}, B.decor)
			if i % 2 == 0 then
				local l = Instance.new("PointLight")
				l.Color = c.Color
				l.Range = 12
				l.Parent = c
			end
		end
		B.carrotRing(V(fx + 17, 3, fz), 4, 5)
		-- ledges spiralling up the south and west faces
		for i = 0, 6 do
			local a = 1.9 + i * 0.42
			local lt = 5 + i * 4.6
			local p = V(fx + math.cos(a) * (r + 3), lt - 1, fz + math.sin(a) * (r + 3))
			B.block(CFrame.new(p) * CFrame.Angles(0, -a, 0), V(7, 2, 6), P.Stone, M.Slate)
			if i % 2 == 1 then
				B.carrot(p + V(0, 4, 0))
			end
		end
		-- the willow on top
		B.cyl(fx - 6, top - 1, fz - 4, 1.8, 14, P.Wood, M.Wood)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			local leaf = B.blob(V(fx - 6 + math.cos(a) * 6, top + 9, fz - 4 + math.sin(a) * 6), V(5, 12, 5), i % 2 == 0 and P.Leaf or P.LeafDark)
			leaf.CFrame = leaf.CFrame * CFrame.Angles(0, 0, 0.1)
		end
		B.blob(V(fx - 6, top + 14, fz - 4), V(16, 6, 16), P.Leaf)
		B.golden("falls", V(fx + 4, top + 4, fz + 6))
		for i = 0, 8 do
			B.flower(fx + rng:NextNumber(-14, 14), top, fz + rng:NextNumber(-14, 14))
		end
		-- a spring pad up the west side, and a zipline down toward the spawn
		B.springPad(V(-120, 0, 160), throwTo(V(-120, 1, 160), V(-92, top, 170), 8))
		B.zipline(V(fx + 8, top + 6, fz - 16), V(-45, 7, 112))
		B.sign(V(-60, 0, 145), V(0.4, 0, -1).Unit, "WILLOW FALLS", "Climb, slide or spring")
	end

	----------------------------------------------------------------- the Windmill
	do
		local wx, wz = -185, -35
		B.cyl(wx, -1, wz, 7, 30, P.Plaster)
		B.cyl(wx, 28, wz, 8.5, 2, P.Roof, M.Slate)
		B.cyl(wx, 30, wz, 6, 4, P.Roof, M.Slate)
		B.cyl(wx, 34, wz, 8, 1.4, P.WoodLight, M.WoodPlanks) -- the lookout on top
		B.block(CFrame.new(wx + 7.1, 4, wz), V(0.4, 7, 3.6), P.Wood, M.Wood)
		-- sails turning on the north face (scenery)
		local hub = B.block(CFrame.new(wx, 24, wz - 8), V(2, 2, 2), P.Wood, M.Wood)
		hub.CanCollide = false
		for i = 0, 3 do
			local sail = B.make("Part", {
				Size = V(3.4, 13, 0.3),
				CFrame = hub.CFrame * CFrame.Angles(0, 0, i * math.pi / 2) * CFrame.new(0, 7.5, -0.5),
				Color = P.Plaster,
				Material = M.Fabric,
				CanCollide = false,
				CanQuery = false,
				Anchored = false,
				Massless = true,
			}, B.decor)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hub
			weld.Part1 = sail
			weld.Parent = sail
		end
		local hubBase = hub.CFrame
		B.mover(hub, function(t)
			return hubBase * CFrame.Angles(0, 0, t * 0.6)
		end)
		-- the mill wheel: ride a platform up to the lookout
		B.wheel(V(wx + 17, 20, wz), 16, V(0, 0, 1), 4, 0.32, V(8, 1.4, 8))
		B.golden("windmill", V(wx, 39, wz))
		B.carrotRing(V(wx, 38, wz), 5, 6)
		B.sign(V(wx + 14, 0, wz + 26), V(1, 0, 0), "THE WINDMILL", "Ride the wheel to the top")
	end

	----------------------------------------------------------------- the Slide (big hill)
	do
		local pts = { V(152, 29.5, -96), V(166, 23, -92), V(180, 16, -80), V(193, 9, -66), V(203, 3, -50), V(208, 1.5, -40) }
		B.slideRun(pts, 9, P.GrassLight, M.Grass)
		for i = 2, #pts - 1 do
			B.carrot(pts[i] + V(0, 3, 0))
		end
		B.sign(V(150, 28, -104), V(-1, 0, 0), "THE SLIDE", "Wheee!")
	end

	----------------------------------------------------------------- ziplines
	-- Lookout Tower down past the cottage, and the Old Oak down to the spawn
	B.zipline(V(-121, 110, -112), V(-82, 7, -14))
	B.zipline(V(100, 97, 133), V(48, 7, 100))

	----------------------------------------------------------------- Carrot Henge
	do
		local hx, hz = 170, 70
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			local p = V(hx + math.cos(a) * 12, 0, hz + math.sin(a) * 12)
			B.block(CFrame.new(p + V(0, 5, 0)) * CFrame.Angles(0, -a, 0), V(2.4, 10, 3.6), P.Stone, M.Slate)
			if i % 2 == 0 then
				local n = (i + 1) / 8 * math.pi * 2
				local q = V(hx + math.cos(n) * 12, 0, hz + math.sin(n) * 12)
				B.plank(p + V(0, 10.6, 0), q + V(0, 10.6, 0), 3.4, 1.4, P.StoneDark, M.Slate)
			end
		end
		B.cyl(hx, -0.4, hz, 3, 1.4, P.StoneDark, M.Slate)
		B.carrotRing(V(hx, 13.5, hz), 12, 8)
		B.sign(V(hx - 18, 0, hz), V(-1, 0, 0), "CARROT HENGE", "Nobody knows who built it")
	end

	----------------------------------------------------------------- the shipwreck
	do
		local sx, sz = 185, 140
		local hull = CFrame.new(sx, 1, sz) * CFrame.Angles(0, 0.7, 0.35)
		B.block(hull, V(9, 6, 26), P.Wood, M.WoodPlanks)
		B.block(hull * CFrame.new(0, 3.2, 0), V(8, 0.6, 24), P.WoodLight, M.WoodPlanks)
		B.block(hull * CFrame.new(0, 9, 2) * CFrame.Angles(0.15, 0, 0), V(0.9, 14, 0.9), P.Wood, M.Wood)
		B.block(hull * CFrame.new(0, 13, 2), V(7, 0.5, 0.5), P.Wood, M.Wood)
		local chest = B.block(hull * CFrame.new(0, 4.6, -6), V(3, 2.2, 2), P.WoodLight, M.Wood)
		B.block(chest.CFrame * CFrame.new(0, 1.2, 0), V(3.1, 0.4, 2.1), P.Gold, M.Metal)
		B.carrotLine(V(sx - 6, 4, sz - 6), V(sx + 6, 6, sz + 6), 4)
	end

	----------------------------------------------------------------- the Old Stone Bunny
	do
		local statue = BunnyModel.BuildPreview({ fur = 3, accent = 3, hat = "none", neck = "none" })
		statue.Name = "OldStoneBunny"
		for _, d in ipairs(statue:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = d.Transparency < 1
				d.Color = Color3.fromRGB(150, 148, 138):Lerp(Color3.fromRGB(96, 120, 70), (d.Position.Y > 4) and 0.15 or 0.35)
				d.Material = M.Slate
			end
		end
		statue:ScaleTo(4)
		local cf, size = statue:GetBoundingBox()
		local base = V(90, 0, 190)
		statue:PivotTo(statue:GetPivot() + (base - V(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z)) + V(0, 1, 0))
		statue:PivotTo(CFrame.new(statue:GetPivot().Position) * CFrame.Angles(0, math.pi * 0.85, 0))
		statue.Parent = B.solid
		B.cyl(base.X, -0.5, base.Z, 9, 1.6, P.StoneDark, M.Slate)
		B.carrot(V(base.X, size.Y + 4, base.Z))
		B.sign(V(base.X + 12, 0, base.Z - 8), V(1, 0, -0.4).Unit, "THE OLD STONE BUNNY", "Climb to the top of the ears!")
	end
end

--------------------------------------------------------------------------------
-- Frostbite Peaks
--------------------------------------------------------------------------------

local function peaks(B)
	local P = B.P
	local C = V(0, 0, -720)

	----------------------------------------------------------------- the Chairlift
	do
		local a = 3.5
		local dir = V(math.cos(a), 0, math.sin(a))
		local side = dir:Cross(V(0, 1, 0)).Unit * 5
		local low = C + dir * 172 + V(0, 8, 0)
		local high = C + dir * 70 + V(0, 68, 0)
		-- stations (the chairs stop beside them; the line stays clear of the mountain tiers)
		B.block(CFrame.new(low.X, 3, low.Z) * CFrame.Angles(0, -a, 0), V(16, 6, 18), P.WoodLight, M.WoodPlanks)
		B.block(CFrame.new(high.X, 63, high.Z) * CFrame.Angles(0, -a, 0), V(14, 6, 18), P.WoodLight, M.WoodPlanks)
		for _, p in ipairs({ low, high }) do
			for _, s in ipairs({ -1, 1 }) do
				B.block(CFrame.new(p + side * s * 1.6 + V(0, 6, 0)), V(1, 14, 1), P.StoneDark, M.Metal)
			end
		end
		-- cables (scenery)
		for _, s in ipairs({ -1, 1 }) do
			local a1, b1 = low + side * s + V(0, 8, 0), high + side * s + V(0, 8, 0)
			B.make("Part", {
				Size = V(0.3, 0.3, (b1 - a1).Magnitude), CFrame = CFrame.lookAt((a1 + b1) / 2, b1),
				Color = Color3.fromRGB(60, 60, 66), Material = M.Metal, CanCollide = false, CanQuery = false,
			}, B.decor)
		end
		-- chairs ride up one side and down the other, pausing at each station
		local count = 6
		local period = 44
		for i = 0, count - 1 do
			local seat = B.block(CFrame.new(low), V(6, 1, 6), P.Roof, M.WoodPlanks)
			B.mover(seat, function(t)
				local u = ((t / period) + i / count) % 1
				local p
				if u < 0.05 then
					p = low + side -- waiting at the bottom
				elseif u < 0.47 then
					p = (low + side):Lerp(high + side, (u - 0.05) / 0.42)
				elseif u < 0.5 then
					p = high + side -- waiting at the top
				elseif u < 0.53 then
					p = (high + side):Lerp(high - side, (u - 0.5) / 0.03)
				elseif u < 0.95 then
					p = (high - side):Lerp(low - side, (u - 0.53) / 0.42)
				else
					p = (low - side):Lerp(low + side, (u - 0.95) / 0.05)
				end
				return CFrame.new(p) * CFrame.Angles(0, -a, 0)
			end)
		end
		-- a pylon half way up with a prize on top: hop off a moving chair to reach it
		local mid = low:Lerp(high, 0.5)
		local gy = B.groundY(mid.X, mid.Z, mid.Y)
		B.block(CFrame.new(mid.X, (gy + mid.Y + 14) / 2, mid.Z), V(2.4, mid.Y + 14 - gy, 2.4), P.StoneDark, M.Metal)
		B.block(CFrame.new(mid + V(0, 13.5, 0)), V(7, 1, 7), P.StoneDark, M.Metal)
		B.golden("lift", mid + V(0, 18, 0))
		B.sign(low + dir * 10 - V(0, 4, 0), dir, "CHAIRLIFT", "Hop on!")
	end

	----------------------------------------------------------------- summit zipline
	B.zipline(C + V(0, 124, 18), V(-40, 7, -560))

	----------------------------------------------------------------- the Hot Spring
	do
		local a = 3.0
		local p = C + V(math.cos(a) * 182, 0, math.sin(a) * 182)
		B.pond(p.X, p.Z, 10, 2)
		local water = B.cyl(p.X, -1, p.Z, 9.5, 1.3, Color3.fromRGB(120, 180, 190), M.Glass, B.decor)
		water.Transparency = 0.3
		water.CanCollide = false
		steam(water, 10)
		for i = 0, 9 do
			local r = i / 10 * math.pi * 2
			B.rock(p.X + math.cos(r) * 11, 0, p.Z + math.sin(r) * 11, 0.9)
		end
		B.sign(p + V(0, 0, 14), V(0, 0, 1), "HOT SPRING", "Sit a while: it heals!")
		B.info.healZones = B.info.healZones or {}
		table.insert(B.info.healZones, { pos = p, radius = 9 })
	end
end

--------------------------------------------------------------------------------
-- Dustbowl Canyon
--------------------------------------------------------------------------------

local function canyon(B)
	local P = B.P
	local SAND = M.Sandstone

	----------------------------------------------------------------- Geyser Gulch
	do
		local pillars = { { 800, 110, 30, 6 }, { 830, 122, 55, 6 }, { 862, 104, 80, 7 } }
		for _, pl in ipairs(pillars) do
			B.cyl(pl[1], -2, pl[2], pl[4], pl[3] + 2, P.Sandstone, SAND)
			B.cyl(pl[1], pl[3] - 0.6, pl[2], pl[4] + 0.3, 0.8, Color3.fromRGB(196, 150, 104), SAND)
			for y = 8, pl[3] - 6, 9 do
				B.cyl(pl[1], y, pl[2], pl[4] + 0.3, 1.6, P.SandstoneDark, SAND)
			end
		end
		local function vent(from, to)
			local pad = B.springPad(from, throwTo(from + V(0, 1, 0), to, 6), Color3.fromRGB(196, 170, 140))
			steam(pad, 6)
		end
		vent(V(782, 0, 108), V(800, 30, 110))
		vent(V(802, 30, 113), V(830, 55, 122))
		vent(V(833, 55, 118), V(862, 80, 104))
		B.golden("geyser", V(862, 85, 104))
		B.sign(V(772, 0, 98), V(-1, 0, 0), "GEYSER GULCH", "Stand on a vent... if you dare")
		B.carrot(V(815, 52, 117))
		B.carrot(V(846, 78, 113))
	end

	----------------------------------------------------------------- zipline off Eagle's Mesa
	B.zipline(V(664, 95, 104), V(760, 27, 60))

	----------------------------------------------------------------- the fossil
	do
		local fx, fz = 680, -170
		local bone = Color3.fromRGB(226, 214, 186)
		for i = 0, 7 do
			local z = fz - 14 + i * 4
			local h = 9 - math.abs(i - 3.5) * 1.2
			for _, s in ipairs({ -1, 1 }) do
				B.block(CFrame.new(fx + s * 3, h / 2, z) * CFrame.Angles(0, 0, s * 0.35), V(0.9, h, 0.9), bone, M.SmoothPlastic)
			end
		end
		B.block(CFrame.new(fx, 9.5, fz), V(1.4, 1.4, 34), bone)
		B.block(CFrame.new(fx, 4, fz - 22) * CFrame.Angles(0.3, 0, 0), V(5, 4, 8), bone)
		B.carrotLine(V(fx, 13, fz - 12), V(fx, 13, fz + 12), 4)
		B.sign(V(fx + 12, 0, fz), V(1, 0, 0), "THE FOSSIL", "A very old, very big lizard")
	end
end

--------------------------------------------------------------------------------
-- Infernal Castle
--------------------------------------------------------------------------------

local function castle(B)
	local P = B.P

	----------------------------------------------------------------- the Magma Wheel
	do
		local lx, lz = -185, 780
		B.lava(CFrame.new(lx, 0.3, lz), V(60, 0.8, 80))
		B.block(CFrame.new(lx, 1, lz - 46), V(24, 2, 12), P.CastleDark, M.Slate) -- the near shore (facing the gate)
		B.wheel(V(lx, 14, lz - 28), 11, V(0, 0, 1), 4, 0.5, V(7, 1.2, 7), P.CastleStone, M.Slate)
		-- bobbing stepping stones on to the island
		for i, z in ipairs({ lz - 9, lz + 3, lz + 15 }) do
			local stone = B.block(CFrame.new(lx + ((i % 2 == 0) and 5 or -5), 4, z), V(6, 1.4, 6), P.CastleStone, M.Slate)
			B.bobber(stone, 2.2, 1.3, i)
		end
		B.cyl(lx, -1, lz + 30, 7, 6, P.CastleDark, M.Slate)
		B.firebar(V(lx, 6.6, lz + 30), 6.5, 1.5, 0)
		B.golden("magma", V(lx, 10, lz + 34))
		B.torch(V(lx + 10, 3.2, lz - 46))
		B.torch(V(lx - 10, 3.2, lz - 46))
		B.sign(V(lx + 14, 0, lz - 52), V(0, 0, -1), "THE MAGMA WHEEL", "Mind your step", P.CastleDark, Color3.fromRGB(230, 200, 170))
	end

	----------------------------------------------------------------- the King's toppled statue
	do
		local sx, sz = -160, 640
		local stone = Color3.fromRGB(110, 102, 100)
		B.block(CFrame.new(sx, 3, sz) * CFrame.Angles(0, 0.4, 1.2), V(10, 18, 12), stone, M.Slate)
		B.ball(V(sx + 9, 4, sz + 3), 5, stone, M.Slate)
		for i = 0, 4 do
			B.block(CFrame.new(sx + 9 + math.cos(i) * 3, 9, sz + 3 + math.sin(i) * 3), V(1, 2.4, 1), P.GoldDark, M.Metal)
		end
		B.block(CFrame.new(sx - 10, 1.5, sz - 6), V(8, 3, 8), stone, M.Slate)
		B.carrotLine(V(sx - 6, 10, sz), V(sx + 8, 12, sz + 3), 3)
		B.sign(V(sx, 0, sz - 16), V(0, 0, -1), "KING GRUMBLE", "(he was taller in real life)", P.CastleDark, Color3.fromRGB(230, 200, 170))
	end
end

function Revamp.Build(B)
	meadow(B)
	peaks(B)
	canyon(B)
	castle(B)
end

return Revamp
