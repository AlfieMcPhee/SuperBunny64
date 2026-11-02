--[[
	Dustbowl Canyon - a sun-baked mesa island east of the meadow.
	  * Canyon Leap: pillars too far apart for a double jump; roll + jump to long jump
	  * Eagle's Mesa: a tall mesa ringed with ledges
	  * Boulder Run: a long ramp with boulders rolling down it
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local Canyon = {}

function Canyon.Build(B)
	local P = B.P
	local rng = B.rng
	local V = Vector3.new
	local cx, cz = 720, 0
	local C = V(cx, 0, cz)
	local SAND = Enum.Material.Sandstone

	B.island(cx, cz, 210, 0, P.Sandstone, P.Sand, Enum.Material.Sand, P.SandstoneDark)
	-- dunes, a dry riverbed and wind-carved sandstone spires
	local T = B.Terrain
	for _, d in ipairs({ { 760, -150, 30, 6 }, { 830, -20, 22, 5 }, { 690, -150, 26, 5 }, { 600, 110, 18, 4 }, { 880, 110, 24, 5 } }) do
		B.hill(d[1], d[2], d[3], d[4], Enum.Material.Sand)
	end
	B.paint(V(560, 0, 60), V(720, 0, 30), 14, Enum.Material.Ground, { Enum.Material.Sand })
	B.paint(V(720, 0, 30), V(900, 0, 80), 14, Enum.Material.Ground, { Enum.Material.Sand })
	for _, sp in ipairs({ { 900, 30, 7, 34 }, { 560, 150, 6, 28 }, { 840, -140, 8, 40 }, { 610, -160, 5, 22 } }) do
		T:FillCylinder(CFrame.new(sp[1], sp[4] / 2, sp[2]), sp[4], sp[3], Enum.Material.Sandstone)
		T:FillBall(Vector3.new(sp[1], sp[4], sp[2]), sp[3] * 1.15, Enum.Material.Sandstone)
		T:FillBall(Vector3.new(sp[1], 1, sp[2]), sp[3] * 1.6, Enum.Material.Sandstone)
	end
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2 + 0.2
		B.outcrop(C + V(math.cos(a) * 208, -2, math.sin(a) * 208), rng:NextNumber(4, 8), Enum.Material.Sandstone)
	end

	-- Layered mesa block helper
	local function mesa(center, size, top)
		local h = top
		B.block(CFrame.new(center.X, h / 2, center.Z), V(size.X, h, size.Z), P.Sandstone, SAND)
		for y = 6, h - 4, 9 do
			B.block(CFrame.new(center.X, y, center.Z), V(size.X + 0.6, 2, size.Z + 0.6), P.SandstoneDark, SAND)
		end
		B.block(CFrame.new(center.X, h - 0.4, center.Z), V(size.X + 0.4, 0.8, size.Z + 0.4), Color3.fromRGB(196, 150, 104), SAND)
	end

	----------------------------------------------------------------- Canyon Leap
	do
		local z = -60
		mesa(V(610, 0, z), V(40, 0, 40), 40)
		for i = 0, 4 do
			B.block(CFrame.new(554 + i * 8, 3.5 * (i + 1), z), V(8, 7 * (i + 1), 12), P.SandstoneDark, SAND)
		end
		B.sign(V(600, 40, z + 14), V(1, 0, 0), "CANYON LEAP", "ROLL then JUMP to long jump")
		local pillars = { { 670, 40 }, { 718, 40 }, { 767, 42 }, { 817, 42 } }
		local prevEdge = 630
		for _, pl in ipairs(pillars) do
			B.cyl(pl[1], 0, z, 7, pl[2], P.Sandstone, SAND)
			B.cyl(pl[1], pl[2] - 0.6, z, 7.3, 0.8, Color3.fromRGB(196, 150, 104), SAND)
			B.carrot(V((prevEdge + pl[1] - 7) / 2, pl[2] + 12, z))
			prevEdge = pl[1] + 7
		end
		mesa(V(873, 0, z), V(34, 0, 40), 44)
		B.golden("leap", V(873, 49, z))
		-- a rope ladder of ledges back up the goal mesa for the return trip isn't needed:
		-- the canyon floor is safe, so falling just means trying again.
	end

	----------------------------------------------------------------- Eagle's Mesa
	do
		local mx, mz = 650, 110
		B.cyl(mx, 0, mz, 24, 90, P.Sandstone, SAND)
		for y = 8, 84, 10 do
			B.cyl(mx, y, mz, 24.4, 2, P.SandstoneDark, SAND)
		end
		B.cyl(mx, 89.4, mz, 24.4, 0.8, Color3.fromRGB(196, 150, 104), SAND)
		for i = 0, 11 do
			local a = i * 0.55 + 2.4
			local top = 7 + i * 7
			local p = V(mx + math.cos(a) * 30, top - 1, mz + math.sin(a) * 30)
			B.block(CFrame.new(p) * CFrame.Angles(0, -a, 0), V(12, 2, 8), P.SandstoneDark, SAND)
			if i % 3 == 1 then
				B.carrot(p + V(0, 4, 0))
			end
		end
		-- nest on top
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			B.blob(CFrame.new(mx + math.cos(a) * 5, 91, mz + math.sin(a) * 5) * CFrame.Angles(0, -a, 0.3), V(4, 1.4, 1.4), P.Wood)
		end
		B.golden("mesa", V(mx, 95, mz))
	end

	----------------------------------------------------------------- Boulder Run
	do
		local z = 160
		local low, high = V(600, 0, z), V(820, 60, z)
		B.plank(low, high, 24, 3, P.SandstoneDark, SAND)
		for _, s in ipairs({ -1, 1 }) do
			-- walls stand 5 studs above the ramp so boulders and bunnies stay on it
			B.plank(low + V(0, 5, s * 12.6), high + V(0, 5, s * 12.6), 1.2, 8, P.Sandstone, SAND)
		end
		-- temple on top
		B.block(CFrame.new(838, 29.5, z), V(36, 61, 44), P.Sandstone, SAND)
		for _, dx in ipairs({ -12, 12 }) do
			for _, dz in ipairs({ -14, 14 }) do
				B.cyl(838 + dx, 60, z + dz, 1.8, 12, P.Plaster)
			end
		end
		B.block(CFrame.new(838, 73, z), V(32, 2, 36), P.SandstoneDark, SAND)
		B.plank(V(838, 74, z - 18), V(838, 78, z), 32, 1, P.Roof, Enum.Material.Slate)
		B.plank(V(838, 74, z + 18), V(838, 78, z), 32, 1, P.Roof, Enum.Material.Slate)
		B.golden("boulder", V(845, 65, z))
		table.insert(B.info.boulderSpawns, { from = V(818, 68, z), dir = V(-1, 0, 0) })
		for i = 1, 5 do
			B.carrot(low:Lerp(high, i / 6) + V(0, 4, (i % 2 == 0) and 7 or -7))
		end
		B.sign(V(590, 0, z - 18), V(-1, 0, 0), "BOULDER RUN", "Look out above!")
	end

	----------------------------------------------------------------- arrival
	B.checkpointFlag("canyon", Vector3.new(0, 0, 12)) -- beside the boardwalk, not on it
	B.warpBurrow(Config.Warps[3])
	B.carrotLine(V(560, 3, 30), V(640, 3, 30), 5)

	----------------------------------------------------------------- scenery & bugs
	-- rock arch
	B.block(CFrame.new(760, 9, 60), V(8, 18, 8), P.SandstoneDark, SAND)
	B.block(CFrame.new(790, 9, 60), V(8, 18, 8), P.SandstoneDark, SAND)
	B.block(CFrame.new(775, 20, 60), V(40, 6, 9), P.Sandstone, SAND)
	B.carrotLine(V(762, 26, 60), V(788, 26, 60), 3)
	local function clear(p)
		if (p - C).Magnitude > 195 then
			return false
		end
		if math.abs(p.Z + 60) < 30 and p.X > 540 then
			return false
		end
		if (p - V(650, 0, 110)).Magnitude < 45 or math.abs(p.Z - 160) < 22 or (p - V(775, 0, 60)).Magnitude < 28 then
			return false
		end
		if math.abs(p.Z) < 16 and p.X < 600 then
			return false
		end
		return true
	end
	local placed = 0
	for _ = 1, 400 do
		if placed >= 30 then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(20, 195)
		local p = C + V(math.cos(a) * r, 0, math.sin(a) * r)
		if clear(p) then
			if rng:NextNumber() < 0.6 then
				B.cactus(p.X, B.groundY(p.X, p.Z, 60), p.Z, rng:NextNumber(0.8, 1.3))
			else
				B.rock(p.X, B.groundY(p.X, p.Z, 60), p.Z, rng:NextNumber(1, 2.5), P.SandstoneDark)
			end
			placed += 1
		end
	end
	for _, p in ipairs({ V(700, 0, 20), V(760, 0, -10), V(820, 0, 40), V(700, 0, -130), V(600, 0, 60), V(860, 0, 90) }) do
		B.bug(p, "canyon")
	end
	-- thornhogs patrol the canyon floor under the leap pillars and the riverbed
	B.enemy("thornhog", V(690, 0, -60), "canyon", 30, V(1, 0, 0))
	B.enemy("thornhog", V(790, 0, -60), "canyon", 30, V(1, 0, 0))
	B.enemy("thornhog", V(720, 0, 40), "canyon", 26, V(1, 0, 0.3).Unit)
	B.enemy("toad", V(620, 0, 20), "canyon", 24)
	B.enemy("toad", V(800, 0, 110), "canyon", 24)
	B.enemy("puffshroom", V(860, 0, 40), "canyon")
	B.enemy("bat", V(650, 70, 110), "meadow")
	for _, p in ipairs({ V(740, 0, -120), V(800, 0, -100), V(700, 0, 80) }) do
		B.carrot(p + V(0, 3, 0))
	end
end

return Canyon
