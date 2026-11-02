--[[
	HazardService - decides who gets hurt by firebars, crushers, lava and
	boulders. Firebars and crushers move on the shared server clock (see
	shared/HazardMath); clients animate them, the server checks collisions.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local HazardMath = require(Shared:WaitForChild("HazardMath"))

local HazardService = {}

local info, cb
local lastBurn = {}

local function characterOf(hit)
	local model = hit and hit:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	local player = Players:GetPlayerFromCharacter(model)
	return player, model
end

function HazardService.Burn(player)
	local now = os.clock()
	if (lastBurn[player] or 0) > now - 0.35 then
		return
	end
	lastBurn[player] = now
	cb.burn(player)
end

local function hookLava(part)
	part.Touched:Connect(function(hit)
		local player = characterOf(hit)
		if player then
			HazardService.Burn(player)
		end
	end)
end

local function spawnBoulder(spawn)
	local b = Instance.new("Part")
	b.Name = "Boulder"
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.one * 8
	b.Material = Enum.Material.Sandstone
	b.Color = Config.Palette.SandstoneDark
	b.CFrame = CFrame.new(spawn.from + Vector3.new(0, 0, math.random(-6, 6)))
	b.CustomPhysicalProperties = PhysicalProperties.new(3, 0.5, 0.1, 1, 1)
	b.Parent = info.hazardFolder
	b:SetNetworkOwner(nil)
	b.AssemblyLinearVelocity = spawn.dir * 24
	local hitAt = {}
	b.Touched:Connect(function(hit)
		local player = characterOf(hit)
		if player and (hitAt[player] or 0) < os.clock() - 1 then
			hitAt[player] = os.clock()
			cb.hurt(player, b.Position, b.AssemblyLinearVelocity.Unit * 50 + Vector3.new(0, 40, 0))
		end
	end)
	Debris:AddItem(b, 14)
end

function HazardService.Start(worldInfo, callbacks)
	info, cb = worldInfo, callbacks

	for _, d in ipairs(info.solidFolder:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Lava") then
			hookLava(d)
		end
	end

	-- Boulders
	task.spawn(function()
		while true do
			for _, s in ipairs(info.boulderSpawns) do
				spawnBoulder(s)
			end
			task.wait(2.4)
		end
	end)
	-- clear boulders that fell off the world
	RunService.Heartbeat:Connect(function()
		for _, b in ipairs(info.hazardFolder:GetChildren()) do
			if b.Name == "Boulder" and b.Position.Y < Config.WaterLevel - 10 then
				b:Destroy()
			end
		end
	end)

	-- Firebars & crushers
	RunService.Heartbeat:Connect(function()
		local t = HazardMath.Now()
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 then
				local p = root.Position
				for _, fb in ipairs(info.firebars) do
					if math.abs(p.Y - fb.pivot.Y) < 4 and (Vector3.new(p.X, 0, p.Z) - Vector3.new(fb.pivot.X, 0, fb.pivot.Z)).Magnitude < fb.length + 3 then
						local a = HazardMath.FirebarAngle(fb.speed, fb.phase, t)
						local tip = fb.pivot + HazardMath.FirebarDir(a) * fb.length
						-- check the torso and the head
						local d = math.min(
							HazardMath.SegmentDistance(p, fb.pivot, tip),
							HazardMath.SegmentDistance(p + Vector3.new(0, 1.8, 0), fb.pivot, tip)
						)
						if d < 2.1 then
							cb.hurt(player, fb.pivot)
						end
					end
				end
				for _, c in ipairs(info.crushers) do
					local base = c.base.Position
					local half = c.size / 2
					if math.abs(p.X - base.X) < half.X + 0.9 and math.abs(p.Z - base.Z) < half.Z then
						local drop = HazardMath.CrusherDrop(c.period, c.offset, t)
						local bottom = base.Y - half.Y - drop * c.drop
						if bottom < p.Y + 3 and bottom > p.Y - 4 then
							cb.hurt(player, Vector3.new(base.X + 20, p.Y, p.Z)) -- knocked back toward the entrance
						end
					end
				end
			end
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	lastBurn[player] = nil
end)

return HazardService
