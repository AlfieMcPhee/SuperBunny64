--[[
	Baddies - draws every baddie smoothly on this player's screen.

	The server runs their brains and publishes, a few times a second:
	  CF     where the baddie's root is (position, heading, tilt)
	  St     what it's doing (idle, chase, hop, swoop, wind, lunge, swell, blow...)
	  Alert  a timestamp when it spots someone
	  Alive  false while it's been bopped
	Here we glide between those updates every frame and add the animation
	that needs to be snappy: waddles, rolling spikes, wing flaps, jaw snaps,
	puffing up, a "!" when they notice you, and a squash when they're bopped.
	The parts are only moved locally, so this costs no network traffic.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Baddies = {}

local player = Players.LocalPlayer
local tracked = {} -- [Model] = data
local DRAW_DIST = 340
local A = CFrame.Angles

local function setHidden(data, hidden)
	if data.hidden == hidden then
		return
	end
	data.hidden = hidden
	for _, p in ipairs(data.parts) do
		p.LocalTransparencyModifier = hidden and 1 or 0
	end
	if data.bang then
		data.bang.Enabled = false
	end
end

local function makeBang(rootPart, height)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Alert"
	gui.Size = UDim2.fromOffset(40, 50)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.Enabled = false
	gui.Adornee = rootPart
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.LuckiestGuy
	t.Text = "!"
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 220, 90)
	t.TextStrokeTransparency = 0
	t.TextStrokeColor3 = Color3.fromRGB(40, 24, 20)
	t.Parent = gui
	gui.Parent = rootPart
	return gui
end

local function register(model)
	if not model:IsA("Model") or tracked[model] then
		return
	end
	local rootPart = model.PrimaryPart or model:FindFirstChild("Root")
	if not rootPart then
		task.delay(0.5, function()
			if model.Parent then
				register(model)
			end
		end)
		return
	end
	local rest = rootPart.CFrame
	local parts, offsets, sizes, roles = {}, {}, {}, {}
	local top = 2
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			local off = rest:ToObjectSpace(d.CFrame)
			offsets[#parts] = off
			sizes[#parts] = d.Size
			top = math.max(top, off.Y + d.Size.Y / 2)
			if d.Name == "Wing" or d.Name == "WingTip" then
				roles[#parts] = "wing"
			elseif d.Name == "BackLeg" then
				roles[#parts] = "leg"
			elseif d.Name == "Jaw" then
				roles[#parts] = "jaw"
			end
		end
	end
	local data = {
		model = model,
		kind = model:GetAttribute("Kind") or "bug",
		parts = parts,
		offsets = offsets,
		sizes = sizes,
		roles = roles,
		cur = model:GetAttribute("CF") or rest,
		prevPos = nil,
		speed = 0,
		phase = math.random() * 6,
		spin = 0,
		scale = 1,
		state = model:GetAttribute("St") or "idle",
		stateAt = os.clock(),
		alertAt = -10,
		alive = model:GetAttribute("Alive") ~= false,
		aliveAt = -10,
		hidden = false,
		cfs = table.create(#parts),
	}
	data.bang = makeBang(rootPart, top + 1.5)
	model:GetAttributeChangedSignal("St"):Connect(function()
		data.state = model:GetAttribute("St") or "idle"
		data.stateAt = os.clock()
	end)
	model:GetAttributeChangedSignal("Alert"):Connect(function()
		data.alertAt = os.clock()
	end)
	model:GetAttributeChangedSignal("Alive"):Connect(function()
		local alive = model:GetAttribute("Alive") ~= false
		if alive ~= data.alive then
			data.alive = alive
			data.aliveAt = os.clock()
			if alive then
				data.cur = model:GetAttribute("CF") or data.cur
				setHidden(data, false)
			end
		end
	end)
	if not data.alive then
		data.aliveAt = -10
		setHidden(data, true)
	end
	tracked[model] = data
end

-- Per-kind extra motion on top of the smoothed transform
local function animate(data, base, now, dt)
	local kind = data.kind
	local stateAge = now - data.stateAt

	-- walking waddle / rolling, from how fast it's actually moving
	if kind == "bug" or kind == "mossling" then
		local f = math.clamp(data.speed / 10, 0, 1.4)
		if f > 0.05 then
			data.phase += dt * (6 + data.speed * 1.1)
			local s = math.sin(data.phase)
			base = base * CFrame.new(0, math.abs(s) * 0.3 * f, 0) * A(0, 0, s * (kind == "mossling" and 0.14 or 0.07) * f)
		else
			-- idle breathing
			base = base * CFrame.new(0, math.sin(now * 2 + data.phase) * 0.06, 0)
		end
	elseif kind == "thornhog" then
		data.spin += data.speed * dt / 2.2
		base = base * A(-data.spin, 0, 0)
	elseif kind == "toad" and data.state == "idle" then
		-- throat puffing while it sits
		base = base * CFrame.new(0, math.abs(math.sin(now * 3 + data.phase)) * 0.1, 0)
	elseif kind == "puffer" then
		local target = 1
		if data.state == "swell" then
			target = 1 + math.clamp(stateAge / 0.9, 0, 1) * 0.38
		elseif data.state == "blow" then
			target = stateAge < 0.12 and 1.38 or 0.86
		end
		data.scale += (target - data.scale) * math.clamp(dt * 12, 0, 1)
		if data.state == "swell" then
			base = base * A(0, 0, math.sin(now * 40) * 0.03)
		end
	elseif kind == "puffshroom" and data.state == "swell" then
		base = base * A(0, 0, math.sin(now * 40) * 0.05)
	end

	-- noticed you: a quick hop
	local alertAge = now - data.alertAt
	if alertAge < 0.35 then
		base = CFrame.new(0, math.sin(alertAge / 0.35 * math.pi) * 1.6, 0) * base
	end
	if data.bang then
		data.bang.Enabled = alertAge < 0.8 and data.alive
	end

	-- bopped: a squashed spin into the ground, then hidden
	if not data.alive then
		local a = now - data.aliveAt
		if a < 0.35 then
			base = base * CFrame.new(0, -a * 5, 0) * A(0, a * 22, a * 2)
		else
			setHidden(data, true)
		end
	end

	-- write the parts
	local flap = 0
	if kind == "bat" then
		flap = math.sin(now * (data.state == "swoop" and 10 or 18) + data.phase) * 0.7
	end
	local jawOpen = 0.12 + math.sin(now * 2 + data.phase) * 0.05
	if kind == "snapper" then
		if data.state == "wind" then
			jawOpen = 0.65
		elseif data.state == "lunge" then
			jawOpen = stateAge < 0.12 and 0.7 or 0
		elseif data.state == "tired" then
			jawOpen = 0.35
		end
	end
	local legKick = 0
	if kind == "toad" and data.state == "hop" then
		legKick = math.sin(math.clamp(stateAge / 0.7, 0, 1) * math.pi)
	end
	local cfs = data.cfs
	for i, p in ipairs(data.parts) do
		local off = data.offsets[i]
		local role = data.roles[i]
		if role == "wing" then
			local side = off.X >= 0 and 1 or -1
			local hinge = CFrame.new(side * 1.0, 0.3, 0.1)
			off = hinge * A(0, 0, side * flap) * hinge:Inverse() * off
		elseif role == "jaw" then
			local hinge = CFrame.new(0, 3.9, 1.2)
			off = hinge * A(-jawOpen, 0, 0) * hinge:Inverse() * off
		elseif role == "leg" and legKick > 0 then
			off = off * CFrame.new(0, -legKick * 0.6, legKick * 0.9)
		end
		if data.scale ~= 1 then
			off = CFrame.new(off.Position * data.scale) * off.Rotation
			local want = data.sizes[i] * data.scale
			if (p.Size - want).Magnitude > 0.05 then
				p.Size = want
			end
		end
		cfs[i] = base * off
	end
	workspace:BulkMoveTo(data.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

local frame = 0
local function update(dt)
	frame += 1
	local now = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	local alpha = 1 - math.exp(-dt * 13)
	for model, data in pairs(tracked) do
		if not model.Parent then
			tracked[model] = nil
		elseif not (data.hidden and not data.alive) then
			local target = model:GetAttribute("CF")
			if target then
				local dist = (target.Position - camPos).Magnitude
				-- far away ones only need updating every few frames
				if dist < DRAW_DIST and (dist < 150 or (frame + data.phase * 10) % 3 < 1) then
					if (target.Position - data.cur.Position).Magnitude > 30 then
						data.cur = target -- too far behind (just came into view): snap
					else
						data.cur = data.cur:Lerp(target, alpha)
					end
					local pos = data.cur.Position
					if data.prevPos and dt > 0 then
						local flat = Vector3.new(pos.X - data.prevPos.X, 0, pos.Z - data.prevPos.Z)
						data.speed += (flat.Magnitude / dt - data.speed) * math.clamp(dt * 8, 0, 1)
					end
					data.prevPos = pos
					animate(data, data.cur, now, dt)
				end
			end
		end
	end
end

function Baddies.Init()
	task.spawn(function()
		local folder = workspace:WaitForChild("Baddies", 120)
		if not folder then
			return
		end
		for _, m in ipairs(folder:GetChildren()) do
			register(m)
		end
		folder.ChildAdded:Connect(register)
		RunService.RenderStepped:Connect(update)
	end)
end

return Baddies
