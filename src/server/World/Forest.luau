--[[
	Whisperwood - an old, misty forest island west of the Lonely Islet.
	  * a rope bridge from the islet, with a little rest stop half way
	  * the Elder Tree: shelf fungus spiralling up a giant trunk to the canopy
	  * Treetop Village: three treehouses joined by rope bridges (one is missing planks)
	  * Bouncy Grove: giant mushrooms that fling you higher and higher
	  * the Bog: lily pads over murky water, some of which sink
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local Forest = {}

local ROPE = Color3.fromRGB(150, 128, 92)
local BARK = Color3.fromRGB(86, 66, 50)
local BARK_DARK = Color3.fromRGB(64, 50, 40)
local MOSS = Color3.fromRGB(88, 112, 62)
local MOSS_DARK = Color3.fromRGB(62, 84, 50)
local FUNGUS = Color3.fromRGB(196, 168, 120)
local FUNGUS_DARK = Color3.fromRGB(160, 130, 90)
local HUT_ROOF = Color3.fromRGB(104, 118, 76)
local CAPS = {
	Color3.fromRGB(128, 92, 136),
	Color3.fromRGB(86, 122, 138),
	Color3.fromRGB(150, 84, 76),
	Color3.fromRGB(118, 110, 150),
}

function Forest.Build(B)
	local P = B.P
	local rng = B.rng
	local V = Vector3.new
	local M = Enum.Material
	local T = B.Terrain
	local WX, WZ = -780, 60
	local W = V(WX, 0, WZ)

	--------------------------------------------------------------- helpers
	local function decorPart(props)
		props.CanCollide = false
		props.CanQuery = false
		props.CanTouch = false
		return B.make("Part", props, B.decor)
	end

	-- A sagging rope bridge between two deck-top points. `gaps` = segment
	-- indices with missing planks.
	local function ropeBridge(a, b, width, gaps)
		local n = math.max(4, math.floor((b - a).Magnitude / 8))
		local function at(t)
			return a:Lerp(b, t) - V(0, math.sin(t * math.pi) * 1.5, 0)
		end
		for i = 0, n - 1 do
			if not (gaps and gaps[i]) then
				B.plank(at(i / n), at((i + 1) / n), width, 0.8, P.WoodLight, M.WoodPlanks)
			end
		end
		local flat = V(b.X - a.X, 0, b.Z - a.Z).Unit
		local side = flat:Cross(V(0, 1, 0))
		for _, s in ipairs({ -1, 1 }) do
			local off = side * s * (width / 2 + 0.2)
			for _, p in ipairs({ a, b }) do
				B.block(CFrame.new(p + off + V(0, 1.6, 0)), V(0.7, 4.4, 0.7), P.Wood, M.Wood)
			end
			for i = 0, n - 1 do
				local p0 = at(i / n) + off + V(0, 3.2, 0)
				local p1 = at((i + 1) / n) + off + V(0, 3.2, 0)
				decorPart({
					Size = V(0.25, 0.25, (p1 - p0).Magnitude + 0.2),
					CFrame = CFrame.lookAt((p0 + p1) / 2, p1),
					Color = ROPE,
					Material = M.Fabric,
					CastShadow = false,
				})
			end
		end
	end

	-- A tall dark forest tree (round canopy layered on a long trunk)
	local function forestTree(x, y, z, s)
		B.cyl(x, y - 1, z, 1.1 * s, 16 * s, BARK, M.Wood)
		local tone = rng:NextNumber() < 0.5 and P.LeafDark or MOSS_DARK
		B.blob(V(x, y + 17 * s, z), V(11, 8, 11) * s, tone)
		B.blob(V(x + 2.5 * s, y + 14.5 * s, z + 1.5 * s), V(8, 6, 8) * s, P.Pine)
		B.blob(V(x - 2 * s, y + 20 * s, z - 1 * s), V(7, 5.5, 7) * s, tone)
	end

	local function deadTree(x, y, z, h)
		B.cyl(x, y - 1, z, 0.8, h, BARK_DARK, M.Wood)
		for i = 1, 3 do
			local a = i * 2.2 + x
			local base = V(x, y + h * (0.45 + i * 0.15), z)
			decorPart({
				Size = V(0.45, 0.45, 4 + i),
				CFrame = CFrame.lookAt(base, base + V(math.cos(a), 0.7, math.sin(a))) * CFrame.new(0, 0, -(2 + i / 2)),
				Color = BARK_DARK,
				Material = M.Wood,
			})
		end
	end

	--------------------------------------------------------------- island & terrain
	B.island(WX, WZ, 220, 0, P.GrassLight, P.Sand)
	-- moss and leaf-litter patches, gentle hummocks
	for _ = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(30, 200)
		local p = W + V(math.cos(a) * r, 0, math.sin(a) * r)
		B.paint(p, p + V(rng:NextNumber(-24, 24), 0, rng:NextNumber(-24, 24)), rng:NextNumber(10, 20), M.Grass, { M.LeafyGrass })
	end
	for _, h in ipairs({ { -860, 150, 30, 6 }, { -930, -40, 28, 5 }, { -640, 180, 22, 4 }, { -830, -110, 26, 5 }, { -960, 140, 24, 6 } }) do
		B.hill(h[1], h[2], h[3], h[4], M.LeafyGrass)
	end
	for i = 0, 13 do
		local a = i / 14 * math.pi * 2 + 0.3
		B.outcrop(W + V(math.cos(a) * 214, -1, math.sin(a) * 214), rng:NextNumber(5, 9), M.Rock)
	end
	-- dirt trails from the arrival clearing
	B.path(V(-566, 0, 40), V(-640, 0, 40), 8)
	B.path(V(-640, 0, 40), V(-750, 0, 60), 7)
	B.path(V(-640, 0, 40), V(-660, 0, 10), 6)
	B.path(V(-640, 0, 40), V(-712, 0, -62), 6)
	B.path(V(-810, 0, 50), V(-860, 0, 22), 6)

	--------------------------------------------------------------- the way in (from the Lonely Islet)
	ropeBridge(V(-358, 2.5, 40), V(-452, 2.5, 40), 8)
	B.island(-460, 40, 8, 2, P.Grass, P.Sand)
	B.torch(V(-460, 3.2, 46))
	B.carrot(V(-460, 6, 40))
	ropeBridge(V(-468, 2.5, 40), V(-568, 2.5, 40), 8)
	B.ramp(V(-576, 0, 40), V(-568, 2.5, 40), 8, P.WoodLight, M.WoodPlanks)
	B.carrotLine(V(-380, 5, 40), V(-440, 5, 40), 4)
	B.carrotLine(V(-490, 5, 40), V(-550, 5, 40), 4)
	B.sign(V(-352, 2, 54), V(1, 0, 0), "WHISPERWOOD", "West, over the rope bridge")
	B.sign(V(-586, 0, 26), V(1, 0, 0), "WHISPERWOOD", "Elder Tree / Treetops / Bog / Grove")

	B.checkpointFlag("forest", V(0, 0, -10))
	B.warpBurrow(Config.Warps[5])
	B.npc("fern", -592, 18, V(1, 0, 0.3))
	B.crate(-600, 30)

	--------------------------------------------------------------- the Elder Tree
	do
		local trunkTop = 150
		B.cyl(WX, -2, WZ, 18, trunkTop + 2, BARK, M.Wood)
		for y = 14, trunkTop - 10, 22 do
			local ring = B.cyl(WX, y, WZ, 18.3, 1.2, BARK_DARK, M.Wood, B.decor)
			ring.CanCollide = false
			ring.CanQuery = false
		end
		-- moss streaks
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2 + 0.2
			decorPart({
				Size = V(0.4, rng:NextNumber(20, 40), 4),
				CFrame = CFrame.new(WX + math.cos(a) * 18.1, rng:NextNumber(20, 120), WZ + math.sin(a) * 18.1) * CFrame.Angles(0, -a, 0),
				Color = MOSS,
				Material = M.Grass,
			})
		end
		-- roots (leaving the first shelf and the hiding kit's nook clear)
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2 + 0.35
			if math.abs(a - 0.83) > 0.4 and math.abs(a - 2 * math.pi) > 0.4 and a > 0.3 then
				local inner = V(WX + math.cos(a) * 15, 6, WZ + math.sin(a) * 15)
				local outer = V(WX + math.cos(a) * 30, -0.5, WZ + math.sin(a) * 30)
				B.plank(outer, inner, 4.5, 3, BARK, M.Wood)
			end
		end
		-- shelf fungus spiral (17 shelves, 8 studs apart)
		for i = 0, 16 do
			local a = i * 0.5
			local top = 8 + i * 8
			local x, z = WX + math.cos(a) * 23.5, WZ + math.sin(a) * 23.5
			B.cyl(x, top - 2, z, 5.5, 2, FUNGUS, M.SmoothPlastic)
			local rim = B.cyl(x, top - 2.4, z, 5.9, 0.6, FUNGUS_DARK, nil, B.decor)
			rim.CanCollide = false
			rim.CanQuery = false
			if i % 3 == 2 then
				B.carrot(V(x, top + 3, z))
			end
		end
		-- the canopy: a broad crown you can stand on
		B.cyl(WX, trunkTop - 5, WZ, 24, 5, BARK_DARK, M.Wood)
		B.cyl(WX, trunkTop - 0.6, WZ, 23, 0.8, MOSS, M.Grass)
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			local r = 26 + (i % 3) * 3
			B.blob(V(WX + math.cos(a) * r, trunkTop + 4 + (i % 2) * 5, WZ + math.sin(a) * r), V(22, 14, 22), i % 2 == 0 and P.LeafDark or MOSS_DARK)
		end
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2 + 0.5
			B.blob(V(WX + math.cos(a) * 14, trunkTop + 16, WZ + math.sin(a) * 14), V(18, 10, 18), P.Pine)
		end
		B.golden("eldertree", V(WX, trunkTop + 5, WZ))
		B.carrotRing(V(WX, 3, WZ), 34, 10)
		B.sign(V(-750, 0, 60), V(1, 0, 0), "THE ELDER TREE", "Climb the shelf fungus")
	end

	--------------------------------------------------------------- Treetop Village
	do
		local top = 40
		local trees = { V(-670, 0, -10), V(-630, 0, 100), V(-700, 0, 190) }
		for i, c in ipairs(trees) do
			B.cyl(c.X, -1, c.Z, 8, top - 1, BARK, M.Wood)
			B.cyl(c.X, top - 2, c.Z, 14, 2, P.WoodLight, M.WoodPlanks)
			local rim = B.cyl(c.X, top - 2.3, c.Z, 14.4, 0.6, P.Wood, M.Wood, B.decor)
			rim.CanCollide = false
			-- a hut on the first two; the third is a lookout with the prize
			if i < 3 then
				B.cyl(c.X, top, c.Z, 5, 6, P.Plaster)
				B.block(CFrame.new(c.X + 5, top + 2, c.Z), V(0.3, 4, 2.4), P.Wood, M.Wood)
				B.cyl(c.X, top + 6, c.Z, 7, 1, HUT_ROOF, M.Slate)
				B.cyl(c.X, top + 7, c.Z, 5.5, 1, HUT_ROOF, M.Slate)
				B.cyl(c.X, top + 8, c.Z, 1, 2, BARK_DARK, M.Wood)
			else
				B.golden("treetop", V(c.X, top + 4.5, c.Z))
			end
			B.torch(V(c.X + 10, top + 1.2, c.Z + 6))
			B.torch(V(c.X - 10, top + 1.2, c.Z - 6))
			for k = 0, 5 do
				local a = k / 6 * math.pi * 2
				B.blob(V(c.X + math.cos(a) * 12, top + 22 + (k % 2) * 4, c.Z + math.sin(a) * 12), V(18, 11, 18), k % 2 == 0 and P.LeafDark or MOSS_DARK)
			end
		end
		-- spiral steps up the first tree (outside the platform, so no bumped heads)
		local t1 = trees[1]
		for k = 0, 8 do
			local a = -0.6 + k * 0.62
			local stepTop = 4 + k * 4
			local x, z = t1.X + math.cos(a) * 18, t1.Z + math.sin(a) * 18
			B.block(CFrame.new(x, stepTop - 0.75, z) * CFrame.Angles(0, -a, 0), V(7, 1.5, 6), P.WoodLight, M.WoodPlanks)
			decorPart({
				Size = V(0.8, 0.8, 9),
				CFrame = CFrame.lookAt(V(x, stepTop - 1.6, z), V(t1.X, stepTop - 4, t1.Z)) * CFrame.new(0, 0, -4.5),
				Color = P.Wood,
				Material = M.Wood,
			})
			if k % 2 == 1 then
				B.carrot(V(x, stepTop + 3, z))
			end
		end
		-- bridges: T1 -> T2 is whole, T2 -> T3 is missing two planks
		local function edge(from, to)
			local d = V(to.X - from.X, 0, to.Z - from.Z).Unit
			return from + d * 13.5 + V(0, top, 0), to - d * 13.5 + V(0, top, 0)
		end
		local a1, b1 = edge(trees[1], trees[2])
		ropeBridge(a1, b1, 6)
		local a2, b2 = edge(trees[2], trees[3])
		ropeBridge(a2, b2, 6, { [3] = true, [7] = true })
		B.carrotLine(a1:Lerp(b1, 0.2) + V(0, 2, 0), a1:Lerp(b1, 0.8) + V(0, 2, 0), 4)
		B.carrotLine(a2:Lerp(b2, 0.15) + V(0, 2, 0), a2:Lerp(b2, 0.85) + V(0, 2, 0), 5)
		B.npc("hoot", t1.X + 9, t1.Z - 6, V(0, 0, 1), top + 10)
		B.crate(trees[2].X + 9, trees[2].Z + 7, top + 5)
		B.sign(V(-648, 0, -24), V(1, 0, 0), "TREETOP VILLAGE", "Steps around the trunk")
	end

	--------------------------------------------------------------- Bouncy Grove
	do
		local z = 20
		local caps = { { -870, 6 }, { -890, 32 }, { -910, 58 }, { -930, 84 } }
		for i, c in ipairs(caps) do
			local x, capTop = c[1], c[2]
			B.cyl(x, -1, z, 2.2, capTop - 1.5, Color3.fromRGB(214, 204, 180))
			local cap = B.blob(V(x, capTop - 2.5, z), V(14, 5, 14), CAPS[i], nil, B.solid, true)
			cap:SetAttribute("Bounce", 110)
			cap.Name = "BounceMushroom"
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(170, 200, 230)
			glow.Range = 14
			glow.Brightness = 0.6
			glow.Parent = cap
			for k = 0, 4 do
				local a = k / 5 * math.pi * 2 + i
				B.blob(V(x + math.cos(a) * 4, capTop - 0.3, z + math.sin(a) * 4), V(1.8, 0.6, 1.8), Color3.fromRGB(226, 220, 200))
			end
			B.carrot(V(x - 10, capTop + 14, z))
		end
		-- the high log, resting on a dead trunk
		B.cyl(-952, -1, 31, 2.6, 104, BARK_DARK, M.Wood)
		B.make("Part", {
			Shape = Enum.PartType.Cylinder,
			Size = V(18, 4, 4),
			CFrame = CFrame.new(-952, 103, 20) * CFrame.Angles(0, math.pi / 2, 0),
			Color = BARK,
			Material = M.Wood,
		})
		B.blob(V(-952, 105.2, 22), V(3, 0.6, 6), MOSS)
		B.golden("grove", V(-952, 109.5, 16))
		B.sign(V(-852, 0, 34), V(1, 0, 0), "BOUNCY GROVE", "Land on the caps!")
		-- smaller mushrooms all around
		for _ = 1, 14 do
			local p = V(rng:NextNumber(-960, -850), 0, z + rng:NextNumber(-30, 30))
			if math.abs(p.Z - z) > 10 then
				B.mushrooms(p.X, B.groundY(p.X, p.Z, 30), p.Z)
			end
		end
	end

	--------------------------------------------------------------- the Bog
	do
		local bx, bz, br = -720, -100, 34
		T:FillCylinder(CFrame.new(bx, -1.5, bz), 3, br, M.Air)
		T:FillCylinder(CFrame.new(bx, -3.5, bz), 1, br, M.Mud)
		B.paint(V(bx - br - 6, 0, bz), V(bx + br + 6, 0, bz), 14, M.Mud, { M.Grass, M.LeafyGrass })
		B.paint(V(bx, 0, bz - br - 6), V(bx, 0, bz + br + 6), 14, M.Mud, { M.Grass, M.LeafyGrass })
		local water = B.make("Part", {
			Name = "BogWater",
			Shape = Enum.PartType.Cylinder,
			Size = V(1.2, br * 2, br * 2),
			CFrame = CFrame.new(bx, -1.4, bz) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(70, 84, 62),
			Material = M.Glass,
			Transparency = 0.1,
			CastShadow = false,
		})
		water:SetAttribute("Water", true)
		-- low mist
		local mist = decorPart({ Size = V(br * 2, 1, br * 2), CFrame = CFrame.new(bx, 0, bz), Transparency = 1 })
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Rate = 10
		e.Lifetime = NumberRange.new(5, 8)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 9) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.8), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(Color3.fromRGB(200, 210, 190))
		e.Parent = mist
		-- the islet in the middle
		B.cyl(bx, -3, bz, 6, 4, MOSS_DARK, M.Grass)
		deadTree(bx + 2, 1, bz + 3, 14)
		B.golden("bog", V(bx - 1, 5, bz - 1))
		-- lily pads; kind = "still", "bob", "sink" or "slide"
		local pads = {
			{ -714, -76, "bob" }, { -724, -86, "sink" }, { -730, -110, "slide" },
			{ -720, -116, "still" }, { -710, -126, "sink" }, { -740, -96, "still" }, { -748, -108, "sink" },
		}
		for i, pd in ipairs(pads) do
			local pad = B.cyl(pd[1], -0.4, pd[2], 3.6, 1, Color3.fromRGB(96, 128, 70))
			B.blob(V(pd[1] + 1.2, 0.75, pd[2] + 0.8), V(1.4, 0.6, 1.4), Color3.fromRGB(214, 190, 200))
			local base = pad.CFrame
			if pd[3] == "bob" then
				B.bobber(pad, 0.4, 1.4, i)
			elseif pd[3] == "sink" then
				-- floats for a while, then slips under for a moment
				B.mover(pad, function(t)
					local s = math.sin(t * 0.9 + i * 1.7)
					return base - V(0, math.max(0, s - 0.35) * 4.5, 0)
				end)
			elseif pd[3] == "slide" then
				B.slider(pad, V(6, 0, 0), 0.8, i)
			end
			if i == 1 or i == 6 then
				B.carrot(V(pd[1], 4, pd[2]))
			end
		end
		for _, d in ipairs({ { -700, -84, 12 }, { -742, -124, 10 }, { -698, -118, 16 }, { -752, -80, 11 } }) do
			deadTree(d[1], -1, d[2], d[3])
		end
		B.sign(V(-700, 0, -62), V(0, 0, 1), "THE BOG", "Mind the sinking pads")
		B.crate(-700, -58)
	end

	--------------------------------------------------------------- baddies
	for _, p in ipairs({ V(-620, 0, 30), V(-690, 0, 60), V(-760, 0, 120), V(-840, 0, 80), V(-660, 0, 150), V(-880, 0, -60) }) do
		B.enemy("mossling", p, "forest", 0)
	end
	for _, p in ipairs({ V(-680, 0, -100), V(-760, 0, -90), V(-728, 0, -140), V(-820, 0, 20) }) do
		B.enemy("snapper", p, "forest")
	end
	B.enemy("toad", V(-650, 0, 60), "forest", 26)
	B.enemy("toad", V(-900, 0, 110), "forest", 26)
	B.enemy("bat", V(-640, 58, 45), "forest")
	B.enemy("bat", V(-780, 90, 30), "forest")
	B.enemy("puffshroom", V(-860, 0, -20), "meadow")
	for _, p in ipairs({ V(-600, 0, 70), V(-720, 0, 20), V(-800, 0, 140), V(-900, 0, 60), V(-640, 0, -50), V(-940, 0, -10) }) do
		B.bug(p, "forest")
	end

	--------------------------------------------------------------- scenery
	local avoid = {
		{ V(-580, 0, 40), 26 }, { V(-592, 0, 72), 14 }, { W, 44 }, { V(-670, 0, -10), 30 }, { V(-630, 0, 100), 22 },
		{ V(-700, 0, 190), 22 }, { V(-910, 0, 20), 36 }, { V(-952, 0, 31), 12 }, { V(-720, 0, -100), 46 },
		{ V(-760, 0, 82), 10 }, { V(-990, 0, 60), 12 },
	}
	local function nearLine(p, a, b, w)
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		return (p - (a + ab * t)).Magnitude < w
	end
	local function clear(p, extra)
		if (p - W).Magnitude > 200 then
			return false
		end
		if p.X > -600 and math.abs(p.Z - 40) < 20 then
			return false
		end
		-- keep the bridge lines between the treehouses clear
		if nearLine(p, V(-670, 0, -10), V(-630, 0, 100), 10) or nearLine(p, V(-630, 0, 100), V(-700, 0, 190), 10) then
			return false
		end
		for _, a in ipairs(avoid) do
			if (p - a[1]).Magnitude < a[2] + extra then
				return false
			end
		end
		return true
	end
	local function scatter(count, tries, extra, place, spacing)
		local placed = 0
		for _ = 1, tries do
			if placed >= count then
				break
			end
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(20, 200)
			local p = W + V(math.cos(a) * r, 0, math.sin(a) * r)
			if clear(p, extra) then
				place(p, B.groundY(p.X, p.Z, 30))
				if spacing then
					table.insert(avoid, { p, spacing })
				end
				placed += 1
			end
		end
	end
	scatter(70, 900, 6, function(p, y)
		local roll = rng:NextNumber()
		if roll < 0.55 then
			forestTree(p.X, y, p.Z, rng:NextNumber(0.9, 1.5))
		elseif roll < 0.85 then
			B.pineTree(p.X, y, p.Z, rng:NextNumber(1.4, 2.2))
		else
			deadTree(p.X, y, p.Z, rng:NextNumber(10, 16))
		end
	end, 9)
	scatter(30, 400, 2, function(p, y)
		B.bush(p.X, y, p.Z, rng:NextNumber(0.9, 1.5), MOSS_DARK)
	end, 4)
	scatter(14, 300, 3, function(p, y)
		B.log(p.X, y, p.Z, rng:NextNumber(0, math.pi), rng:NextNumber(1, 1.6))
	end, 6)
	scatter(22, 400, 1, function(p, y)
		B.mushrooms(p.X, y, p.Z)
	end, 3)
	scatter(16, 300, 2, function(p, y)
		B.rock(p.X, y, p.Z, rng:NextNumber(0.8, 2), P.StoneDark)
	end, 4)
	scatter(20, 500, 3, function(p)
		B.carrotOnGround(p.X, p.Z)
	end, 10)
	scatter(140, 400, 0, function(p, y)
		B.tuft(p.X, y, p.Z)
	end, nil)
end

return Forest
