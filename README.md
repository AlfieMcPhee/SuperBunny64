# Bunny 64

A 3D collect-a-thon platformer for **Roblox** starring a plush bunny teddy.
Explore four regions, find **20 golden carrots** and topple **King Grumble**
in his throne room above the Infernal Castle. Three save files, unlockable
hats, and a late-90s console look: chunky low-poly shapes, a muted palette,
distance fog and N64-style menus.

## Moves

| Move | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Run / jump | WASD / Space | Stick / A | Stick / Jump |
| Double jump (front flip) | Space in the air | A in the air | Jump in the air |
| Roll (bops bugs) | Shift or Q | X | ROLL |
| Long jump | Jump during a roll or slide | | |
| Belly slide | C / Ctrl / E while running | B | CROUCH |
| Ground pound | C / Ctrl / E in the air | B in the air | CROUCH in the air |
| Menu | M | Select | MENU |

Ice chutes start a slide automatically - steer with the stick.

## The world

* **Carrot Meadow** (hub): cottage roof, spiral Lookout Tower, the Old Oak,
  a springy mushroom up to the Cloud Garden sky islands, the Lonely Islet.
* **Frostbite Peaks** (north, over the causeway): ramps up a terraced
  mountain, a long ice slide chute, a giant snowman, a freezing pond with
  drifting ice floes.
* **Dustbowl Canyon** (east, over the boardwalk): long-jump pillars that a
  double jump can't clear, Eagle's Mesa, and Boulder Run.
* **Infernal Castle** (south, needs 10 golden carrots): lava rivers and a
  drawbridge, the Firebar Gauntlet, Crusher Hall, the rampart walk, the Lava
  Dungeon outside the east wall, and the Keep - a lava-floored climb with
  firebars and moving ledges. On the keep roof, the throne-room portal
  (needs 15 golden carrots) leads to the boss.
* **King Grumble**: a giant crowned Grumblebug. His three glowing weak
  points are only exposed when he's dazed - bait him into charging a stone
  pillar, or survive his ground slam (jump the fire ring). Then hop onto his
  back and jump on a weak point. He spits fireballs once he's angry.

Checkpoint flags save where you respawn. Burrow Warps (one per region) let
you travel between regions once discovered.

## Golden carrots (20)

Meadow 7 (including *Carrot Collector* for 100 carrots and *Bug Buster* for
20 bopped bugs), Peaks 4, Canyon 3, Castle 6 (including the King's Crown).
Every 10 carrots restores a heart. Press **M > Carrot Log** for hints.

## Customisation

Fur colour, accent colour, hats and neckwear. Hats unlock as your best file
collects golden carrots (Bobble Beanie at 2 ... Wizard Hat at 16); beating
King Grumble unlocks the King's Crown. Looks are shared across your files.

## Saving

Three files (A/B/C) per player, stored with DataStoreService: session
locking, retries, autosave every 60 s, save on leave and on server shutdown,
and an immediate save on every golden carrot and boss win. Saves from the
first version are moved into File A automatically.

## Getting it into Roblox

1. Open **`Bunny64.rbxlx`** in Roblox Studio (File > Open from File).
2. **File > Publish to Roblox**.
3. **Home > Game Settings > Security > Enable Studio Access to API Services**
   (so saving works when testing in Studio).
4. Press **Play**. The world is built by the server when the game starts, so
   the edit-mode viewport is empty - that's expected.

The bunny is a custom character (`StarterPlayer.StarterCharacter`, created at
runtime), so avatar settings don't matter.

## Working on the code

| Path | Becomes | Purpose |
| --- | --- | --- |
| `src/shared/Config.luau` | `ReplicatedStorage.Bunny64` | All tuning: moves, goals, gates, palette, cosmetics, sounds, music |
| `src/shared/BunnyModel.luau` | 〃 | The bunny rig, hats and neckwear |
| `src/shared/HazardMath.luau` | 〃 | Shared firebar / crusher timing |
| `src/server/init.server.luau` | `ServerScriptService.Bunny64Server` | Files, pickups, hearts, checkpoints, warps |
| `src/server/World/*` | module folder | One builder per region |
| `src/server/DataService.luau` | module | Saving |
| `src/server/EnemyService.luau`, `BugModel.luau` | modules | Grumblebugs |
| `src/server/HazardService.luau` | module | Firebars, crushers, lava, boulders |
| `src/server/BossService.luau` | module | King Grumble |
| `src/client/*` | `StarterPlayerScripts.Bunny64Client` | Menus, HUD, moves, animation, effects |
| `src/character/*` | `StarterCharacterScripts` | Empty stand-ins for Roblox's default Animate/Health scripts |

* **Rojo**: `rojo serve` with the included `default.project.json`.
* **Rebuild the place file**: `python3 tools/build_place.py`.
* `python3 tools/check_luau.py` checks script structure and flags names that
  are used but never declared.

## Sound and music

Sound effects use sounds bundled with the Roblox client. Put uploaded music
ids in `Config.Music` (title, meadow, peaks, canyon, castle, boss) for
per-area music; the Options menu has volume sliders.

## Changing the save format

Saves live in the DataStore named in `Config.DataStoreName`. Carrot ids are
based on their positions, so moving a carrot in a region builder makes it a
"new" carrot for existing saves.
