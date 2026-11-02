--[[
	Weather - a little atmosphere for each region, drawn around the camera:
	  meadow  drifting pollen motes
	  peaks   gentle snowfall
	  canyon  wind-blown dust
	  castle  rising embers
	  forest  drifting fireflies
	  sky     wisps of cloud streaming past
	Uses particle textures that ship with Roblox, so no uploads are needed.
]]

local RunService = game:GetService("RunService")

local Weather = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local STYLES = {
	meadow = {
		texture = SPARK, rate = 6, lifetime = NumberRange.new(6, 9), speed = NumberRange.new(0.5, 1.5),
		accel = Vector3.new(0.6, 0.2, 0.3), size = 0.35, color = Color3.fromRGB(255, 240, 170), light = 0.4,
		offset = Vector3.new(0, 4, 0), dir = Enum.NormalId.Top, spread = 180,
	},
	peaks = {
		texture = SPARK, rate = 60, lifetime = NumberRange.new(6, 8), speed = NumberRange.new(4, 7),
		accel = Vector3.new(1.2, -1, 0.4), size = 0.4, color = Color3.fromRGB(246, 250, 255), light = 0.2,
		offset = Vector3.new(0, 30, 0), dir = Enum.NormalId.Bottom, spread = 20,
	},
	canyon = {
		texture = SMOKE, rate = 4, lifetime = NumberRange.new(4, 6), speed = NumberRange.new(8, 12),
		accel = Vector3.new(4, 0, 1), size = 4, color = Color3.fromRGB(214, 180, 130), light = 0,
		offset = Vector3.new(-30, 1, 0), dir = Enum.NormalId.Right, spread = 30, transparency = 0.8,
	},
	castle = {
		texture = FIRE, rate = 14, lifetime = NumberRange.new(3, 5), speed = NumberRange.new(2, 5),
		accel = Vector3.new(0.5, 2.5, 0.2), size = 0.3, color = Color3.fromRGB(255, 150, 70), light = 1,
		offset = Vector3.new(0, -8, 0), dir = Enum.NormalId.Top, spread = 40,
	},
	forest = {
		texture = SPARK, rate = 9, lifetime = NumberRange.new(4, 7), speed = NumberRange.new(0.3, 1.2),
		accel = Vector3.new(0.3, 0.15, -0.2), size = 0.3, color = Color3.fromRGB(214, 236, 130), light = 1,
		offset = Vector3.new(0, 2, 0), dir = Enum.NormalId.Top, spread = 180,
	},
	sky = {
		texture = SMOKE, rate = 3, lifetime = NumberRange.new(5, 7), speed = NumberRange.new(6, 9),
		accel = Vector3.new(1.5, 0, 0.5), size = 6, color = Color3.fromRGB(240, 244, 252), light = 0.1,
		offset = Vector3.new(-30, -6, 0), dir = Enum.NormalId.Right, spread = 25, transparency = 0.82,
	},
}

local emitterPart, emitter
local current = nil

local function apply(style)
	emitter.Texture = style.texture
	emitter.Rate = style.rate
	emitter.Lifetime = style.lifetime
	emitter.Speed = style.speed
	emitter.Acceleration = style.accel
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.15, style.size),
		NumberSequenceKeypoint.new(0.85, style.size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Color = ColorSequence.new(style.color)
	emitter.LightEmission = style.light
	local t = style.transparency or 0.15
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, t),
		NumberSequenceKeypoint.new(0.8, t),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.EmissionDirection = style.dir
	emitter.SpreadAngle = Vector2.new(style.spread, style.spread)
	emitter.Enabled = true
end

function Weather.SetRegion(region)
	if region == current or not emitter then
		return
	end
	current = region
	local style = STYLES[region]
	if style then
		apply(style)
	else
		emitter.Enabled = false
	end
end

function Weather.SetEnabled(on)
	if emitter then
		emitter.Enabled = on and current ~= nil and STYLES[current] ~= nil
	end
end

function Weather.Init()
	emitterPart = Instance.new("Part")
	emitterPart.Name = "WeatherEmitter"
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(90, 1, 90)
	emitterPart.Parent = workspace:FindFirstChild("Bunny64LocalFX") or workspace
	emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.LockedToPart = false
	emitter.Parent = emitterPart
	RunService.RenderStepped:Connect(function()
		local style = STYLES[current or ""]
		local cam = workspace.CurrentCamera
		if style then
			emitterPart.CFrame = CFrame.new(cam.CFrame.Position + style.offset)
		end
	end)
end

return Weather
