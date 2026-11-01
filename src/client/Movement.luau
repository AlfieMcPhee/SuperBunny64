--[[
	Movement - the bunny's extra moves on top of Roblox's humanoid:
	  * Double jump (press jump again in the air)
	  * Ground pound (E / Ctrl / B button / on-screen button while airborne)
	  * Springy mushrooms
	  * Knockback, stomp bounces and water resets sent by the server
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local player = Players.LocalPlayer
local HST = Enum.HumanoidStateType

local Movement = {}

local Effects
local Remotes
local enabled = false
local controls = nil

local character, humanoid, root
local usedDouble = false
local lastGrounded = 0
local lastJumpRequest = 0
local pounding = false
local poundStart = 0
local lastBounce = 0

local function inAir()
	if not humanoid then
		return false
	end
	local s = humanoid:GetState()
	return s == HST.Freefall or s == HST.Jumping
end

local function launch(velocity, kind)
	if not root then
		return
	end
	pounding = false
	usedDouble = false
	root.AssemblyLinearVelocity = velocity
	if humanoid and velocity.Y > 0 then
		humanoid:ChangeState(HST.Freefall)
	end
	if kind == "stomp" then
		Effects.Play("Stomp", 1.3)
	elseif kind == "hurt" then
		Effects.Play("Hurt", 0.8)
		Effects.Shake(0.8, 0.3)
	end
end

local function tryDoubleJump()
	if not enabled or not root or pounding or usedDouble then
		return
	end
	if not inAir() or os.clock() - lastGrounded < 0.15 then
		return
	end
	usedDouble = true
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, Config.DoubleJumpPower, v.Z)
	Effects.Play("DoubleJump", 1.1)
	Effects.Burst(root.Position - Vector3.new(0, 2.5, 0), Config.Palette.Cream, 6, 4, 0.5, -1)
end

local function startPound()
	if not enabled or not root or pounding or not inAir() or os.clock() - lastGrounded < 0.1 then
		return
	end
	pounding = true
	poundStart = os.clock()
	Remotes.Pound:FireServer("start")
	Effects.Play("Pound", 1.4)
end

local function landPound()
	pounding = false
	local pos = root.Position - Vector3.new(0, 3, 0)
	Remotes.Pound:FireServer("land", pos)
	Effects.Shake(1.2, 0.3)
	Effects.Play("Land", 0.8)
end

local function onBounceTouch(part, hit)
	if not character or not hit:IsDescendantOf(character) then
		return
	end
	local now = os.clock()
	if now - lastBounce < 0.4 then
		return
	end
	lastBounce = now
	local power = part:GetAttribute("Bounce") or Config.MushroomBounce
	if pounding then
		power *= 1.15
	end
	local v = root.AssemblyLinearVelocity
	launch(Vector3.new(v.X, power, v.Z), "bounce")
	Effects.Play("Boing", 0.7)
	Effects.Burst(part.Position + Vector3.new(0, part.Size.Y / 2, 0), part.Color, 10, 8, 0.7, 3)
end

local function watchBouncers()
	local worldFolder = workspace:WaitForChild("Bunny64World")
	local function hook(d)
		if d:IsA("BasePart") and d:GetAttribute("Bounce") then
			d.Touched:Connect(function(hit)
				onBounceTouch(d, hit)
			end)
		end
	end
	for _, d in ipairs(worldFolder:GetDescendants()) do
		hook(d)
	end
	worldFolder.DescendantAdded:Connect(hook)
end

local function onCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	root = char:WaitForChild("HumanoidRootPart")
	usedDouble = false
	pounding = false
	humanoid.StateChanged:Connect(function(_, new)
		if new == HST.Landed or new == HST.Running then
			usedDouble = false
			lastGrounded = os.clock()
		elseif new == HST.Jumping then
			lastGrounded = os.clock()
			Effects.Play("Jump", 1 + math.random() * 0.1)
		end
	end)
end

function Movement.SetEnabled(on)
	enabled = on
	if controls then
		if on then
			controls:Enable()
		else
			controls:Disable()
		end
	end
end

function Movement.Init(effects, remotes)
	Effects = effects
	Remotes = remotes

	task.spawn(function()
		local ok, module = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
		end)
		if ok and module then
			controls = module:GetControls()
			if not enabled then
				controls:Disable()
			end
		end
	end)

	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)

	UserInputService.JumpRequest:Connect(function()
		local now = os.clock()
		local fresh = now - lastJumpRequest > 0.2
		lastJumpRequest = now
		if fresh then
			tryDoubleJump()
		end
	end)

	ContextActionService:BindAction("Bunny64Pound", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			startPound()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.E, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("Bunny64Pound", "POUND")
	ContextActionService:SetPosition("Bunny64Pound", UDim2.new(1, -170, 1, -90))

	remotes.Bounce.OnClientEvent:Connect(function(vel, keepHorizontal, kind)
		if not root then
			return
		end
		if kind == "reset" then
			pounding = false
			root.AssemblyLinearVelocity = Vector3.zero
			return
		end
		local v = root.AssemblyLinearVelocity
		if keepHorizontal then
			vel = Vector3.new(v.X, vel.Y, v.Z)
		end
		launch(vel, kind)
	end)

	RunService.Heartbeat:Connect(function()
		if not root or not humanoid then
			return
		end
		local now = os.clock()
		if humanoid.FloorMaterial ~= Enum.Material.Air then
			lastGrounded = now
		end
		if pounding then
			local t = now - poundStart
			if t < Config.PoundHang then
				root.AssemblyLinearVelocity = Vector3.zero
			else
				root.AssemblyLinearVelocity = Vector3.new(0, -Config.PoundSpeed, 0)
				if humanoid.FloorMaterial ~= Enum.Material.Air then
					landPound()
				elseif t > 4 then
					pounding = false
				end
			end
		end
	end)

	task.spawn(watchBouncers)
end

function Movement.IsPounding()
	return pounding
end

return Movement
