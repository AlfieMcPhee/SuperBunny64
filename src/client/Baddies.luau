--[[
	Baddies - draws every baddie smoothly on this player's screen.

	The server runs their brains and bodies and publishes, ~10 times a second:
	  CF         where the baddie's root is (position, heading, slope tilt)
	  Vel        how fast it's moving (so we can predict between updates)
	  St         what it's doing (idle, walk, chase, hop, swoop, wind, lunge...)
	  Alert      a timestamp when it spots you ("!") or loses you ("?", AlertKind)
	  Alive      false while it's been bopped

	Every frame we predict where it is now (last position + velocity * time
	since the update), glide toward that, and add the animation that has to
	be snappy: six scuttling bug legs, waddles, a rolling Thornhog, wing flaps,
	jaw snaps, puffing up, the "!" / "?" and a squash when bopped. Parts are
	moved locally only, so this costs no network traffic.
]]

local RunService = game:GetService("RunService")

local Baddies = {}

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
	t.Name = "Mark"
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
	local parts, offsets, sizes, roles, legs = {}, {}, {}, {}, {}
	local top = 2
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			local i = #parts
			local off = rest:ToObjectSpace(d.CFrame)
			offsets[i] = off
			sizes[i] = d.Size
			top = math.max(top, off.Y + d.Size.Y / 2)
			if d.Name == "Wing" or d.Name == "WingTip" then
				roles[i] = "wing"
			elseif d.Name == "BackLeg" then
				roles[i] = "leg"
			elseif d.Name == "Jaw" then
				roles[i] = "jaw"
			elseif d.Name == "Leg" and d:GetAttribute("LegSide") then
				roles[i] = "bugleg"
				-- hip (in the root's space) and gait phase for this leg
				local side = d:GetAttribute("LegSide")
				local index = d:GetAttribute("LegIndex") or 1
				legs[i] = {
					hinge = CFrame.new(side * 1.3, -0.15, d:GetAttribute("LegZ") or 0),
					phase = (index % 2 == 0) == (side > 0) and 0 or math.pi, -- tripod gait
				}
			end
		end
	end
	local cf = model:GetAttribute("CF") or rest
	local data = {
		model = model,
		kind = model:GetAttribute("Kind") or "bug",
		parts = parts,
		offsets = offsets,
		sizes = sizes,
		roles = roles,
		legs = legs,
		target = cf,
		vel = model:GetAttribute("Vel") or Vector3.zero,
		recvAt = os.clock(),
		cur = cf,
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
	model:GetAttributeChangedSignal("CF"):Connect(function()
		data.target = model:GetAttribute("CF") or data.target
		data.vel = model:GetAttribute("Vel") or Vector3.zero
		data.recvAt = os.clock()
	end)
	model:GetAttributeChangedSignal("Vel"):Connect(function()
		data.vel = model:GetAttribute("Vel") or Vector3.zero
	end)
	model:GetAttributeChangedSignal("St"):Connect(function()
		data.state = model:GetAttribute("St") or "idle"
		data.stateAt = os.clock()
	end)
	model:GetAttributeChangedSignal("Alert"):Connect(function()
		data.alertAt = os.clock()
		local mark = data.bang and data.bang:FindFirstChild("Mark")
		if mark then
			local kind = model:GetAttribute("AlertKind") or "!"
			mark.Text = kind
			mark.TextColor3 = kind == "?" and Color3.fromRGB(190, 210, 255) or Color3.fromRGB(255, 220, 90)
		end
	end)
	model:GetAttributeChangedSignal("Alive"):Connect(function()
		local alive = model:GetAttribute("Alive") ~= false
		if alive ~= data.alive then
			data.alive = alive
			data.aliveAt = os.clock()
			if alive then
				data.target = model:GetAttribute("CF") or data.target
				data.cur = data.target
				data.vel = Vector3.zero
				setHidden(data, false)
			end
		end
	end)
	if not data.alive then
		setHidden(data, true)
	end
	tracked[model] = data
end

-- Per-kind extra motion on top of the smoothed transform
local function animate(data, base, now, dt)
	local kind = data.kind
	local stateAge = now - data.stateAt
	local speed = data.speed

	-- gaits, from how fast it's actually moving
	if kind == "bug" then
		data.phase += dt * (4 + speed * 1.1)
		local f = math.clamp(speed / 12, 0, 1.2)
		base = base * CFrame.new(0, math.abs(math.sin(data.phase * 2)) * 0.12 * f + math.sin(now * 2 + data.spin) * 0.04, 0)
			* A(0, 0, math.sin(data.phase) * 0.04 * f)
	elseif kind == "mossling" then
		local f = math.clamp(speed / 10, 0, 1.4)
		if f > 0.05 then
			data.phase += dt * (6 + speed * 1.1)
			local s = math.sin(data.phase)
			base = base * CFrame.new(0, math.abs(s) * 0.3 * f, 0) * A(0, 0, s * 0.14 * f)
		else
			base = base * CFrame.new(0, math.sin(now * 2 + data.phase) * 0.06, 0)
		end
	elseif kind == "thornhog" then
		data.spin += speed * dt / 2.2
		base = base * A(-data.spin, 0, 0)
		if data.state == "skid" then
			base = base * A(0, 0, math.sin(now * 40) * 0.05)
		end
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

	-- noticed you: a quick hop for anyone who doesn't do their own
	local alertAge = now - data.alertAt
	if alertAge < 0.35 and kind ~= "bug" and kind ~= "mossling" then
		base = CFrame.new(0, math.sin(alertAge / 0.35 * math.pi) * 1.6, 0) * base
	end
	if data.bang then
		data.bang.Enabled = alertAge < 0.9 and data.alive
	end

	-- bopped: squashed flat into the ground, then gone
	local squash = 1
	if not data.alive then
		local a = now - data.aliveAt
		if a < 0.4 then
			squash = math.max(0.15, 1 - a * 4)
			base = base * CFrame.new(0, -(1 - squash) * 1.2, 0)
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
		legKick = math.sin(math.clamp(stateAge / 0.75, 0, 1) * math.pi)
	end
	local stride = math.clamp(speed / 10, 0, 1) * 0.45
	local cfs = data.cfs
	for i, p in ipairs(data.parts) do
		local off = data.offsets[i]
		local role = data.roles[i]
		if role == "bugleg" then
			local leg = data.legs[i]
			local swing = math.sin(data.phase + leg.phase) * stride
			local lift = math.max(0, math.cos(data.phase + leg.phase)) * stride * 0.6
			off = leg.hinge * A(0, swing, 0) * CFrame.new(0, lift, 0) * leg.hinge:Inverse() * off
		elseif role == "wing" then
			local side = off.X >= 0 and 1 or -1
			local hinge = CFrame.new(side * 1.0, 0.3, 0.1)
			off = hinge * A(0, 0, side * flap) * hinge:Inverse() * off
		elseif role == "jaw" then
			local hinge = CFrame.new(0, 3.9, 1.2)
			off = hinge * A(-jawOpen, 0, 0) * hinge:Inverse() * off
		elseif role == "leg" and legKick > 0 then
			off = off * CFrame.new(0, -legKick * 0.6, legKick * 0.9)
		end
		local s = data.scale
		if s ~= 1 or squash ~= 1 then
			off = CFrame.new(off.X * s, off.Y * s * squash, off.Z * s) * off.Rotation
			local want = data.sizes[i] * Vector3.new(s, s * squash, s)
			if (p.Size - want).Magnitude > 0.05 then
				p.Size = want
			end
		elseif p.Size ~= data.sizes[i] then
			p.Size = data.sizes[i]
		end
		cfs[i] = base * off
	end
	workspace:BulkMoveTo(data.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

local frame = 0
local warned = {}
local function update(dt)
	frame += 1
	dt = math.min(dt, 0.1)
	local now = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for model, data in pairs(tracked) do
		if not model.Parent then
			tracked[model] = nil
		elseif not (data.hidden and not data.alive) then
			local dist = (data.target.Position - camPos).Magnitude
			-- far away ones only need updating every few frames
			if dist < DRAW_DIST and (dist < 150 or (frame + math.floor(data.phase * 10)) % 3 == 0) then
				local stepDt = dist < 150 and dt or dt * 3
				-- predict where it is now from its last update and velocity
				local ahead = math.min(now - data.recvAt, 0.25)
				local predicted = data.target + data.vel * ahead
				local gap = (predicted.Position - data.cur.Position).Magnitude
				if gap > 25 then
					data.cur = predicted -- too far behind (just came into view): snap
				else
					local posAlpha = 1 - math.exp(-stepDt * 16)
					local rotAlpha = 1 - math.exp(-stepDt * 10)
					local pos = data.cur.Position:Lerp(predicted.Position, posAlpha)
					data.cur = CFrame.new(pos) * data.cur.Rotation:Lerp(predicted.Rotation, rotAlpha)
				end
				data.speed += (Vector3.new(data.vel.X, 0, data.vel.Z).Magnitude - data.speed) * math.clamp(stepDt * 8, 0, 1)
				local ok, err = pcall(animate, data, data.cur, now, stepDt)
				if not ok and not warned[data.kind] then
					warned[data.kind] = true
					warn("[Bunny64] Baddies (" .. data.kind .. "): " .. tostring(err))
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
