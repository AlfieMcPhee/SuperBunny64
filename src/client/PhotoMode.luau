--[[
	PhotoMode - a free camera for screenshots (Pause > PHOTO MODE).

	  WASD / left stick       fly
	  hold right mouse / right stick   look around
	  Q / E (or LB / RB)      down / up
	  Shift (or LT)           faster
	  Backspace / B           back to the pause menu
	The camera stays within 120 studs of the bunny so it can't roam the map.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local PhotoMode = {}

local active = false

function PhotoMode.Start(onExit)
	if active then
		return
	end
	active = true
	local cam = workspace.CurrentCamera
	local startCF = cam.CFrame
	local pos = startCF.Position
	local _, yaw, _ = startCF:ToOrientation()
	local pitch = math.asin(math.clamp(startCF.LookVector.Y, -1, 1))
	local anchor = pos
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		anchor = root.Position
	end
	cam.CameraType = Enum.CameraType.Scriptable

	local conns = {}
	local function stop()
		if not active then
			return
		end
		active = false
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		cam.CameraType = Enum.CameraType.Custom
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
		onExit()
	end

	table.insert(conns, UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.M then
			stop()
		end
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			yaw -= input.Delta.X * 0.004
			pitch = math.clamp(pitch - input.Delta.Y * 0.004, -1.45, 1.45)
		end
	end))

	local pad = Enum.UserInputType.Gamepad1
	table.insert(conns, RunService.RenderStepped:Connect(function(dt)
		-- look
		UserInputService.MouseBehavior = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
			and Enum.MouseBehavior.LockCurrentPosition or Enum.MouseBehavior.Default
		local move = Vector3.zero
		local up = 0
		local fast = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		for _, state in ipairs(UserInputService:GetGamepadState(pad)) do
			if state.KeyCode == Enum.KeyCode.Thumbstick1 and state.Position.Magnitude > 0.15 then
				move += Vector3.new(state.Position.X, 0, -state.Position.Y)
			elseif state.KeyCode == Enum.KeyCode.Thumbstick2 and state.Position.Magnitude > 0.15 then
				yaw -= state.Position.X * dt * 2.2
				pitch = math.clamp(pitch + state.Position.Y * dt * 1.6, -1.45, 1.45)
			elseif state.KeyCode == Enum.KeyCode.ButtonL1 and state.UserInputState == Enum.UserInputState.Begin then
				up -= 1
			elseif state.KeyCode == Enum.KeyCode.ButtonR1 and state.UserInputState == Enum.UserInputState.Begin then
				up += 1
			elseif state.KeyCode == Enum.KeyCode.ButtonL2 and state.Position.Z > 0.5 then
				fast = true
			end
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			move += Vector3.new(0, 0, -1)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			move += Vector3.new(0, 0, 1)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			move += Vector3.new(-1, 0, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			move += Vector3.new(1, 0, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.E) then
			up += 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
			up -= 1
		end
		local rot = CFrame.fromOrientation(pitch, yaw, 0)
		local speed = fast and 70 or 25
		local delta = rot:VectorToWorldSpace(move) + Vector3.new(0, up, 0)
		if delta.Magnitude > 0.01 then
			pos += delta.Unit * speed * dt
		end
		-- stay near the bunny
		local off = pos - anchor
		if off.Magnitude > 120 then
			pos = anchor + off.Unit * 120
		end
		cam.CFrame = CFrame.new(pos) * rot
	end))
end

function PhotoMode.IsActive()
	return active
end

return PhotoMode
