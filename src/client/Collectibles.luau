--[[
	Collectibles - spins the carrots, hides the ones this file already has,
	and asks the server to collect carrots the bunny touches.
	Each player has their own carrots, so pickups are client-side visuals
	backed by server validation and saving.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local player = Players.LocalPlayer
local Collectibles = {}

local items = {} -- [Model] = item
local folder
local slot = nil -- the active file's progress (nil on the title screen)
local Effects, Remotes
local combo, lastPickup = 0, 0

local reqOf = {}
for _, g in ipairs(Config.Goldens) do
	reqOf[g.id] = g.req
end

local function isLocked(id)
	if not slot then
		return true
	end
	local req = reqOf[id]
	if req == "carrots" then
		return slot.carrotCount < Config.CollectorGoal
	elseif req == "bugs" then
		return slot.bugs < Config.BugBusterGoal
	elseif req == "boss" then
		return not slot.bossDefeated
	end
	return false
end

local function shouldShow(item)
	if not slot then
		return true -- the title screen shows the world as it is
	end
	if item.kind == "golden" then
		if slot.goldens[item.id] or isLocked(item.id) then
			return false
		end
	elseif slot.carrots[item.id] then
		return false
	end
	return os.clock() - item.pendingAt >= 2
end

local function apply(model, item)
	local show = shouldShow(item)
	if show and model.Parent ~= folder then
		model.Parent = folder
	elseif not show and model.Parent ~= nil then
		model.Parent = nil
	end
end

local function register(model)
	if not model:IsA("Model") or items[model] then
		return
	end
	local id = model:GetAttribute("CollectId")
	if not id then
		return
	end
	local item = {
		id = id,
		kind = model:GetAttribute("Kind") or "carrot",
		pivot = model:GetPivot(),
		phase = math.random() * 6,
		pendingAt = -10,
	}
	items[model] = item
	apply(model, item)
end

-- Where every golden carrot is (for the map)
function Collectibles.GoldenPositions()
	local out = {}
	for _, item in pairs(items) do
		if item.kind == "golden" then
			out[item.id] = item.pivot.Position
		end
	end
	return out
end

function Collectibles.Sync(slotSnap)
	slot = slotSnap
	if not folder then
		return
	end
	for model, item in pairs(items) do
		apply(model, item)
	end
end

function Collectibles.Init(effects, remotes)
	Effects, Remotes = effects, remotes
	folder = workspace:WaitForChild("Bunny64World"):WaitForChild("Collectibles")
	for _, child in ipairs(folder:GetChildren()) do
		register(child)
	end
	folder.ChildAdded:Connect(register)

	local nextResync = 0
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		if t > nextResync then
			nextResync = t + 1
			Collectibles.Sync(slot)
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local alive = root and hum and hum.Health > 0 and slot ~= nil
		for model, item in pairs(items) do
			if model.Parent == folder then
				local golden = item.kind == "golden"
				local bob = math.sin(t * 2.5 + item.phase) * (golden and 0.8 or 0.4)
				model:PivotTo(item.pivot * CFrame.new(0, bob, 0) * CFrame.Angles(0, t * (golden and 1.2 or 2.2) + item.phase, 0))
				if alive then
					local reach = golden and 7 or 5.5
					if (root.Position - item.pivot.Position).Magnitude < reach then
						item.pendingAt = t
						model.Parent = nil
						Remotes.Collect:FireServer(item.id)
						if golden then
							Effects.Burst(item.pivot.Position, Config.Palette.Gold, 24, 12, 0.9, 10)
						else
							combo = (t - lastPickup < 1.5) and math.min(combo + 1, 10) or 0
							lastPickup = t
							Effects.Play("Carrot", 1 + combo * 0.06)
							Effects.Burst(item.pivot.Position, Config.Palette.Carrot, 7, 5, 0.5, 4)
						end
					end
				end
			end
		end
	end)
end

return Collectibles
