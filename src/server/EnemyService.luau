--[[
	EnemyService - Grumblebugs: grumpy beetles that wander the meadow and
	charge at bunnies who get too close. Jump on them or ground pound near
	them to bop them. They come back after a while.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local P = Config.Palette

local EnemyService = {}

local bugs = {}
local folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local callbacks
local lastHurt = {} -- [Player] = os.clock()
local poundingUntil = {} -- [Player] = os.clock()

local function part(model, cf, size, color, isBall, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if isBall then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	end
	p.Parent = model
	return p
end

local function buildBug(pos)
	local model = Instance.new("Model")
	model.Name = "Grumblebug"
	local base = CFrame.new(pos)
	local root = part(model, base * CFrame.new(0, 1.6, 0), Vector3.new(4, 3, 5), P.BugShell)
	root.Transparency = 1
	root.Name = "Root"
	model.PrimaryPart = root
	-- body (front is -Z)
	part(model, base * CFrame.new(0, 1.9, 0.4), Vector3.new(5, 3.4, 6), P.BugShell, true)
	part(model, base * CFrame.new(0, 0.8, 0.4), Vector3.new(4.4, 1, 5.4), P.BugBelly, true)
	part(model, base * CFrame.new(0, 3.55, 0.4), Vector3.new(0.15, 0.2, 5.4), P.BugBelly) -- wing seam
	for _, s in ipairs({ { 1.1, 3.1, -0.4, 1.3 }, { -1.2, 3.0, 1.4, 1.1 }, { 0.9, 2.9, 2.2, 0.9 } }) do
		part(model, base * CFrame.new(s[1], s[2], s[3]), Vector3.new(s[4], 0.5, s[4]), P.BugSpot, true)
	end
	part(model, base * CFrame.new(0, 1.7, -2.9), Vector3.new(2.6, 2.3, 2.3), P.BugBelly, true)
	for _, sx in ipairs({ -1, 1 }) do
		part(model, base * CFrame.new(sx * 0.6, 2.2, -3.85), Vector3.new(0.85, 0.95, 0.4), P.Cream, true)
		part(model, base * CFrame.new(sx * 0.55, 2.1, -4.05), Vector3.new(0.35, 0.42, 0.15), P.Button, true)
		part(model, base * CFrame.new(sx * 0.6, 2.8, -3.95) * CFrame.Angles(0, 0, sx * 0.45), Vector3.new(0.9, 0.22, 0.2), P.Button)
		part(model, base * CFrame.new(sx * 0.5, 3.4, -3.3) * CFrame.Angles(-0.5, 0, sx * -0.3), Vector3.new(0.15, 1.6, 0.15), P.BugBelly)
		for i = -1, 1 do
			part(model, base * CFrame.new(sx * 2.5, 0.5, i * 1.6) * CFrame.Angles(0, 0, sx * 0.5), Vector3.new(1.8, 0.35, 0.35), P.BugBelly)
		end
	end
	model.Parent = folder
	return model
end

local function groundAt(pos)
	local hit = workspace:Raycast(pos + Vector3.new(0, 8, 0), Vector3.new(0, -30, 0), rayParams)
	if hit then
		return hit.Position.Y, hit.Instance
	end
	return nil
end

local function defeat(bug, player)
	bug.alive = false
	bug.respawnAt = os.clock() + Config.BugRespawnSeconds
	callbacks.effect("poof", bug.pos + Vector3.new(0, 2, 0))
	-- quick squash, then vanish
	task.spawn(function()
		for i = 1, 6 do
			if not bug.model.Parent then
				break
			end
			bug.model:PivotTo(CFrame.new(bug.pos + Vector3.new(0, 1.6 - i * 0.3, 0)) * CFrame.Angles(0, bug.yaw, 0))
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

	for _, home in ipairs(info.bugs) do
		local y = groundAt(home + Vector3.new(0, 10, 0)) or home.Y
		local pos = Vector3.new(home.X, y, home.Z)
		local bug = {
			home = pos,
			pos = pos,
			yaw = math.random() * math.pi * 2,
			turnAt = 0,
			alive = true,
			respawnAt = 0,
			phase = math.random() * 6,
		}
		bug.model = buildBug(pos)
		table.insert(bugs, bug)
	end

	RunService.Heartbeat:Connect(function(dt)
		EnemyService.Step(dt)
	end)
end

function EnemyService.MarkPounding(player, seconds)
	poundingUntil[player] = os.clock() + seconds
end

-- Ground pound shockwave from a player landing at `pos`
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
			if d < bestDist and math.abs(hrp.Position.Y - 3 - pos.Y) < 10 then
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
				callbacks.effect("poof", bug.pos + Vector3.new(0, 2, 0))
			end
			continue
		end

		local target, hrp = nearestPlayer(bug.pos)
		local fromHome = Vector3.new(bug.pos.X - bug.home.X, 0, bug.pos.Z - bug.home.Z).Magnitude
		local speed = 7
		if target and fromHome < 60 then
			local d = hrp.Position - bug.pos
			bug.yaw = math.atan2(-d.X, -d.Z)
			speed = 15
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
		if gy and gy > Config.WaterLevel + 1 and math.abs(gy - bug.pos.Y) < 3 and not (hitPart and hitPart:GetAttribute("Moving")) then
			bug.pos = Vector3.new(nextPos.X, gy, nextPos.Z)
		else
			bug.yaw += math.pi * (0.5 + math.random() * 0.5)
		end
		local bob = math.abs(math.sin(now * (speed > 10 and 16 or 9) + bug.phase)) * 0.3
		bug.model:PivotTo(CFrame.new(bug.pos + Vector3.new(0, 1.6 + bob, 0)) * CFrame.Angles(0, bug.yaw, 0))

		-- Contact with bunnies
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 then
				local feet = root.Position.Y - 3
				local flat = Vector3.new(root.Position.X - bug.pos.X, 0, root.Position.Z - bug.pos.Z).Magnitude
				if flat < 4.6 and feet < bug.pos.Y + 4.2 and feet > bug.pos.Y - 2.5 then
					local vy = root.AssemblyLinearVelocity.Y
					local pounding = (poundingUntil[player] or 0) > now
					if (vy < -1 and feet > bug.pos.Y + 1.4) or pounding then
						defeat(bug, player)
						callbacks.bounce(player, Vector3.new(0, Config.StompBounce, 0), true)
						break
					elseif now - (lastHurt[player] or 0) > 1.5 then
						lastHurt[player] = now
						callbacks.hurt(player, bug.pos)
					end
				end
			end
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	lastHurt[player] = nil
	poundingUntil[player] = nil
end)

function EnemyService.GiveInvulnerability(player, seconds)
	lastHurt[player] = os.clock() + seconds - 1.5
end

return EnemyService
