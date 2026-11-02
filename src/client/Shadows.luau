--[[
	Shadows - a round "blob" shadow straight under every bunny.

	In a 3D platformer the sun's shadow is rarely directly beneath you, so
	judging where you'll land is hard. Classic console platformers solved it
	with a simple dark disc projected straight down; it shrinks and fades as
	you get higher. This is that disc.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shadows = {}

local discs = {} -- [Model] = Part
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include

local function makeDisc()
	local p = Instance.new("Part")
	p.Name = "BlobShadow"
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.new(0, 0, 0)
	p.Transparency = 0.5
	p.Size = Vector3.new(0.05, 3, 3)
	p.Parent = workspace:FindFirstChild("Bunny64LocalFX") or workspace
	return p
end

function Shadows.Init()
	local world = workspace:WaitForChild("Bunny64World")
	params.FilterDescendantsInstances = { world:WaitForChild("Solid"), workspace.Terrain }
	RunService.RenderStepped:Connect(function()
		local seen = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root and char:GetAttribute("Bunny") then
				seen[char] = true
				local disc = discs[char]
				if not disc then
					disc = makeDisc()
					discs[char] = disc
				end
				local hit = workspace:Raycast(root.Position, Vector3.new(0, -120, 0), params)
				if hit then
					local height = math.max(0, root.Position.Y - 2.6 - hit.Position.Y)
					local d = math.clamp(3.4 - height * 0.04, 1.2, 3.4)
					disc.Size = Vector3.new(0.05, d, d)
					disc.Transparency = math.clamp(0.42 + height * 0.006, 0.42, 0.8)
					-- lie flat on whatever slope is below (cylinder axis along the surface normal)
					local pos = hit.Position + hit.Normal * 0.06
					local n = hit.Normal
					local ref = math.abs(n.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis
					disc.CFrame = CFrame.fromMatrix(pos, n, ref:Cross(n).Unit)
					disc.Parent = workspace:FindFirstChild("Bunny64LocalFX") or workspace
				else
					disc.Parent = nil
				end
			end
		end
		for char, disc in pairs(discs) do
			if not seen[char] then
				disc:Destroy()
				discs[char] = nil
			end
		end
	end)
end

return Shadows
