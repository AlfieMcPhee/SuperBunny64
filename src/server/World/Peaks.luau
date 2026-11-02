--[[
	Frostbite Peaks - a snowy island north of the meadow.
	  * A terraced mountain with winding ramps up to the summit
	  * A long ice slide chute spiralling down the outside of the mountain
	  * A giant snowman wearing a very tall hat
	  * A freezing pond with drifting ice floes
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local Peaks = {}

function Peaks.Build(B)
	local P = B.P
	local rng = B.rng
	local V = Vector3.new
	local cx, cz = 0, -720
	local C = V(cx, 0, cz)
	local SNOW = Enum.Material.Snow

	B.island(cx, cz, 230, 0, P.Snow, P.SnowShade, SNOW, P.Rock)
	-- snow drifts and frost-shattered rocks on the open ground around the mountain
	for i = 0, 27 do
		local a = i / 28 * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local r = rng:NextNumber(158, 222)
		local near = function(ang, w)
			return math.abs(((a - ang + math.pi) % (2 * math.pi)) - math.pi) < w
		end
		if not (near(0, 0.32) or near(1.0, 0.25) or near(0.6 * math.pi, 0.15) or near(math.pi / 2, 0.15)) then
			local p = C + V(math.cos(a) * r, 0, math.sin(a) * r)
			if i % 3 == 0 then
				B.outcrop(p + V(0, -2, 0), rng:NextNumber(4, 7), Enum.Material.Rock)
			else
				B.hill(p.X, p.Z, rng:NextNumber(8, 16), rng:NextNumber(2, 4), SNOW)
			end
		end
	end

	----------------------------------------------------------------- mountain
	local tiers = {
		{ r = 150, top = 6 }, { r = 130, top = 24 }, { r = 104, top = 42 }, { r = 80, top = 60 },
		{ r = 58, top = 78 }, { r = 38, top = 96 }, { r = 20, top = 114 },
	}
	for _, t in ipairs(tiers) do
		B.mound(cx, cz, t.r, t.top, P.Snow, 0, P.Rock, SNOW, Enum.Material.Slate)
	end
	-- glacier ice streaks and exposed rock on the mountain tiers
	for i = 1, #tiers - 1 do
		local a = i * 1.3
		local r = (tiers[i].r + tiers[i + 1].r) / 2
		local p = C + V(math.cos(a) * r, tiers[i].top, math.sin(a) * r)
		B.paint(p, p + V(math.cos(a + 1.5) * 18, 0, math.sin(a + 1.5) * 18), 8, Enum.Material.Glacier, { SNOW })
		B.outcrop(C + V(math.cos(a + 3) * (tiers[i].r - 2), tiers[i].top - 6, math.sin(a + 3) * (tiers[i].r - 2)), 5, Enum.Material.Rock)
	end
	for i = 1, #tiers - 1 do
		local r1 = tiers[i + 1].r
		local top0, top1 = tiers[i].top, tiers[i + 1].top
		local a = 0.6 + i * 2.0
		local rho = r1 + 7
		local tangent = V(-math.sin(a), 0, math.cos(a))
		local mid = C + V(math.cos(a) * rho, 0, math.sin(a) * rho)
		local low = mid - tangent * 22 + V(0, top0, 0)
		local high = mid + tangent * 22 + V(0, top1, 0)
		B.ramp(low, high, 10, P.SnowShade, SNOW)
		-- landing pad joining the top of the ramp to the tier above
		local flat = V(high.X, 0, high.Z) - C
		local dir = flat.Unit
		local inner, outer = r1 - 4, flat.Magnitude + 5
		local center = C + dir * ((inner + outer) / 2) + V(0, top1 - 1, 0)
		B.block(CFrame.lookAt(center, center + dir), V(12, 2, outer - inner), P.Snow, SNOW)
		B.carrot((low + high) / 2 + V(0, 3, 0))
	end
	B.golden("summit", V(cx, 119, cz))
	B.pineTree(cx + 10, 114, cz + 6, 0.6, P.Pine, true)

	----------------------------------------------------------------- the slide chute
	do
		local N = 36
		local function point(s)
			local th = math.pi + 1.6 * math.pi * s
			local R = 45 + 130 * s
			return V(cx + math.cos(th) * R, 96 - 74 * s, cz + math.sin(th) * R)
		end
		local up = V(0, 1, 0)
		for k = 0, N - 1 do
			local a, b = point(k / N), point((k + 1) / N)
			local dir = (b - a).Unit
			local floor = B.plank(a, b + dir * 0.8, 13, 1.5, P.Ice, Enum.Material.Ice)
			floor:SetAttribute("Slide", true)
			floor.Name = "Chute"
			local right = dir:Cross(up).Unit
			for _, s in ipairs({ -1, 1 }) do
				local off = right * s * 6.8 + up * 1.6
				B.plank(a + off, b + dir * 0.8 + off, 0.8, 3.2, P.Snow, SNOW)
			end
			if k % 4 == 0 then
				local support = B.cyl(a.X, 0, a.Z, 1.4, a.Y - 1.5, P.Rock, nil, B.decor)
				support.CanCollide = false
			end
			if k % 6 == 3 then
				B.carrot(a + V(0, 3, 0))
			end
		end
		-- entrance from the second-highest tier
		B.block(CFrame.new(cx - 40, 95, cz), V(22, 2, 16), P.Snow, SNOW)
		B.sign(V(cx - 34, 96, cz + 9), V(1, 0, 0), "ICE CHUTE", "Slide down, steer with the stick")
		-- landing pillar at the bottom
		local th = math.pi + 1.6 * math.pi
		local ex, ez = cx + math.cos(th) * 188, cz + math.sin(th) * 188
		B.cyl(ex, 0, ez, 12, 22, P.Rock, Enum.Material.Slate)
		B.cyl(ex, 21, ez, 12.4, 1, P.Snow, SNOW)
		B.golden("chute", V(ex, 27, ez))
	end

	----------------------------------------------------------------- giant snowman
	do
		local a = 1.0
		local sx, sz = cx + math.cos(a) * 180, cz + math.sin(a) * 180
		local snowBall = function(y, r)
			return B.ball(V(sx, y, sz), r, P.Snow, SNOW)
		end
		snowBall(13, 14)
		snowBall(34, 10)
		snowBall(49, 7)
		local face = V(cx, 0, cz) - V(sx, 0, sz)
		face = face.Unit
		local right = face:Cross(V(0, 1, 0))
		for _, s in ipairs({ -1, 1 }) do
			B.blob(V(sx, 51, sz) + face * 6.4 + right * s * 2.2, V(1.3, 1.3, 1.3), P.Ink)
		end
		local nose = CFrame.lookAt(V(sx, 49, sz) + face * 7.5, V(sx, 49, sz) + face * 20)
		B.make("Part", {
			Shape = Enum.PartType.Cylinder,
			Size = V(5, 1.4, 1.4),
			CFrame = nose * CFrame.new(0, 0, -2) * CFrame.Angles(0, math.pi / 2, 0),
			Color = P.Carrot,
			CanCollide = false,
		}, B.decor)
		for i = 0, 3 do
			B.blob(V(sx, 34 - i * 4 + 6, sz) + face * (9.6 - math.abs(i - 1.5) * 0.4), V(1.2, 1.2, 1.2), P.Ink)
		end
		B.cyl(sx, 54.5, sz, 9, 1.2, Color3.fromRGB(40, 36, 40))
		B.cyl(sx, 55.7, sz, 5.5, 8, Color3.fromRGB(40, 36, 40))
		B.cyl(sx, 56.2, sz, 5.6, 1.4, P.Roof, Enum.Material.Fabric)
		B.golden("snowman", V(sx, 68, sz))
		for i = 0, 9 do
			local pa = a + math.pi + i * 0.5
			local px, pz = sx + math.cos(pa) * 22, sz + math.sin(pa) * 22
			local top = 8 + i * 6
			B.cyl(px, 0, pz, 3, top, P.Ice, Enum.Material.Ice)
			if i % 2 == 1 then
				B.carrot(V(px, top + 3.5, pz))
			end
		end
	end

	----------------------------------------------------------------- frozen pond with drifting floes
	do
		local px, pz = cx + 190, cz
		local center = V(px, 0, pz)
		B.cyl(px, -0.4, pz, 39, 0.8, P.Ice, Enum.Material.Ice)
		local pond = B.cyl(px, -0.5, pz, 36, 1.05, Color3.fromRGB(70, 110, 124), Enum.Material.Glass)
		pond.Transparency = 0.1
		pond.Name = "FreezingWater"
		pond:SetAttribute("Water", true)
		for i = 0, 2 do
			local floe = B.cyl(px + 26, 0.3, pz, 4.5, 1.6, P.Ice, Enum.Material.Ice)
			B.orbiter(floe, center, 26, 0.3, i * math.pi * 2 / 3)
		end
		for i = 0, 1 do
			local floe = B.cyl(px + 13, 0.3, pz, 4, 1.6, P.Ice, Enum.Material.Ice)
			B.orbiter(floe, center, 13, -0.45, i * math.pi)
		end
		B.cyl(px, 0, pz, 5, 2.5, P.Snow, SNOW)
		B.golden("floes", V(px, 7, pz))
		B.carrotRing(V(px, 3.5, pz), 42, 6)
		B.sign(V(px - 46, 0, pz - 10), V(-1, 0, 0), "FROZEN POND", "Brrr! Don't fall in")
	end

	----------------------------------------------------------------- arrival, warp and checkpoint
	B.checkpointFlag("peaks")
	B.warpBurrow(Config.Warps[2])
	B.carrotLine(V(-20, 3, -540), V(20, 3, -540), 5)

	----------------------------------------------------------------- scenery & bugs
	local function clear(p)
		local rel = p - C
		local r = rel.Magnitude
		if r < 156 or r > 222 then
			return false
		end
		local ang = math.atan2(rel.Z, rel.X)
		local function near(a, width)
			local d = math.abs(((ang - a + math.pi) % (2 * math.pi)) - math.pi)
			return d < width
		end
		if near(0, 0.3) or near(1.0, 0.25) or near(0.6 * math.pi, 0.15) or near(math.pi / 2, 0.15) then
			return false
		end
		return true
	end
	local placed = 0
	for _ = 1, 500 do
		if placed >= 40 then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(158, 222)
		local p = C + V(math.cos(a) * r, 0, math.sin(a) * r)
		if clear(p) then
			B.pineTree(p.X, B.groundY(p.X, p.Z, 60), p.Z, rng:NextNumber(0.8, 1.3), P.Pine, true)
			placed += 1
		end
	end
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2 + 0.2
		local p = C + V(math.cos(a) * 170, 0, math.sin(a) * 170)
		if clear(p) then
			B.blob(CFrame.new(p + V(0, 3, 0)) * CFrame.Angles(0.2, a, 0.3), V(2.5, 8, 2.5), P.Ice, Enum.Material.Ice, B.solid, true)
		end
	end
	for _, b in ipairs({ { 0.3, 175 }, { 2.2, 180 }, { 3.6, 190 }, { 4.5, 175 }, { 5.6, 185 } }) do
		B.bug(C + V(math.cos(b[1]) * b[2], 0, math.sin(b[1]) * b[2]), "peaks")
	end
	B.bug(C + V(math.cos(3.0) * 140, 24, math.sin(3.0) * 140), "peaks")
	-- frostbats guard the mountain and the pond; puffshrooms in the snow; a snowy toad
	B.enemy("bat", C + V(math.cos(2.6) * 120, 40, math.sin(2.6) * 120), "peaks")
	B.enemy("bat", C + V(math.cos(4.6) * 90, 62, math.sin(4.6) * 90), "peaks")
	B.enemy("bat", C + V(190, 14, 0), "peaks")
	B.enemy("bat", C + V(math.cos(0.3) * 50, 104, math.sin(0.3) * 50), "peaks")
	B.enemy("puffshroom", C + V(math.cos(4.0) * 190, 0, math.sin(4.0) * 190), "peaks")
	B.enemy("puffshroom", C + V(math.cos(5.3) * 175, 0, math.sin(5.3) * 175), "peaks")
	B.enemy("toad", C + V(math.cos(3.3) * 185, 0, math.sin(3.3) * 185), "peaks", 20)
	B.bug(C + V(math.cos(5.0) * 92, 42, math.sin(5.0) * 92), "peaks")
end

return Peaks
