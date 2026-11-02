--[[
	ShopService - the carrot-coin shop and the (optional) Robux purchases.

	  Carrot coins   earned by playing (carrots, silvers, golden carrots, bosses,
	                 ore carrots) and spent on looks in Pause > SHOP. Coins never
	                 buy power: everything in the shop is cosmetic.
	  Game passes    Config.GamePasses (e.g. the Supporter Pack). Ownership is
	                 checked on join and after a purchase, and mirrored as the
	                 player attribute "Pass_<key>" so DataService.Progress sees it.
	  Products       Config.Products (a bag of coins). Receipts are recorded in
	                 the save so a purchase is never granted twice.

	With ids left at 0 (see PUBLISHING.md) the Robux items just show as
	"COMING SOON" and nothing can be bought with Robux.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local ShopService = {}

local ctx
local LISTS = { Hats = true, Necks = true, FurColors = true, AccentColors = true, Trails = true }

local function passKeyFor(id)
	for key, pass in pairs(Config.GamePasses) do
		if pass.id == id then
			return key, pass
		end
	end
	return nil
end

local function checkPasses(player)
	local changed = false
	for key, pass in pairs(Config.GamePasses) do
		if type(pass.id) == "number" and pass.id > 0 and not player:GetAttribute("Pass_" .. key) then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and owns then
				player:SetAttribute("Pass_" .. key, true)
				changed = true
			end
		end
	end
	if changed then
		ctx.push(player, nil)
	end
end

local function findItem(listName, id)
	local list = LISTS[listName] and Config[listName]
	if not list then
		return nil
	end
	for _, e in ipairs(list) do
		if (e.id or e.name) == id then
			return e
		end
	end
	return nil
end

function ShopService.Start(_info, context)
	ctx = context
	local DataService = ctx.DataService

	-- buy something with carrot coins
	ctx.BuyRemote.OnServerInvoke = function(player, listName, id)
		if type(listName) ~= "string" or type(id) ~= "string" then
			return false, "?"
		end
		local item = findItem(listName, id)
		local profile = DataService.Get(player)
		if not item or not item.price or not profile then
			return false, "NOT FOR SALE"
		end
		profile.data.owned = profile.data.owned or {}
		local key = item.id or item.name
		if profile.data.owned[key] then
			return true, "ALREADY YOURS"
		end
		if not DataService.SpendCoins(player, item.price) then
			return false, "NOT ENOUGH COINS"
		end
		profile.data.owned[key] = true
		ctx.push(player, { kind = "purchase", what = item.name })
		task.spawn(DataService.Save, player, false)
		return true, "BOUGHT!"
	end

	-- game passes
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			local key, pass = passKeyFor(passId)
			if key then
				player:SetAttribute("Pass_" .. key, true)
				ctx.push(player, { kind = "purchase", what = pass.name })
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(checkPasses, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(checkPasses, player)
	end

	-- developer products (coins): grant once per receipt, after the save has it
	MarketplaceService.ProcessReceipt = function(receipt)
		local product
		for _, p in pairs(Config.Products) do
			if p.id == receipt.ProductId then
				product = p
			end
		end
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local profile = player and DataService.Get(player)
		if not product or not player or not profile or not profile.loaded then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		profile.data.receipts = profile.data.receipts or {}
		if profile.data.receipts[receipt.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		profile.data.coins = (profile.data.coins or 0) + (product.coins or 0)
		profile.data.receipts[receipt.PurchaseId] = os.time()
		-- keep the receipt list from growing forever
		local n = 0
		for _ in pairs(profile.data.receipts) do
			n += 1
		end
		if n > 60 then
			local oldestKey, oldest = nil, math.huge
			for k, t in pairs(profile.data.receipts) do
				if t < oldest then
					oldestKey, oldest = k, t
				end
			end
			profile.data.receipts[oldestKey] = nil
		end
		DataService.Save(player, false)
		ctx.push(player, { kind = "purchase", what = product.name })
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return ShopService
