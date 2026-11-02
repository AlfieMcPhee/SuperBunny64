--[[
	Bunny 64 - client entry point. Wires together menus, HUD, movement,
	animation, collectibles and world effects, and reacts to server events.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = Shared:WaitForChild("Remotes")

local Effects = require(script:WaitForChild("Effects"))
local Hud = require(script:WaitForChild("Hud"))
local Menus = require(script:WaitForChild("Menus"))
local Movement = require(script:WaitForChild("Movement"))
local Animator = require(script:WaitForChild("Animator"))
local Collectibles = require(script:WaitForChild("Collectibles"))
local WorldFX = require(script:WaitForChild("WorldFX"))
local AdminPanel = require(script:WaitForChild("AdminPanel"))
local Shadows = require(script:WaitForChild("Shadows"))
local Dialogue = require(script:WaitForChild("Dialogue"))
local PhotoMode = require(script:WaitForChild("PhotoMode"))
local Weather = require(script:WaitForChild("Weather"))

local player = Players.LocalPlayer

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

player.CameraMaxZoomDistance = 70
player.CameraMinZoomDistance = 12
workspace.CurrentCamera.FieldOfView = 65

local remotes = {}
for _, name in ipairs({
	"GetProfile", "SelectSlot", "EraseSlot", "Customise", "QuitToTitle", "SetOptions", "Collect",
	"Update", "Pound", "Bounce", "Effect", "SetMove", "WarpMenu", "Warp", "TipSeen", "Talked",
}) do
	remotes[name] = Remotes:WaitForChild(name)
end
-- optional extras: if a server system is switched off, the game still runs without them
for _, name in ipairs({ "AdminCommand", "AdminNotice" }) do
	remotes[name] = Remotes:WaitForChild(name, 10)
end

local goldenNames, checkpointNames, warpNames = {}, {}, {}
for _, g in ipairs(Config.Goldens) do
	goldenNames[g.id] = g.name
end
for id, c in pairs(Config.Checkpoints) do
	checkpointNames[id] = c.name
end
for _, w in ipairs(Config.Warps) do
	warpNames[w.id] = w.name
end

local snap = nil
local GOLD = Config.Palette.Gold

local function applySnapshot(s)
	snap = s
	Menus.SetSnapshot(s)
	Effects.SetOptions(s.menu.options)
	AdminPanel.SetAdmin(s.isAdmin)
	Collectibles.Sync(s.slot)
	if s.slot then
		Hud.SetProgress(s.slot, s.canSave)
		WorldFX.SetGoldenCount(s.slot.goldenCount)
		WorldFX.SetCheckpoint(s.slot.checkpoint)
		WorldFX.SetSlot(s.slot)
	else
		WorldFX.SetGoldenCount(0)
	end
end

local function handleEvent(s, event)
	if not event or not s.slot then
		return
	end
	local kind = event.kind
	if kind == "carrot" then
		if event.heal then
			Hud.Toast("+1 HEART", 1.5, Color3.fromRGB(240, 140, 140))
		end
	elseif kind == "unlock" then
		Effects.Jingle()
		local what = event.id == "collector" and (Config.CollectorGoal .. " CARROTS!") or (Config.BugBusterGoal .. " BADDIES BOPPED!")
		Hud.Toast(what .. "\nA GOLDEN CARROT APPEARED AT THE MEADOW SPAWN", 4, GOLD)
	elseif kind == "golden" then
		Effects.Jingle()
		Effects.Shake(0.5, 0.3)
		local text = string.upper(goldenNames[event.id] or "GOLDEN CARROT") .. string.format("\nGOLDEN CARROT %d / %d", s.slot.goldenCount, #Config.Goldens)
		if event.unlocked then
			text ..= "\nNEW LOOK UNLOCKED: " .. event.unlocked
		end
		Hud.Toast(text, 4, GOLD)
		-- the "golden carrot get!" moment: a little cheer before you carry on
		if Menus.Screen() == nil then
			Movement.Celebrate(1.6)
		end
		if s.slot.goldenCount == Config.CastleGate then
			task.delay(4.2, function()
				Hud.Toast("THE CASTLE GATE HAS OPENED...", 3.5, Color3.fromRGB(240, 150, 110))
			end)
		end
	elseif kind == "complete" then
		Effects.Jingle()
		task.delay(0.6, Effects.Jingle)
		Hud.Toast("YOU FOUND THEM ALL!", 3, GOLD)
		task.delay(2.5, function()
			Menus.ShowEnding(snap)
		end)
	elseif kind == "bop" then
		Hud.Toast("BOP!", 0.7)
	elseif kind == "checkpoint" then
		Hud.Toast("CHECKPOINT: " .. string.upper(checkpointNames[event.id] or ""), 2)
	elseif kind == "warpfound" then
		Effects.Play("MenuSelect", 1.4)
		Hud.Toast("BURROW WARP FOUND:\n" .. (warpNames[event.id] or ""), 2.5, GOLD)
	elseif kind == "silver" then
		if event.got >= event.total then
			Effects.Jingle()
			Hud.Toast(string.format("SILVER CARROT %d/%d\nALL FIVE! A GOLDEN CARROT HAS APPEARED...", event.got, event.total), 4, GOLD)
		else
			Hud.Toast(string.format("SILVER CARROT %d/%d", event.got, event.total), 2, Color3.fromRGB(210, 224, 245))
		end
	elseif kind == "trialstart" then
		local trial = Config.Trials[event.id]
		Effects.Play("MenuSelect", 1.5)
		Hud.Toast(trial and (trial.name .. "!\nGO GO GO!") or "GO!", 1.5, Color3.fromRGB(150, 210, 255))
		Hud.StartTimer(event.time, trial and trial.name or "")
	elseif kind == "trialfail" then
		Hud.StopTimer()
		Effects.Play("Hurt", 0.7)
		Hud.Toast("TIME'S UP!\nSTEP ON THE PAD TO TRY AGAIN", 3, Color3.fromRGB(240, 140, 120))
	elseif kind == "trialwin" then
		Hud.StopTimer()
		Effects.Jingle()
		local msg = string.format("TRIAL CLEAR!  %.1f s", event.time or 0)
		if event.first then
			msg ..= "\nA GOLDEN CARROT HAS APPEARED AT THE FINISH!"
		end
		Hud.Toast(msg, 4, GOLD)
	elseif kind == "stamp" then
		local name = event.id
		for _, st in ipairs(Config.Stamps) do
			if st.id == event.id then
				name = st.name
			end
		end
		-- wait for any golden-carrot toast to finish first
		task.delay(3.8, function()
			Effects.Jingle()
			Hud.Toast("STAMP GET!\n" .. name, 3, Color3.fromRGB(150, 210, 255))
		end)
	elseif kind == "bossdown" then
		Effects.Jingle()
		task.delay(0.5, Effects.Jingle)
		Hud.Toast("KING GRUMBLE IS DEFEATED!\nTHE CROWN IS YOURS...", 5, GOLD)
	end
end

remotes.Update.OnClientEvent:Connect(function(s)
	applySnapshot(s)
	handleEvent(s, s.event)
end)

remotes.WarpMenu.OnClientEvent:Connect(function(list)
	Menus.ShowWarp(list)
end)

remotes.Effect.OnClientEvent:Connect(function(kind, pos, extra)
	local P = Config.Palette
	if kind == "poof" then
		Effects.Burst(pos, Color3.fromRGB(226, 218, 200), 12, 7, 0.8, 5)
	elseif kind == "spores" then
		Effects.Ring(pos - Vector3.new(0, 1.5, 0), Color3.fromRGB(176, 196, 120), 8.5, 20, 0.6)
		Effects.Burst(pos + Vector3.new(0, 1, 0), Color3.fromRGB(196, 210, 140), 12, 6, 0.9, 3)
	elseif kind == "screech" then
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - pos).Magnitude < 60 then
			Effects.Play("Screech", 1.6)
		end
	elseif kind == "pound" then
		Effects.Ring(pos, P.Path, 13)
	elseif kind == "splash" then
		Effects.Burst(pos, Color3.fromRGB(150, 182, 186), 16, 6, 0.7, 9)
		Effects.Play("Splash")
	elseif kind == "burn" then
		Effects.Burst(pos, P.Ember, 14, 5, 0.7, 10, Enum.Material.Neon)
	elseif kind == "fire" then
		Effects.Burst(pos, P.Ember, 6, 3, 0.6, 2, Enum.Material.Neon)
	elseif kind == "shockwave" then
		Effects.Shockwave(pos, extra or 44, 64)
		Effects.Shake(1, 0.4)
		Effects.Play("Land", 0.5)
	elseif kind == "bossroar" then
		Effects.Play("Boss", 0.6)
		Effects.Shake(1.5, 1.5)
		-- the boss's title card, the way old games introduced them
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - pos).Magnitude < 120 then
			Hud.RegionBanner("KING GRUMBLE")
			task.delay(0.6, function()
				Hud.Toast("TYRANT OF THE INFERNAL CASTLE", 2.2, Color3.fromRGB(240, 150, 110))
			end)
		end
	elseif kind == "bosscharge" then
		Effects.Play("Roll", 0.5)
	elseif kind == "bossbonk" then
		Effects.Play("Land", 0.4)
		Effects.Shake(1.4, 0.5)
		Effects.Burst(pos, Color3.fromRGB(255, 236, 160), 10, 6, 0.8, 6, Enum.Material.Neon)
		Hud.Toast("HE'S DIZZY! JUMP ON A GLOWING SPOT!", 2.5, GOLD)
	elseif kind == "bosshit" then
		Effects.Play("Stomp", 0.7)
		Effects.Shake(1.2, 0.4)
		Effects.Burst(pos, Color3.fromRGB(240, 170, 70), 24, 12, 1, 10, Enum.Material.Neon)
	elseif kind == "bossdie" then
		Effects.Play("Boss", 0.4)
		Effects.Shake(2, 2.4)
	elseif kind == "warp" then
		Hud.IrisBlink(0.2, 0.15, 0.5)
		Effects.Play("Boing", 1.2)
		Effects.Burst(pos, Config.Palette.Dirt, 14, 6, 0.7, 6)
	elseif kind == "saved" then
		Hud.ShowSaved()
	elseif kind == "trialstop" then
		Hud.StopTimer()
	elseif kind == "crate" then
		Effects.Play("Crate", 1.3)
		Effects.Burst(pos, Config.Palette.WoodLight, 14, 7, 0.8, 7)
	elseif kind == "heart" then
		Effects.Play("Heart", 1.6)
		Hud.Toast("+1 HEART", 1.2, Color3.fromRGB(240, 140, 140))
	elseif kind == "locked" then
		Hud.Toast(string.format("YOU NEED %d GOLDEN CARROTS\nTO FACE THE KING", pos), 3, Color3.fromRGB(240, 150, 110))
	end
end)

-- Hearts follow the humanoid
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
			Hud.Toast("OUCH! BACK TO THE LAST CHECKPOINT...", 3)
			task.delay(1.2, function()
				Hud.IrisClose(0.9)
			end)
		end
		last = h
	end)
end
if player.Character then
	task.spawn(watchHealth, player.Character)
end
player.CharacterAdded:Connect(watchHealth)

-- open the iris again whenever a fresh bunny appears (after dying, or loading a file)
player.CharacterAdded:Connect(function()
	task.delay(0.9, function()
		Hud.IrisOpen(0.8)
	end)
end)

Hud.OnLowHealthBeat(function()
	Effects.Play("Heartbeat", 0.55)
end)

-- One-off tips near the places they matter
task.spawn(function()
	local shown = {}
	while true do
		task.wait(0.5)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local tipsOn = not (snap and snap.menu.options and snap.menu.options.tips == false)
		if tipsOn and root and snap and snap.slot and Menus.Screen() == nil and not Dialogue.IsTalking() then
			local seen = snap.slot.tips or {}
			for _, tip in ipairs(Config.Tips) do
				if not seen[tip.id] and not shown[tip.id] and (root.Position - tip.pos).Magnitude < tip.radius then
					shown[tip.id] = true
					seen[tip.id] = true
					local c = Menus.CurrentControls()
					local k = Menus.PrettyKey
					local text = tip.text
					text = string.gsub(text, "{jump}", k(c.jump.key))
					text = string.gsub(text, "{roll}", k(c.roll.key))
					text = string.gsub(text, "{crouch}", k(c.crouch.key))
					text = string.gsub(text, "{menu}", k(c.menu.key))
					Hud.Tip(text)
					remotes.TipSeen:FireServer(tip.id)
					break
				end
			end
		end
	end
end)

Movement.OnLoading = function()
	Hud.Toast("LOADING THE WORLD...", 2)
end

-- Start everything -----------------------------------------------------------------
Hud.Init(function()
	Menus.TogglePause()
end)
Movement.Init(Effects, remotes)
task.spawn(Collectibles.Init, Effects, remotes)
task.spawn(Animator.Init, Movement)
task.spawn(WorldFX.Init, Effects, Hud)
Hud.WatchBoss(WorldFX.InArena)

Menus.Init({
	GoldenPositions = Collectibles.GoldenPositions,
	PhotoMode = PhotoMode,
	SetOverlaysVisible = function(on)
		AdminPanel.SetVisible(on)
	end,
	Effects = Effects,
	Remotes = remotes,
	Movement = Movement,
	Hud = Hud,
	WorldFX = WorldFX,
	onPlay = function()
		WorldFX.ResetRegion()
		AdminPanel.SetVisible(true)
		Hud.SetVisible(true)
		if snap and snap.slot then
			Hud.SetProgress(snap.slot, snap.canSave)
			if snap.slot.goldenCount == 0 and snap.slot.carrotCount == 0 then
				task.delay(1, function()
					local c = Menus.CurrentControls()
					local k = Menus.PrettyKey
					Hud.Toast(string.format("FIND THE GOLDEN CARROTS!\n%s: ROLL   %s: SLIDE / POUND   %s: MENU", k(c.roll.key), k(c.crouch.key), k(c.menu.key)), 5, GOLD)
				end)
			end
		end
	end,
	onQuit = function()
		AdminPanel.SetVisible(false)
		remotes.QuitToTitle:FireServer()
		Menus.BackToTitle()
	end,
})
AdminPanel.Init({
	Remotes = remotes,
	Movement = Movement,
	Hud = Hud,
	Effects = Effects,
	Menus = Menus,
})
Dialogue.Init({
	Remotes = remotes,
	Movement = Movement,
	Effects = Effects,
	Menus = Menus,
	GetSnapshot = function()
		return snap
	end,
})
task.spawn(Shadows.Init)
Weather.Init()
WorldFX.OnRegion = Weather.SetRegion
Effects.SetMusic("title")

task.spawn(function()
	local s = nil
	for _ = 1, 5 do
		local ok, result = pcall(function()
			return remotes.GetProfile:InvokeServer()
		end)
		if ok and result then
			s = result
			break
		end
		task.wait(2)
	end
	if s then
		applySnapshot(s)
	end
end)
