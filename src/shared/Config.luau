--[[
	Bunny 64 - shared configuration.
	Everything tunable lives here so you can tweak the game without digging
	through the scripts.
]]

local Config = {}

Config.GameName = "BUNNY 64"
Config.Version = "1.0.0"

-- Saving ------------------------------------------------------------------
-- Changing this name starts everybody with a fresh save.
Config.DataStoreName = "Bunny64_Save_v1"
Config.AutosaveSeconds = 60

-- Feel ----------------------------------------------------------------------
Config.Gravity = 170
Config.WalkSpeed = 24
Config.JumpPower = 58          -- first jump (~10 studs high)
Config.DoubleJumpPower = 55    -- second jump in the air
Config.PoundHang = 0.18        -- seconds you hang in the air before a ground pound
Config.PoundSpeed = 160
Config.StompBounce = 62
Config.MushroomBounce = 190
Config.MaxHearts = 3
Config.HealEveryCarrots = 10   -- every N carrots restores a heart
Config.WaterLevel = -6

-- Goals ---------------------------------------------------------------------
Config.CollectorGoal = 50      -- carrots needed for the "Carrot Collector" golden carrot
Config.BugBusterGoal = 12      -- Grumblebugs to bop for the "Bug Buster" golden carrot
Config.BugRespawnSeconds = 40

Config.Goldens = {
	{ id = "burrow", name = "Burrow Rooftop", hint = "Old cottages have the best views. Try the crates." },
	{ id = "tower", name = "Lookout Tower", hint = "Spiral steps lead to the top of the stone tower." },
	{ id = "oak", name = "Old Oak Crown", hint = "Climb the great oak's leafy branches." },
	{ id = "sky", name = "Cloud Garden", hint = "A springy mushroom tops the big hill..." },
	{ id = "islet", name = "Lonely Islet", hint = "Hop the stepping stones out west. Mind the sinking ones." },
	{ id = "collector", name = "Carrot Collector", hint = "Gather 50 carrots." },
	{ id = "buster", name = "Bug Buster", hint = "Bop 12 Grumblebugs." },
}

-- Sounds --------------------------------------------------------------------
-- These use sounds bundled with the Roblox client. Swap in your own uploaded
-- audio ("rbxassetid://123...") for a more personal soundtrack.
Config.Sounds = {
	Jump = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.4 },
	DoubleJump = { id = "rbxasset://sounds/swoosh.wav", volume = 0.5 },
	Pound = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.5 },
	Land = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.6 },
	Carrot = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.45 },
	Golden = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7 },
	Stomp = { id = "rbxasset://sounds/swoosh.wav", volume = 0.6 },
	Hurt = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.6 },
	Splash = { id = "rbxasset://sounds/impact_water.mp3", volume = 0.6 },
	Boing = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.7 },
	Start = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5 },
}
-- Put an uploaded music track id here, e.g. "rbxassetid://1234567890"
Config.MusicId = ""
Config.MusicVolume = 0.3

-- Palette: muted, earthy, late-90s console colours --------------------------
local rgb = Color3.fromRGB
Config.Palette = {
	Grass = rgb(104, 136, 72),
	GrassLight = rgb(122, 150, 82),
	GrassDark = rgb(82, 112, 60),
	Dirt = rgb(128, 98, 70),
	DirtDark = rgb(104, 80, 58),
	Path = rgb(150, 124, 92),
	Sand = rgb(190, 172, 128),
	Stone = rgb(138, 134, 122),
	StoneDark = rgb(102, 98, 90),
	Wood = rgb(110, 80, 54),
	WoodLight = rgb(146, 112, 76),
	Plaster = rgb(206, 192, 164),
	Roof = rgb(136, 66, 54),
	Water = rgb(56, 98, 108),
	Leaf = rgb(76, 108, 56),
	LeafDark = rgb(58, 88, 46),
	Pine = rgb(56, 84, 58),
	Mushroom = rgb(160, 64, 54),
	MushroomStem = rgb(214, 200, 172),
	Carrot = rgb(204, 108, 46),
	CarrotDark = rgb(170, 84, 36),
	CarrotLeaf = rgb(84, 120, 52),
	Gold = rgb(206, 166, 70),
	GoldDark = rgb(166, 128, 48),
	Fur = rgb(170, 128, 90),
	Cream = rgb(222, 206, 176),
	EarPink = rgb(190, 128, 124),
	Button = rgb(32, 26, 26),
	Bow = rgb(140, 50, 48),
	Patch = rgb(98, 118, 138),
	BugShell = rgb(90, 70, 104),
	BugBelly = rgb(50, 40, 54),
	BugSpot = rgb(176, 146, 80),
	Ink = rgb(36, 26, 22),
	UiText = rgb(240, 226, 196),
}

return Config
