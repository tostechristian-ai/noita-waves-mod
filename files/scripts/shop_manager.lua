shop_manager = shop_manager or {}

shop_manager.shop_duration = 3600
shop_manager.supply_tag = "arena_singleplayer_tower_supply"
shop_manager.arena_offset_x = -800
shop_manager.arena_offset_y = 100
shop_manager.tower_floors = {
    { x = -677, y = 1336 },
    { x = -677, y = 2872 },
    { x = -677, y = 4920 },
    { x = -677, y = 6456 },
    { x = -677, y = 8504 },
    { x = -677, y = 10552 },
}

function shop_manager.set_arena_origin(player)
    local x, y = EntityGetTransform(player)
    local desired_x = x + shop_manager.arena_offset_x
    local reference_y = y - 512 + shop_manager.arena_offset_y
    local ground_y = spawn_manager.get_ground_y(desired_x, reference_y)
    arena_state.arena_x = desired_x
    arena_state.arena_y = ground_y and ground_y - 56 or y + shop_manager.arena_offset_y
    arena_state.arena_ground_reference_y = reference_y
end

function shop_manager.get_arena_location()
    return arena_state.arena_x, arena_state.arena_y
end

function shop_manager.get_arena_player_spawn()
    local arena_x, arena_y = shop_manager.get_arena_location()
    if not arena_x or not arena_y then
        return nil, nil
    end

    local reference_y = arena_state.arena_ground_reference_y or (arena_y - 512)
    return spawn_manager.get_grounded_player_position(arena_x, reference_y, 240, 24)
end

function shop_manager.get_shop_location(floor_index)
    local active_floor = floor_index or (arena_state and arena_state.tower_floor) or 1
    floor_index = math.max(1, math.min(active_floor, #shop_manager.tower_floors))
    local floor = shop_manager.tower_floors[floor_index]
    return floor.x, floor.y
end

function shop_manager.advance_tower_floor(completed_round)
    if not arena_state or completed_round % 5 ~= 0 then
        return false
    end

    local current_floor = arena_state.tower_floor or 1
    if current_floor >= #shop_manager.tower_floors then
        return false
    end

    arena_state.tower_floor = current_floor + 1
    return true
end

local function mark_tower_supply(entity, label)
    if entity and entity ~= 0 and EntityGetIsAlive(entity) then
        EntityAddTag(entity, shop_manager.supply_tag)
        return true
    end

    print("Noita Waves: failed to spawn tower " .. label)
    return false
end

function shop_manager.refresh_tower_supplies(visit_id, shop_x, shop_y)
    if not arena_state or visit_id == nil then
        return false
    end

    if arena_state.last_tower_supply_visit == visit_id then
        return false
    end

    if shop_x == nil or shop_y == nil then
        shop_x, shop_y = shop_manager.get_shop_location()
    end
    for _, entity in ipairs(EntityGetInRadiusWithTag(shop_x, shop_y, 300, shop_manager.supply_tag) or {}) do
        if EntityGetIsAlive(entity) and EntityGetParent(entity) == 0 then
            EntityKill(entity)
        end
    end

    local ground_y = spawn_manager.get_ground_y(shop_x, shop_y)
    local supply_y = ground_y and ground_y - 16 or shop_y + 20
    local perk_x, perk_y = spawn_manager.get_free_position(shop_x - 96, supply_y, 28, 48, 8)
    local heart_x, heart_y = spawn_manager.get_free_position(shop_x - 48, supply_y, 28, 48, 8)
    local refresh_x, refresh_y = spawn_manager.get_free_position(shop_x + 48, supply_y, 28, 48, 8)

    dofile_once("data/scripts/perks/perk.lua")
    dofile_once("data/scripts/perks/perk_list.lua")

    local spawned_all = true
    if perk_list and #perk_list > 0 and type(perk_spawn) == "function" then
        local perk = perk_list[math.random(1, #perk_list)]
        spawned_all = mark_tower_supply(perk_spawn(perk_x, perk_y, perk.id), "perk") and spawned_all
    else
        print("Noita Waves: perk scripts did not provide a perk list")
        spawned_all = false
    end

    spawned_all = mark_tower_supply(
        EntityLoad("data/entities/items/pickup/heart_fullhp_temple.xml", heart_x, heart_y),
        "HP pickup"
    ) and spawned_all
    spawned_all = mark_tower_supply(
        EntityLoad("data/entities/items/pickup/spell_refresh.xml", refresh_x, refresh_y),
        "spell refresh"
    ) and spawned_all

    if spawned_all then
        arena_state.last_tower_supply_visit = visit_id
    end
    return spawned_all
end

function shop_manager.teleport_player(player, x, y)
    if not player or not EntityGetIsAlive(player) then
        return false
    end

    EntityApplyTransform(player, x, y)
    GameSetCameraPos(x, y)

    local damage_model = EntityGetFirstComponentIncludingDisabled(player, "DamageModelComponent")
    if damage_model then
        ComponentSetValue2(damage_model, "invincible_time", 60)
    end

    return true
end

function shop_manager.award_wave_gold(player, round)
    local amount = 200 + (round - 1) * 100
    local wallet = EntityGetFirstComponentIncludingDisabled(player, "WalletComponent")
    if not wallet then
        wallet = EntityAddComponent2(player, "WalletComponent", { money = 0 })
    end

    local current_gold = ComponentGetValue2(wallet, "money") or 0
    ComponentSetValue2(wallet, "money", current_gold + amount)
    return amount
end

function shop_manager.clear_legacy_stock()
    local shop_x, shop_y = shop_manager.get_shop_location()
    for _, entity in ipairs(EntityGetInRadiusWithTag(shop_x, shop_y, 400, "arena_singleplayer_shop_stock") or {}) do
        if EntityGetIsAlive(entity) and EntityGetParent(entity) == 0 then
            EntityKill(entity)
        end
    end
end
