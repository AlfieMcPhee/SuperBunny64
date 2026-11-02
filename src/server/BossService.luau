--[[
	BossService - King Grumble, the giant crowned Grumblebug in the throne room.

	His four glowing weak points sit on top of his shell. They are only
	exposed while he is dazed: after he charges into a stone pillar, or after
	a ground slam tires him out. Jump (or ground pound) onto a weak point to
	break it. Break all four to win.

	  sleep -> roar -> chase -> windup -> charge -> (stunned | recover -> slam -> tired) -> chase ...

	He gets nastier with every weak point you break:
	  phase 1  charges and slams
	  phase 2  + spits fireballs, lava bursts up under you while he chases
	  phase 3  + fireballs come in threes, he slams twice, calls in his bugs
	  phase 4  ENRAGED: faster, slams three times, rains lava, shorter daze
	Shared hazards (strikes, shockwaves, shots, minions) live in BossKit.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local BugModel = require(script.Parent:WaitForChild("BugModel"))
local BossKit = require(script.Parent:WaitForChild("BossKit"))
local RunService = game:GetService("RunService")

local BossService = {}

local SCALE = 3.4
local MAX_HP = 4
local arena
local cb
local boss = { minions = {} }
local pillars = {}
local folder

local function setState(name)
	boss.state = name
	boss.t0 = os.clock()
	if boss.model then
		boss.model:SetAttribute("State", name)
	end
end

local function exposed()
	return boss.state == "stunned" or boss.state == "tired"
end

local function build()
	if boss.model then
		boss.model:Destroy()
	end
	local model, _, root = BugModel.Build("castle", SCALE, CFrame.new())
	model.Name = "KingGrumble"
	-- crown
	local headY, headZ = 1.65 * SCALE, -2.9 * SCALE
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.Metal
		p.Color = Config.Palette.Gold
		p.Size = Vector3.new(0.9, 2.2, 0.6)
		p.CFrame = CFrame.new(math.cos(a) * 2.6, headY + 3.4, headZ + math.sin(a) * 2.2) * CFrame.Angles(0, -a, 0)
		p.Parent = model
	end
	local band = Instance.new("Part")
	band.Shape = Enum.PartType.Cylinder
	band.Anchored = true
	band.CanCollide = false
	band.CanQuery = false
	band.CanTouch = false
	band.Material = Enum.Material.Metal
	band.Color = Config.Palette.Gold
	band.Size = Vector3.new(1.2, 5.6, 5.6)
	band.CFrame = CFrame.new(0, headY + 2.6, headZ) * CFrame.Angles(0, 0, math.pi / 2)
	band.Parent = model
	-- weak points
	boss.spots = {}
	for _, lp in ipairs({ Vector3.new(-1.15, 3.2, 1.5), Vector3.new(1.15, 3.2, 1.5), Vector3.new(0, 3.15, -0.6), Vector3.new(0, 2.9, 2.9) }) do
		local s = Instance.new("Part")
		s.Name = "WeakPoint"
		s.Anchored = true
		s.CanCollide = false
		s.CanQuery = false
		s.CanTouch = false
		s.Size = Vector3.new(1.4, 0.9, 1.4) * SCALE
		s.CFrame = CFrame.new(lp * SCALE)
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = s
		s.Parent = model
		table.insert(boss.spots, { part = s, alive = true })
	end
	boss.shells = {}
	boss.body = {}
	for _, d in ipairs(model:GetChildren()) do
		if d.Name == "Shell" then
			table.insert(boss.shells, d)
		end
		if d:IsA("BasePart") and d.Name ~= "WeakPoint" then
			boss.body[d] = d.Color
		end
	end
	boss.model = model
	boss.root = root
	BossKit.Tag(model, "grumble", "KING GRUMBLE", MAX_HP, arena, "JUMP ON A GLOWING SPOT!")
	model.Parent = folder
end

local function reset()
	BossKit.Clear(boss)
	build()
	boss.pos = arena.center
	boss.yaw = 0
	boss.hp = MAX_HP
	boss.model:SetAttribute("HP", MAX_HP)
	boss.lastFire = 0
	boss.lastLava = 0
	boss.slams = 0
	boss.enraged = false
	setState("sleep")
end

local function place(extraY, tilt)
	boss.model:PivotTo(CFrame.new(boss.pos + Vector3.new(0, 1.8 * SCALE + (extraY or 0), 0)) * CFrame.Angles(0, boss.yaw, 0) * CFrame.Angles(tilt or 0, 0, 0))
end

local function refreshSpots()
	local on = exposed()
	for _, s in ipairs(boss.spots) do
		if s.alive then
			s.part.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			s.part.Color = on and Color3.fromRGB(240, 170, 70) or Color3.fromRGB(80, 50, 40)
		end
	end
	for _, sh in ipairs(boss.shells) do
		sh.CanCollide = on -- climb onto his back while he's dazed
	end
end

local function enrage()
	boss.enraged = true
	boss.model:SetAttribute("Enraged", true)
	for part in pairs(boss.body) do
		if part.Parent then
			part.Color = part.Color:Lerp(Color3.fromRGB(200, 50, 30), 0.45)
		end
	end
	cb.effect("bossroar", boss.pos, { name = "KING GRUMBLE", title = "...IS FURIOUS!" })
end

local function faceTo(pos)
	local d = pos - boss.pos
	if Vector3.new(d.X, 0, d.Z).Magnitude > 0.1 then
		boss.yaw = math.atan2(-d.X, -d.Z)
	end
end

local function forward()
	return Vector3.new(-math.sin(boss.yaw), 0, -math.cos(boss.yaw))
end

local function spitFireball(target, spread)
	local from = boss.pos + Vector3.new(0, 3, 0) + forward() * 3.4 * SCALE
	local to = target.root.Position
	local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if dir.Magnitude < 0.1 then
		return
	end
	for _, ang in ipairs(spread and { -0.32, 0, 0.32 } or { 0 }) do
		local d = (CFrame.Angles(0, ang, 0) * dir.Unit)
		BossKit.projectile(boss, arena, Vector3.new(from.X, arena.center.Y + 3, from.Z), d * (boss.enraged and 42 or 36), { life = 4 })
	end
	cb.effect("fire", from)
end

local function slamLand()
	BossKit.shockwave(boss, arena, boss.pos, boss.enraged and 52 or 44, 64, arena.center.Y)
	if boss.enraged then
		-- a ring of lava bursts around him
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2 + math.random()
			BossKit.strike(boss, arena, boss.pos + Vector3.new(math.cos(a) * 20, 0, math.sin(a) * 20), { kind = "lava", radius = 6, delay = 1.1 })
		end
	end
end

-- Admin helper: put King Grumble back to full health, asleep in the middle
function BossService.Reset()
	if arena then
		reset()
		place(0)
	end
end

function BossService.Start(worldInfo, callbacks)
	cb = callbacks
	arena = BossKit.Arena(worldInfo.arenaCenter, worldInfo.arenaRadius, 80)
	folder = BossKit.Init(worldInfo, callbacks)
	for _, d in ipairs(worldInfo.solidFolder:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "ArenaPillar" then
			table.insert(pillars, Vector3.new(d.Position.X, arena.center.Y, d.Position.Z))
		end
	end
	reset()
	place(0)

	local emptySince = os.clock()
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local list = arena:players()
		if #list == 0 then
			if now - emptySince > 8 and (boss.state ~= "sleep" or boss.hp < MAX_HP) and boss.state ~= "dead" then
				reset()
				place(0)
			end
			if boss.state == "sleep" then
				return -- nobody here: nothing to do
			end
		else
			emptySince = now
		end
		local st = boss.state
		local age = now - boss.t0
		local phase = MAX_HP - boss.hp + 1 -- 1..4
		local target = arena:nearest(list, boss.pos)
		local lift, tilt = 0, 0

		if st == "sleep" then
			boss.yaw += dt * 0.2
			lift = math.sin(now * 1.5) * 0.3
			if #list > 0 then
				setState("roar")
				cb.effect("bossroar", boss.pos, { name = "KING GRUMBLE", title = "TYRANT OF THE INFERNAL CASTLE" })
			end
		elseif st == "roar" then
			if target then
				faceTo(target.root.Position)
			end
			tilt = math.sin(age * 20) * 0.04 + 0.12
			if age > 2 then
				setState("chase")
			end
		elseif st == "chase" then
			if target then
				faceTo(target.root.Position)
				local speed = 12 + 4 * phase + (boss.enraged and 4 or 0)
				boss.pos = arena:clamp(boss.pos + forward() * speed * dt)
				if phase >= 2 and now - boss.lastFire > (phase == 2 and 1.6 or 1.1) then
					boss.lastFire = now
					spitFireball(target, phase >= 3)
				end
				-- lava bursts up under whoever he's chasing
				if phase >= 2 and now - boss.lastLava > (boss.enraged and 1.4 or 2.6) then
					boss.lastLava = now
					for _, e in ipairs(list) do
						BossKit.strike(boss, arena, e.root.Position, { kind = "lava", radius = 5, delay = 1.0 })
					end
				end
			end
			lift = math.abs(math.sin(now * 10)) * 0.6
			if age > 3.2 - 0.35 * phase then
				setState("windup")
			end
		elseif st == "windup" then
			if target and age < 0.4 then
				faceTo(target.root.Position)
			end
			tilt = -0.18
			lift = math.sin(age * 40) * 0.25
			if age > 1.0 - 0.13 * phase then
				setState("charge")
				cb.effect("bosscharge", boss.pos)
			end
		elseif st == "charge" then
			local speed = 56 + 8 * phase
			local nextPos, hitEdge = arena:clamp(boss.pos + forward() * speed * dt)
			boss.pos = nextPos
			tilt = -0.08
			local bonk = false
			for _, pl in ipairs(pillars) do
				if (Vector3.new(boss.pos.X, 0, boss.pos.Z) - Vector3.new(pl.X, 0, pl.Z)).Magnitude < 4.5 + 2.6 * SCALE then
					bonk = true
				end
			end
			if bonk then
				setState("stunned")
				refreshSpots()
				cb.effect("bossbonk", boss.pos + Vector3.new(0, 3 * SCALE, 0))
			elseif hitEdge or age > 2.2 then
				setState("recover")
			end
		elseif st == "recover" then
			if age > 0.8 - 0.1 * phase then
				boss.slams = 0
				setState("slam")
			end
		elseif st == "slam" then
			local dur = boss.enraged and 0.95 or 1.1
			local u = math.clamp(age / dur, 0, 1)
			lift = math.sin(u * math.pi) * 22
			if target then
				faceTo(target.root.Position)
				boss.pos = arena:clamp(boss.pos + forward() * (boss.enraged and 30 or 22) * dt)
			end
			if age >= dur then
				slamLand()
				boss.slams += 1
				local slams = boss.enraged and 3 or (phase >= 3 and 2 or 1)
				if boss.slams < slams then
					setState("slam")
				else
					setState("tired")
					refreshSpots()
				end
			end
		elseif st == "stunned" or st == "tired" then
			tilt = math.sin(now * 3) * 0.06
			lift = -0.6
			if st == "stunned" then
				boss.yaw += math.sin(now * 5) * dt * 0.6
			end
			local hold = (st == "stunned" and 4.4 or 3.4) - 0.5 * (phase - 1)
			if age > hold then
				setState("chase")
				refreshSpots()
			end
		elseif st == "hurt" then
			tilt = math.sin(age * 30) * 0.1 -- clients flash him while State == "hurt"
			if age > 1.4 then
				if boss.hp <= 0 then
					setState("dying")
					BossKit.Clear(boss)
					cb.effect("bossdie", boss.pos + Vector3.new(0, 3 * SCALE, 0))
				else
					if boss.hp <= 2 and BossKit.minionCount(boss) < 3 then
						-- "GUARDS!" - a few of his bugs scuttle in from the edge
						for i = 1, (boss.hp == 1 and 3 or 2) do
							local a = math.random() * math.pi * 2
							BossKit.minion(boss, "bug", arena.center + Vector3.new(math.cos(a) * (arena.radius - 10), 0, math.sin(a) * (arena.radius - 10)), "castle")
						end
					end
					if boss.hp == 1 and not boss.enraged then
						enrage()
					end
					setState("chase")
				end
			end
		elseif st == "dying" then
			boss.yaw += dt * (4 + age * 6)
			lift = age * 4
			if age > 2.4 then
				cb.effect("poof", boss.pos + Vector3.new(0, 3 * SCALE, 0))
				boss.model.Parent = nil
				setState("dead")
				local winners = {}
				for _, e in ipairs(list) do
					table.insert(winners, e.player)
				end
				cb.defeated(winners)
			end
		elseif st == "dead" then
			if age > 45 and #list == 0 then
				reset()
			end
		end

		if boss.model.Parent then
			place(lift, tilt)
			boss.model:SetAttribute("Exposed", exposed())
		end

		-- Player interactions -------------------------------------------------
		if st ~= "dead" and st ~= "dying" and st ~= "sleep" then
			for _, e in ipairs(list) do
				local h = e.root.Position
				local feet = h.Y - 2.6
				local handled = false
				if exposed() then
					for _, s in ipairs(boss.spots) do
						if s.alive and BossKit.stomped(e, s.part.Position, 4.6) then
							local w = s.part.Position
							s.alive = false
							s.part.Parent = nil
							boss.hp -= 1
							boss.model:SetAttribute("HP", boss.hp)
							cb.bounce(e.player, Vector3.new(0, 80, 0))
							cb.effect("bosshit", w)
							setState("hurt")
							refreshSpots()
							handled = true
							break
						end
					end
				end
				if not handled and not exposed() and boss.state ~= "hurt" then
					local flat = Vector3.new(h.X - boss.pos.X, 0, h.Z - boss.pos.Z).Magnitude
					if flat < 3.2 * SCALE and feet < boss.pos.Y + 3.4 * SCALE then
						cb.hurt(e.player, boss.pos)
					end
				end
			end
		end
	end)
end

return BossService
