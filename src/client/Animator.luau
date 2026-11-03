--[[
	Animator - procedural animation for every bunny in the server.

	No animation assets: each frame we work out a pose from what the bunny is
	doing (its move and velocity), ease toward it, and write Motor6D.Transform.
	Ears and the body hang on little springs, so landings, turns and stops
	have follow-through instead of snapping.

	The local bunny's move comes straight from Movement; other players' moves
	come from the "Move" attribute the server sets.

	Robustness: each bunny is animated inside a pcall, so a problem with one
	(e.g. a half-loaded character) can't freeze everyone else's animation, and
	a character whose joints aren't there yet is looked for again a moment later.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local Animator = {}

local player = Players.LocalPlayer
local Movement
local rigs = {} -- [Model] = rig data, or { retryAt = t } while its joints are missing
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local JOINTS = {
	root = "RootJoint", neck = "Neck", lArm = "LeftShoulder", rArm = "RightShoulder",
	lLeg = "LeftHip", rLeg = "RightHip", lEar = "LeftEarJoint", rEar = "RightEarJoint",
}
local I = CFrame.identity
local A = CFrame.Angles
local TAU = math.pi * 2

local function findRig(char)
	local motors = {}
	for key, name in pairs(JOINTS) do
		local m = char:FindFirstChild(name, true)
		if not m or not m:IsA("Motor6D") then
			return nil
		end
		motors[key] = m
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		return nil
	end
	local cur = {}
	for key in pairs(JOINTS) do
		cur[key] = I
	end
	return {
		motors = motors,
		cur = cur,
		phase = math.random() * 6,
		ears = { l = { a = 0, v = 0 }, r = { a = 0, v = 0 } },
		lean = { x = 0, vx = 0, z = 0, vz = 0 }, -- body follow-through spring
		twitchAt = os.clock() + 3,
		twitch = 0,
		lookAt = os.clock() + 4,
		look = 0,
		spin = 0,
		zipSwing = 0,
		lastVel = Vector3.zero,
		root = root,
		hum = hum,
	}
end

local function easeOut(u)
	u = math.clamp(u, 0, 1)
	return 1 - (1 - u) * (1 - u)
end

-- Work out the pose for one bunny this frame
local function poseFor(rig, char, dt, now, isLocal)
	local root, hum = rig.root, rig.hum
	local v = root.AssemblyLinearVelocity
	local hv = Vector3.new(v.X, 0, v.Z).Magnitude
	local vy = v.Y
	local t = now

	-- acceleration in the bunny's own frame drives the body's follow-through
	local accel = (v - rig.lastVel) / math.max(dt, 1 / 240)
	rig.lastVel = v
	local localAccel = root.CFrame:VectorToObjectSpace(Vector3.new(accel.X, 0, accel.Z))

	-- what is this bunny doing?
	local move, moveAge, flipAge, grounded
	if isLocal then
		local s = Movement.State()
		move = s.move or ""
		moveAge = now - (s.moveStart or now)
		flipAge = now - (s.flipAt or -10)
		grounded = hum.FloorMaterial ~= Enum.Material.Air
	else
		move = char:GetAttribute("Move") or ""
		local at = char:GetAttribute("MoveAt") or 0
		local age = workspace:GetServerTimeNow() - at
		moveAge = age
		flipAge = (move == "flip") and age or 10
		if move == "flip" then
			move = ""
		end
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -3.8, 0), rayParams)
		grounded = hit ~= nil
	end

	local p = {
		root = I, neck = I, lArm = A(0, 0, -0.12), rArm = A(0, 0, 0.12),
		lLeg = I, rLeg = I,
	}
	local extra = I
	local earTarget = math.clamp(-vy * 0.018 + hv * 0.022, -0.5, 1.3)
	local springy = true -- body follow-through on/off for this pose

	if hum.Health <= 0 then
		p.root = CFrame.new(0, -1.7, 0.4) * A(1.45, 0, 0)
		p.lArm, p.rArm = A(0, 0, -1.6), A(0, 0, 1.6)
		p.lLeg, p.rLeg = A(0.3, 0, -0.2), A(0.3, 0, 0.2)
		earTarget = -0.4
		springy = false
	elseif move == "wave" then
		p.rArm = A(0, 0, 2.6 + math.sin(t * 12) * 0.35)
		p.lArm = A(0, 0, -0.2)
		p.neck = A(0.05, -0.15, math.sin(t * 3) * 0.08)
		p.root = A(0, 0, -0.06)
		earTarget = 0.1
	elseif move == "dance" then
		local beat = t * 7
		p.root = CFrame.new(0, math.abs(math.sin(beat)) * 0.35, 0) * A(0, math.sin(beat * 0.5) * 0.5, math.sin(beat) * 0.15)
		p.lArm = A(0, 0, -1.6 - math.sin(beat) * 0.9)
		p.rArm = A(0, 0, 1.6 - math.sin(beat) * 0.9)
		p.lLeg = A(math.max(0, math.sin(beat)) * 0.7, 0, 0)
		p.rLeg = A(math.max(0, -math.sin(beat)) * 0.7, 0, 0)
		p.neck = A(0, 0, math.sin(beat) * 0.2)
		earTarget = 0.6 + math.sin(beat) * 0.6
	elseif move == "sit" then
		p.root = CFrame.new(0, -1.15, 0) * A(-0.05, 0, 0)
		p.lLeg, p.rLeg = A(1.5, 0, -0.15), A(1.5, 0, 0.15)
		p.lArm, p.rArm = A(0.6, 0, -0.2), A(0.6, 0, 0.2)
		p.neck = A(-0.05, math.sin(t * 0.5) * 0.3, 0)
		earTarget = -0.2 + math.sin(t * 1.3) * 0.1
		springy = false
	elseif move == "talk" then
		p.neck = A(0.05 + math.abs(math.sin(t * 9)) * 0.08, 0, math.sin(t * 2) * 0.05)
		p.lArm = A(0, 0, -0.25 - math.abs(math.sin(t * 4)) * 0.3)
		p.rArm = A(0, 0, 0.2)
		earTarget = 0.2
	elseif move == "cheer" then
		-- golden carrot get! bounce on the spot with both paws in the air
		local hop = math.abs(math.sin(t * 9))
		p.root = CFrame.new(0, hop * 0.7, 0) * A(0.1, math.sin(t * 4.5) * 0.3, 0)
		p.lArm, p.rArm = A(0, 0, -2.75 + hop * 0.2), A(0, 0, 2.75 - hop * 0.2)
		p.lLeg, p.rLeg = A(0.3 * hop, 0, -0.1), A(0.3 * hop, 0, 0.1)
		p.neck = A(0.35, 0, 0)
		earTarget = 1.0 - hop
		springy = false
	elseif move == "roll" then
		-- curled into a ball, tumbling forward as fast as we're moving
		rig.spin += dt * (8 + hv * 0.32)
		extra = CFrame.new(0, -1.05, 0) * A(-rig.spin, 0, 0) * CFrame.new(0, 0.25, 0)
		p.lLeg, p.rLeg = A(1.7, 0, 0.1), A(1.7, 0, -0.1)
		p.lArm, p.rArm = A(1.5, 0, 0.55), A(1.5, 0, -0.55)
		p.neck = A(-0.7, 0, 0)
		earTarget = -0.6
		springy = false
	elseif move == "longjump" or move == "fly" then
		-- the superhero stretch
		p.root = A(-1.2, 0, 0)
		p.lArm, p.rArm = A(2.8, 0, 0.18), A(2.8, 0, -0.18)
		p.lLeg = A(-0.5 + math.sin(t * 10) * 0.08, 0, -0.08)
		p.rLeg = A(-0.25 - math.sin(t * 10) * 0.08, 0, 0.08)
		p.neck = A(0.8, 0, 0)
		earTarget = 1.3
		springy = false
	elseif move == "dive" then
		-- arms out in front, belly first, ears streaming
		local u = easeOut(moveAge / 0.18)
		p.root = A(-1.45 * u, 0, 0)
		p.lArm, p.rArm = A(2.95 * u, 0, 0.2), A(2.95 * u, 0, -0.2)
		p.lLeg, p.rLeg = A(-0.35, 0, -0.12), A(-0.35, 0, 0.12)
		p.neck = A(0.95 * u, 0, 0)
		earTarget = 1.35
		springy = false
	elseif move == "slide" then
		p.root = CFrame.new(0, -1.05, 0) * A(-1.38, 0, math.sin(t * 9) * 0.04)
		p.lArm, p.rArm = A(2.85, 0, 0.3), A(2.85, 0, -0.3)
		p.lLeg, p.rLeg = A(-0.12, 0, -0.12), A(-0.12, 0, 0.12)
		p.neck = A(0.95, 0, 0)
		earTarget = 1.3
		springy = false
	elseif move == "walljump" then
		-- kicked off the wall: spread out, then tuck into a spin
		local u = math.clamp(moveAge / 0.3, 0, 1)
		extra = A(-TAU * easeOut(u) * 0.5, 0, 0)
		p.lArm, p.rArm = A(0, 0, -2.2), A(0, 0, 2.2)
		p.lLeg, p.rLeg = A(0.9, 0, -0.3), A(-0.4, 0, 0.3)
		earTarget = 1.1
		springy = false
	elseif move == "pound" then
		local hang = Config.PoundHang
		if moveAge < hang then
			-- a little somersault in the air...
			extra = A(-TAU * easeOut(moveAge / hang), 0, 0)
			p.lLeg, p.rLeg = A(1.6, 0, 0), A(1.6, 0, 0)
			p.lArm, p.rArm = A(1.2, 0, 0.4), A(1.2, 0, -0.4)
		else
			-- ...then bottom first, straight down
			p.root = CFrame.new(0, 0.4, 0) * A(0.2, 0, 0)
			p.lLeg, p.rLeg = A(1.35, 0, -0.2), A(1.35, 0, 0.2)
			p.lArm, p.rArm = A(0, 0, -2.7), A(0, 0, 2.7)
		end
		earTarget = 1.3
		springy = false
	elseif move == "zip" then
		-- hanging from the pulley by both paws; the body swings with speed changes
		local swing = math.clamp(-localAccel.Z * 0.012, -0.6, 0.6)
		rig.zipSwing += (swing - rig.zipSwing) * math.clamp(dt * 3, 0, 1)
		local sway = math.sin(t * 2.4) * 0.08
		p.root = A(rig.zipSwing + sway, 0, math.sin(t * 1.7) * 0.05)
		p.lArm, p.rArm = A(0, 0, -2.95), A(0, 0, 2.95)
		local kick = math.sin(t * 7) * 0.4 * math.clamp(hv / 40, 0.3, 1)
		p.lLeg = A(0.6 + kick, 0, -0.12)
		p.rLeg = A(0.6 - kick, 0, 0.12)
		p.neck = A(-0.25, 0, 0)
		earTarget = 1.25
		springy = false
	elseif move == "backflip" then
		local u = math.clamp(moveAge / 0.75, 0, 1)
		extra = A(TAU * easeOut(u), 0, 0)
		local tuck = math.sin(u * math.pi)
		p.lLeg, p.rLeg = A(1.5 * tuck, 0, 0), A(1.5 * tuck, 0, 0)
		p.lArm, p.rArm = A(0, 0, -2.6 + tuck), A(0, 0, 2.6 - tuck)
		earTarget = -0.3
		springy = false
	elseif move == "spring" then
		local u = math.clamp(moveAge / 0.6, 0, 1)
		extra = A(-TAU * easeOut(u), 0, 0)
		p.lArm, p.rArm = A(0, 0, -2.7), A(0, 0, 2.7)
		p.lLeg, p.rLeg = A(0.4, 0, -0.15), A(-0.2, 0, 0.15)
		earTarget = 1.2
		springy = false
	elseif move == "crouch" then
		local crawl = math.clamp(hv / 7, 0, 1)
		rig.phase += dt * 6 * crawl
		local s = math.sin(rig.phase) * crawl
		p.root = CFrame.new(0, -0.95, 0) * A(-0.3, 0, 0)
		p.lLeg, p.rLeg = A(1.15 + s * 0.3, 0, -0.1), A(1.15 - s * 0.3, 0, 0.1)
		p.lArm, p.rArm = A(0.9 - s * 0.4, 0, -0.2), A(0.9 + s * 0.4, 0, 0.2)
		p.neck = A(0.25, 0, 0)
		earTarget = -0.55
	elseif move == "skid" then
		-- heels dug in, leaning back
		p.root = CFrame.new(0, -0.3, 0) * A(0.45, 0, 0)
		p.lLeg, p.rLeg = A(-0.7, 0, -0.1), A(0.25, 0, 0.1)
		p.lArm, p.rArm = A(0, 0, -1.5), A(0, 0, 1.5)
		p.neck = A(-0.2, 0, 0)
		earTarget = 1.1
		springy = false
	elseif not grounded then
		local rising = vy > 0
		p.lLeg = A(rising and 0.8 or 0.35, 0, 0)
		p.rLeg = A(rising and -0.25 or 0.15, 0, 0)
		p.lArm = A(0, 0, rising and -2.3 or -1.3)
		p.rArm = A(0, 0, rising and 2.3 or 1.3)
		p.root = A(-0.08, 0, 0)
		if not rising and vy < -60 then
			-- a long fall: flailing
			p.lArm = A(0, 0, -2.4 + math.sin(t * 18) * 0.4)
			p.rArm = A(0, 0, 2.4 - math.sin(t * 18) * 0.4)
		end
		if flipAge < 0.45 then
			local u = flipAge / 0.45
			extra = A(-TAU * easeOut(u), 0, 0)
			p.lLeg, p.rLeg = A(1.4, 0, 0), A(1.4, 0, 0)
			p.lArm, p.rArm = A(1.2, 0, 0.3), A(1.2, 0, -0.3)
		end
	else
		local f = math.clamp(hv / 24, 0, 1.3)
		rig.phase += dt * (5 + hv * 0.55)
		local s = math.sin(rig.phase)
		p.lLeg = A(s * 0.95 * f, 0, 0)
		p.rLeg = A(-s * 0.95 * f, 0, 0)
		p.lArm = A(-s * 0.75 * f, 0, -0.15 - 0.1 * f)
		p.rArm = A(s * 0.75 * f, 0, 0.15 + 0.1 * f)
		local idle = math.clamp(1 - f, 0, 1)
		p.root = CFrame.new(0, math.abs(math.cos(rig.phase)) * 0.28 * f + math.sin(t * 2.2) * 0.05 * idle, 0)
			* A(-0.16 * f, 0, s * 0.05 * f)
		-- now and then, an idle bunny looks around
		if idle > 0.9 and now > rig.lookAt then
			rig.lookAt = now + 3 + math.random() * 4
			rig.look = (math.random() - 0.5) * 1.4
		elseif idle < 0.5 then
			rig.look = 0
		end
		p.neck = A(0.08 * f + math.sin(t * 1.7) * 0.04 * idle, rig.look * idle, math.sin(t * 0.9) * 0.05 * idle)
		-- idle breathing in the arms
		p.lArm = p.lArm * A(0, 0, -math.sin(t * 2.2) * 0.04 * idle)
		p.rArm = p.rArm * A(0, 0, math.sin(t * 2.2) * 0.04 * idle)
		-- landing squash: knees give, body dips, then springs back
		local landAge = now - (rig.landAt or -10)
		if landAge < 0.24 then
			local k = 1 - landAge / 0.24
			k = k * k * math.clamp(rig.landHard or 0.5, 0.3, 1)
			p.root = CFrame.new(0, -0.8 * k, 0) * A(-0.28 * k, 0, 0) * p.root
			p.lLeg = A(0.85 * k, 0, 0) * p.lLeg
			p.rLeg = A(0.85 * k, 0, 0) * p.rLeg
			p.lArm = A(0, 0, -0.6 * k) * p.lArm
			p.rArm = A(0, 0, 0.6 * k) * p.rArm
			earTarget -= 0.9 * k
		end
	end
	if move ~= "roll" then
		rig.spin = 0
	end
	if move ~= "zip" then
		rig.zipSwing = 0
	end

	-- body follow-through: lean into speeding up / turning, sway back on stopping
	local lean = rig.lean
	if springy then
		local tx = math.clamp(localAccel.Z * 0.004, -0.35, 0.35) -- forward/back
		local tz = math.clamp(-localAccel.X * 0.004, -0.3, 0.3) -- side to side
		lean.vx += ((tx - lean.x) * 90 - lean.vx * 11) * dt
		lean.x += lean.vx * dt
		lean.vz += ((tz - lean.z) * 90 - lean.vz * 11) * dt
		lean.z += lean.vz * dt
		p.root = p.root * A(lean.x, 0, lean.z)
	else
		lean.x, lean.vx, lean.z, lean.vz = 0, 0, 0, 0
	end

	-- remember when we touch down (and how hard) for the squash above
	if grounded and not rig.wasGrounded then
		rig.landAt = now
		rig.landHard = math.clamp(-(rig.lastVy or 0) / 90, 0, 1)
	end
	rig.wasGrounded = grounded
	rig.lastVy = vy

	return p, extra, earTarget
end

local function apply(rig, char, dt, now, isLocal)
	local pose, extra, earTarget = poseFor(rig, char, dt, now, isLocal)
	local alpha = 1 - math.exp(-dt * 16)
	for key, target in pairs(pose) do
		rig.cur[key] = rig.cur[key]:Lerp(target, alpha)
	end
	rig.motors.root.Transform = rig.cur.root * extra
	rig.motors.neck.Transform = rig.cur.neck
	rig.motors.lArm.Transform = rig.cur.lArm
	rig.motors.rArm.Transform = rig.cur.rArm
	rig.motors.lLeg.Transform = rig.cur.lLeg
	rig.motors.rLeg.Transform = rig.cur.rLeg

	-- floppy ears on springs
	if now > rig.twitchAt then
		rig.twitchAt = now + 2 + math.random() * 4
		rig.twitch = math.random() < 0.5 and 1 or -1
	end
	for side, ear in pairs(rig.ears) do
		local target = earTarget
		if (side == "r" and rig.twitch > 0.3) or (side == "l" and rig.twitch < -0.3) then
			target -= 0.35
		end
		ear.v += (target - ear.a) * 110 * dt - ear.v * 9 * dt
		ear.a += ear.v * dt
	end
	rig.twitch *= math.exp(-dt * 6)
	local sway = math.sin(now * 2.3) * 0.05
	rig.motors.lEar.Transform = A(rig.ears.l.a, 0, -math.max(0, rig.ears.l.a) * 0.25 + sway)
	rig.motors.rEar.Transform = A(rig.ears.r.a * 0.92, 0, math.max(0, rig.ears.r.a) * 0.25 - sway)
end

local warned = {}
local function update(dt)
	dt = math.clamp(dt or 1 / 60, 1 / 240, 0.1)
	local now = os.clock()
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char and char.Parent and char:GetAttribute("Bunny") then
			local rig = rigs[char]
			if rig == nil or (rig.retryAt and now > rig.retryAt) then
				rig = findRig(char) or { retryAt = now + 0.5 }
				rigs[char] = rig
			end
			if rig.motors and rig.root.Parent then
				local ok, err = pcall(apply, rig, char, dt, now, plr == player)
				if not ok and not warned[tostring(err)] then
					warned[tostring(err)] = true
					warn("[Bunny64] Animator: " .. tostring(err))
				end
			end
		end
	end
	-- forget characters that are gone
	for char in pairs(rigs) do
		if not char.Parent then
			rigs[char] = nil
		end
	end
end

function Animator.Init(movement)
	Movement = movement
	local worldFolder = workspace:WaitForChild("Bunny64World")
	rayParams.FilterDescendantsInstances = { worldFolder:WaitForChild("Solid"), workspace.Terrain }
	-- Motor6D.Transform is written just before physics each frame
	local ok, preSim = pcall(function()
		return RunService.PreSimulation
	end)
	if ok and preSim then
		preSim:Connect(function(dt)
			update(dt)
		end)
	else
		RunService.Stepped:Connect(function(_, dt)
			update(dt)
		end)
	end
end

return Animator
