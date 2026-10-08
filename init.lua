-- Noita Waves
-- Clean standalone wave-based arena mod

print("Noita Waves initialized")

arena_state = arena_state or {
	round = 1,
	state = "initializing",
	player_spawned = false,
	started = false,
}

dofile_once("mods/noita-arena-singleplayer/files/scripts/spawn_manager.lua")
dofile_once("mods/noita-arena-singleplayer/files/scripts/enemy_manager.lua")
dofile_once("mods/noita-arena-singleplayer/files/scripts/shop_manager.lua")
dofile_once("mods/noita-arena-singleplayer/files/scripts/wave_manager.lua")
dofile_once("mods/noita-arena-singleplayer/files/scripts/arena_manager.lua")
dofile_once("mods/noita-arena-singleplayer/files/scripts/game_manager.lua")
dofile_once("mods/noita-arena-singleplayer/files/scripts/hud.lua")

function OnModPostInit()
	print("Noita Waves post-init")
	game_manager.init()
end

function OnMagicNumbersAndWorldSeedInitialized()
	print("Noita Waves world initialized")
end

function OnPlayerSpawned(player_entity)
	print("Player spawned in Noita Waves")

	arena_state.player_spawned = true
	GameAddFlagRun("arena_singleplayer_loaded")

	if not arena_state.run_initialized then
		shop_manager.set_arena_origin(player_entity)
		game_manager.begin_new_run(player_entity)
	end

	local damage_model = EntityGetFirstComponent(player_entity, "DamageModelComponent")
	if damage_model then
		ComponentSetValue2(damage_model, "invincible_time", 120)
	end
end

function OnWorldPreUpdate()
	if not GameHasFlagRun("arena_singleplayer_loaded") then
		return
	end

	if not arena_state.started then
		local players = EntityGetWithTag("player_unit")
		if players and players[1] and not arena_state.run_initialized then
			shop_manager.set_arena_origin(players[1])
			game_manager.begin_new_run(players[1])
		end
	end

	if arena_state.started and arena_state.state ~= "game_over" then
		game_manager.update()
	end
end

function OnWorldPostUpdate()
	if GameHasFlagRun("arena_singleplayer_loaded") then
		arena_hud.draw()
	end
end

function OnPausedChanged(paused, is_wand_pickup)
	if paused then
		GameAddFlagRun("arena_singleplayer_paused")
	else
		GameRemoveFlagRun("arena_singleplayer_paused")
	end
end
