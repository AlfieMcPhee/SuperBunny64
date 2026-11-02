--[[
	DataService - loads and saves each player's progress with DataStoreService.

	Save layout (one DataStore key per player):
	  {
	    version = 2,
	    slots = { ["1"] = slot, ["2"] = slot, ["3"] = slot },   -- File A / B / C
	    custom = { fur, accent, hat, neck },                     -- shared look
	    options = { sfx, music, shake },
	  }

	* Session locking so two servers can't overwrite each other.
	* Retries with back-off, autosave, save on leave and on shutdown.
	* Saves from the first version are moved into File A automatically.
	* In Studio without API access the game still runs; nothing is saved.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local DataService = {}

local SCHEMA_VERSION = 2
local LOCK_TIMEOUT = 600

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

function DataService.NewSlot()
	return {
		carrots = {},
		goldens = {},
		carrotCount = 0,
		bugs = 0,
		playTime = 0,
		completedTime = nil,
		checkpoint = "meadow",
		warps = { meadow = true },
		bossDefeated = false,
		tips = {},
		stamps = {},
		silvers = {},
		trials = {},
		stats = { crates = 0, longjumps = 0 },
		regions = {},
		friends = {},
		created = os.time(),
	}
end

local function defaultData()
	return {
		version = SCHEMA_VERSION,
		slots = {},
		custom = table.clone(Config.DefaultCustom),
		options = { sfx = 8, music = 6, shake = true, tips = true, assist = false },
	}
end

local function reconcileSlot(slot)
	if type(slot) ~= "table" then
		return nil
	end
	for k, v in pairs(DataService.NewSlot()) do
		if slot[k] == nil and k ~= "completedTime" then
			slot[k] = v
		end
	end
	local n = 0
	for _ in pairs(slot.carrots) do
		n += 1
	end
	slot.carrotCount = n
	if not Config.Checkpoints[slot.checkpoint] then
		slot.checkpoint = "meadow"
	end
	return slot
end

local function reconcile(data)
	if type(data) ~= "table" then
		return defaultData()
	end
	if data.version == nil or data.version < 2 then
		-- version 1 kept a single game at the top level: move it into File A
		local legacy = {
			carrots = data.carrots or {},
			goldens = data.goldens or {},
			bugs = data.bugs or 0,
			playTime = data.playTime or 0,
			completedTime = nil, -- the game grew; the old ending no longer counts
		}
		data = defaultData()
		if next(legacy.carrots) or next(legacy.goldens) then
			data.slots["1"] = reconcileSlot(legacy)
		end
	end
	for k, v in pairs(defaultData()) do
		if data[k] == nil then
			data[k] = v
		end
	end
	for i = 1, Config.SaveSlots do
		local key = tostring(i)
		data.slots[key] = reconcileSlot(data.slots[key])
	end
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

--------------------------------------------------------------------------------
-- Load / save
--------------------------------------------------------------------------------

function DataService.Load(player)
	local profile = {
		player = player,
		data = defaultData(),
		canSave = false,
		loaded = false,
		active = nil, -- "1" / "2" / "3" while playing a file
		lastTick = os.clock(),
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
						return nil
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

local function tickPlayTime(profile)
	local now = os.clock()
	local slot = profile.active and profile.data.slots[profile.active]
	if slot then
		slot.playTime += now - profile.lastTick
	end
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
					return nil
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
			if DataService.OnSaved and not release then
				pcall(DataService.OnSaved, player)
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

--------------------------------------------------------------------------------
-- Files (save slots)
--------------------------------------------------------------------------------

function DataService.ActiveSlot(player)
	local profile = DataService.Get(player)
	if profile and profile.active then
		return profile.data.slots[profile.active], profile
	end
	return nil, profile
end

function DataService.SelectSlot(player, index)
	local profile = DataService.Get(player)
	if not profile or type(index) ~= "number" or index < 1 or index > Config.SaveSlots or index % 1 ~= 0 then
		return nil
	end
	tickPlayTime(profile)
	local key = tostring(index)
	if not profile.data.slots[key] then
		profile.data.slots[key] = DataService.NewSlot()
	end
	profile.active = key
	profile.lastTick = os.clock()
	return profile.data.slots[key]
end

function DataService.ClearActive(player)
	local profile = DataService.Get(player)
	if profile then
		tickPlayTime(profile)
		profile.active = nil
	end
end

function DataService.EraseSlot(player, index)
	local profile = DataService.Get(player)
	if not profile or type(index) ~= "number" or index < 1 or index > Config.SaveSlots then
		return false
	end
	local key = tostring(math.floor(index))
	if profile.active == key then
		return false
	end
	profile.data.slots[key] = nil
	return true
end

function DataService.GetPlayTime(player)
	local profile = profiles[player]
	local slot = profile and profile.active and profile.data.slots[profile.active]
	if not slot then
		return 0
	end
	return slot.playTime + (os.clock() - profile.lastTick)
end

local function count(t)
	local n = 0
	for _ in pairs(t or {}) do
		n += 1
	end
	return n
end
DataService.Count = count

function DataService.Summaries(player)
	local profile = DataService.Get(player)
	local out = {}
	for i = 1, Config.SaveSlots do
		local slot = profile and profile.data.slots[tostring(i)]
		if slot then
			out[i] = {
				exists = true,
				goldens = count(slot.goldens),
				carrots = slot.carrotCount,
				playTime = (profile.active == tostring(i)) and DataService.GetPlayTime(player) or slot.playTime,
				completed = slot.completedTime ~= nil,
			}
		else
			out[i] = { exists = false, goldens = 0, carrots = 0, playTime = 0, completed = false }
		end
	end
	return out
end

-- Best progress across all files (unlocks cosmetics)
function DataService.Progress(player)
	local profile = DataService.Get(player)
	local best, boss, bosses = 0, false, {}
	if profile then
		for i = 1, Config.SaveSlots do
			local slot = profile.data.slots[tostring(i)]
			if slot then
				best = math.max(best, count(slot.goldens))
				boss = boss or slot.bossDefeated == true
				for id, v in pairs(slot.bosses or {}) do
					if v then
						bosses[id] = true
					end
				end
			end
		end
	end
	if boss then
		bosses.grumble = true
	end
	-- Robux passes are checked by ShopService and mirrored as player attributes
	local passes = {}
	for key in pairs(Config.GamePasses or {}) do
		if player:GetAttribute("Pass_" .. key) then
			passes[key] = true
		end
	end
	return {
		goldens = best, boss = boss, bosses = bosses, passes = passes,
		owned = profile and profile.data.owned or {}, coins = profile and profile.data.coins or 0,
	}
end

--------------------------------------------------------------------------------
-- Autosave & shutdown
--------------------------------------------------------------------------------

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
