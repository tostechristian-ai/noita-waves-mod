import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "files" / "scripts"


def read_script(name):
    return (SCRIPTS / name).read_text(encoding="utf-8")


class SpawnSafetyChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.spawn = read_script("spawn_manager.lua")
        cls.shop = read_script("shop_manager.lua")
        cls.wave = read_script("wave_manager.lua")
        cls.enemy = read_script("enemy_manager.lua")

    def test_arena_player_search_falls_back_to_the_arena_coordinate(self):
        self.assertIn("function spawn_manager.get_grounded_player_position", self.spawn)
        self.assertIn("return arena_x, arena_y", self.shop)
        self.assertIn("shop_manager.get_arena_location()", self.wave)
        self.assertNotIn("spawn_manager.is_safe_player_position", self.shop)

    def test_enemy_placement_uses_selected_arena_and_keeps_raw_fallback(self):
        self.assertIn("{ x = -300, y = -24 }", self.spawn)
        self.assertIn("GameGetCameraBounds()", self.spawn)
        self.assertIn("local candidate_x = candidate_side < 0", self.spawn)
        self.assertIn("return spawn_manager.get_free_position(", self.spawn)
        self.assertIn("arena_state.arena_y + offset.y", self.spawn)
        self.assertIn("return x, y", self.spawn)
        self.assertNotIn("is_safe_mob_position", self.enemy + self.spawn)
        self.assertIn("shop_manager.select_arena_for_wave(wave_number)", self.wave)
        self.assertIn("arena_state.arena_x + offset.x", self.spawn)

    def test_arena_player_search_avoids_tree_trunks_and_resolves_wave_spawn_center(self):
        self.assertIn("local function has_clear_standing_space", self.spawn)
        self.assertIn("reference_y + 5120", self.spawn)
        self.assertIn("surface_y - 120", self.spawn)
        self.assertIn("surface_y - 8", self.spawn)
        self.assertIn("arena_y - 2048,\n            1200,\n            48", self.shop)
        self.assertIn("arena_y + 56,\n            2048", self.shop)
        self.assertIn("math.abs(surface_y - expected_surface_y)", self.spawn)
        self.assertIn("arena_state.arena_spawn_x = player_x", self.shop)
        self.assertIn("arena_state.arena_spawn_y = player_y", self.shop)
        self.assertIn("arena_state.arena_x = spawn_x", self.shop)
        self.assertIn("arena_state.arena_y = spawn_y", self.shop)
        self.assertIn("arena_state.arena_ground_reference_y = spawn_y - 256", self.shop)
        self.assertIn("established non-blocking coordinate fallback", self.shop)

    def test_failed_location_checks_do_not_block_wave_or_tower_teleports(self):
        self.assertIn("shop_manager.teleport_player(players[1], arena_x, arena_y)", self.wave)
        self.assertNotIn('arena_state.state = "spawn_error"', self.wave[:self.wave.index("function wave_manager.update")])
        self.assertIn("local x, y = shop_manager.get_shop_location(floor_index)", self.shop)
        self.assertNotIn("is_safe_player_position", self.shop)

    def test_ambient_cleanup_is_local_and_preserves_wave_enemies_and_special_entities(self):
        cleanup = self.enemy[
            self.enemy.index("function enemy_manager.cleanup_ambient_near_arena()"):
            self.enemy.index("local function squared_distance")
        ]
        self.assertIn("EntityGetInRadius(arena_x, arena_y, 700)", cleanup)
        self.assertIn('EntityHasTag(entity, "enemy")', cleanup)
        self.assertIn('has_component(entity, "AnimalAIComponent")', cleanup)
        self.assertIn('has_component(entity, "DamageModelComponent")', cleanup)
        self.assertIn('EntityGetParent(entity) == 0', cleanup)
        self.assertNotIn("EntityGetWithTag", cleanup)
        self.assertNotIn("EntityGetAll", cleanup)
        for protected in ('"arena_enemy"', '"shopkeeper"', '"npc"', '"boss"', '"InteractableComponent"'):
            self.assertIn(protected, self.enemy)
        self.assertIn('arena_state.state == "preparing" or arena_state.state == "battle"', self.wave)
        self.assertIn("arena_state.ambient_cleanup_next = frame + 120", self.enemy)

    def test_arena_rotation_is_shuffled_and_mobs_use_selected_arena(self):
        self.assertIn("{ -14000, -9000, 4000, 7000, 12000 }", self.shop)
        self.assertIn("shuffled_arena_indices", self.shop)
        self.assertIn("arena_state.arena_index = arena_index", self.shop)
        self.assertIn("arena_state.arena_x = location.x", self.shop)
        self.assertIn("arena_state.arena_y = location.y", self.shop)
        self.assertIn("arena_state.arena_x + offset.x", self.spawn)
        self.assertIn("arena_state.arena_index or 0", self.enemy)
        self.assertIn("fixed overworld X candidate", self.shop)
        self.assertIn("selected arena terrain completed", self.wave)
        self.assertIn("arena_state.arena_landing_resolved = false", self.wave)
        self.assertIn("shop_manager.finalize_arena_player_spawn(player)", self.wave)

    def test_arena_rotation_includes_five_fixed_candidates(self):
        anchors = re.search(r"shop_manager\.arena_anchor_x\s*=\s*\{([^}]*)\}", self.shop)
        self.assertIsNotNone(anchors)
        values = [int(value.strip()) for value in anchors.group(1).split(",")]
        self.assertEqual(values, [-14000, -9000, 4000, 7000, 12000])
        self.assertIn("shuffled_arena_indices(#locations)", self.shop)

    def test_leash_waits_then_recovers_only_tracked_wave_mobs_with_separation_and_cooldown(self):
        leash = self.enemy[
            self.enemy.index("function enemy_manager.update_leash"):
            self.enemy.index("function enemy_manager.spawn_missing")
        ]
        self.assertIn("function enemy_manager.update_leash(enemies, player)", leash)
        self.assertIn('EntityHasTag(entity, "arena_enemy")', leash)
        self.assertIn("frame - leash.out_since >= 180", leash)
        self.assertIn("leash.next_recovery = frame + 600", leash)
        self.assertIn("128 * 128", self.enemy)
        self.assertIn("EntityApplyTransform(entity, target_x, target_y)", leash)
        self.assertNotIn("EntityKill", leash)
        self.assertIn("arena_state.enemy_leash_state = {}", self.wave)
        self.assertIn("ENEMY RECOVERED", read_script("hud.lua"))
        self.assertIn("wave_manager.update()", self.wave)

    def test_tower_cycle_and_supplies_are_preserved(self):
        self.assertIn("completed_round % 5 ~= 0", self.shop)
        self.assertIn("arena_state.tower_floor = current_floor + 1", self.shop)
        self.assertIn('shop_manager.refresh_tower_supplies("run_start")', read_script("game_manager.lua"))
        self.assertIn("shop_manager.refresh_tower_supplies(\"round_\"", self.wave)

    def test_shop_intermission_remains_one_minute(self):
        self.assertRegex(self.shop, r"shop_manager\.shop_duration = 3600\b")


class WaveBalanceChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.enemy = read_script("enemy_manager.lua")

    def test_waves_one_through_ten_have_explicit_rosters(self):
        order_match = re.search(
            r"enemy_manager\.enemy_type_order\s*=\s*\{([^}]*)\}",
            self.enemy,
            re.DOTALL,
        )
        self.assertIsNotNone(order_match)
        enemy_order = re.findall(r'"(\w+)"', order_match.group(1))

        composition_block = re.search(
            r"enemy_manager\.wave_compositions\s*=\s*\{(.*?)\n\}",
            self.enemy,
            re.DOTALL,
        )
        self.assertIsNotNone(composition_block)

        compositions = {}
        for wave, values in re.findall(
            r"\[(\d+)\]\s*=\s*\{([^}]*)\}",
            composition_block.group(1),
        ):
            compositions[int(wave)] = {
                enemy: int(count)
                for enemy, count in re.findall(r"(\w+)\s*=\s*(\d+)", values)
            }

        expected_species = {
            1: {"firebug", "bat"},
            2: {"firebug", "bat", "rat", "ant"},
            3: {"firebug", "bat", "bigfirebug", "rat", "zombie"},
            4: {"firebug", "bat", "bigfirebug", "bigbat", "rat", "acidshooter"},
            5: {"firebug", "bat", "bigfirebug", "bigbat", "ant", "zombie", "acidshooter"},
            6: {"firebug", "bat", "bigfirebug", "bigbat", "rat", "zombie", "acidshooter", "shotgunner"},
            7: {"firebug", "bat", "bigfirebug", "bigbat", "rat", "acidshooter", "shotgunner", "sniper"},
            8: {"firebug", "bat", "bigfirebug", "bigbat", "rat", "acidshooter", "shotgunner", "sniper", "shaman"},
            9: {"firebug", "bat", "bigfirebug", "bigbat", "zombie", "acidshooter", "shotgunner", "sniper", "shaman"},
            10: {"firebug", "bat", "bigfirebug", "bigbat", "rat", "acidshooter", "shotgunner", "sniper", "shaman", "wand_ghost"},
        }
        self.assertEqual(set(compositions), set(expected_species))
        self.assertEqual(set(enemy_order), set().union(*expected_species.values()) | {"wizard_neutral"})
        for wave, species in expected_species.items():
            with self.subTest(wave=wave):
                composition = compositions[wave]
                self.assertEqual(set(composition), set(enemy_order))
                self.assertEqual(
                    {enemy for enemy, count in composition.items() if count > 0},
                    species,
                )
                self.assertLessEqual(sum(composition.values()), 10)

        self.assertEqual(compositions[1]["firebug"], 2)
        self.assertEqual(compositions[1]["bat"], 1)
        self.assertEqual(compositions[10]["wand_ghost"], 1)
        self.assertIn('"wand_ghost"', self.enemy)
        self.assertIn('"wizard_neutral"', self.enemy)
        self.assertIn('EntityLoad("data/entities/animals/" .. enemy_name .. ".xml", x, y)', self.enemy)

    def test_wave_entities_are_tagged_immediately_after_load(self):
        load_start = self.enemy.index('local enemy = EntityLoad("data/entities/animals/"')
        tag_start = self.enemy.index('EntityAddTag(enemy, "arena_enemy")', load_start)
        health_scaling = self.enemy.index("scale_enemy_health(enemy, wave_number)", tag_start)
        self.assertLess(load_start, tag_start)
        self.assertLess(tag_start, health_scaling)

    def test_endless_mix_is_bounded_and_upgrades_at_most_once_per_block(self):
        upgrades = re.findall(
            r'\{\s*from\s*=\s*"(\w+)",\s*to\s*=\s*"(\w+)"\s*\}',
            self.enemy,
        )
        self.assertEqual(
            upgrades,
            [
                ("firebug", "bigfirebug"),
                ("bat", "bigbat"),
                ("rat", "zombie"),
                ("shaman", "wizard_neutral"),
            ],
        )
        self.assertIn(
            "math.min(4, math.floor((wave_number - 11) / 5) + 1)",
            self.enemy,
        )

        order_match = re.search(
            r"enemy_manager\.enemy_type_order\s*=\s*\{([^}]*)\}",
            self.enemy,
            re.DOTALL,
        )
        enemy_order = re.findall(r'"(\w+)"', order_match.group(1))
        composition_block = re.search(
            r"enemy_manager\.wave_compositions\s*=\s*\{(.*?)\n\}",
            self.enemy,
            re.DOTALL,
        )
        final_values = re.search(
            r"\[10\]\s*=\s*\{([^}]*)\}",
            composition_block.group(1),
        )
        current = {
            enemy: int(count)
            for enemy, count in re.findall(r"(\w+)\s*=\s*(\d+)", final_values.group(1))
        }

        for wave in range(11, 61):
            completed_blocks = min(4, (wave - 11) // 5 + 1)
            current_wave = dict(current)
            for source, target in upgrades[:completed_blocks]:
                current_wave[source] -= 1
                current_wave[target] += 1

            with self.subTest(wave=wave):
                self.assertEqual(set(current_wave), set(enemy_order))
                self.assertEqual(sum(current_wave.values()), 10)
                self.assertLessEqual(current_wave["bigfirebug"], 2)
                self.assertLessEqual(current_wave["bigbat"], 2)
                self.assertLessEqual(
                    sum(current_wave[name] for name in ("bigfirebug", "bigbat")),
                    10,
                )
                self.assertEqual(current_wave["wand_ghost"], 1)
                self.assertIn(current_wave["wizard_neutral"], (0, 1))

    def test_health_scaling_is_smooth_capped_and_preserves_native_health_fraction(self):
        self.assertIn("1 + 0.08 * math.sqrt(wave_number - 5)", self.enemy)
        self.assertIn("math.min(1.5,", self.enemy)
        self.assertIn(
            'EntityGetComponentIncludingDisabled(enemy, "DamageModelComponent")',
            self.enemy,
        )
        self.assertIn('ComponentGetValue2(damage_model, "max_hp_cap")', self.enemy)
        self.assertIn("local health_fraction = hp / max_hp", self.enemy)
        self.assertIn(
            'ComponentSetValue2(damage_model, "hp", new_max_hp * health_fraction)',
            self.enemy,
        )
        self.assertNotIn('ComponentSetValue2(damage_model, "hp", max_hp * multiplier)', self.enemy)


if __name__ == "__main__":
    unittest.main()
