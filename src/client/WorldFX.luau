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
local goldenCount = 0
local currentRegion = nil
local inArena = false

-- Region looks -------------------------------------------------------------------
local LOOKS = {
	meadow = {
		fog = Color3.fromRGB(176, 182, 172), fogStart = 160, fogEnd = 900, ambient = Color3.fromRGB(132, 124, 112),
		tint = Color3.fromRGB(255, 244, 228), sat = -0.18, clock = 16.3,
	},
	peaks = {
		fog = Color3.fromRGB(196, 206, 214), fogStart = 120, fogEnd = 700, ambient = Color3.fromRGB(138, 144, 156),
		tint = Color3.fromRGB(236, 244, 255), sat = -0.25, clock = 14.5,
	},
	canyon = {
		fog = Color3.fromRGB(206, 178, 140), fogStart = 160, fogEnd = 850, ambient = Color3.fromRGB(150, 126, 100),
		tint = Color3.fromRGB(255, 236, 210), sat = -0.12, clock = 17.2,
	},
	castle = {
		fog = Color3.fromRGB(70, 34, 30), fogStart = 60, fogEnd = 520, ambient = Color3.fromRGB(110, 70, 60),
		tint = Color3.fromRGB(255, 214, 196), sat = -0.1, clock = 18.6,
	},
}

local function regionAt(pos)
	if pos.Z > 470 and math.abs(pos.X) < 320 then
		return "castle"
	elseif pos.Z < -470 then
		return "peaks"
	elseif pos.X > 460 then
		return "canyon"
	end
	return "meadow"
end

local function applyLook(id)
	local look = LOOKS[id]
	local info = TweenInfo.new(2.5, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, {
		FogColor = look.fog, FogStart = look.fogStart, FogEnd = look.fogEnd,
		OutdoorAmbient = look.ambient, ClockTime = look.clock,
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

-- Gates -----------------------------------------------------------------------------------
local function refreshGates()
	for _, g in ipairs(gates) do
		local open = goldenCount >= (g:GetAttribute("GoldenGate") or 0)
		g.CanCollide = not open
		g.Transparency = open and 0.85 or 0.2
	end
end

function WorldFX.SetGoldenCount(n)
	goldenCount = n or 0
	refreshGates()
end

function WorldFX.InArena()
	return inArena
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
		end
	end
	refreshGates()

	local nextZoneCheck = 0
	RunService.RenderStepped:Connect(function()
		updateHazards()

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
					Hud.RegionBanner(r.name)
				end
			end
			if not inArena then
				Effects.SetMusic(region)
			end
		end
		local arena = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(0, 0, 800)).Magnitude < 70 and pos.Y > 185
		if arena ~= inArena then
			inArena = arena
			Effects.SetMusic(arena and "boss" or region)
			if arena then
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
		RunService.RenderStepped:Connect(function()
			local boss = bossFolder:FindFirstChild("KingGrumble")
			if not boss then
				return
			end
			local hurt = boss:GetAttribute("State") == "hurt"
			local flash = hurt and (math.floor(os.clock() * 12) % 2 == 0) and 0.6 or 0
			for _, d in ipairs(boss:GetChildren()) do
				if d:IsA("BasePart") and d.Name ~= "Root" then
					d.LocalTransparencyModifier = flash
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
