--[[
	DataService - loads and saves each player's progress with DataStoreService.

	* Session locking: a save records which server owns it, so two servers can't
	  overwrite each other if a player hops servers quickly.
	* Retries with back-off, autosave, save on leave and on server shutdown.
	* In Studio without "Enable Studio Access to API Services" the game still
	  runs; progress just isn't saved (the HUD tells the player).
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local DataService = {}

local SCHEMA_VERSION = 1
local LOCK_TIMEOUT = 600 -- seconds before a stale lock may be taken over

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[Bunny64] DataStore unavailable:", result)
	end
end

local profiles = {} -- [Player] = profile

local function defaultData()
	return {
		version = SCHEMA_VERSION,
		carrots = {}, -- [carrotId] = true
		goldens = {}, -- [goldenId] = true
		carrotCount = 0,
		bugs = 0,
		playTime = 0,
		completedTime = nil,
		firstJoin = os.time(),
	}
end

local function reconcile(data)
	if type(data) ~= "table" then
		return defaultData()
	end
	for key, value in pairs(defaultData()) do
		if data[key] == nil then
			data[key] = value
		end
	end
	-- Recount in case of older saves
	local count = 0
	for _ in pairs(data.carrots) do
		count += 1
	end
	data.carrotCount = count
	return data
end

local function shallowCopy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = v
	end
	return out
end

local function isApiDisabledError(err)
	local msg = tostring(err)
	return string.find(msg, "StudioAccessToApisNotAllowed") ~= nil
		or string.find(msg, "publish", 1, true) ~= nil
		or string.find(msg, "403", 1, true) ~= nil
end

local function keyFor(player)
	return "player_" .. player.UserId
end

-- Load ------------------------------------------------------------------------
function DataService.Load(player)
	local profile = {
		player = player,
		data = defaultData(),
		canSave = false,
		loaded = false,
		lastTick = os.clock(),
		sessionStart = os.clock(),
	}
	profiles[player] = profile

	if store then
		local attempts = 5
		for attempt = 1, attempts do
			if not player.Parent then
				return nil
			end
			local locked = false
			local ok, result = pcall(function()
				return store:UpdateAsync(keyFor(player), function(old)
					old = reconcile(old)
					local lock = old.lock
					if lock and lock.job ~= game.JobId and os.time() - (lock.time or 0) < LOCK_TIMEOUT and attempt < attempts then
						locked = true
						return nil -- cancel: another server still owns this save
					end
					old.lock = { job = game.JobId, time = os.time() }
					return old
				end)
			end)
			if ok and result then
				profile.data = reconcile(result)
				profile.canSave = true
				break
			elseif not ok then
				warn(string.format("[Bunny64] Load attempt %d for %s failed: %s", attempt, player.Name, tostring(result)))
				if isApiDisabledError(result) then
					break
				end
			end
			task.wait(locked and 3 or attempt * 1.5)
		end
	end

	profile.data.lock = nil
	profile.loaded = true
	if not profile.canSave then
		warn("[Bunny64] Progress for " .. player.Name .. " will NOT be saved this session.")
	end
	return profile
end

-- Save ------------------------------------------------------------------------
local function tickPlayTime(profile)
	local now = os.clock()
	profile.data.playTime += now - profile.lastTick
	profile.lastTick = now
end

function DataService.Save(player, release)
	local profile = profiles[player]
	if not profile or not profile.loaded then
		return false
	end
	tickPlayTime(profile)
	if not profile.canSave or not store then
		return false
	end
	local payload = shallowCopy(profile.data)
	payload.lock = (not release) and { job = game.JobId, time = os.time() } or nil

	for attempt = 1, 3 do
		local stolen = false
		local ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function(old)
				if type(old) == "table" and old.lock and old.lock.job ~= game.JobId then
					stolen = true
					return nil -- another server took over; don't clobber its data
				end
				return payload
			end)
		end)
		if ok then
			if stolen then
				warn("[Bunny64] Save skipped for " .. player.Name .. ": session owned by another server.")
				profile.canSave = false
				return false
			end
			return true
		end
		warn(string.format("[Bunny64] Save attempt %d for %s failed: %s", attempt, player.Name, tostring(err)))
		task.wait(attempt)
	end
	return false
end

function DataService.Release(player)
	DataService.Save(player, true)
	profiles[player] = nil
end

function DataService.Get(player)
	local profile = profiles[player]
	if profile and profile.loaded then
		return profile
	end
	return nil
end

function DataService.WaitFor(player, timeout)
	local start = os.clock()
	while player.Parent and os.clock() - start < (timeout or 30) do
		local profile = DataService.Get(player)
		if profile then
			return profile
		end
		task.wait(0.1)
	end
	return nil
end

function DataService.GetPlayTime(player)
	local profile = profiles[player]
	if not profile then
		return 0
	end
	return profile.data.playTime + (os.clock() - profile.lastTick)
end

-- Autosave & shutdown -----------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(Config.AutosaveSeconds)
		for player in pairs(profiles) do
			task.spawn(DataService.Save, player, false)
		end
	end
end)

game:BindToClose(function()
	if RunService:IsStudio() and not store then
		return
	end
	local pending = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if profiles[player] then
			pending += 1
			task.spawn(function()
				DataService.Save(player, true)
				pending -= 1
			end)
		end
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < 25 do
		task.wait(0.1)
	end
end)

return DataService
