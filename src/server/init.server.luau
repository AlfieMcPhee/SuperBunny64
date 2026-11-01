--[[
	Bunny 64 - server entry point.
	Builds the world, loads/saves progress, validates pickups, runs enemies.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local DataService = require(script:WaitForChild("DataService"))
local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
local EnemyService = require(script:WaitForChild("EnemyService"))
local BunnyCharacter = require(script:WaitForChild("BunnyCharacter"))

Players.CharacterAutoLoads = false

-- Remotes ---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(className, name)
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local GetProfile = remote("RemoteFunction", "GetProfile")
local Collect = remote("RemoteEvent", "Collect")
local Update = remote("RemoteEvent", "Update")
local Pound = remote("RemoteEvent", "Pound")
local Bounce = remote("RemoteEvent", "Bounce")
local Effect = remote("RemoteEvent", "Effect")
remotes.Parent = Shared

-- World -----------------------------------------------------------------------
local info = WorldBuilder.Build()

local goldenSet = {}
for _, g in ipairs(Config.Goldens) do
	goldenSet[g.id] = g
end
local TOTAL_CARROTS = 0
for _ in pairs(info.carrots) do
	TOTAL_CARROTS += 1
end
Shared:SetAttribute("TotalCarrots", TOTAL_CARROTS)

-- Helpers -----------------------------------------------------------------------
local function countKeys(t)
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

local function snapshot(player, event)
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	local d = profile.data
	return {
		carrots = d.carrots,
		goldens = d.goldens,
		carrotCount = d.carrotCount,
		goldenCount = countKeys(d.goldens),
		bugs = d.bugs,
		playTime = DataService.GetPlayTime(player),
		completedTime = d.completedTime,
		canSave = profile.canSave,
		totalCarrots = TOTAL_CARROTS,
		event = event,
	}
end

local function push(player, event)
	local snap = snapshot(player, event)
	if snap then
		Update:FireClient(player, snap)
	end
	local profile = DataService.Get(player)
	local stats = player:FindFirstChild("leaderstats")
	if stats and profile then
		stats.Carrots.Value = profile.data.carrotCount
		stats.Golden.Value = countKeys(profile.data.goldens)
	end
end

local function getRoot(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid")
end

-- Per-player runtime state
local state = {} -- [Player] = { safe = CFrame, invulnUntil = number }

local function heal(player, amount)
	local _, hum = getRoot(player)
	if hum and hum.Health > 0 then
		hum.Health = math.min(hum.MaxHealth, hum.Health + amount)
	end
end

local function hurt(player, fromPos, amount, ignoreInvuln)
	local root, hum = getRoot(player)
	local st = state[player]
	if not (root and hum and st) or hum.Health <= 0 then
		return
	end
	if not ignoreInvuln and os.clock() < st.invulnUntil then
		return
	end
	st.invulnUntil = os.clock() + 1.5
	hum:TakeDamage(amount or 1)
	local away = Vector3.new(root.Position.X - fromPos.X, 0, root.Position.Z - fromPos.Z)
	if away.Magnitude < 0.1 then
		away = Vector3.new(0, 0, 1)
	end
	Bounce:FireClient(player, away.Unit * 45 + Vector3.new(0, 40, 0), false, "hurt")
end

-- Progress events -----------------------------------------------------------------
local function checkCompletion(player, profile)
	local d = profile.data
	if not d.completedTime and countKeys(d.goldens) >= #Config.Goldens then
		d.completedTime = DataService.GetPlayTime(player)
		return true
	end
	return false
end

local function onBopped(player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	profile.data.bugs += 1
	local event = { kind = "bop" }
	if profile.data.bugs == Config.BugBusterGoal then
		event = { kind = "unlock", id = "buster" }
	end
	push(player, event)
end

Collect.OnServerEvent:Connect(function(player, id)
	if type(id) ~= "string" then
		return
	end
	local profile = DataService.Get(player)
	local root = getRoot(player)
	if not profile or not root then
		return
	end
	local d = profile.data

	local carrotPos = info.carrots[id]
	if carrotPos then
		if d.carrots[id] or (root.Position - carrotPos).Magnitude > 18 then
			return
		end
		d.carrots[id] = true
		d.carrotCount += 1
		local event = { kind = "carrot", id = id }
		if d.carrotCount % Config.HealEveryCarrots == 0 then
			heal(player, 1)
			event.heal = true
		end
		if d.carrotCount == Config.CollectorGoal then
			event = { kind = "unlock", id = "collector", heal = event.heal }
		end
		push(player, event)
		return
	end

	local goldPos = info.goldens[id]
	if goldPos and goldenSet[id] then
		if d.goldens[id] or (root.Position - goldPos).Magnitude > 20 then
			return
		end
		if id == "collector" and d.carrotCount < Config.CollectorGoal then
			return
		end
		if id == "buster" and d.bugs < Config.BugBusterGoal then
			return
		end
		d.goldens[id] = true
		heal(player, Config.MaxHearts)
		local done = checkCompletion(player, profile)
		push(player, { kind = done and "complete" or "golden", id = id })
		task.spawn(DataService.Save, player, false) -- goldens are precious: save right away
	end
end)

GetProfile.OnServerInvoke = function(player)
	DataService.WaitFor(player, 30)
	return snapshot(player, nil)
end

Pound.OnServerEvent:Connect(function(player, action, pos)
	local root = getRoot(player)
	if not root then
		return
	end
	if action == "start" then
		EnemyService.MarkPounding(player, 2)
	elseif action == "land" and typeof(pos) == "Vector3" and (pos - root.Position).Magnitude < 15 then
		EnemyService.MarkPounding(player, 0.15)
		EnemyService.Shockwave(player, pos)
		Effect:FireAllClients("pound", pos)
	end
end)

-- Enemies ---------------------------------------------------------------------------
EnemyService.Start(info, {
	effect = function(kind, pos)
		Effect:FireAllClients(kind, pos)
	end,
	bopped = onBopped,
	bounce = function(player, vel, keepHorizontal)
		Bounce:FireClient(player, vel, keepHorizontal, "stomp")
	end,
	hurt = function(player, fromPos)
		hurt(player, fromPos, 1, false)
	end,
})

-- Characters ---------------------------------------------------------------------------
local function spawnCharacter(player)
	if player.Parent then
		player:LoadCharacter()
	end
end

local function onCharacter(player, character)
	local st = state[player]
	if st then
		st.invulnUntil = os.clock() + 2
		st.safe = info.spawn
	end
	BunnyCharacter.Apply(character)
	local humanoid = character:WaitForChild("Humanoid")
	local regen = character:WaitForChild("Health", 3)
	if regen then
		regen:Destroy() -- hearts only come back from carrots
	end
	humanoid.MaxHealth = Config.MaxHearts
	humanoid.Health = Config.MaxHearts
	humanoid.WalkSpeed = Config.WalkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.JumpPower
	humanoid.Died:Connect(function()
		task.wait(3)
		if player.Character == character then
			spawnCharacter(player)
		end
	end)
end

local function onPlayerAdded(player)
	state[player] = { safe = info.spawn, invulnUntil = 0 }

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local carrots = Instance.new("IntValue")
	carrots.Name = "Carrots"
	carrots.Parent = stats
	local golden = Instance.new("IntValue")
	golden.Name = "Golden"
	golden.Parent = stats
	stats.Parent = player

	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)

	local profile = DataService.Load(player)
	if not profile or not player.Parent then
		return
	end
	push(player, nil)
	spawnCharacter(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	state[player] = nil
	DataService.Release(player)
end)

-- Water & safe-spot tracking ----------------------------------------------------------
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include
floorParams.FilterDescendantsInstances = { info.solidFolder }

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.2 then
		return
	end
	acc = 0
	for player, st in pairs(state) do
		local root, hum = getRoot(player)
		if root and hum and hum.Health > 0 then
			local pos = root.Position
			if pos.Y < Config.WaterLevel - 2.5 then
				Effect:FireAllClients("splash", Vector3.new(pos.X, Config.WaterLevel, pos.Z))
				hurt(player, pos, 1, true)
				if hum.Health > 0 then
					player.Character:PivotTo(st.safe)
					Bounce:FireClient(player, Vector3.zero, false, "reset")
				end
			elseif hum.FloorMaterial ~= Enum.Material.Air then
				local hit = workspace:Raycast(pos, Vector3.new(0, -8, 0), floorParams)
				if hit and not hit.Instance:GetAttribute("Moving") and hit.Instance.Anchored and hit.Instance:GetAttribute("Bounce") == nil then
					st.safe = CFrame.new(hit.Position + Vector3.new(0, 4, 0)) * (root.CFrame - root.CFrame.Position)
				end
			end
		end
	end
end)

print(string.format("[Bunny64] Ready: %d carrots, %d golden carrots.", TOTAL_CARROTS, #Config.Goldens))
