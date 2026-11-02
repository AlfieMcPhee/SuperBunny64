--[[
	AdminPanel - the admin perks menu (press P, or the ADMIN button).
	Only shows for admins; the server checks every command anyway.

	Flying is done here on the client: a LinearVelocity carries the bunny
	where the camera points (WASD / stick), Space goes up, Shift goes down,
	hold Ctrl to go faster.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))

local player = Players.LocalPlayer
local AdminPanel = {}

local deps
local isAdmin = false
local gui, panel, openButton, playerList
local visible = false
local flying = false
local flyLV, flyAO, flyConn

local function run(command, arg)
	local remote = deps.Remotes.AdminCommand
	if not remote then
		return nil
	end
	local ok, msg, value = remote:InvokeServer(command, arg)
	if msg then
		deps.Hud.Toast(msg, 1.8, ok and UI.Gold or Color3.fromRGB(240, 140, 120))
	end
	return ok, value
end

--------------------------------------------------------------------------------
-- Flying
--------------------------------------------------------------------------------

local function stopFly()
	flying = false
	if flyConn then
		flyConn:Disconnect()
		flyConn = nil
	end
	if flyLV then
		flyLV:Destroy()
		flyLV = nil
	end
	if flyAO then
		flyAO:Destroy()
		flyAO = nil
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	deps.Movement.SetFlying(false)
end

local function startFly()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		return false
	end
	flying = true
	deps.Movement.SetFlying(true)
	local att = root:FindFirstChild("MoveAttachment") or Instance.new("Attachment")
	att.Name = "MoveAttachment"
	att.Parent = root
	flyLV = Instance.new("LinearVelocity")
	flyLV.Name = "AdminFly"
	flyLV.Attachment0 = att
	flyLV.RelativeTo = Enum.ActuatorRelativeTo.World
	flyLV.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	flyLV.MaxForce = 1e6
	flyLV.VectorVelocity = Vector3.zero
	flyLV.Parent = root
	flyAO = Instance.new("AlignOrientation")
	flyAO.Name = "AdminFlyTurn"
	flyAO.Mode = Enum.OrientationAlignmentMode.OneAttachment
	flyAO.Attachment0 = att
	flyAO.MaxTorque = 1e6
	flyAO.Responsiveness = 40
	flyAO.CFrame = root.CFrame - root.Position
	flyAO.Parent = root
	hum.PlatformStand = true

	flyConn = RunService.RenderStepped:Connect(function()
		if not root.Parent or hum.Health <= 0 then
			stopFly()
			return
		end
		local cam = workspace.CurrentCamera
		local controls = deps.Movement.GetControls()
		local moveVec = controls and controls:GetMoveVector() or Vector3.zero
		local dir = cam.CFrame:VectorToWorldSpace(moveVec)
		local up = 0
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA) then
			up += 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonB) then
			up -= 1
		end
		local v = dir + Vector3.new(0, up, 0)
		local fast = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2)
		local speed = fast and 160 or 70
		flyLV.VectorVelocity = v.Magnitude > 0.05 and v.Unit * speed or Vector3.zero
		local look = cam.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			flyAO.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
		end
	end)
	return true
end

local function toggleFly()
	if flying then
		stopFly()
		run("fly", false)
	elseif startFly() then
		run("fly", true)
	end
end

--------------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------------

local function button(parent, text, order, onClick, width)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.Text = text
	b.Font = UI.BODY
	b.TextSize = 16
	b.TextColor3 = UI.Cream
	b.BackgroundColor3 = Color3.fromRGB(58, 62, 108)
	b.Size = UDim2.new(width or 1, -6, 0, 30)
	b.LayoutOrder = order or 0
	UI.corner(b, 6)
	UI.stroke(b, 2, UI.Gold, Enum.ApplyStrokeMode.Border)
	UI.stroke(b, 2)
	b.Parent = parent
	b.Activated:Connect(function()
		deps.Effects.Play("MenuSelect", 1.2)
		onClick(b)
	end)
	return b
end

local function heading(parent, text, order)
	UI.label(parent, { Text = text, Font = UI.TITLE, TextSize = 20, TextColor3 = UI.Gold, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = order, Stroke = 3 })
end

local function grid(parent, order, cellWidth)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = order
	f.Parent = parent
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(cellWidth or 0.5, -4, 0, 30)
	g.CellPadding = UDim2.fromOffset(4, 4)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = f
	return f
end

local function refreshPlayers()
	if not playerList then
		return
	end
	playerList:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = playerList
	local others = 0
	for i, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			others += 1
			UI.label(playerList, { Text = string.upper(p.DisplayName), TextSize = 18, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = i * 2 - 1, TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2 })
			local row = grid(playerList, i * 2, 1 / 3)
			local id = p.UserId
			button(row, "GO TO", 1, function() run("goto", id) end)
			button(row, "BRING", 2, function() run("bring", id) end)
			button(row, "FREEZE", 3, function() run("freeze", id) end)
			button(row, "LAUNCH", 4, function() run("launch", id) end)
			button(row, "CONTROL", 5, function() run("control", id) end)
			button(row, "HEAL", 6, function() run("heal", id) end)
		end
	end
	if others == 0 then
		UI.label(playerList, { Text = "No one else is here yet.", TextSize = 16, Size = UDim2.new(1, 0, 0, 22), Stroke = 2 })
	end
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Bunny64Admin"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	openButton = Instance.new("TextButton")
	openButton.Text = "ADMIN"
	openButton.Font = UI.TITLE
	openButton.TextSize = 18
	openButton.TextColor3 = UI.Gold
	openButton.BackgroundColor3 = Color3.fromRGB(90, 40, 50)
	openButton.Size = UDim2.fromOffset(92, 30)
	openButton.Position = UDim2.fromOffset(20, 160)
	UI.corner(openButton, 8)
	UI.stroke(openButton, 3, UI.Gold, Enum.ApplyStrokeMode.Border)
	UI.stroke(openButton, 2)
	openButton.Parent = gui
	openButton.Activated:Connect(function()
		AdminPanel.Toggle()
	end)

	local frame, shadow = UI.panel(gui, UDim2.fromOffset(380, 560), UDim2.new(1, -210, 0.5, 0))
	panel = shadow
	panel.Visible = false
	UI.label(frame, { Text = "ADMIN PERKS", Font = UI.TITLE, TextSize = 30, TextColor3 = UI.Gold, Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 10), Stroke = 4 })
	local close = Instance.new("TextButton")
	close.Text = "X"
	close.Font = UI.TITLE
	close.TextSize = 22
	close.TextColor3 = UI.Cream
	close.BackgroundTransparency = 1
	close.Size = UDim2.fromOffset(36, 36)
	close.Position = UDim2.new(1, -44, 0, 8)
	close.Parent = frame
	close.Activated:Connect(function()
		AdminPanel.Toggle(false)
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, -24, 1, -64)
	scroll.Position = UDim2.fromOffset(12, 52)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = UI.Gold
	scroll.Parent = frame
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	heading(scroll, "YOU", 1)
	local me = grid(scroll, 2)
	button(me, "FLY", 1, function(b)
		toggleFly()
		b.Text = flying and "FLY: ON" or "FLY"
	end)
	button(me, "GOD MODE", 2, function(b)
		local ok, on = run("god")
		if ok then
			b.Text = on and "GOD: ON" or "GOD MODE"
		end
	end)
	button(me, "SPEED x1", 3, function(b)
		local ok, level = run("speed")
		if ok then
			b.Text = "SPEED x" .. tostring(level)
		end
	end)
	button(me, "FULL HEAL", 4, function()
		run("heal")
	end)

	heading(scroll, "TELEPORT", 3)
	local tp = grid(scroll, 4)
	local places = {
		{ "MEADOW", "meadow" }, { "PEAKS", "peaks" }, { "CANYON", "canyon" }, { "CASTLE GATE", "castle" },
		{ "COURTYARD", "courtyard" }, { "THE KEEP", "keep" }, { "DUNGEON", "dungeon" }, { "BOSS!", "boss" },
		{ "WHISPERWOOD", "forest" }, { "CLOUDTOP", "sky" }, { "UNDERBURROW", "underburrow" }, { "DEPTHS", "underburrow2" },
	}
	for i, p in ipairs(places) do
		button(tp, p[1], i, function()
			run("tp", p[2])
		end)
	end

	heading(scroll, "WORLD", 5)
	local world = grid(scroll, 6)
	button(world, "RESET BOSS", 1, function()
		run("resetboss")
	end)
	button(world, "ALL GOLDENS", 2, function()
		run("allgoldens")
	end)

	heading(scroll, "PLAYERS", 7)
	playerList = Instance.new("Frame")
	playerList.BackgroundTransparency = 1
	playerList.Size = UDim2.new(1, 0, 0, 0)
	playerList.AutomaticSize = Enum.AutomaticSize.Y
	playerList.LayoutOrder = 8
	playerList.Parent = scroll
	refreshPlayers()
	Players.PlayerAdded:Connect(refreshPlayers)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshPlayers)
	end)
	UI.label(scroll, {
		Text = "Fly: WASD + Space up, Shift down, Ctrl fast. Control makes a player follow you for 20s.",
		TextSize = 13, TextWrapped = true, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 9, Stroke = 2, TextTransparency = 0.2,
	})
end

function AdminPanel.Toggle(force)
	if not isAdmin or not gui then
		return
	end
	local open = force
	if open == nil then
		open = not panel.Visible
	end
	panel.Visible = open
	if open then
		refreshPlayers()
	end
end

function AdminPanel.SetAdmin(on)
	isAdmin = on == true
	if gui then
		gui.Enabled = isAdmin and visible
	end
	if isAdmin then
		ContextActionService:BindAction("Bunny64Admin", function(_, state)
			if state == Enum.UserInputState.Begin then
				AdminPanel.Toggle()
			end
			return Enum.ContextActionResult.Pass
		end, false, Enum.KeyCode.P)
	else
		ContextActionService:UnbindAction("Bunny64Admin")
	end
end

function AdminPanel.SetVisible(on)
	visible = on
	if gui then
		gui.Enabled = isAdmin and on
	end
	if not on and flying then
		stopFly()
	end
end

function AdminPanel.Init(dependencies)
	deps = dependencies
	build()
	player.CharacterAdded:Connect(function()
		if flying then
			flying = false
			flyConn = flyConn and flyConn:Disconnect() or nil
			flyLV, flyAO = nil, nil
		end
	end)
	-- messages for everyone (being controlled, being launched...)
	local notice = deps.Remotes.AdminNotice
	if notice then
		notice.OnClientEvent:Connect(function(kind, value)
			if kind == "toast" then
				deps.Hud.Toast(value, 3, UI.Gold)
			elseif kind == "control" then
				if value then
					deps.Movement.SetEnabled(false)
				elseif deps.Menus.Screen() == nil then
					deps.Movement.SetEnabled(true)
				end
			end
		end)
	end
end

return AdminPanel
