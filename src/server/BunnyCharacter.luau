--[[
	BunnyCharacter - dresses any R15 or R6 avatar as a plush bunny teddy.

	The original body parts are hidden and soft "fabric" blobs are welded to
	each limb, so Roblox's own walk/jump animations still drive the bunny.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local P = Config.Palette

local BunnyCharacter = {}

local function blob(limb, offset, size, color, material, isBlock)
	local p = Instance.new("Part")
	p.Name = "Bunny_" .. limb.Name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Fabric
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if not isBlock then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.CFrame = limb.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = limb
	weld.Part1 = p
	weld.Parent = p
	p.Parent = limb.Parent
	return p
end

local function hideOriginal(character)
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and not string.find(d.Name, "^Bunny_") then
			d.Transparency = 1
		elseif d:IsA("Decal") and d.Parent and d.Parent.Name == "Head" then
			d:Destroy()
		elseif d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		end
	end
end

function BunnyCharacter.Apply(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15
	local function get(r15Name, r6Name)
		return character:WaitForChild(isR15 and r15Name or r6Name, 10)
	end

	local head = get("Head", "Head")
	local torso = get("UpperTorso", "Torso")
	local lowerTorso = isR15 and get("LowerTorso", "Torso") or torso
	local lArm = get("LeftUpperArm", "Left Arm")
	local rArm = get("RightUpperArm", "Right Arm")
	local lHand = isR15 and get("LeftHand", "Left Arm") or lArm
	local rHand = isR15 and get("RightHand", "Right Arm") or rArm
	local lLeg = get("LeftUpperLeg", "Left Leg")
	local rLeg = get("RightUpperLeg", "Right Leg")
	local lFoot = isR15 and get("LeftFoot", "Left Leg") or lLeg
	local rFoot = isR15 and get("RightFoot", "Right Leg") or rLeg
	if not (head and torso and lArm and rArm and lLeg and rLeg) then
		return
	end

	hideOriginal(character)
	character.DescendantAdded:Connect(function(d)
		if d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") then
			task.defer(function()
				d:Destroy()
			end)
		end
	end)

	local CF = CFrame.new
	local V = Vector3.new
	local fur, cream, pink = P.Fur, P.Cream, P.EarPink
	local smooth = Enum.Material.SmoothPlastic

	-- Torso: round plush body with a cream belly and stitched seam (front is -Z)
	local bodyY = isR15 and -0.4 or -0.2
	blob(torso, CF(0, bodyY, 0), V(3.0, 3.3, 2.6), fur)
	blob(torso, CF(0, bodyY - 0.2, -1.05), V(2.0, 2.3, 0.7), cream)
	for i = 0, 2 do
		blob(torso, CF(0, bodyY + 0.6 - i * 0.55, -1.42) * CFrame.Angles(0, 0, (i % 2 == 0) and 0.4 or -0.4), V(0.45, 0.1, 0.06), P.Button, smooth, true)
	end
	-- Bow tie
	blob(torso, CF(-0.45, 1.05, -1.1) * CFrame.Angles(0, 0, 0.3), V(0.8, 0.55, 0.35), P.Bow)
	blob(torso, CF(0.45, 1.05, -1.1) * CFrame.Angles(0, 0, -0.3), V(0.8, 0.55, 0.35), P.Bow)
	blob(torso, CF(0, 1.05, -1.2), V(0.35, 0.35, 0.3), P.Bow)
	-- Fluffy tail
	blob(lowerTorso, CF(0, isR15 and 0 or -0.8, 1.15), V(1.0, 1.0, 1.0), cream)

	-- Head (big and round, teddy-proportioned)
	blob(head, CF(0, 0.45, 0), V(2.8, 2.5, 2.5), fur)
	blob(head, CF(0, 0.05, -1.05), V(1.45, 0.95, 0.8), cream)
	blob(head, CF(0, 0.3, -1.42), V(0.45, 0.32, 0.3), pink)
	for _, sx in ipairs({ -1, 1 }) do
		blob(head, CF(sx * 0.52, 0.72, -1.08), V(0.38, 0.44, 0.22), P.Button, smooth)
		blob(head, CF(sx * 0.55, 0.8, -1.18), V(0.1, 0.1, 0.06), P.Cream, smooth)
		-- ears: outer fabric with a pink inner, tilted outward
		local earCF = CF(sx * 0.62, 2.4, 0.1) * CFrame.Angles(-0.15, 0, -sx * 0.2)
		blob(head, earCF, V(0.85, 2.9, 0.5), fur)
		blob(head, earCF * CF(0, -0.1, -0.15), V(0.48, 2.2, 0.28), pink)
		if sx == 1 then
			-- sewn-on patch, every well-loved teddy has one
			blob(head, earCF * CF(0, 0.3, 0.24) * CFrame.Angles(0, 0, 0.3), V(0.42, 0.42, 0.06), P.Patch, Enum.Material.Fabric, true)
		end
	end

	-- Arms & paws
	for _, pair in ipairs({ { lArm, lHand }, { rArm, rHand } }) do
		blob(pair[1], CF(0, isR15 and -0.3 or 0.1, 0), V(1.05, isR15 and 1.9 or 2.0, 1.05), fur)
		blob(pair[2], CF(0, isR15 and 0 or -0.9, 0), V(0.95, 0.85, 0.95), cream)
	end

	-- Legs & big feet with pink pads
	for _, pair in ipairs({ { lLeg, lFoot }, { rLeg, rFoot } }) do
		blob(pair[1], CF(0, isR15 and 0 or 0.25, 0), V(1.2, isR15 and 1.6 or 1.5, 1.2), fur)
		local footOffset = isR15 and CF(0, 0, -0.3) or CF(0, -0.8, -0.35)
		blob(pair[2], footOffset, V(1.2, 0.7, 1.9), fur)
		blob(pair[2], footOffset * CF(0, 0, 0.92), V(0.75, 0.45, 0.12), pink)
	end

	-- Soft ink outline around the bunny for a hand-drawn, storybook edge
	local outline = Instance.new("Highlight")
	outline.Name = "BunnyOutline"
	outline.FillTransparency = 1
	outline.OutlineColor = P.Ink
	outline.OutlineTransparency = 0.25
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = character

	humanoid.BreakJointsOnDeath = false
end

return BunnyCharacter
