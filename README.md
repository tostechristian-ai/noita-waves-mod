# Noita Waves

A standalone single-player arena survival mode for Noita.

**Current release: `v0.1.0-alpha.3` (pre-release).** This update adds rotating overworld arenas, safer local ambient cleanup, wave-enemy recovery, and a more varied, bounded wave roster. Gameplay and compatibility may change during alpha development.

## Installation

### Windows installer

Download `NoitaWavesInstaller.exe` from the [GitHub Releases](https://github.com/tostechristian-ai/noita-waves-mod/releases) page and run it. The installer detects common Steam library locations or lets you browse to the Noita game folder. Alternatively, download and extract `NoitaWaves-Installer.zip`, then run `Install-NoitaWaves.bat`. Both install the same mod payload into `mods\noita-arena-singleplayer`; an existing folder is moved to a timestamped backup before replacement.

This is a standard mod-folder installer. It does not inject code, patch Noita's executable or game data, or enable the mod automatically. After installation, enable **Noita Waves** in Noita's Mods menu and choose it from New Game.

### Manual install

Copy the mod payload (`init.lua`, `mod.xml`, the two menu banner PNGs, `files/`, and `README.md`) into Noita's `mods/noita-arena-singleplayer` folder. Keep `mod.xml` directly inside that folder. The repository's `installer/`, `tests/`, and `LEGACY_AUDIT.md` are not part of the game mod payload.

The mod uses vanilla game assets and does not require Noita Online or Noita Arena.

## Gameplay

- Start at the first Holy Mountain shop with a basic wand, a random full potion, an empty potion, and $200.
- Prepare for one minute before wave 1; use the on-screen button to start early.
- Five fixed overworld arena candidates rotate in a shuffled order without repeating the same location consecutively. Terrain is loaded before a best-effort clear landing position is resolved; mobs use that wave's resolved arena center.
- Waves 1-10 introduce vanilla enemy types gradually, with no more than 10 enemies per wave. Later waves use a capped endless mix with bounded upgrades.
- Enemy health scales smoothly after wave 5, up to a 1.5x cap, while preserving each enemy's native health fraction and respecting its native maximum-health cap.
- Tracked wave enemies receive a bright `!` marker; off-screen enemies get a directional edge marker.
- During preparation and combat, cleanup checks only within 700 world units of the selected arena and only removes ordinary root enemy entities with animal AI and a damage model. It protects wave enemies, the player, interactable entities, and tagged NPC/shopkeeper/boss categories. Unusual modded enemies outside this filter may remain.
- If a tracked wave enemy stays more than 1000 units from the player or 1200 units from the arena for three seconds, the mod attempts to recover it near the player. Recovery is separated from the player, rate-limited per enemy, and does not kill the enemy or change wave counts.
- Each cleared wave awards gold and returns the player to the Holy Mountain shop for a one-minute intermission. The button can start the next wave early. Every five cleared waves, the player descends one tower floor.
- Tower visits refresh a perk, full-health pickup, and spell refresh without stacking this mod's own supplies. The HUD shows wave, kills, gold, enemy count, markers, and recovery notices.

## How to Play

1. Start Noita, select **New Game**, and choose **Noita Waves**.
2. Prepare at the Holy Mountain or use the HUD button to start wave 1 early.
3. Defeat the enemies in the selected field, then spend your gold during the shop break.
4. Wait for the next wave or use the HUD button to start it early.
5. After death, start a new game to begin another run.

## Design Notes

This is a self-contained Noita mod, not a Noita Together or multiplayer mode. It uses vanilla enemies and the Holy Mountain shop, and does not depend on Noita Online or Noita Arena. Each completed wave awards $200 plus $100 for every additional wave. The mod's three arena supplies are separate tagged pickups and do not duplicate the temple's normal shop offers. Other temple/tower stock comes from separately enabled mods.

Arena X coordinates are candidate estimates, not guaranteed clear landing spots. Noita world generation and other map mods can change terrain; if the terrain search cannot find a suitable position, the mod uses its non-blocking coordinate fallback. Locations, spawn attempts, and leash recoveries are logged. Mods that replace vanilla enemy files can change wave behavior. Failed enemy loads are retried and then shown as a spawn error instead of awarding a false victory.

During combat, nearby ordinary ambient enemies may be removed inside the bounded arena cleanup radius. The cleanup does not scan or remove enemies elsewhere in the world. The run ends on player death and returns to Noita's game-over flow.

## Developer Checks

From the source repository, run `python tests/test_spawn_safety.py` for focused checks covering cleanup protections, arena rotation and spawn centering, leash recovery, placement fallback, tower cycling, intermission, and wave balance. Lua/game runtime behavior still requires in-game verification.
