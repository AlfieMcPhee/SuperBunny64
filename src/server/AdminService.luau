--[[
	AdminService - fun admin perks for the game owner and friends.

	Who is an admin:
	  * the place owner (or the owner rank of the owning group)
	  * anyone whose UserId is in Config.Admins
	  * everyone while testing in Roblox Studio

	Every command is checked here on the server; the client panel only asks.

	  Self:    fly, god mode, speed boost, full heal
	  Travel:  teleport to any checkpoint / the throne room / another player
	  Others:  bring, freeze, launch, heal, control (they follow you, inputs locked)
	  World:   reset King Grumble, give yourself every golden carrot (testing)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local AdminService = {}

local ctx
local controlled = {} -- [targetPlayer] = { by = adminPlayer, untilTime = number }
local speedLevel = {} -- [Player] = 1..3
local Notice

function AdminService.IsAdmin(player)
	if RunService:IsStudio() then
		return true
	end
	for _, id in ipairs(Config.Admins or {}) do
		if player.UserId == id then
			return true
		end
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and rank == 255
end

local function rootOf(player)
	local char = player and player.Character
	return char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid"), char
end

local function findPlayer(userId)
	if type(userId) ~= "number" then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

local function notify(player, text)
	if player and player.Parent then
		Notice:FireClient(player, "toast", text)
	end
end

local function release(target)
	local c = controlled[target]
	controlled[target] = nil
	if c and target.Parent then
		Notice:FireClient(target, "control", false)
		notify(target, "YOU'RE FREE AGAIN!")
	end
end

local COMMANDS = {}

-- Self ---------------------------------------------------------------------------
function COMMANDS.god(admin)
	local _, _, char = rootOf(admin)
	if not char then
		return false, "No character"
	end
	local on = not char:GetAttribute("God")
	char:SetAttribute("God", on)
	return true, on and "GOD MODE ON" or "GOD MODE OFF", on
end

function COMMANDS.speed(admin)
	local _, hum = rootOf(admin)
	if not hum then
		return false, "No character"
	end
	local level = (speedLevel[admin] or 1) % 3 + 1
	speedLevel[admin] = level
	hum.WalkSpeed = Config.WalkSpeed * level
	return true, "SPEED x" .. level, level
end

function COMMANDS.heal(admin, targetId)
	local target = targetId and findPlayer(targetId) or admin
	if not target then
		return false, "Player not found"
	end
	ctx.heal(target, Config.MaxHearts)
	if target ~= admin then
		notify(target, "AN ADMIN HEALED YOU")
	end
	return true, "HEALED " .. string.upper(target.DisplayName)
end

-- the client moves the bunny while flying; the server just shows the pose to everyone
function COMMANDS.fly(admin, on)
	local _, _, char = rootOf(admin)
	if not char then
		return false, "No character"
	end
	char:SetAttribute("Move", on and "fly" or "")
	char:SetAttribute("MoveAt", workspace:GetServerTimeNow())
	return true, on and "FLYING - WASD + SPACE/SHIFT" or "FLY OFF", on == true
end

-- Travel -------------------------------------------------------------------------
function COMMANDS.tp(admin, where)
	local cf
	if where == "boss" then
		cf = ctx.checkpointCF("throne")
	elseif type(where) == "string" and Config.Checkpoints[where] then
		cf = ctx.checkpointCF(where)
	end
	if not cf then
		return false, "Unknown place"
	end
	ctx.teleport(admin, cf)
	return true, "WHOOSH!"
end

COMMANDS["goto"] = function(admin, targetId)
	local target = findPlayer(targetId)
	local troot = rootOf(target)
	if not troot then
		return false, "Player not found"
	end
	ctx.teleport(admin, troot.CFrame * CFrame.new(0, 0, 6))
	return true, "WENT TO " .. string.upper(target.DisplayName)
end

-- Other players ---------------------------------------------------------------------
function COMMANDS.bring(admin, targetId)
	local target = findPlayer(targetId)
	local aroot = rootOf(admin)
	if not target or not aroot or not rootOf(target) then
		return false, "Player not found"
	end
	ctx.teleport(target, aroot.CFrame * CFrame.new(0, 0, -6))
	notify(target, string.upper(admin.DisplayName) .. " BROUGHT YOU HERE")
	return true, "BROUGHT " .. string.upper(target.DisplayName)
end

function COMMANDS.freeze(admin, targetId)
	local target = findPlayer(targetId)
	local troot = rootOf(target)
	if not troot then
		return false, "Player not found"
	end
	troot.Anchored = not troot.Anchored
	notify(target, troot.Anchored and "BRRR! AN ADMIN FROZE YOU" or "YOU THAWED OUT")
	return true, (troot.Anchored and "FROZE " or "UNFROZE ") .. string.upper(target.DisplayName)
end

function COMMANDS.launch(admin, targetId)
	local target = findPlayer(targetId)
	if not rootOf(target) then
		return false, "Player not found"
	end
	ctx.bounce(target, Vector3.new(math.random(-20, 20), 160, math.random(-20, 20)))
	notify(target, "WHEEEE!")
	return true, "LAUNCHED " .. string.upper(target.DisplayName)
end

function COMMANDS.control(admin, targetId)
	local target = findPlayer(targetId)
	if not target or target == admin or not rootOf(target) then
		return false, "Pick someone else"
	end
	if controlled[target] then
		release(target)
		return true, "RELEASED " .. string.upper(target.DisplayName)
	end
	controlled[target] = { by = admin, untilTime = os.clock() + 20 }
	Notice:FireClient(target, "control", true)
	notify(target, string.upper(admin.DisplayName) .. " IS CONTROLLING YOU!\nFOLLOW THE LEADER...")
	return true, string.upper(target.DisplayName) .. " FOLLOWS YOU FOR 20s"
end

-- World ----------------------------------------------------------------------------
function COMMANDS.resetboss()
	ctx.BossService.Reset()
	return true, "KING GRUMBLE RESET"
end

function COMMANDS.allgoldens(admin)
	local slot = ctx.DataService.ActiveSlot(admin)
	if not slot then
		return false, "Load a file first"
	end
	for _, g in ipairs(Config.Goldens) do
		slot.goldens[g.id] = true
	end
	slot.bossDefeated = true
	ctx.push(admin, nil)
	return true, "ALL GOLDEN CARROTS GIVEN (THIS FILE)"
end

--------------------------------------------------------------------------------

function AdminService.Start(context)
	ctx = context
	local fn = Instance.new("RemoteFunction")
	fn.Name = "AdminCommand"
	fn.Parent = ctx.remotes
	Notice = Instance.new("RemoteEvent")
	Notice.Name = "AdminNotice"
	Notice.Parent = ctx.remotes

	fn.OnServerInvoke = function(player, command, arg)
		if not AdminService.IsAdmin(player) then
			return false, "Admins only"
		end
		local handler = type(command) == "string" and COMMANDS[command]
		if not handler then
			return false, "Unknown command"
		end
		local ok, a, b, c = pcall(handler, player, arg)
		if not ok then
			warn("[Bunny64] Admin command failed:", a)
			return false, "Something went wrong"
		end
		return a, b, c
	end

	-- controlled players walk toward their admin
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local now = os.clock()
		for target, c in pairs(controlled) do
			local aroot = rootOf(c.by)
			local troot, thum = rootOf(target)
			if not target.Parent or not c.by.Parent or not aroot or not thum or now > c.untilTime then
				release(target)
			else
				local behind = aroot.CFrame * CFrame.new(math.sin(now) * 3, 0, 7)
				thum:MoveTo(behind.Position)
				if (troot.Position - aroot.Position).Magnitude > 120 then
					troot.CFrame = behind
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		controlled[player] = nil
		speedLevel[player] = nil
		for target, c in pairs(controlled) do
			if c.by == player then
				release(target)
			end
		end
	end)
end

return AdminService
