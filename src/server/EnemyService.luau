--[[
	EnemyService - all the baddies.

	  bug         Grumblebug      wanders, charges            stomp / pound / roll / slide
	  toad        Hopscotch Toad  hops toward you in arcs     stomp / pound / roll / slide
	  bat         Flitbat         circles, swoops at you      stomp / roll / long jump / pound wave
	  thornhog    Thornhog        rolls back and forth        ONLY a ground-pound shockwave (spikes!)
	  puffshroom  Puffshroom      puffs a ring of spores      stomp it between puffs

	Defeated baddies come back after Config.BugRespawnSeconds.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local BugModel = require(script.Parent:WaitForChild("BugModel"))
local EnemyModels = require(script.Parent:WaitForChild("EnemyModels"))

local EnemyService = {}

local enemies = {}
local folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local callbacks
local poundingUntil = {} -- [Player] = os.clock()

local ATTACK_MOVES = { roll = true, slide = true, longjump = true }
local FEET = 2.6 -- HumanoidRootPart centre to feet

-- Per-kind shape: how tall the centre sits above the ground, contact radius, top height
local SHAPE = {
	bug = { lift = 1.8, radius = 4.4, top = 4.0 },
	toad = { lift = 1.6, radius = 3.6, top = 3.2 },
	bat = { lift = 0, below = 1.6, radius = 3.2, top = 1.6 },
	thornhog = { lift = 2.0, radius = 3.6, top = 4.2 },
	puffshroom = { lift = 1.9, radius = 3.4, top = 5.0 },
	mossling = { lift = 1.6, radius = 3.6, top = 3.4 },
	snapper = { lift = 1.5, radius = 3.4, top = 3.2 }, -- measured around its head
	puffer = { lift = 0, below = 1.8, radius = 3.8, top = 3.4 },
}

-- Kinds that hover at their home point instead of standing on the ground
local FLYING = { bat = true, puffer = true }

local function groundAt(pos)
	local hit = workspace:Raycast(pos + Vector3.new(0, 8, 0), Vector3.new(0, -30, 0), rayParams)
	if hit then
		return hit.Position.Y, hit.Instance
	end
	return nil
end

local function walkable(gy, hitPart, fromY, maxStep)
	if not gy or gy < Config.WaterLevel + 1 or math.abs(gy - fromY) > (maxStep or 3) then
		return false
	end
	if hitPart and (hitPart:GetAttribute("Moving") or hitPart:GetAttribute("Lava") or hitPart:GetAttribute("Water") or hitPart:GetAttribute("Slide")) then
		return false
	end
	return true
end

local function center(e)
	if FLYING[e.kind] then
		return e.pos
	end
	return e.pos + Vector3.new(0, SHAPE[e.kind].lift + (e.lift or 0), 0)
end

local function place(e, roll, pitch)
	e.model:PivotTo(CFrame.new(center(e)) * CFrame.Angles(0, e.yaw, 0) * CFrame.Angles(pitch or 0, 0, roll or 0))
end

local function lookYaw(from, to)
	local d = to - from
	return math.atan2(-d.X, -d.Z)
end

local function forward(yaw)
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

local function defeat(e, player)
	e.alive = false
	e.respawnAt = os.clock() + Config.BugRespawnSeconds
	local c = center(e)
	callbacks.effect("poof", c)
	task.spawn(function()
		for i = 1, 8 do
			if not e.model.Parent then
				break
			end
			e.model:PivotTo(CFrame.new(c + Vector3.new(0, math.sin(i / 8 * math.pi) * 2, 0)) * CFrame.Angles(0, e.yaw, i / 8 * math.pi))
			task.wait(0.03)
		end
		e.model.Parent = nil
	end)
	if player then
		callbacks.bopped(player)
	end
end

local function build(e)
	if e.kind == "bug" then
		e.model = BugModel.Build(e.skin, 1, CFrame.new(e.pos))
	else
		e.model, e.extra = EnemyModels[e.kind](e.skin, CFrame.new(e.pos))
	end
	e.model.Parent = folder
end

function EnemyService.Start(info, cb)
	callbacks = cb
	folder = Instance.new("Folder")
	folder.Name = "Baddies"
	folder.Parent = workspace
	rayParams.FilterDescendantsInstances = { info.solidFolder, workspace.Terrain }

	for _, def in ipairs(info.enemies) do
		local home = def.pos
		local pos = home
		if not FLYING[def.kind] then
			local y = groundAt(home + Vector3.new(0, 10, 0)) or home.Y
			pos = Vector3.new(home.X, y, home.Z)
		end
		local e = {
			kind = def.kind,
			skin = def.skin,
			home = pos,
			pos = pos,
			yaw = math.random() * math.pi * 2,
			alive = true,
			respawnAt = 0,
			phase = math.random() * 6,
			state = "idle",
			t0 = os.clock() + math.random() * 2,
			fast = def.skin == "castle",
			range = def.range or 22,
			axis = def.axis,
		}
		build(e)
		table.insert(enemies, e)
	end

	RunService.Heartbeat:Connect(function(dt)
		EnemyService.Step(dt)
	end)
end

function EnemyService.MarkPounding(player, seconds)
	poundingUntil[player] = os.clock() + seconds
end

-- Ground pound shockwave: beats every kind, even the spiky one
function EnemyService.Shockwave(player, pos)
	for _, e in ipairs(enemies) do
		if e.alive then
			local c = center(e)
			local d = Vector3.new(c.X - pos.X, 0, c.Z - pos.Z).Magnitude
			if d < 14 and math.abs(c.Y - pos.Y) < 9 then
				defeat(e, player)
			end
		end
	end
end

local function nearestPlayer(pos, maxDist, maxDy)
	local best, bestDist, bestHrp = nil, maxDist, nil
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local d = (hrp.Position - pos).Magnitude
			if d < bestDist and math.abs(hrp.Position.Y - FEET - pos.Y) < maxDy then
				best, bestDist, bestHrp = player, d, hrp
			end
		end
	end
	return best, bestHrp
end

--------------------------------------------------------------------------------
-- Behaviours
--------------------------------------------------------------------------------

local BEHAVIOUR = {}

function BEHAVIOUR.bug(e, dt, now)
	local target, hrp = nearestPlayer(e.pos, 45, 10)
	local fromHome = Vector3.new(e.pos.X - e.home.X, 0, e.pos.Z - e.home.Z).Magnitude
	local speed = e.fast and 9 or 7
	if target and fromHome < 60 then
		e.yaw = lookYaw(e.pos, hrp.Position)
		speed = e.fast and 19 or 15
	elseif fromHome > e.range then
		e.yaw = lookYaw(e.pos, e.home)
	elseif now > e.t0 then
		e.yaw += (math.random() - 0.5) * 2.5
		e.t0 = now + 1 + math.random() * 2
	end
	local nextPos = e.pos + forward(e.yaw) * speed * dt
	local gy, hit = groundAt(nextPos)
	if walkable(gy, hit, e.pos.Y) then
		e.pos = Vector3.new(nextPos.X, gy, nextPos.Z)
	else
		e.yaw += math.pi * (0.5 + math.random() * 0.5)
	end
	local step = now * (speed > 10 and 18 or 10) + e.phase
	e.lift = math.abs(math.sin(step)) * 0.25
	place(e, math.sin(step) * 0.06)
end

function BEHAVIOUR.toad(e, dt, now)
	if e.state == "idle" then
		e.lift = math.abs(math.sin(now * 3 + e.phase)) * 0.12
		place(e, 0, -0.05)
		if now > e.t0 then
			local _, hrp = nearestPlayer(e.pos, 40, 12)
			local fromHome = (e.pos - e.home) * Vector3.new(1, 0, 1)
			if hrp then
				e.yaw = lookYaw(e.pos, hrp.Position)
			elseif fromHome.Magnitude > e.range then
				e.yaw = lookYaw(e.pos, e.home)
			else
				e.yaw += (math.random() - 0.5) * 2.4
			end
			local dist = hrp and 14 or 10
			local dest = e.pos + forward(e.yaw) * dist
			local gy, hit = groundAt(dest)
			if walkable(gy, hit, e.pos.Y, 8) then
				e.state = "hop"
				e.hopFrom = e.pos
				e.hopTo = Vector3.new(dest.X, gy, dest.Z)
				e.t0 = now
			else
				e.yaw += math.pi
				e.t0 = now + 0.6
			end
		end
	else
		local u = math.clamp((now - e.t0) / 0.7, 0, 1)
		local flat = e.hopFrom:Lerp(e.hopTo, u)
		e.pos = flat
		e.lift = math.sin(u * math.pi) * 7
		place(e, 0, -0.35 * math.sin(u * math.pi))
		if e.extra and e.extra.legs then
			-- legs kick out behind while airborne
			for _, leg in ipairs(e.extra.legs) do
				leg.CFrame = leg.CFrame * CFrame.new(0, -math.sin(u * math.pi) * 0.6, math.sin(u * math.pi) * 0.9)
			end
		end
		if u >= 1 then
			e.state = "idle"
			e.lift = 0
			e.t0 = now + 0.9 + math.random() * 1.2
		end
	end
end

function BEHAVIOUR.bat(e, dt, now)
	local hover = e.home + Vector3.new(0, 0, 0)
	if e.state == "idle" then
		e.orbit = (e.orbit or e.phase) + dt * 1.1
		local want = hover + Vector3.new(math.cos(e.orbit) * 10, math.sin(now * 2 + e.phase) * 1.2, math.sin(e.orbit) * 10)
		e.pos = e.pos:Lerp(want, math.clamp(dt * 3, 0, 1))
		e.yaw = e.orbit + math.pi
		if now > e.t0 then
			local _, hrp = nearestPlayer(e.pos, 42, 30)
			if hrp then
				e.state = "swoop"
				e.target = hrp.Position
				e.t0 = now
				e.yaw = lookYaw(e.pos, e.target)
				callbacks.effect("screech", e.pos)
			else
				e.t0 = now + 0.5
			end
		end
	elseif e.state == "swoop" then
		local d = e.target - e.pos
		if d.Magnitude < 2 or now - e.t0 > 1.6 then
			e.state = "rise"
			e.t0 = now
		else
			e.pos += d.Unit * math.min(d.Magnitude, (e.fast and 38 or 32) * dt)
		end
	else -- rise back home
		e.pos = e.pos:Lerp(hover, math.clamp(dt * 1.8, 0, 1))
		if now - e.t0 > 1.4 then
			e.state = "idle"
			e.t0 = now + 1.8 + math.random()
		end
	end
	place(e, 0, e.state == "swoop" and -0.5 or 0)
	-- flap
	local root = e.model.PrimaryPart.CFrame
	local flap = math.sin(now * (e.state == "swoop" and 10 or 18) + e.phase) * 0.7
	for _, w in ipairs(e.extra.wings) do
		local hinge = root * w.offset * CFrame.Angles(0, 0, w.side * flap)
		w.part.CFrame = hinge * w.local1
		w.tip.CFrame = hinge * w.local2
	end
end

function BEHAVIOUR.thornhog(e, dt, now)
	-- patrols along its axis; charges if a bunny is in front of it on the ground
	e.dir = e.dir or 1
	local axis = e.axis or Vector3.new(1, 0, 0)
	local _, hrp = nearestPlayer(e.pos, 26, 5)
	local speed = e.fast and 18 or 15
	local moveDir = axis * e.dir
	if hrp then
		local to = (hrp.Position - e.pos) * Vector3.new(1, 0, 1)
		if to.Magnitude > 0.1 then
			moveDir = to.Unit
			speed = e.fast and 26 or 22
		end
	end
	local nextPos = e.pos + moveDir * speed * dt
	local along = (nextPos - e.home):Dot(axis)
	local gy, hit = groundAt(nextPos)
	if not hrp and math.abs(along) > e.range then
		e.dir = -e.dir
	elseif walkable(gy, hit, e.pos.Y) and (nextPos - e.home).Magnitude < e.range + 25 then
		e.pos = Vector3.new(nextPos.X, gy, nextPos.Z)
	else
		e.dir = -e.dir
	end
	e.yaw = lookYaw(Vector3.zero, moveDir)
	e.spin = (e.spin or 0) + dt * speed / 2.2
	place(e, 0, -e.spin)
end

function BEHAVIOUR.puffshroom(e, dt, now)
	-- idle 2.4s, swell 0.6s, puff 0.9s
	local cycle = (now + e.phase) % 3.9
	local was = e.state
	if cycle < 2.4 then
		e.state = "idle"
		e.lift = math.sin(now * 2 + e.phase) * 0.1
	elseif cycle < 3.0 then
		e.state = "swell"
		e.lift = (cycle - 2.4) * 0.8
	else
		e.state = "puff"
		e.lift = 0
	end
	if e.state == "puff" and was ~= "puff" then
		callbacks.effect("spores", center(e))
	end
	place(e, math.sin(now * 20) * (e.state == "swell" and 0.06 or 0))
end

-- Mossling: a hump of moss until you get close, then it pops up and gives chase
local function stepToward(e, dir, speed, dt)
	local nextPos = e.pos + dir * speed * dt
	local gy, hit = groundAt(nextPos)
	if walkable(gy, hit, e.pos.Y) then
		e.pos = Vector3.new(nextPos.X, gy, nextPos.Z)
		return true
	end
	return false
end

function BEHAVIOUR.mossling(e, dt, now)
	local HIDDEN = -2.5
	if e.state == "idle" then
		e.lift = HIDDEN + math.sin(now * 1.5 + e.phase) * 0.08
		place(e)
		if now > e.t0 then
			local _, hrp = nearestPlayer(e.pos, 17, 8)
			if hrp then
				e.state = "pop"
				e.t0 = now
				e.yaw = lookYaw(e.pos, hrp.Position)
				callbacks.effect("poof", e.pos + Vector3.new(0, 1, 0))
			else
				e.t0 = now + 0.25
			end
		end
	elseif e.state == "pop" then
		local u = math.clamp((now - e.t0) / 0.35, 0, 1)
		e.lift = HIDDEN * (1 - u) + math.sin(u * math.pi) * 2
		place(e)
		if u >= 1 then
			e.state = "chase"
			e.t0 = now
		end
	elseif e.state == "chase" then
		local _, hrp = nearestPlayer(e.pos, 40, 10)
		local toHome = (e.home - e.pos) * Vector3.new(1, 0, 1)
		local speed = 0
		if hrp and now - e.t0 < 7 and toHome.Magnitude < 45 then
			e.yaw = lookYaw(e.pos, hrp.Position)
			speed = 13
		elseif toHome.Magnitude > 1.5 then
			e.yaw = lookYaw(Vector3.zero, toHome)
			speed = 9
		else
			e.state = "sink"
			e.t0 = now
		end
		if speed > 0 and not stepToward(e, forward(e.yaw), speed, dt) and not hrp then
			e.pos = e.home -- stuck on the way home: just burrow back
		end
		local step = now * 14 + e.phase
		e.lift = math.abs(math.sin(step)) * 0.5
		place(e, math.sin(step) * 0.12)
	else -- sink back into the moss
		local u = math.clamp((now - e.t0) / 0.5, 0, 1)
		e.lift = HIDDEN * u
		place(e)
		if u >= 1 then
			e.state = "idle"
			e.t0 = now + 2
		end
	end
end

-- Snapper: a rooted biting plant. Rears back (the tell), lunges, then droops
-- for a moment - the best time to stomp its head.
function BEHAVIOUR.snapper(e, dt, now)
	local pitch = 0
	if e.state == "idle" then
		pitch = math.sin(now * 1.6 + e.phase) * 0.08
		if now > e.t0 then
			local _, hrp = nearestPlayer(e.pos, 13, 7)
			if hrp then
				e.yaw = lookYaw(e.pos, hrp.Position)
				e.state = "wind"
				e.t0 = now
			else
				e.yaw += math.sin(now + e.phase) * 0.05
				e.t0 = now + 0.2
			end
		end
	elseif e.state == "wind" then
		local u = math.clamp((now - e.t0) / 0.5, 0, 1)
		pitch = 0.4 * u + math.sin(now * 40) * 0.03
		if u >= 1 then
			e.state = "lunge"
			e.t0 = now
		end
	elseif e.state == "lunge" then
		local u = math.clamp((now - e.t0) / 0.15, 0, 1)
		pitch = 0.4 - 1.45 * u
		if now - e.t0 > 0.45 then
			e.state = "tired"
			e.t0 = now
		end
	else -- tired
		local u = math.clamp((now - e.t0) / 1.1, 0, 1)
		pitch = -1.05 * (1 - u)
		if u >= 1 then
			e.state = "idle"
			e.t0 = now + 0.8
		end
	end
	place(e, 0, pitch)
	local cf = CFrame.new(center(e)) * CFrame.Angles(0, e.yaw, 0) * CFrame.Angles(pitch, 0, 0)
	e.head = (cf * CFrame.new(0, 4.6, 0)).Position
	if e.extra and e.extra.jaw then
		local open = (e.state == "wind" and 0.6) or (e.state == "lunge" and (now - e.t0 < 0.12 and 0.6 or 0)) or 0.15
		e.extra.jaw.CFrame = cf * e.extra.jawRest * CFrame.Angles(-open, 0, 0) * e.extra.jawLocal
	end
end

-- Puffer: a grumpy little cloud. Drifts, turns to face you, puffs up, then
-- blows a gust that shoves you back (straight off a cloud, if you're careless)
function BEHAVIOUR.puffer(e, dt, now)
	local drift = Vector3.new(math.cos(now * 0.5 + e.phase) * 3, math.sin(now * 1.3 + e.phase) * 0.8, math.sin(now * 0.5 + e.phase) * 3)
	e.pos = e.pos:Lerp(e.home + drift, math.clamp(dt * 2, 0, 1))
	local scale = 1
	if e.state == "idle" then
		if now > e.t0 then
			local _, hrp = nearestPlayer(e.pos, 36, 14)
			if hrp then
				e.yaw = lookYaw(e.pos, hrp.Position)
				e.state = "swell"
				e.t0 = now
			else
				e.t0 = now + 0.4
			end
		end
	elseif e.state == "swell" then
		local _, hrp = nearestPlayer(e.pos, 40, 14)
		if hrp then
			e.yaw = lookYaw(e.pos, hrp.Position)
		end
		local u = math.clamp((now - e.t0) / 0.9, 0, 1)
		scale = 1 + u * 0.35
		if u >= 1 then
			e.state = "blow"
			e.t0 = now
			e.blown = {}
			callbacks.effect("gust", e.pos, forward(e.yaw))
		end
	elseif e.state == "blow" then
		scale = 1.35 - math.clamp((now - e.t0) / 0.3, 0, 1) * 0.45
		local dir = forward(e.yaw)
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and not e.blown[player] then
				local to = hrp.Position - e.pos
				local flat = Vector3.new(to.X, 0, to.Z)
				if flat.Magnitude < 32 and math.abs(to.Y) < 12 and flat.Magnitude > 0.1 and flat.Unit:Dot(dir) > 0.8 then
					e.blown[player] = true
					callbacks.gust(player, dir * 58 + Vector3.new(0, 24, 0))
				end
			end
		end
		if now - e.t0 > 1.0 then
			e.state = "idle"
			e.t0 = now + 2.4 + math.random()
		end
	end
	place(e)
	if e.extra and e.extra.puffs then
		local root = e.model.PrimaryPart.CFrame
		for _, pf in ipairs(e.extra.puffs) do
			pf.part.Size = pf.size * scale
			pf.part.CFrame = root * CFrame.new(pf.cf.Position * scale) * pf.cf.Rotation
		end
	end
end

--------------------------------------------------------------------------------
-- Contact with bunnies
--------------------------------------------------------------------------------

local function contact(e, now)
	local shape = SHAPE[e.kind]
	if e.kind == "mossling" and (e.state == "idle" or e.state == "sink") then
		return -- tucked away under the moss
	end
	local c = e.head or center(e)
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local p = root.Position
			local feet = p.Y - FEET
			local flat = Vector3.new(p.X - c.X, 0, p.Z - c.Z).Magnitude
			local bottom = c.Y - (shape.below or shape.lift)
			local top = bottom + shape.top
			-- spore puffs reach further than the body
			if e.kind == "puffshroom" and e.state == "puff" and flat < 8.5 and feet < top + 2 and feet > bottom - 3 then
				callbacks.hurt(player, c)
			elseif flat < shape.radius and feet < top + 0.8 and p.Y + 2 > bottom then
				local vy = root.AssemblyLinearVelocity.Y
				local pounding = (poundingUntil[player] or 0) > now
				local move = char:GetAttribute("Move")
				local stomping = (vy < -1 and feet > top - 1.4) or pounding
				if e.kind == "thornhog" then
					-- spikes: only a shockwave works, everything else hurts
					callbacks.hurt(player, c)
					if stomping then
						callbacks.bounce(player, Vector3.new(0, 55, 0), true)
					end
				elseif stomping then
					defeat(e, player)
					callbacks.bounce(player, Vector3.new(0, Config.StompBounce, 0), true)
					return
				elseif move and ATTACK_MOVES[move] and e.kind ~= "puffshroom" and e.kind ~= "puffer" then
					defeat(e, player)
					return
				else
					callbacks.hurt(player, c)
				end
			end
		end
	end
end

function EnemyService.Step(dt)
	local now = os.clock()
	for _, e in ipairs(enemies) do
		if not e.alive then
			if now >= e.respawnAt then
				e.alive = true
				e.pos = e.home
				e.state = "idle"
				e.t0 = now + 1
				e.model.Parent = folder
				callbacks.effect("poof", center(e))
			end
			continue
		end
		BEHAVIOUR[e.kind](e, dt, now)
		contact(e, now)
	end
end

Players.PlayerRemoving:Connect(function(player)
	poundingUntil[player] = nil
end)

return EnemyService
