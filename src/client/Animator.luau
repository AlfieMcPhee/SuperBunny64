--[[
	Animator - procedural animation for every bunny in the server.

	No animation assets: each frame we compute a pose from the bunny's
	velocity and current move, blend toward it, and write Motor6D.Transform.
	Ears hang on little springs so they flop when you land or run.
	Other players' moves come from the "Move" attribute the server sets.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local Animator = {}

local player = Players.LocalPlayer
local Movement
local rigs = {} -- [Model] = rig data
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
	local cur = {}
	for key in pairs(JOINTS) do
		cur[key] = I
	end
	return {
		motors = motors,
		cur = cur,
		phase = math.random() * 6,
		ears = { l = { a = 0, v = 0 }, r = { a = 0, v = 0 } },
		twitchAt = os.clock() + 3,
		twitch = 0,
		root = char:FindFirstChild("HumanoidRootPart"),
		hum = char:FindFirstChildOfClass("Humanoid"),
	}
end

local function poseFor(rig, char, dt, now, isLocal)
	local root, hum = rig.root, rig.hum
	local v = root.AssemblyLinearVelocity
	local hv = Vector3.new(v.X, 0, v.Z).Magnitude
	local vy = v.Y
	local t = now

	-- what is this bunny doing?
	local move, moveAge, flipAge, grounded
	if isLocal then
		local s = Movement.State()
		move = s.move
		moveAge = now - s.moveStart
		flipAge = now - s.flipAt
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
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -3.6, 0), rayParams)
		grounded = hit ~= nil
	end

	local p = {
		root = I, neck = I, lArm = A(0, 0, -0.12), rArm = A(0, 0, 0.12),
		lLeg = I, rLeg = I,
	}
	local extra = I
	local earTarget = math.clamp(-vy * 0.018 + hv * 0.022, -0.5, 1.3)

	if hum.Health <= 0 then
		p.root = CFrame.new(0, -1.7, 0.4) * A(1.45, 0, 0)
		p.lArm, p.rArm = A(0, 0, -1.6), A(0, 0, 1.6)
		p.lLeg, p.rLeg = A(0.3, 0, -0.2), A(0.3, 0, 0.2)
		earTarget = -0.4
	elseif move == "roll" then
		local spin = moveAge * 17
		extra = CFrame.new(0, -0.7, 0) * A(-spin, 0, 0)
		p.lLeg, p.rLeg = A(1.5, 0, 0), A(1.5, 0, 0)
		p.lArm, p.rArm = A(1.3, 0, 0.35), A(1.3, 0, -0.35)
		p.neck = A(-0.55, 0, 0)
		earTarget = 0.4
	elseif move == "longjump" then
		p.root = A(-1.15, 0, 0)
		p.lArm, p.rArm = A(2.7, 0, 0.25), A(2.7, 0, -0.25)
		p.lLeg, p.rLeg = A(-0.45, 0, -0.08), A(-0.2, 0, 0.08)
		p.neck = A(0.75, 0, 0)
		earTarget = 1.25
	elseif move == "slide" then
		p.root = CFrame.new(0, -1.05, 0) * A(-1.38, 0, math.sin(t * 9) * 0.04)
		p.lArm, p.rArm = A(2.85, 0, 0.3), A(2.85, 0, -0.3)
		p.lLeg, p.rLeg = A(-0.12, 0, -0.12), A(-0.12, 0, 0.12)
		p.neck = A(0.95, 0, 0)
		earTarget = 1.3
	elseif move == "pound" then
		local hang = Config.PoundHang
		if moveAge < hang then
			extra = A(0, moveAge / hang * TAU, 0)
		end
		p.lLeg, p.rLeg = A(1.3, 0, -0.15), A(1.3, 0, 0.15)
		p.lArm, p.rArm = A(0, 0, -2.6), A(0, 0, 2.6)
		p.root = A(0.15, 0, 0)
		earTarget = -0.6
	elseif not grounded then
		local rising = vy > 0
		p.lLeg = A(rising and 0.8 or 0.35, 0, 0)
		p.rLeg = A(rising and -0.25 or 0.15, 0, 0)
		p.lArm = A(0, 0, rising and -2.3 or -1.3)
		p.rArm = A(0, 0, rising and 2.3 or 1.3)
		p.root = A(-0.08, 0, 0)
		if flipAge < 0.45 then
			local u = flipAge / 0.45
			extra = A(-TAU * (1 - (1 - u) * (1 - u)), 0, 0)
			p.lLeg, p.rLeg = A(1.4, 0, 0), A(1.4, 0, 0)
			p.lArm, p.rArm = A(1.2, 0, 0.3), A(1.2, 0, -0.3)
		end
	else
		local f = math.clamp(hv / 24, 0, 1)
		rig.phase += dt * (5 + hv * 0.55)
		local s = math.sin(rig.phase)
		p.lLeg = A(s * 0.95 * f, 0, 0)
		p.rLeg = A(-s * 0.95 * f, 0, 0)
		p.lArm = A(-s * 0.75 * f, 0, -0.15 - 0.1 * f)
		p.rArm = A(s * 0.75 * f, 0, 0.15 + 0.1 * f)
		local idle = 1 - f
		p.root = CFrame.new(0, math.abs(math.cos(rig.phase)) * 0.28 * f + math.sin(t * 2.2) * 0.05 * idle, 0)
			* A(-0.14 * f, 0, s * 0.05 * f)
		p.neck = A(0.08 * f + math.sin(t * 1.7) * 0.04 * idle, math.sin(t * 0.6) * 0.15 * idle, math.sin(t * 0.9) * 0.05 * idle)
		-- idle breathing in the arms
		p.lArm = p.lArm * A(0, 0, -math.sin(t * 2.2) * 0.04 * idle)
		p.rArm = p.rArm * A(0, 0, math.sin(t * 2.2) * 0.04 * idle)
	end

	return p, extra, earTarget
end

local function update(dt)
	local now = os.clock()
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char and char:GetAttribute("Bunny") and char.Parent then
			local rig = rigs[char]
			if rig == nil then
				rig = findRig(char) or false
				rigs[char] = rig
			end
			if rig and rig.root and rig.hum and rig.root.Parent then
				local isLocal = plr == player
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

				-- floppy ears
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
	rayParams.FilterDescendantsInstances = { worldFolder:WaitForChild("Solid") }
	RunService.Stepped:Connect(function(_, dt)
		update(dt)
	end)
end

return Animator
