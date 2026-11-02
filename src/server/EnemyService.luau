--[[
	EnemyService - Grumblebugs wander their patch and charge at bunnies who
	get too close. Stomp them, ground pound near them, or roll/slide into them.
	They come back after a while.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local BugModel = require(script.Parent:WaitForChild("BugModel"))

local EnemyService = {}

local bugs = {}
local folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local callbacks
local poundingUntil = {} -- [Player] = os.clock()

local ATTACK_MOVES = { roll = true, slide = true, longjump = true }

local function groundAt(pos)
	local hit = workspace:Raycast(pos + Vector3.new(0, 8, 0), Vector3.new(0, -30, 0), rayParams)
	if hit then
		return hit.Position.Y, hit.Instance
	end
	return nil
end

local function placeModel(bug, extraY, roll)
	bug.model:PivotTo(CFrame.new(bug.pos + Vector3.new(0, 1.8 + extraY, 0)) * CFrame.Angles(0, bug.yaw, roll or 0))
end

local function defeat(bug, player)
	bug.alive = false
	bug.respawnAt = os.clock() + Config.BugRespawnSeconds
	callbacks.effect("poof", bug.pos + Vector3.new(0, 2, 0))
	task.spawn(function()
		-- flip over and squash
		for i = 1, 8 do
			if not bug.model.Parent then
				break
			end
			bug.model:PivotTo(CFrame.new(bug.pos + Vector3.new(0, 1.8 + math.sin(i / 8 * math.pi) * 2, 0)) * CFrame.Angles(0, bug.yaw, i / 8 * math.pi))
			task.wait(0.03)
		end
		bug.model.Parent = nil
	end)
	if player then
		callbacks.bopped(player)
	end
end

function EnemyService.Start(info, cb)
	callbacks = cb
	folder = Instance.new("Folder")
	folder.Name = "Grumblebugs"
	folder.Parent = workspace
	rayParams.FilterDescendantsInstances = { info.solidFolder }

	for _, def in ipairs(info.bugs) do
		local home = def.pos
		local y = groundAt(home + Vector3.new(0, 10, 0)) or home.Y
		local pos = Vector3.new(home.X, y, home.Z)
		local model = BugModel.Build(def.skin, 1, CFrame.new(pos))
		model.Parent = folder
		table.insert(bugs, {
			model = model,
			home = pos,
			pos = pos,
			yaw = math.random() * math.pi * 2,
			turnAt = 0,
			alive = true,
			respawnAt = 0,
			phase = math.random() * 6,
			fast = def.skin == "castle",
		})
	end

	RunService.Heartbeat:Connect(function(dt)
		EnemyService.Step(dt)
	end)
end

function EnemyService.MarkPounding(player, seconds)
	poundingUntil[player] = os.clock() + seconds
end

function EnemyService.Shockwave(player, pos)
	for _, bug in ipairs(bugs) do
		if bug.alive then
			local d = Vector3.new(bug.pos.X - pos.X, 0, bug.pos.Z - pos.Z).Magnitude
			if d < 14 and math.abs(bug.pos.Y - pos.Y) < 8 then
				defeat(bug, player)
			end
		end
	end
end

local function nearestPlayer(pos)
	local best, bestDist, bestHrp = nil, 45, nil
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local d = (hrp.Position - pos).Magnitude
			if d < bestDist and math.abs(hrp.Position.Y - 2.6 - pos.Y) < 10 then
				best, bestDist, bestHrp = player, d, hrp
			end
		end
	end
	return best, bestHrp
end

function EnemyService.Step(dt)
	local now = os.clock()
	for _, bug in ipairs(bugs) do
		if not bug.alive then
			if now >= bug.respawnAt then
				bug.alive = true
				bug.pos = bug.home
				bug.model.Parent = folder
				placeModel(bug, 0)
				callbacks.effect("poof", bug.pos + Vector3.new(0, 2, 0))
			end
			continue
		end

		local target, hrp = nearestPlayer(bug.pos)
		local fromHome = Vector3.new(bug.pos.X - bug.home.X, 0, bug.pos.Z - bug.home.Z).Magnitude
		local speed = bug.fast and 9 or 7
		if target and fromHome < 60 then
			local d = hrp.Position - bug.pos
			bug.yaw = math.atan2(-d.X, -d.Z)
			speed = bug.fast and 19 or 15
		else
			if fromHome > 22 then
				local d = bug.home - bug.pos
				bug.yaw = math.atan2(-d.X, -d.Z)
			elseif now > bug.turnAt then
				bug.yaw += (math.random() - 0.5) * 2.5
				bug.turnAt = now + 1 + math.random() * 2
			end
		end

		local look = Vector3.new(-math.sin(bug.yaw), 0, -math.cos(bug.yaw))
		local nextPos = bug.pos + look * speed * dt
		local gy, hitPart = groundAt(nextPos)
		local ok = gy and gy > Config.WaterLevel + 1 and math.abs(gy - bug.pos.Y) < 3
		if ok and hitPart and (hitPart:GetAttribute("Moving") or hitPart:GetAttribute("Lava") or hitPart:GetAttribute("Water") or hitPart:GetAttribute("Slide")) then
			ok = false
		end
		if ok then
			bug.pos = Vector3.new(nextPos.X, gy, nextPos.Z)
		else
			bug.yaw += math.pi * (0.5 + math.random() * 0.5)
		end
		local step = now * (speed > 10 and 18 or 10) + bug.phase
		placeModel(bug, math.abs(math.sin(step)) * 0.25, math.sin(step) * 0.06)

		-- Contact with bunnies
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 then
				local feet = root.Position.Y - 2.6
				local flat = Vector3.new(root.Position.X - bug.pos.X, 0, root.Position.Z - bug.pos.Z).Magnitude
				if flat < 4.4 and feet < bug.pos.Y + 4 and feet > bug.pos.Y - 2.5 then
					local vy = root.AssemblyLinearVelocity.Y
					local pounding = (poundingUntil[player] or 0) > now
					local move = char:GetAttribute("Move")
					if (vy < -1 and feet > bug.pos.Y + 1.6) or pounding then
						defeat(bug, player)
						callbacks.bounce(player, Vector3.new(0, Config.StompBounce, 0), true)
						break
					elseif move and ATTACK_MOVES[move] then
						defeat(bug, player)
						break
					else
						callbacks.hurt(player, bug.pos)
					end
				end
			end
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	poundingUntil[player] = nil
end)

return EnemyService
