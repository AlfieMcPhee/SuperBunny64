--[[
	Effects - local sounds, music, chunky block particles and camera shake.
]]

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local Effects = {}

local sfxVolume, musicVolume, shakeOn = 0.8, 0.6, true

local sfxGroup = Instance.new("SoundGroup")
sfxGroup.Name = "Bunny64SFX"
sfxGroup.Volume = sfxVolume
sfxGroup.Parent = SoundService
local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "Bunny64Music"
musicGroup.Volume = musicVolume
musicGroup.Parent = SoundService

local sounds = {}
for name, def in pairs(Config.Sounds) do
	local s = Instance.new("Sound")
	s.Name = "Bunny64_" .. name
	s.SoundId = def.id
	s.Volume = def.volume or 0.5
	s.SoundGroup = sfxGroup
	s.Parent = SoundService
	sounds[name] = s
end

function Effects.SetOptions(options)
	if type(options) ~= "table" then
		return
	end
	sfxVolume = (options.sfx or 8) / 10
	musicVolume = (options.music or 6) / 10
	shakeOn = options.shake ~= false
	sfxGroup.Volume = sfxVolume
	musicGroup.Volume = musicVolume
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

function Effects.Jingle()
	for i, speed in ipairs({ 0.8, 1.0, 1.2, 1.6 }) do
		task.delay((i - 1) * 0.12, function()
			Effects.Play("Golden", speed)
		end)
	end
end

-- Music: one looping track per area (ids in Config.Music) ----------------------
local currentTrack, currentKey = nil, nil
function Effects.SetMusic(key)
	if key == currentKey then
		return
	end
	currentKey = key
	local id = Config.Music[key] or ""
	local old = currentTrack
	if old then
		TweenService:Create(old, TweenInfo.new(1), { Volume = 0 }):Play()
		Debris:AddItem(old, 1.1)
	end
	currentTrack = nil
	if id ~= "" then
		local s = Instance.new("Sound")
		s.Name = "Bunny64Track"
		s.SoundId = id
		s.Looped = true
		s.Volume = 0
		s.SoundGroup = musicGroup
		s.Parent = SoundService
		s:Play()
		TweenService:Create(s, TweenInfo.new(1.2), { Volume = Config.MusicVolume }):Play()
		currentTrack = s
	end
end

-- Particles ----------------------------------------------------------------------
local fxFolder = Instance.new("Folder")
fxFolder.Name = "Bunny64LocalFX"
fxFolder.Parent = workspace
Effects.Folder = fxFolder

local function cube(pos, color, size, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = Vector3.one * size
	p.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
	p.Parent = fxFolder
	return p
end

function Effects.Burst(pos, color, count, speed, size, rise, material)
	count = count or 8
	speed = speed or 6
	size = size or 0.6
	rise = rise or 4
	for _ = 1, count do
		local p = cube(pos, color, size * (0.6 + math.random() * 0.8), material)
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

function Effects.Ring(pos, color, radius, count, duration)
	radius = radius or 12
	count = count or 16
	duration = duration or 0.4
	for i = 1, count do
		local a = i / count * math.pi * 2
		local p = cube(pos + Vector3.new(0, 0.5, 0), color, 1.2)
		local target = pos + Vector3.new(math.cos(a) * radius, 1.2, math.sin(a) * radius)
		TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
			CFrame = CFrame.new(target),
			Size = Vector3.one * 0.4,
			Transparency = 0.5,
		}):Play()
		Debris:AddItem(p, duration + 0.05)
	end
end

-- An expanding ring of fire that the boss's slam sends out
function Effects.Shockwave(pos, speed, maxR)
	local count = 40
	local duration = maxR / speed
	for i = 1, count do
		local a = i / count * math.pi * 2
		local p = cube(pos + Vector3.new(0, 1, 0), Config.Palette.Ember, 2.2, Enum.Material.Neon)
		local target = pos + Vector3.new(math.cos(a) * maxR, 1, math.sin(a) * maxR)
		TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = CFrame.new(target), Size = Vector3.one * 1.2 }):Play()
		Debris:AddItem(p, duration)
	end
end

-- Camera shake ------------------------------------------------------------------------
local shakeAmount, shakeUntil, shakeLen = 0, 0, 0.001
function Effects.Shake(amount, duration)
	if not shakeOn then
		return
	end
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

return Effects
