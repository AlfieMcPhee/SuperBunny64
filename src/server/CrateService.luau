--[[
	CrateService - breakable heart crates.

	Roll, slide, long jump or ground pound into a crate (or stomp on it) and
	it bursts, giving the bunny who broke it a heart. Crates come back after a
	while, so they're placed before the hard parts as a little mercy.
	Ore-carrot rocks (attribute Ore) break the same way but give carrot coins
	and take longer to grow back.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CrateService = {}

local RESPAWN = 45
local ORE_RESPAWN = 240
local BREAK_MOVES = { roll = true, slide = true, longjump = true, pound = true, walljump = true, dive = true }
local crates = {}
local cb

local function breakCrate(c, player)
	if not c.alive then
		return
	end
	c.alive = false
	c.respawnAt = os.clock() + (c.ore and ORE_RESPAWN or RESPAWN)
	cb.effect(c.ore and "ore" or "crate", c.part.Position)
	c.part.Parent = nil
	if player then
		if c.ore then
			if cb.ore then
				cb.ore(player, c.part.Position)
			end
		else
			cb.heal(player)
		end
	end
end

function CrateService.Start(info, callbacks)
	cb = callbacks
	for _, part in ipairs(info.crates) do
		table.insert(crates, { part = part, parent = part.Parent, alive = true, respawnAt = 0, ore = part:GetAttribute("Ore") == true })
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.08 then
			return
		end
		acc = 0
		local now = os.clock()
		for _, c in ipairs(crates) do
			if not c.alive then
				if now > c.respawnAt then
					c.alive = true
					c.part.Parent = c.parent
					cb.effect("poof", c.part.Position)
				end
				continue
			end
			local pos = c.part.Position
			for _, player in ipairs(Players:GetPlayers()) do
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root then
					local p = root.Position
					local flat = Vector3.new(p.X - pos.X, 0, p.Z - pos.Z).Magnitude
					local feet = p.Y - 2.6
					if flat < 4.6 and feet > pos.Y - 3 and feet < pos.Y + 4 then
						local move = char:GetAttribute("Move")
						local vy = root.AssemblyLinearVelocity.Y
						if (move and BREAK_MOVES[move]) or (feet > pos.Y + 1.2 and vy < -6) then
							breakCrate(c, player)
							if feet > pos.Y + 1.2 then
								cb.bounce(player, Vector3.new(0, 48, 0))
							end
							break
						end
					end
				end
			end
		end
	end)
end

-- Ground pound shockwaves smash nearby crates too
function CrateService.Shockwave(player, pos)
	for _, c in ipairs(crates) do
		if c.alive and (c.part.Position - pos).Magnitude < 10 then
			breakCrate(c, player)
		end
	end
end

return CrateService
