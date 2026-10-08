game_manager = game_manager or {}

game_manager.initialized = false

game_manager.default_state = {
    round = 1,
    state = "ready",
    player_spawned = false,
    forced_start = false,
    tower_floor = 1,
}

function game_manager.init()
    if game_manager.initialized then
        return
    end

    if not arena_state then
        arena_state = {}
    end

    for key, value in pairs(game_manager.default_state) do
        if arena_state[key] == nil then
            arena_state[key] = value
        end
    end

    game_manager.initialized = true
end

function game_manager.begin_new_run(player)
    game_manager.init()
    if arena_state.run_initialized then
        return
    end

    if not player or not EntityGetIsAlive(player) then
        local players = EntityGetWithTag("player_unit")
        player = players and players[1]
    end
    if not player or not EntityGetIsAlive(player) then
        return
    end

    arena_state.run_initialized = true
    arena_state.round = 1
    arena_state.tower_floor = 1
    arena_state.state = "initial_countdown"
    arena_state.player_spawned = true
    arena_state.started = true
    arena_state.starting_wand_given = false
    arena_state.starting_potions_given = false
    arena_state.kills = 0
    arena_state.run_started_at = GameGetFrameNum()
    arena_state.first_wave_starts_at = GameGetFrameNum() + 60 * 60
    arena_state.first_wave_skip_requested = false
    arena_state.game_over_shown = false
    arena_state.last_tower_supply_visit = nil
    game_manager.give_starting_wand(player)
    game_manager.give_starting_potions(player)
    game_manager.set_starting_gold(player, 200)

    shop_manager.clear_legacy_stock()
    if shop_manager.teleport_player_to_shop(player) then
        shop_manager.refresh_tower_supplies("run_start")
    end
    GamePrintImportant("Arena", "First round starts in 1 minute. Starting cash: $200.")
end

function game_manager.request_first_wave_skip()
    if not arena_state
        or arena_state.state ~= "initial_countdown"
        or arena_state.first_wave_skip_requested then
        return false
    end

    arena_state.first_wave_skip_requested = true
    arena_state.first_wave_starts_at = GameGetFrameNum() + 60
    GamePrint("Arena: first wave starts in 1 second.")
    return true
end

function game_manager.set_starting_gold(player, amount)
    local wallet = EntityGetFirstComponentIncludingDisabled(player, "WalletComponent")
    if not wallet then
        wallet = EntityAddComponent2(player, "WalletComponent", { money = amount })
    else
        ComponentSetValue2(wallet, "money", amount)
    end
end

function game_manager.give_starting_wand(player)
    if arena_state.starting_wand_given then
        return true
    end

    if not player or not EntityGetIsAlive(player) then
        return false
    end

    local x, y = EntityGetTransform(player)
    local wand = EntityLoad("data/entities/items/wand_level_01.xml", x, y)
    if not wand then
        print("Noita Arena Singleplayer: failed to load the starting wand")
        return false
    end

    local item_component = EntityGetFirstComponentIncludingDisabled(wand, "ItemComponent")
    if item_component then
        ComponentSetValue2(item_component, "has_been_picked_by_player", true)
    end

    GamePickUpInventoryItem(player, wand, false)
    arena_state.starting_wand_given = true
    return true
end

function game_manager.give_starting_potions(player)
    if arena_state.starting_potions_given then
        return true
    end

    if not player or not EntityGetIsAlive(player) then
        return false
    end

    local x, y = EntityGetTransform(player)
    local full_potion = EntityLoad("data/entities/items/pickup/potion.xml", x, y)
    local empty_potion = EntityLoad("data/entities/items/pickup/potion_empty.xml", x, y)
    if not full_potion or not empty_potion then
        if full_potion then
            EntityKill(full_potion)
        end
        if empty_potion then
            EntityKill(empty_potion)
        end
        print("Noita Waves: failed to load starting potion bottles")
        return false
    end

    for _, potion in ipairs({ full_potion, empty_potion }) do
        local item_component = EntityGetFirstComponentIncludingDisabled(potion, "ItemComponent")
        if item_component then
            ComponentSetValue2(item_component, "has_been_picked_by_player", true)
        end
        GamePickUpInventoryItem(player, potion, false)
    end

    arena_state.starting_potions_given = true
    return true
end

function game_manager.update()
    if not game_manager.initialized then
        game_manager.init()
    end

    if not arena_state.starting_wand_given or not arena_state.starting_potions_given then
        local players = EntityGetWithTag("player_unit")
        local player = players and players[1]
        if player then
            if not arena_state.starting_wand_given then
                game_manager.give_starting_wand(player)
            end
            if not arena_state.starting_potions_given then
                game_manager.give_starting_potions(player)
            end
        end
    end

    if arena_state.state == "initial_countdown" then
        arena_manager.update()
        if arena_state.state == "game_over" then
            return
        end
        if GameGetFrameNum() >= arena_state.first_wave_starts_at then
            arena_manager.begin()
        end
        return
    end

    if arena_state and arena_state.state ~= "game_over" then
        arena_manager.update()
    end
end
