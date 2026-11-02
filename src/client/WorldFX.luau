--[[
	WorldFX - client-side world behaviour:
	  * animates firebars and crushers from the shared server clock
	  * opens golden-carrot gates for players who have enough golden carrots
	  * per-region lighting, fog and music, plus the region title banner
	  * makes King Grumble flash when he's hit
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local HazardMath = require(Shared:WaitForChild("HazardMath"))

local player = Players.LocalPlayer
local WorldFX = {}

local Effects, Hud
local hazards = {}
local gates = {}
local flags = {}
local activeCheckpoint = nil
local goldenCount = 0
local currentRegion = nil
local slotRef = nil

-- Region title cards show how many golden carrots you've found there
function WorldFX.SetSlot(slot)
	slotRef = slot
end
local inArena = false
local arenaBoss = nil -- the boss model whose arena we're standing in

-- Which boss arena (if any) is this point in? Bosses publish their arena as attributes.
local function bossAt(pos)
	local folder = workspace:FindFirstChild("Boss")
	if not folder then
		return nil
	end
	for _, m in ipairs(folder:GetChildren()) do
		if m:GetAttribute("Boss") then
			local c = m:GetAttribute("ArenaCenter")
			local r = m:GetAttribute("ArenaRadius")
			local h = m:GetAttribute("ArenaHeight") or 80
			if c and r then
				local flat = Vector3.new(pos.X - c.X, 0, pos.Z - c.Z).Magnitude
				if flat < r + 12 and pos.Y > c.Y - 10 and pos.Y < c.Y + h then
					return m
				end
			end
		end
	end
	return nil
end

-- Region looks -------------------------------------------------------------------
local LOOKS = {
	-- ambient = outdoor fill light, indoor = light inside roofed rooms (keep, dungeon...)
	meadow = {
		fog = Color3.fromRGB(176, 182, 172), fogStart = 160, fogEnd = 900, ambient = Color3.fromRGB(132, 124, 112),
		indoor = Color3.fromRGB(120, 114, 106), tint = Color3.fromRGB(255, 244, 228), sat = -0.18, clock = 16.3, brightness = 2.2,
	},
	peaks = {
		fog = Color3.fromRGB(196, 206, 214), fogStart = 120, fogEnd = 700, ambient = Color3.fromRGB(138, 144, 156),
		indoor = Color3.fromRGB(124, 130, 140), tint = Color3.fromRGB(236, 244, 255), sat = -0.25, clock = 14.5, brightness = 2.2,
	},
	canyon = {
		fog = Color3.fromRGB(206, 178, 140), fogStart = 160, fogEnd = 850, ambient = Color3.fromRGB(150, 126, 100),
		indoor = Color3.fromRGB(130, 112, 94), tint = Color3.fromRGB(255, 236, 210), sat = -0.12, clock = 17.2, brightness = 2.3,
	},
	-- moody but readable: warm red haze far out, plenty of fill light indoors
	castle = {
		fog = Color3.fromRGB(150, 98, 82), fogStart = 160, fogEnd = 950, ambient = Color3.fromRGB(168, 138, 126),
		indoor = Color3.fromRGB(150, 122, 110), tint = Color3.fromRGB(255, 234, 220), sat = -0.08, clock = 16.6, brightness = 2.6,
	},
	-- late-afternoon gloom under the trees: green-grey haze, close fog
	forest = {
		fog = Color3.fromRGB(128, 146, 126), fogStart = 60, fogEnd = 520, ambient = Color3.fromRGB(112, 124, 104),
		indoor = Color3.fromRGB(110, 118, 100), tint = Color3.fromRGB(236, 246, 226), sat = -0.2, clock = 17.6, brightness = 1.9,
	},
	-- the Underburrow: deep violet dark, crystals and torches doing the lighting
	secret = {
		fog = Color3.fromRGB(34, 26, 52), fogStart = 30, fogEnd = 420, ambient = Color3.fromRGB(96, 86, 124),
		indoor = Color3.fromRGB(96, 86, 124), tint = Color3.fromRGB(226, 214, 255), sat = -0.15, clock = 0.4, brightness = 1.2,
	},
	-- bright and clear above the clouds; the fog is the cloud sea far below
	sky = {
		fog = Color3.fromRGB(214, 222, 236), fogStart = 260, fogEnd = 1200, ambient = Color3.fromRGB(156, 160, 176),
		indoor = Color3.fromRGB(140, 144, 160), tint = Color3.fromRGB(246, 248, 255), sat = -0.1, clock = 13.4, brightness = 2.6,
	},
}

local function regionAt(pos)
	local S = Config.Secret
	if Vector3.new(pos.X - S.center.X, 0, pos.Z - S.center.Z).Magnitude < S.radius then
		return "secret"
	elseif pos.Y > Config.SkyFloor - 60 then
		return "sky"
	elseif pos.Z > 470 and math.abs(pos.X) < 320 then
		return "castle"
	elseif pos.Z < -470 then
		return "peaks"
	elseif pos.X > 460 then
		return "canyon"
	elseif pos.X < -470 then
		return "forest"
	end
	return "meadow"
end

local function applyLook(id)
	if WorldFX.OnRegion then
		WorldFX.OnRegion(id)
	end
	local look = LOOKS[id]
	local info = TweenInfo.new(2.5, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, {
		FogColor = look.fog, FogStart = look.fogStart, FogEnd = look.fogEnd,
		OutdoorAmbient = look.ambient, Ambient = look.indoor, ClockTime = look.clock, Brightness = look.brightness,
	}):Play()
	local grade = Lighting:FindFirstChild("Bunny64Grade")
	if grade then
		TweenService:Create(grade, info, { TintColor = look.tint, Saturation = look.sat }):Play()
	end
end

-- Hazards ---------------------------------------------------------------------------------
local function register(model)
	if not model:IsA("Model") then
		return
	end
	local kind = model:GetAttribute("Kind")
	if kind == "firebar" then
		table.insert(hazards, {
			model = model, kind = kind, pivot = model:GetAttribute("Pivot"),
			speed = model:GetAttribute("Speed"), phase = model:GetAttribute("Phase"),
		})
	elseif kind == "crusher" then
		table.insert(hazards, {
			model = model, kind = kind, base = model:GetAttribute("Base"), drop = model:GetAttribute("Drop"),
			period = model:GetAttribute("Period"), offset = model:GetAttribute("Offset"), last = 0,
		})
	end
end

local function updateHazards()
	local t = HazardMath.Now()
	for _, h in ipairs(hazards) do
		if h.model.Parent then
			if h.kind == "firebar" then
				local a = HazardMath.FirebarAngle(h.speed, h.phase, t)
				h.model:PivotTo(CFrame.new(h.pivot) * CFrame.Angles(0, a, 0))
			else
				local d = HazardMath.CrusherDrop(h.period, h.offset, t)
				h.model:PivotTo(h.base - Vector3.new(0, d * h.drop, 0))
				if d >= 1 and h.last < 1 then
					local char = player.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if root and (root.Position - h.base.Position).Magnitude < 40 then
						Effects.Shake(0.5, 0.2)
						Effects.Play("Land", 0.6)
					end
				end
				h.last = d
			end
		end
	end
end

-- Traps (each player's own screen, so they react instantly) ------------------------------
-- Blink blocks swap in and out on the shared server clock; crumbling tiles shake
-- for a moment after you land on them, drop away, then come back.
local blinks = {}
local crumbles = {}
local crumbling = {} -- [Part] = { t0, base }
local trapParams = RaycastParams.new()
trapParams.FilterType = Enum.RaycastFilterType.Include

local function updateTraps(now)
	if #blinks > 0 then
		local t = workspace:GetServerTimeNow()
		for _, b in ipairs(blinks) do
			local period = b.period
			local on = math.floor(t / period) % 2 == b.group
			local into = (t % period) / period
			if on ~= b.on then
				b.on = on
				b.part.CanCollide = on
			end
			local ltm
			if not on then
				ltm = 0.85
			elseif into > 0.68 then
				ltm = (math.floor(t * 14) % 2 == 0) and 0.55 or 0.05 -- about to vanish!
			else
				ltm = 0
			end
			b.part.LocalTransparencyModifier = ltm
		end
	end
	if #crumbles == 0 then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -4.5, 0), trapParams)
		if hit and hit.Instance:GetAttribute("Crumble") and not crumbling[hit.Instance] then
			crumbling[hit.Instance] = { t0 = now, base = hit.Instance.CFrame }
			Effects.Play("Crate", 0.6)
		end
	end
	for part, c in pairs(crumbling) do
		local age = now - c.t0
		if age < 0.55 then
			part.CFrame = c.base * CFrame.new((math.random() - 0.5) * 0.3, 0, (math.random() - 0.5) * 0.3)
		elseif age < 3.6 then
			if part.CanCollide then
				part.CanCollide = false
				Effects.Burst(c.base.Position, part.Color, 8, 4, 0.6, -2)
			end
			local fall = age - 0.55
			part.CFrame = c.base - Vector3.new(0, fall * fall * 30, 0)
			part.LocalTransparencyModifier = math.clamp(fall * 1.5, 0, 1)
		else
			part.CFrame = c.base
			part.CanCollide = true
			part.LocalTransparencyModifier = 0
			crumbling[part] = nil
		end
	end
end

-- Gates -----------------------------------------------------------------------------------
local function refreshGates()
	for _, g in ipairs(gates) do
		local open = goldenCount >= (g:GetAttribute("GoldenGate") or 0)
		g.CanCollide = not open
		g.Transparency = open and 0.85 or 0.2
	end
end

local function refreshFlags()
	for _, f in ipairs(flags) do
		local on = f:GetAttribute("Checkpoint") == activeCheckpoint
		f.Color = on and Color3.fromRGB(226, 182, 74) or Color3.fromRGB(136, 66, 54)
		f.Material = on and Enum.Material.Neon or Enum.Material.Fabric
	end
end

-- The flag of the checkpoint you'll respawn at glows gold
function WorldFX.SetCheckpoint(id)
	activeCheckpoint = id
	refreshFlags()
end

function WorldFX.SetGoldenCount(n)
	goldenCount = n or 0
	refreshGates()
end

function WorldFX.InArena()
	return inArena
end

function WorldFX.ArenaBoss()
	return arenaBoss
end

function WorldFX.Init(effects, hud)
	Effects, Hud = effects, hud
	local world = workspace:WaitForChild("Bunny64World")
	local hazardFolder = world:WaitForChild("Hazards")
	for _, m in ipairs(hazardFolder:GetChildren()) do
		register(m)
	end
	hazardFolder.ChildAdded:Connect(register)
	for _, d in ipairs(world:WaitForChild("Solid"):GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("GoldenGate") then
			table.insert(gates, d)
		elseif d:IsA("BasePart") and d:GetAttribute("Checkpoint") then
			table.insert(flags, d)
		elseif d:IsA("BasePart") and d:GetAttribute("Blink") ~= nil then
			table.insert(blinks, { part = d, group = d:GetAttribute("Blink"), period = d:GetAttribute("BlinkPeriod") or 1.6 })
		elseif d:IsA("BasePart") and d:GetAttribute("Crumble") then
			table.insert(crumbles, d)
		end
	end
	refreshGates()
	refreshFlags()

	local nextZoneCheck = 0
	trapParams.FilterDescendantsInstances = { world:WaitForChild("Solid") }
	RunService.RenderStepped:Connect(function()
		updateHazards()
		updateTraps(os.clock())

		local now = os.clock()
		if now < nextZoneCheck then
			return
		end
		nextZoneCheck = now + 0.5
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local pos = root.Position
		local region = regionAt(pos)
		if region ~= currentRegion then
			currentRegion = region
			applyLook(region)
			for _, r in ipairs(Config.Regions) do
				if r.id == region then
					local got, total = 0, 0
					for _, g in ipairs(Config.Goldens) do
						if g.region == region then
							total += 1
							if slotRef and slotRef.goldens[g.id] then
								got += 1
							end
						end
					end
					Hud.RegionBanner(string.format("%s  %d/%d", r.name, got, total))
				end
			end
			if not inArena then
				Effects.SetMusic(region)
			end
		end
		local boss = bossAt(pos)
		local arena = boss ~= nil and boss:GetAttribute("State") ~= "dead"
		if arena ~= inArena or (arena and boss ~= arenaBoss) then
			inArena = arena
			arenaBoss = arena and boss or nil
			Effects.SetMusic(arena and (boss:GetAttribute("Music") or "boss") or region)
			if arena and boss:GetAttribute("BossId") == "grumble" then
				Hud.RegionBanner("THRONE ROOM")
			end
		end
	end)

	-- Boss flashing while hurt
	task.spawn(function()
		local bossFolder = workspace:WaitForChild("Boss", 60)
		if not bossFolder then
			return
		end
		local flashing = {}
		RunService.RenderStepped:Connect(function()
			for _, boss in ipairs(bossFolder:GetChildren()) do
				if boss:GetAttribute("Boss") then
					local hurt = boss:GetAttribute("State") == "hurt"
					if hurt or flashing[boss] then
						flashing[boss] = hurt or nil
						local flash = hurt and (math.floor(os.clock() * 12) % 2 == 0) and 0.6 or 0
						for _, d in ipairs(boss:GetChildren()) do
							if d:IsA("BasePart") and d.Name ~= "Root" and d.Transparency < 1 then
								d.LocalTransparencyModifier = flash
							end
						end
					end
				end
			end
		end)
	end)
end

-- Forget the current region so entering the game re-applies its look and music
function WorldFX.ResetRegion()
	currentRegion = nil
	inArena = false
end

function WorldFX.Region()
	return currentRegion
end

return WorldFX
