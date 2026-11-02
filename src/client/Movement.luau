--[[
	Movement - the bunny's moveset on top of Roblox's humanoid.

	  Jump            Space / A / jump button
	  Double jump     jump again in the air (with a front flip)
	  Roll            Shift / Q / X / ROLL button: a quick tumble that bops bugs
	  Long jump       jump during a roll or a slide
	  Slide           Crouch (C / Ctrl / E / B / CROUCH button) while running.
	                  Ice chutes start a slide automatically; steer with the stick.
	  Ground pound    Crouch in the air
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local player = Players.LocalPlayer
local HST = Enum.HumanoidStateType
local DOWN = Vector3.new(0, -1, 0)

local Movement = {}

local Effects, Remotes
local enabled = false
local controls = nil

local character, humanoid, root, lv
local move = "" -- "", roll, longjump, slide, pound
local moveStart = 0
local moveDir = Vector3.new(0, 0, -1)
local moveSpeed = 0
local usedDouble = false
local flipAt = -10
local lastGrounded = 0
local lastJumpRequest = 0
local lastRollEnd = 0
local lastBounce = 0
local airborneSince = nil
local sentMove = nil
local flying = false -- admin fly mode (client/AdminPanel) takes over movement
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function sendMove(name)
	if name ~= sentMove then
		sentMove = name
		Remotes.SetMove:FireServer(name)
	end
end

local function setPlane(vec)
	if lv then
		lv.PlaneVelocity = Vector2.new(vec.X, vec.Z)
	end
end

local function setMove(name)
	move = name
	moveStart = os.clock()
	if lv then
		lv.Enabled = (name == "roll" or name == "longjump" or name == "slide")
	end
	if name == "" then
		sendMove(os.clock() - flipAt < 0.5 and "flip" or "")
	else
		sendMove(name)
	end
end

local function grounded()
	return humanoid and humanoid.FloorMaterial ~= Enum.Material.Air
end

local function inAir()
	if not humanoid then
		return false
	end
	local s = humanoid:GetState()
	return s == HST.Freefall or s == HST.Jumping
end

local function flatVelocity()
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z)
end

local function facingDir()
	local md = humanoid.MoveDirection
	if md.Magnitude > 0.1 then
		return Vector3.new(md.X, 0, md.Z).Unit
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
end

-- Walls push back on the velocity we command; follow what physics actually
-- did so the bunny glances along walls instead of grinding into them.
local function followActual()
	local actual = flatVelocity()
	if actual.Magnitude > 4 then
		local d = actual.Unit
		if d:Dot(moveDir) < 0.995 then
			moveDir = d
		end
		if actual.Magnitude < moveSpeed * 0.5 then
			moveSpeed = actual.Magnitude + 4
		end
	end
end

local function floorHit()
	return workspace:Raycast(root.Position, Vector3.new(0, -5, 0), rayParams)
end

--------------------------------------------------------------------------------
-- Moves
--------------------------------------------------------------------------------

local function launch(velocity, kind)
	if not root then
		return
	end
	if move ~= "" then
		setMove("")
	end
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
	elseif kind == "burn" then
		Effects.Play("Burn", 1.3)
		Effects.Shake(0.6, 0.25)
	end
end

local function startRoll()
	if flying or not enabled or not root or move ~= "" or not grounded() or os.clock() - lastRollEnd < Config.RollCooldown then
		return
	end
	moveDir = facingDir()
	moveSpeed = Config.RollSpeed
	setMove("roll")
	setPlane(moveDir * moveSpeed)
	Effects.Play("Roll", 0.9)
	Effects.Burst(root.Position - Vector3.new(0, 2.4, 0), Config.Palette.Path, 5, 3, 0.5, 1)
end

local function startLongJump(speed)
	moveSpeed = math.max(speed or 0, Config.LongJumpSpeed)
	setMove("longjump")
	usedDouble = true -- no double jump out of a long jump
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, Config.LongJumpUp, v.Z)
	setPlane(moveDir * moveSpeed)
	task.defer(function()
		-- the humanoid applies its own jump this frame; make sure our arc wins
		if root and move == "longjump" and root.AssemblyLinearVelocity.Y < Config.LongJumpUp - 5 then
			local v2 = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v2.X, Config.LongJumpUp, v2.Z)
		end
	end)
	Effects.Play("DoubleJump", 0.8)
end

local function startSlide(onChute)
	local hv = flatVelocity()
	if not onChute and hv.Magnitude < 10 then
		return
	end
	moveDir = hv.Magnitude > 1 and hv.Unit or facingDir()
	moveSpeed = math.max(hv.Magnitude, onChute and 30 or Config.SlideStartSpeed)
	setMove("slide")
	setPlane(moveDir * moveSpeed)
	Effects.Play("Roll", 0.7)
end

local function startPound()
	if not enabled or not root or move == "pound" or not inAir() or os.clock() - lastGrounded < 0.1 then
		return
	end
	setMove("pound")
	Remotes.Pound:FireServer("start")
	Effects.Play("Pound", 1.4)
end

local function landPound()
	setMove("")
	local pos = root.Position - Vector3.new(0, 2.6, 0)
	Remotes.Pound:FireServer("land", pos)
	Effects.Shake(1.2, 0.3)
	Effects.Play("Land", 0.8)
end

local function crouch()
	if flying or not enabled or not root then
		return
	end
	if move == "" or move == "longjump" then
		if inAir() and not grounded() then
			startPound()
		elseif move == "" then
			startSlide(false)
		end
	end
end

local function tryJumpMove()
	if flying or not enabled or not root then
		return
	end
	if move == "roll" or (move == "slide" and os.clock() - moveStart > 0.08) then
		startLongJump(moveSpeed + 10)
		return
	end
	if move ~= "" or usedDouble or not inAir() or os.clock() - lastGrounded < 0.15 then
		return
	end
	usedDouble = true
	flipAt = os.clock()
	sendMove("flip")
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, Config.DoubleJumpPower, v.Z)
	Effects.Play("DoubleJump", 1.1)
	Effects.Burst(root.Position - Vector3.new(0, 2.5, 0), Color3.fromRGB(230, 222, 204), 6, 4, 0.5, -1)
end

--------------------------------------------------------------------------------
-- Character setup
--------------------------------------------------------------------------------

-- The world (especially terrain) reaches each player a moment after they join.
-- Hold the bunny in place until there's ground under it, so a fresh spawn or a
-- teleport can never drop it through a world that hasn't loaded yet.
local holdToken = nil
local function holdUntilGround(minTime)
	if not root then
		return
	end
	local token = {}
	holdToken = token
	local myRoot = root
	myRoot.Anchored = true
	task.spawn(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, Effects.Folder }
		local start = os.clock()
		task.wait(minTime or 0.5) -- let the server move us to the checkpoint first
		local shown = false
		while holdToken == token and myRoot.Parent and os.clock() - start < 20 do
			local hit = workspace:Raycast(myRoot.Position + Vector3.new(0, 2, 0), Vector3.new(0, -24, 0), params)
			if hit then
				break
			end
			if not shown and os.clock() - start > 1.5 and Movement.OnLoading then
				shown = true
				Movement.OnLoading()
			end
			task.wait(0.1)
		end
		if holdToken == token and myRoot.Parent then
			myRoot.AssemblyLinearVelocity = Vector3.zero
			myRoot.Anchored = false
		end
	end)
end

local function onCharacter(char)
	character = char
	flying = false
	humanoid = char:WaitForChild("Humanoid")
	root = char:WaitForChild("HumanoidRootPart")
	move = ""
	usedDouble = false
	sentMove = nil
	rayParams.FilterDescendantsInstances = { char, Effects.Folder }

	local att = Instance.new("Attachment")
	att.Name = "MoveAttachment"
	att.Parent = root
	lv = Instance.new("LinearVelocity")
	lv.Name = "MoveVelocity"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	lv.MaxForce = 200000
	lv.Enabled = false
	lv.Parent = root
	holdUntilGround(0.5)

	humanoid.StateChanged:Connect(function(_, new)
		if new == HST.Landed or new == HST.Running then
			usedDouble = false
			lastGrounded = os.clock()
		elseif new == HST.Jumping then
			lastGrounded = os.clock()
			if move == "" then
				Effects.Play("Jump", 1 + math.random() * 0.1)
			end
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
	if not on and move ~= "" and root then
		setMove("")
	end
end

function Movement.SetFlying(on)
	flying = on
	if on and move ~= "" and root then
		setMove("")
	end
end

function Movement.GetControls()
	return controls
end

function Movement.IsEnabled()
	return enabled
end

-- For the animator: what is the local bunny doing right now?
function Movement.State()
	return {
		move = flying and "fly" or move,
		moveStart = moveStart,
		flipAt = flipAt,
		speed = moveSpeed,
	}
end

--------------------------------------------------------------------------------
-- Per-frame update
--------------------------------------------------------------------------------

-- Springy mushrooms: launch the bunny when it lands on one. (Detected with a
-- ray straight down, because the bunny's collision box hovers above the
-- ground and never actually "touches" what it stands on.)
local function bounceOff(part)
	local now = os.clock()
	if not root or now - lastBounce < 0.4 then
		return
	end
	lastBounce = now
	local power = part:GetAttribute("Bounce") or Config.MushroomBounce
	if move == "pound" then
		power *= 1.15
	end
	local v = root.AssemblyLinearVelocity
	launch(Vector3.new(v.X, power, v.Z), "bounce")
	Effects.Play("Boing", 0.7)
	Effects.Burst(part.Position + Vector3.new(0, part.Size.Y / 2, 0), part.Color, 10, 8, 0.7, 3)
end

local function step(dt)
	if not root or not humanoid or humanoid.Health <= 0 or flying then
		return
	end
	local now = os.clock()
	local onGround = grounded()
	if onGround then
		lastGrounded = now
		airborneSince = nil
	elseif not airborneSince then
		airborneSince = now
	end

	-- landed on a bounce pad?
	if root.AssemblyLinearVelocity.Y < 5 then
		local under = floorHit()
		if under and under.Instance:GetAttribute("Bounce") and root.Position.Y - under.Position.Y < 3.6 then
			bounceOff(under.Instance)
		end
	end

	if move == "" and onGround and sentMove == "flip" then
		sendMove("")
	end

	if move == "roll" or move == "longjump" or move == "slide" then
		if now - moveStart > 0.1 then
			followActual()
		end
	end

	if move == "roll" then
		local t = now - moveStart
		moveSpeed = Config.RollSpeed * (1 - 0.35 * t / Config.RollTime)
		setPlane(moveDir * moveSpeed)
		if t > Config.RollTime then
			lastRollEnd = now
			setMove("")
		end
	elseif move == "longjump" then
		local t = now - moveStart
		local md = humanoid.MoveDirection
		if md.Magnitude > 0.1 then
			local want = Vector3.new(md.X, 0, md.Z).Unit
			local blend = math.clamp(dt * 2.4, 0, 1)
			moveDir = (moveDir:Lerp(want, blend)).Unit
		end
		moveSpeed = math.max(moveSpeed - 9 * dt, 26)
		setPlane(moveDir * moveSpeed)
		if onGround and t > 0.15 then
			setMove("")
			Effects.Burst(root.Position - Vector3.new(0, 2.5, 0), Config.Palette.Path, 6, 4, 0.5, 1)
		end
	elseif move == "slide" then
		local hit = floorHit()
		if hit then
			local onChute = hit.Instance:GetAttribute("Slide") == true
			local n = hit.Normal
			local v = moveDir * moveSpeed
			-- gravity pulls you downhill
			local downhill = DOWN - n * n:Dot(DOWN)
			local flatDown = Vector3.new(downhill.X, 0, downhill.Z)
			if flatDown.Magnitude > 0.02 then
				local steep = math.sqrt(math.max(0, 1 - n.Y * n.Y))
				v += flatDown.Unit * Config.Gravity * steep * dt * 1.6
			end
			-- steering
			local md = humanoid.MoveDirection
			if md.Magnitude > 0.1 then
				v += Vector3.new(md.X, 0, md.Z) * (onChute and 50 or 28) * dt
			end
			local speed = v.Magnitude
			if onChute then
				-- chutes keep you moving forward, fast
				speed = math.clamp(speed + 22 * dt, 30, Config.ChuteSpeed)
			else
				speed = math.max(0, speed - Config.SlideFriction * dt)
			end
			if v.Magnitude > 0.01 then
				moveDir = Vector3.new(v.X, 0, v.Z).Unit
			end
			moveSpeed = speed
			setPlane(moveDir * moveSpeed)
			if not onChute and speed < 8 then
				setMove("")
			end
		elseif airborneSince and now - airborneSince > 0.12 then
			-- sailed off an edge: keep the momentum as a glide
			setMove("longjump")
			usedDouble = true
		end
	elseif move == "pound" then
		local t = now - moveStart
		if t < Config.PoundHang then
			root.AssemblyLinearVelocity = Vector3.zero
		else
			root.AssemblyLinearVelocity = Vector3.new(0, -Config.PoundSpeed, 0)
			if onGround then
				landPound()
			elseif t > 4 then
				setMove("")
			end
		end
	elseif move == "" and onGround and enabled then
		-- ice chutes grab you
		local hit = floorHit()
		if hit and hit.Instance:GetAttribute("Slide") then
			startSlide(true)
		end
	end
end

--------------------------------------------------------------------------------

local function onBounceTouch(part, hit)
	if character and hit:IsDescendantOf(character) then
		bounceOff(part)
	end
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

local function keyCode(name, fallback)
	local ok, code = pcall(function()
		return Enum.KeyCode[name]
	end)
	return (ok and code) or Enum.KeyCode[fallback]
end

-- (Re)bind the moves to the player's chosen keys. controls = { [id] = { key, pad } }
function Movement.ApplyControls(controls)
	controls = controls or {}
	local binds = {}
	for _, def in ipairs(Config.Controls) do
		local c = controls[def.id] or {}
		binds[def.id] = { keyCode(c.key or def.key, def.key), keyCode(c.pad or def.pad, def.pad) }
	end
	for _, name in ipairs({ "Bunny64Roll", "Bunny64Crouch", "Bunny64Jump" }) do
		ContextActionService:UnbindAction(name)
	end

	ContextActionService:BindAction("Bunny64Roll", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			startRoll()
		end
		return Enum.ContextActionResult.Sink
	end, true, binds.roll[1], binds.roll[2])
	ContextActionService:SetTitle("Bunny64Roll", "ROLL")
	ContextActionService:SetPosition("Bunny64Roll", UDim2.new(1, -230, 1, -110))

	ContextActionService:BindAction("Bunny64Crouch", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			crouch()
		end
		return Enum.ContextActionResult.Sink
	end, true, binds.crouch[1], binds.crouch[2])
	ContextActionService:SetTitle("Bunny64Crouch", "CROUCH")
	ContextActionService:SetPosition("Bunny64Crouch", UDim2.new(1, -170, 1, -170))

	-- Space / A always jump (Roblox handles those); a custom jump key is added on top
	local jumpKeys = {}
	if binds.jump[1] ~= Enum.KeyCode.Space then
		table.insert(jumpKeys, binds.jump[1])
	end
	if binds.jump[2] ~= Enum.KeyCode.ButtonA then
		table.insert(jumpKeys, binds.jump[2])
	end
	if #jumpKeys > 0 then
		ContextActionService:BindAction("Bunny64Jump", function(_, inputState)
			if not enabled or not humanoid then
				return Enum.ContextActionResult.Pass
			end
			if inputState == Enum.UserInputState.Begin then
				local now = os.clock()
				lastJumpRequest = now
				if grounded() then
					humanoid.Jump = true
				end
				tryJumpMove()
			end
			return Enum.ContextActionResult.Sink
		end, false, table.unpack(jumpKeys))
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
			tryJumpMove()
		end
	end)

	Movement.ApplyControls(nil)

	remotes.Bounce.OnClientEvent:Connect(function(vel, keepHorizontal, kind)
		if not root then
			return
		end
		if kind == "reset" then
			if move ~= "" then
				setMove("")
			end
			root.AssemblyLinearVelocity = Vector3.zero
			holdUntilGround(0.15) -- teleported: wait for the ground there
			return
		end
		local v = root.AssemblyLinearVelocity
		if keepHorizontal then
			vel = Vector3.new(v.X, vel.Y, v.Z)
		end
		launch(vel, kind)
	end)

	RunService.Heartbeat:Connect(step)
	task.spawn(watchBouncers)
end

return Movement
