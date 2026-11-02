--[[
	BossKit - the shared toolbox for every boss fight.

	  Arena        who is in the fight (a circle plus a height band)
	  Tag          boss-bar data on the model (name, HP, arena) for the client
	  strike       a glowing warning circle, then a hit (lightning, lava, roots...)
	  shockwave    an expanding ring along the floor: jump it
	  projectile   a ball that flies straight, lobs with gravity, or homes in
	  minion       a temporary baddie (cleared when the fight resets)
	  Clear        removes everything a boss left lying around

	Every hazard is telegraphed: nothing in a boss fight should hit you without
	showing you first where it's going to land.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))

local BossKit = {}

local FEET = 2.6
local folder
local cb
local hazards = {}
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include

--------------------------------------------------------------------------------
-- Arenas
--------------------------------------------------------------------------------

local Arena = {}
Arena.__index = Arena

-- center = the arena floor's centre; players count while within radius (+10)
-- and between the floor and floor + height
function BossKit.Arena(center, radius, height)
	return setmetatable({ center = center, radius = radius, height = height or 80 }, Arena)
end

function Arena:contains(p, pad)
	local flat = Vector3.new(p.X - self.center.X, 0, p.Z - self.center.Z).Magnitude
	return flat < self.radius + (pad or 10) and p.Y > self.center.Y - 10 and p.Y < self.center.Y + self.height
end

function Arena:players()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 and self:contains(root.Position) then
			table.insert(list, { player = player, root = root, hum = hum, char = char })
		end
	end
	return list
end

function Arena:nearest(list, pos)
	local best, bestD = nil, math.huge
	for _, e in ipairs(list) do
		local d = (e.root.Position - pos).Magnitude
		if d < bestD then
			best, bestD = e, d
		end
	end
	return best
end

function Arena:random(list)
	if #list == 0 then
		return nil
	end
	return list[math.random(1, #list)]
end

-- Keep a point inside the arena (flat), returns (point, hitEdge)
function Arena:clamp(p, margin)
	local flat = Vector3.new(p.X - self.center.X, 0, p.Z - self.center.Z)
	local limit = self.radius - (margin or 8)
	if flat.Magnitude > limit then
		flat = flat.Unit * limit
		return Vector3.new(self.center.X + flat.X, p.Y, self.center.Z + flat.Z), true
	end
	return p, false
end

-- A random point on the arena floor
function Arena:randomPoint(margin)
	local a = math.random() * math.pi * 2
	local r = math.sqrt(math.random()) * (self.radius - (margin or 6))
	return self.center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

--------------------------------------------------------------------------------
-- Boss bar data
--------------------------------------------------------------------------------

-- The client's boss bar, title card, music and hurt-flash all read these
function BossKit.Tag(model, id, name, maxHp, arena, hint)
	model:SetAttribute("Boss", true)
	model:SetAttribute("BossId", id)
	model:SetAttribute("BossName", name)
	model:SetAttribute("MaxHP", maxHp)
	model:SetAttribute("HP", maxHp)
	model:SetAttribute("ArenaCenter", arena.center)
	model:SetAttribute("ArenaRadius", arena.radius)
	model:SetAttribute("ArenaHeight", arena.height)
	model:SetAttribute("Hint", hint or "")
end

--------------------------------------------------------------------------------
-- Hazards
--------------------------------------------------------------------------------

local function floorAt(pos)
	local hit = workspace:Raycast(pos + Vector3.new(0, 12, 0), Vector3.new(0, -60, 0), floorParams)
	return hit and hit.Position.Y or pos.Y
end

local function newPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = folder
	return p
end

local STRIKE_COLORS = {
	lightning = Color3.fromRGB(250, 236, 140),
	lava = Color3.fromRGB(255, 120, 60),
	roots = Color3.fromRGB(150, 210, 110),
	shadow = Color3.fromRGB(170, 120, 230),
}

-- A warning circle on the floor, then a hit `delay` seconds later
function BossKit.strike(owner, arena, pos, opts)
	opts = opts or {}
	local r = opts.radius or 5
	local y = floorAt(pos)
	local kind = opts.kind or "lightning"
	local warn = newPart({
		Name = "Warning",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, r * 2, r * 2),
		CFrame = CFrame.new(pos.X, y + 0.2, pos.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = STRIKE_COLORS[kind] or STRIKE_COLORS.lightning,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
	})
	table.insert(hazards, {
		type = "strike", owner = owner, arena = arena, pos = Vector3.new(pos.X, y, pos.Z), r = r,
		t0 = os.clock(), delay = opts.delay or 1, part = warn, kind = kind, height = opts.height or 14,
	})
end

-- An expanding ring along the floor; only hurts bunnies standing on the ground
function BossKit.shockwave(owner, arena, center, speed, maxR, floorY)
	local y = floorY or floorAt(center)
	table.insert(hazards, {
		type = "wave", owner = owner, arena = arena, center = Vector3.new(center.X, y, center.Z),
		t0 = os.clock(), speed = speed or 44, maxR = maxR or 60, hit = {},
	})
	cb.effect("shockwave", Vector3.new(center.X, y, center.Z), speed or 44)
end

-- A ball: straight (vel), lobbed (gravity > 0) or homing (homing = turn rate)
function BossKit.projectile(owner, arena, from, vel, opts)
	opts = opts or {}
	local size = opts.size or 3.2
	local ball = newPart({
		Name = "BossShot",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		CFrame = CFrame.new(from),
		Color = opts.color or Config.Palette.Ember,
		Material = Enum.Material.Neon,
	})
	local light = Instance.new("PointLight")
	light.Color = opts.color or Color3.fromRGB(255, 140, 70)
	light.Range = 12
	light.Parent = ball
	table.insert(hazards, {
		type = "shot", owner = owner, arena = arena, part = ball, vel = vel, gravity = opts.gravity or 0,
		homing = opts.homing, target = opts.target, die = os.clock() + (opts.life or 5), r = size / 2 + 1.4,
		onLand = opts.onLand,
	})
	return ball
end

-- A temporary baddie for the fight
function BossKit.minion(owner, kind, pos, skin)
	local e = EnemyService.Spawn(kind, pos, skin, 40)
	if e then
		owner.minions = owner.minions or {}
		table.insert(owner.minions, e)
		cb.effect("poof", pos + Vector3.new(0, 2, 0))
	end
	return e
end

function BossKit.minionCount(owner)
	local n = 0
	for _, e in ipairs(owner.minions or {}) do
		if not e.gone and e.alive then
			n += 1
		end
	end
	return n
end

-- Remove every hazard and minion that belongs to this boss
function BossKit.Clear(owner)
	for i = #hazards, 1, -1 do
		local h = hazards[i]
		if h.owner == owner then
			if h.part then
				h.part:Destroy()
			end
			table.remove(hazards, i)
		end
	end
	for _, e in ipairs(owner.minions or {}) do
		EnemyService.Despawn(e)
	end
	owner.minions = {}
end

local function step(dt)
	local now = os.clock()
	for i = #hazards, 1, -1 do
		local h = hazards[i]
		local done = false
		local list = h.arena:players()
		if h.type == "strike" then
			local age = now - h.t0
			if age < h.delay then
				-- the warning flashes faster as the hit gets close
				local u = age / h.delay
				h.part.Transparency = 0.25 + 0.5 * (0.5 + 0.5 * math.sin(age * (8 + 30 * u)))
			else
				for _, e in ipairs(list) do
					local p = e.root.Position
					local flat = Vector3.new(p.X - h.pos.X, 0, p.Z - h.pos.Z).Magnitude
					local feet = p.Y - FEET
					if flat < h.r + 0.8 and feet > h.pos.Y - 2 and feet < h.pos.Y + h.height then
						cb.hurt(e.player, h.pos)
					end
				end
				cb.effect("strike", h.pos, h.kind)
				h.part:Destroy()
				done = true
			end
		elseif h.type == "wave" then
			local r = (now - h.t0) * h.speed
			if r > h.maxR then
				done = true
			else
				for _, e in ipairs(list) do
					local p = e.root.Position
					local flat = Vector3.new(p.X - h.center.X, 0, p.Z - h.center.Z).Magnitude
					local grounded = p.Y - FEET < h.center.Y + 1.4
					if grounded and not h.hit[e.player] and math.abs(flat - r) < 2.8 then
						h.hit[e.player] = true
						cb.hurt(e.player, h.center)
					end
				end
			end
		elseif h.type == "shot" then
			local p = h.part.Position
			if h.homing and h.target and h.target.Parent then
				local want = (h.target.Position - p)
				if want.Magnitude > 0.1 then
					local speed = h.vel.Magnitude
					h.vel = h.vel:Lerp(want.Unit * speed, math.clamp(h.homing * dt, 0, 1))
				end
			end
			h.vel += Vector3.new(0, -h.gravity * dt, 0)
			p += h.vel * dt
			h.part.CFrame = CFrame.new(p)
			if now > h.die or not h.arena:contains(p, 30) then
				done = true
			else
				for _, e in ipairs(list) do
					if (e.root.Position - p).Magnitude < h.r then
						cb.hurt(e.player, p - h.vel * 0.1)
						done = true
						break
					end
				end
				if not done and h.gravity > 0 and h.vel.Y < 0 and p.Y < h.arena.center.Y + h.part.Size.Y / 2 then
					done = true
					if h.onLand then
						h.onLand(Vector3.new(p.X, h.arena.center.Y, p.Z))
					end
				end
			end
			if done then
				h.part:Destroy()
			end
		end
		if done then
			table.remove(hazards, i)
		end
	end
end

function BossKit.Init(info, callbacks)
	cb = callbacks
	if not folder then
		folder = workspace:FindFirstChild("Boss")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Boss"
			folder.Parent = workspace
		end
		floorParams.FilterDescendantsInstances = { info.solidFolder, workspace.Terrain }
		RunService.Heartbeat:Connect(step)
	end
	return folder
end

function BossKit.Folder()
	return folder
end

-- Has this player's feet just come down on a point (a weak spot)?
function BossKit.stomped(e, point, radius, pounding)
	local h = e.root.Position
	local feet = h.Y - FEET
	local vy = e.root.AssemblyLinearVelocity.Y
	local flat = Vector3.new(h.X - point.X, 0, h.Z - point.Z).Magnitude
	local move = e.char:GetAttribute("Move")
	return flat < (radius or 4.6) and feet > point.Y - 2.2 and feet < point.Y + 5
		and (vy < 1 or move == "pound" or pounding)
end

return BossKit
