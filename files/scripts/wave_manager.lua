wave_manager = wave_manager or {}

function wave_manager.start_wave(wave_number)
    if not arena_state then
        return false
    end

    shop_manager.select_arena_for_wave(wave_number)
    local arena_x, arena_y = shop_manager.get_arena_location()
    local players = EntityGetWithTag("player_unit")
    if players and players[1] then
        if not arena_x or not arena_y then
            arena_x, arena_y = EntityGetTransform(players[1])
        end
        shop_manager.teleport_player(players[1], arena_x, arena_y)
    end

    arena_state.round = wave_number
    arena_state.state = "preparing"
    arena_state.spawn_offset_start = math.random(1, #spawn_manager.spawn_offsets)
    arena_state.enemies = {}
    arena_state.pending_spawns = {}
    for _, enemy_name in ipairs(enemy_manager.get_wave_enemies(wave_number)) do
        table.insert(arena_state.pending_spawns, { name = enemy_name, attempts = 0 })
    end
    arena_state.spawn_retry = 0
    arena_state.spawn_next_attempt = GameGetFrameNum() + 60
    arena_state.spawn_failure_shown = false
    arena_state.arena_landing_resolved = false
    arena_state.enemy_leash_state = {}
    arena_state.leash_next_check = 0
    arena_state.leash_notice_until = nil
    arena_state.ambient_cleanup_next = 0
    arena_state.wave_enemies = #arena_state.pending_spawns
    arena_state.wave_kills = 0
    arena_state.last_enemy_count = 0
    GamePrintImportant("Wave " .. wave_number, "Enemies are approaching the arena.")
    return true
end

function wave_manager.request_shop_skip()
    if not arena_state or arena_state.state ~= "shop" or arena_state.shop_skip_requested then
        return false
    end

    arena_state.shop_skip_requested = true
    arena_state.shop_started_at = GameGetFrameNum() - shop_manager.shop_duration + 60
    GamePrint("Arena: next wave starts in 1 second.")
    return true
end

function wave_manager.update()
    if not arena_state then
        return
    end

    if arena_state.state == "preparing" or arena_state.state == "battle" then
        enemy_manager.cleanup_ambient_near_arena()
    end

    if arena_state.state == "preparing" then
        if GameGetFrameNum() < arena_state.spawn_next_attempt then
            return
        end

        if not arena_state.arena_landing_resolved then
            local players = EntityGetWithTag("player_unit")
            local player = players and players[1]
            if player and EntityGetIsAlive(player) then
                shop_manager.finalize_arena_player_spawn(player)
            end
            arena_state.arena_landing_resolved = true
            print(
                "Noita Waves: loading selected arena terrain completed; wave mobs will use arena center "
                    .. tostring(arena_state.arena_x) .. ", " .. tostring(arena_state.arena_y)
            )
        end

        local spawned, missing, failed = enemy_manager.spawn_missing(
            arena_state.pending_spawns,
            arena_state.round,
            #arena_state.enemies
        )
        for _, entity in ipairs(spawned) do
            table.insert(arena_state.enemies, entity)
        end
        arena_state.pending_spawns = missing

        if #failed > 0 then
            arena_state.state = "spawn_error"
            if not arena_state.spawn_failure_shown then
                arena_state.spawn_failure_shown = true
                GamePrintImportant(
                    "Wave Spawn Failed",
                    "Could not load all enemies. Check the Noita log for missing or modified enemy files."
                )
            end
        elseif #missing == 0 and #arena_state.enemies > 0 then
            arena_state.state = "battle"
            arena_state.last_enemy_count = #arena_state.enemies
            GamePrintImportant("Wave " .. arena_state.round, #arena_state.enemies .. " enemies spawned")
        elseif arena_state.spawn_retry < 4 then
            arena_state.spawn_retry = arena_state.spawn_retry + 1
            arena_state.spawn_next_attempt = GameGetFrameNum() + 60
        else
            arena_state.state = "spawn_error"
            if not arena_state.spawn_failure_shown then
                arena_state.spawn_failure_shown = true
                GamePrintImportant(
                    "Wave Spawn Failed",
                    "Could not load all enemies. Check the Noita log for missing or modified enemy files."
                )
            end
        end
        return
    end

    if arena_state.state == "shop" then
        local started_at = arena_state.shop_started_at or GameGetFrameNum()
        if GameGetFrameNum() >= started_at + shop_manager.shop_duration then
            wave_manager.start_wave(arena_state.next_round)
        end
        return
    end

    if arena_state.state ~= "battle" then
        return
    end

    local remaining_enemies = enemy_manager.count_alive_enemies(arena_state.enemies)
    local players = EntityGetWithTag("player_unit")
    enemy_manager.update_leash(arena_state.enemies, players and players[1])
    local killed = math.max(0, (arena_state.last_enemy_count or remaining_enemies) - remaining_enemies)
    if killed > 0 then
        arena_state.kills = (arena_state.kills or 0) + killed
        arena_state.wave_kills = (arena_state.wave_kills or 0) + killed
        arena_state.last_enemy_count = remaining_enemies
    end

    if remaining_enemies <= 0 then
        local player = players and players[1]
        if not player then
            return
        end

        local completed_round = arena_state.round
        local next_round = completed_round + 1
        local reward = shop_manager.award_wave_gold(player, completed_round)
        local moved_to_lower_floor = shop_manager.advance_tower_floor(completed_round)

        arena_state.state = "shop"
        arena_state.next_round = next_round
        arena_state.shop_started_at = GameGetFrameNum()
        arena_state.shop_skip_requested = false
        local shop_x, shop_y = shop_manager.get_shop_location()
        shop_manager.teleport_player_to_shop(player)
        shop_manager.refresh_tower_supplies("round_" .. tostring(next_round), shop_x, shop_y)

        if moved_to_lower_floor then
            GamePrintImportant(
                "Wave Cleared! Tower Descent",
                "You earned $" .. reward .. ". Supplies refreshed on tower level "
                    .. tostring(arena_state.tower_floor) .. "; wave " .. next_round
                    .. " starts in 1 minute; use the button to start sooner."
            )
        else
            GamePrintImportant(
                "Wave Cleared!",
                "You earned $" .. reward .. ". Shop now; wave " .. next_round
                    .. " starts in 1 minute; use the button to start sooner."
            )
        end
    end
end
