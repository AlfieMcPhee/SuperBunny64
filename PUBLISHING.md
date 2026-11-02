# Publishing Bunny 64 (and earning from it)

A practical checklist for getting the game public, switching on the optional
Robux items and giving it the best chance of finding players. Roblox changes
its dashboards and rules from time to time, so if a menu name below doesn't
match exactly, look for the nearest equivalent on the
[Creator Dashboard](https://create.roblox.com/dashboard/creations).

## 1. Publish

1. Open `Bunny64.rbxlx` in Roblox Studio and **File > Publish to Roblox**.
2. **Game Settings > Security**: turn on **Enable Studio Access to API
   Services** (saving) and leave HTTP off (the game doesn't need it).
3. **Game Settings > Basic Info**:
   * **Genre**: Adventure.
   * **Devices**: computer, phone, tablet, console. The game has touch
     buttons and full gamepad support.

## 2. Playtest before going public (most important)

Nothing in this project has been played in a live Roblox server yet. All the
checks so far are static (syntax and geometry reasoning). Before going public:

* **Play the whole thing with a few friends, especially on phones.**
  * Watch frame rate in the busy lands: the meadow, Whisperwood and the
    castle.
  * Check that controls feel good on touch.
* **Tuning to try first** (all in `src/shared/Config.luau`):
  * stamina: `Config.Stamina`;
  * weight: `RunAccel`, `FallGravityMult`, `HardLanding`;
  * the moves: `DiveSpeed`, `BackflipPower`, `PoundJumpPower`, `ZipSpeed`;
  * how strong updrafts and Puffer gusts are.
* **Walk every new route.**
  * Rides and jumps: spring pads landing on their targets, every zipline, the
    windmill wheel, the chairlift pylon, Geyser Gulch, the Magma Wheel.
  * The Underburrow from top to bottom: crumbling tiles, blink bridge,
    chimney and the long-jump gaps.
* **Fight every boss**:
  * King Grumble (now four phases);
  * Old Rootjaw;
  * the Thunderhead;
  * the Shade.
* **Saving**: quit and rejoin, then check coins, shop items and boss rewards
  are still there.

Fix anything that feels unfair before players see it. First impressions
decide whether Roblox recommends a game.

## 3. Maturity questionnaire

Roblox requires the **Maturity & Compliance questionnaire** before an
experience can be public (Creator Dashboard > your experience > Audience /
Questionnaire). Answer it honestly. Bunny 64 has cartoon stomping of bugs and
monsters, no blood, no real-world violence, no gambling or random paid items,
and no social features beyond the normal chat. That usually lands in the
mildest rating, which gives it the widest audience.

## 4. Icon, thumbnails and description

These matter more than almost anything else for clicks.

* **Icon (512×512):** the bunny's face, big and clear, with a golden carrot.
  It should read at thumbnail size on a phone.
* **Thumbnails (1920×1080, upload 3–5):**
  * a boss fight (the Thunderhead's lightning or King Grumble enraged);
  * Cloudtop Heights from a zipline;
  * the Underburrow's purple glow;
  * the bunny mid-backflip in the meadow.

  Use **Pause > PHOTO MODE** (free camera, HUD hidden) to take these.
* **Title:** "Bunny 64" plus a short hook is fine, e.g. "Bunny 64 – 3D
  Platformer Adventure".
* **Description:** one line of what it is, then bullets: 7 lands, 4 bosses,
  47 golden carrots, a secret dungeon, a dive / backflip / pound jump moveset,
  3 save files, an original chiptune soundtrack.

## 5. Optional Robux items

Everything you can buy is cosmetic or coins for cosmetics. Nothing affects
gameplay, which keeps it fair and keeps the questionnaire simple.

### Supporter Pack (game pass)

1. Creator Dashboard > your experience > **Monetization > Passes > Create a
   Pass**.
2. Name it "Supporter Pack", upload a 512×512 icon, and save.
3. Open the pass, turn **Item for Sale** on and set a price. 199–399 Robux is
   typical for a supporter pass.
4. Copy the pass **ID** (a number in the URL or the pass details) into
   `Config.GamePasses.supporter.id`.

The pack gives the Stardust fur, Space Helmet, Hero Cape, Rainbow trail and
1.5x carrot coins. Edit the items with `pass = "supporter"` in Config to
change what it includes.

### Bag of Carrot Coins (developer product)

1. **Monetization > Developer Products > Create**: name it "Bag of Carrot
   Coins" and set a price (49–99 Robux is typical).
2. Copy its **ID** into `Config.Products.coins.id`. Change
   `Config.Products.coins.coins` to set how many coins it gives (default
   1000).

Receipts are recorded in the player's save, so a purchase is never granted
twice even if Roblox retries.

### Private servers

**Monetization > Private Servers**: turn them on and set a monthly price. This
needs no code.

### Premium Payouts

Automatic: Roblox pays you for time Premium subscribers spend in your game.
Bunny 64 gives Premium members 1.5x carrot coins as a thank-you.

After setting any ids, rebuild (`python3 tools/build_place.py`) or edit
Config in Studio, then publish again.

## 6. Badges (optional)

Create badges on the Creator Dashboard (Engagement > Badges) and put their
ids in `Config.Badges` against stamp ids, e.g. `golden20 = 1234567890`. Good
ones:

* `golden1`
* `golden20`
* `boss`
* `allbosses`
* `regions`

## 7. Getting players

* **Sponsored ads:** the Roblox Ads Manager lets you spend Robux (or money) to
  show the game in Discover. Start small, with a few days on your best
  thumbnail, and watch how many people come back the next day.
* **Short videos:** 15–30 second clips work well on TikTok, YouTube Shorts and
  Reels. Good subjects:
  * the boss intros;
  * a zipline into the clouds;
  * falling down the well into the Underburrow ("secret area!");
  * a perfect run through the Firebar Beam.
* **A Discord server** for players to share secrets and bugs.
* **Updates every few weeks.** A new silver hunt, a new trial, a new hat in
  the shop or a seasonal event each give a reason to come back, and updates
  help with the algorithm.
* **Watch your analytics** (Creator Dashboard > Analytics): day-1 retention
  and average session time are what Roblox's recommendations care about. If
  people leave in the first five minutes, make the start of the meadow more
  exciting before spending on ads.

## 8. Cashing out (DevEx)

Earned Robux can be exchanged for real money through the Developer Exchange
once you meet its requirements. These include a minimum age, a minimum
balance of earned Robux, a verified account and good standing. The exact
rules and rates change, so check Roblox's current DevEx page before planning
around them.
