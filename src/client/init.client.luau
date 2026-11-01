--[[
	Bunny 64 - client entry point.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = Shared:WaitForChild("Remotes")

local Effects = require(script:WaitForChild("Effects"))
local Hud = require(script:WaitForChild("Hud"))
local Movement = require(script:WaitForChild("Movement"))
local Collectibles = require(script:WaitForChild("Collectibles"))

local player = Players.LocalPlayer

-- Hearts replace the default health bar
task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)
		if ok then
			break
		end
		task.wait(0.5)
	end
end)

player.CameraMaxZoomDistance = 60
player.CameraMinZoomDistance = 10
workspace.CurrentCamera.FieldOfView = 65

local remotes = {
	Collect = Remotes:WaitForChild("Collect"),
	Update = Remotes:WaitForChild("Update"),
	Pound = Remotes:WaitForChild("Pound"),
	Bounce = Remotes:WaitForChild("Bounce"),
	Effect = Remotes:WaitForChild("Effect"),
	GetProfile = Remotes:WaitForChild("GetProfile"),
}

Hud.Init()
Movement.Init(Effects, remotes)
task.spawn(Collectibles.Init, Effects, remotes)

local goldenNames = {}
for _, g in ipairs(Config.Goldens) do
	goldenNames[g.id] = g.name
end

local function handleEvent(snap, event)
	if not event then
		return
	end
	if event.kind == "carrot" then
		if event.heal then
			Hud.Toast("+1 HEART", 1.5, Color3.fromRGB(214, 120, 116))
		end
	elseif event.kind == "unlock" then
		Effects.Jingle()
		local what = event.id == "collector" and (Config.CollectorGoal .. " CARROTS!") or (Config.BugBusterGoal .. " BUGS BOPPED!")
		Hud.Toast(what .. "\nA GOLDEN CARROT APPEARED AT THE START", 4, Config.Palette.Gold)
	elseif event.kind == "golden" then
		Effects.Jingle()
		Effects.Shake(0.5, 0.3)
		Hud.Toast(string.upper(goldenNames[event.id] or "GOLDEN CARROT") .. string.format("\nGOLDEN CARROT %d/%d", snap.goldenCount, #Config.Goldens), 3.5, Config.Palette.Gold)
	elseif event.kind == "complete" then
		Effects.Jingle()
		task.delay(0.6, Effects.Jingle)
		Hud.Toast("YOU FOUND THEM ALL!", 3, Config.Palette.Gold)
		task.delay(2, Hud.ShowEnding, snap)
	elseif event.kind == "bop" then
		Hud.Toast("BOP!", 0.8)
	end
end

remotes.Update.OnClientEvent:Connect(function(snap)
	Hud.SetProfile(snap)
	Collectibles.Sync(snap)
	handleEvent(snap, snap.event)
end)

remotes.Effect.OnClientEvent:Connect(function(kind, pos)
	if kind == "poof" then
		Effects.Burst(pos, Config.Palette.Cream, 12, 7, 0.8, 5)
	elseif kind == "pound" then
		Effects.Ring(pos, Config.Palette.Path, 13)
	elseif kind == "splash" then
		Effects.Burst(pos, Color3.fromRGB(150, 182, 186), 16, 6, 0.7, 9)
		Effects.Play("Splash")
	end
end)

-- Hearts follow the humanoid's health
local function watchHealth(character)
	local humanoid = character:WaitForChild("Humanoid")
	local last = humanoid.Health
	Hud.SetHearts(humanoid.Health, humanoid.MaxHealth)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		Hud.SetHearts(humanoid.Health, humanoid.MaxHealth)
	end)
	humanoid.HealthChanged:Connect(function(h)
		Hud.SetHearts(h, humanoid.MaxHealth)
		if h <= 0 and last > 0 then
			Hud.Toast("OUCH! BACK TO THE MEADOW...", 3)
		end
		last = h
	end)
end
if player.Character then
	task.spawn(watchHealth, player.Character)
end
player.CharacterAdded:Connect(watchHealth)

-- Load progress, then show the title screen
local profile = nil
pcall(function()
	profile = remotes.GetProfile:InvokeServer()
end)
if profile then
	Hud.SetProfile(profile)
	Collectibles.Sync(profile)
end

Hud.ShowTitle(profile, function()
	Effects.Play("Start", 1.2)
	Movement.SetEnabled(true)
	if profile and profile.completedTime == nil and profile.goldenCount == 0 then
		Hud.Toast("FIND THE 7 GOLDEN CARROTS", 3.5, Config.Palette.Gold)
	end
end)
