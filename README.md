# Noita Waves

A standalone single-player arena survival mode for Noita.

**Status: Alpha.** The mod is playable but still under active development; gameplay and compatibility may change.

## Installation

Copy this repository's contents into Noita's `mods/noita-arena-singleplayer` folder (create the folder if needed), so `mod.xml` is directly inside that folder. The folder name is required because the mod loads its scripts and menu banner using the `noita-arena-singleplayer` path.

Enable **Noita Waves** in Noita's Mods menu, then start a new game and choose **Noita Waves**. The mod uses vanilla game assets and does not require Noita Online or Noita Arena.

### Windows installer

For a guided install, download `NoitaWavesInstaller.exe` from the [GitHub Releases](https://github.com/tostechristian-ai/noita-waves-mod/releases) page and run it. Alternatively, download and extract `NoitaWaves-Installer.zip`, then double-click `Install-NoitaWaves.bat`. The installer detects common Steam library locations or lets you browse to the Noita folder. If an older `noita-arena-singleplayer` folder exists, it is preserved as a timestamped backup before the new files are installed.

This is a standard mod-folder installer, not a game injector: it does not modify Noita's executable or game data. Once installed, enable the mod in Noita's Mods menu.

## Current Focus

This prototype intentionally strips away the old spirit/AI ghost architecture and builds a clean wave-based arena loop instead.

- Player starts at the first Holy Mountain shop with a basic wand, a random full potion, an empty potion, and $200
- The first wave begins after a 1-minute countdown; the arena is placed 800 world units left of the original player spawn (200 farther left than before), with its ground search and fallback shifted 100 world units down
- Wave enemies get a high-contrast `!` marker; off-screen enemies get a directional edge arrow
- Waves take place at this same field; between waves the player returns to the tower level they're on and receives a fresh perk, full-health pickup, and spell refresh
- Every five cleared waves, the player descends to the next Holy Mountain level; supplies are refreshed there too
- Wave-based combat progression
- HUD displays the current wave, remaining enemies, kills, and gold
- Gold rewards after each cleared wave
- A 1-minute shop intermission between waves, with a clickable button to start the next wave early
- Increasing enemy count and health scaling after wave 5

## How to Play

1. Start Noita
2. Select "New Game"
3. Choose "Noita Waves"
4. Use the 1-minute preparation period at the Holy Mountain, then defeat each wave in the field left of the surface start
5. Spend your gold in the shop during the break
6. Return to the field for the next wave
7. After death, start a new game to begin another run

## Intended Gameplay Loop

```text
Start at the Holy Mountain shop with $200, a basic wand, a random full potion, and an empty potion
  -> Fresh tower perk, full-health pickup, and spell refresh
  -> 1-minute countdown; click the on-screen button to start wave 1 early
  -> Wave 1
  -> Spawn enemies
  -> Fight until all enemies are dead
  -> Earn gold and teleport to the Holy Mountain shop
  -> Every fifth wave, descend one tower level
  -> Refresh the local perk, full-health pickup, and spell refresh
  -> Shop break with fresh supplies; click the on-screen button to skip the remaining timer
  -> Automatically teleport back to the arena when the button is clicked or the 1-minute timer expires
  -> Teleport back to the field for the next arena wave
  -> Wave 2
  -> Track kills and wave progress on the HUD
  -> Repeat until player death and the game over screen
```

## Design Notes

This is not a Noita Together or multiplayer mode. It is a self-contained Noita mod that uses vanilla enemies, a surface arena, the Holy Mountain shop, a basic wand, and two starting potion bottles: one filled with a random vanilla potion material and one empty. Each completed wave awards $200 plus $100 for every additional wave. It does not duplicate the temple's normal shop offers; the three arena supplies are separate, tagged pickups. Any other temple/tower stock comes from separately enabled mods. It does not require Noita Online or Noita Arena.

## Status

The initial enemy roster uses the base-game `firebug`, `bat`, `bigfirebug`, and `bigbat` entity paths. Added enemies are not automatically added to its wave roster. During wave preparation and combat, non-wave `enemy` and `prey` entities within 400 world units of the arena are removed every 15 frames so they cannot distract from targets; mammoth entities (including babies) are also removed by filename if present, tracked wave enemies are excluded, and mobs elsewhere in the world are untouched. Markers identify only live enemies spawned for the current wave: a bright `!` follows visible targets, while colored `<`, `>`, `^`, or `v` arrows point toward targets beyond the screen edge. The arena is 800 Noita world units left of the initial player spawn, and its terrain search/fallback is shifted 100 units downward. Each fight teleport uses a clear grounded position when available and falls back to the saved arena position if the ground search cannot find one. At the start of a run, click the visible HUD button to reduce the first-wave countdown to one second; between waves, click the same-position HUD button to reduce the 1-minute shop break to one second. Both use their existing timer-driven transition paths. Each tower visit (run start and every cleared wave) refreshes one random perk, a full-health pickup, and a spell refresh at that floor. Every five cleared waves, the mode descends one level through the six existing Holy Mountain depths; after reaching the lowest level it stays there. Supplies created by this mod are tagged and replaced rather than stacked; repeated refresh requests for the same visit do not spawn another set. Arena spawn points are adjusted to the terrain surface where possible. Mods that replace these vanilla enemy files can change wave behavior, and major world/map or Holy Mountain overhauls can change terrain near the arena or shop. You should not need to disable every mod; if a wave reports a spawn error, test with mods that replace these enemies or overhaul the map disabled first.

The enabled New Enemies Mod adds mammoths and other surface creatures, while More Shop and More Tower Wands expand normal temple/tower stock. Their content is separate from the wave roster. The arena cleanup removes nearby non-wave `enemy`/`prey` entities and mammoth-file entities during preparation and combat, not the rest of the world.

A wave only counts as complete when every successfully loaded enemy from that wave is dead. Failed entity loads are retried and then shown as a spawn error instead of awarding a false victory. The run ends on player death and returns to Noita's game-over flow; use New Game to restart.
