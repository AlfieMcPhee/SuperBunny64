# Bunny 64

A 3D collect-a-thon platformer for **Roblox** starring a plush bunny teddy.
Explore seven lands (one of them secret), find **47 golden carrots**, beat
**four bosses**, bring Granny Clover's lost grandkits home, and dress your
bunny up with things you've earned. Three save files, a late-90s console
look (chunky low-poly shapes, a muted palette, distance fog, N64-style menus)
and an original 8-bit soundtrack.

Publishing it and setting up the optional Robux items is covered in
**[PUBLISHING.md](PUBLISHING.md)**.

## Moves

| Move | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Run / jump | WASD / Space | Stick / A | Stick / Jump |
| Double jump (front flip) | Space in the air | A in the air | Jump in the air |
| Triple jump | Jump again the moment you land, while running (x3) | | |
| Side flip | Jump during a skid (turn hard at speed) | | |
| Ledge grab | Automatic when you just miss an edge; jump to climb, crouch to drop | | |
| Roll (bops baddies) | Shift or Q | X | ROLL |
| Long jump | Jump during a roll or slide | | |
| Dive | Roll button in the air (jump during it to roll out) | X in the air | ROLL in the air |
| Belly slide | C / Ctrl / E while running | B | CROUCH |
| Ground pound | Crouch in the air | B in the air | CROUCH in the air |
| Pound jump | Jump the moment a ground pound lands | | |
| Backflip | Hold crouch while standing still, then jump | | |
| Wall jump | Jump while against a wall in mid-air | | |
| Zipline | Jump up into the rope; jump to let go, crouch to drop | | |
| Menu | M | Select | MENU |

All keys and gamepad buttons can be rebound in **Options > Controls**.
**Options > CAMERA** switches between FOLLOW (the camera swings in behind
you as you run, Mario 64 style) and FREE.

**Stamina.** The green pips under your hearts are stamina. Rolls, dives and
long jumps each use one (a long jump straight out of a roll is included in the
roll), and they refill while you stand on the ground. You start with three and
earn a fourth and fifth pip at 12 and 24 golden carrots. Out of puff, rolls and
long jumps come out short.

**Weight.** Running builds up to full speed, turning hard at speed skids, you
fall faster than you rise, and big drops land with a thump and a short
stagger.

## The lands

* **Carrot Meadow** (hub). The cottage, the Lookout Tower, the Old Oak, the
  Cloud Garden and the Lonely Islet are all here. The revamp adds:
  * **Willow Falls**, a cliff to climb with a waterfall (and something behind it).
  * **The Windmill**, with a mill wheel you ride to the top.
  * **The Slide** down the big hill.
  * **Ziplines** from the tower and the oak.
  * **Spring pads**, **Carrot Henge**, a shipwreck, **the Old Stone Bunny** and the
    **old well**.
* **Frostbite Peaks** (north). A terraced mountain, the ice chute, a giant
  snowman and a freezing pond. Also the **Chairlift** (leap off onto the pylon
  half way up), a **summit zipline** and a **hot spring** that heals you.
* **Dustbowl Canyon** (east). Long-jump pillars, Eagle's Mesa and Boulder Run.
  Also **Geyser Gulch** (steam vents fling you up three pillars), a **mesa
  zipline** and a giant fossil.
* **Infernal Castle** (south, 10 golden carrots). Lava rivers, the Firebar
  Gauntlet, Crusher Hall, the ramparts, the Lava Dungeon and the Keep. Also
  the **Magma Wheel** over a lava lake. King Grumble waits in the throne room
  (15 golden carrots).
* **Whisperwood** (far west, over the rope bridge from the Lonely Islet). The
  Elder Tree's shelf-fungus climb, Treetop Village's rope bridges, Bouncy Grove
  and the Bog's sinking lily pads. Old Rootjaw lives in **the Hollow**.
* **Cloudtop Heights** (climb the beanstalk; 18 golden carrots). Cloud Hop,
  the Rainbow Bridge, Captain Gust's airship and the Updraft Spire's rising
  winds. The Thunderhead broods over **the Stormcrown**. Falling off the
  clouds costs a heart and puts you back where you last stood.
* **???**: a secret. Ask Elder Shellby once you have 20 golden carrots.

## Bosses

Every boss telegraphs its attacks: a flashing circle on the floor shows where
lightning, lava or roots are about to strike, and shockwave rings are jumped.

| Boss | Where | How to hurt it |
| --- | --- | --- |
| **King Grumble** | Throne room above the castle | Bait him into charging a stone pillar, or survive his slams; then jump on a glowing weak point. Four weak points; he spits fireballs, raises lava, calls his bugs and finally gets **enraged**. |
| **Old Rootjaw** | The Hollow, Whisperwood | It lunges and gets its head stuck in the ground. Jump on the bud on its head. Seed bombs, root rings and Mosslings. |
| **Thunderhead** | The Stormcrown, Cloudtop | Dodge rounds of lightning, then it sinks down worn out. Stomp its storm core. Gales push you to the edge; it calls Puffers. |
| **The Shade** | The secret dungeon | A dark mirror bunny that runs your trail. Leaps at you, then it's dazed: jump on its head. Five hits, homing orbs, half-arena eruptions. |

## Baddies

| Baddie | How to beat it |
| --- | --- |
| Grumblebug | Stomp, ground pound, roll, slide or dive into it |
| Hopscotch Toad | Hops after you in big arcs. Stomp it. |
| Flitbat | Circles, then swoops. Stomp it, or roll or long jump into it. |
| Thornhog | All spikes: only a ground-pound shockwave works |
| Puffshroom | Puffs spores every few seconds. Stomp it between puffs. |
| Mossling | Hides as moss, pops up and chases. Stomp or roll. |
| Snapper | Rooted plant that rears back and lunges. Stomp its head while it droops. |
| Puffer | A grumpy cloud that blows you away. Stomp it from above. |

Baddies have proper little bodies and brains, Goomba-style. They:

* walk with gravity and step up small bumps, never wander off ledges, and lean
  to slopes;
* wander about, spot you only if they can see you (a "!" and a hop), chase,
  and give up with a "?" when you get away.

Each player's game predicts their movement between server updates and
animates them: scuttling legs, waddles, flaps, jaw snaps and a squash when
they're bopped.

## Things to collect and do

* **47 golden carrots**: Meadow 12, Peaks 7, Canyon 6, Castle 8, Whisperwood 6,
  Cloudtop 6, and 2 secret. Press **M > Carrot Log** for hints.
* **Silver carrot hunts**: five silvers per land; finding all five makes that
  land's golden appear.
* **Granny's Lost Kits**: five tiny grandkits, one in every land.
* **Time trials**: *Summit Sprint* (Peaks) and *Boulder Dash* (Canyon).
* **Ore-carrot rocks**: smash them (roll, slide, dive, pound or stomp) for
  carrot coins. They grow back after a few minutes.
* **Heart crates** before the hard parts.
* **18 stamps** (Pause > STAMPS). Put Roblox badge ids in `Config.Badges` to
  award real badges.
* **Fastest Bunnies**: a board by the meadow spawn with the 10 fastest 100%
  clears.

## Looks and the shop

**Customise** (fur, accent colour, hat, neckwear, trail) unlocks things as
you play:

* **Golden carrots** unlock most hats.
* **Bosses** give the King's Crown, Root Crown, Storm Cloud, Shade Halo, Shade
  fur and boss trails.
* **Every golden carrot** gives Golden fur.

**Carrot coins** come from carrots, silvers, golden carrots, bosses and
ore-carrot rocks. They're shared by all three files and spent in
**Pause > SHOP** on cosmetic-only items, with a live preview. Roblox Premium
members earn 1.5x coins.

Optionally, a **Supporter Pack** game pass (exclusive looks plus 1.5x coins)
and a **bag of coins** product can be sold for Robux. They stay "COMING SOON"
until you set their ids (see PUBLISHING.md). Nothing in the game can be bought
that affects gameplay.

## Friends

Talk with F (gamepad Y): Elder Shellby, Mayor Burrows and Granny Clover
(meadow), Pip (Peaks), Prospector Digby (Canyon), Guard Nibbles and Sir Ember
(castle), Ranger Fern and Professor Hoot (Whisperwood), Nimbus and Captain Gust
(Cloudtop), and one more who lives somewhere dark. Their lines live in
`Config.NPCs` and change as you progress.

## Design notes (the invisible stuff)

* **Coyote time, jump buffering, variable jump height**: the controls forgive
  you.
* **Wall jumps** give your double jump back. So do updrafts.
* **Blob shadow** under the bunny, so you always know where you'll land.
* **Readable danger**: telegraphed boss attacks, a beating last heart, heart
  crates before hard parts, a flashing warning before blink blocks vanish.
* **Iris wipes, region title cards, "golden carrot get!" celebrations.**
* **Contextual tips** the first time you meet a new idea (saved per file).
* **One theme, many moods**: every song is a variation on *Bunny's Theme*.

## Admin perks

Press **P** (or the **ADMIN** button) for the admin panel. The place owner,
`Config.Admins` and everyone in Studio get it. It offers:

* fly, god mode and speed;
* teleport to any checkpoint (including the secret dungeon) or the boss;
* bring, freeze, launch, heal or control players;
* reset all bosses;
* give yourself every golden carrot.

## Fair play

A Roblox client controls its own character's position, so the server
sanity-checks it:

* **Flying:** only the admin command can turn fly on, using a server-only
  flag. Players can't claim it to skip fall damage.
* **Leaderboard:** impossible jumps in position that no server teleport
  explains count as strikes, and enough strikes stop that file posting to
  the leaderboard. Clears under 30 minutes don't post either. Tune this in
  `Config.AntiCheat`.
* **Stamps:** long jumps and wall jumps only count when the server sees a
  real one (speed, airborne, next to a wall).

## Saving

Three files (A/B/C) per player in DataStoreService. Saving has:

* session locking and retries;
* autosave every 60 s, plus a save on leave, on shutdown, and on every golden
  carrot, boss win and purchase.

Looks, carrot coins and shop items are shared across files.

## Getting it into Roblox

1. Open **`Bunny64.rbxlx`** in Roblox Studio (File > Open from File).
2. **File > Publish to Roblox**.
3. **Game Settings > Security > Enable Studio Access to API Services** (for
   saving in Studio).
4. Press **Play**. The server builds the world at start-up, so the edit-mode
   viewport is empty.

Then follow **PUBLISHING.md** for the questionnaire, thumbnails, passes and
getting players.

## Working on the code

| Path | Purpose |
| --- | --- |
| `src/shared/Config.luau` | All tuning: moves, stamina, goals, gates, cosmetics, shop, sounds, music |
| `src/shared/BunnyModel.luau` | The bunny rig, hats, neckwear, trails, unlock rules |
| `src/server/World/*` | One builder per land, plus `Revamp` (new traversal circuits) and `Secret` |
| `src/server/World/Builder.luau` | Building helpers: terrain, ziplines, spring pads, wheels, slides, ore rocks... |
| `src/server/EnemyService.luau`, `EnemyModels.luau`, `BugModel.luau` | Baddie brains and models |
| `src/server/BossKit.luau` | Shared boss pieces: arenas, telegraphed strikes, shockwaves, projectiles, minions |
| `src/server/BossService.luau`, `BossRootjaw`, `BossThunderhead`, `BossShade` | The four bosses |
| `src/server/ShopService.luau` | Coin shop, game passes, developer products |
| `src/server/DataService.luau` | Saving |
| `src/client/Movement.luau`, `Animator.luau` | Moveset, stamina, ziplines, procedural animation |
| `src/client/Baddies.luau` | Smooth baddie rendering |
| `src/client/WorldFX.luau` | Region looks, music, hazards, gates, crumbling/blinking blocks, boss arenas |
| `src/client/Menus.luau`, `Hud.luau` | Menus (shop, map, log...) and HUD |
| `src/client/Chiptune.luau` | The 8-bit music engine and songs |

* **Rojo**: `rojo serve` with `default.project.json`.
* **Rebuild the place**: `python3 tools/build_place.py`.
* **Check**: `python3 tools/check_luau.py` runs a full Luau syntax check and
  also catches:
  * names used before their `local` declaration (a run-time crash in Luau);
  * calls to module functions that don't exist.

  Run it before rebuilding.
* **Check against Roblox's API**: `python3 tools/check_roblox_api.py
  API-Dump.json` flags properties, methods and Enum items that don't exist.
  The dump is published by the Roblox-Client-Tracker project; see the
  script's header for the link.
* **When testing in Studio**, keep **View > Output** open. Every per-frame
  system (moves, animation, baddies) reports its first error there as
  `[Bunny64] ...` and carries on, rather than freezing silently.

## Sound and music

All music is original 8-bit, played by `src/client/Chiptune.luau`, and every
song is a variation on one leitmotif, *Bunny's Theme*:

| Where | Arrangement |
| --- | --- |
| Title | lullaby |
| Meadow | march |
| Peaks | waltz |
| Canyon | trail tune |
| Castle | minor-key brood |
| Whisperwood | nocturne |
| Cloudtop | breezy F major |
| Underburrow | crawl in the dark |
| King Grumble | battle theme |
| Rootjaw and Thunderhead | galloping rival theme |
| The Shade | "mirror match" |
| Ending | reprise |

Put uploaded track ids in `Config.Music` to override any of them. Sound
effects use sounds bundled with Roblox.

## Changing the save format

Carrot ids are based on their positions, so moving a carrot in a builder makes
it a "new" carrot for existing saves.
