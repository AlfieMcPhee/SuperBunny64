# Bunny 64

A 3D collect-a-thon platformer for **Roblox** starring a plush bunny teddy.
Explore six lands, find **37 golden carrots**, bring Granny Clover's lost
grandkits home and topple **King Grumble** in his throne room above the
Infernal Castle. Three save files, unlockable
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
All keys and gamepad buttons can be rebound in **Options > Controls**
(saved with your progress; clashing bindings swap automatically).

## Baddies

| Baddie | Where | How to beat it |
| --- | --- | --- |
| Grumblebug | everywhere | stomp, ground pound, roll or slide into it |
| Hopscotch Toad | meadow, canyon, peaks | hops after you in big arcs - stomp it |
| Flitbat | peaks, castle, canyon | circles, then swoops - stomp it or roll / long jump into it |
| Thornhog | canyon floor, castle approach | all spikes: only a ground-pound shockwave works |
| Puffshroom | meadow, peaks, castle, woods | puffs a ring of spores every few seconds - stomp it between puffs |
| Mossling | Whisperwood | hides as a hump of moss, pops up and chases you - stomp it or roll into it |
| Snapper | Whisperwood (bog edges, grove) | rooted biting plant: rears back, lunges, then droops - stomp its head while it's tired |
| Puffer | Cloudtop Heights | grumpy cloud that puffs up and blows you away - stomp it from above |
| King Grumble | throne room | see below |

## The world

Natural ground is Roblox smooth terrain - grassy cliffs, rolling hills, reedy
ponds, sandy beaches sloping into the sea, painted dirt paths, snow drifts and
glacier ice, desert dunes and sandstone spires, cracked-lava scorch marks -
dressed with trees, bushes, logs, mushrooms, flower patches and tall grass
tufts. Built things (towers, castles, platforms) stay chunky low-poly parts.

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
* **Whisperwood** (far west, over the rope bridge from the Lonely Islet): a
  misty old forest. Climb the shelf fungus spiralling up the giant **Elder
  Tree**, cross the rope bridges of **Treetop Village** (one is missing
  planks), bounce up the giant caps of **Bouncy Grove**, and hop the lily pads
  of **the Bog** - some of them sink.
* **Cloudtop Heights** (up the beanstalk on the meadow's west side, needs 18
  golden carrots): floating islands far above the meadow. **Cloud Hop** east,
  the arching **Rainbow Bridge** south (mind the gap), Captain Gust's airship
  the **Cumulus** with a crow's nest up the mast, and the **Updraft Spire**,
  where rising winds carry you from ledge to ledge. Falling off the clouds
  costs a heart and puts you back where you last stood.

Checkpoint flags save where you respawn (your active flag glows gold). Burrow Warps (one per region) let
you travel between regions once discovered.

## Design notes (the invisible stuff)

Good platformers are generous in ways players never notice. Bunny 64 does:

* **Coyote time** - you can still jump for a split second after running off a ledge.
* **Jump buffering** - press jump just before landing and it still counts.
* **Variable jump height** - tap for a hop, hold for full height.
* **Wall jump** - jump into a wall, press jump again; it also gives back your double jump.
* **Blob shadow** - a dark disc straight under the bunny, so you always know where you'll land.
* **Readable danger** - your last heart beats; heart crates sit before the hard parts.
* **Iris wipes** - the classic circle transition on death, warps and loading a file.
* **"Golden carrot get!"** - a short celebration pose every time.
* **Contextual tips** - one-off hints the first time you reach a new idea (saved per file).
* **Friendly faces** - eleven characters with typewriter dialogue that changes as you progress.
* **One theme, many moods** - the whole soundtrack is built on a single leitmotif.

## Side challenges

* **Silver carrot hunts** - five silver carrots hide in each region (on roofs,
  ledges, tower tops, even over a lava vent). Find all five and that region's
  golden carrot appears. Positions live in `Config.SilverSets`.
* **Granny's Lost Kits** - Granny Clover's five grandkits have wandered off,
  one in every land. Find them all (they're tiny bunnies) and Granny has a
  golden carrot for you.
* **Time trials** - step on a glowing start pad and race the clock:
  *Summit Sprint* (Peaks, 90 s to the summit) and *Boulder Dash* (Canyon, 20 s up
  the boulder ramp). Beat the time and a golden carrot appears at the finish.
  Tune them in `Config.Trials`.

## Atmosphere

Weather per region (meadow pollen, peaks snowfall, canyon dust, castle embers,
fireflies in the woods, cloud wisps in the sky),
a boss title card for King Grumble, a scrolling credits roll over the ending
reprise, and a little SAVED icon whenever your progress is stored.

## Goals beyond the golden carrots

* **Stamps** (Pause > STAMPS) - 16 achievements, from your first golden carrot to
  beating the King without a scratch, wall-jump chains and smashing 20 crates.
  Add Roblox badge ids to `Config.Badges` to award real badges too.
* **Fastest Bunnies** - a board by the meadow spawn showing the 10 fastest 100%
  clears across every server (OrderedDataStore).
* **Golden fur** - unlocked in Customise once a file finds every golden carrot.

## Getting around

* **Map** (Pause > MAP) - every island and route, golden carrots (gold = found),
  discovered warps, your checkpoint and you.
* **Region cards** show your golden carrot progress as you arrive.

## Fun & accessibility

* **Emotes** - 1 wave, 2 dance, 3 sit (gamepad: D-pad left / right / up).
* **Photo mode** (Pause > PHOTO MODE) - free camera, HUD hidden.
* **Assist mode** (Options) - 5 hearts and longer recovery after a hit.
* **Tips on/off** (Options).
* Baddies can't hurt you while you're chatting or celebrating.

## Friends

Talk to them with F (gamepad Y): Elder Shellby and Mayor Burrows (meadow
spawn), Granny Clover (cottage), Guard Nibbles (castle bridge), Pip (Frostbite
Peaks), Prospector Digby (Dustbowl Canyon), Sir Ember (castle courtyard),
Ranger Fern (Whisperwood arrival) and Professor Hoot (Treetop Village), Nimbus
the cloud sheep and Captain Gust (Cloudtop Heights). Their lines are in
`Config.NPCs`; each picks the last set of lines whose goal you've reached.

## Admin perks

Press **P** (or the **ADMIN** button) for the admin panel. Admins are the
place owner (or the owning group's owner), anyone whose UserId is listed in
`Config.Admins`, and everyone while testing in Studio. The server checks every
command.

* **You:** fly (WASD where the camera looks, Space up, Shift down, Ctrl fast),
  god mode, speed x1/x2/x3, full heal
* **Teleport:** every checkpoint, plus straight to the boss
* **Players:** go to, bring, freeze/unfreeze, launch, heal, and *control*
  (they follow you for 20 seconds with their inputs locked; they're told who
  is doing it)
* **World:** reset King Grumble, give yourself every golden carrot on the
  current file (for testing)

## Golden carrots (37)

Meadow 9 (including *Carrot Collector* for 100 carrots, *Bug Buster* for
20 bopped bugs and *Granny's Lost Kits*), Peaks 6, Canyon 5, Castle 7
(including the King's Crown), Whisperwood 5, Cloudtop Heights 5. Each land has
a silver hunt golden, and the Peaks and Canyon each have a time-trial golden.
Every 10 carrots restores a heart. Press **M > Carrot Log** for hints.

## Customisation

Fur colour, accent colour, hats and neckwear. Hats unlock as your best file
collects golden carrots (Bobble Beanie at 2 ... Wizard Hat at 16, Leaf Cap at
20, Sky Pilot Cap at 26); beating
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
| `src/server/EnemyService.luau`, `BugModel.luau`, `EnemyModels.luau` | modules | All the baddies and their models |
| `src/server/HazardService.luau` | module | Firebars, crushers, lava, boulders |
| `src/server/BossService.luau` | module | King Grumble |
| `src/client/*` | `StarterPlayerScripts.Bunny64Client` | Menus, HUD, moves, animation, effects |
| `src/client/Chiptune.luau` | 〃 | The 8-bit music sequencer and songs |
| `src/character/*` | `StarterCharacterScripts` | Empty stand-ins for Roblox's default Animate/Health scripts |

* **Rojo**: `rojo serve` with the included `default.project.json`.
* **Rebuild the place file**: `python3 tools/build_place.py`.
* `python3 tools/check_luau.py` runs a full Luau syntax check (a real parser),
  checks block structure, and flags names that are used but never declared.
  Run it before rebuilding the place file.

## Sound and music

**8-bit music is built in**, all of it variations on one original leitmotif, *Bunny's Theme*: a lullaby (title), a march (meadow), a waltz (peaks), a swung trail tune (canyon), a minor-key brood (castle), a hushed nocturne (Whisperwood), a breezy F-major lift (Cloudtop Heights), a battle version (boss) and a full reprise (ending). The engine has melody, harmony, bass, arpeggio, drum and echo channels. `src/client/Chiptune.luau` is a tiny tracker that
plays original chip tunes for the title screen, each region and the boss,
using one built-in blip sample at different pitches plus a noise sample for
drums. Songs are plain text patterns you can edit (`C5 . E5 - | ...`).
`Config.Chiptune` picks the samples and tuning. To use your own uploaded
tracks instead, put their ids in `Config.Music` - any area with an id plays
that track rather than the chip tune. Volume sliders are in Options.

Sound effects use sounds bundled with the Roblox client.

## Grass

The animated grass comes from terrain decoration, which the server turns on at
start-up. If you don't see grass blades, select **Workspace > Terrain** in
Studio and tick **Decoration**.

## Changing the save format

Saves live in the DataStore named in `Config.DataStoreName`. Carrot ids are
based on their positions, so moving a carrot in a region builder makes it a
"new" carrot for existing saves.
