arena_manager = arena_manager or {}

function arena_manager.begin()
    if not arena_state then
        arena_state = {}
    end

    arena_state.round = 1
    arena_state.state = "ready"
    arena_state.wave_break_started_at = nil
    wave_manager.start_wave(1)
end

function arena_manager.update()
    if not arena_state then
        return
    end

    local player = EntityGetWithTag("player_unit")
    if not player or not player[1] or not EntityGetIsAlive(player[1]) then
        arena_state.state = "game_over"
        if not arena_state.game_over_shown then
            arena_state.game_over_shown = true
            GamePrintImportant(
                "Game Over",
                "Wave " .. tostring(arena_state.round or 1) .. " reached. Kills: " .. tostring(arena_state.kills or 0)
            )
            GameTriggerGameOver()
        end
        return
    end

    wave_manager.update()
end
