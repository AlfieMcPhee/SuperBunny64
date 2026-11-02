--[[
	BossRootjaw - Old Rootjaw, the giant snapping plant at the heart of
	Whisperwood's Hollow. It can't move, but its neck reaches the whole arena.

	  sleep -> roar -> track -> windup -> lunge -> stuck -> recover -> track ...
	                      \-> roots (rings of roots burst up)       (phase 2+)
	                      \-> seeds (lobbed seed bombs sprout roots) (phase 2+)

	When it slams its head into the ground it gets stuck for a moment: the
	glowing bud on top of its head is the weak point - jump on it! Three hits.
	It calls Mosslings to help once it's hurt.
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local BossKit = require(script.Parent:WaitForChild("BossKit"))

local BossRootjaw = {}

local MAX_HP = 3
local STEM = Color3.fromRGB(84, 112, 62)
local STEM_DARK = Color3.fromRGB(64, 88, 50)
local HEAD = Color3.fromRGB(122, 58, 70)
local INSIDE = Color3.fromRGB(196, 110, 110)
local SEGMENTS = 9

local arena, cb, folder
local boss = { minions = {} }

local function part(model, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = model
	return p
end

local function ball(model, size, color, material)
	local p = part(model, { Size = size, Color = color, Material = material or Enum.Material.SmoothPlastic })
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end

local function setState(name)
	boss.state = name
	boss.t0 = os.clock()
	boss.model:SetAttribute("State", name)
end

local function exposed()
	return boss.state == "stuck"
end

local function build()
	if boss.model then
		boss.model:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "OldRootjaw"
	local c = arena.center
	-- leafy rosette at the base (static)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local leaf = ball(model, Vector3.new(14, 1.2, 6), i % 2 == 0 and STEM or STEM_DARK)
		leaf.CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 7, 0.6, math.sin(a) * 7)) * CFrame.Angles(0, -a, 0.15)
	end
	part(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 7, 7), CFrame = CFrame.new(c + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = STEM_DARK })
	-- the neck: segments re-laid every frame
	boss.segments = {}
	for i = 1, SEGMENTS do
		local w = 3.6 - i * 0.12
		local seg = part(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, w, w), Color = i % 2 == 0 and STEM or STEM_DARK })
		table.insert(boss.segments, seg)
	end
	-- the head: parts stored with offsets from the head's CFrame
	boss.head = {}
	local function headPart(p, offset)
		table.insert(boss.head, { part = p, offset = offset })
		return p
	end
	local skull = headPart(ball(model, Vector3.new(10, 6, 11), HEAD), CFrame.new(0, 0.6, 0))
	skull.Name = "Head"
	boss.skull = skull
	headPart(ball(model, Vector3.new(9, 3, 9.5), INSIDE), CFrame.new(0, -1.4, -0.4))
	boss.jaw = headPart(ball(model, Vector3.new(9.4, 3.2, 10), HEAD), CFrame.new(0, -2.6, 0.2))
	for i = 0, 6 do
		local a = i / 6 * math.pi - math.pi / 2
		headPart(part(model, { Size = Vector3.new(0.7, 1.4, 0.7), Color = Color3.fromRGB(236, 230, 214) }), CFrame.new(math.sin(a) * 4, -1.0, -math.cos(a) * 4.5))
	end
	for _, sx in ipairs({ -1, 1 }) do
		headPart(ball(model, Vector3.new(2.2, 2.2, 1.4), Color3.fromRGB(240, 232, 200)), CFrame.new(sx * 2.2, 2.4, -4.4))
		headPart(ball(model, Vector3.new(1, 1.2, 0.6), Color3.fromRGB(30, 22, 22)), CFrame.new(sx * 2.1, 2.3, -5.0))
		headPart(part(model, { Size = Vector3.new(2.8, 0.5, 0.6), Color = Color3.fromRGB(40, 28, 26) }), CFrame.new(sx * 2.2, 3.7, -4.6) * CFrame.Angles(0, 0, sx * 0.45))
		headPart(ball(model, Vector3.new(6, 0.8, 3), STEM), CFrame.new(sx * 5.5, 1, 1) * CFrame.Angles(0, 0, sx * -0.5))
	end
	-- the bud: the weak point
	boss.bud = headPart(ball(model, Vector3.new(4.2, 3, 4.2), Color3.fromRGB(150, 90, 120)), CFrame.new(0, 4.1, 0.8))
	boss.bud.Name = "WeakPoint"
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		headPart(ball(model, Vector3.new(2.4, 0.5, 1.4), Color3.fromRGB(196, 120, 150)), CFrame.new(math.cos(a) * 1.8, 5.4, 0.8 + math.sin(a) * 1.8) * CFrame.Angles(0, -a, 0.6))
	end
	-- a solid "back of the head" to stand on while it's stuck
	boss.platform = headPart(part(model, { Size = Vector3.new(9, 1, 9), Transparency = 1, Name = "HeadTop" }), CFrame.new(0, 3.1, 0.8))
	boss.model = model
	BossKit.Tag(model, "rootjaw", "OLD ROOTJAW", MAX_HP, arena, "ITS HEAD IS STUCK! JUMP ON THE BUD!")
	model:SetAttribute("Music", "rival")
	model.Parent = folder
end

local function headRest(age)
	local c = arena.center
	return c + Vector3.new(math.sin(age * 0.9) * 2, 15 + math.sin(age * 1.7) * 1, math.cos(age * 0.7) * 2)
end

local function layout()
	local c = arena.center
	local base = c + Vector3.new(0, 3, 0)
	local h = boss.headPos
	-- the neck curves: straight up from the base, then over to the head
	local ctrl = Vector3.new(c.X, math.max(h.Y, 8) + 4, c.Z):Lerp(h, 0.35)
	local prev = base
	local parts, cfs = {}, {}
	for i, seg in ipairs(boss.segments) do
		local u = i / SEGMENTS
		local a = base:Lerp(ctrl, u)
		local b = ctrl:Lerp(h, u)
		local p = a:Lerp(b, u)
		local len = (p - prev).Magnitude
		if len > 0.01 then
			seg.Size = Vector3.new(len + 1.2, seg.Size.Y, seg.Size.Z)
			table.insert(parts, seg)
			table.insert(cfs, CFrame.lookAt((prev + p) / 2, p) * CFrame.Angles(0, math.pi / 2, 0))
		end
		prev = p
	end
	local headCF = CFrame.new(h) * CFrame.Angles(0, boss.yaw, 0) * CFrame.Angles(boss.pitch or 0, 0, 0)
	for _, hp in ipairs(boss.head) do
		local off = hp.offset
		if hp.part == boss.jaw then
			off = CFrame.new(0, 0, 2.5) * CFrame.Angles(-(boss.jawOpen or 0.1), 0, 0) * CFrame.new(0, 0, -2.5) * off
		end
		table.insert(parts, hp.part)
		table.insert(cfs, headCF * off)
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

local function refresh()
	local on = exposed()
	boss.bud.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
	boss.bud.Color = on and Color3.fromRGB(255, 170, 210) or Color3.fromRGB(150, 90, 120)
	boss.platform.CanCollide = on
	boss.skull.CanCollide = on
end

local function reset()
	BossKit.Clear(boss)
	build()
	boss.hp = MAX_HP
	boss.yaw = 0
	boss.pitch = 0.5
	boss.headPos = arena.center + Vector3.new(0, 4, -6)
	boss.jawOpen = 0
	boss.lastSeeds = 0
	boss.cycle = 0
	setState("sleep")
	refresh()
	layout()
end

local function faceYaw(from, to)
	local d = to - from
	if Vector3.new(d.X, 0, d.Z).Magnitude > 0.1 then
		return math.atan2(-d.X, -d.Z)
	end
	return boss.yaw
end

local function rootRings(phase)
	local c = arena.center
	for ring = 1, 3 do
		local r = ring * 8.5
		local n = 5 + ring * 2
		local off = math.random() * math.pi
		for i = 0, n - 1 do
			local a = i / n * math.pi * 2 + off
			BossKit.strike(boss, arena, c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), {
				kind = "roots", radius = 3.6, delay = 0.9 + ring * 0.45 - phase * 0.08, height = 9,
			})
		end
	end
end

local function spitSeeds(list, phase)
	local from = boss.headPos + Vector3.new(0, 1, 0)
	for _, e in ipairs(list) do
		for k = 1, phase do
			local to = e.root.Position + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
			local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
			local t = 1.2
			local g = 60
			local vel = flat / t + Vector3.new(0, (arena.center.Y - from.Y) / t + 0.5 * g * t, 0)
			task.delay((k - 1) * 0.25, function()
				if boss.state ~= "dead" and boss.state ~= "dying" then
					BossKit.projectile(boss, arena, from, vel, {
						gravity = g, size = 2.4, color = Color3.fromRGB(150, 200, 100), life = 3,
						onLand = function(pos)
							BossKit.strike(boss, arena, pos, { kind = "roots", radius = 4, delay = 0.55, height = 8 })
						end,
					})
				end
			end)
		end
	end
	cb.effect("spores", from)
end

function BossRootjaw.Start(worldInfo, callbacks)
	local def = worldInfo.bossArenas and worldInfo.bossArenas.rootjaw
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
		local target = arena:nearest(list, arena.center)
		local c = arena.center
		local wantYaw = target and faceYaw(boss.headPos, target.root.Position) or boss.yaw
		local function turn(rate)
			local d = (wantYaw - boss.yaw + math.pi) % (math.pi * 2) - math.pi
			boss.yaw += math.clamp(d, -rate * dt, rate * dt)
		end

		if st == "sleep" then
			boss.headPos = c + Vector3.new(0, 4 + math.sin(now) * 0.3, -6)
			boss.pitch = 0.5
			boss.jawOpen = 0
			if #list > 0 then
				setState("roar")
				cb.effect("bossroar", c, { name = "OLD ROOTJAW", title = "THE HUNGRY HEART OF WHISPERWOOD" })
			end
		elseif st == "roar" then
			local u = math.clamp(age / 1.2, 0, 1)
			boss.headPos = (c + Vector3.new(0, 4, -6)):Lerp(headRest(now), u)
			boss.pitch = 0.5 - u * 0.8 + math.sin(age * 25) * 0.05
			boss.jawOpen = 0.6
			turn(2)
			if age > 2.2 then
				setState("track")
			end
		elseif st == "track" then
			boss.headPos = boss.headPos:Lerp(headRest(now), math.clamp(dt * 3, 0, 1))
			boss.pitch = 0.15
			boss.jawOpen = 0.15 + math.sin(now * 3) * 0.08
			turn(3)
			if phase >= 2 and now - boss.lastSeeds > 4 - phase * 0.6 and age > 0.6 then
				boss.lastSeeds = now
				spitSeeds(list, phase)
			end
			if age > 2.6 - phase * 0.4 and target then
				boss.cycle += 1
				if phase >= 2 and boss.cycle % 3 == 0 then
					setState("roots")
					rootRings(phase)
				else
					boss.aim = arena:clamp(Vector3.new(target.root.Position.X, c.Y, target.root.Position.Z), 6)
					setState("windup")
				end
			end
		elseif st == "roots" then
			-- head rears up and quivers while the roots burst
			boss.headPos = boss.headPos:Lerp(c + Vector3.new(0, 20, 0), math.clamp(dt * 4, 0, 1))
			boss.pitch = -0.5
			boss.jawOpen = 0.7
			if age > 2.6 then
				setState("track")
			end
		elseif st == "windup" then
			-- rear back away from the aim point
			local away = Vector3.new(c.X - boss.aim.X, 0, c.Z - boss.aim.Z)
			away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
			local rest = c + away * 6 + Vector3.new(0, 21, 0)
			boss.headPos = boss.headPos:Lerp(rest, math.clamp(dt * 5, 0, 1))
			wantYaw = faceYaw(boss.headPos, boss.aim)
			turn(6)
			boss.pitch = -0.35 + math.sin(age * 30) * 0.04
			boss.jawOpen = 0.8
			if age > 1.0 - phase * 0.12 then
				boss.from = boss.headPos
				setState("lunge")
				cb.effect("bosscharge", boss.headPos)
			end
		elseif st == "lunge" then
			local u = math.clamp(age / 0.22, 0, 1)
			local dest = boss.aim + Vector3.new(0, 2.8, 0)
			boss.headPos = boss.from:Lerp(dest, u * u)
			boss.pitch = 0.4 * u
			boss.jawOpen = 0.8 * (1 - u)
			if u >= 1 then
				setState("stuck")
				refresh()
				BossKit.shockwave(boss, arena, boss.aim, 40, 26, c.Y)
				cb.effect("bossbonk", boss.headPos + Vector3.new(0, 4, 0))
			end
		elseif st == "stuck" then
			-- wriggling to get free
			boss.headPos = boss.aim + Vector3.new(0, 2.8, 0) + Vector3.new(math.sin(now * 14) * 0.15, 0, 0)
			boss.pitch = 0.4 + math.sin(now * 9) * 0.03
			boss.jawOpen = 0
			if age > 3.2 - phase * 0.45 then
				setState("recover")
				refresh()
			end
		elseif st == "recover" then
			boss.headPos = boss.headPos:Lerp(headRest(now), math.clamp(dt * 4, 0, 1))
			boss.pitch = 0.15
			if age > 0.8 then
				setState("track")
			end
		elseif st == "hurt" then
			boss.headPos = boss.headPos:Lerp(c + Vector3.new(0, 12, 0), math.clamp(dt * 4, 0, 1))
			boss.pitch = math.sin(age * 30) * 0.15
			boss.jawOpen = 0.9
			if age > 1.5 then
				if boss.hp <= 0 then
					setState("dying")
					BossKit.Clear(boss)
					cb.effect("bossdie", boss.headPos)
				else
					if BossKit.minionCount(boss) < 3 then
						for i = 1, 2 do
							local a = math.random() * math.pi * 2
							BossKit.minion(boss, "mossling", c + Vector3.new(math.cos(a) * 18, 0, math.sin(a) * 18), "forest")
						end
					end
					setState("track")
				end
			end
		elseif st == "dying" then
			local u = math.clamp(age / 2.4, 0, 1)
			boss.headPos = boss.headPos:Lerp(c + Vector3.new(0, 1, -8), math.clamp(dt * 2, 0, 1))
			boss.pitch = 0.6 * u
			boss.yaw += dt * 3 * (1 - u)
			if age > 2.6 then
				cb.effect("poof", boss.headPos)
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
			layout()
			boss.model:SetAttribute("Exposed", exposed())
		end

		-- contact with bunnies
		if st ~= "sleep" and st ~= "dying" and st ~= "dead" then
			local headTop = boss.headPos + Vector3.new(0, 4.6, 0)
			for _, e in ipairs(list) do
				local h = e.root.Position
				if exposed() and BossKit.stomped(e, headTop + Vector3.new(0, -0.6, 0.8), 4) then
					boss.hp -= 1
					boss.model:SetAttribute("HP", boss.hp)
					cb.bounce(e.player, Vector3.new(0, 80, 0))
					cb.effect("bosshit", headTop)
					setState("hurt")
					refresh()
					break
				elseif not exposed() and st ~= "hurt" then
					if (h - boss.headPos).Magnitude < 6.2 then
						cb.hurt(e.player, boss.headPos)
					end
				end
			end
		end
	end)
end

function BossRootjaw.Reset()
	if arena then
		reset()
	end
end

return BossRootjaw
