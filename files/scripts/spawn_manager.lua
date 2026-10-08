spawn_manager = spawn_manager or {}

spawn_manager.spawn_offsets = {
    { x = -300, y = -24 },
    { x = 300, y = -40 },
    { x = -240, y = -48 },
    { x = 240, y = -16 },
    { x = -180, y = -32 },
    { x = 180, y = -52 },
    { x = -120, y = -20 },
    { x = 120, y = -44 },
    { x = -60, y = -28 },
    { x = 60, y = -36 },
}

function spawn_manager.get_spawn_point(index)
    local start = arena_state.spawn_offset_start or 1
    local offset_index = ((start + index - 2) % #spawn_manager.spawn_offsets) + 1
    local offset = spawn_manager.spawn_offsets[offset_index]
    local x = arena_state.arena_x + offset.x
    local reference_y = arena_state.arena_ground_reference_y or (arena_state.arena_y - 512)
    local surface_y = spawn_manager.get_ground_y(x, reference_y)
    if surface_y then
        return spawn_manager.get_free_position(x, surface_y - 32, 100, 120, 20)
    end

    return spawn_manager.get_free_position(
        x,
        arena_state.arena_y + offset.y,
        100,
        120,
        20
    )
end

function spawn_manager.get_ground_y(x, reference_y)
    local hit, _, surface_y = RaytracePlatforms(
        x,
        reference_y,
        x,
        reference_y + 2048
    )
    if hit and surface_y and surface_y > reference_y then
        return surface_y
    end

    hit, _, surface_y = RaytraceSurfaces(
        x,
        reference_y,
        x,
        reference_y + 2048
    )
    if hit and surface_y and surface_y > reference_y then
        return surface_y
    end

    return nil
end

function spawn_manager.get_grounded_player_position(x, reference_y, search_radius, step)
    search_radius = search_radius or 160
    step = step or 24

    for offset = 0, search_radius, step do
        local candidates = offset == 0 and { 0 } or { -offset, offset }
        for _, x_offset in ipairs(candidates) do
            local candidate_x = x + x_offset
            local surface_y = spawn_manager.get_ground_y(candidate_x, reference_y)
            if surface_y then
                local clearance_hit = RaytraceSurfaces(
                    candidate_x,
                    surface_y - 64,
                    candidate_x,
                    surface_y - 16
                )
                if not clearance_hit then
                    local free_x, free_y = candidate_x, surface_y - 56
                    if type(FindFreePositionForBody) == "function" then
                        local adjusted_x, adjusted_y = FindFreePositionForBody(
                            free_x,
                            free_y,
                            0,
                            0,
                            18
                        )
                        if adjusted_x and adjusted_y then
                            free_x, free_y = adjusted_x, adjusted_y
                        end
                    end
                    return free_x, free_y
                end
            end
        end
    end

    return nil, nil
end

function spawn_manager.get_free_position(x, y, radius_x, radius_y, step)
    if type(FindFreePositionForBody) == "function" then
        local free_x, free_y = FindFreePositionForBody(
            x,
            y,
            radius_x or 300,
            radius_y or 300,
            step or 30
        )
        if free_x and free_y then
            return free_x, free_y
        end
    end

    return x, y
end
