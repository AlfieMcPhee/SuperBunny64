--[[
	Bunny 64 - shared configuration.
	Everything tunable lives here so you can tweak the game without digging
	through the scripts.
]]

local Config = {}

Config.GameName = "BUNNY 64"
Config.Version = "2.0"

-- Saving ------------------------------------------------------------------------
-- Changing this name starts everybody with a fresh save.
Config.DataStoreName = "Bunny64_Save_v1"
Config.AutosaveSeconds = 60
Config.SaveSlots = 3

-- Feel ----------------------------------------------------------------------------
Config.Gravity = 170
Config.WalkSpeed = 24
Config.JumpPower = 58          -- first jump (~10 studs high)
Config.DoubleJumpPower = 55    -- second jump in the air
Config.PoundHang = 0.18        -- seconds you hang in the air before a ground pound
Config.PoundSpeed = 160
Config.StompBounce = 62
Config.MushroomBounce = 190

Config.RollSpeed = 54          -- burst speed of a roll
Config.RollTime = 0.45
Config.RollCooldown = 0.3
Config.LongJumpSpeed = 68      -- jump during a roll or slide
Config.LongJumpUp = 52
Config.SlideStartSpeed = 42
Config.SlideFriction = 26      -- speed lost per second on flat ground
Config.ChuteSpeed = 78         -- top speed on ice chutes

Config.MaxHearts = 3
Config.HealEveryCarrots = 10   -- every N carrots restores a heart
Config.WaterLevel = -6

-- Controls (players can rebind these in Options > Controls) -----------------------
Config.Controls = {
	{ id = "jump", name = "JUMP", key = "Space", pad = "ButtonA" },
	{ id = "roll", name = "ROLL", key = "LeftShift", pad = "ButtonX" },
	{ id = "crouch", name = "CROUCH / SLIDE / POUND", key = "C", pad = "ButtonB" },
	{ id = "menu", name = "MENU", key = "M", pad = "ButtonSelect" },
}
-- keys that can't be bound (movement, Roblox menus, chat)
Config.ReservedKeys = {
	W = true, A = true, S = true, D = true, Up = true, Down = true, Left = true, Right = true,
	Escape = true, Tab = true, Slash = true, Backquote = true, Backspace = true, Return = true,
}

-- Goals -----------------------------------------------------------------------------
Config.CollectorGoal = 100     -- carrots needed for the "Carrot Collector" golden carrot
Config.BugBusterGoal = 20      -- Grumblebugs to bop for the "Bug Buster" golden carrot
Config.BugRespawnSeconds = 40
Config.CastleGate = 10         -- golden carrots needed to open the castle gate
Config.ThroneGate = 15         -- golden carrots needed to face King Grumble

Config.Regions = {
	{ id = "meadow", name = "CARROT MEADOW" },
	{ id = "peaks", name = "FROSTBITE PEAKS" },
	{ id = "canyon", name = "DUSTBOWL CANYON" },
	{ id = "castle", name = "INFERNAL CASTLE" },
}

Config.Goldens = {
	-- Carrot Meadow
	{ id = "burrow", region = "meadow", name = "Burrow Rooftop", hint = "Old cottages have the best views. Try the crates." },
	{ id = "tower", region = "meadow", name = "Lookout Tower", hint = "Spiral steps lead to the top of the stone tower." },
	{ id = "oak", region = "meadow", name = "Old Oak Crown", hint = "Climb the great oak's leafy branches." },
	{ id = "sky", region = "meadow", name = "Cloud Garden", hint = "A springy mushroom tops the big hill..." },
	{ id = "islet", region = "meadow", name = "Lonely Islet", hint = "Hop the stepping stones out west. Mind the sinking ones." },
	{ id = "collector", region = "meadow", name = "Carrot Collector", hint = "Gather 100 carrots. It appears at the meadow spawn.", req = "carrots" },
	{ id = "buster", region = "meadow", name = "Bug Buster", hint = "Bop 20 baddies of any kind. It appears at the meadow spawn.", req = "bugs" },
	-- Frostbite Peaks
	{ id = "summit", region = "peaks", name = "Frosty Summit", hint = "Wind your way up the mountain ramps." },
	{ id = "chute", region = "peaks", name = "Slippery Slope", hint = "Slide down the ice chute from high on the mountain." },
	{ id = "snowman", region = "peaks", name = "Snowman's Hat", hint = "Ice pillars spiral up to a very big hat." },
	{ id = "floes", region = "peaks", name = "Frozen Pond", hint = "Ride the drifting ice floes. The water is freezing!" },
	-- Dustbowl Canyon
	{ id = "leap", region = "canyon", name = "Canyon Leap", hint = "Roll, then jump, to long jump across the pillars." },
	{ id = "mesa", region = "canyon", name = "Eagle's Mesa", hint = "Climb the ledges of the tallest mesa." },
	{ id = "boulder", region = "canyon", name = "Boulder Run", hint = "Dodge the boulders up the long ramp to the temple." },
	-- Infernal Castle
	{ id = "firebar", region = "castle", name = "Firebar Gauntlet", hint = "Cross the lava pool in the courtyard. Time your jumps." },
	{ id = "thwomp", region = "castle", name = "Crusher Hall", hint = "Run the corridor of crushing stones in the courtyard." },
	{ id = "dungeon", region = "castle", name = "Lava Dungeon", hint = "The dungeon is outside the east wall. Bring patience." },
	{ id = "rampart", region = "castle", name = "Rampart Watch", hint = "Walk the castle walls to the north-east tower." },
	{ id = "keep", region = "castle", name = "Keep Climb", hint = "Climb the ledges inside the keep. Don't touch the lava." },
	{ id = "boss", region = "castle", name = "King Grumble's Crown", hint = "Defeat King Grumble in the throne room above the castle.", req = "boss" },
}

-- Respawn points (also act as checkpoints once touched)
Config.Checkpoints = {
	meadow = { name = "Carrot Meadow", pos = Vector3.new(0, 5, 60) },
	peaks = { name = "Frostbite Peaks", pos = Vector3.new(0, 5, -520) },
	canyon = { name = "Dustbowl Canyon", pos = Vector3.new(528, 5, 0) },
	castle = { name = "Castle Approach", pos = Vector3.new(0, 5, 565) },
	courtyard = { name = "Castle Courtyard", pos = Vector3.new(0, 7, 715) },
	keep = { name = "The Keep", pos = Vector3.new(0, 8, 832) },
	dungeon = { name = "Dungeon Gate", pos = Vector3.new(180, 5, 700) },
	throne = { name = "Throne Room", pos = Vector3.new(0, 206, 752) },
}

-- Burrow warps (discovered by walking near them)
Config.Warps = {
	{ id = "meadow", name = "CARROT MEADOW", pos = Vector3.new(-24, 0, 44) },
	{ id = "peaks", name = "FROSTBITE PEAKS", pos = Vector3.new(24, 0, -530) },
	{ id = "canyon", name = "DUSTBOWL CANYON", pos = Vector3.new(540, 0, 24) },
	{ id = "castle", name = "INFERNAL CASTLE", pos = Vector3.new(26, 0, 575) },
}

-- Customisation ----------------------------------------------------------------------
local rgb = Color3.fromRGB
Config.FurColors = {
	{ name = "CARAMEL", fur = rgb(170, 128, 90), cream = rgb(226, 210, 180) },
	{ name = "COCOA", fur = rgb(112, 80, 60), cream = rgb(206, 184, 152) },
	{ name = "ASH", fur = rgb(132, 128, 124), cream = rgb(214, 210, 200) },
	{ name = "SNOWDROP", fur = rgb(222, 216, 204), cream = rgb(244, 236, 222) },
	{ name = "MIDNIGHT", fur = rgb(58, 54, 62), cream = rgb(176, 168, 160) },
	{ name = "HONEY", fur = rgb(196, 152, 84), cream = rgb(236, 218, 176) },
	{ name = "ROSE", fur = rgb(190, 140, 140), cream = rgb(236, 214, 204) },
	{ name = "MOSS", fur = rgb(120, 128, 92), cream = rgb(214, 210, 180) },
}
Config.AccentColors = {
	{ name = "CRIMSON", color = rgb(140, 50, 48) },
	{ name = "NAVY", color = rgb(52, 66, 110) },
	{ name = "FOREST", color = rgb(58, 96, 62) },
	{ name = "MUSTARD", color = rgb(196, 156, 58) },
	{ name = "PLUM", color = rgb(102, 64, 110) },
	{ name = "TEAL", color = rgb(52, 112, 112) },
	{ name = "CHARCOAL", color = rgb(48, 46, 48) },
	{ name = "CREAM", color = rgb(226, 214, 190) },
}
-- need = golden carrots required (best file), boss = needs King Grumble defeated
Config.Hats = {
	{ id = "none", name = "NO HAT", need = 0 },
	{ id = "straw", name = "STRAW HAT", need = 0 },
	{ id = "beanie", name = "BOBBLE BEANIE", need = 2 },
	{ id = "carrot", name = "CARROT TOP", need = 4 },
	{ id = "tophat", name = "TOP HAT", need = 6 },
	{ id = "flowers", name = "FLOWER CROWN", need = 8 },
	{ id = "propeller", name = "PROPELLER CAP", need = 10 },
	{ id = "viking", name = "VIKING HELM", need = 13 },
	{ id = "wizard", name = "WIZARD HAT", need = 16 },
	{ id = "crown", name = "KING'S CROWN", need = 0, boss = true },
}
Config.Necks = {
	{ id = "bow", name = "BOW TIE", need = 0 },
	{ id = "scarf", name = "WOOLLY SCARF", need = 0 },
	{ id = "bell", name = "BELL COLLAR", need = 3 },
	{ id = "none", name = "NOTHING", need = 0 },
}
Config.DefaultCustom = { fur = 1, accent = 1, hat = "none", neck = "bow" }

-- Sounds --------------------------------------------------------------------------------
-- These use sounds bundled with the Roblox client. Swap in your own uploaded
-- audio ("rbxassetid://123...") for a more personal soundtrack.
Config.Sounds = {
	Jump = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.4 },
	DoubleJump = { id = "rbxasset://sounds/swoosh.wav", volume = 0.5 },
	Pound = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.5 },
	Land = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.6 },
	Roll = { id = "rbxasset://sounds/swoosh.wav", volume = 0.45 },
	Carrot = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.45 },
	Golden = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7 },
	Stomp = { id = "rbxasset://sounds/swoosh.wav", volume = 0.6 },
	Hurt = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.6 },
	Splash = { id = "rbxasset://sounds/impact_water.mp3", volume = 0.6 },
	Boing = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.7 },
	MenuMove = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.25 },
	MenuSelect = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.45 },
	Burn = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.6 },
	Boss = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.9 },
	Screech = { id = "rbxasset://sounds/swoosh.wav", volume = 0.4 },
}
-- Put uploaded music ids here, e.g. "rbxassetid://1234567890". Empty = silence.
Config.Music = {
	title = "",
	meadow = "",
	peaks = "",
	canyon = "",
	castle = "",
	boss = "",
}
Config.MusicVolume = 0.35

-- Built-in 8-bit music (client/Chiptune.luau). Areas without an uploaded
-- track in Config.Music play these original chip tunes instead.
-- baseNote = the MIDI note the sample sounds at when played at normal speed;
-- nudge it up/down by 12 to shift a whole voice an octave.
Config.Chiptune = {
	Enabled = true,
	Lead = { id = "rbxasset://sounds/electronicpingshort.wav", baseNote = 84, volume = 0.3 },
	Bass = { id = "rbxasset://sounds/electronicpingshort.wav", baseNote = 72, volume = 0.5 },
	Noise = { id = "rbxasset://sounds/swoosh.wav", volume = 0.3 },
	Drums = {
		k = { speed = 0.22, gate = 0.09, volume = 0.6 },
		s = { speed = 2.4, gate = 0.07, volume = 0.28 },
		h = { speed = 5, gate = 0.03, volume = 0.12 },
	},
}

-- Palette: muted, earthy, late-90s console colours ----------------------------------------
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
	Gold = rgb(214, 172, 72),
	GoldDark = rgb(166, 128, 48),
	EarPink = rgb(196, 134, 130),
	Button = rgb(26, 22, 24),
	Patch = rgb(98, 118, 138),
	Snow = rgb(222, 226, 228),
	SnowShade = rgb(186, 196, 204),
	Ice = rgb(156, 196, 214),
	Rock = rgb(118, 120, 128),
	Sandstone = rgb(184, 134, 92),
	SandstoneDark = rgb(150, 104, 70),
	Cactus = rgb(92, 120, 76),
	Basalt = rgb(56, 50, 52),
	BasaltLight = rgb(78, 70, 70),
	CastleStone = rgb(92, 86, 86),
	CastleDark = rgb(62, 58, 60),
	Lava = rgb(206, 84, 34),
	Ember = rgb(232, 132, 54),
	Ink = rgb(30, 22, 20),
	UiText = rgb(244, 232, 204),
}

-- Enemy colour schemes per region
Config.BugSkins = {
	meadow = { shell = rgb(92, 72, 108), shell2 = rgb(70, 54, 84), spot = rgb(176, 146, 80), body = rgb(44, 36, 46), eye = rgb(196, 150, 70) },
	peaks = { shell = rgb(94, 118, 140), shell2 = rgb(70, 90, 110), spot = rgb(222, 228, 232), body = rgb(40, 46, 56), eye = rgb(150, 210, 230) },
	canyon = { shell = rgb(150, 100, 60), shell2 = rgb(120, 78, 46), spot = rgb(84, 58, 40), body = rgb(56, 40, 30), eye = rgb(220, 180, 90) },
	castle = { shell = rgb(54, 46, 46), shell2 = rgb(38, 32, 32), spot = rgb(222, 96, 40), body = rgb(30, 24, 24), eye = rgb(240, 120, 50) },
}

return Config
