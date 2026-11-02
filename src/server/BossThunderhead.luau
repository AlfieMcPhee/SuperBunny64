--[[
	BossThunderhead - a furious storm cloud that squats over the Stormcrown, a
	floating arena south of Cloudtop's hub.

	  sleep -> roar -> storm (rounds of lightning) -> drained -> rise -> gale -> storm ...
	                                                    \-> (phase 2+) calls Puffers

	Lightning always shows a flashing circle first. After a storm it's run out
	of puff and sinks down to the arena: hop onto it and stomp the glowing
	storm core on top. Between storms it inhales and blows a gale across the
	arena that shoves you toward the edge - keep moving into it. Three hits.
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local BossKit = require(script.Parent:WaitForChild("BossKit"))

local BossThunderhead = {}

local MAX_HP = 3
local HOVER = 24
local arena, cb, folder
local boss = { minions = {} }

local function setState(name)
	boss.state = name
	boss.t0 = os.clock()
	boss.model:SetAttribute("State", name)
end

local function exposed()
	return boss.state == "drained"
end

local function ball(model, cf, size, color, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	p.Parent = model
	return p
end

local function build()
	if boss.model then
		boss.model:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "Thunderhead"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	root.Size = Vector3.new(2, 2, 2)
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	local dark = Color3.fromRGB(92, 96, 112)
	local mid = Color3.fromRGB(122, 126, 142)
	local light = Color3.fromRGB(160, 164, 180)
	boss.bodyParts = {}
	local main = ball(model, CFrame.new(0, 0, 0), Vector3.new(20, 11, 18), mid)
	table.insert(boss.bodyParts, main)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local r = 8 + (i % 3)
		local s = 7 + (i % 4)
		local p = ball(model, CFrame.new(math.cos(a) * r, (i % 2) * 2 - 1, math.sin(a) * r * 0.9), Vector3.new(s * 1.3, s, s * 1.2), i % 3 == 0 and dark or (i % 3 == 1 and mid or light))
		table.insert(boss.bodyParts, p)
	end
	ball(model, CFrame.new(0, -5, 0), Vector3.new(18, 4, 16), dark)
	-- angry face on the front
	for _, sx in ipairs({ -1, 1 }) do
		ball(model, CFrame.new(sx * 3.2, 1.2, -8.6), Vector3.new(3, 2.4, 1), Color3.fromRGB(255, 236, 140), Enum.Material.Neon)
		local brow = Instance.new("Part")
		brow.Anchored = true
		brow.CanCollide = false
		brow.CanQuery = false
		brow.CanTouch = false
		brow.Size = Vector3.new(4.4, 0.8, 0.8)
		brow.CFrame = CFrame.new(sx * 3.2, 3.0, -8.9) * CFrame.Angles(0, 0, sx * 0.4)
		brow.Color = Color3.fromRGB(50, 52, 64)
		brow.Parent = model
	end
	ball(model, CFrame.new(0, -2.4, -8.8), Vector3.new(5, 1.6, 1), Color3.fromRGB(40, 40, 52))
	-- the storm core on top: the weak point
	boss.core = ball(model, CFrame.new(0, 6.4, 0), Vector3.new(4.5, 4.5, 4.5), Color3.fromRGB(110, 140, 170))
	boss.core.Name = "WeakPoint"
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(150, 210, 255)
	glow.Range = 20
	glow.Brightness = 1.5
	glow.Parent = boss.core
	-- a flat cloud top you can land on while it's drained
	local top = Instance.new("Part")
	top.Name = "CloudTop"
	top.Anchored = true
	top.CanCollide = false
	top.CanQuery = false
	top.Transparency = 1
	top.Size = Vector3.new(18, 1, 16)
	top.CFrame = CFrame.new(0, 4.6, 0)
	top.Parent = model
	boss.top = top
	boss.model = model
	BossKit.Tag(model, "thunderhead", "THUNDERHEAD", MAX_HP, arena, "IT'S WORN OUT! STOMP THE STORM CORE!")
	model:SetAttribute("Music", "rival")
	model.Parent = folder
end

local function refresh()
	local on = exposed()
	boss.core.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
	boss.core.Color = on and Color3.fromRGB(170, 230, 255) or Color3.fromRGB(110, 140, 170)
	boss.top.CanCollide = on
end

local function reset()
	BossKit.Clear(boss)
	build()
	boss.hp = MAX_HP
	boss.pos = arena.center + Vector3.new(0, HOVER, 0)
	boss.yaw = 0
	boss.rounds = 0
	boss.lastRound = 0
	setState("sleep")
	refresh()
end

local function place(tilt)
	boss.model:PivotTo(CFrame.new(boss.pos) * CFrame.Angles(0, boss.yaw, 0) * CFrame.Angles(tilt or 0, 0, 0))
end

local function faceTo(p)
	local d = p - boss.pos
	if Vector3.new(d.X, 0, d.Z).Magnitude > 0.1 then
		local want = math.atan2(-d.X, -d.Z)
		local diff = (want - boss.yaw + math.pi) % (math.pi * 2) - math.pi
		boss.yaw += diff * 0.08
	end
end

local function lightningRound(list, phase)
	for _, e in ipairs(list) do
		-- where you are now, and where you're heading
		local p = e.root.Position
		local v = e.root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		BossKit.strike(boss, arena, p, { kind = "lightning", radius = 5, delay = 1.05 - phase * 0.1, height = 30 })
		if phase >= 2 then
			BossKit.strike(boss, arena, arena:clamp(p + v * 0.9, 4), { kind = "lightning", radius = 4.5, delay = 1.2 - phase * 0.1, height = 30 })
		end
	end
	for _ = 1, 1 + phase do
		BossKit.strike(boss, arena, arena:randomPoint(4), { kind = "lightning", radius = 5, delay = 1.1, height = 30 })
	end
end

function BossThunderhead.Start(worldInfo, callbacks)
	local def = worldInfo.bossArenas and worldInfo.bossArenas.thunderhead
	if not def then
		return
	end
	cb = callbacks
	arena = BossKit.Arena(def.center, def.radius, 70)
	folder = BossKit.Init(worldInfo, callbacks)
	reset()
	place()

	local emptySince = os.clock()
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local list = arena:players()
		if #list == 0 then
			if now - emptySince > 8 and (boss.state ~= "sleep" or boss.hp < MAX_HP) and boss.state ~= "dead" then
				reset()
				place()
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
		local tilt = 0
		local hoverAt = c + Vector3.new(0, HOVER, 0)

		if st == "sleep" then
			boss.pos = hoverAt + Vector3.new(0, math.sin(now) * 1.5, 0)
			boss.yaw += dt * 0.15
			if #list > 0 then
				setState("roar")
				cb.effect("bossroar", c, { name = "THUNDERHEAD", title = "THE STORM ABOVE THE CLOUDS" })
			end
		elseif st == "roar" then
			tilt = math.sin(age * 20) * 0.05
			if target then
				faceTo(target.root.Position)
			end
			if age > 2.2 then
				boss.rounds = 0
				setState("storm")
			end
		elseif st == "storm" then
			-- drift over whoever it's angriest at
			if target then
				local want = Vector3.new(target.root.Position.X, c.Y + HOVER, target.root.Position.Z)
				want = arena:clamp(want, 10)
				boss.pos = boss.pos:Lerp(Vector3.new(want.X, c.Y + HOVER + math.sin(now * 2) * 1.2, want.Z), math.clamp(dt * 0.8, 0, 1))
				faceTo(target.root.Position)
			end
			tilt = math.sin(now * 8) * 0.03
			if now - boss.lastRound > 1.3 - phase * 0.12 and age > 0.5 then
				boss.lastRound = now
				boss.rounds += 1
				lightningRound(list, phase)
			end
			if boss.rounds >= 3 + phase then
				setState("sink")
				if phase >= 2 and BossKit.minionCount(boss) < 2 then
					for i = 1, 2 do
						local a = math.random() * math.pi * 2
						BossKit.minion(boss, "puffer", c + Vector3.new(math.cos(a) * (arena.radius - 6), 7, math.sin(a) * (arena.radius - 6)), "sky")
					end
				end
			end
		elseif st == "sink" then
			-- out of puff: it sags down to the arena
			local down = Vector3.new(boss.pos.X, c.Y + 6, boss.pos.Z)
			boss.pos = boss.pos:Lerp(down, math.clamp(dt * 2.5, 0, 1))
			tilt = 0.12
			if age > 1.3 then
				setState("drained")
				refresh()
				cb.effect("bossbonk", boss.pos + Vector3.new(0, 7, 0))
			end
		elseif st == "drained" then
			boss.pos = Vector3.new(boss.pos.X, c.Y + 6 + math.sin(now * 2) * 0.2, boss.pos.Z)
			tilt = 0.12 + math.sin(now * 3) * 0.04
			if age > 3.6 - phase * 0.5 then
				setState("rise")
				refresh()
			end
		elseif st == "rise" then
			boss.pos = boss.pos:Lerp(hoverAt, math.clamp(dt * 2, 0, 1))
			if age > 1.2 then
				setState("inhale")
			end
		elseif st == "inhale" then
			-- puffs up, picks a side, then...
			if target then
				faceTo(target.root.Position)
			end
			tilt = -0.15 + math.sin(age * 30) * 0.03
			if age > 1.2 then
				setState("gale")
				local dir = target and Vector3.new(target.root.Position.X - boss.pos.X, 0, target.root.Position.Z - boss.pos.Z) or Vector3.new(1, 0, 0)
				boss.galeDir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
				boss.lastGust = 0
				cb.effect("gust", boss.pos, boss.galeDir)
			end
		elseif st == "gale" then
			-- ...blows a gale across the arena in bursts
			tilt = 0.1
			if now - boss.lastGust > 0.55 then
				boss.lastGust = now
				cb.effect("gust", boss.pos - Vector3.new(0, 10, 0), boss.galeDir)
				for _, e in ipairs(list) do
					cb.gust(e.player, boss.galeDir * (34 + phase * 6) + Vector3.new(0, 14, 0))
				end
			end
			if age > 1.4 + phase * 0.5 then
				boss.rounds = 0
				setState("storm")
			end
		elseif st == "hurt" then
			tilt = math.sin(age * 30) * 0.12
			boss.pos = boss.pos:Lerp(hoverAt, math.clamp(dt * 2, 0, 1))
			if age > 1.5 then
				if boss.hp <= 0 then
					setState("dying")
					BossKit.Clear(boss)
					cb.effect("bossdie", boss.pos)
				else
					setState("inhale")
				end
			end
		elseif st == "dying" then
			boss.yaw += dt * (2 + age * 4)
			boss.pos += Vector3.new(0, dt * 6, 0)
			if age > 2.6 then
				cb.effect("poof", boss.pos)
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
				place()
			end
			return
		end

		if boss.model.Parent then
			place(tilt)
			boss.model:SetAttribute("Exposed", exposed())
		end

		-- contact: only matters when it's down low
		if st ~= "sleep" and st ~= "dying" and st ~= "dead" then
			local corePos = boss.core.Position
			for _, e in ipairs(list) do
				local h = e.root.Position
				if exposed() and BossKit.stomped(e, corePos + Vector3.new(0, -1.2, 0), 5) then
					boss.hp -= 1
					boss.model:SetAttribute("HP", boss.hp)
					cb.bounce(e.player, Vector3.new(0, 85, 0))
					cb.effect("bosshit", corePos)
					setState("hurt")
					refresh()
					break
				elseif not exposed() and st ~= "hurt" then
					local flat = Vector3.new(h.X - boss.pos.X, 0, h.Z - boss.pos.Z).Magnitude
					if flat < 10 and math.abs(h.Y - boss.pos.Y) < 6 then
						cb.hurt(e.player, boss.pos)
					end
				end
			end
		end
	end)
end

function BossThunderhead.Reset()
	if arena then
		reset()
		place()
	end
end

return BossThunderhead
