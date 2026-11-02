--[[
	The Underburrow - a secret dungeon floating in the dark, far from every
	other land. You get here by ground-pounding through the lid of the old well
	in the meadow (Config.SecretGate golden carrots), and it is meant to be HARD.

	  Entrance        Old Whiskers, a sign, a way back up
	  Crumbling Path  tiles that fall a moment after you land on them
	  Firebar Beam    a narrow beam with three spinning firebars
	  The Depths      the only checkpoint
	  Blink Bridge    two sets of blocks that swap in and out on a beat
	  The Chimney     wall-jump straight up between two walls
	  The Gaps        long jumps between pillars (the Heart of the Underburrow floats here)
	  Shade's Arena   the Shade waits at the bottom of the dark

	Falling into the dark costs a heart and puts you back where you last stood
	(see the server's void check). Crumbling and blinking blocks are worked on
	each player's own screen by client/WorldFX, so they react instantly.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local Secret = {}

local STONE = Color3.fromRGB(70, 62, 82)
local STONE_DARK = Color3.fromRGB(46, 40, 56)
local TRIM = Color3.fromRGB(110, 96, 130)
local CRYSTAL = Color3.fromRGB(160, 120, 230)

function Secret.Build(B)
	local P = B.P
	local V = Vector3.new
	local M = Enum.Material
	local X = -1400

	local function slab(cx, top, cz, sx, sz, thick, color)
		thick = thick or 4
		local p = B.block(CFrame.new(cx, top - thick / 2, cz), V(sx, thick, sz), color or STONE, M.Slate)
		-- a lighter rim so edges read clearly in the dark
		local rim = B.block(CFrame.new(cx, top - 0.2, cz), V(sx + 0.3, 0.5, sz + 0.3), TRIM, M.Slate, B.decor)
		rim.CanCollide = false
		rim.CanQuery = false
		-- jagged rock hanging underneath
		local hang = B.blob(V(cx, top - thick - sx * 0.25, cz), V(sx * 0.8, sx * 0.6, sz * 0.8), STONE_DARK, M.Slate)
		hang.CastShadow = false
		return p
	end

	local function crystal(pos, s)
		s = s or 1
		local c = B.make("Part", {
			Size = V(1.2, 3.4, 1.2) * s,
			CFrame = CFrame.new(pos + V(0, 1.6 * s, 0)) * CFrame.Angles(0.15, math.random() * 6, 0.2),
			Color = CRYSTAL,
			Material = M.Neon,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		}, B.decor)
		local light = Instance.new("PointLight")
		light.Color = CRYSTAL
		light.Range = 18 * s
		light.Brightness = 1.1
		light.Parent = c
	end

	local function markUnsafe(p)
		p:SetAttribute("Unsafe", true) -- the server never respawns you onto it
	end

	--------------------------------------------------------------- entrance
	slab(X, 150, -1400, 34, 34)
	B.checkpointFlag("underburrow", V(-9, 0, 2))
	B.npc("whiskers", X + 10, -1392, V(-1, 0, -0.3), 170)
	B.sign(V(X - 6, 150, -1414), V(0, 0, 1), "THE UNDERBURROW", "Turn back, little bunny.")
	B.exitPrompt(V(X - 12, 150.5, -1390), "meadow", "Climb back up")
	for _, c in ipairs({ { -14, -14 }, { 14, -14 }, { -14, 14 }, { 14, 14 } }) do
		crystal(V(X + c[1], 150, -1400 + c[2]), 1.2)
	end
	B.crate(X + 8, -1408, 170)

	--------------------------------------------------------------- Crumbling Path
	for k = 0, 7 do
		local z = -1426 - k * 10
		local x = X + ((k % 2 == 0) and -4 or 4)
		local top = 150 + k
		local tile = B.block(CFrame.new(x, top - 0.75, z), V(7, 1.5, 7), Color3.fromRGB(120, 100, 86), M.Cobblestone)
		tile.Name = "CrumbleTile"
		tile:SetAttribute("Crumble", true)
		markUnsafe(tile)
		if k % 2 == 1 then
			B.carrot(V(x, top + 3, z))
		end
	end
	B.sign(V(X + 12, 150, -1416), V(0, 0, 1), "CRUMBLING PATH", "Don't stop moving")

	--------------------------------------------------------------- Firebar Beam
	slab(X, 158, -1515, 20, 20, 5)
	B.firebar(V(X, 159.6, -1515), 9, 1.4, 0)
	crystal(V(X - 8, 158, -1507))
	crystal(V(X + 8, 158, -1523))
	B.block(CFrame.new(X, 157, -1545), V(3, 2, 40), STONE, M.Slate)
	local beamRim = B.block(CFrame.new(X, 157.9, -1545), V(3.3, 0.4, 40), TRIM, M.Slate, B.decor)
	beamRim.CanCollide = false
	for i, f in ipairs({ { -1534, 2.0 }, { -1547, -2.4 }, { -1559, 2.8 } }) do
		B.firebar(V(X, 159.6, f[1]), 6, f[2], i * 1.3, true) -- no post: jump over the middle
	end
	B.carrotLine(V(X, 161, -1530), V(X, 161, -1562), 4)

	--------------------------------------------------------------- the Depths (checkpoint)
	slab(X, 158, -1578, 22, 22, 5)
	B.checkpointFlag("underburrow2", V(-8, 0, -4))
	B.crate(X + 7, -1572, 175)
	crystal(V(X - 9, 158, -1586), 1.3)
	crystal(V(X + 9, 158, -1586), 1.3)
	B.sign(V(X + 6, 158, -1588), V(0, 0, 1), "BLINK BRIDGE", "Jump on the beat")

	--------------------------------------------------------------- Blink Bridge
	for k = 0, 5 do
		local z = -1599 - k * 10
		local x = X + ((k % 2 == 0) and -3 or 3)
		local block = B.block(CFrame.new(x, 157.25, z), V(6, 1.5, 6), k % 2 == 0 and Color3.fromRGB(110, 170, 220) or Color3.fromRGB(220, 130, 170), M.Neon)
		block.Name = "BlinkBlock"
		block:SetAttribute("Blink", k % 2)
		block:SetAttribute("BlinkPeriod", 1.6)
		block.CastShadow = false
		markUnsafe(block)
	end

	--------------------------------------------------------------- The Chimney
	slab(X, 158, -1662, 24, 26, 5)
	for _, side in ipairs({ -1, 1 }) do
		B.block(CFrame.new(X + side * 5.5, 190, -1667), V(2, 64, 14), STONE, M.Slate)
		local stripe = B.block(CFrame.new(X + side * 4.45, 190, -1667), V(0.1, 64, 1), TRIM, M.Slate, B.decor)
		stripe.CanCollide = false
	end
	B.block(CFrame.new(X, 190, -1675), V(13, 64, 2), STONE_DARK, M.Slate) -- back wall
	B.firebar(V(X, 204, -1667), 3.8, 1.6, 0, true)
	B.sign(V(X + 9, 158, -1653), V(0, 0, 1), "THE CHIMNEY", "Wall jump, wall jump, wall jump...")
	for y = 172, 212, 20 do
		B.carrot(V(X, y, -1665))
	end
	slab(X, 222, -1690, 24, 26, 5)
	crystal(V(X - 9, 222, -1698), 1.2)
	crystal(V(X + 9, 222, -1698), 1.2)

	--------------------------------------------------------------- The Gaps (long jumps)
	for i, z in ipairs({ -1737, -1771, -1805 }) do
		B.cyl(X, 222 - 60, z, 3.5, 60, STONE, M.Slate)
		B.cyl(X, 221.6, z, 3.8, 0.5, TRIM, M.Slate)
		if i == 3 then
			B.golden("underburrow", V(X, 227, z))
		else
			B.carrot(V(X, 226, z))
		end
	end
	B.sign(V(X + 8, 222, -1701), V(0, 0, 1), "THE GAPS", "ROLL then JUMP. Breathe first.")

	--------------------------------------------------------------- Shade's Arena
	do
		local c = V(X, 222, -1842)
		local r = 28
		B.info.bossArenas = B.info.bossArenas or {}
		B.info.bossArenas.shade = { center = c, radius = r }
		B.cyl(c.X, c.Y - 6, c.Z, r, 6, STONE, M.Slate)
		B.cyl(c.X, c.Y - 0.3, c.Z, r + 0.4, 0.5, TRIM, M.Slate)
		B.cyl(c.X, c.Y - 0.05, c.Z, 6, 0.2, CRYSTAL, M.Neon).CanCollide = false
		local under = B.blob(c - V(0, 18, 0), V(r * 1.6, 26, r * 1.6), STONE_DARK, M.Slate)
		under.CastShadow = false
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2 + math.pi / 4
			local p = c + V(math.cos(a) * (r - 3), 0, math.sin(a) * (r - 3))
			B.cyl(p.X, c.Y, p.Z, 1.2, 14, STONE_DARK, M.Slate)
			crystal(p + V(0, 14, 0), 1.4)
		end
		B.golden("shade", c + V(0, 5, 0))
		B.exitPrompt(c + V(0, 0.5, r - 5), "meadow", "Climb out")
	end
end

return Secret
