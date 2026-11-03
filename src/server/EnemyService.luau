--[[
	EnemyService - all the baddies' brains and bodies.

	  bug         Grumblebug      wanders, spots you, charges          stomp / pound / roll / slide / dive
	  toad        Hopscotch Toad  hops after you in big arcs           stomp / pound / roll / slide / dive
	  bat         Flitbat         circles, swoops at you               stomp / roll / long jump / pound wave
	  thornhog    Thornhog        patrols, charges, skids on overshoot ONLY a ground-pound shockwave (spikes!)
	  puffshroom  Puffshroom      puffs a ring of spores               stomp it between puffs
	  mossling    Mossling        hides in the moss, pops up, chases   stomp / pound / roll / slide / dive
	  snapper     Snapper         rooted; rears back, lunges           stomp its head (best while it's tired)
	  puffer      Puffer          floating cloud, blows you away       stomp it from above

	Ground baddies have real little bodies (like Mario 64's Goombas): velocity
	with acceleration, gravity, ground snapping and step-ups, feelers for walls
	and ledges (they won't wander off a cliff), and they lean to the slope
	they're standing on. Their brains:
	  wander (walk to a spot near home, pause, repeat)
	  -> notice (they need to SEE you: line of sight; "!" and a hop)
	  -> chase (accelerate toward you)
	  -> give up ("?" and walk home) when you're too far, gone too long, or out of reach.

	The server runs brains and bodies at 20 Hz for baddies near a player (the
	rest sleep). Each baddie's transform is published ~10 times a second as the
	model's "CF" attribute with its velocity ("Vel"), plus "St" for its state,
	"Alert" ("!" or "?") and "Alive"; client/Baddies predicts and smooths between
	updates and adds the snappy animation, so they move smoothly for everyone.

	Defeated baddies come back after Config.BugRespawnSeconds. Bosses can call
	in extra, temporary ones with EnemyService.Spawn.
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

local ATTACK_MOVES = { roll = true, slide = true, longjump = true, dive = true }
local FEET = 2.6 -- HumanoidRootPart centre to feet
local GRAVITY = 140
local TICK = 1 / 20 -- brains and bodies run at 20 Hz
local AWAKE_DIST = 340 -- baddies further than this from every player sleep
local SEND_EVERY = 0.1
local SEE_DIST = 300
local UP = Vector3.new(0, 1, 0)

-- Per-kind shape: how high the centre sits above the feet, contact radius,
-- height of the top, body radius for wall/ledge feelers
local SHAPE = {
	bug = { lift = 1.8, radius = 4.4, top = 4.0, body = 2.8 },
	toad = { lift = 1.6, radius = 3.6, top = 3.2, body = 2.2 },
	bat = { lift = 0, below = 1.6, radius = 3.2, top = 1.6 },
	thornhog = { lift = 2.0, radius = 3.6, top = 4.2, body = 2.3 },
	puffshroom = { lift = 1.9, radius = 3.4, top = 5.0 },
	mossling = { lift = 1.6, radius = 3.6, top = 3.4, body = 2.2 },
	snapper = { lift = 1.5, radius = 3.4, top = 3.2 }, -- measured around its head
	puffer = { lift = 0, below = 1.8, radius = 3.8, top = 3.4 },
}

-- Kinds that hover at their home point instead of standing on the ground
local FLYING = { bat = true, puffer = true }
-- Kinds that never leave their spot
local ROOTED = { puffshroom = true, snapper = true }

local BEHAVIOUR = {} -- (filled in below)

--------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------

local function groundHit(pos, above, depth)
	return workspace:Raycast(pos + Vector3.new(0, above or 4, 0), Vector3.new(0, -((above or 4) + (depth or 30)), 0), rayParams)
end

local function badFloor(part)
	return part and (part:GetAttribute("Lava") or part:GetAttribute("Water") or part:GetAttribute("Slide") or part:GetAttribute("Moving"))
end

local function center(e)
	if FLYING[e.kind] then
		return e.pos
	end
	return e.pos + e.up * (SHAPE[e.kind].lift + (e.lift or 0))
end

local function lookYaw(from, to)
	local d = to - from
	return math.atan2(-d.X, -d.Z)
end

local function forward(yaw)
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- Turn toward a heading at a limited rate, so baddies swing round rather than snap
local function turnToward(e, yaw, rate, dt)
	local d = (yaw - e.yaw + math.pi) % (math.pi * 2) - math.pi
	local step = rate * dt
	e.yaw += math.clamp(d, -step, step)
	return math.abs(d) < 0.3
end

-- Build the published transform: centre, heading, tilted to the ground under it
local function place(e, pitch, roll)
	local fwd = forward(e.yaw)
	local up = FLYING[e.kind] and UP or e.up
	local right = fwd:Cross(up)
	if right.Magnitude < 0.01 then
		right = fwd:Cross(UP)
	end
	right = right.Unit
	local look = up:Cross(right).Unit
	local cf = CFrame.fromMatrix(center(e), right, up, -look)
	e.cf = cf * CFrame.Angles(pitch or 0, 0, roll or 0)
end

-- "!" (spotted you) or "?" (lost you) over its head, with a little hop on "!"
local function alert(e, kind)
	local now = os.clock()
	if now - (e.alertAt or -10) > 1.5 then
		e.alertAt = now
		e.model:SetAttribute("AlertKind", kind or "!")
		e.model:SetAttribute("Alert", workspace:GetServerTimeNow())
	end
end

-- Living players (and whether this baddie can see them)
local function canSee(e, hrp)
	local eye = center(e) + Vector3.new(0, 1.5, 0)
	local to = hrp.Position - eye
	local hit = workspace:Raycast(eye, to, rayParams)
	return hit == nil or (hit.Position - eye).Magnitude > to.Magnitude - 2
end

local function nearestPlayer(e, maxDist, maxDy, needSight)
	local best, bestDist, bestHrp = nil, maxDist, nil
	local pos = e.pos
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 and char:GetAttribute("Move") ~= "talk" then
			local d = (hrp.Position - pos).Magnitude
			if d < bestDist and math.abs(hrp.Position.Y - FEET - pos.Y) < maxDy and (not needSight or canSee(e, hrp)) then
				best, bestDist, bestHrp = player, d, hrp
			end
		end
	end
	return best, bestHrp, bestDist
end

--------------------------------------------------------------------------------
-- Bodies: walk toward a wanted velocity, with gravity, step-ups, wall and
-- ledge feelers. Returns "wall" / "ledge" when it had to stop.
--------------------------------------------------------------------------------

local function move(e, wantVel, accel, dt, allowDrop)
	local shape = SHAPE[e.kind]
	-- ease the horizontal velocity toward what the brain wants
	local hv = flat(e.vel)
	local diff = wantVel - hv
	local maxStep = accel * dt
	if diff.Magnitude > maxStep then
		diff = diff.Unit * maxStep
	end
	hv += diff

	local blocked = nil
	if e.grounded and hv.Magnitude > 0.5 then
		local dir = hv.Unit
		local reach = shape.body + 1
		-- wall feeler at knee and body height
		for _, h in ipairs({ 0.9, shape.lift + 0.6 }) do
			local from = e.pos + Vector3.new(0, h, 0)
			local hit = workspace:Raycast(from, dir * reach, rayParams)
			if hit and hit.Normal.Y < 0.55 then
				blocked = "wall"
				break
			end
		end
		-- ledge feeler: is there ground just ahead, not too far down?
		if not blocked then
			local ahead = e.pos + dir * reach
			local hit = groundHit(ahead, 4, 12)
			local drop = hit and (e.pos.Y - hit.Position.Y) or math.huge
			if not hit or badFloor(hit.Instance) or hit.Position.Y < Config.WaterLevel + 1 or drop > (allowDrop or 3.5) then
				blocked = "ledge"
			end
		end
		if blocked then
			hv = Vector3.zero
		end
	end

	local newPos = e.pos + hv * dt
	local vy = e.vel.Y
	-- gravity and ground
	local hit = groundHit(newPos, 3.2, 6 + math.max(0, -vy * dt))
	local groundY = hit and hit.Position.Y
	if e.grounded and groundY and newPos.Y - groundY < 3.5 and groundY - newPos.Y < 3.2 then
		-- stay glued to the ground, stepping up or down small bumps
		newPos = Vector3.new(newPos.X, groundY, newPos.Z)
		vy = 0
		e.grounded = true
		e.groundNormal = hit.Normal
	else
		vy -= GRAVITY * dt
		newPos += Vector3.new(0, vy * dt, 0)
		if groundY and newPos.Y <= groundY and vy <= 0 then
			newPos = Vector3.new(newPos.X, groundY, newPos.Z)
			vy = 0
			e.grounded = true
			e.groundNormal = hit.Normal
			e.landedAt = os.clock()
		else
			e.grounded = false
		end
	end
	e.vel = Vector3.new(hv.X, vy, hv.Z)
	e.pos = newPos
	-- lean to the slope (smoothed), but never more than ~30 degrees
	local n = e.grounded and e.groundNormal or UP
	if n.Y < 0.86 then
		n = (flat(n).Unit * 0.5 + UP * 0.866).Unit
	end
	e.up = e.up:Lerp(n, math.clamp(dt * 8, 0, 1)).Unit
	return blocked
end

-- Fell somewhere it shouldn't be (the sea, lava): gone until it respawns
local function outOfBounds(e)
	if e.pos.Y < Config.WaterLevel - 4 then
		return true
	end
	if (e.pos - e.home).Magnitude > 160 then
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- Defeat and respawn
--------------------------------------------------------------------------------

local function defeat(e, player)
	if not e.alive then
		return
	end
	e.alive = false
	e.respawnAt = os.clock() + Config.BugRespawnSeconds
	callbacks.effect("poof", center(e))
	e.model:SetAttribute("Alive", false) -- the client squashes it and hides it
	if player then
		callbacks.bopped(player)
	end
end

local function reset(e, now)
	e.pos = e.home
	e.vel = Vector3.zero
	e.up = UP
	e.grounded = not FLYING[e.kind]
	e.state = "idle"
	e.lift = 0
	e.t0 = now + 1 + math.random()
	e.goal = nil
	e.target = nil
	e.popped = false
	e.hadTarget = false
end

local function build(e)
	if e.kind == "bug" then
		e.model = BugModel.Build(e.skin, 1, CFrame.new(e.pos))
	else
		e.model, e.extra = EnemyModels[e.kind](e.skin, CFrame.new(e.pos))
	end
	e.model:SetAttribute("Kind", e.kind)
	e.model:SetAttribute("Alive", true)
	e.model:SetAttribute("St", "idle")
	place(e)
	e.model:SetAttribute("CF", e.cf)
	e.model:SetAttribute("Vel", Vector3.zero)
	e.model.Parent = folder
end

local function newEnemy(kind, pos, skin, range, axis, temp)
	local p = pos
	if not FLYING[kind] then
		local hit = groundHit(pos, 10, 40)
		p = Vector3.new(pos.X, hit and hit.Position.Y or pos.Y, pos.Z)
	end
	local e = {
		kind = kind,
		skin = skin,
		home = p,
		pos = p,
		vel = Vector3.zero,
		up = UP,
		grounded = not FLYING[kind],
		yaw = math.random() * math.pi * 2,
		alive = true,
		respawnAt = 0,
		phase = math.random() * 6,
		state = "idle",
		t0 = os.clock() + math.random() * 2,
		fast = skin == "castle",
		range = range or 22,
		axis = axis,
		temp = temp,
		acc = math.random() * TICK,
	}
	build(e)
	table.insert(enemies, e)
	return e
end

--------------------------------------------------------------------------------
-- Brains
--------------------------------------------------------------------------------

-- Pick somewhere to amble to near home
local function wanderGoal(e)
	for _ = 1, 6 do
		local a = math.random() * math.pi * 2
		local r = math.random() * e.range
		local g = e.home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local hit = groundHit(g, 8, 20)
		if hit and not badFloor(hit.Instance) and math.abs(hit.Position.Y - e.pos.Y) < 6 then
			return Vector3.new(g.X, hit.Position.Y, g.Z)
		end
	end
	return e.home
end

-- Shared walk-about-then-chase brain (Grumblebugs, chasing Mosslings)
local function goombaBrain(e, dt, now, opts)
	local fromHome = flat(e.pos - e.home).Magnitude
	if e.state == "idle" or e.state == "walk" then
		-- look for a bunny now and then
		if now > (e.lookAt or 0) then
			e.lookAt = now + 0.25
			local player, hrp = nearestPlayer(e, opts.notice, 10, true)
			if player then
				e.target = player
				e.state = "notice"
				e.t0 = now
				e.vel = Vector3.new(0, opts.hop, 0)
				e.grounded = false
				alert(e, "!")
				return Vector3.zero, opts.accel
			end
		end
		if e.state == "idle" then
			if now > e.t0 then
				e.goal = wanderGoal(e)
				e.state = "walk"
				e.t0 = now + 6
			end
			return Vector3.zero, opts.accel
		end
		-- walk to the goal
		local to = flat(e.goal - e.pos)
		if to.Magnitude < 2 or now > e.t0 then
			e.state = "idle"
			e.t0 = now + 0.8 + math.random() * 1.8
			return Vector3.zero, opts.accel
		end
		turnToward(e, lookYaw(Vector3.zero, to), 4, dt)
		return forward(e.yaw) * opts.walk, opts.accel
	elseif e.state == "notice" then
		-- the "!" moment: hop and turn to face you
		local hrp = e.target and e.target.Character and e.target.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			turnToward(e, lookYaw(e.pos, hrp.Position), 10, dt)
		end
		if now - e.t0 > 0.45 then
			e.state = "chase"
			e.t0 = now
		end
		return Vector3.zero, opts.accel
	elseif e.state == "chase" then
		local char = e.target and e.target.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local giveUp = not hrp or not hum or hum.Health <= 0 or now - e.t0 > opts.patience
			or fromHome > e.range + opts.leash or (hrp.Position - e.pos).Magnitude > opts.notice * 1.8
			or math.abs(hrp.Position.Y - FEET - e.pos.Y) > 14
		if giveUp then
			e.state = "home"
			e.t0 = now
			alert(e, "?")
			return Vector3.zero, opts.accel
		end
		turnToward(e, lookYaw(e.pos, hrp.Position), opts.turn, dt)
		return forward(e.yaw) * opts.run, opts.accel, 6
	else -- "home": amble back, then carry on wandering
		local to = flat(e.home - e.pos)
		if to.Magnitude < 3 or now - e.t0 > 12 then
			e.state = "idle"
			e.t0 = now + 1
			return Vector3.zero, opts.accel
		end
		if now - e.t0 < 0.8 then
			return Vector3.zero, opts.accel -- a puzzled pause first
		end
		turnToward(e, lookYaw(Vector3.zero, to), 4, dt)
		return forward(e.yaw) * opts.walk, opts.accel, 6
	end
end

function BEHAVIOUR.bug(e, dt, now)
	local want, accel, drop = goombaBrain(e, dt, now, {
		notice = 34, hop = 22, walk = e.fast and 8 or 6, run = e.fast and 19 or 16, accel = 40, turn = 6,
		patience = 9, leash = 40,
	})
	local blocked = move(e, want, accel, dt, drop)
	if blocked and e.state == "walk" then
		e.state = "idle" -- bumped into something: think again
		e.t0 = now + 0.4
	elseif blocked and e.state == "chase" then
		e.stuckFor = (e.stuckFor or 0) + dt
		if e.stuckFor > 1.2 then
			e.stuckFor = 0
			e.state = "home"
			e.t0 = now
			alert(e, "?")
		end
	else
		e.stuckFor = 0
	end
	place(e)
end

function BEHAVIOUR.mossling(e, dt, now)
	local HIDDEN = -2.5
	if e.state == "hidden" or (e.state == "idle" and not e.popped) then
		e.state = "hidden"
		e.lift = HIDDEN + math.sin(now * 1.5 + e.phase) * 0.08
		move(e, Vector3.zero, 40, dt)
		if now > e.t0 then
			e.t0 = now + 0.25
			local player, hrp = nearestPlayer(e, 17, 8, false)
			if player then
				e.state = "pop"
				e.target = player
				e.t0 = now
				e.yaw = lookYaw(e.pos, hrp.Position)
				alert(e, "!")
				callbacks.effect("poof", e.pos + Vector3.new(0, 1, 0))
			end
		end
	elseif e.state == "pop" then
		local u = math.clamp((now - e.t0) / 0.35, 0, 1)
		e.lift = HIDDEN * (1 - u) + math.sin(u * math.pi) * 2
		move(e, Vector3.zero, 40, dt)
		if u >= 1 then
			e.lift = 0
			e.popped = true
			e.state = "chase"
			e.t0 = now
		end
	elseif e.state == "sink" then
		local u = math.clamp((now - e.t0) / 0.5, 0, 1)
		e.lift = HIDDEN * u
		move(e, Vector3.zero, 40, dt)
		if u >= 1 then
			e.popped = false
			e.state = "hidden"
			e.t0 = now + 2
		end
	else
		local want, accel, drop = goombaBrain(e, dt, now, {
			notice = 20, hop = 16, walk = 9, run = 14, accel = 34, turn = 6, patience = 7, leash = 30,
		})
		move(e, want, accel, dt, drop)
		if e.state == "idle" then
			-- back home: burrow down again
			e.state = "sink"
			e.t0 = now
		end
	end
	place(e)
end

function BEHAVIOUR.toad(e, dt, now)
	if e.grounded and e.state == "hop" and now - e.t0 > 0.15 then
		e.state = "idle"
		e.t0 = now + 0.7 + math.random() * 1.0
	end
	if e.state == "idle" then
		move(e, Vector3.zero, 60, dt)
		if now > e.t0 and e.grounded then
			local player, hrp = nearestPlayer(e, 40, 12, true)
			local fromHome = flat(e.pos - e.home)
			if hrp then
				if not e.hadTarget then
					alert(e, "!")
				end
				e.yaw = lookYaw(e.pos, hrp.Position)
			elseif fromHome.Magnitude > e.range then
				e.yaw = lookYaw(e.pos, e.home)
			else
				e.yaw += (math.random() - 0.5) * 2.4
			end
			e.hadTarget = player ~= nil
			-- a big arcing hop (won't hop off a cliff)
			local dist = player and 15 or 10
			local dest = e.pos + forward(e.yaw) * dist
			local hit = groundHit(dest, 10, 16)
			if hit and not badFloor(hit.Instance) and math.abs(hit.Position.Y - e.pos.Y) < 8 then
				e.state = "hop"
				e.t0 = now
				local airtime = 0.75
				e.vel = forward(e.yaw) * (dist / airtime) + Vector3.new(0, GRAVITY * airtime / 2, 0)
				e.grounded = false
			else
				e.yaw += math.pi
				e.t0 = now + 0.5
			end
		end
	else
		move(e, flat(e.vel), 0, dt, 50)
	end
	place(e, e.state == "hop" and math.clamp(-e.vel.Y * 0.008, -0.35, 0.35) or 0)
end

function BEHAVIOUR.thornhog(e, dt, now)
	-- patrols along its axis; spots you, charges, and skids when it overshoots
	e.dir = e.dir or 1
	local axis = e.axis or Vector3.new(1, 0, 0)
	local want = Vector3.zero
	local accel = 30
	if e.state == "idle" or e.state == "walk" then
		e.state = "walk"
		local along = flat(e.pos - e.home):Dot(axis)
		if along * e.dir > e.range then
			e.dir = -e.dir
		end
		want = axis * e.dir * (e.fast and 11 or 9)
		turnToward(e, lookYaw(Vector3.zero, want), 5, dt)
		if now > (e.lookAt or 0) then
			e.lookAt = now + 0.3
			local player, hrp = nearestPlayer(e, 26, 5, true)
			if player then
				e.target = player
				e.state = "charge"
				e.t0 = now
				e.chargeDir = flat(hrp.Position - e.pos).Unit
				alert(e, "!")
			end
		end
	elseif e.state == "charge" then
		accel = 45
		want = e.chargeDir * (e.fast and 28 or 24)
		turnToward(e, lookYaw(Vector3.zero, e.chargeDir), 8, dt)
		local hrp = e.target and e.target.Character and e.target.Character:FindFirstChild("HumanoidRootPart")
		local passed = hrp and flat(hrp.Position - e.pos):Dot(e.chargeDir) < -4
		if passed or now - e.t0 > 2.2 then
			e.state = "skid"
			e.t0 = now
		end
	else -- skid to a stop, then go back to patrolling
		accel = 22
		if now - e.t0 > 1.0 then
			e.state = "walk"
		end
	end
	local blocked = move(e, want, accel, dt)
	if blocked then
		if e.state == "walk" then
			e.dir = -e.dir
		elseif e.state == "charge" then
			e.state = "skid"
			e.t0 = now
		end
	end
	place(e) -- the client spins it as it rolls
end

function BEHAVIOUR.bat(e, dt, now)
	local hover = e.home
	local old = e.pos
	if e.state == "idle" then
		e.orbit = (e.orbit or e.phase) + dt * 1.1
		local want = hover + Vector3.new(math.cos(e.orbit) * 10, math.sin(now * 2 + e.phase) * 1.2, math.sin(e.orbit) * 10)
		e.pos = e.pos:Lerp(want, math.clamp(dt * 3, 0, 1))
		e.yaw = e.orbit + math.pi
		if now > e.t0 then
			local _, hrp = nearestPlayer(e, 42, 30, true)
			if hrp then
				e.state = "swoop"
				e.target = hrp.Position
				e.t0 = now
				e.yaw = lookYaw(e.pos, e.target)
				alert(e, "!")
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
	e.vel = (e.pos - old) / dt
	place(e, e.state == "swoop" and -0.5 or 0)
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
	place(e)
end

-- Snapper: a rooted biting plant. Rears back (the tell), lunges, then droops
-- for a moment - the best time to stomp its head.
function BEHAVIOUR.snapper(e, dt, now)
	local pitch = 0
	if e.state == "idle" then
		pitch = math.sin(now * 1.6 + e.phase) * 0.08
		if now > e.t0 then
			local _, hrp = nearestPlayer(e, 13, 7, false)
			if hrp then
				e.yaw = lookYaw(e.pos, hrp.Position)
				e.state = "wind"
				e.t0 = now
				alert(e, "!")
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
	place(e, pitch)
	e.head = (CFrame.new(center(e)) * CFrame.Angles(0, e.yaw, 0) * CFrame.Angles(pitch, 0, 0) * CFrame.new(0, 4.6, 0)).Position
end

-- Puffer: a grumpy little cloud. Drifts, turns to face you, puffs up, then
-- blows a gust that shoves you back (straight off a cloud, if you're careless)
function BEHAVIOUR.puffer(e, dt, now)
	local old = e.pos
	local drift = Vector3.new(math.cos(now * 0.5 + e.phase) * 3, math.sin(now * 1.3 + e.phase) * 0.8, math.sin(now * 0.5 + e.phase) * 3)
	e.pos = e.pos:Lerp(e.home + drift, math.clamp(dt * 2, 0, 1))
	if e.state == "idle" then
		if now > e.t0 then
			local _, hrp = nearestPlayer(e, 36, 14, true)
			if hrp then
				e.yaw = lookYaw(e.pos, hrp.Position)
				e.state = "swell"
				e.t0 = now
				alert(e, "!")
			else
				e.t0 = now + 0.4
			end
		end
	elseif e.state == "swell" then
		local _, hrp = nearestPlayer(e, 40, 14, false)
		if hrp then
			turnToward(e, lookYaw(e.pos, hrp.Position), 4, dt)
		end
		if now - e.t0 > 0.9 then
			e.state = "blow"
			e.t0 = now
			e.blown = {}
			callbacks.effect("gust", e.pos, forward(e.yaw))
		end
	elseif e.state == "blow" then
		local dir = forward(e.yaw)
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and not e.blown[player] then
				local to = hrp.Position - e.pos
				local f = flat(to)
				if f.Magnitude < 32 and math.abs(to.Y) < 12 and f.Magnitude > 0.1 and f.Unit:Dot(dir) > 0.8 then
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
	e.vel = (e.pos - old) / dt
	place(e) -- the client puffs it up and down from its state
end

--------------------------------------------------------------------------------
-- Contact with bunnies
--------------------------------------------------------------------------------

local function contact(e, now)
	local shape = SHAPE[e.kind]
	if e.kind == "mossling" and (e.state == "hidden" or e.state == "sink") then
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
			local d = Vector3.new(p.X - c.X, 0, p.Z - c.Z).Magnitude
			local bottom = c.Y - (shape.below or shape.lift)
			local top = bottom + shape.top
			-- spore puffs reach further than the body
			if e.kind == "puffshroom" and e.state == "puff" and d < 8.5 and feet < top + 2 and feet > bottom - 3 then
				callbacks.hurt(player, c)
			elseif d < shape.radius and feet < top + 0.8 and p.Y + 2 > bottom then
				local vy = root.AssemblyLinearVelocity.Y
				local pounding = (poundingUntil[player] or 0) > now
				local mv = char:GetAttribute("Move")
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
				elseif mv and ATTACK_MOVES[mv] and e.kind ~= "puffshroom" and e.kind ~= "puffer" then
					defeat(e, player)
					return
				else
					callbacks.hurt(player, c)
					-- bump back a little, like a Goomba bonking you
					if not ROOTED[e.kind] and not FLYING[e.kind] then
						local away = flat(e.pos - p)
						if away.Magnitude > 0.1 then
							e.vel = away.Unit * 10 + Vector3.new(0, 14, 0)
							e.grounded = false
						end
					end
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Publishing to clients
--------------------------------------------------------------------------------

local viewers = {}

local function nearAViewer(p, dist)
	for _, v in ipairs(viewers) do
		if (v - p).Magnitude < dist then
			return true
		end
	end
	return false
end

local function publish(e, now)
	if e.state ~= e.sentState then
		e.sentState = e.state
		e.model:SetAttribute("St", e.state)
	end
	if not e.cf or now < (e.sendAt or 0) then
		return
	end
	e.sendAt = now + SEND_EVERY
	local last = e.sentCf
	if last and (last.Position - e.cf.Position).Magnitude < 0.05 and last.LookVector:Dot(e.cf.LookVector) > 0.9997
		and last.UpVector:Dot(e.cf.UpVector) > 0.9997 then
		if e.sentMoving then
			e.sentMoving = false
			e.model:SetAttribute("Vel", Vector3.zero)
		end
		return
	end
	if nearAViewer(e.cf.Position, SEE_DIST) then
		e.sentCf = e.cf
		e.sentMoving = true
		e.model:SetAttribute("Vel", e.vel or Vector3.zero)
		e.model:SetAttribute("CF", e.cf)
	end
end

--------------------------------------------------------------------------------
-- Main loop
--------------------------------------------------------------------------------

local warned = {}
local function think(e, now)
	BEHAVIOUR[e.kind](e, TICK, now)
	if not FLYING[e.kind] and not ROOTED[e.kind] and outOfBounds(e) then
		defeat(e, nil) -- fell into the sea: it'll come back later
		return
	end
	contact(e, now)
end

function EnemyService.Step(dt)
	local now = os.clock()
	table.clear(viewers)
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			table.insert(viewers, hrp.Position)
		end
	end
	for i = #enemies, 1, -1 do
		local e = enemies[i]
		if e.gone or (e.temp and not e.alive) then
			-- a boss's minion: gone for good once bopped
			if not e.gone then
				e.gone = true
				task.delay(0.6, function()
					e.model:Destroy()
				end)
			end
			table.remove(enemies, i)
			continue
		end
		if not e.alive then
			if now >= e.respawnAt then
				e.alive = true
				reset(e, now)
				place(e)
				e.sentCf = e.cf
				e.model:SetAttribute("Vel", Vector3.zero)
				e.model:SetAttribute("CF", e.cf)
				e.model:SetAttribute("Alive", true)
				callbacks.effect("poof", center(e))
			end
			continue
		end
		-- far from everyone: sleep
		if not nearAViewer(e.pos, AWAKE_DIST) then
			continue
		end
		e.acc += dt
		while e.acc >= TICK do
			e.acc -= TICK
			local ok, err = pcall(think, e, now)
			if not ok then
				if not warned[e.kind] then
					warned[e.kind] = true
					warn("[Bunny64] EnemyService " .. e.kind .. ": " .. tostring(err))
				end
				e.acc = 0
				break
			end
			if not e.alive then
				break
			end
		end
		publish(e, now)
	end
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function EnemyService.Start(info, cb)
	callbacks = cb
	folder = Instance.new("Folder")
	folder.Name = "Baddies"
	folder.Parent = workspace
	rayParams.FilterDescendantsInstances = { info.solidFolder, workspace.Terrain }
	for _, def in ipairs(info.enemies) do
		newEnemy(def.kind, def.pos, def.skin, def.range, def.axis, false)
	end
	RunService.Heartbeat:Connect(function(dt)
		EnemyService.Step(math.min(dt, 0.25))
	end)
end

-- Bosses call in extra baddies: they don't respawn and vanish when despawned
function EnemyService.Spawn(kind, pos, skin, range)
	if not folder or not BEHAVIOUR[kind] then
		return nil
	end
	return newEnemy(kind, pos, skin, range or 30, nil, true)
end

function EnemyService.Despawn(e)
	if e and e.model then
		e.gone = true
		e.alive = false
		e.model:Destroy()
	end
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

Players.PlayerRemoving:Connect(function(player)
	poundingUntil[player] = nil
end)

return EnemyService
