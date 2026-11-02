--[[
	Cloudtop Heights - floating islands high above the meadow, reached by
	climbing the beanstalk (Config.SkyGate golden carrots).
	  * Cloud Hop: drifting clouds heading east
	  * Rainbow Bridge: an arching rainbow south to a pot of gold (mind the gap)
	  * the Cumulus: Captain Gust's airship, with a crow's nest up the mast
	  * Updraft Spire: rising winds carry you from ledge to ledge
	  * the Stormcrown: a floating arena where the Thunderhead broods (boss)
	Falling off the clouds puts you back where you last stood (see the server).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local Sky = {}

local CLOUD = Color3.fromRGB(232, 234, 240)
local CLOUD_SHADE = Color3.fromRGB(198, 204, 220)
local STALK = Color3.fromRGB(92, 128, 70)
local STALK_DARK = Color3.fromRGB(70, 104, 56)
-- a soft, slightly faded rainbow
local BANDS = {
	Color3.fromRGB(182, 102, 96),
	Color3.fromRGB(200, 146, 90),
	Color3.fromRGB(212, 192, 116),
	Color3.fromRGB(122, 160, 104),
	Color3.fromRGB(100, 136, 168),
	Color3.fromRGB(134, 112, 164),
}

function Sky.Build(B)
	local P = B.P
	local rng = B.rng
	local V = Vector3.new
	local M = Enum.Material
	local T = B.Terrain
	local HX, HY, HZ = 60, 420, -60

	--------------------------------------------------------------- helpers
	local function puff(pos, size, color)
		local p = B.blob(pos, size, color or CLOUD, M.SmoothPlastic)
		p.CastShadow = false
		return p
	end

	-- floating chunk of terrain with a cloud skirt
	local function skyIsland(x, top, z, r)
		T:FillCylinder(CFrame.new(x, top - 3, z), 6, r, M.Ground)
		T:FillCylinder(CFrame.new(x, top - 1.25, z), 2.5, r, M.Grass)
		T:FillBall(V(x, top - 7, z), r * 0.7, M.Ground)
		T:FillBall(V(x + r * 0.15, top - 12, z - r * 0.1), r * 0.42, M.Rock)
		T:FillBall(V(x - r * 0.1, top - 16, z + r * 0.05), r * 0.22, M.Rock)
		local n = math.max(6, math.floor(r / 2.5))
		for i = 0, n - 1 do
			local a = i / n * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local s = rng:NextNumber(0.5, 0.8) * math.min(r, 18)
			puff(V(x + math.cos(a) * r * 0.95, top - 5 - rng:NextNumber(0, 3), z + math.sin(a) * r * 0.95), V(s * 1.6, s * 0.7, s * 1.6), i % 2 == 0 and CLOUD or CLOUD_SHADE)
		end
	end

	-- a solid cloud you can stand on; `top` is the walkable height
	local function cloud(x, top, z, w, d)
		w = w or 14
		d = d or 12
		local c = B.blob(V(x, top - 2, z), V(w, 4, d), CLOUD, M.SmoothPlastic, B.solid, true)
		c.Name = "Cloud"
		c.CastShadow = false
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2 + x
			local s = rng:NextNumber(4, 6)
			local p = B.blob(V(x + math.cos(a) * w * 0.35, top - 1.6, z + math.sin(a) * d * 0.35), V(s * 1.3, s * 0.8, s), i % 2 == 0 and CLOUD or CLOUD_SHADE, M.SmoothPlastic)
			p.CastShadow = false
			local weld = Instance.new("WeldConstraint")
			p.Anchored = false
			p.Massless = true
			weld.Part0 = c
			weld.Part1 = p
			weld.Parent = p
			p.Parent = c
		end
		return c
	end

	--------------------------------------------------------------- the hub
	skyIsland(HX, HY, HZ, 30)
	-- the top of the beanstalk pokes up through the hub
	B.cyl(40, HY - 30, -40, 4, 42, STALK, M.Grass) -- top at 432
	for i = 0, 7 do
		local a = i * 1.3
		local y = HY + 2 + i * 1.4
		B.blob(CFrame.new(40 + math.cos(a) * 5, y, -40 + math.sin(a) * 5) * CFrame.Angles(0, -a, 0.4), V(5, 0.5, 3), STALK_DARK)
	end
	B.blob(V(40, HY + 11, -40), V(7, 2, 7), STALK_DARK)
	B.exitPrompt(V(36, HY + 0.5, -52), "beanstalk", "Climb down")
	B.checkpointFlag("sky")
	B.warpBurrow(Config.Warps[6])
	B.npc("nimbus", 74, -74, V(-1, 0, 0.3), HY + 20)
	B.sign(V(64, HY, -48), V(0, 0, -1), "CLOUDTOP HEIGHTS", "Don't look down!")
	B.crate(46, -74, HY + 20)
	B.carrotRing(V(HX, HY + 3, HZ), 18, 8)
	for i = 0, 4 do
		local a = i * 1.25 + 0.4
		B.flower(HX + math.cos(a) * 24, HY, HZ + math.sin(a) * 24)
	end
	B.bug(V(50, HY, -70), "sky")
	B.bug(V(75, HY, -58), "sky")

	--------------------------------------------------------------- Cloud Hop (east)
	do
		local hops = { { 105, 420, -60 }, { 122, 424, -50 }, { 139, 428, -66 }, { 156, 432, -56 }, { 173, 436, -70 } }
		for i, h in ipairs(hops) do
			local c = cloud(h[1], h[2], h[3])
			if i == 2 or i == 4 then
				B.slider(c, V(0, 0, 5), 0.9, i)
			end
			if i ~= 3 then
				B.carrot(V(h[1], h[2] + 3, h[3]))
			end
		end
		skyIsland(192, 440, -60, 12)
		B.golden("cloudhop", V(192, 445, -60))
		B.enemy("puffer", V(150, 444, -84), "sky")
		B.sign(V(84, HY, -66), V(-1, 0, 0), "CLOUD HOP", "East, cloud by cloud")
	end

	--------------------------------------------------------------- Rainbow Bridge (south)
	do
		local a, b = V(HX, HY, -86), V(HX, 430, -218)
		local n = 16
		local function at(t)
			return a:Lerp(b, t) + V(0, math.sin(t * math.pi) * 10, 0)
		end
		for i = 0, n - 1 do
			if i ~= 8 then -- the gap
				local p0, p1 = at(i / n), at((i + 1) / n)
				for k, color in ipairs(BANDS) do
					local off = V((k - 3.5) * 1.6, 0, 0)
					local part = B.plank(p0 + off, p1 + off, 1.6, 1, color)
					part.CastShadow = false
				end
			end
		end
		for _, t in ipairs({ 0.25, 0.4, 0.7, 0.85 }) do
			B.carrot(at(t) + V(0, 3, 0))
		end
		skyIsland(HX, 430, -230, 14)
		-- the pot of gold
		B.cyl(HX, 430, -234, 3, 3, Color3.fromRGB(40, 36, 40), M.Metal)
		for i = 0, 6 do
			local ang = i / 7 * math.pi * 2
			B.blob(V(HX + math.cos(ang) * 1.4, 433.2, -234 + math.sin(ang) * 1.4), V(1.2, 0.5, 1.2), P.Gold, M.Metal)
		end
		B.golden("rainbow", V(HX, 435, -226))
		B.enemy("bat", V(HX + 14, 446, -170), "sky")
		B.sign(V(HX + 9, HY, -84), V(0, 0, 1), "RAINBOW BRIDGE", "Mind the gap")
	end

	--------------------------------------------------------------- the airship Cumulus (west)
	do
		local deck = 422
		local z = -20
		-- cloud stepping stones out to the bow
		for i, c in ipairs({ { 18, 421, -44 }, { 0, 423, -34 }, { -17, 422, -27 }, { -33, 423, -22 } }) do
			local cl = cloud(c[1], c[2], c[3], 12, 11)
			if i == 3 then
				B.bobber(cl, 1.5, 1.1, 0)
			end
			B.carrot(V(c[1], c[2] + 3, c[3]))
		end
		local WOOD = P.Wood
		B.block(CFrame.new(-82, deck - 4, z), V(52, 8, 16), WOOD, M.WoodPlanks)
		B.block(CFrame.new(-52, deck - 3.5, z), V(8, 7, 11), WOOD, M.WoodPlanks)
		B.block(CFrame.new(-82, deck - 8.5, z), V(44, 3, 10), P.Roof, M.WoodPlanks)
		B.block(CFrame.new(-82, deck - 0.2, z), V(51, 0.4, 15), P.WoodLight, M.WoodPlanks)
		-- bow sprit and figurehead
		B.make("Part", {
			Size = V(12, 0.8, 0.8),
			CFrame = CFrame.new(-44, deck + 1.5, z) * CFrame.Angles(0, 0, 0.3),
			Color = WOOD,
			Material = M.Wood,
			CanCollide = false,
		}, B.decor)
		B.blob(V(-48.5, deck - 1, z), V(2, 3, 2), P.Gold, M.Metal)
		-- railings (decor: the ship is open-decked, so watch your step)
		for _, s in ipairs({ -1, 1 }) do
			local rail = B.block(CFrame.new(-82, deck + 1.2, z + s * 7.8), V(52, 0.4, 0.4), P.WoodLight, M.Wood, B.decor)
			rail.CanCollide = false
			for x = -106, -58, 6 do
				local post = B.block(CFrame.new(x, deck + 0.6, z + s * 7.8), V(0.4, 1.2, 0.4), WOOD, M.Wood, B.decor)
				post.CanCollide = false
			end
		end
		-- cabin at the stern
		B.block(CFrame.new(-101, deck + 3.5, z), V(12, 7, 13), P.Plaster)
		B.block(CFrame.new(-101, deck + 7.4, z), V(13, 0.8, 14), P.Roof, M.Slate)
		B.block(CFrame.new(-94.9, deck + 2.5, z), V(0.3, 4.5, 2.6), WOOD, M.Wood)
		local wheel = B.cyl(-90, deck + 3, z, 1.6, 0.4, WOOD, M.Wood, B.decor)
		wheel.CFrame = CFrame.new(-90, deck + 3, z) -- facing the bow
		wheel.CanCollide = false
		B.block(CFrame.new(-90.6, deck + 1.4, z), V(0.6, 2.8, 0.6), WOOD, M.Wood)
		-- propellers off the stern
		for _, s in ipairs({ -1, 1 }) do
			B.cyl(-110, deck - 5, z + s * 6, 0.6, 3, P.StoneDark, M.Metal)
			for k = 0, 2 do
				local blade = B.block(CFrame.new(-110.5, deck - 2, z + s * 6) * CFrame.Angles(k * 2.09, 0, 0) * CFrame.new(0, 2, 0), V(0.3, 4, 1.2), P.WoodLight, M.Wood, B.decor)
				blade.CanCollide = false
			end
		end
		-- the mast: yardarms staggered so you never bump your head, then the crow's nest
		local mx = -80
		B.cyl(mx, deck, z, 1.2, 43, WOOD, M.Wood)
		local yards = { { 5, 432 }, { -5, 443 }, { 6, 454 } }
		for i, y in ipairs(yards) do
			B.block(CFrame.new(mx + y[1], y[2] - 0.75, z), V(2.5, 1.5, 18), P.WoodLight, M.Wood)
			local sail = B.block(CFrame.new(mx + y[1] + 0.4, y[2] - 5.5, z), V(0.3, 8, 15), P.Plaster, M.Fabric, B.decor)
			sail.CanCollide = false
			sail.CastShadow = false
			if i < 3 then
				B.carrot(V(mx + y[1], y[2] + 3, z + 6))
			end
		end
		B.cyl(mx, 463, z, 4.5, 2, P.WoodLight, M.WoodPlanks)
		for k = 0, 9 do
			local ang = k / 10 * math.pi * 2
			if k ~= 0 then -- a gap in the rim to climb in
				local post = B.block(CFrame.new(mx + math.cos(ang) * 4.3, 466, z + math.sin(ang) * 4.3) * CFrame.Angles(0, -ang, 0), V(0.4, 2, 2.6), WOOD, M.Wood, B.decor)
				post.CanCollide = false
			end
		end
		local pole = B.cyl(mx - 3, 465, z - 3, 0.25, 10, WOOD, M.Wood, B.decor)
		pole.CanCollide = false
		local flag = B.block(CFrame.new(mx - 3, 473, z - 4.6), V(0.15, 2, 3), P.Roof, M.Fabric, B.decor)
		flag.CanCollide = false
		B.golden("crowsnest", V(mx + 1, 469, z))
		B.npc("gust", -66, -14, V(1, 0, 0), deck + 20)
		B.crate(-64, -25, deck + 6)
		B.enemy("puffer", V(-30, 432, -6), "sky")
		B.enemy("puffer", V(-80, 444, -42), "sky")
	end

	--------------------------------------------------------------- Updraft Spire (south-east)
	do
		local sx, sz = 180, -180
		-- cloud steps down from the Cloud Hop island...
		for _, c in ipairs({ { 190, 436, -86 }, { 187, 433, -104 }, { 184, 430, -122 }, { 182, 427, -140 } }) do
			cloud(c[1], c[2], c[3])
			B.carrot(V(c[1], c[2] + 3, c[3]))
		end
		-- ...and a slow cloud ferry from the end of the rainbow
		local ferry = cloud(117, 428, -214, 14, 14)
		B.slider(ferry, V(32, 0, 14), 0.35, 0)
		skyIsland(sx, 424, sz, 22)
		B.cyl(sx, 418, sz, 10, 102, Color3.fromRGB(150, 156, 170), M.Slate)
		for y = 440, 510, 14 do
			local band = B.cyl(sx, y, sz, 10.3, 1.2, Color3.fromRGB(120, 126, 140), M.Slate, B.decor)
			band.CanCollide = false
		end
		B.cyl(sx, 519.4, sz, 10.4, 0.8, P.Gold, M.Metal)
		local ledges = { { 0, 450 }, { 2.1, 480 }, { 4.2, 510 } }
		for _, l in ipairs(ledges) do
			local p = V(sx + math.cos(l[1]) * 15, l[2] - 1, sz + math.sin(l[1]) * 15)
			B.block(CFrame.new(p) * CFrame.Angles(0, -l[1], 0), V(11, 2, 8), Color3.fromRGB(176, 180, 192), M.Slate)
		end
		-- rising winds: each one lifts you beside the next ledge
		local winds = { { -0.7, 424, 458 }, { 1.05, 447, 488 }, { 3.15, 477, 518 } }
		for _, w in ipairs(winds) do
			local h = w[3] - w[2]
			local p = V(sx + math.cos(w[1]) * 16, w[2] + h / 2, sz + math.sin(w[1]) * 16)
			B.wind(CFrame.new(p) * CFrame.Angles(0, -w[1], 0), V(8, h, 8), V(0, 32, 0))
			-- a little vent on the island marks the first one
			if w[2] < 430 then
				B.cyl(p.X, 423.6, p.Z, 4, 0.6, Color3.fromRGB(120, 126, 140), M.Slate)
			end
		end
		B.golden("updraft", V(sx, 525, sz))
		B.sign(V(sx - 4, 424, sz + 18), V(0, 0, 1), "UPDRAFT SPIRE", "Ride the rising wind")
		B.enemy("puffer", V(sx + 26, 474, sz + 10), "sky")
		B.enemy("bat", V(sx - 20, 500, sz), "sky")
		B.carrot(V(sx, 430, sz + 15))
	end

	--------------------------------------------------------------- the Stormcrown (Thunderhead's arena)
	do
		local ax, ay, az, ar = 60, 445, 95, 32
		B.info.bossArenas = B.info.bossArenas or {}
		B.info.bossArenas.thunderhead = { center = V(ax, ay, az), radius = ar }
		skyIsland(ax, ay, az, ar + 2)
		T:ReplaceMaterial(Region3.new(V(ax - ar - 4, ay - 4, az - ar - 4), V(ax + ar + 4, ay + 1, az + ar + 4)):ExpandToGrid(4), 4, M.Grass, M.Slate)
		for _, c in ipairs({ { 60, 423, -12 }, { 64, 427, 6 }, { 58, 431, 24 }, { 62, 435, 42 }, { 60, 440, 58 } }) do
			cloud(c[1], c[2], c[3])
			B.carrot(V(c[1], c[2] + 3, c[3]))
		end
		-- lightning rods around the rim
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2 + math.pi / 4
			local x, z = ax + math.cos(a) * (ar - 2), az + math.sin(a) * (ar - 2)
			B.cyl(x, ay - 1, z, 0.5, 18, P.StoneDark, M.Metal)
			B.ball(V(x, ay + 17.5, z), 1, Color3.fromRGB(190, 200, 220), M.Metal)
		end
		B.golden("thunderhead", V(ax, ay + 5, az))
		B.sign(V(70, HY, -34), V(0, 0, -1), "THE STORMCROWN", "South, if you dare the weather")
	end

	--------------------------------------------------------------- distant scenery clouds (walk-through)
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2
		local r = rng:NextNumber(260, 340)
		local s = rng:NextNumber(14, 26)
		local p = puff(V(HX + math.cos(a) * r, rng:NextNumber(390, 450), HZ + math.sin(a) * r), V(s * 2.4, s * 0.8, s * 1.6), i % 3 == 0 and CLOUD_SHADE or CLOUD)
		p.CanCollide = false
	end
end

return Sky
