--[[
	BossService - King Grumble, the giant crowned Grumblebug in the throne room.

	His three glowing weak points sit on top of his shell. They are only
	exposed while he is dazed: after he charges into a stone pillar, or after
	a ground slam tires him out. Jump (or ground pound) onto a weak point to
	break it. Break all three to win.

	  sleep -> roar -> chase -> windup -> charge -> (stunned | recover -> slam -> tired) -> chase ...
	Each hit makes him faster; from the second phase he spits fireballs.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local BugModel = require(script.Parent:WaitForChild("BugModel"))

local BossService = {}

local SCALE = 3.4
local A, RADIUS
local cb
local boss = {}
local pillars = {}
local fireballs = {}
local waves = {}
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

local function playersInArena()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local p = root.Position
			if (Vector3.new(p.X, 0, p.Z) - Vector3.new(A.X, 0, A.Z)).Magnitude < RADIUS + 10 and p.Y > A.Y - 8 and p.Y < A.Y + 80 then
				table.insert(list, { player = player, root = root, hum = hum, char = char })
			end
		end
	end
	return list
end

local function nearest(list)
	local best, bestD = nil, math.huge
	for _, e in ipairs(list) do
		local d = (e.root.Position - boss.pos).Magnitude
		if d < bestD then
			best, bestD = e, d
		end
	end
	return best
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
	for _, lp in ipairs({ Vector3.new(-1.15, 3.2, 1.5), Vector3.new(1.15, 3.2, 1.5), Vector3.new(0, 3.15, -0.6) }) do
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
	for _, d in ipairs(model:GetChildren()) do
		if d.Name == "Shell" then
			table.insert(boss.shells, d)
		end
	end
	boss.model = model
	boss.root = root
	model:SetAttribute("Boss", true)
	model.Parent = folder
end

local function reset()
	build()
	boss.pos = A
	boss.yaw = 0
	boss.hp = 3
	boss.model:SetAttribute("HP", 3)
	boss.lastFire = 0
	boss.slams = 0
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

local function faceTo(pos)
	local d = pos - boss.pos
	if Vector3.new(d.X, 0, d.Z).Magnitude > 0.1 then
		boss.yaw = math.atan2(-d.X, -d.Z)
	end
end

local function forward()
	return Vector3.new(-math.sin(boss.yaw), 0, -math.cos(boss.yaw))
end

local function clampToArena(p)
	local flat = Vector3.new(p.X - A.X, 0, p.Z - A.Z)
	if flat.Magnitude > RADIUS - 8 then
		flat = flat.Unit * (RADIUS - 8)
		return Vector3.new(A.X + flat.X, A.Y, A.Z + flat.Z), true
	end
	return Vector3.new(p.X, A.Y, p.Z), false
end

local function spitFireball(target)
	local from = boss.pos + Vector3.new(0, 2 * SCALE, 0) + forward() * 3.4 * SCALE
	local to = target.root.Position
	local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if dir.Magnitude < 0.1 then
		return
	end
	local ball = Instance.new("Part")
	ball.Name = "Fireball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 3.2
	ball.Material = Enum.Material.Neon
	ball.Color = Config.Palette.Ember
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CFrame = CFrame.new(Vector3.new(from.X, A.Y + 3, from.Z))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 70)
	light.Range = 14
	light.Parent = ball
	ball.Parent = folder
	table.insert(fireballs, { part = ball, vel = dir.Unit * 36, die = os.clock() + 4 })
	cb.effect("fire", from)
end

local function slamLand()
	table.insert(waves, { center = boss.pos, t0 = os.clock(), speed = 44, maxR = 64, hit = {} })
	cb.effect("shockwave", boss.pos, 44)
end

local function hurtPlayer(e, fromPos)
	cb.hurt(e.player, fromPos)
end

-- Admin helper: put King Grumble back to full health, asleep in the middle
function BossService.Reset()
	if A then
		reset()
		place(0)
	end
end

function BossService.Start(worldInfo, callbacks)
	cb = callbacks
	A = worldInfo.arenaCenter
	RADIUS = worldInfo.arenaRadius
	folder = Instance.new("Folder")
	folder.Name = "Boss"
	folder.Parent = workspace
	for _, d in ipairs(worldInfo.solidFolder:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "ArenaPillar" then
			table.insert(pillars, Vector3.new(d.Position.X, A.Y, d.Position.Z))
		end
	end
	reset()
	place(0)

	local emptySince = os.clock()
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local list = playersInArena()
		if #list == 0 then
			if now - emptySince > 8 and (boss.state ~= "sleep" or boss.hp < 3) then
				reset()
				place(0)
			end
		else
			emptySince = now
		end
		local st = boss.state
		local age = now - boss.t0
		local phase = 4 - boss.hp -- 1, 2, 3
		local target = nearest(list)
		local lift, tilt = 0, 0

		if st == "sleep" then
			boss.yaw += dt * 0.2
			lift = math.sin(now * 1.5) * 0.3
			if #list > 0 then
				setState("roar")
				cb.effect("bossroar", boss.pos)
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
				local speed = 12 + 4 * phase
				boss.pos = clampToArena(boss.pos + forward() * speed * dt)
				if phase >= 2 and now - boss.lastFire > (phase == 2 and 1.5 or 0.9) then
					boss.lastFire = now
					spitFireball(target)
				end
			end
			lift = math.abs(math.sin(now * 10)) * 0.6
			if age > 3.2 - 0.4 * phase then
				setState("windup")
			end
		elseif st == "windup" then
			if target and age < 0.4 then
				faceTo(target.root.Position)
			end
			tilt = -0.18
			lift = math.sin(age * 40) * 0.25
			if age > 1.0 - 0.15 * phase then
				setState("charge")
				cb.effect("bosscharge", boss.pos)
			end
		elseif st == "charge" then
			local speed = 56 + 8 * phase
			local nextPos, hitEdge = clampToArena(boss.pos + forward() * speed * dt)
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
			if age > 0.8 then
				boss.slams = 0
				setState("slam")
			end
		elseif st == "slam" then
			local dur = 1.1
			local u = math.clamp(age / dur, 0, 1)
			lift = math.sin(u * math.pi) * 22
			if target then
				faceTo(target.root.Position)
				boss.pos = clampToArena(boss.pos + forward() * 22 * dt)
			end
			if age >= dur then
				slamLand()
				boss.slams += 1
				if phase == 3 and boss.slams < 2 then
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
			if age > (st == "stunned" and 4.2 or 3.2) then
				setState("chase")
				refreshSpots()
			end
		elseif st == "hurt" then
			tilt = math.sin(age * 30) * 0.1 -- clients flash him while State == "hurt"
			if age > 1.4 then
				if boss.hp <= 0 then
					setState("dying")
					cb.effect("bossdie", boss.pos + Vector3.new(0, 3 * SCALE, 0))
				else
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
				local vy = e.root.AssemblyLinearVelocity.Y
				local handled = false
				if exposed() then
					for _, s in ipairs(boss.spots) do
						if s.alive then
							local w = s.part.Position
							local flat = Vector3.new(h.X - w.X, 0, h.Z - w.Z).Magnitude
							if flat < 4.6 and feet > w.Y - 2.2 and feet < w.Y + 5 and (vy < 1 or e.char:GetAttribute("Move") == "pound") then
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
				end
				if not handled and not exposed() and boss.state ~= "hurt" then
					local flat = Vector3.new(h.X - boss.pos.X, 0, h.Z - boss.pos.Z).Magnitude
					if flat < 3.2 * SCALE and feet < boss.pos.Y + 3.4 * SCALE then
						hurtPlayer(e, boss.pos)
					end
				end
			end
		end

		-- Fireballs ---------------------------------------------------------------
		for i = #fireballs, 1, -1 do
			local f = fireballs[i]
			local p = f.part.Position + f.vel * dt
			f.part.CFrame = CFrame.new(p)
			local dead = now > f.die or (Vector3.new(p.X - A.X, 0, p.Z - A.Z)).Magnitude > RADIUS + 4
			if not dead then
				for _, e in ipairs(list) do
					if (e.root.Position - p).Magnitude < 3.6 then
						hurtPlayer(e, p - f.vel)
						dead = true
					end
				end
			end
			if dead then
				f.part:Destroy()
				table.remove(fireballs, i)
			end
		end

		-- Shockwaves --------------------------------------------------------------
		for i = #waves, 1, -1 do
			local w = waves[i]
			local r = (now - w.t0) * w.speed
			if r > w.maxR then
				table.remove(waves, i)
			else
				for _, e in ipairs(list) do
					local h = e.root.Position
					local flat = Vector3.new(h.X - w.center.X, 0, h.Z - w.center.Z).Magnitude
					local grounded = h.Y - 2.6 < A.Y + 1.4
					if grounded and not w.hit[e.player] and math.abs(flat - r) < 2.8 then
						w.hit[e.player] = true
						cb.hurt(e.player, w.center)
					end
				end
			end
		end
	end)
end

return BossService
