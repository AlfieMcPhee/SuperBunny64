--[[
	Movement - the bunny's moveset on top of Roblox's humanoid.

	  Jump            Space / A / jump button
	  Double jump     jump again in the air (with a front flip)
	  Roll            Shift / Q / X / ROLL button: a quick tumble that bops bugs
	  Long jump       jump during a roll or a slide
	  Slide           Crouch (C / Ctrl / E / B / CROUCH button) while running.
	                  Ice chutes start a slide automatically; steer with the stick.
	  Ground pound    Crouch in the air
	  Pound jump      jump the moment a ground pound lands: a big spinning leap
	  Dive            Roll in the air: a forward lunge (jump during it to roll out)
	  Backflip        hold Crouch while standing still, then jump: the highest jump
	  Wall jump       jump while pressed against a wall in mid-air

	Stamina: rolls, dives and long jumps each use a pip; pips refill on the ground.

	Weight: running builds up to full speed, turning hard at speed skids, falls
	pull harder than rises, and big drops land with a short stagger.

	Game-feel helpers (the invisible stuff good platformers do):
	  coyote time     you can still jump for a moment after running off a ledge
	  jump buffer     pressing jump just before landing jumps as soon as you land
	  variable jump   let go of jump early for a short hop, hold for full height
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

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
local move = "" -- "", roll, longjump, slide, pound, dive, backflip, crouch, walljump
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
local windFolder = nil -- workspace.Bunny64World.Winds, found on first use
local inWind = false
local jumpedSinceGround = false
local jumpRising = false
local bufferUntil = 0
local lastVy = 0
local nextDust = 0
local celebrateUntil = 0
local emote, emoteStart = nil, 0 -- wave / dance / sit
local talking = false
local runSpeed = 0 -- current top speed while building up a run
local skidUntil, landAt, staggerUntil = 0, -10, 0
local lastPoundLand = -10
local divedSinceGround = false
local stamina, staminaMax = 3, 3
local staminaRegenAt = 0
local zipFolder = nil -- workspace.Bunny64World.Ziplines
local zip = nil -- { a, b, dir, len, t, speed } while riding a zipline
local zipAlign, zipOrient, zipPulley, zipSound -- the ride's constraints, pulley and whirr
local releaseZip -- (defined with the zipline code below)
local rollPower = 1 -- 0.6 for a tired roll
local zipReleasedAt = -10
local lastLaunch = 0
local COYOTE_TIME = 0.13
local BUFFER_TIME = 0.15
local DUST = Color3.fromRGB(206, 196, 176)
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
		lv.Enabled = (name == "roll" or name == "longjump" or name == "slide" or name == "walljump" or name == "dive" or name == "backflip" or name == "spring")
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
-- Stamina
--------------------------------------------------------------------------------

local function staminaChanged()
	if Movement.OnStamina then
		Movement.OnStamina(stamina, staminaMax)
	end
end

-- Try to spend stamina for a move; returns false (and puffs) when you're out
local function spend(kind)
	local cost = Config.Stamina.cost[kind] or 0
	if stamina + 0.001 < cost then
		if root then
			Effects.Burst(root.Position + Vector3.new(0, 1, 0), Color3.fromRGB(200, 210, 190), 4, 2, 0.4, 2)
		end
		if Movement.OnTired then
			Movement.OnTired()
		end
		return false
	end
	stamina -= cost
	staminaRegenAt = os.clock() + Config.Stamina.regenDelay
	staminaChanged()
	return true
end

function Movement.SetStaminaMax(n)
	if n ~= staminaMax then
		local gained = n > staminaMax
		staminaMax = n
		if gained then
			stamina = n
		end
		stamina = math.min(stamina, n)
		staminaChanged()
	end
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

local function startDive()
	if not spend("dive") then
		return
	end
	divedSinceGround = true
	usedDouble = true
	jumpRising = false
	local hv = flatVelocity()
	moveDir = facingDir()
	moveSpeed = math.max(hv.Magnitude, Config.DiveSpeed)
	setMove("dive")
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y * 0.3, Config.DiveUp), v.Z)
	setPlane(moveDir * moveSpeed)
	root.CFrame = CFrame.lookAt(root.Position, root.Position + moveDir)
	Effects.Play("DoubleJump", 0.7)
	Effects.Burst(root.Position, Color3.fromRGB(230, 222, 204), 6, 4, 0.5, 0)
end

local function startRoll()
	if flying or not enabled or not root or os.clock() < celebrateUntil then
		return
	end
	if not grounded() then
		-- in the air the roll button dives instead
		if (move == "" or move == "walljump") and inAir() and not divedSinceGround and os.clock() - lastGrounded > 0.08 then
			startDive()
		end
		return
	end
	if move ~= "" or os.clock() - lastRollEnd < Config.RollCooldown then
		return
	end
	local tired = not spend("roll")
	rollPower = tired and 0.6 or 1
	moveDir = facingDir()
	moveSpeed = Config.RollSpeed * rollPower
	setMove("roll")
	setPlane(moveDir * moveSpeed)
	Effects.Play("Roll", 0.9)
	Effects.Burst(root.Position - Vector3.new(0, 2.4, 0), Config.Palette.Path, 5, 3, 0.5, 1)
end

local function startLongJump(speed, free)
	local tired = not free and not spend("longjump")
	moveSpeed = math.max(speed or 0, Config.LongJumpSpeed)
	if tired then
		moveSpeed *= 0.6 -- out of puff: a short, weak long jump
	end
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
	lastPoundLand = os.clock()
	local pos = root.Position - Vector3.new(0, 2.6, 0)
	Remotes.Pound:FireServer("land", pos)
	Effects.Shake(1.2, 0.3)
	Effects.Play("Land", 0.8)
end

local function crouch()
	if flying or not enabled or not root then
		return
	end
	if move == "zip" and zip then
		releaseZip(false) -- drop off the zipline
		return
	end
	if move == "" or move == "longjump" or move == "dive" or move == "backflip" then
		if inAir() and not grounded() then
			if move == "dive" or move == "backflip" then
				setMove("")
			end
			startPound()
		elseif move == "" then
			if flatVelocity().Magnitude > 12 then
				startSlide(false)
			else
				-- crouch in place: crawl, or jump for a backflip
				setMove("crouch")
			end
		end
	end
end

local function uncrouch()
	if move == "crouch" then
		setMove("")
	end
end

-- A wall right in front of us (or where the stick points)?
local function findWall()
	local dirs = { facingDir() }
	local md = humanoid.MoveDirection
	if md.Magnitude > 0.1 then
		table.insert(dirs, Vector3.new(md.X, 0, md.Z).Unit)
	end
	for _, d in ipairs(dirs) do
		for _, h in ipairs({ 0, 1.2 }) do
			local hit = workspace:Raycast(root.Position + Vector3.new(0, h, 0), d * 2.8, rayParams)
			if hit and math.abs(hit.Normal.Y) < 0.35 and not hit.Instance:GetAttribute("Lava") then
				return hit
			end
		end
	end
	return nil
end

local function wallJump(hit)
	local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit
	moveDir = n
	moveSpeed = 40
	setMove("walljump")
	usedDouble = false -- a wall jump gives you your double jump back
	jumpRising = false
	root.CFrame = CFrame.lookAt(root.Position, root.Position + n)
	root.AssemblyLinearVelocity = n * moveSpeed + Vector3.new(0, 60, 0)
	setPlane(n * moveSpeed)
	flipAt = os.clock()
	Effects.Play("Stomp", 1.6)
	Effects.Burst(hit.Position, DUST, 6, 3, 0.5, 2)
end

local function tryJumpMove()
	if flying or not enabled or not root or os.clock() < celebrateUntil then
		return
	end
	local now = os.clock()
	if move == "roll" or (move == "slide" and now - moveStart > 0.08) then
		startLongJump(moveSpeed + 10, move == "roll") -- out of a roll it's included in the roll's cost
		return
	end
	if move == "zip" and zip then
		releaseZip(true) -- let go of the zipline with a hop
		return
	end
	if move == "dive" then
		-- roll out of the dive: a little hop that keeps your speed
		local v = root.AssemblyLinearVelocity
		setMove("")
		jumpRising = false
		flipAt = now
		sendMove("flip")
		root.AssemblyLinearVelocity = Vector3.new(v.X, Config.RolloutPower, v.Z)
		humanoid:ChangeState(HST.Freefall)
		Effects.Play("Jump", 1.2)
		return
	end
	if move == "crouch" then
		return -- the humanoid's own jump fires; StateChanged turns it into a backflip
	end
	-- coyote time: walked off a ledge a moment ago and haven't jumped yet
	if move == "" and not grounded() and not jumpedSinceGround and now - lastGrounded < COYOTE_TIME then
		jumpedSinceGround = true
		jumpRising = true
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, Config.JumpPower, v.Z)
		humanoid:ChangeState(HST.Jumping)
		Effects.Play("Jump", 1.05)
		return
	end
	if (move == "" or move == "longjump") and inAir() and now - lastGrounded > 0.12 then
		local wall = findWall()
		if wall then
			wallJump(wall)
			return
		end
	end
	if move ~= "" or usedDouble or not inAir() or now - lastGrounded < 0.15 then
		-- remember the press: if we land in the next moment, jump right away
		if not grounded() then
			bufferUntil = now + BUFFER_TIME
		end
		return
	end
	usedDouble = true
	jumpRising = true
	flipAt = now
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
	emote = nil
	talking = false
	humanoid = char:WaitForChild("Humanoid")
	root = char:WaitForChild("HumanoidRootPart")
	move = ""
	zip = nil
	if zipPulley then
		zipPulley:Destroy()
	end
	zipAlign, zipOrient, zipPulley, zipSound = nil, nil, nil, nil
	usedDouble = false
	divedSinceGround = false
	sentMove = nil
	runSpeed = Config.RunStartSpeed
	stamina = staminaMax
	staminaChanged()
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

	jumpedSinceGround = false
	jumpRising = false
	celebrateUntil = 0
	humanoid.StateChanged:Connect(function(_, new)
		if new == HST.Landed or new == HST.Running then
			usedDouble = false
			divedSinceGround = false
			jumpedSinceGround = false
			jumpRising = false
			lastGrounded = os.clock()
			if new == HST.Landed then
				landAt = os.clock()
				if lastVy < -55 then
					Effects.Ring(root.Position - Vector3.new(0, 2.6, 0), DUST, 5, 10, 0.3)
				end
				if lastVy < -Config.HardLanding and move ~= "pound" then
					-- a heavy landing: a thump, a camera dip and a moment to recover
					staggerUntil = os.clock() + 0.16
					Effects.Shake(0.5, 0.18)
					Effects.Play("Land", 0.7)
				end
				if move == "backflip" then
					setMove("")
				end
			end
			-- jump buffer: jump was pressed just before touching down
			if os.clock() < bufferUntil and enabled and move == "" then
				bufferUntil = 0
				task.defer(function()
					if humanoid and humanoid.Parent then
						humanoid:ChangeState(HST.Jumping)
					end
				end)
			end
		elseif new == HST.Jumping then
			local now = os.clock()
			lastGrounded = now
			jumpedSinceGround = true
			jumpRising = true
			if move == "crouch" then
				-- backflip: straight up and over, drifting backwards
				local back = -facingDir()
				jumpRising = false
				usedDouble = true
				moveDir = back
				moveSpeed = Config.BackflipBack
				setMove("backflip")
				setPlane(back * moveSpeed)
				task.defer(function()
					if root and move == "backflip" then
						root.AssemblyLinearVelocity = back * moveSpeed + Vector3.new(0, Config.BackflipPower, 0)
					end
				end)
				Effects.Play("DoubleJump", 0.85)
			elseif move == "" and now - lastPoundLand < 0.32 then
				-- pound jump: spring out of the ground pound's impact
				jumpRising = false
				usedDouble = true
				flipAt = now
				sendMove("flip")
				task.defer(function()
					if root then
						local v = root.AssemblyLinearVelocity
						root.AssemblyLinearVelocity = Vector3.new(v.X, Config.PoundJumpPower, v.Z)
					end
				end)
				Effects.Play("DoubleJump", 1.3)
				Effects.Ring(root.Position - Vector3.new(0, 2.6, 0), Color3.fromRGB(240, 226, 170), 6, 12, 0.35)
			elseif move == "" then
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

-- Emotes: wave, dance or sit until you move (wave ends on its own)
function Movement.Emote(id)
	if not enabled or flying or not root or move ~= "" or not grounded() then
		return
	end
	if emote == id then
		emote = nil
		sendMove("")
		return
	end
	emote = id
	emoteStart = os.clock()
	sendMove(id)
end

local function endEmote()
	if emote then
		emote = nil
		sendMove("")
	end
end

-- While chatting with a friend: shown to others, and baddies leave you alone
function Movement.SetTalking(on)
	talking = on
	endEmote()
	if root then
		sendMove(on and "talk" or "")
	end
end

-- Golden-carrot celebration: a little cheer, controls paused for a moment
function Movement.Celebrate(duration)
	if not root or flying then
		return
	end
	if move ~= "" then
		setMove("")
	end
	celebrateUntil = os.clock() + duration
	sendMove("cheer")
	if controls and enabled then
		controls:Disable()
	end
	if grounded() then
		root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end
	task.delay(duration, function()
		if os.clock() >= celebrateUntil - 0.01 then
			sendMove("")
			if controls and enabled then
				controls:Enable()
			end
		end
	end)
end

-- Is the player holding jump? (humanoid.Jump mirrors the jump input on every device)
local jumpCodes = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA }
local function jumpHeld()
	if humanoid and humanoid.Jump then
		return true
	end
	for _, code in ipairs(jumpCodes) do
		local isPad = string.sub(code.Name, 1, 6) == "Button" or string.sub(code.Name, 1, 4) == "DPad"
		if isPad then
			if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, code) then
				return true
			end
		elseif UserInputService:IsKeyDown(code) then
			return true
		end
	end
	return false
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
		move = flying and "fly"
			or (os.clock() < celebrateUntil and "cheer")
			or (talking and "talk")
			or (move == "" and emote)
			or (move == "" and os.clock() < skidUntil and "skid")
			or move,
		moveStart = moveStart,
		flipAt = flipAt,
		speed = moveSpeed,
		landAt = landAt,
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

--------------------------------------------------------------------------------
-- Ziplines: grab the rope and ride a pulley down it
--------------------------------------------------------------------------------

local DEFAULT_FOV = 65

local function cameraFov(fov, time)
	local cam = workspace.CurrentCamera
	if cam then
		TweenService:Create(cam, TweenInfo.new(time or 0.4, Enum.EasingStyle.Sine), { FieldOfView = fov }):Play()
	end
end

local function buildPulley()
	local model = Instance.new("Model")
	model.Name = "ZipPulley"
	local function piece(size, color, material, cf, shape)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.Color = color
		p.Material = material
		if shape then
			p.Shape = shape
		end
		p:SetAttribute("Offset", cf)
		p.Parent = model
		return p
	end
	local metal = Color3.fromRGB(70, 72, 80)
	-- a wheel riding on the cable, a housing, and a bar to hang from
	local wheel = piece(Vector3.new(0.5, 1.3, 1.3), Color3.fromRGB(40, 40, 46), Enum.Material.Metal, CFrame.new(), Enum.PartType.Cylinder)
	piece(Vector3.new(0.9, 1.6, 0.35), Config.Palette.Roof, Enum.Material.SmoothPlastic, CFrame.new(0, -0.35, 0))
	for _, sx in ipairs({ -1, 1 }) do
		piece(Vector3.new(0.18, 1.4, 0.18), metal, Enum.Material.Metal, CFrame.new(sx * 0.7, -1.15, 0))
	end
	piece(Vector3.new(1.9, 0.26, 0.26), Config.Palette.WoodLight, Enum.Material.Wood, CFrame.new(0, -1.85, 0))
	model.PrimaryPart = wheel
	model.Parent = Effects.Folder
	return model
end

local function placePulley(at, along)
	if not zipPulley then
		return
	end
	local flat = Vector3.new(along.X, 0, along.Z)
	local base = flat.Magnitude > 0.01 and CFrame.lookAt(at, at + flat) or CFrame.new(at)
	local spin = CFrame.Angles(os.clock() * -18, 0, 0)
	for _, p in ipairs(zipPulley:GetChildren()) do
		local off = p:GetAttribute("Offset") or CFrame.new()
		if p == zipPulley.PrimaryPart then
			-- the wheel turns as you ride (cylinders spin about their X axis)
			p.CFrame = base * CFrame.Angles(0, math.pi / 2, 0) * spin
		else
			p.CFrame = base * off
		end
	end
end

local function endZip()
	zip = nil
	zipReleasedAt = os.clock()
	for _, inst in ipairs({ zipAlign, zipOrient, zipPulley, zipSound }) do
		if inst then
			inst:Destroy()
		end
	end
	zipAlign, zipOrient, zipPulley, zipSound = nil, nil, nil, nil
	cameraFov(DEFAULT_FOV, 0.6)
	if move == "zip" then
		setMove("")
	end
	if humanoid then
		humanoid:ChangeState(HST.Freefall)
	end
end

local function startZip(a, b, t)
	local ab = b - a
	zip = { a = a, b = b, dir = ab.Unit, len = ab.Magnitude, t = t, speed = math.max(flatVelocity().Magnitude * 0.6, 20) }
	setMove("zip")
	usedDouble = false
	jumpRising = false
	humanoid:ChangeState(HST.Physics)
	local att = root:FindFirstChild("MoveAttachment")
	zipAlign = Instance.new("AlignPosition")
	zipAlign.Mode = Enum.PositionAlignmentMode.OneAttachment
	zipAlign.Attachment0 = att
	zipAlign.RigidityEnabled = true
	zipAlign.Position = root.Position
	zipAlign.Parent = root
	zipOrient = Instance.new("AlignOrientation")
	zipOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	zipOrient.Attachment0 = att
	zipOrient.RigidityEnabled = true
	zipOrient.CFrame = root.CFrame.Rotation
	zipOrient.Parent = root
	zipPulley = buildPulley()
	zipSound = Instance.new("Sound")
	zipSound.SoundId = Config.Sounds.Roll.id
	zipSound.Looped = true
	zipSound.Volume = 0.3
	zipSound.PlaybackSpeed = 0.6
	zipSound.Parent = root
	zipSound:Play()
	cameraFov(DEFAULT_FOV + 9, 0.8)
	Effects.Play("Stomp", 1.4)
	Effects.Burst(a:Lerp(b, t), Color3.fromRGB(255, 220, 150), 6, 4, 0.4, 0, Enum.Material.Neon)
end

-- Let go of the zipline: a hop (jump) or a drop (crouch)
releaseZip = function(hop)
	if not zip then
		return
	end
	local v = zip.dir * zip.speed
	endZip()
	if hop then
		flipAt = os.clock()
		sendMove("flip")
		root.AssemblyLinearVelocity = Vector3.new(v.X * 0.85, 46, v.Z * 0.85)
		Effects.Play("Jump", 1.1)
	else
		root.AssemblyLinearVelocity = Vector3.new(v.X * 0.6, math.min(v.Y, 0), v.Z * 0.6)
	end
end

local function stepZipGrab(now)
	if not zipFolder then
		local world = workspace:FindFirstChild("Bunny64World")
		zipFolder = world and world:FindFirstChild("Ziplines")
		if not zipFolder then
			return
		end
	end
	if zip or now - zipReleasedAt < 0.6 then
		return
	end
	if not (move == "" or move == "longjump" or move == "dive" or move == "walljump" or move == "backflip" or move == "spring") then
		return
	end
	local hands = root.Position + Vector3.new(0, 3, 0)
	for _, rope in ipairs(zipFolder:GetChildren()) do
		local a, b = rope:GetAttribute("ZipA"), rope:GetAttribute("ZipB")
		if typeof(a) == "Vector3" and typeof(b) == "Vector3" then
			local ab = b - a
			local t = math.clamp((hands - a):Dot(ab) / ab:Dot(ab), 0, 1)
			if t < 0.94 and (hands - (a + ab * t)).Magnitude < 3.4 then
				startZip(a, b, t)
				return
			end
		end
	end
end

local function stepZipRide(dt, now)
	if not zipAlign or not zipAlign.Parent then
		endZip()
		return
	end
	-- gravity pulls you faster on steep lines; there's always a little push
	local slope = math.max(0, -zip.dir.Y)
	zip.speed = math.min(Config.ZipSpeed, zip.speed + (12 + 70 * slope) * dt)
	zip.t += zip.speed * dt / zip.len
	if zip.t >= 1 then
		-- off the end: flung forward with all that speed
		local v = zip.dir * zip.speed
		endZip()
		flipAt = now
		sendMove("flip")
		root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 0) + 24, v.Z)
		Effects.Play("DoubleJump", 1.1)
		return
	end
	local ropePoint = zip.a:Lerp(zip.b, zip.t)
	local flatDir = Vector3.new(zip.dir.X, 0, zip.dir.Z)
	zipAlign.Position = ropePoint - Vector3.new(0, 3.3, 0)
	if flatDir.Magnitude > 0.01 then
		zipOrient.CFrame = CFrame.lookAt(Vector3.zero, flatDir.Unit)
	end
	root.AssemblyLinearVelocity = zip.dir * zip.speed
	placePulley(ropePoint, zip.dir)
	if zipSound then
		zipSound.PlaybackSpeed = 0.6 + zip.speed / Config.ZipSpeed * 0.9
	end
	if now > nextDust then
		nextDust = now + 0.05
		Effects.Burst(ropePoint, Color3.fromRGB(255, 214, 140), 2, 3, 0.25, -2, Enum.Material.Neon)
	end
end

--------------------------------------------------------------------------------
-- The per-frame update, in protected pieces: the core moves always run first,
-- and if an optional system (stamina, pads, wind...) ever errors, it reports
-- once in the Output window and the rest of the bunny keeps working.
--------------------------------------------------------------------------------

local function stepMoves(dt, now, onGround)
	if move == "" and onGround and sentMove == "flip" then
		sendMove("")
	end
	if move == "roll" or move == "longjump" or move == "slide" then
		if now - moveStart > 0.1 then
			followActual()
		end
	end

	if move == "walljump" then
		local t = now - moveStart
		setPlane(moveDir * moveSpeed)
		if t > 0.3 or (onGround and t > 0.1) then
			setMove("")
		end
	elseif move == "roll" then
		local t = now - moveStart
		moveSpeed = Config.RollSpeed * rollPower * (1 - 0.35 * t / Config.RollTime)
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
			moveDir = (moveDir:Lerp(want, math.clamp(dt * 2.4, 0, 1))).Unit
		end
		moveSpeed = math.max(moveSpeed - 9 * dt, math.min(moveSpeed, 26))
		setPlane(moveDir * moveSpeed)
		if onGround and t > 0.15 then
			setMove("")
			Effects.Burst(root.Position - Vector3.new(0, 2.5, 0), Config.Palette.Path, 6, 4, 0.5, 1)
		end
	elseif move == "dive" then
		local t = now - moveStart
		local md = humanoid.MoveDirection
		if md.Magnitude > 0.1 then
			moveDir = (moveDir:Lerp(Vector3.new(md.X, 0, md.Z).Unit, math.clamp(dt * 2, 0, 1))).Unit
		end
		moveSpeed = math.max(moveSpeed - 14 * dt, 32)
		setPlane(moveDir * moveSpeed)
		if onGround and t > 0.08 then
			-- belly-flop into a slide
			moveSpeed = math.max(moveSpeed * 0.85, 30)
			setMove("slide")
			setPlane(moveDir * moveSpeed)
			Effects.Burst(root.Position - Vector3.new(0, 2.5, 0), DUST, 8, 5, 0.6, 1)
			Effects.Play("Land", 1.1)
		elseif t > 3 then
			setMove("")
		end
	elseif move == "spring" or move == "backflip" then
		setPlane(moveDir * moveSpeed)
		if (onGround and now - moveStart > 0.15) or now - moveStart > 4 then
			setMove("")
		end
	elseif move == "crouch" then
		if not onGround then
			setMove("")
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
				speed = math.clamp(speed + 22 * dt, 30, Config.ChuteSpeed) -- chutes keep you moving, fast
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

local function stepStamina(dt, now, onGround)
	if onGround and stamina < staminaMax and now > staminaRegenAt and move ~= "roll" and move ~= "slide" then
		local before = math.floor(stamina * 4)
		stamina = math.min(staminaMax, stamina + Config.Stamina.regen * dt)
		if math.floor(stamina * 4) ~= before or stamina >= staminaMax then
			staminaChanged()
		end
	end
end

-- running builds up to full speed; hard turns at speed skid
local function stepRunSpeed(dt, now, onGround, vel)
	local boost = character:GetAttribute("SpeedBoost") or 1
	local top = Config.WalkSpeed * boost
	local md = humanoid.MoveDirection
	local hv = Vector3.new(vel.X, 0, vel.Z)
	if move == "crouch" then
		runSpeed = 7
	elseif now < staggerUntil then
		runSpeed = Config.RunStartSpeed * 0.5
	elseif md.Magnitude < 0.1 then
		if onGround then
			runSpeed = Config.RunStartSpeed * boost
		end
	elseif onGround and move == "" and hv.Magnitude > top * 0.7 and md:Dot(hv.Unit) < -0.55 and now > skidUntil then
		skidUntil = now + 0.2
		runSpeed = 4
		Effects.Play("Roll", 1.6)
		Effects.Burst(root.Position - Vector3.new(0, 2.5, 0), DUST, 6, 4, 0.5, 1)
		sendMove("skid")
		task.delay(0.22, function()
			if move == "" and sentMove == "skid" then
				sendMove("")
			end
		end)
	elseif now > skidUntil then
		local rate = Config.RunAccel * (onGround and 1 or 0.6)
		runSpeed = math.min(top, math.max(runSpeed, Config.RunStartSpeed * boost) + rate * dt)
	end
	runSpeed = math.max(runSpeed, 1)
	if math.abs(humanoid.WalkSpeed - runSpeed) > 0.05 then
		humanoid.WalkSpeed = runSpeed
	end
end

-- heavier falls (not while pounding or riding the wind)
local function stepGravity(dt, onGround)
	local vel = root.AssemblyLinearVelocity
	if not onGround and vel.Y < 0 and move ~= "pound" and not inWind then
		local vy = math.max(vel.Y - Config.Gravity * (Config.FallGravityMult - 1) * dt, -Config.MaxFallSpeed)
		root.AssemblyLinearVelocity = Vector3.new(vel.X, vy, vel.Z)
	end
end

-- mushrooms bounce you up; spring pads throw you where they aim
local function stepPads(now)
	if root.AssemblyLinearVelocity.Y >= 5 then
		return
	end
	local under = floorHit()
	if not under then
		return
	end
	local part = under.Instance
	local height = root.Position.Y - under.Position.Y
	if part:GetAttribute("Bounce") and height < 3.6 then
		bounceOff(part)
		return
	end
	local launchVel = part:GetAttribute("Launch")
	if typeof(launchVel) == "Vector3" and height < 3.8 and now - lastLaunch > 0.5 then
		lastLaunch = now
		launch(launchVel, "bounce")
		flipAt = now
		sendMove("flip")
		local flat = Vector3.new(launchVel.X, 0, launchVel.Z)
		if flat.Magnitude > 5 then
			-- carry the throw exactly, so the pad lands you where it aims
			moveDir = flat.Unit
			moveSpeed = flat.Magnitude
			setMove("spring")
			setPlane(moveDir * moveSpeed)
			usedDouble = false
		end
		Effects.Play("Boing", 1.1)
		Effects.Burst(under.Position, part.Color, 10, 6, 0.6, 4)
	end
end

-- rising winds and gusts (Cloudtop Heights): parts in the world's Winds folder
local function stepWind(dt)
	if not windFolder then
		local world = workspace:FindFirstChild("Bunny64World")
		windFolder = world and world:FindFirstChild("Winds")
	end
	local nowInWind = false
	if windFolder then
		local pos = root.Position
		for _, w in ipairs(windFolder:GetChildren()) do
			local force = w:GetAttribute("Wind")
			if typeof(force) == "Vector3" and w:IsA("BasePart") then
				local lp = w.CFrame:PointToObjectSpace(pos)
				local half = w.Size / 2
				if math.abs(lp.X) < half.X and math.abs(lp.Z) < half.Z and lp.Y > -half.Y - 3 and lp.Y < half.Y then
					nowInWind = true
					local v = root.AssemblyLinearVelocity
					local vy = force.Y > 0 and math.max(v.Y, force.Y) or v.Y
					local push = Vector3.new(force.X, 0, force.Z) * math.clamp(dt * 3, 0, 1)
					root.AssemblyLinearVelocity = Vector3.new(v.X + push.X, vy, v.Z + push.Z)
					if not inWind and force.Y > 0 then
						humanoid:ChangeState(HST.Freefall)
						jumpRising = false
						if move == "pound" then
							setMove("")
						end
					end
					usedDouble = false -- the wind gives you your double jump back
				end
			end
		end
	end
	inWind = nowInWind
end

local warnedParts = {}
local function safely(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and not warnedParts[name] then
		warnedParts[name] = true
		warn(string.format("[Bunny64] Movement (%s): %s", name, tostring(err)))
	end
end

local function step(dt)
	if not root or not humanoid or humanoid.Health <= 0 or flying then
		return
	end
	dt = math.min(dt, 0.1)
	local now = os.clock()
	local onGround = grounded()
	if onGround then
		lastGrounded = now
		airborneSince = nil
	elseif not airborneSince then
		airborneSince = now
	end
	local vel = root.AssemblyLinearVelocity
	if emote then
		local moving = humanoid.MoveDirection.Magnitude > 0.1 or not onGround or move ~= ""
		if moving or (emote == "wave" and now - emoteStart > 2.6) then
			endEmote()
		end
	end
	-- variable jump height: letting go early cuts the jump short
	if jumpRising then
		if vel.Y <= 0 then
			jumpRising = false
		elseif move == "" and vel.Y > 16 and not jumpHeld() then
			root.AssemblyLinearVelocity = Vector3.new(vel.X, vel.Y * 0.45, vel.Z)
			jumpRising = false
		end
	end

	if move == "zip" then
		safely("zipline", stepZipRide, dt, now)
		lastVy = root.AssemblyLinearVelocity.Y
		return
	end
	safely("moves", stepMoves, dt, now, onGround)
	safely("stamina", stepStamina, dt, now, onGround)
	safely("run", stepRunSpeed, dt, now, onGround, vel)
	safely("gravity", stepGravity, dt, onGround)
	safely("pads", stepPads, now)
	safely("zipgrab", stepZipGrab, now)
	safely("wind", stepWind, dt)

	-- running dust
	vel = root.AssemblyLinearVelocity
	if onGround and move == "" and now > nextDust and Vector3.new(vel.X, 0, vel.Z).Magnitude > 20 then
		nextDust = now + 0.16
		Effects.Burst(root.Position - Vector3.new(0, 2.5, 0), DUST, 2, 2, 0.45, 0.8)
	end
	lastVy = vel.Y
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
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			uncrouch()
		end
		return Enum.ContextActionResult.Sink
	end, true, binds.crouch[1], binds.crouch[2])
	ContextActionService:SetTitle("Bunny64Crouch", "CROUCH")
	ContextActionService:SetPosition("Bunny64Crouch", UDim2.new(1, -170, 1, -170))

	ContextActionService:UnbindAction("Bunny64Emote")
	local emoteKeys, emoteOf = {}, {}
	for _, e in ipairs(Config.Emotes) do
		for _, name in ipairs({ e.key, e.pad }) do
			local ok, code = pcall(function()
				return Enum.KeyCode[name]
			end)
			if ok and code then
				table.insert(emoteKeys, code)
				emoteOf[code] = e.id
			end
		end
	end
	ContextActionService:BindAction("Bunny64Emote", function(_, inputState, input)
		if inputState == Enum.UserInputState.Begin and emoteOf[input.KeyCode] then
			Movement.Emote(emoteOf[input.KeyCode])
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(emoteKeys))

	-- Space / A always jump (Roblox handles those); a custom jump key is added on top
	local jumpKeys = {}
	jumpCodes = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA, binds.jump[1], binds.jump[2] }
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
