# Word Duel (MSGames)

Online word-ladder duels. Two players get the same START and TARGET word and race to turn one into the
other, changing one letter at a time (every step must be a real word). First to finish wins.

Built with **Godot 4.7** (GL Compatibility, portrait, Android) and a **Supabase** backend.

## Get the APK (no PC needed)

1. Push to `main` (or open the **Actions** tab, pick **Build Android APK** and press **Run workflow**).
2. When the run is green (about 5 to 8 minutes) open the repo's **Releases** page, find **Word Duel - latest build**
   and download `word-duel-debug.apk` on your phone. Allow "install unknown apps" when Android asks.

Every build gets a higher version code, so new APKs install over the old one.

### Signed release build (for Google Play later)
Add these in the repo under Settings, Secrets and variables, Actions:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | your keystore file as base64 (`base64 -w0 my.keystore`) |
| `ANDROID_KEYSTORE_ALIAS` | key alias |
| `ANDROID_KEYSTORE_PASSWORD` | keystore + key password |

With those set, the workflow also produces `word-duel-release.apk`.
Google Play requires an **AAB** for new apps. That needs Godot's Gradle build (see the Godot docs,
"Gradle builds for Android"); this workflow builds APKs only.

## How the game works

* **Ranked match**: matchmaking pairs players of similar division. If nobody is found within 7 seconds the server
  gives you a bot opponent, so there is never an empty queue.
* **Finish rules**: first to reach the target wins. If both finish within 1 second it is a **draw**.
  If time runs out, the player closest to the target wins.
* **Weekend matches** (Sat and Sun, Lagos time): puzzles are one division harder, rewards are bigger, and a
  draw is decided by the **fewest moves**.
* **7 divisions**: Rookie, Bronze, Silver, Gold, Platinum, Diamond, Legend (0 / 100 / 300 / 600 / 1000 / 1500 / 2200 trophies).
  You cannot drop below the start of your current division. Seasons reset monthly (soft reset plus coin reward).
* **Daily puzzle**: same puzzle for everyone, ranked by moves then time, with a daily streak bonus.
* **Play a friend**: 4-letter room code, no trophies.
* **Events**: rows in the `wd.events` table (double coins or double trophies for a date range).
* **Ads**: banner area, a full-screen ad every 3 matches, rewarded ads for hints, +25 coins and "double coins".

## Project layout

```
project.godot, export_presets.cfg     Godot project + Android export settings
data/words.txt                        dictionary (2,857 common 3-6 letter words) used by the game AND the database
scripts/                              GDScript: autoloads (config, api, game, sfx, ads), screens/, widgets/
art/                                  sprites: badges, icons, avatars, logo, background, fx; fonts (Lilita One + Nunito, OFL)
backend/                              SQL for Supabase (tables, game logic) + seed/puzzles.csv
tests/                                headless smoke test + mock server (runs in CI)
.github/workflows/build-android.yml   cloud APK build
```

## Backend (Supabase)

Project `word-duel` (eu-west-2). The game only calls RPC functions in the `public` schema; all tables live in a
private `wd` schema that the API cannot read directly. Players authenticate with an id + secret created on
first launch and stored on the device.

* Re-create from scratch: run `backend/001_tables.sql` then `backend/002_functions.sql` (needs the repo to be public,
  the data is loaded from raw.githubusercontent.com).
* Test the weekend rules any day: `insert into wd.settings values ('force_weekend','1') on conflict (key) do update set value='1';`
  (set it back to `'0'` afterwards).
* Add an event: `insert into wd.events (title, description, kind, multiplier, starts_at, ends_at) values ('Eid Double Coins','Double coins!','coin_x',2,'2027-03-20','2027-03-23');`
  (`kind` is `coin_x`, `trophy_x` or `info`).
* Tune rewards, trophies and bot speed in `wd.apply`, `wd.make_bot` in `002_functions.sql`.

## Real AdMob ads

The game currently shows **simulated test ads** (`scripts/ads.gd`). To show real ads:

1. Add an AdMob plugin for Godot 4 (for example the Poing Studios "godot-admob-android" plugin) and enable the
   Gradle build for Android (Project > Install Android Build Template, then enable *Use Gradle Build* in the Android
   export preset). The prebuilt non-Gradle build used by the workflow cannot load plugins.
2. Put your own ids in `scripts/config.gd` (the ids there are Google's public **test** ids).
3. In `scripts/ads.gd` replace the three places marked `REAL ADS` (banner, interstitial, rewarded). The rest of
   the game already calls `Ads.after_match()`, `Ads.show_rewarded()` and `Ads.set_banner()`.

## Tests

`python3 tests/mock_server.py .` then `godot --headless --path . -s tests/ui_test.gd`
plays a full match, the daily puzzle and every screen against the mock server.
