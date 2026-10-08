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

function spawn_manager.get_ground_y(x, reference_y)
    if type(RaytracePlatforms) == "function" then
        local hit, _, surface_y = RaytracePlatforms(x, reference_y, x, reference_y + 5120)
        if hit and surface_y and surface_y > reference_y then
            return surface_y
        end
    end

    if type(RaytraceSurfaces) == "function" then
        local hit, _, surface_y = RaytraceSurfaces(x, reference_y, x, reference_y + 5120)
        if hit and surface_y and surface_y > reference_y then
            return surface_y
        end
    end
    return nil
end

local function has_clear_standing_space(x, surface_y)
    if type(RaytraceSurfaces) ~= "function" then
        return true
    end

    for _, x_offset in ipairs({ -16, 0, 16 }) do
        local hit = RaytraceSurfaces(
            x + x_offset,
            surface_y - 120,
            x + x_offset,
            surface_y - 8
        )
        if hit then
            return false
        end
    end
    return true
end

function spawn_manager.get_grounded_player_position(
    x,
    reference_y,
    search_radius,
    step,
    expected_surface_y,
    max_vertical_delta
)
    search_radius = search_radius or 160
    step = step or 24

    for offset = 0, search_radius, step do
        local candidates = offset == 0 and { 0 } or { -offset, offset }
        for _, x_offset in ipairs(candidates) do
            local candidate_x = x + x_offset
            local surface_y = spawn_manager.get_ground_y(candidate_x, reference_y)
            local within_vertical_band = surface_y and (not expected_surface_y
                or math.abs(surface_y - expected_surface_y) <= (max_vertical_delta or 384)
            )
            if surface_y and within_vertical_band and has_clear_standing_space(candidate_x, surface_y) then
                local player_x, player_y = candidate_x, surface_y - 56
                if type(FindFreePositionForBody) == "function" then
                    local adjusted_x, adjusted_y = FindFreePositionForBody(
                        player_x,
                        player_y,
                        0,
                        0,
                        18
                    )
                    if adjusted_x and adjusted_y
                        and has_clear_standing_space(adjusted_x, adjusted_y + 56)
                    then
                        player_x, player_y = adjusted_x, adjusted_y
                    end
                end
                return player_x, player_y
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
            0,
            0,
            math.min(radius_x or 18, radius_y or 18)
        )
        if free_x and free_y then
            return free_x, free_y
        end
    end
    return x, y
end

function spawn_manager.get_spawn_point(index)
    local start = arena_state.spawn_offset_start or 1
    local offset_index = ((start + index - 2) % #spawn_manager.spawn_offsets) + 1
    local offset = spawn_manager.spawn_offsets[offset_index]
    local x = arena_state.arena_x + offset.x
    local reference_y = arena_state.arena_ground_reference_y or (arena_state.arena_y - 512)

    if type(GameGetCameraBounds) == "function" then
        local camera_x, camera_y, camera_width, camera_height = GameGetCameraBounds()
        if camera_x and camera_y and camera_width and camera_height
            and camera_width > 0 and camera_height > 0
        then
            local inset = math.min(48, camera_width * 0.15)
            local side = index % 2 == 1 and -1 or 1
            local bands = { 0, 40, 80 }
            for attempt = 1, #bands * 2 do
                local candidate_side = attempt % 2 == 1 and side or -side
                local band_index = math.floor((attempt + 1) / 2)
                local candidate_inset = inset + bands[band_index]
                local candidate_x = candidate_side < 0
                    and camera_x + candidate_inset
                    or camera_x + camera_width - candidate_inset
                local surface_y = spawn_manager.get_ground_y(candidate_x, camera_y - 48)
                if surface_y and surface_y <= camera_y + camera_height + 64 then
                    return spawn_manager.get_free_position(
                        candidate_x,
                        surface_y - 32,
                        18,
                        18,
                        20
                    )
                end
            end
        end
    end

    local surface_y = spawn_manager.get_ground_y(x, reference_y)
    if surface_y then
        return spawn_manager.get_free_position(x, surface_y - 32, 18, 18, 20)
    end
    return spawn_manager.get_free_position(
        x,
        arena_state.arena_y + offset.y,
        18,
        18,
        20
    )
end
