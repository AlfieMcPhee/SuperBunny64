--[[
	BossShade - the secret boss at the bottom of the Underburrow: a giant dark
	bunny that looks just like you, and moves like you too.

	  sleep -> roar -> stalk -> windup -> leap -> dazed -> (hurt | blink) -> stalk ...

	It follows the path you ran a moment ago, so standing still is a bad idea.
	It leaps at where you're standing (a violet circle shows where it'll land)
	and lands with a shockwave - then it's dazed for a moment. Jump on its head!
	Five hits. From phase 2 it throws homing shadow orbs, from phase 3 half the
	arena erupts after each hit, and from phase 4 its bats join in.
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local BunnyModel = require(Shared:WaitForChild("BunnyModel"))
local BossKit = require(script.Parent:WaitForChild("BossKit"))

local BossShade = {}

local MAX_HP = 5
local SCALE = 2.2
local VIOLET = Color3.fromRGB(170, 120, 240)
local arena, cb, folder
local boss = { minions = {} }
local trail = {} -- { t, pos } of the target's recent positions

local function setState(name)
	boss.state = name
	boss.t0 = os.clock()
	boss.model:SetAttribute("State", name)
end

local function exposed()
	return boss.state == "dazed"
end

local function build()
	if boss.model then
		boss.model:Destroy()
	end
	local model = BunnyModel.BuildPreview({ fur = 5, accent = 3, hat = "none", neck = "none" })
	model.Name = "TheShade"
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Anchored = true
			if d.Name == "Eye" then
				d.Color = VIOLET
				d.Material = Enum.Material.Neon
			elseif d.Name == "EyeShine" then
				d.Transparency = 1
			elseif d.Transparency < 1 then
				d.Color = d.Color:Lerp(Color3.fromRGB(30, 24, 42), 0.85)
				d.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	model:ScaleTo(SCALE)
	local cf, size = model:GetBoundingBox()
	boss.footOffset = model:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2)
	boss.height = size.Y
	-- a solid spot on its head to land on while it's dazed
	local top = Instance.new("Part")
	top.Name = "HeadTop"
	top.Anchored = true
	top.CanCollide = false
	top.CanQuery = false
	top.Transparency = 1
	top.Size = Vector3.new(6, 1, 6)
	top.Parent = model
	boss.top = top
	local glow = Instance.new("PointLight")
	glow.Color = VIOLET
	glow.Range = 22
	glow.Brightness = 1.2
	glow.Parent = model.PrimaryPart
	boss.model = model
	BossKit.Tag(model, "shade", "THE SHADE", MAX_HP, arena, "IT'S DAZED! JUMP ON ITS HEAD!")
	model:SetAttribute("Music", "shade")
	model.Parent = folder
end

local function headPoint()
	return boss.pos + Vector3.new(0, 4.25 * SCALE + 1.2 * SCALE * 0.9, 0)
end

local function place(lift, tilt)
	local pivot = CFrame.new(boss.pos + Vector3.new(0, boss.footOffset + (lift or 0), 0)) * CFrame.Angles(0, boss.yaw, 0) * CFrame.Angles(tilt or 0, 0, 0)
	boss.model:PivotTo(pivot)
	boss.top.CFrame = CFrame.new(headPoint() - Vector3.new(0, 0.6, 0))
end

local function refresh()
	boss.top.CanCollide = exposed()
	boss.model:SetAttribute("Exposed", exposed())
end

local function reset()
	BossKit.Clear(boss)
	build()
	boss.hp = MAX_HP
	boss.pos = arena.center + Vector3.new(0, 0, -10)
	boss.yaw = math.pi
	boss.lastOrb = 0
	table.clear(trail)
	setState("sleep")
	refresh()
	place()
end

local function faceTo(p, rate, dt)
	local d = p - boss.pos
	if Vector3.new(d.X, 0, d.Z).Magnitude > 0.1 then
		local want = math.atan2(-d.X, -d.Z)
		local diff = (want - boss.yaw + math.pi) % (math.pi * 2) - math.pi
		boss.yaw += math.clamp(diff, -rate * dt, rate * dt)
	end
end

-- Where was the target `delay` seconds ago?
local function trailPoint(delay)
	local want = os.clock() - delay
	for i = #trail, 1, -1 do
		if trail[i].t <= want then
			return trail[i].pos
		end
	end
	return trail[1] and trail[1].pos or nil
end

local function eruption(phase)
	-- half of the arena erupts: get to the other side!
	local c = arena.center
	local a = math.random() * math.pi * 2
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	for x = -arena.radius, arena.radius, 8 do
		for z = -arena.radius, arena.radius, 8 do
			local off = Vector3.new(x, 0, z)
			if off.Magnitude < arena.radius - 2 and off:Dot(dir) > -3 then
				BossKit.strike(boss, arena, c + off, { kind = "shadow", radius = 4.6, delay = 1.6 - phase * 0.08, height = 14 })
			end
		end
	end
end

function BossShade.Start(worldInfo, callbacks)
	local def = worldInfo.bossArenas and worldInfo.bossArenas.shade
	if not def then
		return
	end
	cb = callbacks
	arena = BossKit.Arena(def.center, def.radius, 60)
	folder = BossKit.Init(worldInfo, callbacks)
	reset()

	local emptySince = os.clock()
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local list = arena:players()
		if #list == 0 then
			if now - emptySince > 8 and (boss.state ~= "sleep" or boss.hp < MAX_HP) and boss.state ~= "dead" then
				reset()
			end
			if boss.state == "sleep" or boss.state == "dead" then
				return
			end
		else
			emptySince = now
		end
		local st = boss.state
		local age = now - boss.t0
		local phase = MAX_HP - boss.hp + 1
		local target = arena:nearest(list, boss.pos)
		local c = arena.center
		local lift, tilt = 0, 0

		-- remember where the target has been
		if target then
			table.insert(trail, { t = now, pos = Vector3.new(target.root.Position.X, c.Y, target.root.Position.Z) })
			while #trail > 0 and now - trail[1].t > 2 do
				table.remove(trail, 1)
			end
		end

		if st == "sleep" then
			lift = math.sin(now * 1.2) * 0.2
			if #list > 0 then
				setState("roar")
				cb.effect("bossroar", c, { name = "THE SHADE", title = "IT LOOKS JUST LIKE YOU" })
			end
		elseif st == "roar" then
			if target then
				faceTo(target.root.Position, 3, dt)
			end
			lift = math.abs(math.sin(age * 6)) * 1.5
			if age > 2.2 then
				setState("stalk")
			end
		elseif st == "stalk" then
			-- run along your trail from a moment ago
			local delay = 0.95 - phase * 0.08
			local goal = trailPoint(delay)
			if goal then
				local to = Vector3.new(goal.X - boss.pos.X, 0, goal.Z - boss.pos.Z)
				local speed = math.min(to.Magnitude / math.max(dt, 0.001), 26 + phase * 3)
				if to.Magnitude > 0.1 then
					boss.pos = arena:clamp(boss.pos + to.Unit * speed * dt, 4)
					faceTo(goal, 10, dt)
				end
			end
			lift = math.abs(math.sin(now * 11)) * 1.4
			if phase >= 2 and target and now - boss.lastOrb > 2.0 - phase * 0.2 then
				boss.lastOrb = now
				local from = boss.pos + Vector3.new(0, 7, 0)
				local dir = (target.root.Position - from)
				if dir.Magnitude > 0.1 then
					BossKit.projectile(boss, arena, from, dir.Unit * 24, {
						homing = 1.3, target = target.root, size = 2.6, color = VIOLET, life = 4,
					})
				end
			end
			if age > 4.2 - phase * 0.35 and target then
				setState("windup")
			end
		elseif st == "windup" then
			if target then
				faceTo(target.root.Position, 8, dt)
			end
			lift = -1.2
			tilt = 0.25
			if age > 0.55 and target then
				boss.from = boss.pos
				boss.to = arena:clamp(Vector3.new(target.root.Position.X, c.Y, target.root.Position.Z), 5)
				boss.leapTime = 1.05 - phase * 0.06
				BossKit.strike(boss, arena, boss.to, { kind = "shadow", radius = 7, delay = boss.leapTime, height = 12 })
				setState("leap")
				cb.effect("bosscharge", boss.pos)
			end
		elseif st == "leap" then
			local u = math.clamp(age / boss.leapTime, 0, 1)
			boss.pos = boss.from:Lerp(boss.to, u)
			lift = math.sin(u * math.pi) * 26
			tilt = -0.4 + u * 0.6
			if u >= 1 then
				BossKit.shockwave(boss, arena, boss.pos, 46, 36, c.Y)
				if phase >= 3 then
					for i = 0, 5 do
						local a = i / 6 * math.pi * 2 + math.random()
						BossKit.strike(boss, arena, boss.pos + Vector3.new(math.cos(a) * 14, 0, math.sin(a) * 14), { kind = "shadow", radius = 4.5, delay = 0.9, height = 12 })
					end
				end
				setState("dazed")
				refresh()
				cb.effect("bossbonk", headPoint())
			end
		elseif st == "dazed" then
			tilt = 0.18 + math.sin(now * 3) * 0.05
			lift = -0.8
			boss.yaw += math.sin(now * 4) * dt * 0.8
			if age > 2.6 - phase * 0.25 then
				setState("blink")
				refresh()
			end
		elseif st == "blink" then
			-- vanish in a puff and reappear somewhere else
			if age < 0.05 then
				cb.effect("poof", boss.pos + Vector3.new(0, 5, 0))
				boss.pos = arena:randomPoint(8)
				cb.effect("poof", boss.pos + Vector3.new(0, 5, 0))
			end
			if age > 0.6 then
				setState("stalk")
			end
		elseif st == "hurt" then
			tilt = math.sin(age * 30) * 0.12
			if age > 1.3 then
				if boss.hp <= 0 then
					setState("dying")
					BossKit.Clear(boss)
					cb.effect("bossdie", headPoint())
				else
					if phase >= 3 then
						eruption(phase)
					end
					if phase >= 4 and BossKit.minionCount(boss) < 2 then
						for i = 1, 2 do
							local a = math.random() * math.pi * 2
							BossKit.minion(boss, "bat", c + Vector3.new(math.cos(a) * 16, 9, math.sin(a) * 16), "castle")
						end
					end
					setState("blink")
				end
			end
		elseif st == "dying" then
			boss.yaw += dt * (3 + age * 5)
			lift = -age * 2
			if age > 2.6 then
				cb.effect("poof", boss.pos + Vector3.new(0, 6, 0))
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
			return
		end

		if boss.model.Parent then
			place(lift, tilt)
		end

		-- contact with bunnies
		if st ~= "sleep" and st ~= "dying" and st ~= "dead" and st ~= "blink" then
			local head = headPoint()
			for _, e in ipairs(list) do
				local h = e.root.Position
				if exposed() and BossKit.stomped(e, head, 4.4) then
					boss.hp -= 1
					boss.model:SetAttribute("HP", boss.hp)
					cb.bounce(e.player, Vector3.new(0, 85, 0))
					cb.effect("bosshit", head)
					setState("hurt")
					refresh()
					break
				elseif not exposed() and st ~= "hurt" then
					local flat = Vector3.new(h.X - boss.pos.X, 0, h.Z - boss.pos.Z).Magnitude
					local bottom = boss.pos.Y + lift
					if flat < 3.8 and h.Y - 2.6 < bottom + boss.height * 0.8 and h.Y > bottom - 1 then
						cb.hurt(e.player, boss.pos)
					end
				end
			end
		end
	end)
end

function BossShade.Reset()
	if arena then
		reset()
	end
end

return BossShade
