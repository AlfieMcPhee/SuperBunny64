--[[
	Chiptune - a tiny 8-bit music sequencer.

	Roblox can't synthesise sound, so this "tracker" plays one short blip
	sample at different pitches (PlaybackSpeed = 2^(semitones/12)) and cuts
	each note off at the right length, which gives that staccato console-chip
	sound. Drums are a noise sample pitched up or down.

	Songs are written as text patterns, one token per step (an eighth note):
	  C5  D#4  Bb3   a note         .   rest         -   hold the previous note
	  drums:  k = kick   s = snare   h = hi-hat
	`|` is just a bar line for readability.

	All songs below are original compositions for Bunny 64.
	Swap the sample in Config.Chiptune for a different timbre.
]]

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Bunny64")
local Config = require(Shared:WaitForChild("Config"))

local Chiptune = {}

--------------------------------------------------------------------------------
-- Songs
--------------------------------------------------------------------------------

local SONGS = {
	title = {
		bpm = 132,
		lead = [[
			G4 . C5 . E5 . G5 - | - . E5 . G5 . C6 - | - - B5 . A5 . G5 . | A5 - - - . . . . |
			F5 . A5 . G5 . E5 . | F5 . D5 . E5 . C5 . | D5 . E5 . F5 . D5 . | C5 - - - . . . . ]],
		harmony = [[
			E4 . G4 . C5 . E5 - | - . C5 . E5 . G5 - | - - G5 . F5 . E5 . | F5 - - - . . . . |
			D5 . F5 . E5 . C5 . | D5 . B4 . C5 . A4 . | B4 . C5 . D5 . B4 . | G4 - - - . . . . ]],
		bass = [[
			C3 . . . G2 . . . | C3 . . . E3 . . . | G2 . . . G3 . . . | F3 . . . F2 . . . |
			F2 . . . C3 . . . | D3 . . . A2 . . . | G2 . . . G2 . B2 . | C3 . . . G2 . C3 . ]],
		drums = [[ k . . . s . . . | k . . . s . . . | k . . . s . . . | k . k . s . s s |
			k . . . s . . . | k . . . s . . . | k . . . s . h . | k . s . k . . . ]],
	},
	meadow = {
		bpm = 140,
		lead = [[
			C5 . E5 G5 A5 G5 E5 . | F5 . A5 - G5 E5 C5 . | D5 . F5 A5 G5 F5 E5 D5 | E5 - C5 - G4 - . . |
			C5 . E5 G5 C6 B5 A5 G5 | A5 . F5 A5 G5 - E5 . | F5 E5 D5 F5 E5 D5 C5 D5 | C5 - - . G4 . . . ]],
		bass = [[
			C3 . G3 . C3 . G3 . | F3 . C4 . F3 . C4 . | D3 . A3 . D3 . A3 . | C3 . G3 . E3 . G3 . |
			C3 . G3 . C3 . G3 . | F3 . C4 . F3 . C4 . | G3 . D4 . G3 . B3 . | C3 . G3 . C3 . . . ]],
		drums = [[ k . h . s . h . | k . h . s . h . | k . h . s . h . | k . h k s . h . |
			k . h . s . h . | k . h . s . h . | k . h . s . h h | k . s . k s s . ]],
	},
	peaks = {
		bpm = 118,
		lead = [[
			A4 . C5 . E5 - D5 . | C5 . B4 . A4 - - . | G4 . B4 . D5 - C5 . | B4 . G4 . E4 - - . |
			A4 . C5 . E5 . A5 . | G5 - E5 . D5 . C5 . | B4 . C5 . D5 . E5 . | A4 - - - . . . . ]],
		harmony = [[
			. . . . A5 . . . | . . . . E5 . . . | . . . . G5 . . . | . . . . B4 . . . |
			. . . . C6 . . . | . . . . B5 . . . | . . . . G5 . . . | . . . . E5 . . . ]],
		bass = [[
			A2 - - . E3 - - . | F2 - - . C3 - - . | G2 - - . D3 - - . | E2 - - . B2 - - . |
			A2 - - . E3 - - . | F2 - - . C3 - - . | G2 - - . D3 - - . | A2 - - . E2 - - . ]],
		drums = [[ k . . . h . . . | k . . . h . . . | k . . . h . . . | k . . . h . h . |
			k . . . h . . . | k . . . h . . . | k . . . h . . . | k . . h k . . . ]],
	},
	canyon = {
		bpm = 150,
		lead = [[
			D5 . . F5 . G5 A5 . | C6 . A5 . G5 . F5 . | G5 . . A5 . G5 F5 . | D5 - - - . . . . |
			D5 . . F5 . G5 A5 . | C6 . D6 . C6 . A5 . | G5 . F5 . E5 . C5 . | D5 - - - . . A4 C5 ]],
		bass = [[
			D3 . A3 . D3 . A3 . | C3 . G3 . C3 . G3 . | G2 . D3 . G2 . D3 . | D3 . A3 . D3 . A3 . |
			D3 . A3 . D3 . A3 . | C3 . G3 . C3 . G3 . | C3 . G3 . A2 . E3 . | D3 . A3 . D3 . . . ]],
		drums = [[ k . h k s . h . | k . h k s . h . | k . h k s . h . | k . h k s . s . |
			k . h k s . h . | k . h k s . h . | k . h k s . h . | k k s . k . s s ]],
	},
	castle = {
		bpm = 112,
		lead = [[
			E4 . . G4 . F4 . E4 | . . B4 . C5 . B4 . | A4 . . G4 . F4 . E4 | D#4 - - - . . . . |
			E4 . . G4 . F4 . E4 | . . C5 . D5 . C5 . | B4 . A4 . G4 . F4 . | E4 - - - . . . . ]],
		bass = [[
			E2 E2 . E2 F2 . E2 . | E2 E2 . E2 G2 . F2 . | A2 A2 . A2 G2 . F2 . | B2 B2 . B2 B2 . B2 . |
			E2 E2 . E2 F2 . E2 . | C3 C3 . C3 D3 . C3 . | B2 B2 . A2 G2 . F2 . | E2 . . . E2 . . . ]],
		drums = [[ k . . k s . . . | k . . k s . . . | k . . k s . . . | k . k k s . s . |
			k . . k s . . . | k . . k s . . . | k . . k s . . . | k . . . s s s s ]],
	},
	boss = {
		bpm = 168,
		lead = [[
			E5 E5 G5 E5 A5 E5 B5 A5 | G5 E5 F#5 D5 E5 - . . | E5 E5 G5 E5 A5 E5 C6 B5 | A5 G5 F#5 G5 E5 - . . |
			C5 C5 E5 C5 G5 C5 A5 G5 | D5 D5 F#5 D5 A5 D5 B5 A5 | E5 F#5 G5 A5 B5 C6 B5 A5 | B5 - - - D#5 - - - ]],
		bass = [[
			E2 E3 E2 E3 E2 E3 E2 E3 | E2 E3 E2 E3 E2 E3 E2 E3 | E2 E3 E2 E3 E2 E3 E2 E3 | E2 E3 E2 E3 D2 D3 D2 D3 |
			C2 C3 C2 C3 C2 C3 C2 C3 | D2 D3 D2 D3 D2 D3 D2 D3 | E2 E3 E2 E3 E2 E3 E2 E3 | B1 B2 B1 B2 B1 B2 B1 B2 ]],
		drums = [[ k h s h k k s h | k h s h k k s h | k h s h k k s h | k h s h k s s s |
			k h s h k k s h | k h s h k k s h | k h s h k k s h | k s k s k s s s ]],
	},
}

--------------------------------------------------------------------------------
-- Parsing
--------------------------------------------------------------------------------

local SEMI = { C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11 }

local function noteToMidi(tok)
	local letter, acc, oct = string.match(tok, "^([A-G])([#b]?)(%-?%d)$")
	if not letter then
		return nil
	end
	local n = SEMI[letter] + (acc == "#" and 1 or (acc == "b" and -1 or 0))
	return 12 * (tonumber(oct) + 1) + n
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

-- Returns { length = steps, events = { [step] = { note|drum, steps } } }
local function parseChannel(pattern, isDrums)
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
		elseif isDrums then
			events[step] = { drum = tok, len = 1 }
			lastStep = nil
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
	local p = { stepDur = 60 / song.bpm / 2, channels = {} }
	for _, ch in ipairs({ "lead", "harmony", "bass", "drums" }) do
		if song[ch] then
			p.channels[ch] = parseChannel(song[ch], ch == "drums")
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

local function playStep(index)
	local cfg = Config.Chiptune
	for ch, data in pairs(current.channels) do
		local e = data.events[index % data.length]
		if e then
			local len = e.len * current.stepDur
			if e.drum then
				local d = cfg.Drums[e.drum]
				if d then
					trigger(e.drum == "k" and "kick" or "noise", d.speed, d.gate, d.volume)
				end
			else
				local def = ch == "bass" and cfg.Bass or cfg.Lead
				local speed = 2 ^ ((e.midi - def.baseNote) / 12)
				trigger(ch == "bass" and "bass" or (ch == "harmony" and "harmony" or "lead"), speed, len * 0.85, def.volume * (ch == "harmony" and 0.55 or 1))
			end
		end
	end
end

function Chiptune.Init(soundGroup)
	group = soundGroup
	local cfg = Config.Chiptune
	makeVoices("lead", cfg.Lead, 3)
	makeVoices("harmony", cfg.Lead, 2)
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
	current = Config.Chiptune.Enabled and parsed[name] or nil
	step = 0
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
