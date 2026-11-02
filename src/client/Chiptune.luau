--[[
	Chiptune - Bunny 64's 8-bit music engine and soundtrack.

	Roblox can't synthesise sound, so this little "tracker" plays one short
	blip sample at different pitches (PlaybackSpeed = 2^(semitones/12)) and
	cuts each note off on time, which gives that staccato console-chip sound.

	Channels per song:
	  lead      the melody                       C5 D#4 Bb3 = notes, - = hold, . = rest
	  harmony   a second voice, quieter
	  bass      the low line
	  arp       chord symbols (C Am F G7 Em Bb maj7 ...) played as rippling
	            16th-note arpeggios - the classic chip "shimmer"
	  drums     k = kick, s = snare, h = hi-hat
	  echo      true = the melody repeats softly a beat and a half later,
	            which makes slow tunes feel wistful and roomy
	One token per eighth note; `|` is just a bar line.

	THE SOUNDTRACK
	Every tune is built on one leitmotif, "Bunny's Theme", re-arranged for
	each place: a lullaby on the title screen, a bouncy march in the meadow,
	a waltz in the snow, a swung trail tune in the canyon, a brooding minor
	version in the castle, a frantic battle version for King Grumble, and a
	full reprise for the ending. All music here is original to Bunny 64.
]]

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local Chiptune = {}

--------------------------------------------------------------------------------
-- The soundtrack
--------------------------------------------------------------------------------

-- Bunny's Theme (C major), 8 bars:
--   E5 . G5 . A5 - G5 E5 | D5 - E5 - C5 - - . | E5 . G5 . A5 - C6 B5 | G5 - - - - . . . |
--   A5 . G5 . E5 - D5 C5 | D5 - E5 - G5 - - . | A5 . G5 E5 D5 . C5 D5 | C5 - - - - . . .
--   chords: C | Am | F | G | Am | Em | F G | C

local SONGS = {
	-- Title: "Bunny's Lullaby" - the theme, slow and gentle, with soft arpeggios
	title = {
		bpm = 96,
		echo = true,
		arpOctave = 4,
		lead = [[
			E5 . G5 . A5 - G5 E5 | D5 - E5 - C5 - - . | E5 . G5 . A5 - C6 B5 | G5 - - - - . . . |
			A5 . G5 . E5 - D5 C5 | D5 - E5 - G5 - - . | A5 . G5 E5 D5 . C5 D5 | C5 - - - - . . . ]],
		arp = [[
			C - - - - - - - | Am - - - - - - - | F - - - - - - - | G - - - - - - - |
			Am - - - - - - - | Em - - - - - - - | F - - - G - - - | C - - - - - - - ]],
		bass = [[
			C3 - - - - - - - | A2 - - - - - - - | F2 - - - - - - - | G2 - - - - - - - |
			A2 - - - - - - - | E2 - - - - - - - | F2 - - - G2 - - - | C3 - - - - - - - ]],
	},

	-- Carrot Meadow: the theme as a bouncy little march
	meadow = {
		bpm = 138,
		arpOctave = 5,
		lead = [[
			E5 . G5 . A5 - G5 E5 | D5 - E5 - C5 - - . | E5 . G5 . A5 - C6 B5 | G5 - - - - . G4 . |
			A5 . G5 . E5 - D5 C5 | D5 - E5 - G5 - - . | A5 . G5 E5 D5 . C5 D5 | C5 - - - C5 . . . ]],
		harmony = [[
			C5 . E5 . F5 - E5 C5 | A4 - C5 - A4 - - . | C5 . E5 . F5 - A5 G5 | D5 - - - - . . . |
			E5 . E5 . C5 - B4 A4 | B4 - B4 - E5 - - . | F5 . E5 C5 B4 . A4 B4 | G4 - - - G4 . . . ]],
		bass = [[
			C3 . G3 . C3 . G3 . | A2 . E3 . A2 . E3 . | F2 . C3 . F2 . C3 . | G2 . D3 . G2 . B2 . |
			A2 . E3 . A2 . E3 . | E2 . B2 . E2 . B2 . | F2 . C3 . G2 . D3 . | C3 . G3 . C3 . . . ]],
		drums = [[ k . h . s . h . | k . h . s . h . | k . h . s . h . | k . h k s . h h |
			k . h . s . h . | k . h . s . h . | k . h . s . h h | k . s . k s s . ]],
	},

	-- Frostbite Peaks: "Snowfall Waltz" - the theme in A minor, 3/4 time, sparkling arps
	peaks = {
		bpm = 150,
		echo = true,
		arpOctave = 5,
		lead = [[
			C5 - E5 F5 E5 C5 | B4 - C5 - A4 - | C5 - E5 F5 A5 G5 | E5 - - - - . |
			F5 - E5 C5 B4 A4 | B4 - C5 - E5 - | F5 E5 C5 B4 A4 B4 | A4 - - - - . ]],
		arp = [[
			Am - - - - - | E - - - - - | F - - - - - | C - - - - - |
			Dm - - - - - | Am - - - - - | F - - E - - | Am - - - - - ]],
		bass = [[
			A2 - - E3 - - | E2 - - B2 - - | F2 - - C3 - - | C3 - - G2 - - |
			D3 - - A2 - - | A2 - - E3 - - | F2 - - E2 - - | A2 - - E2 - - ]],
		drums = [[ k . . h . h | k . . h . h | k . . h . h | k . . h . h |
			k . . h . h | k . . h . h | k . . h . h | k . . s . . ]],
	},

	-- Dustbowl Canyon: "Dusty Trail" - the theme in D dorian with a lazy swing
	canyon = {
		bpm = 144,
		arpOctave = 4,
		lead = [[
			F5 . . A5 . B5 A5 F5 | E5 - F5 - D5 - - . | F5 . . A5 . B5 D6 C6 | A5 - - - - . . . |
			B5 . A5 . F5 - E5 D5 | E5 - F5 - A5 - - . | B5 . A5 F5 E5 . D5 E5 | D5 - - - - . A4 C5 ]],
		arp = [[
			Dm - - - - - - - | C - - - - - - - | G - - - - - - - | Am - - - - - - - |
			Dm - - - - - - - | C - - - - - - - | G - - - Am - - - | Dm - - - - - - - ]],
		bass = [[
			D3 . A2 . D3 . A2 . | C3 . G2 . C3 . G2 . | G2 . D3 . G2 . D3 . | A2 . E3 . A2 . E3 . |
			D3 . A2 . D3 . A2 . | C3 . G2 . C3 . G2 . | G2 . D3 . A2 . E3 . | D3 . A2 . D3 . . . ]],
		drums = [[ k . h k s . h . | k . h k s . h . | k . h k s . h . | k . h k s . s . |
			k . h k s . h . | k . h k s . h . | k . h k s . h . | k k s . k . s s ]],
	},

	-- Infernal Castle: "Grumble's Keep" - the theme turned dark, in E minor with a flat 2nd
	castle = {
		bpm = 108,
		echo = true,
		arpOctave = 3,
		lead = [[
			G4 . B4 . C5 - B4 G4 | F4 - G4 - E4 - - . | G4 . B4 . C5 - E5 D5 | B4 - - - - . . . |
			C5 . B4 . G4 - F4 E4 | F4 - G4 - B4 - - . | C5 . B4 G4 F4 . E4 F4 | E4 - - - - . . . ]],
		arp = [[
			Em - - - - - - - | F - - - - - - - | Am - - - - - - - | Em - - - - - - - |
			Am - - - - - - - | F - - - - - - - | C - - - B - - - | Em - - - - - - - ]],
		bass = [[
			E2 E2 . E2 E2 . E2 . | F2 F2 . F2 F2 . F2 . | A2 A2 . A2 A2 . A2 . | E2 E2 . E2 B1 . B1 . |
			A2 A2 . A2 A2 . A2 . | F2 F2 . F2 F2 . F2 . | C3 C3 . C3 B2 . B2 . | E2 . . . E2 . . . ]],
		drums = [[ k . . . s . . k | k . . . s . . . | k . . . s . . k | k . k . s . . . |
			k . . . s . . k | k . . . s . . . | k . . . s . s . | k . . . s s s s ]],
	},

	-- King Grumble: the theme as a frantic battle - same melody, much faster, driven hard
	boss = {
		bpm = 172,
		arpOctave = 4,
		lead = [[
			G5 G5 B5 G5 C6 - B5 G5 | F5 F5 G5 F5 E5 - - . | G5 G5 B5 G5 C6 - E6 D6 | B5 - B5 - B5 - D#5 - |
			C6 . B5 . G5 - F5 E5 | F5 - G5 - B5 - - . | C6 B5 G5 F5 E5 F5 G5 A5 | B5 - - - D#5 - E5 - ]],
		harmony = [[
			E5 . . . E5 . . . | D5 . . . C5 . . . | E5 . . . A5 . . . | F#5 . . . F#5 . . . |
			A5 . . . E5 . . . | D5 . . . F5 . . . | A5 . . . B4 . . . | F#5 . . . B4 . . . ]],
		arp = [[
			Em - - - - - - - | F - - - - - - - | Am - - - - - - - | B7 - - - - - - - |
			Am - - - - - - - | F - - - - - - - | C - - - B7 - - - | Em - - - B7 - - - ]],
		bass = [[
			E2 E3 E2 E3 E2 E3 E2 E3 | F2 F3 F2 F3 F2 F3 F2 F3 | A2 A3 A2 A3 A2 A3 A2 A3 | B1 B2 B1 B2 B1 B2 B1 B2 |
			A2 A3 A2 A3 A2 A3 A2 A3 | F2 F3 F2 F3 F2 F3 F2 F3 | C3 C2 C3 C2 B1 B2 B1 B2 | E2 E3 E2 E3 B1 B2 B1 B2 ]],
		drums = [[ k h s h k k s h | k h s h k k s h | k h s h k k s h | k h s h k s s s |
			k h s h k k s h | k h s h k k s h | k h s h k k s h | k s k s k s s s ]],
	},

	-- Ending: "Home Again" - the full theme, warm and slow, every voice together
	ending = {
		bpm = 104,
		echo = true,
		arpOctave = 4,
		lead = [[
			E5 . G5 . A5 - G5 E5 | D5 - E5 - C5 - - . | E5 . G5 . A5 - C6 B5 | G5 - - - - . . . |
			A5 . G5 . E5 - D5 C5 | D5 - E5 - G5 - - . | A5 . G5 E5 D5 . C5 D5 | C5 - - - - - - - ]],
		harmony = [[
			C5 - - - E5 - - - | A4 - - - E5 - - - | C5 - - - F5 - - - | B4 - - - D5 - - - |
			C5 - - - C5 - - - | B4 - - - B4 - - - | C5 - - - B4 - - - | G4 - - - - - - - ]],
		arp = [[
			C - - - - - - - | Am - - - - - - - | Fmaj7 - - - - - - - | G - - - - - - - |
			Am - - - - - - - | Em - - - - - - - | F - - - G - - - | C - - - - - - - ]],
		bass = [[
			C3 - - - G2 - - - | A2 - - - E2 - - - | F2 - - - C3 - - - | G2 - - - D3 - - - |
			A2 - - - E2 - - - | E2 - - - B2 - - - | F2 - - - G2 - - - | C3 - - - - - - - ]],
		drums = [[ k . . . h . . . | k . . . h . . . | k . . . h . . . | k . . . h . h . |
			k . . . h . . . | k . . . h . . . | k . . . h . . . | k . . . . . . . ]],
	},
}

--------------------------------------------------------------------------------
-- Parsing
--------------------------------------------------------------------------------

local SEMI = { C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11 }
local QUALITY = {
	[""] = { 0, 4, 7 }, m = { 0, 3, 7 }, ["7"] = { 0, 4, 7, 10 }, m7 = { 0, 3, 7, 10 },
	maj7 = { 0, 4, 7, 11 }, dim = { 0, 3, 6 }, sus4 = { 0, 5, 7 }, sus2 = { 0, 2, 7 },
}

local function noteToMidi(tok)
	local letter, acc, oct = string.match(tok, "^([A-G])([#b]?)(%-?%d)$")
	if not letter then
		return nil
	end
	local n = SEMI[letter] + (acc == "#" and 1 or (acc == "b" and -1 or 0))
	return 12 * (tonumber(oct) + 1) + n
end

local function chordToTones(tok, octave)
	local letter, acc, quality = string.match(tok, "^([A-G])([#b]?)(.*)$")
	if not letter or not QUALITY[quality] then
		return nil
	end
	local root = 12 * (octave + 1) + SEMI[letter] + (acc == "#" and 1 or (acc == "b" and -1 or 0))
	local tones = {}
	for _, iv in ipairs(QUALITY[quality]) do
		table.insert(tones, root + iv)
	end
	table.insert(tones, root + 12)
	return tones
end

local function tokenize(pattern)
	local out = {}
	for tok in string.gmatch(pattern, "%S+") do
		if tok ~= "|" then
			table.insert(out, tok)
		end
	end
	return out
end

-- Returns { length = steps, events = { [step] = { midi|drum|tones, len } } }
local function parseChannel(pattern, kind, octave)
	local toks = tokenize(pattern)
	local events = {}
	local lastStep = nil
	for i, tok in ipairs(toks) do
		local step = i - 1
		if tok == "-" then
			if lastStep then
				events[lastStep].len += 1
			end
		elseif tok == "." then
			lastStep = nil
		elseif kind == "drums" then
			events[step] = { drum = tok, len = 1 }
			lastStep = nil
		elseif kind == "arp" then
			local tones = chordToTones(tok, octave)
			if tones then
				events[step] = { tones = tones, len = 1 }
				lastStep = step
			end
		else
			local midi = noteToMidi(tok)
			if midi then
				events[step] = { midi = midi, len = 1 }
				lastStep = step
			end
		end
	end
	return { length = #toks, events = events }
end

local parsed = {}
for name, song in pairs(SONGS) do
	local p = { stepDur = 60 / song.bpm / 2, channels = {}, echo = song.echo == true }
	for _, ch in ipairs({ "lead", "harmony", "bass", "arp", "drums" }) do
		if song[ch] then
			p.channels[ch] = parseChannel(song[ch], ch, song.arpOctave or 4)
		end
	end
	parsed[name] = p
end

--------------------------------------------------------------------------------
-- Voices
--------------------------------------------------------------------------------

local group
local voices = {} -- [channel] = { list = {voice}, next = 1 }
local current, currentName = nil, nil
local step, nextStepAt = 0, 0
local pending = {} -- scheduled sub-step notes: { at = time, fn = function }
local arpIndex = 0

local function makeVoices(channel, def, count)
	local list = {}
	for _ = 1, count do
		local s = Instance.new("Sound")
		s.Name = "Chip_" .. channel
		s.SoundId = def.id
		s.Volume = def.volume
		s.SoundGroup = group
		s.Parent = SoundService
		table.insert(list, { sound = s, stopAt = math.huge, def = def })
	end
	voices[channel] = { list = list, next = 1 }
end

local function trigger(channel, speed, length, volume)
	local bank = voices[channel]
	if not bank then
		return
	end
	local v = bank.list[bank.next]
	bank.next = bank.next % #bank.list + 1
	local s = v.sound
	s.PlaybackSpeed = math.clamp(speed, 0.05, 20)
	s.Volume = volume or v.def.volume
	s.TimePosition = 0
	s:Play()
	v.stopAt = os.clock() + length
end

local function speedFor(midi, def)
	return 2 ^ ((midi - def.baseNote) / 12)
end

local function schedule(at, fn)
	table.insert(pending, { at = at, fn = fn })
end

local function playStep(index)
	local cfg = Config.Chiptune
	local now = os.clock()
	local dur = current.stepDur
	for ch, data in pairs(current.channels) do
		local e = data.events[index % data.length]
		if ch == "arp" then
			-- arpeggios keep rippling while a chord is held
			local held = e
			if not held then
				for back = 1, 16 do
					local prev = data.events[(index - back) % data.length]
					if prev then
						if prev.len > back then
							held = prev
						end
						break
					end
				end
			end
			if held then
				local tones = held.tones
				for sub = 0, 1 do
					schedule(now + sub * dur / 2, function()
						arpIndex += 1
						local midi = tones[(arpIndex - 1) % #tones + 1]
						trigger("arp", speedFor(midi, cfg.Lead), dur * 0.42, cfg.Arp.volume)
					end)
				end
			end
		elseif e then
			local len = e.len * dur
			if e.drum then
				local d = cfg.Drums[e.drum]
				if d then
					trigger(e.drum == "k" and "kick" or "noise", d.speed, d.gate, d.volume)
				end
			else
				local def = ch == "bass" and cfg.Bass or cfg.Lead
				local speed = speedFor(e.midi, def)
				local vol = def.volume * (ch == "harmony" and 0.55 or 1)
				trigger(ch, speed, len * 0.85, vol)
				if ch == "lead" and current.echo then
					schedule(now + dur * 3, function()
						trigger("echo", speed, math.min(len, dur * 2) * 0.8, def.volume * 0.32)
					end)
				end
			end
		end
	end
end

function Chiptune.Init(soundGroup)
	group = soundGroup
	local cfg = Config.Chiptune
	makeVoices("lead", cfg.Lead, 3)
	makeVoices("harmony", cfg.Lead, 2)
	makeVoices("echo", cfg.Lead, 3)
	makeVoices("arp", cfg.Lead, 3)
	makeVoices("bass", cfg.Bass, 2)
	makeVoices("kick", cfg.Lead, 2)
	makeVoices("noise", cfg.Noise, 3)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, bank in pairs(voices) do
			for _, v in ipairs(bank.list) do
				if now >= v.stopAt then
					v.sound:Stop()
					v.stopAt = math.huge
				end
			end
		end
		for i = #pending, 1, -1 do
			local p = pending[i]
			if now >= p.at then
				table.remove(pending, i)
				if current then
					p.fn()
				end
			end
		end
		if not current then
			return
		end
		if now - nextStepAt > 0.5 then
			nextStepAt = now -- we fell behind (window was hidden); don't machine-gun notes
		end
		while now >= nextStepAt do
			playStep(step)
			step += 1
			nextStepAt += current.stepDur
		end
	end)
end

function Chiptune.Play(name)
	if name == currentName then
		return
	end
	currentName = name
	current = Config.Chiptune.Enabled and name and parsed[name] or nil
	step = 0
	arpIndex = 0
	table.clear(pending)
	nextStepAt = os.clock() + 0.25
	for _, bank in pairs(voices) do
		for _, v in ipairs(bank.list) do
			v.sound:Stop()
			v.stopAt = math.huge
		end
	end
end

function Chiptune.Stop()
	Chiptune.Play(nil)
end

function Chiptune.Has(name)
	return parsed[name] ~= nil
end

return Chiptune
