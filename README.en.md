<div align="center">

# LumoraRPG

**A Megabonk-style 3D pixel-art roguelike survivor: waves of monsters, weapons that fire on their own, bosses, pets, a skill tree and live co-op with friends.**

**[Play in the browser →](https://highlvmami.github.io/LumoraRPG/)** · **[Download for Windows](https://github.com/highlvmami/LumoraRPG/releases/download/latest/LumoraRPG-windows.zip)**

[Türkçe](README.md) · English

<p>
  <img src="https://img.shields.io/badge/Godot-4.5-478CBF?logo=godotengine&logoColor=white" alt="Godot 4.5">
  <img src="https://img.shields.io/badge/GDScript-355570?logo=godotengine&logoColor=white" alt="GDScript">
  <img src="https://img.shields.io/badge/Node.js-20%2B-339933?logo=nodedotjs&logoColor=white" alt="Node.js">
  <img src="https://img.shields.io/badge/WebSocket-010101?logo=socketdotio&logoColor=white" alt="WebSocket">
  <img src="https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white" alt="PostgreSQL">
  <img src="https://img.shields.io/badge/Render-46E3B7?logo=render&logoColor=black" alt="Render">
  <img src="https://img.shields.io/badge/GitHub%20Actions-2088FF?logo=githubactions&logoColor=white" alt="GitHub Actions">
</p>

</div>

You pick a character and drop onto an open map. Monsters come from every side, your weapons hit whatever gets in range, and you keep moving to stay alive. Every level you pick one of three cards to power up for that run, and a boss shows up every five minutes. When the run ends, the EXP, gold, items and chests you earned stay on your account: gear, pets and the skill tree make the next run stronger. The game is made with Godot 4.5 and runs in the browser and on Windows; online accounts and co-op go through a small Node.js server. The game itself is in Turkish.

> The online server runs on Render's free plan. After a while without players it goes to sleep, and the first connection then takes up to a minute. If the server can't be reached, the game opens offline with the account saved on this device.

## Screenshots

<p align="center">
  <img src="docs/screenshots/oyun.jpg" alt="In a run: a mage, pets and level-up cards" width="100%">
</p>

<p align="center">
  <img src="docs/screenshots/yetenek-agaci.jpg" alt="Skill tree growing out from the middle" width="49%">
  <img src="docs/screenshots/taverna.jpg" alt="Room: players sitting in the tavern" width="49%">
</p>

<p align="center">
  <img src="docs/screenshots/petler.jpg" alt="Pet slots" width="49%">
  <img src="docs/screenshots/pet-listesi.jpg" alt="Pet list" width="49%">
</p>

<p align="center">
  <img src="docs/screenshots/siralama.jpg" alt="Leaderboard" width="32%">
  <img src="docs/screenshots/karakterler.jpg" alt="Characters" width="32%">
  <img src="docs/screenshots/canta.jpg" alt="Backpack" width="32%">
</p>

<p align="center"><sub>In a run · Skill tree · Tavern (room) · Pet slots and pet list · Leaderboard · Characters · Backpack. Taken with sample data.</sub></p>

## Features

### Gameplay
- **Random maps:** Calm Forest, Beach Town and Deadly Dungeon; every run starts on one of them.
- **Auto attack:** the nearest monster inside your range ring gets hit. Next to the class weapon you can carry up to 5 weapons (spinning blades, fireball, lightning, holy ground and a class skill), each with 5 levels.
- **Level-up cards:** every level shows 3 cards without pausing the game (1 · 2 · 3 or click); boosts last for the run.
- **Monsters change over time:** slimes, fast wolves, rock-throwing goblins and giant spiders, growing in number and strength.
- **Bosses:** every 5 minutes the Forest Giant or the Spider Queen. They mark their attacks with red zones on the ground and get angrier, with new attacks, as their health drops.
- **Ultimate (R / Q):** each class has two, hitting every enemy on the map.

### Characters, items and chests
- Up to 3 characters per account: **Warrior**, **Archer**, **Mage**.
- 6 rarities (Common → Divine) and 6 equipment slots; worn gear shows on the character.
- **Shared backpack:** filter by slot and rarity, always sorted by rarity, with items another character wears at the end. Hovering an item shows its stats compared with what you wear.
- **Chests:** bosses drop them and the market sells them; a wheel spins and stops on your prize.

### Pets
- **9 pets** from eggs, in 4 rarities: Bear, Fox, Frog (Common); Minotaur, Owl, Turtle (Rare); Unicorn, Baby Dragon (Epic); Phoenix (Legendary).
- 3 slots opening at account levels 10, 25 and 50; pets in slots give their stats and follow you in runs at a small, cute size (flyers hover above you).
- **Pet collection:** every pet, rarest first; the ones you have found in color, the rest gray.

### Skill tree
- **Lumora's Heart** in the middle with four branches around it, each in its own color: **Offense**, **Defense**, **Fortune** and the out-of-run **Treasury** (backpack space, chest luck, market discount, sell price, item drop chance, egg luck).
- Every account level gives 2 skill points; skills further out cost more. Reset any time.

### Online
- **Accounts:** username and password; your game is stored on the server so the same account works on any computer. "Remember me" skips the password.
- **Tavern room:** open a room, invite a friend or share the 5-letter code (up to 4 players). Everyone in the room sits at the tavern table; when someone joins, their character walks in through the door and takes a free chair. When the host presses PLAY, everyone plays live on the same map.
- **Leaderboards:** account level, monsters killed, bosses beaten, character level, survival time, damage dealt and gold earned.
- **Friends:** online status and account level next to each name, plus a list of everyone online now.

### More
- 24 achievements with gold rewards, logs of the last 50 runs, version notes, graphics/camera/interface settings.
- The Windows build updates itself on every start (it only downloads the small game pack).

## Controls

| Key | Action |
|---|---|
| WASD / arrow keys | Move |
| Space | Jump |
| Mouse | Turn the camera (click the game window first) |
| Mouse wheel | Zoom in / out |
| 1 · 2 · 3 | Pick a level-up card |
| R / Q | Ultimate |
| Esc / P | Pause (resume, quality, main menu, boosts) |
| F1 | Developer menu (only on an account that entered the secret code in Settings) |

## How it works

- **Data-driven balance:** monsters, weapons, items, pets, skills and achievements live in JSON files under `data/`; changing numbers needs no code.
- **Pixel look:** the world renders into a low-resolution SubViewport and is scaled up, while the interface stays sharp at full resolution. Models are built from boxes in code; there are no image files.
- **Co-op:** the player who opened the room runs the game (enemies, damage, rewards). The server only relays messages; the host sends the state 10 times a second and the others send their moves and hits.
- **Accounts:** the server keeps passwords only as scrypt hashes and session tokens as sha256 hashes. Saved games are stored as JSONB and the newest save wins; leaderboards are computed from those saves.
- **Continuous delivery:** every PR runs the Godot tests, the server test and a two-game co-op test on GitHub Actions, and checks that the web build starts in Chrome. Merging to `main` publishes the web build to GitHub Pages and the Windows build to Releases.

## Tech stack

| Part | Technology |
|---|---|
| Game | Godot 4.5 (GDScript) |
| Server | Node.js, `ws`, `pg` |
| Database | PostgreSQL (server memory without one) |
| Hosting | GitHub Pages (web), GitHub Releases (Windows), Render (server) |
| Tests | Godot headless tests, Node server test, headless Chrome |

## Project layout

| Folder | What |
|---|---|
| `scripts/` | Game code: player, enemies, weapons, progression, UI, networking |
| `data/` | Balance and content (JSON) |
| `scenes/` | Start-up (updater) and main scene |
| `server/` | Online server: accounts, rooms, invites, leaderboards, co-op relay |
| `tests/` | Automated tests |
| `docs/` | Roadmap and screenshots |

## Running it

1. Download [Godot 4.5](https://godotengine.org/download) (standard build), **Import** `project.godot` and press **F5**.
2. To try the server locally:

```bash
cd server
npm install
node index.js                  # ws://localhost:8080
```

Start the game with `-- --server=ws://localhost:8080` to use it. With `DATABASE_URL` set, accounts are kept in PostgreSQL.

Tests:

```bash
godot --headless --path . -s res://tests/smoke_test.gd
godot --headless --path . -s res://tests/coop_test.gd    # needs node
(cd server && node test.js)
```

Design and roadmap (Turkish): [docs/ROADMAP.md](docs/ROADMAP.md)
