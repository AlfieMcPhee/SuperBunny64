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
Config.AssistHearts = 5        -- hearts in Assist Mode (Options)
Config.HealEveryCarrots = 10   -- every N carrots restores a heart
Config.WaterLevel = -6

-- Admins ------------------------------------------------------------------------
-- The place owner (or owning group's owner) is always an admin, and everyone is
-- an admin while testing in Studio. Add friends' Roblox UserIds here.
-- Admins press P (or the ADMIN button) for the admin panel.
Config.Admins = {
	-- 123456789,
}

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

-- Stamps: in-game achievements (Pause > STAMPS). Put a Roblox badge id in
-- Config.Badges to also award a real badge for any of them.
Config.Stamps = {
	{ id = "golden1", name = "SHINY!", desc = "Find your first golden carrot." },
	{ id = "golden10", name = "HALFWAY HOP", desc = "Find 10 golden carrots." },
	{ id = "golden20", name = "CARROT CHAMPION", desc = "Find all 20 golden carrots." },
	{ id = "carrots", name = "CRUNCH TIME", desc = "Collect every single carrot." },
	{ id = "regions", name = "SIGHTSEER", desc = "Visit all four regions." },
	{ id = "friends", name = "SOCIAL BUNNY", desc = "Chat with all six friends." },
	{ id = "bops50", name = "BUG SQUASHER", desc = "Bop 50 baddies." },
	{ id = "crates", name = "CRATE EXPECTATIONS", desc = "Smash 20 heart crates." },
	{ id = "longjump", name = "FLYING SIDEWAYS", desc = "Long jump 25 times." },
	{ id = "walljump", name = "BOING BOING BOING", desc = "Wall jump 3 times in a row." },
	{ id = "boss", name = "CROWN JEWEL", desc = "Defeat King Grumble." },
	{ id = "bossnohit", name = "UNTOUCHABLE", desc = "Defeat King Grumble without getting hurt." },
	{ id = "speedy", name = "SPEEDY BUNNY", desc = "Find all 20 golden carrots in under 2 hours." },
}
Config.Badges = {
	-- golden20 = 1234567890,
}

-- Emotes (keys 1-3, or the gamepad D-pad) - just for fun
Config.Emotes = {
	{ id = "wave", name = "WAVE", key = "One", pad = "DPadLeft" },
	{ id = "dance", name = "DANCE", key = "Two", pad = "DPadRight" },
	{ id = "sit", name = "SIT", key = "Three", pad = "DPadUp" },
}

-- One-off tips, shown the first time you come near each spot (per save file).
-- {jump} {roll} {crouch} {menu} become the player's own key names.
Config.Tips = {
	{ id = "move", pos = Vector3.new(0, 4, 60), radius = 26, text = "Press {jump} to jump, and again in mid-air to double jump. Tap it for a little hop, hold it to jump higher." },
	{ id = "talk", pos = Vector3.new(30, 4, 66), radius = 22, text = "Friendly folk have a lot to say. Walk up to them and press F (or Y) to chat." },
	{ id = "baddie", pos = Vector3.new(40, 4, 25), radius = 22, text = "Grumblebugs are grumpy but squishy. Jump on them, or {roll} into them!" },
	{ id = "warp", pos = Vector3.new(-24, 4, 44), radius = 14, text = "Burrow Warps whisk you between regions once you've found them." },
	{ id = "crate", pos = Vector3.new(26, 4, 48), radius = 14, text = "Heart crates! Smash them with a roll, slide or ground pound to get a heart back." },
	{ id = "walljump", pos = Vector3.new(-130, 25, -120), radius = 45, text = "Jump into a wall and press {jump} again to wall jump. Great for climbing towers!" },
	{ id = "slide", pos = Vector3.new(0, 4, -250), radius = 24, text = "While running, press {crouch} to belly-slide. Jump during a slide for a long jump." },
	{ id = "chute", pos = Vector3.new(-40, 98, -720), radius = 18, text = "Ice chutes grab you and don't let go. Steer with the stick - and enjoy the ride." },
	{ id = "longjump", pos = Vector3.new(570, 20, -60), radius = 30, text = "Those gaps are too wide for a double jump. {roll}, then press {jump} mid-roll to long jump!" },
	{ id = "spikes", pos = Vector3.new(690, 4, -60), radius = 30, text = "Thornhogs are all spikes. Only a ground pound shockwave works: {crouch} in mid-air near them." },
	{ id = "lava", pos = Vector3.new(0, 5, 565), radius = 24, text = "Lava bounces you out, but it costs a heart. Checkpoint flags glow gold when they're yours." },
	{ id = "boss", pos = Vector3.new(0, 206, 752), radius = 24, text = "King Grumble only shows his weak spots when he's dazed. Make him charge a pillar!" },
}

-- Friendly characters. Each NPC picks the LAST dialogue set whose conditions
-- are met (goldens = golden carrots in this file, boss = King Grumble beaten).
Config.NPCs = {
	shellby = {
		name = "ELDER SHELLBY", kind = "tortoise", voice = 0.55,
		dialogue = {
			{ lines = {
				"Oh! A visitor. Forgive me, I don't move very fast. Or think very fast. Or... what was I saying?",
				"Ah yes. The golden carrots! King Grumble's bugs scattered them all over the islands.",
				"Twenty of them, I think. I've been counting for... about eleven years.",
				"Start small. The old cottage roof, the tower, the big oak. The meadow is kind to beginners.",
			} },
			{ goldens = 5, lines = {
				"Five already? Back in my day we had one carrot and we were GRATEFUL.",
				"The causeway north goes to the Peaks, the boardwalk east goes to the Canyon.",
				"South is the castle. The gate needs ten golden carrots. The King is very fussy about doors.",
			} },
			{ goldens = 10, lines = {
				"Ten! The castle gate should open for you now.",
				"Be careful in there, little one. Lava is hot. I learned that the slow way.",
			} },
			{ boss = true, lines = {
				"You beat the King? Then the meadow is safe again. I'm going to celebrate.",
				"...",
				"I am celebrating. On the inside.",
			} },
		},
	},
	clover = {
		name = "GRANNY CLOVER", kind = "granny", voice = 0.8,
		dialogue = {
			{ lines = {
				"Hello, sweetpea! Mind the flowerbeds. I just planted the carrots. Well, I planted where the carrots WERE.",
				"Something shiny landed on my roof last night. My knees aren't what they used to be.",
				"Those crates by the wall should help. You're a bouncy one, aren't you?",
			} },
			{ goldens = 3, lines = {
				"You found the one on my roof! Oh, you're a treasure.",
				"When you get tired, come back and sit a while. The meadow will still be here.",
			} },
			{ boss = true, lines = {
				"I heard the castle went quiet. Was that you? Of course it was.",
				"I baked a carrot cake. It's mostly carrot. Some of it is cake.",
			} },
		},
	},
	pip = {
		name = "PIP", kind = "penguin", voice = 1.35,
		dialogue = {
			{ lines = {
				"HEY! HI! Welcome to the Peaks! It's cold! Isn't it great?!",
				"The ramps go all the way up the mountain. There's a golden carrot at the very top!",
				"Halfway up there's an ice chute. You slide ALL the way down. I've done it forty times today.",
				"Watch out for the pond though. The ice floes drift around. And the water is... very wet.",
			} },
			{ goldens = 12, lines = {
				"You again! You look like someone who's seen some things. Snowy things. Spiky things.",
				"Did you try the snowman's hat? The ice pillars spiral up around him!",
			} },
		},
	},
	digby = {
		name = "PROSPECTOR DIGBY", kind = "mole", voice = 0.7,
		dialogue = {
			{ lines = {
				"Well butter my burrow, a surface-dweller! Welcome to Dustbowl Canyon.",
				"See them pillars out yonder? Too far apart for any normal hop.",
				"Trick is to ROLL first, then JUMP while you're rollin'. Long jump, they call it. I call it flyin' sideways.",
				"And steer clear of the Thornhogs. Prickly fellers. Only a good ground pound'll sort 'em out.",
			} },
			{ goldens = 14, lines = {
				"Up the long ramp there's a temple. Boulders come tumblin' down it every few seconds.",
				"Don't fight the boulders. The boulders always win. Go around 'em.",
			} },
		},
	},
	nibbles = {
		name = "GUARD NIBBLES", kind = "mouse", voice = 1.15,
		dialogue = {
			{ lines = {
				"HALT! Who goes there? Oh. A bunny. Hello.",
				"This is the King's castle. Nobody gets through the gate without ten golden carrots.",
				"That's the rule. I didn't make the rule. I just stand here. I'm very good at standing.",
			} },
			{ goldens = 10, lines = {
				"Ten golden carrots?! Well... rules are rules. In you go.",
				"Between you and me, the King's been grumpy for years. Maybe he just needs someone to stand up to him.",
				"His weak spots only glow when he's dizzy. You didn't hear that from me.",
			} },
			{ boss = true, lines = {
				"The King says he's 'reflecting on his choices'. He asked for a cup of tea.",
				"I think you might have actually helped him. Weird, right?",
			} },
		},
	},
	ember = {
		name = "SIR EMBER", kind = "knightbug", voice = 0.6,
		dialogue = {
			{ lines = {
				"Greetings, small fluffy intruder. I am Sir Ember, Knight of the Courtyard.",
				"I am supposed to stop you. But my shift ended an hour ago.",
				"The firebars to the west, the crushers to the east, the keep straight ahead. Each hides a golden carrot.",
				"The keep is the tallest climb. At the top, a portal to the throne room. Fifteen golden carrots to enter.",
			} },
			{ boss = true, lines = {
				"You defeated His Majesty. I suppose I should be upset.",
				"I am not upset. I am going on holiday.",
			} },
		},
	},
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
	-- post-game reward
	{ name = "GOLDEN", fur = rgb(214, 172, 72), cream = rgb(244, 226, 170), need = 20 },
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
	Talk = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.22 },
	Crate = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.6 },
	Heart = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5 },
	Heartbeat = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.35 },
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
	Arp = { volume = 0.13 }, -- arpeggios use the Lead sample, softly
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
