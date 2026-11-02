--[[
	Infernal Castle - a volcanic island south of the meadow. The hard part.

	  Approach      lava rivers, cinderbugs, a drawbridge over the lava moat
	  Courtyard     Firebar Gauntlet (west) and Crusher Hall (east)
	  Ramparts      a ramp up to the wall walk, the north-east watchtower
	  The Keep      a lava-floored climb up the inside walls to the roof
	  Dungeon       outside the east wall: sinking blocks, beams and firebars
	  Throne Room   a floating arena high above the castle (King Grumble)
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local Castle = {}

Castle.ArenaCenter = Vector3.new(0, 200, 800)
Castle.ArenaRadius = 52

function Castle.Build(B)
	local P = B.P
	local rng = B.rng
	local V = Vector3.new
	local CF = CFrame.new
	local SLATE = Enum.Material.Slate
	local BASALT = Enum.Material.Basalt
	local stone, dark = P.CastleStone, P.CastleDark

	B.island(0, 800, 260, 0, P.Basalt, Color3.fromRGB(72, 64, 62), BASALT, P.BasaltLight)

	----------------------------------------------------------------- approach
	B.checkpointFlag("castle")
	B.warpBurrow(Config.Warps[4])
	B.sign(V(-20, 0, 570), V(0, 0, -1), "INFERNAL CASTLE", "Turn back, little bunny...", dark, Color3.fromRGB(230, 200, 170))
	B.lava(CF(0, 0.3, 602), V(240, 0.8, 12))
	B.lava(CF(0, 0.3, 632), V(240, 0.8, 12))
	B.block(CF(0, 0.6, 602), V(6, 1.2, 15), dark, SLATE)
	B.block(CF(40, 0.6, 632), V(6, 1.2, 15), dark, SLATE)
	B.block(CF(-50, 0.6, 632), V(6, 1.2, 15), dark, SLATE)
	B.carrotLine(V(0, 4, 585), V(0, 4, 650), 5)
	for _, p in ipairs({ V(-60, 0, 585), V(60, 0, 590), V(-30, 0, 645), V(160, 0, 690) }) do
		B.bug(p, "castle")
	end
	for i = 0, 5 do
		local x = -100 + i * 40
		B.torch(V(x, 1.2, 652))
	end
	-- smouldering vents
	for _, p in ipairs({ V(-110, 0, 580), V(100, 0, 615), V(140, 0, 580), V(-140, 0, 640) }) do
		B.cyl(p.X, -0.5, p.Z, 5, 2, P.BasaltLight, BASALT)
		B.lava(CF(p.X, 1.4, p.Z), V(4, 0.4, 4))
	end

	----------------------------------------------------------------- moat & drawbridge
	B.lava(CF(0, 0.3, 672), V(290, 0.8, 32))
	B.block(CF(0, 1, 672), V(24, 2, 40), P.Wood, Enum.Material.WoodPlanks)
	for _, s in ipairs({ -1, 1 }) do
		B.plank(V(s * 11, 2.5, 652), V(s * 11, 30, 690), 0.5, 0.5, Color3.fromRGB(60, 58, 58), Enum.Material.Metal).CanCollide = false
	end
	B.carrot(V(0, 5, 665))
	B.carrot(V(0, 5, 680))

	----------------------------------------------------------------- walls & towers
	local WALL = 45
	B.block(CF(-61, WALL / 2, 695), V(98, WALL, 10), stone, SLATE)
	B.block(CF(61, WALL / 2, 695), V(98, WALL, 10), stone, SLATE)
	B.block(CF(0, 35.5, 695), V(24, 19, 10), stone, SLATE)
	B.block(CF(0, WALL / 2, 905), V(220, WALL, 10), stone, SLATE)
	B.block(CF(-105, WALL / 2, 800), V(10, WALL, 220), stone, SLATE)
	B.block(CF(105, WALL / 2, 800), V(10, WALL, 220), stone, SLATE)
	-- dark band and battlements
	for _, w in ipairs({
		{ CF(0, 30, 690.4), V(220, 2, 0.6) }, { CF(0, 30, 909.6), V(220, 2, 0.6) },
		{ CF(-109.6, 30, 800), V(0.6, 2, 220) }, { CF(109.6, 30, 800), V(0.6, 2, 220) },
	}) do
		B.block(w[1], w[2], dark, SLATE)
	end
	for i = 0, 26 do
		local t = -104 + i * 8
		for _, z in ipairs({ 691.5, 908.5 }) do
			B.block(CF(t, WALL + 2, z), V(3.5, 4, 3), dark, SLATE)
		end
		for _, x in ipairs({ -108.5, 108.5 }) do
			B.block(CF(x, WALL + 2, 696 + i * 8), V(3, 4, 3.5), dark, SLATE)
		end
	end
	for _, c in ipairs({ V(-110, 0, 690), V(110, 0, 690), V(-110, 0, 910), V(110, 0, 910) }) do
		B.cyl(c.X, 0, c.Z, 14, 60, stone, SLATE)
		B.cyl(c.X, 59.4, c.Z, 14.4, 0.8, dark, SLATE)
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			B.block(CF(c.X + math.cos(a) * 13, 62, c.Z + math.sin(a) * 13) * CFrame.Angles(0, -a, 0), V(3, 4, 3.5), dark, SLATE)
		end
		B.torch(V(c.X, 61.2, c.Z))
	end
	-- banners on the front wall
	for _, x in ipairs({ -40, 40 }) do
		B.block(CF(x, 32, 689.6), V(8, 18, 0.3), Color3.fromRGB(110, 34, 30), Enum.Material.Fabric)
		B.block(CF(x, 33, 689.4), V(3, 3, 0.2), P.Gold, Enum.Material.Metal)
	end

	-- ramp up the inside of the east wall to the wall walk
	B.ramp(V(94, 2, 785), V(94, WALL, 880), 12, dark, SLATE)
	B.block(CF(99, WALL - 1, 886), V(12, 2, 12), dark, SLATE)
	B.carrotLine(V(94, 10, 800), V(94, 38, 865), 3)
	B.carrotLine(V(-60, WALL + 3, 905), V(60, WALL + 3, 905), 3)
	-- steps around the north-east tower
	for i, a in ipairs({ math.pi - 0.55, math.pi - 1.15, math.pi - 1.75 }) do
		local top = WALL + 5 * i
		B.block(CF(110 + math.cos(a) * 18, top - 1, 690 + math.sin(a) * 18) * CFrame.Angles(0, -a, 0), V(7, 2, 7), dark, SLATE)
	end
	B.golden("rampart", V(110, 66, 690))

	----------------------------------------------------------------- courtyard
	B.block(CF(0, 1, 800), V(200, 2, 200), Color3.fromRGB(84, 78, 76), SLATE)
	B.checkpointFlag("courtyard")
	B.bug(V(0, 2, 790), "castle")
	B.bug(V(20, 2, 805), "castle")

	-- Firebar Gauntlet (west half)
	B.lava(CF(-60, 2.4, 752), V(80, 0.8, 96))
	local plats = {
		{ -26, 712, 6 }, { -42, 727, 9 }, { -58, 741, 12 }, { -72, 756, 15 }, { -84, 772, 18 }, { -90, 790, 21 },
	}
	local speeds = { 0, 1.7, -1.9, 2.1, -2.3, -1.2 }
	for i, pl in ipairs(plats) do
		B.cyl(pl[1], 0, pl[2], 6, pl[3], dark, SLATE)
		B.cyl(pl[1], pl[3] - 0.5, pl[2], 6.3, 0.5, P.Ember, Enum.Material.Neon)
		if speeds[i] ~= 0 then
			B.firebar(V(pl[1], pl[3] + 2.6, pl[2]), i == 6 and 12 or 10, speeds[i], i)
		end
		if i == 1 or i == 3 or i == 5 then
			B.carrot(V(pl[1] + 4, pl[3] + 3.5, pl[2]))
		end
	end
	B.golden("firebar", V(-93, 26, 793))
	B.sign(V(-12, 2, 708), V(0, 0, -1), "FIREBAR GAUNTLET", "Timing is everything", dark, Color3.fromRGB(230, 200, 170))

	-- Crusher Hall (east half)
	B.block(CF(65, 14, 732), V(70, 24, 2), dark, SLATE)
	B.block(CF(65, 14, 768), V(70, 24, 2), dark, SLATE)
	B.block(CF(65, 27, 750), V(70, 2, 38), dark, SLATE)
	for i, x in ipairs({ 40, 52, 64, 76, 88 }) do
		B.crusher(CF(x, 20, 750), V(9, 10, 33), 13, 2.6, i * 0.45)
		if i < 5 then
			B.carrot(V(x + 6, 5, 750))
		end
	end
	for _, x in ipairs({ 35, 95 }) do
		B.torch(V(x, 3.2, 734.5))
	end
	B.golden("thwomp", V(96, 7, 750))
	B.sign(V(26, 2, 742), V(-1, 0, 0), "CRUSHER HALL", "Wait for them to rise...", dark, Color3.fromRGB(230, 200, 170))

	----------------------------------------------------------------- the keep
	do
		local TOP = 64
		B.block(CF(-34, 33, 822), V(52, 62, 4), stone, SLATE)
		B.block(CF(34, 33, 822), V(52, 62, 4), stone, SLATE)
		B.block(CF(0, 41, 822), V(16, 46, 4), stone, SLATE)
		B.block(CF(0, 33, 893), V(120, 62, 4), stone, SLATE)
		B.block(CF(-58, 33, 857.5), V(4, 62, 67), stone, SLATE)
		B.block(CF(58, 33, 857.5), V(4, 62, 67), stone, SLATE)
		-- roof with a hole above the north-west corner
		B.block(CF(11, TOP - 1, 857.5), V(90, 2, 67), dark, SLATE)
		B.block(CF(-45, TOP - 1, 868.5), V(22, 2, 45), dark, SLATE)
		for i = 0, 14 do
			B.block(CF(-56 + i * 8, TOP + 2, 821.5), V(3.5, 4, 3), dark, SLATE)
			B.block(CF(-56 + i * 8, TOP + 2, 893.5), V(3.5, 4, 3), dark, SLATE)
		end
		B.block(CF(0, 20, 819.8), V(18, 4, 0.6), Color3.fromRGB(110, 34, 30), Enum.Material.Fabric)

		B.lava(CF(0, 2.4, 857.5), V(112, 0.8, 67))
		B.block(CF(0, 2, 832), V(20, 4, 16), dark, SLATE)
		B.checkpointFlag("keep")
		for _, p in ipairs({ V(-54.5, 20, 857), V(54.5, 20, 857), V(0, 20, 889.5), V(-54.5, 45, 840), V(54.5, 45, 870) }) do
			B.torch(p)
		end

		local function perimeter(u)
			if u < 100 then
				return V(-50 + u, 0, 830)
			elseif u < 155 then
				return V(50, 0, 830 + (u - 100))
			elseif u < 255 then
				return V(50 - (u - 155), 0, 885)
			else
				return V(-50, 0, 885 - (u - 255))
			end
		end
		for k = 0, 16 do
			local p = perimeter(66 + 15 * k)
			local top = 6 + 3.2 * k
			local ledge = B.block(CF(p.X, top - 1, p.Z), V(9, 2, 9), stone, SLATE)
			if k == 6 or k == 11 then
				B.bobber(ledge, 3, 1.6, k)
			elseif k == 15 then
				B.slider(ledge, V(0, 0, 4), 1.3, 0)
			elseif k == 4 or k == 9 or k == 13 then
				B.firebar(V(p.X, top + 2.6, p.Z), 8, k == 9 and -2.2 or (k == 4 and 2.0 or 2.5), k)
			end
			if k == 2 or k == 7 or k == 12 then
				B.carrot(V(p.X, top + 3.5, p.Z))
			end
		end
		B.golden("keep", V(-50, 62, 834))

		-- the throne room portal on the roof
		local portal = B.cyl(20, TOP - 0.2, 870, 6, 1, Color3.fromRGB(90, 40, 60), Enum.Material.Neon)
		portal.Name = "ThronePortal"
		portal:SetAttribute("ThronePortal", true)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ThronePrompt"
		prompt.ActionText = "Enter"
		prompt.ObjectText = "Throne Room"
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = portal
		B.gate(CF(20, TOP + 8, 870), V(14, 16, 14), Config.ThroneGate, Color3.fromRGB(150, 60, 70))
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2 + math.pi / 4
			B.cyl(20 + math.cos(a) * 9, TOP, 870 + math.sin(a) * 9, 1, 10, dark, SLATE)
			B.torch(V(20 + math.cos(a) * 9, TOP + 11.2, 870 + math.sin(a) * 9))
		end
	end

	----------------------------------------------------------------- the dungeon (outside the east wall)
	do
		B.block(CF(150, 15, 721), V(40, 30, 2), dark, SLATE)
		B.block(CF(210, 15, 721), V(40, 30, 2), dark, SLATE)
		B.block(CF(180, 22, 721), V(20, 16, 2), dark, SLATE)
		B.block(CF(180, 15, 879), V(100, 30, 2), dark, SLATE)
		B.block(CF(131, 15, 800), V(2, 30, 160), dark, SLATE)
		B.block(CF(229, 15, 800), V(2, 30, 160), dark, SLATE)
		B.block(CF(180, 31, 800), V(100, 2, 160), Color3.fromRGB(44, 40, 42), SLATE)
		B.sign(V(166, 0, 712), V(0, 0, -1), "THE DUNGEON", "Abandon hope, bring carrots", dark, Color3.fromRGB(230, 200, 170))
		B.checkpointFlag("dungeon")

		B.lava(CF(180, 0.6, 806), V(96, 0.8, 144))
		B.block(CF(180, 1.5, 728), V(96, 3, 12), stone, SLATE)
		-- 1: stepping blocks (one sinks)
		for i, step in ipairs({ { 742, 4 }, { 754, 6 }, { 766, 8 }, { 778, 6 } }) do
			local b = B.block(CF(150, step[2] - 1, step[1]), V(6, 2, 6), stone, SLATE)
			if i == 2 then
				B.bobber(b, 2.6, 1.3, 0)
			end
		end
		-- 2: sliding platform
		local slide = B.block(CF(180, 6, 790), V(10, 2, 10), P.Wood, Enum.Material.WoodPlanks)
		B.slider(slide, V(24, 0, 0), 0.8, math.pi)
		B.block(CF(214, 3.5, 790), V(12, 7, 12), stone, SLATE)
		B.carrot(V(180, 11, 790))
		-- 3: narrow beam swept by firebars
		B.block(CF(214, 6, 821), V(3, 2, 50), dark, SLATE)
		for _, fz in ipairs({ 808, 834 }) do
			B.cyl(221, 0, fz, 1.5, 7, dark, SLATE)
			B.firebar(V(221, 9.6, fz), 11, fz == 808 and 1.4 or -1.6, fz)
		end
		B.carrot(V(214, 10, 821))
		B.block(CF(214, 4, 852), V(12, 8, 12), stone, SLATE)
		-- 4: sinking platforms
		for i, x in ipairs({ 198, 184, 170, 156 }) do
			local b = B.block(CF(x, 7, 860), V(7, 2, 7), stone, SLATE)
			B.bobber(b, 3.2, 1.2, i * 1.3)
			if i % 2 == 0 then
				B.carrot(V(x, 12, 860))
			end
		end
		B.block(CF(140, 5, 862), V(14, 10, 20), stone, SLATE)
		B.golden("dungeon", V(140, 15, 864))
		B.exitPrompt(V(140, 10.5, 856), "dungeon", "Leave dungeon")
		for _, p in ipairs({ V(133, 10, 760), V(133, 10, 840), V(227, 10, 760), V(227, 10, 840), V(180, 10, 877) }) do
			B.torch(p)
		end
		-- hanging cages
		for _, p in ipairs({ V(165, 18, 800), V(195, 20, 840) }) do
			for _, d in ipairs({ V(-2, 0, -2), V(2, 0, -2), V(-2, 0, 2), V(2, 0, 2) }) do
				B.block(CF(p + d), V(0.3, 6, 0.3), Color3.fromRGB(60, 58, 58), Enum.Material.Metal)
			end
			B.block(CF(p + V(0, 3, 0)), V(4.4, 0.4, 4.4), Color3.fromRGB(60, 58, 58), Enum.Material.Metal)
			B.block(CF(p + V(0, 8, 0)), V(0.2, 10, 0.2), Color3.fromRGB(60, 58, 58), Enum.Material.Metal)
		end
	end

	----------------------------------------------------------------- the throne room (boss arena)
	do
		local A = Castle.ArenaCenter
		-- a ring of lava around the edge (the stone floor sits slightly higher)
		local rim = B.cyl(A.X, A.Y - 3.8, A.Z, 55, 4, P.Lava, Enum.Material.Neon)
		rim.Name = "ArenaRim"
		rim:SetAttribute("Lava", true)
		B.cyl(A.X, A.Y - 4, A.Z, 52, 4.4, stone, SLATE)
		B.cyl(A.X, A.Y, A.Z, 22, 0.42, dark, SLATE)
		for i, r in ipairs({ 46, 34, 20 }) do
			B.cyl(A.X, A.Y - 4 - i * 6, A.Z, r, 6, P.BasaltLight, BASALT, B.decor)
		end
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2 + math.pi / 4
			local px, pz = A.X + math.cos(a) * 34, A.Z + math.sin(a) * 34
			local pillar = B.cyl(px, A.Y, pz, 4.5, 16, stone, SLATE)
			pillar.Name = "ArenaPillar"
			B.torch(V(px, A.Y + 17.2, pz))
		end
		B.golden("boss", A + V(0, 5, 0))
		B.exitPrompt(Config.Checkpoints.throne.pos + V(10, -6, 0), "courtyard", "Return to courtyard")
	end

	----------------------------------------------------------------- scenery
	for _ = 1, 30 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(150, 245)
		local p = V(math.cos(a) * r, 0, 800 + math.sin(a) * r)
		local inDungeon = p.X > 120 and p.X < 240 and p.Z > 710 and p.Z < 890
		local onApproach = math.abs(p.X) < 40 and p.Z < 700
		if not inDungeon and not onApproach and (p.Z < 680 or p.Z > 920 or math.abs(p.X) > 125) then
			B.rock(p.X, 0, p.Z, rng:NextNumber(1.5, 3.5), rng:NextNumber() < 0.5 and P.Basalt or P.BasaltLight)
		end
	end
end

return Castle
