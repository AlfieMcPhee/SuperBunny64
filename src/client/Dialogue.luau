--[[
	Dialogue - talk to friendly characters.

	A chunky text box types each line out letter by letter, with a little
	voice blip per letter at that character's own pitch. Press jump, the talk
	key, or click/tap to skip the typing or move to the next line.
	What each NPC says depends on how far you've got (Config.NPCs).
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))

local player = Players.LocalPlayer
local Dialogue = {}

local deps
local gui, box, nameLabel, textLabel, arrow
local talking = false
local advance = false
local talkStart = 0

local function pickLines(spec, slot)
	local goldens = slot and slot.goldenCount or 0
	local boss = slot and slot.bossDefeated or false
	local kits = 0
	for sid in pairs(slot and slot.silvers or {}) do
		if string.sub(sid, 1, 7) == "s_kits_" then
			kits += 1
		end
	end
	local chosen = spec.dialogue[1].lines
	for _, set in ipairs(spec.dialogue) do
		local ok = true
		if set.goldens and goldens < set.goldens then
			ok = false
		end
		if set.boss and not boss then
			ok = false
		end
		if set.kits and kits < set.kits then
			ok = false
		end
		if set.has and not (slot and slot.goldens[set.has]) then
			ok = false
		end
		if ok then
			chosen = set.lines
		end
	end
	return chosen
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Bunny64Dialogue"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local frame, shadow = UI.panel(gui, UDim2.new(0.9, 0, 0, 170), UDim2.new(0.5, 0, 1, -120))
	box = shadow
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(820, 170)
	limit.Parent = shadow
	nameLabel = UI.label(frame, {
		Text = "", Font = UI.TITLE, TextSize = 26, TextColor3 = UI.Gold, Size = UDim2.new(1, -40, 0, 30),
		Position = UDim2.fromOffset(20, 10), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3,
	})
	textLabel = UI.label(frame, {
		Text = "", TextSize = 22, TextWrapped = true, Size = UDim2.new(1, -40, 1, -56), Position = UDim2.fromOffset(20, 44),
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Stroke = 2,
	})
	arrow = UI.label(frame, {
		Text = "v", Font = UI.TITLE, TextSize = 24, TextColor3 = UI.Gold, Size = UDim2.fromOffset(30, 30),
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -8), Stroke = 3,
	})
	TweenService:Create(arrow, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.new(1, -14, 1, -2) }):Play()
end

local function waitForAdvance()
	advance = false
	while not advance and talking do
		task.wait()
	end
	advance = false
end

function Dialogue.Talk(id)
	local spec = Config.NPCs[id]
	if not spec or talking then
		return
	end
	local snap = deps.GetSnapshot()
	if not snap or not snap.slot then
		return
	end
	talking = true
	talkStart = os.clock()
	deps.Movement.SetEnabled(false)
	deps.Movement.SetTalking(true)
	if deps.Remotes and deps.Remotes.Talked then
		deps.Remotes.Talked:FireServer(id)
	end
	gui.Enabled = true
	nameLabel.Text = "* " .. spec.name
	box.Position = UDim2.new(0.5, 0, 1, 60)
	TweenService:Create(box, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 1, -120) }):Play()
	local voice = spec.voice or 1
	for _, line in ipairs(pickLines(spec, snap.slot)) do
		textLabel.Text = line
		textLabel.MaxVisibleGraphemes = 0
		arrow.Visible = false
		advance = false
		local count = utf8.len(line) or #line
		local shown = 0
		while shown < count and talking do
			if advance then
				advance = false
				shown = count
			else
				shown += 1
				local ch = string.sub(line, shown, shown)
				if ch ~= " " and shown % 2 == 1 then
					deps.Effects.Play("Talk", voice * (0.95 + math.random() * 0.1))
				end
				-- little pauses after punctuation give the lines some rhythm
				if ch == "." or ch == "!" or ch == "?" then
					task.wait(0.12)
				elseif ch == "," then
					task.wait(0.06)
				else
					task.wait(0.022)
				end
			end
			textLabel.MaxVisibleGraphemes = shown
		end
		textLabel.MaxVisibleGraphemes = -1
		arrow.Visible = true
		waitForAdvance()
		deps.Effects.Play("MenuMove", 1.2)
	end
	talking = false
	gui.Enabled = false
	deps.Movement.SetTalking(false)
	if deps.Menus.Screen() == nil then
		deps.Movement.SetEnabled(true)
	end
end

function Dialogue.IsTalking()
	return talking
end

function Dialogue.Init(dependencies)
	deps = dependencies
	build()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		local id = prompt:GetAttribute("NpcId")
		if id then
			task.spawn(Dialogue.Talk, id)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not talking or processed or os.clock() - talkStart < 0.3 then
			return
		end
		local k = input.KeyCode
		local t = input.UserInputType
		if k == Enum.KeyCode.Space or k == Enum.KeyCode.Return or k == Enum.KeyCode.F or k == Enum.KeyCode.E
			or k == Enum.KeyCode.ButtonA or k == Enum.KeyCode.ButtonY
			or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			advance = true
		end
	end)
end

return Dialogue
