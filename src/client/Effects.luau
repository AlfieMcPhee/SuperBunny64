--[[
	Effects - local sounds, chunky block particles and camera shake.
]]

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local Effects = {}

local sounds = {}
for name, def in pairs(Config.Sounds) do
	local s = Instance.new("Sound")
	s.Name = "Bunny64_" .. name
	s.SoundId = def.id
	s.Volume = def.volume or 0.5
	s.Parent = SoundService
	sounds[name] = s
end

function Effects.Play(name, speed)
	local base = sounds[name]
	if not base or base.SoundId == "" then
		return
	end
	local s = base:Clone()
	s.PlaybackSpeed = speed or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 4)
end

-- A short rising jingle for golden carrots
function Effects.Jingle()
	for i, speed in ipairs({ 0.8, 1.0, 1.2, 1.6 }) do
		task.delay((i - 1) * 0.12, function()
			Effects.Play("Golden", speed)
		end)
	end
end

local fxFolder = Instance.new("Folder")
fxFolder.Name = "Bunny64LocalFX"
fxFolder.Parent = workspace

local function cube(pos, color, size)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = Vector3.one * size
	p.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
	p.Parent = fxFolder
	return p
end

-- Burst of little tumbling cubes
function Effects.Burst(pos, color, count, speed, size, rise)
	count = count or 8
	speed = speed or 6
	size = size or 0.6
	rise = rise or 4
	for _ = 1, count do
		local p = cube(pos, color, size * (0.6 + math.random() * 0.8))
		local a = math.random() * math.pi * 2
		local dist = speed * (0.4 + math.random() * 0.6)
		local target = pos + Vector3.new(math.cos(a) * dist, rise * (0.3 + math.random()), math.sin(a) * dist)
		local t = 0.45 + math.random() * 0.3
		TweenService:Create(p, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(target) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
			Size = Vector3.one * 0.05,
			Transparency = 0.6,
		}):Play()
		Debris:AddItem(p, t + 0.05)
	end
end

-- Flat ring of dust (ground pound / landing)
function Effects.Ring(pos, color, radius)
	radius = radius or 12
	for i = 1, 16 do
		local a = i / 16 * math.pi * 2
		local p = cube(pos + Vector3.new(0, 0.5, 0), color, 1.2)
		local target = pos + Vector3.new(math.cos(a) * radius, 1.2, math.sin(a) * radius)
		TweenService:Create(p, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(target),
			Size = Vector3.one * 0.1,
			Transparency = 0.7,
		}):Play()
		Debris:AddItem(p, 0.45)
	end
end

-- Camera shake ------------------------------------------------------------------
local shakeAmount, shakeUntil, shakeLen = 0, 0, 0.001
function Effects.Shake(amount, duration)
	shakeAmount = math.max(amount, shakeAmount * math.max(0, (shakeUntil - os.clock()) / shakeLen))
	shakeLen = duration
	shakeUntil = os.clock() + duration
end

RunService:BindToRenderStep("Bunny64Shake", Enum.RenderPriority.Camera.Value + 1, function()
	local left = shakeUntil - os.clock()
	if left <= 0 then
		return
	end
	local k = shakeAmount * (left / shakeLen)
	local cam = workspace.CurrentCamera
	cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
end)

-- Optional music ---------------------------------------------------------------------
if Config.MusicId ~= "" then
	local music = Instance.new("Sound")
	music.Name = "Bunny64Music"
	music.SoundId = Config.MusicId
	music.Volume = Config.MusicVolume
	music.Looped = true
	music.Parent = SoundService
	music:Play()
	Effects.Music = music
end

return Effects
