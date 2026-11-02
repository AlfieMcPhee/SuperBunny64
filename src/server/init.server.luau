--[[
	Bunny 64 - server entry point.
	Builds the world, runs save files, pickups, hearts, hazards, checkpoints,
	warps, enemies, the boss and customisation.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage:WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local BunnyModel = require(Shared:WaitForChild("BunnyModel"))

local DataService = require(script:WaitForChild("DataService"))
local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
local EnemyService = require(script:WaitForChild("EnemyService"))
local HazardService = require(script:WaitForChild("HazardService"))
local BossService = require(script:WaitForChild("BossService"))

Players.CharacterAutoLoads = false

-- The plush bunny is everyone's character
do
	local old = StarterPlayer:FindFirstChild("StarterCharacter")
	if old then
		old:Destroy()
	end
	BunnyModel.BuildCharacter().Parent = StarterPlayer
end

-- Remotes -------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(className, name)
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local GetProfile = remote("RemoteFunction", "GetProfile")
local SelectSlot = remote("RemoteFunction", "SelectSlot")
local EraseSlot = remote("RemoteFunction", "EraseSlot")
local Customise = remote("RemoteFunction", "Customise")
local QuitToTitle = remote("RemoteEvent", "QuitToTitle")
local SetOptions = remote("RemoteEvent", "SetOptions")
local Collect = remote("RemoteEvent", "Collect")
local Update = remote("RemoteEvent", "Update")
local Pound = remote("RemoteEvent", "Pound")
local Bounce = remote("RemoteEvent", "Bounce")
local Effect = remote("RemoteEvent", "Effect")
local SetMove = remote("RemoteEvent", "SetMove")
local WarpMenu = remote("RemoteEvent", "WarpMenu")
local Warp = remote("RemoteEvent", "Warp")
remotes.Parent = Shared

-- World -------------------------------------------------------------------------------
local info = WorldBuilder.Build()

local goldenDefs = {}
for _, g in ipairs(Config.Goldens) do
	goldenDefs[g.id] = g
end
local TOTAL_CARROTS = 0
for _ in pairs(info.carrots) do
	TOTAL_CARROTS += 1
end
Shared:SetAttribute("TotalCarrots", TOTAL_CARROTS)

local count = DataService.Count
local state = {} -- [Player] = { safe = CFrame, invulnUntil = number }

local function getRoot(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid")
end

-- Snapshots -------------------------------------------------------------------------------
local function snapshot(player, event)
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	local snap = {
		menu = {
			slots = DataService.Summaries(player),
			custom = profile.data.custom,
			options = profile.data.options,
			progress = DataService.Progress(player),
		},
		active = profile.active and tonumber(profile.active) or nil,
		canSave = profile.canSave,
		totalCarrots = TOTAL_CARROTS,
		event = event,
	}
	local slot = DataService.ActiveSlot(player)
	if slot then
		snap.slot = {
			carrots = slot.carrots,
			goldens = slot.goldens,
			carrotCount = slot.carrotCount,
			goldenCount = count(slot.goldens),
			bugs = slot.bugs,
			playTime = DataService.GetPlayTime(player),
			completedTime = slot.completedTime,
			checkpoint = slot.checkpoint,
			warps = slot.warps,
			bossDefeated = slot.bossDefeated,
		}
	end
	return snap
end

local function push(player, event)
	local snap = snapshot(player, event)
	if snap then
		Update:FireClient(player, snap)
	end
	local slot = DataService.ActiveSlot(player)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Carrots.Value = slot and slot.carrotCount or 0
		stats.Golden.Value = slot and count(slot.goldens) or 0
	end
end

-- Hearts --------------------------------------------------------------------------------------
local function heal(player, amount)
	local _, hum = getRoot(player)
	if hum and hum.Health > 0 then
		hum.Health = math.min(hum.MaxHealth, hum.Health + amount)
	end
end

local function hurt(player, fromPos, velocity, ignoreInvuln)
	local root, hum = getRoot(player)
	local st = state[player]
	if not (root and hum and st) or hum.Health <= 0 then
		return false
	end
	if not ignoreInvuln and os.clock() < st.invulnUntil then
		return false
	end
	st.invulnUntil = os.clock() + 1.5
	hum:TakeDamage(1)
	if not velocity then
		local away = Vector3.new(root.Position.X - fromPos.X, 0, root.Position.Z - fromPos.Z)
		if away.Magnitude < 0.1 then
			away = Vector3.new(0, 0, 1)
		end
		velocity = away.Unit * 45 + Vector3.new(0, 40, 0)
	end
	Bounce:FireClient(player, velocity, false, "hurt")
	return true
end

local function burn(player)
	local root, hum = getRoot(player)
	local st = state[player]
	if not (root and hum and st) or hum.Health <= 0 then
		return
	end
	if os.clock() >= st.invulnUntil then
		st.invulnUntil = os.clock() + 1.5
		hum:TakeDamage(1)
	end
	Bounce:FireClient(player, Vector3.new(0, 88, 0), true, "burn")
	Effect:FireAllClients("burn", root.Position - Vector3.new(0, 2.5, 0))
end

-- Characters --------------------------------------------------------------------------------
local function checkpointCF(id)
	local cp = Config.Checkpoints[id] or Config.Checkpoints.meadow
	return CFrame.new(cp.pos)
end

local function spawnCharacter(player)
	if player.Parent and DataService.ActiveSlot(player) then
		player:LoadCharacter()
	end
end

local function onCharacter(player, character)
	local st = state[player]
	local slot, profile = DataService.ActiveSlot(player)
	local humanoid = character:WaitForChild("Humanoid")
	local root = character:WaitForChild("HumanoidRootPart")
	if slot then
		local cf = checkpointCF(slot.checkpoint)
		character:PivotTo(cf)
		root.AssemblyLinearVelocity = Vector3.zero
		if st then
			st.safe = cf
			st.invulnUntil = os.clock() + 2
		end
	end
	if profile then
		BunnyModel.Apply(character, profile.data.custom)
	end
	local regen = character:FindFirstChild("Health")
	if regen and regen:IsA("Script") then
		regen:Destroy()
	end
	humanoid.MaxHealth = Config.MaxHearts
	humanoid.Health = Config.MaxHearts
	humanoid.WalkSpeed = Config.WalkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.JumpPower
	character:SetAttribute("Move", "")
	humanoid.Died:Connect(function()
		task.wait(3)
		if player.Character == character then
			spawnCharacter(player)
		end
	end)
end

-- Progress ------------------------------------------------------------------------------------
local function checkCompletion(player, slot)
	if not slot.completedTime and count(slot.goldens) >= #Config.Goldens then
		slot.completedTime = DataService.GetPlayTime(player)
		return true
	end
	return false
end

local function onBopped(player)
	local slot = DataService.ActiveSlot(player)
	if not slot then
		return
	end
	slot.bugs += 1
	local event = { kind = "bop" }
	if slot.bugs == Config.BugBusterGoal then
		event = { kind = "unlock", id = "buster" }
	end
	push(player, event)
end

Collect.OnServerEvent:Connect(function(player, id)
	if type(id) ~= "string" then
		return
	end
	local slot = DataService.ActiveSlot(player)
	local root = getRoot(player)
	if not slot or not root then
		return
	end

	local carrotPos = info.carrots[id]
	if carrotPos then
		if slot.carrots[id] or (root.Position - carrotPos).Magnitude > 18 then
			return
		end
		slot.carrots[id] = true
		slot.carrotCount += 1
		local event = { kind = "carrot", id = id }
		if slot.carrotCount % Config.HealEveryCarrots == 0 then
			heal(player, 1)
			event.heal = true
		end
		if slot.carrotCount == Config.CollectorGoal then
			event = { kind = "unlock", id = "collector", heal = event.heal }
		end
		push(player, event)
		return
	end

	local goldPos = info.goldens[id]
	local def = goldenDefs[id]
	if goldPos and def then
		if slot.goldens[id] or (root.Position - goldPos).Magnitude > 20 then
			return
		end
		if def.req == "carrots" and slot.carrotCount < Config.CollectorGoal then
			return
		elseif def.req == "bugs" and slot.bugs < Config.BugBusterGoal then
			return
		elseif def.req == "boss" and not slot.bossDefeated then
			return
		end
		local before = DataService.Progress(player)
		slot.goldens[id] = true
		heal(player, Config.MaxHearts)
		local done = checkCompletion(player, slot)
		local after = DataService.Progress(player)
		local event = { kind = done and "complete" or "golden", id = id }
		-- tell the player about newly unlocked hats
		for _, list in ipairs({ Config.Hats, Config.Necks }) do
			for _, item in ipairs(list) do
				if not item.boss and (item.need or 0) > before.goldens and (item.need or 0) <= after.goldens then
					event.unlocked = item.name
				end
			end
		end
		push(player, event)
		task.spawn(DataService.Save, player, false)
	end
end)

GetProfile.OnServerInvoke = function(player)
	DataService.WaitFor(player, 30)
	return snapshot(player, nil)
end

SelectSlot.OnServerInvoke = function(player, index)
	local profile = DataService.WaitFor(player, 30)
	if not profile or profile.active then
		return false
	end
	local slot = DataService.SelectSlot(player, index)
	if not slot then
		return false
	end
	push(player, { kind = "start" })
	spawnCharacter(player)
	return true
end

EraseSlot.OnServerInvoke = function(player, index)
	local ok = DataService.EraseSlot(player, index)
	if ok then
		push(player, nil)
		task.spawn(DataService.Save, player, false)
	end
	return ok
end

QuitToTitle.OnServerEvent:Connect(function(player)
	if not DataService.ActiveSlot(player) then
		return
	end
	DataService.ClearActive(player)
	task.spawn(DataService.Save, player, false)
	local char = player.Character
	player.Character = nil
	if char then
		char:Destroy()
	end
	push(player, nil)
end)

Customise.OnServerInvoke = function(player, custom)
	local profile = DataService.Get(player)
	if not profile or type(custom) ~= "table" then
		return nil
	end
	local clean = BunnyModel.Sanitize(custom)
	local progress = DataService.Progress(player)
	if not BunnyModel.IsUnlocked(Config.Hats, clean.hat, progress) then
		clean.hat = profile.data.custom.hat
	end
	if not BunnyModel.IsUnlocked(Config.Necks, clean.neck, progress) then
		clean.neck = profile.data.custom.neck
	end
	profile.data.custom = clean
	if player.Character then
		BunnyModel.Apply(player.Character, clean)
	end
	push(player, nil)
	return clean
end

SetOptions.OnServerEvent:Connect(function(player, options)
	local profile = DataService.Get(player)
	if not profile or type(options) ~= "table" then
		return
	end
	local o = profile.data.options
	if type(options.sfx) == "number" then
		o.sfx = math.clamp(math.floor(options.sfx), 0, 10)
	end
	if type(options.music) == "number" then
		o.music = math.clamp(math.floor(options.music), 0, 10)
	end
	if type(options.shake) == "boolean" then
		o.shake = options.shake
	end
	if type(options.controls) == "table" then
		local function validKey(name)
			if type(name) ~= "string" or #name > 40 then
				return false
			end
			local ok, code = pcall(function()
				return Enum.KeyCode[name]
			end)
			return ok and code ~= nil and not Config.ReservedKeys[name]
		end
		local clean = {}
		for _, def in ipairs(Config.Controls) do
			local c = options.controls[def.id]
			if type(c) == "table" then
				clean[def.id] = {
					key = validKey(c.key) and c.key or def.key,
					pad = validKey(c.pad) and c.pad or def.pad,
				}
			end
		end
		o.controls = clean
	end
end)

local VALID_MOVES = { [""] = true, roll = true, slide = true, longjump = true, pound = true, flip = true }
SetMove.OnServerEvent:Connect(function(player, move)
	local char = player.Character
	if char and type(move) == "string" and VALID_MOVES[move] then
		char:SetAttribute("Move", move)
		char:SetAttribute("MoveAt", workspace:GetServerTimeNow())
	end
end)

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

-- Prompts: warps, exits, the throne room ------------------------------------------------------
local warpDefs = {}
for _, w in ipairs(Config.Warps) do
	warpDefs[w.id] = w
end

local function teleport(player, cf)
	local char = player.Character
	if char then
		char:PivotTo(cf)
		Bounce:FireClient(player, Vector3.zero, false, "reset")
		Effect:FireClient(player, "warp", cf.Position)
	end
end

for _, d in ipairs(info.solidFolder:GetDescendants()) do
	if d:IsA("ProximityPrompt") then
		local part = d.Parent
		d.Triggered:Connect(function(player)
			local slot = DataService.ActiveSlot(player)
			if not slot then
				return
			end
			if part:GetAttribute("Warp") then
				slot.warps[part:GetAttribute("Warp")] = true
				local list = {}
				for _, w in ipairs(Config.Warps) do
					if slot.warps[w.id] then
						table.insert(list, w.id)
					end
				end
				WarpMenu:FireClient(player, list)
			elseif part:GetAttribute("ExitTo") then
				teleport(player, checkpointCF(part:GetAttribute("ExitTo")))
			elseif part:GetAttribute("ThronePortal") then
				if count(slot.goldens) >= Config.ThroneGate then
					slot.checkpoint = "throne"
					teleport(player, checkpointCF("throne"))
					push(player, { kind = "checkpoint", id = "throne" })
				else
					Effect:FireClient(player, "locked", Config.ThroneGate)
				end
			end
		end)
	end
end

Warp.OnServerEvent:Connect(function(player, id)
	local slot = DataService.ActiveSlot(player)
	local def = type(id) == "string" and warpDefs[id]
	if slot and def and slot.warps[id] then
		teleport(player, CFrame.new(def.pos + Vector3.new(0, 5, -9)))
	end
end)

-- Hazards, enemies, boss ------------------------------------------------------------------------
HazardService.Start(info, {
	burn = burn,
	hurt = function(player, fromPos, velocity)
		hurt(player, fromPos, velocity, false)
	end,
})

EnemyService.Start(info, {
	effect = function(kind, pos)
		Effect:FireAllClients(kind, pos)
	end,
	bopped = onBopped,
	bounce = function(player, vel, keepHorizontal)
		Bounce:FireClient(player, vel, keepHorizontal, "stomp")
	end,
	hurt = function(player, fromPos)
		hurt(player, fromPos, nil, false)
	end,
})

BossService.Start(info, {
	effect = function(kind, pos, extra)
		Effect:FireAllClients(kind, pos, extra)
	end,
	hurt = function(player, fromPos)
		hurt(player, fromPos, nil, false)
	end,
	bounce = function(player, vel)
		Bounce:FireClient(player, vel, true, "stomp")
	end,
	defeated = function(winners)
		for _, player in ipairs(winners) do
			local slot = DataService.ActiveSlot(player)
			if slot then
				slot.bossDefeated = true
				push(player, { kind = "bossdown" })
				task.spawn(DataService.Save, player, false)
			end
		end
	end,
})

-- Players -----------------------------------------------------------------------------------------
local function onPlayerAdded(player)
	state[player] = { safe = checkpointCF("meadow"), invulnUntil = 0 }
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in ipairs({ "Golden", "Carrots" }) do
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = stats
	end
	stats.Parent = player
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	local profile = DataService.Load(player)
	if profile and player.Parent then
		push(player, nil)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerRemoving:Connect(function(player)
	state[player] = nil
	DataService.Release(player)
end)

-- Water, lava, checkpoints & warp discovery ------------------------------------------------------------
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include
floorParams.FilterDescendantsInstances = { info.solidFolder, workspace.Terrain }

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.2 then
		return
	end
	acc = 0
	for player, st in pairs(state) do
		local root, hum = getRoot(player)
		local slot = DataService.ActiveSlot(player)
		if root and hum and hum.Health > 0 and slot then
			local pos = root.Position
			local hit = workspace:Raycast(pos, Vector3.new(0, -3.4, 0), floorParams)
			local inWater = pos.Y < Config.WaterLevel - 2.5 or (hit and hit.Instance:GetAttribute("Water"))
			if inWater then
				Effect:FireAllClients("splash", Vector3.new(pos.X, hit and hit.Position.Y or Config.WaterLevel, pos.Z))
				hurt(player, pos, Vector3.zero, true)
				if hum.Health > 0 then
					player.Character:PivotTo(st.safe)
					Bounce:FireClient(player, Vector3.zero, false, "reset")
				end
			elseif hit and hit.Instance:GetAttribute("Lava") then
				HazardService.Burn(player)
			elseif hit and not hit.Instance:GetAttribute("Moving") and hit.Instance.Anchored
				and hit.Instance:GetAttribute("Bounce") == nil and hit.Instance:GetAttribute("Slide") == nil then
				st.safe = CFrame.new(hit.Position + Vector3.new(0, 3, 0)) * (root.CFrame - root.CFrame.Position)
			end

			for id, cp in pairs(Config.Checkpoints) do
				if slot.checkpoint ~= id and (pos - cp.pos).Magnitude < 14 then
					slot.checkpoint = id
					push(player, { kind = "checkpoint", id = id })
				end
			end
			for _, w in ipairs(Config.Warps) do
				if not slot.warps[w.id] and (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(w.pos.X, 0, w.pos.Z)).Magnitude < 16 then
					slot.warps[w.id] = true
					push(player, { kind = "warpfound", id = w.id })
				end
			end
		end
	end
end)

print(string.format("[Bunny64] Ready: %d carrots, %d golden carrots, %d bugs.", TOTAL_CARROTS, #Config.Goldens, #info.enemies))
