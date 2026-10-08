# Legacy architecture audit

## Scope

The active mode is a standalone wave loop. The cleanup removes only the disconnected spirit-combat prototype and its unused UI/build-generation helpers; the current wave, enemy, arena, game, and spawn managers are retained.

## Dependency map

```text
mod.xml
  ├─ registers the game mode and menu text
  ├─ menu background → menu_banner_background.png
  └─ menu foreground → menu_banner_overlay.png

Noita mod callbacks → init.lua
  ├─ dofile_once → spawn_manager.lua
  ├─ dofile_once → enemy_manager.lua
  ├─ dofile_once → shop_manager.lua
  ├─ dofile_once → wave_manager.lua
  ├─ dofile_once → arena_manager.lua
  ├─ dofile_once → game_manager.lua
  └─ dofile_once → hud.lua

game_manager.lua → arena_manager.lua
arena_manager.lua → wave_manager.lua
wave_manager.lua → enemy_manager.lua
enemy_manager.lua → spawn_manager.lua → terrain-adjusted offsets near the saved surface spawn
enemy_manager.lua → vanilla data/entities/animals/*.xml
shop_manager.lua → spawn_manager.lua → terrain lookup for the combat-field landing point
game_manager.lua → vanilla data/entities/items/wand_level_01.xml
hud.lua → on-screen markers for live entities tracked by the current wave

Removed, unreachable prototype
  ├─ files/scripts/ui.lua (no loader or callers)
  ├─ files/scripts/build_generator.lua (no loader or callers)
  └─ files/entities/arena_spirit.xml
       └─ LuaComponent → files/scripts/spirit_ai.lua
```

The four removed files had no path from `init.lua` or `mod.xml`. The spirit entity only referenced its AI script internally. The active mode and metadata do not declare a dependency on the separate Noita Arena or Noita Online mods. `gun_actions.lua` and `gun_enums.lua` were also loaded by `init.lua` but their globals were unused.

The separate multiplayer Arena mod was identified as the source of the Noita Online prompt: when enabled, its `OnPlayerSpawned` callback kills the player and displays a missing-Online popup. It is not a dependency in this Singleplayer mod. The user disabled the conflicting Arena mod in Noita's active mod configuration; the Singleplayer spawn callback records its run flag/player state before moving the player.

## Findings

- The player starts at the first Holy Mountain shop with $200 and a basic wand. A HUD countdown delays wave one by 1 minute. The combat field is 800 world units left of the original player spawn, with its ground reference shifted 100 units down. Before each fight, player placement checks nearby ground candidates and headroom, then starts above the surface. Enemy spawn points are randomized within 300 world units of the arena center and use the saved above-ground reference. Between waves, the player returns to the active Holy Mountain floor; every five cleared waves advances one floor through six known depths, then remains at the lowest.
- Each wave begins only after a short world-load delay. Enemy IDs are tracked per wave; only those living entities affect completion. Failed loads retry up to five times and then stop in a visible spawn-error state instead of awarding a false clear.
- HUD markers follow only the tracked live entities from the current wave. Visible targets receive a high-contrast `!`; off-screen targets receive a directional arrow pinned to the screen edge. Nearby non-wave `enemy` and `prey` entities are removed from the arena during wave preparation and combat, while tracked wave entities and the rest of the world are preserved.
- The initial 1-minute countdown and each 1-minute tower intermission have a clickable HUD button to shorten the existing timer to one second remaining.
- Clearing a wave awards gold and returns the player to the tower supplies for the timed intermission; the automatic timer remains the fallback.
- The mode does not generate duplicate shop offers. Additional temple/tower items are provided by separately enabled shop/content mods.
- At run start and after every cleared wave, the player receives a newly spawned random perk, full-health pickup, and spell refresh at the current tower floor, including after descending. Tagged mod-created supplies are replaced at the next visit; repeated refresh requests for the same transition are ignored, and supplies remain available throughout the timed break.
- During wave preparation and combat, the wave manager asks `enemy_manager.lua` to remove nearby non-wave `enemy` and `prey` entities and filename-matched mammoth entities inside the 400-unit arena radius every 15 frames. Wave-tracked entities are excluded; other parts of the world are untouched.
- `game_manager.lua` grants one vanilla level-1 wand, one randomly filled vanilla potion, and one empty potion at run start, retrying if the player is not ready when first requested.
- `hud.lua` displays wave number, enemy count, total kills, gold, and remaining shop time. Player death shows the reached wave/kill count and enters Noita's native game-over flow.
- The deleted HUD and build generator were never loaded or called. The spirit entity/AI pair was likewise disconnected from the active wave loop.
- The removed opponent-archetype README claims did not describe the active implementation. README now documents the wave-based prototype instead.

## Cleanup disposition

Removed `files/scripts/ui.lua`, `files/scripts/build_generator.lua`, `files/scripts/spirit_ai.lua`, and `files/entities/arena_spirit.xml`. Removed the unused vanilla gun-script imports from `init.lua`. Kept the active manager modules, entrypoint, metadata, and menu banners. The user disabled the conflicting separate Arena mod in the active Noita mod configuration.
