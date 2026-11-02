--[[
	WorldBuilder - builds the whole world at server start.

	  Carrot Meadow (hub)      centre            World/Meadow
	  Frostbite Peaks          north (z -720)    World/Peaks
	  Dustbowl Canyon          east  (x 720)     World/Canyon
	  Infernal Castle          south (z 800)     World/Castle
	  Whisperwood              west  (x -780)    World/Forest
	  Cloudtop Heights         sky   (y 420)     World/Sky
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local folder = script.Parent:WaitForChild("World")
local B = require(folder:WaitForChild("Builder"))
local Meadow = require(folder:WaitForChild("Meadow"))
local Peaks = require(folder:WaitForChild("Peaks"))
local Canyon = require(folder:WaitForChild("Canyon"))
local Castle = require(folder:WaitForChild("Castle"))
local Forest = require(folder:WaitForChild("Forest"))
local Sky = require(folder:WaitForChild("Sky"))

local WorldBuilder = {}
WorldBuilder.Castle = Castle

local function setupLighting()
	local Lighting = game:GetService("Lighting")
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Atmosphere") or child:IsA("Sky") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end
	Lighting.ClockTime = 16.3
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(120, 114, 106)
	Lighting.OutdoorAmbient = Color3.fromRGB(132, 124, 112)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 232, 196)
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 0.2
	Lighting.EnvironmentSpecularScale = 0
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.6
	Lighting.FogColor = Color3.fromRGB(176, 182, 172)
	Lighting.FogStart = 160
	Lighting.FogEnd = 900

	local sky = Instance.new("Sky")
	sky.CelestialBodiesShown = true
	sky.SunAngularSize = 14
	sky.StarCount = 0
	sky.Parent = Lighting

	-- Named so the client can retint them per region
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Bunny64Grade"
	cc.Saturation = -0.18
	cc.Contrast = 0.06
	cc.Brightness = -0.02
	cc.TintColor = Color3.fromRGB(255, 244, 228)
	cc.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "Bunny64Bloom"
	bloom.Intensity = 0.2
	bloom.Size = 22
	bloom.Threshold = 1.4
	bloom.Parent = Lighting
end

local function buildSea()
	local P = Config.Palette
	for _, off in ipairs({ Vector3.new(-1000, 0, -1000), Vector3.new(1000, 0, -1000), Vector3.new(-1000, 0, 1000), Vector3.new(1000, 0, 1000) }) do
		B.make("Part", {
			Name = "Water",
			Size = Vector3.new(2000, 1, 2000),
			CFrame = CFrame.new(off.X, Config.WaterLevel - 0.5, off.Z),
			Color = P.Water,
			Material = Enum.Material.Glass,
			Transparency = 0.15,
			Reflectance = 0.05,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		}, B.decor)
		B.block(CFrame.new(off.X, Config.WaterLevel - 40, off.Z), Vector3.new(2000, 2, 2000), Color3.fromRGB(40, 66, 70), nil, B.decor)
	end
end

function WorldBuilder.Build()
	local old = workspace:FindFirstChild("Baseplate")
	if old then
		old:Destroy()
	end
	workspace.Gravity = Config.Gravity

	local root = Instance.new("Folder")
	root.Name = "Bunny64World"
	B.Init(root)
	workspace.Terrain:Clear()
	-- in the workspace while building, so ground checks see platforms too
	root.Parent = workspace

	setupLighting()
	buildSea()
	-- each region builds in protected mode: one mistake can't wipe out the world
	for _, region in ipairs({ { "Meadow", Meadow }, { "Peaks", Peaks }, { "Canyon", Canyon }, { "Castle", Castle }, { "Forest", Forest }, { "Sky", Sky } }) do
		local ok, err = pcall(region[2].Build, B)
		if not ok then
			warn("[Bunny64] Building " .. region[1] .. " failed: " .. tostring(err))
		end
	end

	-- silver carrot hunts and time trials (data lives in Config)
	local ok, err = pcall(function()
		for setId, set in pairs(Config.SilverSets) do
			for i, spot in ipairs(set.spots) do
				B.silver(setId, i, spot)
			end
			B.golden(setId, set.reward)
		end
		for id, trial in pairs(Config.Trials) do
			B.trialPad(id, trial)
			B.golden(id, trial.reward)
		end
	end)
	if not ok then
		warn("[Bunny64] Building silver hunts / trials failed: " .. tostring(err))
	end

	B.Finish()

	local info = B.info
	info.arenaCenter = Castle.ArenaCenter
	info.arenaRadius = Castle.ArenaRadius
	return info
end

return WorldBuilder
