enemy_manager = enemy_manager or {}

enemy_manager.wave_templates = {
    [1] = { "firebug", "bat" },
    [2] = { "firebug", "bat", "firebug" },
    [3] = { "firebug", "bat", "bigfirebug" },
    [4] = { "bat", "bigfirebug", "bigbat", "firebug" },
    [5] = { "bigfirebug", "bigbat", "firebug", "bat", "bigfirebug" },
}

function enemy_manager.get_wave_enemies(wave_number)
    local templates = enemy_manager.wave_templates[math.min(wave_number, 5)] or enemy_manager.wave_templates[1]
    local enemies = {}
    local total = math.min(2 + wave_number, 10)

    for i = 1, total do
        local enemy_name = templates[(i - 1) % #templates + 1]
        table.insert(enemies, enemy_name)
    end

    return enemies
end

local function load_enemy(enemy_name, wave_number, spawn_index)
    local x, y = spawn_manager.get_spawn_point(spawn_index)
    local enemy = EntityLoad("data/entities/animals/" .. enemy_name .. ".xml", x, y)
    if not enemy or enemy == 0 or not EntityGetIsAlive(enemy) then
        print("Noita Waves: failed to spawn base-game enemy " .. enemy_name .. " at " .. x .. ", " .. y)
        return nil
    end

    EntityAddTag(enemy, "arena_enemy")
    EntityAddTag(enemy, "arena_enemy_wave_" .. tostring(wave_number))

    local damage_model = EntityGetFirstComponentIncludingDisabled(enemy, "DamageModelComponent")
    if damage_model and wave_number > 5 then
        local multiplier = 1 + (wave_number - 5) * 0.12
        local max_hp = ComponentGetValue2(damage_model, "max_hp")
        if max_hp and max_hp > 0 then
            ComponentSetValue2(damage_model, "max_hp", max_hp * multiplier)
            ComponentSetValue2(damage_model, "hp", max_hp * multiplier)
        end
    end

    return enemy
end

function enemy_manager.spawn_missing(enemy_names, wave_number, existing_count)
    local spawned = {}
    local still_missing = {}
    local failed = {}

    for _, entry in ipairs(enemy_names) do
        local spawn_index = existing_count + #spawned + 1
        local enemy = load_enemy(entry.name, wave_number, spawn_index)
        if enemy then
            table.insert(spawned, enemy)
        else
            entry.attempts = entry.attempts + 1
            if entry.attempts < 5 then
                table.insert(still_missing, entry)
            else
                print("Noita Waves: giving up on enemy after 5 attempts: " .. entry.name)
                table.insert(failed, entry)
            end
        end
    end

    return spawned, still_missing, failed
end

function enemy_manager.count_alive_enemies(enemies)
    if not enemies then
        return 0
    end

    local alive = 0
    for _, entity in ipairs(enemies) do
        if entity and EntityGetIsAlive(entity) then
            alive = alive + 1
        end
    end

    return alive
end

function enemy_manager.clear_ambient_in_arena()
    local arena_x, arena_y = shop_manager.get_arena_location()
    if not arena_x or not arena_y then
        return
    end

    local tracked = {}
    for _, entity in ipairs(arena_state.enemies or {}) do
        tracked[entity] = true
    end

    local nearby = {}
    for _, tag in ipairs({ "enemy", "prey" }) do
        for _, entity in ipairs(EntityGetInRadiusWithTag(arena_x, arena_y, 400, tag) or {}) do
            nearby[entity] = true
        end
    end
    for _, entity in ipairs(EntityGetInRadius(arena_x, arena_y, 400) or {}) do
        local filename = EntityGetFilename(entity)
        if filename and string.find(string.lower(filename), "mammoth", 1, true) then
            nearby[entity] = true
        end
    end

    for entity in pairs(nearby) do
        if EntityGetIsAlive(entity)
            and not tracked[entity]
            and not EntityHasTag(entity, "player_unit")
        then
            EntityKill(entity)
        end
    end
end
