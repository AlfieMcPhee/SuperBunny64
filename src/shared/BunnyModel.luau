--[[
	BunnyModel - builds the plush bunny teddy rig and dresses it.

	The rig is a proper custom character: a HumanoidRootPart, a round body,
	big head, stubby arms and legs and floppy ears, all joined with Motor6Ds
	so the client can animate it procedurally (see client/Animator).

	Front of the bunny is -Z. Feet rest at Y = 0 when built.
	Parts carry a "Paint" attribute (fur / cream / pink / accent) so a
	customisation can recolour them without rebuilding.
]]

local Config = require(script.Parent:WaitForChild("Config"))
local P = Config.Palette

local BunnyModel = {}

local SPHERE = Enum.MeshType.Sphere
local FABRIC = Enum.Material.Fabric
local SMOOTH = Enum.Material.SmoothPlastic

local function newPart(parent, name, cf, size, shape, paint, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Material = material or FABRIC
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	if shape == "ball" then
		local m = Instance.new("SpecialMesh")
		m.MeshType = SPHERE
		m.Parent = p
	elseif shape == "cyl" then
		p.Shape = Enum.PartType.Cylinder
	end
	if type(paint) == "string" then
		p:SetAttribute("Paint", paint)
	elseif typeof(paint) == "Color3" then
		p.Color = paint
	end
	p.Parent = parent
	return p
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function motor(name, part0, part1, pivot)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:Inverse() * pivot
	m.C1 = part1.CFrame:Inverse() * pivot
	m.Parent = part1
	return m
end

local CF = CFrame.new
local V = Vector3.new
local ROT = CFrame.Angles

-- Vertical cylinder helper (Roblox cylinders run along X)
local function vcyl(cf)
	return cf * ROT(0, 0, math.pi / 2)
end

--------------------------------------------------------------------------------
-- Rig
--------------------------------------------------------------------------------

function BunnyModel.Build()
	local model = Instance.new("Model")
	model.Name = "Bunny"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = V(2, 2, 1)
	root.CFrame = CF(0, 2.6, 0)
	root.Transparency = 1
	root.CanCollide = true
	root.Parent = model
	model.PrimaryPart = root

	-- Body
	local torso = newPart(model, "Torso", CF(0, 2.1, 0), V(2.5, 2.35, 2.2), "ball", "fur")
	newPart(model, "Belly", CF(0, 1.95, -0.92), V(1.65, 1.6, 0.55), "ball", "cream")
	newPart(model, "Tail", CF(0, 1.5, 1.05), V(0.95, 0.95, 0.95), "ball", "cream")
	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("BasePart") and d ~= torso and d ~= root then
			weld(torso, d)
		end
	end

	-- Head
	local head = newPart(model, "Head", CF(0, 4.25, 0), V(2.75, 2.45, 2.45), "ball", "fur")
	local headBits = {
		newPart(model, "Muzzle", CF(0, 3.9, -1.0), V(1.4, 0.9, 0.75), "ball", "cream"),
		newPart(model, "Nose", CF(0, 4.17, -1.36), V(0.4, 0.27, 0.26), "ball", "pink", SMOOTH),
		newPart(model, "Mouth", CF(0, 3.8, -1.37), V(0.07, 0.24, 0.05), "block", P.Ink, SMOOTH),
	}
	for _, sx in ipairs({ -1, 1 }) do
		local eye = newPart(model, "Eye", CF(sx * 0.5, 4.5, -1.08) * ROT(0, sx * 0.25, 0), V(0.36, 0.5, 0.22), "ball", P.Button, SMOOTH)
		eye.Reflectance = 0.15
		table.insert(headBits, eye)
		table.insert(headBits, newPart(model, "EyeShine", CF(sx * 0.45, 4.6, -1.2), V(0.12, 0.13, 0.05), "ball", Color3.fromRGB(240, 236, 228), SMOOTH))
		local cheek = newPart(model, "Cheek", CF(sx * 0.86, 4.0, -0.9), V(0.48, 0.26, 0.12), "ball", "pink", SMOOTH)
		cheek.Transparency = 0.45
		table.insert(headBits, cheek)
	end
	for _, b in ipairs(headBits) do
		weld(head, b)
	end
	motor("Neck", torso, head, CF(0, 3.15, 0))

	-- Ears (two segments each: base and a floppy tip feel via inner lining)
	for _, sx in ipairs({ -1, 1 }) do
		local base = CF(sx * 0.55, 5.15, 0.1) * ROT(-0.12, 0, sx * -0.2)
		local ear = newPart(model, sx < 0 and "LeftEar" or "RightEar", base * CF(0, 1.25, 0), V(0.82, 2.65, 0.48), "ball", "fur")
		local inner = newPart(model, "EarInner", base * CF(0, 1.15, -0.13), V(0.46, 2.0, 0.24), "ball", "pink")
		weld(ear, inner)
		if sx > 0 then
			local patch = newPart(model, "EarPatch", base * CF(0, 1.55, 0.2) * ROT(0, 0, 0.3), V(0.4, 0.4, 0.08), "block", P.Patch)
			weld(ear, patch)
		end
		motor(sx < 0 and "LeftEarJoint" or "RightEarJoint", head, ear, base)
	end

	-- Arms
	for _, sx in ipairs({ -1, 1 }) do
		local arm = newPart(model, sx < 0 and "LeftArm" or "RightArm", CF(sx * 1.18, 2.25, 0) * ROT(0, 0, sx * 0.15), V(0.82, 1.4, 0.82), "ball", "fur")
		local paw = newPart(model, "Paw", CF(sx * 1.27, 1.65, -0.05), V(0.78, 0.66, 0.8), "ball", "cream")
		weld(arm, paw)
		motor(sx < 0 and "LeftShoulder" or "RightShoulder", torso, arm, CF(sx * 1.05, 2.8, 0))
	end

	-- Legs & big feet
	for _, sx in ipairs({ -1, 1 }) do
		local leg = newPart(model, sx < 0 and "LeftLeg" or "RightLeg", CF(sx * 0.58, 0.95, 0), V(0.98, 1.05, 0.98), "ball", "fur")
		local foot = newPart(model, "Foot", CF(sx * 0.6, 0.3, -0.28), V(1.02, 0.6, 1.6), "ball", "fur")
		local pad = newPart(model, "FootPad", CF(sx * 0.6, 0.32, 0.5), V(0.62, 0.42, 0.1), "ball", "pink", SMOOTH)
		weld(leg, foot)
		weld(leg, pad)
		motor(sx < 0 and "LeftHip" or "RightHip", torso, leg, CF(sx * 0.58, 1.35, 0))
	end

	motor("RootJoint", root, torso, CF(0, 2.1, 0))

	local cosmetics = Instance.new("Folder")
	cosmetics.Name = "Cosmetics"
	cosmetics.Parent = model
	model:SetAttribute("Bunny", true)
	return model
end

-- Character version with a Humanoid (used as StarterPlayer.StarterCharacter)
function BunnyModel.BuildCharacter()
	local model = BunnyModel.Build()
	model.Name = "StarterCharacter"
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = 1.6
	hum.AutomaticScalingEnabled = false
	hum.BreakJointsOnDeath = false
	hum.MaxHealth = Config.MaxHearts
	hum.Health = Config.MaxHearts
	hum.WalkSpeed = Config.WalkSpeed
	hum.UseJumpPower = true
	hum.JumpPower = Config.JumpPower
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	hum.NameDisplayDistance = 60
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.Parent = model
	local animator = Instance.new("Animator")
	animator.Parent = hum
	return model
end

-- Anchored copy for menus / viewports
function BunnyModel.BuildPreview(custom)
	local model = BunnyModel.Build()
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	BunnyModel.Apply(model, custom)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return model
end

--------------------------------------------------------------------------------
-- Cosmetics
--------------------------------------------------------------------------------

local function sanitize(custom)
	custom = type(custom) == "table" and custom or {}
	local out = {}
	out.fur = Config.FurColors[custom.fur] and custom.fur or Config.DefaultCustom.fur
	out.accent = Config.AccentColors[custom.accent] and custom.accent or Config.DefaultCustom.accent
	out.hat = Config.DefaultCustom.hat
	for _, h in ipairs(Config.Hats) do
		if h.id == custom.hat then
			out.hat = h.id
		end
	end
	out.neck = Config.DefaultCustom.neck
	for _, n in ipairs(Config.Necks) do
		if n.id == custom.neck then
			out.neck = n.id
		end
	end
	return out
end
BunnyModel.Sanitize = sanitize

-- Each entry: { shape, cframe (local to anchor part), size, color key or Color3, material, name }
local function hatSpec(id)
	local s = {}
	local function add(shape, cf, size, color, material, name)
		table.insert(s, { shape = shape, cf = cf, size = size, color = color, material = material, name = name })
	end
	if id == "straw" then
		local tilt = ROT(-0.12, 0, 0.1)
		local straw = Color3.fromRGB(198, 172, 112)
		add("cyl", tilt * vcyl(CF(0, 1.05, 0)), V(0.14, 3.6, 3.6), straw)
		add("cyl", tilt * vcyl(CF(0, 1.42, 0)), V(0.75, 2.05, 2.05), straw)
		add("cyl", tilt * vcyl(CF(0, 1.2, 0)), V(0.22, 2.1, 2.1), "accent")
	elseif id == "beanie" then
		add("ball", CF(0, 0.9, 0.05), V(2.8, 1.75, 2.7), "accent")
		add("cyl", vcyl(CF(0, 0.5, 0.02)), V(0.38, 2.85, 2.75), Color3.fromRGB(222, 212, 192))
		add("ball", CF(0, 1.85, 0.05), V(0.75, 0.75, 0.75), Color3.fromRGB(236, 230, 218))
	elseif id == "carrot" then
		for i = -1, 1 do
			add("block", CF(i * 0.28, 1.65, -0.35) * ROT(0.15, i * 0.4, -i * 0.35), V(0.32, 1.4, 0.55), P.CarrotLeaf, nil)
		end
		add("ball", CF(0, 1.05, -0.35), V(0.6, 0.45, 0.6), P.Carrot)
	elseif id == "tophat" then
		local base = CF(0.15, 1.12, -0.5) * ROT(-0.22, 0, -0.14)
		local black = Color3.fromRGB(38, 34, 36)
		add("cyl", base * vcyl(CF()), V(0.12, 2.0, 2.0), black, SMOOTH)
		add("cyl", base * vcyl(CF(0, 0.78, 0)), V(1.5, 1.35, 1.35), black, SMOOTH)
		add("cyl", base * vcyl(CF(0, 0.22, 0)), V(0.28, 1.38, 1.38), "accent", SMOOTH)
	elseif id == "flowers" then
		local cols = { Color3.fromRGB(214, 170, 176), Color3.fromRGB(226, 206, 140), Color3.fromRGB(236, 230, 220), Color3.fromRGB(176, 150, 196) }
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			add("ball", CF(math.cos(a) * 1.2, 0.95 + math.sin(a * 2) * 0.05, math.sin(a) * 1.15), V(0.42, 0.3, 0.42), cols[i % 4 + 1], SMOOTH)
			add("ball", CF(math.cos(a + 0.3) * 1.25, 0.9, math.sin(a + 0.3) * 1.2), V(0.3, 0.12, 0.2), P.Leaf, SMOOTH)
		end
	elseif id == "propeller" then
		add("ball", CF(0, 0.95, 0.05), V(2.65, 1.35, 2.6), "accent")
		add("block", CF(0, 0.62, -1.25) * ROT(0.15, 0, 0), V(1.5, 0.12, 0.9), "accent")
		add("cyl", vcyl(CF(0, 1.7, 0.05)), V(0.5, 0.16, 0.16), Color3.fromRGB(200, 196, 190), SMOOTH)
		add("block", CF(0, 1.95, 0.05), V(2.3, 0.07, 0.38), Color3.fromRGB(214, 172, 72), SMOOTH, "Propeller")
	elseif id == "viking" then
		local metal = Color3.fromRGB(140, 138, 134)
		add("ball", CF(0, 0.8, 0.02), V(2.85, 1.85, 2.8), metal, Enum.Material.Metal)
		add("cyl", vcyl(CF(0, 0.32, 0.02)), V(0.32, 2.9, 2.85), Color3.fromRGB(150, 112, 64), Enum.Material.Metal)
		for _, sx in ipairs({ -1, 1 }) do
			add("cyl", CF(sx * 1.55, 1.1, 0) * ROT(0, 0, sx * -0.75), V(1.5, 0.45, 0.45), Color3.fromRGB(224, 214, 190), SMOOTH)
			add("ball", CF(sx * 2.05, 1.65, 0), V(0.32, 0.5, 0.32), Color3.fromRGB(224, 214, 190), SMOOTH)
		end
	elseif id == "wizard" then
		local blue = Color3.fromRGB(54, 60, 108)
		add("cyl", vcyl(CF(0, 1.0, 0)), V(0.12, 3.0, 3.0), blue)
		local x = 0
		for i = 1, 5 do
			x += i * 0.05
			local r = 1.95 - i * 0.33
			add("cyl", vcyl(CF(x, 1.0 + i * 0.55, 0.1 * i)), V(0.58, r, r), blue)
		end
		add("ball", CF(x + 0.15, 3.95, 0.5), V(0.35, 0.35, 0.35), P.Gold, SMOOTH)
		add("ball", CF(0.5, 1.55, -0.62), V(0.32, 0.32, 0.12), P.Gold, SMOOTH)
	elseif id == "leafcap" then
		-- a big forest leaf worn like a cap, stalk and all
		local leaf = Color3.fromRGB(96, 128, 64)
		add("ball", CF(0, 0.92, 0.1) * ROT(-0.12, 0, 0), V(2.9, 0.75, 3.2), leaf, SMOOTH)
		add("ball", CF(0, 0.98, -1.25) * ROT(-0.35, 0, 0), V(1.7, 0.3, 1.4), leaf, SMOOTH)
		add("block", CF(0, 1.32, 0.15), V(0.12, 0.08, 3.0), Color3.fromRGB(150, 172, 96), SMOOTH)
		add("block", CF(0.1, 1.45, 1.6) * ROT(0.6, 0, 0), V(0.16, 0.16, 0.9), Color3.fromRGB(110, 86, 54), SMOOTH)
	elseif id == "pilot" then
		-- leather flying cap with goggles
		local leather = Color3.fromRGB(122, 84, 56)
		add("ball", CF(0, 0.9, 0.05), V(2.8, 1.6, 2.75), leather, Enum.Material.Leather)
		for _, sx in ipairs({ -1, 1 }) do
			add("block", CF(sx * 1.3, 0.3, 0.1) * ROT(0, 0, sx * 0.12), V(0.25, 1.1, 0.9), leather, Enum.Material.Leather)
			add("cyl", CF(sx * 0.5, 1.2, -1.15) * ROT(0, math.pi / 2, 0), V(0.3, 0.75, 0.75), Color3.fromRGB(140, 120, 70), Enum.Material.Metal)
			add("cyl", CF(sx * 0.5, 1.2, -1.32) * ROT(0, math.pi / 2, 0), V(0.06, 0.55, 0.55), Color3.fromRGB(150, 190, 200), Enum.Material.Glass)
		end
		add("block", CF(0, 1.25, -1.1), V(1.0, 0.18, 0.2), Color3.fromRGB(60, 46, 36), SMOOTH)
	elseif id == "rootcrown" then
		-- twisting roots with little leaves
		for i = 0, 6 do
			local a = i / 7 * math.pi * 2
			add("block", CF(math.cos(a) * 0.95, 1.25, math.sin(a) * 0.95) * ROT(0, -a, 0.35) * ROT(0.25, 0, 0), V(0.25, 1.1, 0.25), Color3.fromRGB(96, 72, 52), SMOOTH)
			if i % 2 == 0 then
				add("ball", CF(math.cos(a) * 1.15, 1.85, math.sin(a) * 1.15), V(0.5, 0.2, 0.32), Color3.fromRGB(110, 150, 76), SMOOTH)
			end
		end
		add("cyl", vcyl(CF(0, 0.85, 0)), V(0.28, 2.2, 2.2), Color3.fromRGB(82, 62, 44), SMOOTH)
	elseif id == "stormcap" then
		-- a tiny grumpy storm cloud that follows you around
		local grey = Color3.fromRGB(150, 154, 170)
		add("ball", CF(0, 2.2, 0), V(1.8, 0.9, 1.4), grey, SMOOTH)
		add("ball", CF(-0.7, 2.1, 0.1), V(1.1, 0.8, 1.0), Color3.fromRGB(170, 174, 190), SMOOTH)
		add("ball", CF(0.75, 2.15, -0.05), V(1.2, 0.85, 1.0), Color3.fromRGB(130, 134, 150), SMOOTH)
		add("block", CF(0.15, 1.55, 0) * ROT(0, 0, 0.4), V(0.12, 0.6, 0.12), Color3.fromRGB(250, 230, 130), Enum.Material.Neon)
		add("block", CF(0.05, 1.25, 0) * ROT(0, 0, -0.4), V(0.12, 0.5, 0.12), Color3.fromRGB(250, 230, 130), Enum.Material.Neon)
	elseif id == "halo" then
		-- a ring of dark violet lights floating over your ears
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			add("ball", CF(math.cos(a) * 1.1, 2.6, math.sin(a) * 1.1), V(0.32, 0.32, 0.32), Color3.fromRGB(170, 120, 240), Enum.Material.Neon)
		end
	elseif id == "crown" then
		add("cyl", vcyl(CF(0, 1.0, 0)), V(0.42, 2.1, 2.1), P.Gold, Enum.Material.Metal)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			add("block", CF(math.cos(a) * 0.92, 1.42, math.sin(a) * 0.92) * ROT(0, -a, 0), V(0.22, 0.55, 0.3), P.Gold, Enum.Material.Metal)
		end
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2 + 0.4
			add("ball", CF(math.cos(a) * 1.05, 1.02, math.sin(a) * 1.05), V(0.24, 0.24, 0.24), Color3.fromRGB(150, 46, 52), SMOOTH)
		end
	end
	return s
end

local function neckSpec(id)
	local s = {}
	local function add(shape, cf, size, color, material)
		table.insert(s, { shape = shape, cf = cf, size = size, color = color, material = material })
	end
	if id == "bow" then
		add("ball", CF(-0.4, 0.95, -0.98) * ROT(0, 0, 0.35), V(0.78, 0.52, 0.36), "accent")
		add("ball", CF(0.4, 0.95, -0.98) * ROT(0, 0, -0.35), V(0.78, 0.52, 0.36), "accent")
		add("ball", CF(0, 0.95, -1.07), V(0.32, 0.32, 0.3), "accent")
	elseif id == "scarf" then
		add("cyl", vcyl(CF(0, 0.98, 0)), V(0.5, 2.35, 2.25), "accent")
		add("block", CF(0.5, 0.35, -1.0) * ROT(-0.1, 0, 0.12), V(0.55, 1.15, 0.18), "accent")
		add("block", CF(0.55, -0.15, -1.04) * ROT(-0.1, 0, 0.12), V(0.55, 0.08, 0.2), Color3.fromRGB(226, 214, 190))
	elseif id == "bell" then
		add("cyl", vcyl(CF(0, 0.98, 0)), V(0.26, 2.3, 2.2), "accent")
		add("ball", CF(0, 0.65, -1.12), V(0.55, 0.55, 0.55), P.Gold, Enum.Material.Metal)
	end
	return s
end

local function colorFor(key, custom)
	if typeof(key) == "Color3" then
		return key
	end
	local fur = Config.FurColors[custom.fur]
	if key == "fur" then
		return fur.fur
	elseif key == "cream" then
		return fur.cream
	elseif key == "pink" then
		return P.EarPink
	elseif key == "accent" then
		return Config.AccentColors[custom.accent].color
	end
	return Color3.new(1, 1, 1)
end

local function buildSpec(folder, anchor, spec, custom)
	for _, e in ipairs(spec) do
		local p = newPart(folder, e.name or "Cosmetic", anchor.CFrame * e.cf, e.size, e.shape, nil, e.material)
		p.Color = colorFor(e.color, custom)
		p.Anchored = anchor.Anchored
		weld(anchor, p)
	end
end

function BunnyModel.Apply(model, custom)
	custom = sanitize(custom)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local paint = d:GetAttribute("Paint")
			if paint then
				d.Color = colorFor(paint, custom)
			end
		end
	end
	local folder = model:FindFirstChild("Cosmetics")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Cosmetics"
		folder.Parent = model
	end
	folder:ClearAllChildren()
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("Torso")
	if head then
		buildSpec(folder, head, hatSpec(custom.hat), custom)
	end
	if torso then
		buildSpec(folder, torso, neckSpec(custom.neck), custom)
	end
	model:SetAttribute("Hat", custom.hat)
	return custom
end

-- Is a cosmetic unlocked? progress = {
--   goldens = best golden count, boss = beat King Grumble, bosses = { [id] = true },
--   owned = { [id] = true } (bought with carrot coins), passes = { [key] = true } (Robux) }
-- An entry can ask for: need (golden carrots), boss = true (the King) or a boss id,
-- price (carrot coins in the shop) or pass (a game pass key from Config.GamePasses).
function BunnyModel.EntryUnlocked(e, progress)
	if not e then
		return false
	end
	progress = progress or {}
	if e.boss == true and not progress.boss then
		return false
	elseif type(e.boss) == "string" and not (progress.bosses and progress.bosses[e.boss]) then
		return false
	end
	if e.pass and not (progress.passes and progress.passes[e.pass]) then
		return false
	end
	if e.price and not (progress.owned and progress.owned[e.id or e.name]) then
		return false
	end
	return (progress.goldens or 0) >= (e.need or 0)
end

function BunnyModel.IsUnlocked(list, id, progress)
	for _, e in ipairs(list) do
		if e.id == id then
			return BunnyModel.EntryUnlocked(e, progress)
		end
	end
	return false
end

-- Why is it locked? (shown in the Customise menu)
function BunnyModel.LockReason(e)
	if e.pass then
		local pass = Config.GamePasses and Config.GamePasses[e.pass]
		return pass and pass.name or "SUPPORTER PACK"
	elseif e.price then
		return string.format("%d COINS IN THE SHOP", e.price)
	elseif type(e.boss) == "string" then
		for _, b in ipairs(Config.Bosses or {}) do
			if b.id == e.boss then
				return "BEAT " .. b.name
			end
		end
		return "BEAT A SECRET BOSS"
	elseif e.boss then
		return "BEAT THE KING"
	end
	return string.format("%d GOLDEN", e.need or 0)
end

return BunnyModel
