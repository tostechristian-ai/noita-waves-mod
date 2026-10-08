arena_hud = arena_hud or {}
arena_hud.gui = arena_hud.gui or GuiCreate()

function arena_hud.draw()
    if not arena_state or not arena_state.started or arena_state.state == "initializing" then
        return
    end

    GuiStartFrame(arena_hud.gui)

    local width, height = GuiGetScreenDimensions(arena_hud.gui)
    local x = math.max(8, width - 154)
    GuiText(arena_hud.gui, x, 8, "WAVE " .. tostring(arena_state.round or 1))
    GuiText(arena_hud.gui, x, 20, "KILLS " .. tostring(arena_state.kills or 0))

    local players = EntityGetWithTag("player_unit")
    if players and players[1] then
        local wallet = EntityGetFirstComponentIncludingDisabled(players[1], "WalletComponent")
        if wallet then
            GuiText(arena_hud.gui, x, 32, "GOLD $" .. tostring(ComponentGetValue2(wallet, "money") or 0))
        end
    end

    if arena_state.state == "battle" then
        GuiText(
            arena_hud.gui,
            x,
            44,
            "ENEMIES " .. tostring(enemy_manager.count_alive_enemies(arena_state.enemies))
        )
        GuiText(arena_hud.gui, x, 56, "! TARGET  ARROWS = OFFSCREEN")
        if arena_state.leash_notice_until and GameGetFrameNum() <= arena_state.leash_notice_until then
            GuiColorSetForNextWidget(arena_hud.gui, 1, 0.8, 0.2, 1)
            GuiText(arena_hud.gui, x, 68, "ENEMY RECOVERED")
        end
        arena_hud.draw_enemy_markers(players and players[1], width, height)
    elseif arena_state.state == "preparing" then
        GuiText(arena_hud.gui, x, 44, "SPAWNING")
    elseif arena_state.state == "initial_countdown" then
        local remaining = math.max(
            0,
            math.ceil((arena_state.first_wave_starts_at - GameGetFrameNum()) / 60)
        )
        GuiText(arena_hud.gui, x, 44, "FIRST ROUND IN " .. tostring(remaining) .. "s")
        GuiColorSetForNextWidget(arena_hud.gui, 1, 0.85, 0.2, 1)
        local button_x = math.max(8, math.floor((width - 180) / 2))
        local button_y = math.max(72, height - 64)
        if GuiButton(arena_hud.gui, 749320, button_x, button_y, "START FIRST WAVE NOW") then
            game_manager.request_first_wave_skip()
        end
    elseif arena_state.state == "shop" then
        local remaining = math.max(
            0,
            math.ceil((arena_state.shop_started_at + shop_manager.shop_duration - GameGetFrameNum()) / 60)
        )
        GuiText(arena_hud.gui, x, 44, "NEXT WAVE IN " .. tostring(remaining) .. "s")
        GuiColorSetForNextWidget(arena_hud.gui, 1, 0.85, 0.2, 1)
        local button_x = math.max(8, math.floor((width - 180) / 2))
        local button_y = math.max(72, height - 64)
        if GuiButton(arena_hud.gui, 749321, button_x, button_y, "START NEXT WAVE NOW") then
            wave_manager.request_shop_skip()
        end
    elseif arena_state.state == "spawn_error" then
        GuiText(arena_hud.gui, x, 44, "WAVE SPAWN FAILED")
    elseif arena_state.state == "game_over" then
        GuiText(arena_hud.gui, x, 44, "GAME OVER")
    end
end

function arena_hud.draw_enemy_markers(player, width, height)
    if not player or width <= 64 or height <= 48 then
        return
    end

    local virtual_width = tonumber(MagicNumbersGetValue("VIRTUAL_RESOLUTION_X")) or width
    local virtual_offset = tonumber(MagicNumbersGetValue("VIRTUAL_RESOLUTION_OFFSET_X")) or 0
    virtual_width = virtual_width + virtual_offset
    if virtual_width <= 0 then
        return
    end

    local camera_x, camera_y = GameGetCameraPos()
    local scale = width / virtual_width
    local margin = 16
    local half_width = width / 2 - margin
    local half_height = height / 2 - margin
    local current_wave_tag = "arena_enemy_wave_" .. tostring(arena_state.round or 1)

    local function draw_target_marker(screen_x, screen_y, text, offscreen)
        screen_x = math.floor(screen_x)
        screen_y = math.floor(screen_y)
        GuiColorSetForNextWidget(arena_hud.gui, 0, 0, 0, 1)
        GuiText(arena_hud.gui, screen_x + 2, screen_y + 2, text, 1.5)
        GuiColorSetForNextWidget(
            arena_hud.gui,
            offscreen and 1 or 0.1,
            offscreen and 0.8 or 1,
            offscreen and 0.05 or 1,
            1
        )
        GuiText(arena_hud.gui, screen_x, screen_y, text, 1.5)
    end

    for _, enemy in ipairs(arena_state.enemies or {}) do
        if enemy and EntityGetIsAlive(enemy) and EntityHasTag(enemy, current_wave_tag) then
            local enemy_x, enemy_y = EntityGetTransform(enemy)
            if enemy_x and enemy_y then
                local screen_x = width / 2 + scale * (enemy_x - camera_x)
                local screen_y = height / 2 + scale * (enemy_y - camera_y)
                local offscreen = screen_x < margin
                    or screen_x > width - margin
                    or screen_y < margin
                    or screen_y > height - margin
                local marker_text = "!"

                if offscreen then
                    local dx = screen_x - width / 2
                    local dy = screen_y - height / 2
                    local x_scale = dx == 0 and math.huge or half_width / math.abs(dx)
                    local y_scale = dy == 0 and math.huge or half_height / math.abs(dy)
                    local edge_scale = math.min(x_scale, y_scale)
                    screen_x = width / 2 + dx * edge_scale
                    screen_y = height / 2 + dy * edge_scale

                    if math.abs(dx) / half_width >= math.abs(dy) / half_height then
                        marker_text = dx < 0 and "<!" or "!>"
                    else
                        marker_text = dy < 0 and "^!" or "v!"
                    end
                end

                screen_x = math.max(margin, math.min(width - margin - 24, screen_x))
                screen_y = math.max(margin, math.min(height - margin - 16, screen_y))
                draw_target_marker(screen_x, screen_y, marker_text, offscreen)
            end
        end
    end
end
