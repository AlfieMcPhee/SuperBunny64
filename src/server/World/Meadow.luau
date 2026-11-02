--[[
	Carrot Meadow - the hub island, plus the routes out to the other regions:
	a grassy causeway north to Frostbite Peaks, a boardwalk east to Dustbowl
	Canyon and a long stone bridge south to the Infernal Castle.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local Meadow = {}

function Meadow.Build(B)
	local P = B.P
	local rng = B.rng
	local V = Vector3.new
	local WATER = Config.WaterLevel

	----------------------------------------------------------------- island
	B.island(0, 0, 230, 0, P.Grass, P.Sand)
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local r = rng:NextNumber(205, 222)
		local rad = rng:NextNumber(26, 40)
		B.cyl(math.cos(a) * r, -30, math.sin(a) * r, rad + 14, 27, P.Sand, Enum.Material.Sand)
		B.mound(math.cos(a) * r, math.sin(a) * r, rad, 0, P.Grass, -30)
	end
	for _ = 1, 9 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(40, 180)
		local x, z = math.cos(a) * r, math.sin(a) * r
		if (V(x, 0, z) - V(-130, 0, -120)).Magnitude > 70 and (V(x, 0, z) - V(140, 0, -90)).Magnitude > 80 and math.abs(x) > 20 then
			B.mound(x, z, rng:NextNumber(14, 24), rng:NextNumber(1.5, 3), P.GrassLight, -2)
		end
	end

	----------------------------------------------------------------- spawn
	local spawnPos = V(0, 0, 60)
	B.cyl(0, -0.5, 60, 7, 0.9, P.Stone, Enum.Material.Slate)
	B.sign(V(12, 0, 40), V(-0.5, 0, 0.85).Unit, "CARROT MEADOW", "North: Peaks / East: Canyon / South: Castle")
	B.carrotRing(spawnPos + V(0, 3, 0), 22, 8)
	B.fence(V(-30, 0, 90), V(-10, 0, 98))
	B.fence(V(-10, 0, 98), V(12, 0, 98))
	B.fence(V(12, 0, 98), V(30, 0, 90))
	B.path(spawnPos, V(-60, 0, -28), 7)
	B.path(spawnPos, V(-105, 0, -95), 7)
	B.path(spawnPos, V(100, 0, 120), 7)
	B.path(spawnPos, V(100, 0, -55), 7)
	B.path(spawnPos, V(-225, 0, 40), 7)
	B.path(spawnPos, V(0, 0, -228), 8)
	B.path(spawnPos, V(228, 0, 0), 8)
	B.path(spawnPos, V(0, 0, 228), 8)
	B.checkpointFlag("meadow")
	B.warpBurrow(Config.Warps[1])
	-- reward goldens appear here once earned
	B.golden("collector", V(-14, 4, 76))
	B.golden("buster", V(14, 4, 76))

	----------------------------------------------------------------- cottage
	do
		local x, z = -60, -40
		local wallTop = 12
		B.block(CFrame.new(x, wallTop / 2, z), V(22, wallTop, 16), P.Plaster)
		for _, dx in ipairs({ -10.6, 10.6 }) do
			for _, dz in ipairs({ -7.6, 7.6 }) do
				B.block(CFrame.new(x + dx, wallTop / 2, z + dz), V(1.2, wallTop, 1.2), P.Wood, Enum.Material.Wood)
			end
		end
		B.block(CFrame.new(x, wallTop - 0.5, z), V(22.4, 1, 16.4), P.Wood, Enum.Material.Wood)
		B.block(CFrame.new(x, 3.5, z + 8.05), V(4, 7, 0.3), P.Wood, Enum.Material.Wood)
		for _, dx in ipairs({ -6, 6 }) do
			B.block(CFrame.new(x + dx, 6.5, z + 8.05), V(3.4, 3, 0.3), Color3.fromRGB(70, 82, 86), Enum.Material.Glass)
		end
		B.wedge(CFrame.new(x, wallTop + 3.5, z - 4.5), V(25, 7, 9), P.Roof, Enum.Material.Slate)
		B.wedge(CFrame.new(x, wallTop + 3.5, z + 4.5) * CFrame.Angles(0, math.pi, 0), V(25, 7, 9), P.Roof, Enum.Material.Slate)
		B.block(CFrame.new(x + 6, wallTop + 7, z - 2), V(2.6, 6, 2.6), P.StoneDark, Enum.Material.Brick)
		B.block(CFrame.new(x - 6, 3, z + 13), V(6, 6, 6), P.WoodLight, Enum.Material.WoodPlanks)
		B.block(CFrame.new(x + 2, 6, z + 13), V(6, 12, 6), P.WoodLight, Enum.Material.WoodPlanks)
		B.carrot(V(x - 6, 9, z + 13))
		B.carrot(V(x + 2, 15, z + 13))
		B.golden("burrow", V(x - 4, wallTop + 11, z))
		B.carrotLine(V(x - 15, 3, z + 22), V(x + 15, 3, z + 22), 4)
		for i = 0, 4 do
			B.block(CFrame.new(x - 18, 0.4, z - 6 + i * 4), V(6, 0.8, 2.4), P.DirtDark)
			B.blob(V(x - 18, 1.2, z - 6 + i * 4), V(1.4, 1, 1.4), P.CarrotLeaf)
		end
	end

	----------------------------------------------------------------- lookout tower
	do
		local cx, cz = -130, -120
		B.terrace(cx, cz, { { 50, 7 }, { 38, 14, P.GrassLight }, { 28, 21 } })
		B.cyl(cx, 21, cz, 10, 82, P.Stone, Enum.Material.Slate)
		for y = 35, 95, 15 do
			B.cyl(cx, y, cz, 10.7, 1.4, P.StoneDark, Enum.Material.Slate)
		end
		B.cyl(cx, 103, cz, 14, 3, P.StoneDark, Enum.Material.Slate)
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			B.block(CFrame.new(cx + math.cos(a) * 13, 107.5, cz + math.sin(a) * 13) * CFrame.Angles(0, -a, 0), V(2.5, 3, 2.5), P.Stone, Enum.Material.Slate)
		end
		B.block(CFrame.new(cx + 4, 112, cz), V(0.6, 12, 0.6), P.Wood, Enum.Material.Wood)
		B.block(CFrame.new(cx + 6.5, 116, cz), V(4.5, 3, 0.2), P.Roof, Enum.Material.Fabric)
		B.golden("tower", V(cx - 3, 111, cz))
		for i = 0, 12 do
			local a = i * 0.62 + 0.3
			local x, z = cx + math.cos(a) * 18, cz + math.sin(a) * 18
			local top = 27 + i * 6.5
			local step = B.cyl(x, top - 2, z, 5, 2, i % 2 == 0 and P.WoodLight or P.Stone, i % 2 == 0 and Enum.Material.WoodPlanks or Enum.Material.Slate)
			if i == 4 or i == 9 then
				B.bobber(step, 2.5, 1.4, i)
			end
			if i % 2 == 0 then
				B.carrot(V(x, top + 3.5, z))
			end
		end
	end

	----------------------------------------------------------------- the old oak
	do
		local cx, cz = 110, 140
		local canopyTop = 93
		B.cyl(cx, -1, cz, 8, canopyTop - 2, P.Wood, Enum.Material.Wood)
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2 + 0.4
			B.block(CFrame.new(cx + math.cos(a) * 9, 1.5, cz + math.sin(a) * 9) * CFrame.Angles(0, -a, 0.5), V(8, 3, 3), P.Wood, Enum.Material.Wood)
		end
		B.cyl(cx, canopyTop - 3, cz, 16, 3, P.LeafDark, Enum.Material.Grass)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			B.blob(V(cx + math.cos(a) * 15, canopyTop + 1, cz + math.sin(a) * 15), V(12, 7, 12), i % 2 == 0 and P.Leaf or P.LeafDark)
			B.blob(V(cx + math.cos(a) * 12, canopyTop - 5, cz + math.sin(a) * 12), V(14, 8, 14), i % 2 == 0 and P.LeafDark or P.Leaf)
		end
		B.golden("oak", V(cx, canopyTop + 5, cz))
		for i = 0, 10 do
			local a = i * 0.6
			local top = 7 + i * 7.5
			local x, z = cx + math.cos(a) * 20, cz + math.sin(a) * 20
			B.cyl(x, top - 1.5, z, 5, 1.5, P.Leaf, Enum.Material.Grass)
			B.make("Part", {
				Shape = Enum.PartType.Cylinder,
				Size = V(14, 1.6, 1.6),
				CFrame = CFrame.new(cx + math.cos(a) * 12, top - 2, cz + math.sin(a) * 12) * CFrame.Angles(0, -a, 0),
				Color = P.Wood,
				Material = Enum.Material.Wood,
			})
			if i % 2 == 1 then
				B.carrot(V(x, top + 3.5, z))
			end
		end
	end

	----------------------------------------------------------------- big hill & cloud garden
	do
		local hx, hz = 140, -90
		B.terrace(hx, hz, { { 60, 7 }, { 45, 14, P.GrassLight }, { 32, 21 }, { 20, 28, P.GrassLight } })
		for i, r in ipairs({ 54, 41, 27 }) do
			B.carrot(V(hx - r, 7 * i + 3, hz + 8))
			B.carrot(V(hx - r + 2, 7 * i + 3, hz - 8))
		end
		B.cyl(hx, 28, hz, 2.6, 4, P.MushroomStem)
		local cap = B.blob(V(hx, 32.5, hz), V(13, 5, 13), P.Mushroom, nil, B.solid, true)
		cap:SetAttribute("Bounce", Config.MushroomBounce)
		cap.Name = "BounceMushroom"
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			B.blob(V(hx + math.cos(a) * 3.8, 34.4, hz + math.sin(a) * 3.8), V(1.8, 0.6, 1.8), P.MushroomStem)
		end

		local function skyIsland(x, top, z, r)
			B.cyl(x, top - 3, z, r, 3, P.Dirt)
			B.cyl(x, top - 1, z, r + 0.4, 1, P.Grass)
			B.cyl(x, top - 6, z, r * 0.75, 3, P.DirtDark, nil, B.decor)
			B.cyl(x, top - 9, z, r * 0.45, 3, P.DirtDark, nil, B.decor)
			B.cyl(x, top - 11, z, r * 0.2, 2, P.DirtDark, nil, B.decor)
		end
		skyIsland(125, 95, -62, 12)
		B.carrot(V(125, 98.5, -62))
		local slider = B.block(CFrame.new(86, 96, -40), V(14, 2, 14), P.WoodLight, Enum.Material.WoodPlanks)
		B.slider(slider, V(14, 0, 0), 0.7, 0)
		skyIsland(45, 99, -25, 11)
		B.carrot(V(45, 102.5, -25))
		local disc = B.cyl(15, 99, 0, 13, 2, P.Plaster)
		for i = 0, 3 do
			local stripe = B.make("Part", {
				Size = V(26.2, 2.1, 2.4),
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
		B.spinner(disc, 0.6)
		B.carrot(V(15, 104.5, 0))
		skyIsland(-15, 104, 25, 15)
		B.golden("sky", V(-15, 109, 25))
		for i = 0, 5 do
			local a = i * 1.1
			B.flower(-15 + math.cos(a) * 9, 104, 25 + math.sin(a) * 9)
		end
	end

	----------------------------------------------------------------- lonely islet (west)
	do
		local ix, iz = -330, 40
		B.island(ix, iz, 32, 2, P.Grass, P.Sand)
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2 + math.pi / 4
			B.cyl(ix + math.cos(a) * 9, 2, iz + math.sin(a) * 9, 1.4, 11, P.Plaster)
		end
		B.block(CFrame.new(ix, 13.5, iz), V(18, 1.5, 18), P.Roof, Enum.Material.Slate)
		B.cyl(ix, 2, iz, 3, 3, P.Stone, Enum.Material.Slate)
		B.golden("islet", V(ix, 8.5, iz))
		B.pineTree(ix + 18, 2, iz - 14, 1)
		B.pineTree(ix - 16, 2, iz + 17, 0.9)
		B.carrot(V(ix + 14, 5, iz + 12))
		B.carrot(V(ix - 14, 5, iz - 10))
		B.bug(V(ix + 16, 2, iz + 2), "meadow")
		local xs = { -253, -265, -277, -289 }
		for i, x in ipairs(xs) do
			local z = iz + math.sin(i * 1.7) * 5
			local stone = B.cyl(x, WATER - 6, z, 4, 9, P.Stone, Enum.Material.Slate)
			if i == 2 or i == 4 then
				local base = stone.CFrame
				B.mover(stone, function(t)
					return base + V(0, math.sin(t * 1.1 + i) * 4 - 1.5, 0)
				end)
			elseif i == 3 then
				B.slider(stone, V(0, 0, 10), 0.9, 0)
			end
			B.carrot(V(x, 1, z))
		end
	end

	----------------------------------------------------------------- north causeway to the peaks
	do
		B.block(CFrame.new(0, -15.5, -372), V(44, 30, 300), P.Dirt)
		B.block(CFrame.new(0, -0.5, -372), V(45, 1, 300), P.Grass)
		B.block(CFrame.new(0, -18, -372), V(70, 30, 304), P.Sand, Enum.Material.Sand)
		B.path(V(0, 0, -228), V(0, 0, -515), 8)
		for i = 0, 7 do
			local z = -250 - i * 36
			local side = (i % 2 == 0) and -1 or 1
			B.pineTree(side * 16, 0, z, 0.9 + (i % 3) * 0.15)
			B.rock(-side * 17, 0, z + 14, 1.2)
		end
		B.carrotLine(V(0, 3, -250), V(0, 3, -490), 9)
		B.bug(V(8, 0, -330), "meadow")
		B.bug(V(-8, 0, -430), "peaks")
		B.sign(V(14, 0, -240), V(0, 0, 1), "FROSTBITE PEAKS", "Mind the slippery ice")
	end

	----------------------------------------------------------------- east boardwalk to the canyon
	do
		local y = 2
		B.ramp(V(222, 0, 0), V(234, y, 0), 14, P.WoodLight, Enum.Material.WoodPlanks)
		for x = 234, 506, 16 do
			B.block(CFrame.new(x + 8, y - 0.5, 0), V(16, 1, 14), P.WoodLight, Enum.Material.WoodPlanks)
			for _, s in ipairs({ -1, 1 }) do
				B.block(CFrame.new(x, y - 8, s * 6.5), V(1.2, 16, 1.2), P.Wood, Enum.Material.Wood)
				B.block(CFrame.new(x, y + 1.5, s * 6.8), V(0.6, 3, 0.6), P.Wood, Enum.Material.Wood)
			end
		end
		for _, s in ipairs({ -1, 1 }) do
			B.make("Part", {
				Size = V(274, 0.4, 0.4),
				CFrame = CFrame.new(370, y + 2.8, s * 6.8),
				Color = P.Wood,
				Material = Enum.Material.Wood,
			})
		end
		B.ramp(V(522, 0, 0), V(510, y, 0), 14, P.WoodLight, Enum.Material.WoodPlanks)
		B.carrotLine(V(260, y + 3, 0), V(490, y + 3, 0), 8)
		B.sign(V(214, 0, 14), V(-1, 0, 0), "DUSTBOWL CANYON", "Roll + jump = long jump!")
	end

	----------------------------------------------------------------- south bridge to the castle
	do
		local y = 3
		B.ramp(V(0, 0, 222), V(0, y, 236), 24, P.CastleStone, Enum.Material.Slate)
		B.block(CFrame.new(0, y - 1, 388), V(24, 2, 304), P.CastleStone, Enum.Material.Slate)
		for _, s in ipairs({ -1, 1 }) do
			B.block(CFrame.new(s * 12.5, y + 1.3, 388), V(1.2, 2.6, 304), P.CastleDark, Enum.Material.Slate)
		end
		for z = 260, 520, 40 do
			B.block(CFrame.new(0, y - 14, z), V(20, 24, 6), P.CastleDark, Enum.Material.Slate)
		end
		B.ramp(V(0, 0, 552), V(0, y, 540), 24, P.CastleStone, Enum.Material.Slate)
		-- the castle gate arch
		for _, s in ipairs({ -1, 1 }) do
			B.block(CFrame.new(s * 19, y + 14, 532), V(12, 30, 8), P.CastleDark, Enum.Material.Slate)
		end
		B.block(CFrame.new(0, y + 31, 532), V(52, 6, 8), P.CastleDark, Enum.Material.Slate)
		-- a magic barrier spanning the whole approach, so nobody can hop around it
		B.gate(CFrame.new(0, y + 18, 532), V(140, 40, 1.5), Config.CastleGate)
		B.carrotLine(V(0, y + 3, 260), V(0, y + 3, 500), 7)
		B.sign(V(16, 0, 214), V(0, 0, -1), "INFERNAL CASTLE", "10 golden carrots open the gate")
	end

	----------------------------------------------------------------- bug homes
	for _, h in ipairs({
		V(40, 0, 25), V(-40, 0, 10), V(60, 0, -30), V(-20, 0, 120), V(70, 0, 80), V(-100, 0, -30),
		V(-150, 7, -70), V(185, 7, -70), V(45, 0, 160), V(-70, 0, 130), V(120, 0, 30), V(-180, 0, 60),
	}) do
		B.bug(h, "meadow")
	end

	----------------------------------------------------------------- scatter scenery
	local avoid = {
		{ V(0, 0, 60), 30 }, { V(-60, 0, -40), 26 }, { V(-130, 0, -120), 56 }, { V(110, 0, 140), 28 },
		{ V(140, 0, -90), 64 }, { V(12, 0, 40), 8 }, { V(-24, 0, 44), 10 },
	}
	local function ok(p, extra)
		if p.Magnitude > 205 then
			return false
		end
		-- keep the three exit corridors clear
		if math.abs(p.X) < 18 + extra and math.abs(p.Z) > 70 then
			return false
		end
		if math.abs(p.Z) < 18 + extra and p.X > 60 then
			return false
		end
		for _, a in ipairs(avoid) do
			if (p - a[1]).Magnitude < a[2] + extra then
				return false
			end
		end
		return true
	end
	local function scatter(count, tries, minR, maxR, extra, place, spacing)
		local placed = 0
		for _ = 1, tries do
			if placed >= count then
				break
			end
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(minR, maxR)
			local p = V(math.cos(a) * r, 0, math.sin(a) * r)
			if ok(p, extra) then
				place(p)
				if spacing then
					table.insert(avoid, { p, spacing })
				end
				placed += 1
			end
		end
	end
	scatter(70, 600, 35, 205, 6, function(p)
		local s = rng:NextNumber(0.8, 1.4)
		if rng:NextNumber() < 0.45 then
			B.pineTree(p.X, 0, p.Z, s)
		else
			B.roundTree(p.X, 0, p.Z, s)
		end
	end, 8)
	scatter(30, 300, 30, 205, 2, function(p)
		B.rock(p.X, 0, p.Z, rng:NextNumber(0.8, 2.2))
	end, 5)
	scatter(24, 600, 35, 190, 3, function(p)
		B.carrot(p + V(0, 3, 0))
	end, 10)
	scatter(200, 400, 10, 210, 0, function(p)
		B.flower(p.X, 0, p.Z)
	end, nil)
end

return Meadow
