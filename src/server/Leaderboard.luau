--[[
	Leaderboard - the "FASTEST BUNNIES" board by the meadow spawn.

	When a file finds every golden carrot, its clear time is stored in an
	OrderedDataStore (keeping each player's best). The board shows the top 10
	across every server and refreshes every couple of minutes.
	Without DataStore access (e.g. Studio with API access off) the board just
	says so.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local P = Config.Palette

local Leaderboard = {}

local store
local rows = {}
local status

local function fmt(seconds)
	seconds = math.floor(seconds)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

local function build()
	local pos = Vector3.new(-34, 0, 60)
	local model = Instance.new("Model")
	model.Name = "FastestBunnies"
	local function block(cf, size, color, material)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CFrame = cf
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.Wood
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	-- the board faces the spawn (+X)
	local face = CFrame.lookAt(pos + Vector3.new(0, 7, 0), pos + Vector3.new(10, 7, 0))
	for _, dz in ipairs({ -5.5, 5.5 }) do
		block(CFrame.new(pos + Vector3.new(0, 5, dz)), Vector3.new(0.9, 10, 0.9), P.Wood)
	end
	local board = block(face * CFrame.new(0, 0.5, 0), Vector3.new(11, 9, 0.6), P.WoodLight)
	block(face * CFrame.new(0, 5.3, 0.1), Vector3.new(12, 1, 1.2), P.Roof, Enum.Material.Slate)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.Parent = board
	local function label(text, y, h, size, color, align)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, -40, 0, h)
		t.Position = UDim2.fromOffset(20, y)
		t.Font = Enum.Font.Antique
		t.Text = text
		t.TextSize = size
		t.TextColor3 = color or Color3.fromRGB(50, 34, 24)
		t.TextXAlignment = align or Enum.TextXAlignment.Center
		t.Parent = gui
		return t
	end
	label("FASTEST BUNNIES", 10, 50, 44)
	label("every golden carrot", 56, 26, 22, Color3.fromRGB(110, 76, 50))
	for i = 1, 10 do
		rows[i] = label("", 84 + (i - 1) * 25, 24, 21, nil, Enum.TextXAlignment.Left)
	end
	status = label("", 334, 22, 16, Color3.fromRGB(110, 76, 50))
	model.Parent = workspace
end

local function refresh()
	if not store then
		status.Text = "(times appear once the game is published)"
		return
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(true, 10)
	end)
	if not ok then
		status.Text = "(couldn't reach the leaderboard)"
		return
	end
	local entries = pages:GetCurrentPage()
	for i = 1, 10 do
		local e = entries[i]
		if e then
			local name = "a bunny"
			local okName, result = pcall(function()
				return Players:GetNameFromUserIdAsync(tonumber(e.key))
			end)
			if okName and result then
				name = result
			end
			rows[i].Text = string.format("%2d.  %-18s %s", i, name, fmt(e.value))
		else
			rows[i].Text = i == 1 and "    nobody yet - will it be you?" or ""
		end
	end
	status.Text = "updated " .. os.date("!%H:%M") .. " UTC"
end

function Leaderboard.Start()
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore("Bunny64_ClearTimes_v1")
	end)
	if ok then
		store = result
	end
	build()
	task.spawn(function()
		while true do
			pcall(refresh)
			task.wait(120)
		end
	end)
end

-- Keep each player's best (lowest) clear time
function Leaderboard.RecordClear(player, seconds)
	if not store or type(seconds) ~= "number" then
		return
	end
	task.spawn(function()
		pcall(function()
			store:UpdateAsync(tostring(player.UserId), function(old)
				local t = math.max(1, math.floor(seconds))
				if old and old <= t then
					return nil
				end
				return t
			end)
		end)
		task.wait(2)
		pcall(refresh)
	end)
end

return Leaderboard
