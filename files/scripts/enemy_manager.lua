enemy_manager = enemy_manager or {}

enemy_manager.enemy_type_order = {
    "firebug",
    "bat",
    "bigfirebug",
    "bigbat",
    "rat",
    "ant",
    "zombie",
    "acidshooter",
    "shotgunner",
    "sniper",
    "shaman",
    "wand_ghost",
    "wizard_neutral",
}

enemy_manager.wave_compositions = {
    [1] = { firebug = 2, bat = 1, bigfirebug = 0, bigbat = 0, rat = 0, ant = 0, zombie = 0, acidshooter = 0, shotgunner = 0, sniper = 0, shaman = 0, wand_ghost = 0, wizard_neutral = 0 },
    [2] = { firebug = 2, bat = 1, bigfirebug = 0, bigbat = 0, rat = 1, ant = 1, zombie = 0, acidshooter = 0, shotgunner = 0, sniper = 0, shaman = 0, wand_ghost = 0, wizard_neutral = 0 },
    [3] = { firebug = 2, bat = 1, bigfirebug = 1, bigbat = 0, rat = 1, ant = 0, zombie = 1, acidshooter = 0, shotgunner = 0, sniper = 0, shaman = 0, wand_ghost = 0, wizard_neutral = 0 },
    [4] = { firebug = 2, bat = 1, bigfirebug = 1, bigbat = 1, rat = 1, ant = 0, zombie = 0, acidshooter = 1, shotgunner = 0, sniper = 0, shaman = 0, wand_ghost = 0, wizard_neutral = 0 },
    [5] = { firebug = 1, bat = 2, bigfirebug = 1, bigbat = 1, rat = 0, ant = 1, zombie = 1, acidshooter = 1, shotgunner = 0, sniper = 0, shaman = 0, wand_ghost = 0, wizard_neutral = 0 },
    [6] = { firebug = 1, bat = 2, bigfirebug = 1, bigbat = 1, rat = 1, ant = 0, zombie = 1, acidshooter = 1, shotgunner = 1, sniper = 0, shaman = 0, wand_ghost = 0, wizard_neutral = 0 },
    [7] = { firebug = 1, bat = 1, bigfirebug = 2, bigbat = 1, rat = 1, ant = 0, zombie = 0, acidshooter = 1, shotgunner = 1, sniper = 1, shaman = 0, wand_ghost = 0, wizard_neutral = 0 },
    [8] = { firebug = 2, bat = 1, bigfirebug = 1, bigbat = 1, rat = 1, ant = 0, zombie = 0, acidshooter = 1, shotgunner = 1, sniper = 1, shaman = 1, wand_ghost = 0, wizard_neutral = 0 },
    [9] = { firebug = 1, bat = 1, bigfirebug = 2, bigbat = 1, rat = 0, ant = 0, zombie = 1, acidshooter = 1, shotgunner = 1, sniper = 1, shaman = 1, wand_ghost = 0, wizard_neutral = 0 },
    [10] = { firebug = 1, bat = 1, bigfirebug = 1, bigbat = 1, rat = 1, ant = 0, zombie = 0, acidshooter = 1, shotgunner = 1, sniper = 1, shaman = 1, wand_ghost = 1, wizard_neutral = 0 },
}

local endless_upgrades = {
    { from = "firebug", to = "bigfirebug" },
    { from = "bat", to = "bigbat" },
    { from = "rat", to = "zombie" },
    { from = "shaman", to = "wizard_neutral" },
}

local function get_wave_composition(wave_number)
    if wave_number <= 10 then
        return enemy_manager.wave_compositions[math.max(1, wave_number)]
    end

    local composition = {}
    for _, enemy_name in ipairs(enemy_manager.enemy_type_order) do
        composition[enemy_name] = enemy_manager.wave_compositions[10][enemy_name]
    end

    local completed_blocks = math.min(4, math.floor((wave_number - 11) / 5) + 1)
    for index = 1, completed_blocks do
        local upgrade = endless_upgrades[index]
        composition[upgrade.from] = composition[upgrade.from] - 1
        composition[upgrade.to] = composition[upgrade.to] + 1
    end

    return composition
end

function enemy_manager.get_wave_enemies(wave_number)
    if type(wave_number) ~= "number" or wave_number ~= wave_number then
        wave_number = 1
    end
    wave_number = math.floor(wave_number)

    local composition = get_wave_composition(wave_number)
    local enemies = {}

    for _, enemy_name in ipairs(enemy_manager.enemy_type_order) do
        for _ = 1, composition[enemy_name] do
            table.insert(enemies, enemy_name)
        end
    end

    return enemies
end

function enemy_manager.get_health_multiplier(wave_number)
    if type(wave_number) ~= "number" or wave_number ~= wave_number or wave_number <= 5 then
        return 1
    end

    return math.min(1.5, 1 + 0.08 * math.sqrt(wave_number - 5))
end

local function is_positive_finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
        and value > 0
end

local function scale_enemy_health(enemy, wave_number)
    local multiplier = enemy_manager.get_health_multiplier(wave_number)
    if multiplier <= 1 then
        return
    end

    local components = EntityGetComponentIncludingDisabled(enemy, "DamageModelComponent")
    if not components then
        return
    end

    for _, damage_model in ipairs(components) do
        local max_hp = ComponentGetValue2(damage_model, "max_hp")
        local hp = ComponentGetValue2(damage_model, "hp")
        if is_positive_finite_number(max_hp)
            and is_positive_finite_number(hp)
            and hp <= max_hp
        then
            local new_max_hp = max_hp * multiplier
            local max_hp_cap = ComponentGetValue2(damage_model, "max_hp_cap")
            if is_positive_finite_number(max_hp_cap) then
                new_max_hp = math.min(new_max_hp, max_hp_cap)
            end

            if is_positive_finite_number(new_max_hp) and new_max_hp > max_hp then
                local health_fraction = hp / max_hp
                ComponentSetValue2(damage_model, "max_hp", new_max_hp)
                ComponentSetValue2(damage_model, "hp", new_max_hp * health_fraction)
            end
        end
    end
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
    arena_state.enemy_leash_state = arena_state.enemy_leash_state or {}

    scale_enemy_health(enemy, wave_number)
    print(
        "Noita Waves: spawned " .. enemy_name .. " for arena "
            .. tostring(arena_state.arena_index or 0) .. " at " .. tostring(x) .. ", " .. tostring(y)
    )

    return enemy
end

local function has_component(entity, component_name)
    return type(EntityGetFirstComponentIncludingDisabled) == "function"
        and EntityGetFirstComponentIncludingDisabled(entity, component_name) ~= nil
end

local protected_ambient_tags = {
    "player_unit",
    "arena_enemy",
    "arena_protected",
    "npc",
    "friendly",
    "shopkeeper",
    "shopkeeper_wand",
    "wandering_shop",
    "wandering_shopkeeper",
    "holy_mountain",
    "temple",
    "boss",
    "miniboss",
    "final_boss",
    "boss_centipede",
    "boss_dragon",
    "boss_alchemist",
    "boss_meat",
}

local function is_protected_ambient_entity(entity)
    for _, tag in ipairs(protected_ambient_tags) do
        if EntityHasTag(entity, tag) then
            return true
        end
    end

    if has_component(entity, "InteractableComponent") then
        return true
    end

    local animal_ai = EntityGetFirstComponentIncludingDisabled(entity, "AnimalAIComponent")
    if animal_ai and type(ComponentGetValue2) == "function"
        and ComponentGetValue2(animal_ai, "gui_special_final_boss")
    then
        return true
    end
    return false
end

function enemy_manager.cleanup_ambient_near_arena()
    local frame = GameGetFrameNum()
    if frame < (arena_state.ambient_cleanup_next or 0) then
        return
    end
    arena_state.ambient_cleanup_next = frame + 120

    if type(EntityGetInRadius) ~= "function" then
        if not arena_state.ambient_cleanup_api_warning_shown then
            arena_state.ambient_cleanup_api_warning_shown = true
            print("Noita Waves: local ambient cleanup unavailable; EntityGetInRadius is missing")
        end
        return
    end

    local arena_x, arena_y = arena_state.arena_x, arena_state.arena_y
    if not arena_x or not arena_y then
        return
    end

    local removed = 0
    for _, entity in ipairs(EntityGetInRadius(arena_x, arena_y, 700) or {}) do
        if entity and EntityGetIsAlive(entity)
            and EntityGetParent(entity) == 0
            and EntityHasTag(entity, "enemy")
            and has_component(entity, "AnimalAIComponent")
            and has_component(entity, "DamageModelComponent")
            and not is_protected_ambient_entity(entity)
        then
            EntityKill(entity)
            removed = removed + 1
        end
    end

    if removed > 0 then
        print(
            "Noita Waves: removed " .. tostring(removed)
                .. " ordinary ambient enemy entities within 700 units of arena "
                .. tostring(arena_state.arena_index or 0) .. " at "
                .. tostring(arena_x) .. ", " .. tostring(arena_y)
        )
    end
end

local function squared_distance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return dx * dx + dy * dy
end

local function is_separated_from_player(x, y, player_x, player_y)
    return squared_distance(x, y, player_x, player_y) >= 128 * 128
end

local function get_leash_position(player_x, player_y, entity, spawn_index)
    local entity_id = tonumber(entity) or spawn_index
    local first_side = entity_id % 2 == 0 and 1 or -1
    for _, side in ipairs({ first_side, -first_side }) do
        local desired_x = player_x + side * 220
        local x, y = spawn_manager.get_grounded_player_position(
            desired_x,
            player_y - 512,
            120,
            24
        )
        if x and y and is_separated_from_player(x, y, player_x, player_y) then
            local free_x, free_y = spawn_manager.get_free_position(x, y, 18, 18, 20)
            if is_separated_from_player(free_x, free_y, player_x, player_y) then
                return free_x, free_y
            end
        end
    end

    local arena_x, arena_y = spawn_manager.get_spawn_point(spawn_index)
    if arena_x and arena_y and is_separated_from_player(arena_x, arena_y, player_x, player_y) then
        return arena_x, arena_y
    end

    local fallback_x = player_x + first_side * 240
    local fallback_y = player_y
    if is_separated_from_player(fallback_x, fallback_y, player_x, player_y) then
        local free_x, free_y = spawn_manager.get_free_position(fallback_x, fallback_y, 18, 18, 20)
        if is_separated_from_player(free_x, free_y, player_x, player_y) then
            return free_x, free_y
        end
    end
    return nil, nil
end

function enemy_manager.update_leash(enemies, player)
    if not enemies or not player or not EntityGetIsAlive(player) then
        return
    end

    local frame = GameGetFrameNum()
    if frame < (arena_state.leash_next_check or 0) then
        return
    end
    arena_state.leash_next_check = frame + 30
    arena_state.enemy_leash_state = arena_state.enemy_leash_state or {}
    local player_x, player_y = EntityGetTransform(player)
    if not player_x or not player_y then
        return
    end

    for index, entity in ipairs(enemies) do
        if entity and EntityGetIsAlive(entity) and EntityHasTag(entity, "arena_enemy") then
            local x, y = EntityGetTransform(entity)
            if x and y then
                local from_player = squared_distance(x, y, player_x, player_y)
                local from_arena = squared_distance(
                    x,
                    y,
                    arena_state.arena_x or player_x,
                    arena_state.arena_y or player_y
                )
                local out_of_range = from_player > 1000 * 1000 or from_arena > 1200 * 1200
                local leash = arena_state.enemy_leash_state[entity] or {}
                arena_state.enemy_leash_state[entity] = leash
                if out_of_range then
                    leash.out_since = leash.out_since or frame
                    if frame - leash.out_since >= 180 and frame >= (leash.next_recovery or 0) then
                        local target_x, target_y = get_leash_position(player_x, player_y, entity, index)
                        leash.next_recovery = frame + 600
                        leash.out_since = nil
                        if target_x and target_y then
                            EntityApplyTransform(entity, target_x, target_y)
                            arena_state.leash_notice_until = frame + 180
                            GamePrint("Arena: a wave enemy wandered too far and was brought back.")
                            print(
                                "Noita Waves: recovered wave enemy " .. tostring(entity)
                                    .. " from " .. tostring(x) .. ", " .. tostring(y)
                                    .. " to " .. tostring(target_x) .. ", " .. tostring(target_y)
                            )
                        else
                            print(
                                "Noita Waves: no separated leash fallback for enemy "
                                    .. tostring(entity) .. "; retaining its current position"
                            )
                        end
                    end
                else
                    leash.out_since = nil
                end
            end
        end
    end
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
