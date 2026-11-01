# Bunny 64

A 3D collect-a-thon platformer for **Roblox** starring a plush bunny teddy.
Hop around Carrot Meadow, bop grumpy Grumblebugs, collect carrots and track
down all **7 golden carrots**. Progress saves automatically.

The look is deliberately late-90s console: chunky low-poly shapes, a muted
earthy palette, distance fog, a warm afternoon sun and a fabric-textured teddy
with button eyes and a patched ear.

## What's in the game

* **Moves** - run, jump, *double jump* (jump again in the air), *ground pound*
  (E / Ctrl / gamepad B / on-screen POUND button while airborne).
* **Carrot Meadow** - spawn meadow, a cottage with a climbable roof, a spiral
  stone tower, a giant oak, a terraced hill with a springy mushroom up to a
  chain of floating sky islands (sliding and spinning platforms), and a lonely
  islet reached over sinking stepping stones.
* **Collectibles** - ~65 carrots (every 10 restores a heart) and 7 golden
  carrots: 5 hidden in the world, 1 for collecting 50 carrots and 1 for bopping
  12 Grumblebugs. Each player has their own carrots, so it works in multiplayer.
* **Grumblebugs** - wander and charge at you. Jump on them or ground pound near
  them. They come back after 40 seconds.
* **Hearts** - 3 hearts; enemies and falling in the sea cost one.
* **Carrot Log** (press **J** or the LOG button) - checklist of golden carrots
  with hints, plus your carrot count, bugs bopped and play time.
* **Save system** - DataStore saving with session locking, retries, autosave
  every 60 s, save on leave and on server shutdown. Golden carrots save
  immediately. Leaderboard shows Carrots and Golden.

## Getting it into Roblox (no extra tools)

1. Open **`Bunny64.rbxlx`** in Roblox Studio (File > Open from File).
2. **File > Publish to Roblox** and create a new experience called *Bunny 64*.
3. Turn on saving: **Home > Game Settings > Security > Enable Studio Access
   to API Services** (needed to test saving in Studio; live servers always
   have DataStore access once published).
4. Press **Play**. The level is built by the server script when the game
   starts, so the edit-mode viewport is empty - that's expected.

Optional: Game Settings > Avatar > set the avatar type to **R15** (R6 works too).

## Working on the code

All game code is in `src/`:

| Path | Becomes | Purpose |
| --- | --- | --- |
| `src/shared/Config.luau` | `ReplicatedStorage.Bunny64.Config` | All tuning: jump heights, goals, palette, sounds |
| `src/server/init.server.luau` | `ServerScriptService.Bunny64Server` | Server entry, pickups, hearts, water |
| `src/server/WorldBuilder.luau` | module | Builds the whole level from parts |
| `src/server/DataService.luau` | module | Saving/loading |
| `src/server/EnemyService.luau` | module | Grumblebugs |
| `src/server/BunnyCharacter.luau` | module | Turns any avatar into the teddy |
| `src/client/*` | `StarterPlayerScripts.Bunny64Client` | Moves, HUD, collectibles, effects |

Two ways to get edits into Studio:

* **Rojo** (recommended for ongoing work): install Rojo, run `rojo serve`
  in this folder and connect from the Rojo Studio plugin. `default.project.json`
  is included.
* **Rebuild the place file**: `python3 tools/build_place.py` regenerates
  `Bunny64.rbxlx` from `src/`.

`python3 tools/check_luau.py` does a quick structural check of the scripts.

## Sound and music

The sound effects point at sounds that ship with the Roblox client
(`rbxasset://sounds/...`). For a stronger retro feel, upload your own chiptune
SFX and a music loop to Roblox and put their ids in `Config.Sounds` /
`Config.MusicId`.

## Changing the save format

Saves live in the DataStore named in `Config.DataStoreName`. Renaming it
starts everybody fresh. Carrot ids are based on their positions, so moving a
carrot in `WorldBuilder.luau` makes it a "new" carrot for existing saves.
