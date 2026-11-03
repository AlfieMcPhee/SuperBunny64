--[[
	CameraRig - an SM64-style follow camera on top of Roblox's camera.

	With CAMERA set to FOLLOW (Options), the camera swings round behind the
	bunny while you run, like a cameraman following you, so you can just play
	with one stick. It never fights you:
	  * it waits a moment after you move the camera yourself (mouse drag,
	    touch drag, right stick)
	  * it doesn't swing when you run toward the camera (you'd lose the view)
	  * it stays put during menus, photo mode, emotes and while standing still
	FREE leaves the camera entirely to the player.

	It works by rotating the camera about its focus after Roblox's camera
	module has run each frame; Roblox's camera carries on from the new angle.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraRig = {}

local player = Players.LocalPlayer
local follow = true
local enabled = true
local lastManual = 0

function CameraRig.SetFollow(on)
	follow = on
end

-- Off while menus / photo mode are up
function CameraRig.SetEnabled(on)
	enabled = on
end

local function manual()
	lastManual = os.clock()
end

function CameraRig.Init()
	UserInputService.InputChanged:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseMovement then
			if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
				manual()
			end
		elseif t == Enum.UserInputType.Touch then
			manual()
		elseif t == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2 and input.Position.Magnitude > 0.2 then
			manual()
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			manual()
		end
	end)

	RunService:BindToRenderStep("Bunny64FollowCam", Enum.RenderPriority.Camera.Value + 2, function(dt)
		if not follow or not enabled or os.clock() - lastManual < 1.6 or (CameraRig.Blocked and CameraRig.Blocked()) then
			return
		end
		local cam = workspace.CurrentCamera
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not cam or not root or not hum or hum.Health <= 0 or cam.CameraType ~= Enum.CameraType.Custom then
			return
		end
		local v = root.AssemblyLinearVelocity
		local flatVel = Vector3.new(v.X, 0, v.Z)
		local speed = flatVel.Magnitude
		if speed < 8 then
			return
		end
		local look = cam.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatLook.Magnitude < 0.1 then
			return
		end
		flatLook = flatLook.Unit
		local want = flatVel.Unit
		-- signed angle from where the camera looks to where we're running
		local angle = math.atan2(flatLook:Cross(want).Y, flatLook:Dot(want))
		if math.abs(angle) > math.rad(115) then
			return -- running toward the camera: leave it be
		end
		local rate = math.clamp(speed / 24, 0.4, 1.6) * 1.1
		local turn = angle * math.clamp(dt * rate, 0, 1)
		local focus = cam.Focus.Position
		cam.CFrame = CFrame.new(focus) * CFrame.Angles(0, turn, 0) * CFrame.new(-focus) * cam.CFrame
	end)
end

return CameraRig
