--[[
	BugModel - builds a Grumblebug: a round beetle with split wing cases,
	a shield-shaped thorax, mandibles, glossy eyes under a cross brow,
	clubbed antennae and six two-part legs.

	Front is -Z, feet at Y = 0 (before scaling). Returns model, legs list
	and the root part. `scale` lets the boss reuse the same design.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local BugModel = {}

local SMOOTH = Enum.Material.SmoothPlastic

function BugModel.Build(skinName, scale, origin)
	local skin = Config.BugSkins[skinName] or Config.BugSkins.meadow
	scale = scale or 1
	origin = origin or CFrame.new()
	local model = Instance.new("Model")
	model.Name = "Grumblebug"
	local legs = {}

	local function part(cf, size, color, ball, material, name)
		local p = Instance.new("Part")
		p.Name = name or "Part"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = size * scale
		p.CFrame = origin * CFrame.new(cf.Position * scale) * (cf - cf.Position)
		p.Color = color
		p.Material = material or SMOOTH
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
	local CF, V, R = CFrame.new, Vector3.new, CFrame.Angles

	local root = part(CF(0, 1.8, 0), V(4, 3, 6), skin.shell, false, nil, "Root")
	root.Transparency = 1
	model.PrimaryPart = root

	-- underside & wing cases
	part(CF(0, 1.15, 0.3), V(3.9, 1.1, 5.8), skin.body, true)
	for _, sx in ipairs({ -1, 1 }) do
		part(CF(sx * 1.02, 2.05, 0.9) * R(0, 0, sx * -0.12), V(2.25, 2.4, 5.0), skin.shell, true, nil, "Shell")
		part(CF(sx * 1.25, 2.75, 1.6), V(0.85, 0.32, 1.1), skin.spot, true, skinName == "castle" and Enum.Material.Neon or SMOOTH)
		part(CF(sx * 0.9, 2.55, -0.1), V(0.6, 0.28, 0.75), skin.spot, true, skinName == "castle" and Enum.Material.Neon or SMOOTH)
	end
	part(CF(0, 3.1, 1.0), V(0.16, 0.2, 4.4), skin.body) -- wing seam
	-- thorax shield
	part(CF(0, 2.1, -1.75), V(3.2, 1.75, 1.9), skin.shell2, true)
	-- head
	part(CF(0, 1.65, -2.9), V(2.0, 1.55, 1.6), skin.body, true, nil, "Head")
	for _, sx in ipairs({ -1, 1 }) do
		-- eyes with a glint
		local eye = part(CF(sx * 0.62, 2.0, -3.45), V(0.62, 0.72, 0.5), Config.Palette.Button, true)
		eye.Reflectance = 0.2
		part(CF(sx * 0.58, 2.12, -3.7), V(0.2, 0.2, 0.08), skin.eye, true, Enum.Material.Neon)
		-- cross brow
		part(CF(sx * 0.55, 2.42, -3.5) * R(0, 0, sx * 0.38), V(0.95, 0.22, 0.32), skin.body)
		-- mandibles
		part(CF(sx * 0.42, 1.25, -3.75) * R(0, sx * 0.55, 0), V(0.3, 0.28, 1.0), skin.shell2)
		-- antenna: stalk + club
		part(CF(sx * 0.42, 2.7, -3.55) * R(-0.75, 0, sx * -0.35), V(0.14, 1.5, 0.14), skin.body)
		part(CF(sx * 0.72, 3.25, -4.15), V(0.38, 0.38, 0.38), skin.body, true)
		-- legs: thigh angled up and out, shin down to the ground
		for i, z in ipairs({ -1.4, 0.3, 1.9 }) do
			local thigh = part(CF(sx * 2.05, 1.65, z) * R(0, 0, sx * 0.45), V(1.5, 0.34, 0.34), skin.body)
			local shin = part(CF(sx * 2.75, 0.75, z + (i - 2) * 0.25) * R(0, 0, sx * -0.15), V(0.3, 1.6, 0.3), skin.body)
			table.insert(legs, { thigh = thigh, shin = shin, side = sx, index = i })
		end
	end
	model.Parent = nil
	return model, legs, root
end

return BugModel
