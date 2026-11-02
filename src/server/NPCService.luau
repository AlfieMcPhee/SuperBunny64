--[[
	NPCService - builds the friendly characters and their "Talk" prompts.
	What they say lives in Config.NPCs and is shown by client/Dialogue.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local BunnyModel = require(Shared:WaitForChild("BunnyModel"))
local P = Config.Palette

local NPCService = {}

local rgb = Color3.fromRGB

local function part(model, cf, size, color, ball, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if ball then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	end
	p.Parent = model
	return p
end

local function eyes(model, base, y, z, spread, size)
	for _, sx in ipairs({ -1, 1 }) do
		local e = part(model, base * CFrame.new(sx * spread, y, z), Vector3.new(size, size * 1.2, size * 0.5), P.Button, true)
		e.Reflectance = 0.2
		part(model, base * CFrame.new(sx * spread * 0.9, y + size * 0.2, z - size * 0.25), Vector3.one * size * 0.3, rgb(240, 236, 228), true)
	end
end

-- Each builder makes a figure facing -Z with its feet at `base`
local BUILD = {}

function BUILD.tortoise(model, base)
	part(model, base * CFrame.new(0, 2.2, 0.4), Vector3.new(5.5, 3.6, 6), rgb(96, 110, 70), true) -- shell
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		part(model, base * CFrame.new(math.cos(a) * 1.6, 3.6, 0.4 + math.sin(a) * 1.8), Vector3.new(1.4, 0.4, 1.4), rgb(124, 138, 86), true)
	end
	part(model, base * CFrame.new(0, 1.1, 0.4), Vector3.new(5.2, 1.2, 5.8), rgb(196, 176, 120), true) -- belly rim
	part(model, base * CFrame.new(0, 2.6, -3.4), Vector3.new(2.2, 2, 2.4), rgb(150, 160, 104), true) -- head
	eyes(model, base, 2.9, -4.4, 0.5, 0.45)
	-- spectacles
	for _, sx in ipairs({ -1, 1 }) do
		part(model, base * CFrame.new(sx * 0.5, 2.95, -4.55), Vector3.new(0.7, 0.7, 0.08), rgb(170, 140, 70), false, Enum.Material.Metal).Transparency = 0.5
	end
	for _, l in ipairs({ { -1.8, -1.6 }, { 1.8, -1.6 }, { -1.8, 2.2 }, { 1.8, 2.2 } }) do
		part(model, base * CFrame.new(l[1], 0.5, l[2]), Vector3.new(1.2, 1.2, 1.2), rgb(150, 160, 104), true)
	end
	-- walking stick
	part(model, base * CFrame.new(2.6, 2.2, -2.2) * CFrame.Angles(0, 0, 0.15), Vector3.new(0.3, 4.4, 0.3), P.Wood, false, Enum.Material.Wood)
end

function BUILD.penguin(model, base)
	part(model, base * CFrame.new(0, 2.2, 0), Vector3.new(3.2, 4.2, 3), rgb(36, 38, 48), true)
	part(model, base * CFrame.new(0, 2.0, -0.9), Vector3.new(2.3, 3.2, 1.6), rgb(236, 236, 240), true)
	part(model, base * CFrame.new(0, 4.4, -0.1), Vector3.new(2.6, 2.4, 2.5), rgb(36, 38, 48), true)
	eyes(model, base, 4.6, -1.2, 0.5, 0.42)
	part(model, base * CFrame.new(0, 4.2, -1.45), Vector3.new(0.7, 0.4, 0.9), rgb(232, 150, 50), true)
	part(model, base * CFrame.new(0, 3.35, 0), Vector3.new(2.7, 0.6, 2.6), rgb(150, 52, 60), false, Enum.Material.Fabric) -- scarf
	part(model, base * CFrame.new(0.9, 2.7, -1.1) * CFrame.Angles(0, 0, 0.2), Vector3.new(0.5, 1.4, 0.2), rgb(150, 52, 60), false, Enum.Material.Fabric)
	for _, sx in ipairs({ -1, 1 }) do
		part(model, base * CFrame.new(sx * 1.6, 2.3, 0) * CFrame.Angles(0, 0, sx * 0.35), Vector3.new(0.5, 2.2, 1.2), rgb(36, 38, 48), true)
		part(model, base * CFrame.new(sx * 0.6, 0.15, -0.6), Vector3.new(1, 0.3, 1.4), rgb(232, 150, 50), true)
	end
end

function BUILD.mole(model, base)
	part(model, base * CFrame.new(0, 2.0, 0), Vector3.new(3.8, 3.8, 3.6), rgb(88, 70, 62), true)
	part(model, base * CFrame.new(0, 1.8, -1.2), Vector3.new(2.6, 2.6, 1.6), rgb(150, 124, 108), true)
	part(model, base * CFrame.new(0, 3.9, -0.3), Vector3.new(2.8, 2.4, 2.6), rgb(88, 70, 62), true)
	part(model, base * CFrame.new(0, 3.6, -1.75), Vector3.new(0.9, 0.7, 0.8), rgb(220, 140, 150), true) -- nose
	for _, sx in ipairs({ -1, 1 }) do
		part(model, base * CFrame.new(sx * 0.5, 4.25, -1.35), Vector3.new(0.35, 0.12, 0.1), P.Button) -- squinty eyes
		part(model, base * CFrame.new(sx * 2.0, 1.4, -0.9), Vector3.new(1.4, 0.6, 1.2), rgb(220, 160, 160), true) -- big paws
	end
	part(model, base * CFrame.new(0, 5.1, -0.3), Vector3.new(3.0, 1.2, 2.8), rgb(196, 160, 60), true, Enum.Material.Metal) -- helmet
	local lamp = part(model, base * CFrame.new(0, 5.4, -1.6), Vector3.new(0.7, 0.7, 0.4), rgb(255, 236, 170), true, Enum.Material.Neon)
	local light = Instance.new("SpotLight")
	light.Range = 18
	light.Brightness = 1.5
	light.Face = Enum.NormalId.Front
	light.Parent = lamp
	part(model, base * CFrame.new(2.4, 2.4, 0.4) * CFrame.Angles(0, 0, -0.4), Vector3.new(0.25, 4, 0.25), P.Wood, false, Enum.Material.Wood) -- pickaxe handle
	part(model, base * CFrame.new(3.2, 4.1, 0.4) * CFrame.Angles(0, 0, 0.8), Vector3.new(0.3, 2.2, 0.3), rgb(140, 140, 146), false, Enum.Material.Metal)
end

function BUILD.mouse(model, base)
	part(model, base * CFrame.new(0, 2.0, 0), Vector3.new(2.8, 3.4, 2.6), rgb(150, 146, 150), true)
	part(model, base * CFrame.new(0, 1.8, -0.9), Vector3.new(1.8, 2.4, 1.2), rgb(226, 214, 210), true)
	part(model, base * CFrame.new(0, 4.1, -0.2), Vector3.new(2.4, 2.2, 2.4), rgb(150, 146, 150), true)
	for _, sx in ipairs({ -1, 1 }) do
		part(model, base * CFrame.new(sx * 1.3, 5.2, 0), Vector3.new(1.8, 1.8, 0.3), rgb(150, 146, 150), true)
		part(model, base * CFrame.new(sx * 1.3, 5.2, -0.12), Vector3.new(1.2, 1.2, 0.2), rgb(226, 170, 176), true)
	end
	eyes(model, base, 4.3, -1.2, 0.45, 0.4)
	part(model, base * CFrame.new(0, 3.85, -1.45), Vector3.new(0.4, 0.35, 0.35), rgb(220, 140, 150), true)
	part(model, base * CFrame.new(0, 5.2, -0.2), Vector3.new(2.5, 0.9, 2.5), rgb(130, 130, 136), true, Enum.Material.Metal) -- helmet
	part(model, base * CFrame.new(1.7, 3, -0.4), Vector3.new(0.2, 6, 0.2), P.Wood, false, Enum.Material.Wood) -- spear
	part(model, base * CFrame.new(1.7, 6.3, -0.4) * CFrame.Angles(0, 0, math.pi / 4), Vector3.new(0.6, 0.6, 0.15), rgb(170, 170, 176), false, Enum.Material.Metal)
	part(model, base * CFrame.new(0, 0.8, 1.6) * CFrame.Angles(0.8, 0, 0), Vector3.new(0.2, 2.6, 0.2), rgb(226, 170, 176)) -- tail
end

function BUILD.knightbug(model, base)
	part(model, base * CFrame.new(0, 2.6, 0.4), Vector3.new(3.6, 4.4, 3.4), rgb(62, 54, 58), true)
	part(model, base * CFrame.new(0, 2.5, -0.9), Vector3.new(2.6, 3.4, 1.4), rgb(150, 140, 136), true, Enum.Material.Metal) -- breastplate
	part(model, base * CFrame.new(0, 5.2, -0.4), Vector3.new(2.6, 2.4, 2.4), rgb(140, 140, 146), true, Enum.Material.Metal) -- helmet
	part(model, base * CFrame.new(0, 5.1, -1.55), Vector3.new(1.8, 0.3, 0.2), rgb(30, 24, 24)) -- visor slit
	for _, sx in ipairs({ -1, 1 }) do
		part(model, base * CFrame.new(sx * 0.45, 5.1, -1.6), Vector3.new(0.3, 0.2, 0.1), P.Ember, false, Enum.Material.Neon)
	end
	part(model, base * CFrame.new(0, 6.7, -0.2) * CFrame.Angles(-0.3, 0, 0), Vector3.new(0.4, 1.8, 1.4), rgb(150, 50, 50), false, Enum.Material.Fabric) -- plume
	part(model, base * CFrame.new(-2.1, 2.6, -0.6), Vector3.new(0.5, 2.8, 2.2), rgb(110, 40, 40), true, Enum.Material.Metal) -- shield
	part(model, base * CFrame.new(2.0, 2.9, -0.8), Vector3.new(0.25, 4.6, 0.25), rgb(180, 180, 186), false, Enum.Material.Metal) -- sword
	for _, sx in ipairs({ -1, 1 }) do
		part(model, base * CFrame.new(sx * 0.8, 0.5, 0.2), Vector3.new(0.8, 1.2, 1.2), rgb(62, 54, 58), true)
	end
end

local function build(def, spec)
	local model = Instance.new("Model")
	model.Name = "NPC_" .. def.id
	local flatFacing = (def.facing * Vector3.new(1, 0, 1)).Unit
	local base = CFrame.lookAt(def.pos, def.pos + flatFacing) -- front (-Z) faces `facing`
	if spec.kind == "granny" then
		local bunny = BunnyModel.BuildPreview({ fur = 4, accent = 5, hat = "flowers", neck = "scarf" })
		bunny:PivotTo(base * CFrame.new(0, 2.6, 0))
		for _, d in ipairs(bunny:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		bunny.Parent = model
	else
		(BUILD[spec.kind] or BUILD.tortoise)(model, base)
	end
	-- an invisible anchor that holds the prompt and lets the dialogue know who's talking
	local anchor = part(model, base * CFrame.new(0, 3, 0), Vector3.new(3, 5, 3), Color3.new())
	anchor.Name = "TalkAnchor"
	anchor.Transparency = 1
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Talk"
	prompt.ObjectText = spec.name
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("NpcId", def.id)
	prompt.Parent = anchor
	model.PrimaryPart = anchor
	return model
end

function NPCService.Start(info)
	local folder = Instance.new("Folder")
	folder.Name = "Friends"
	folder.Parent = workspace
	for _, def in ipairs(info.npcs) do
		local spec = Config.NPCs[def.id]
		if spec then
			local ok, model = pcall(build, def, spec)
			if ok then
				model.Parent = folder
			else
				warn("[Bunny64] Couldn't build NPC " .. def.id .. ": " .. tostring(model))
			end
		end
	end
end

return NPCService
