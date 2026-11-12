# Test Infrastructure — Slag & Starlight

**Project:** Slag & Starlight (Godot 4.x retro 2.5D sci-fi RPG on Khoros-IV)  
**Sources of Truth:** `/home/antigravity/.agents/teamwork/ORIGINAL_REQUEST.md`, `/home/antigravity/PROJECT.md`

---

## 1. Test Philosophy

1. **Opaque-Box, Requirement-Driven:** Every test case derives its inputs and expected outputs directly from `ORIGINAL_REQUEST.md` (mechanics, formulas, room-by-room dungeon design) and `PROJECT.md` (Interface Contracts, Feature Inventory, Code Layout). Tests verify observable behavior, state transitions, and signal emissions rather than internal private implementation details.
2. **Progressive Testability (M1–M5 + Final):** Tests are partitioned by milestone and tier so that both the Python static/structural validator (`tests/validate_project.py --milestone M1..M5|ALL`) and the Godot headless test runner (`tests/run_tests.gd`) can validate each milestone as it lands.
3. **Self-Contained & Deterministic:** Every test case initializes its own fixtures/state, resets global singletons (`EventBus`, `GameState`, `PlayerStats`, `QuestManager`) before and after execution, and avoids order-dependent side effects.
4. **Dual-Layer Verification:**
   - **Layer A (Python 3.11 Static/Structural/Logic Validator):** Runs immediately in environments without Godot 4.x. Validates `project.godot`, GDScript syntax & interface contracts, `.tscn`/`.tres` resource integrity, `.gdshader` headers/syntax, and milestone file completeness.
   - **Layer B (Godot 4.x `--headless` Runner):** Executes live unit and E2E tests inside the Godot `SceneTree` (`godot --headless --path . --script res://tests/run_tests.gd --quit`).

---

## 2. Complete 22-Feature Inventory Matrix

Every feature from `PROJECT.md` § Feature Inventory is mapped to Tiers 1–4 and static validation:

| # | Feature (from `PROJECT.md`) | Milestone | Tier 1: Feature Coverage | Tier 2: Boundary & Corner Cases | Tier 3: Cross-Feature Combinations | Tier 4: Real-World Scenarios |
|---|-----------------------------|-----------|--------------------------|---------------------------------|------------------------------------|------------------------------|
| 1 | **2.5D SubViewport Setup** | M1 | `Main.tscn` has `SubViewportContainer` -> `SubViewport` `320x200`, `viewport` stretch, `Nearest` filter, `gl_compatibility` | Resize/aspect edge cases; invalid/zero viewport size guard | SubViewport + `PostProcessLayer` + `HUDLayer` layering | Full dungeon walkthrough renders within `320x200` pipeline |
| 2 | **Retro Post-Process Shader** | M1 | `retro_quantize_fog.gdshader` exists, `shader_type canvas_item`, 256-color quantization + fog uniforms | Extreme fog distance (`0.0`, negative, `>1000.0`) | Shader active over 3D world without obscuring `HUDLayer` | Sub-Level 04 dark corridors -> Rust-Spire surface fog |
| 3 | **Low-Poly Modular Geometry** | M1 | Modular prefabs in `scenes/levels/modules/`, `64x64`/`128x128` textures, `TEXTURE_FILTER_NEAREST` | Missing/unassigned material fallback | Modular rooms + `InteractRay`/`WeaponRay` collision layers | All 7 rooms of `SubLevel04.tscn` + `RustSpireOutpost.tscn` |
| 4 | **Billboarded 8-Dir Sprites** | M1 | `Billboard8Dir.gd` sets `BILLBOARD_FIXED_Y`, updates `frame_coords.y` (0–7) via dot/cross | Zero-length camera/entity vector, exact 45°/90°/180° angles | 8-dir sprite updates while enemy chases/attacks player | Kael, Slag-Ticks, Drones, Unit 734-B facing in Rooms 2–7 |
| 5 | **Core Autoloads** | M1 | `EventBus` (10 signals), `GameState` (`flags`, `set_flag`, `get_flag`, `modify_reputation`), `PlayerStats` | Missing flag default return, negative/zero reputation delta | `EventBus` connects combat/minigames/quests/HUD | State persists across Sub-Level 04 -> Rust-Spire transition |
| 6 | **Player Controller & Rays** | M1 | `CharacterBody3D`, `Camera3D`, `InteractRay` (`2.5m`), `WeaponRay` (`50m`/`2.2m`) | Out-of-range (`2.6m` interact, `51m` blaster, `2.3m` melee) | Movement velocity drives `WeaponView2D` sine-wave bob | Traversing catwalks, vents, and lift in Sub-Level 04 |
| 7 | **Procedural Retro Assets** | M1 | `tools/generate_assets.py` generates textures, 8-dir sheets, weapons, UI/paper-doll PNGs | Palette bounds (<=256 colors), exact `64x64`/`128x128` dims | Generated PNGs referenced by `.tres`/`.tscn` `ext_resource` | Visual assets loaded across all 7 rooms & UI screens |
| 8 | **`ItemData` Resource & Catalog** | M2 | `ItemData.gd` properties (`id`, `name`, `icon`, `paper_doll_sprite`, `slot_type`, `weight`, `armor_rating`, `damage_range`, `durability`) | `durability == 0`, `weight == 0.0`, negative `armor_rating` clamp | `ItemData` equipped -> `PlayerStats.total_armor` & paper-doll | Looting Blaster, Spanner, Pressure Suit, Gauntlets, Barrel |
| 9 | **7-Slot Paper-Doll & Grid UI** | M2 | 7 equipment slots + Grid Backpack, world pause/slowdown, Z-index order (`Under-suit->Greaves->Torso->Pauldrons->Helmet->Weapon`) | Empty backpack, full backpack capacity | Equipping `Servo-Grip Gauntlets` updates both UI & lockpicking | Room 1 Bunkhouse locker equip flow |
| 10 | **Drag-and-Drop `InventorySlot`** | M2 | `_get_drag_data`, `_can_drop_data`, `_drop_data` slot-type validation, `equipment_changed` signal | Mismatched `slot_type` rejected; `ANY` backpack accepts all | Dragging torso armor recalculates `total_armor` + `Scrap Shielding` | Swapping weapons/armor mid-dungeon in Sub-Level 04 |
| 11 | **Locational Armor Math** | M2 | Weighted roll (`40% Torso, 25% Legs, 20% Arms, 15% Head`), damage reduction, durability loss | `0` damage, negative damage, overflow damage (`9999`), `0` durability armor | `Scrap Shielding` (+15% Torso armor) on Torso hit | Tanking Unit 734-B hits in Room 7 Boss Fight |
| 12 | **2D HUD Weapon View** | M3 | `WeaponView2D.gd` `AnimatedSprite2D` bottom-right HUD, velocity sine-wave bobbing | Zero velocity (no bob), extreme velocity clamp | Switches animation between Blaster Pistol and Hydro-Spanner | Firing/swinging through Rooms 2, 5, 6, 7 |
| 13 | **Ranged Blaster Combat** | M3 | `WeaponRay` (50m) vs `Area3D`, `d100` hit roll, spark/ricochet, heat capacitor + `Power Cell` reload | Clamped `5%–95%` hit chance, max heat overheat, `0` Power Cells | `Cell Recycler` (20% no-consume), `Overcharge Capacitor`, `Ricochet Shot` | Shooting Mining Drones on Room 5 catwalks & Unit 734-B |
| 14 | **Directional Melee Combat** | M3 | Mouse drag threshold: Thrust (`+15%/-20%`), Overhead (`-15%/+30%`), Left/Right (`0%/0%`) | Drag below threshold (no swing), `2.2m` vs `2.3m` range | `Piston Strike` staggers on Overhead; `Grit` scales melee damage | Smashing Room 2 Slag-Ticks & supply crates |
| 15 | **Enemy FSM & Archetypes** | M3 | `IDLE`/`CHASE`/`ATTACK`/`DEAD` FSM; Slag-Tick, Mining Drone, Feral Driller, Sentry Turret, Unit 734-B | Damage on `DEAD` enemy ignored, `EnemyHitbox.take_damage` bounds | `Ambush Calibration` (+50% on `is_unaware`), `Turret Override` | Room 2, 5, 6, 7 combat encounters |
| 16 | **Mag-Tumbler Lockpicking** | M4 | CRT overlay, 3–5 oscillating cylinders, Left/Right + Spacebar, shear line check | `0` durability `Mag-Pick`, failed timing damages `Mag-Pick` | `Guile` + `Mag-Tumbler Sense` (+25% sweet spot) + `Servo-Grip Gauntlets` (+10%) | Room 4 Path A (Mag-Lock maintenance vent) |
| 17 | **Node-Matrix Hacking** | M4 | CRT overlay, `5x5`–`8x8` grid, Entry->Data Core, `Firewall`, `ICE Boost`, `Data Cache`, `Signal Dampener` | `ICE Trace Timer == 0` failure, non-adjacent tile click rejected | `Tech` + `Signal Bypass` (+1 visibility) | Room 4 Path B (Wall Terminal) & Room 6 (Overseer Mainframe) |
| 18 | **XP, Leveling & 4 Attributes** | M4 | XP awards -> level-up (`+1 Attribute Pt`, `+2 Skill Pts`), `level_up` signal; `Grit`, `Reflex`, `Tech`, `Guile` | `0`/negative XP ignored, multi-level XP overflow, `0` points spend | Attributes scale HP/melee (`Grit`), accuracy (`Reflex`), hack (`Tech`), lockpick (`Guile`) | Leveling up from Room 2–5 kills/hacks before Room 6 |
| 19 | **3-Branch Skill Tree (15 Skills)** | M4 | `SkillResource`, `SkillNodeButton`, `Line2D` color change; all 15 skills across 3 branches | Prerequisite unmet rejection, insufficient Skill Points, duplicate unlock | All Tier 3 skill perks active in combat/minigames/dialogue | Unlocking `Turret Override` or `Miner's Cant` mid-run |
| 20 | **Keyword Dialogue UI** | M5 | Portrait + scrolling text (left), clickable Topics (right), `dialogue_topic_visited` signal | `[Tech 15]` gate boundary (`14` locked vs `15` unlocked) | `Miner's Cant` skill unlocks union/underworld topics | Talking to Kael in Room 3 & Room 7 (`Dead Man's Switch` & Blackbox) |
| 21 | **Quest Manager & Radiant Jobs** | M5 | `QuestResource` + `QuestStage` (`KILL`/`FETCH`/`HACK`/`TALK`), `"Dead Man's Switch"`, `RadiantJobGenerator` | Duplicate quest start, out-of-order stage completion, empty template guard | Quest stages complete via `EventBus` (`enemy_killed`, `minigame_completed`, `item_picked_up`) | Full `"Dead Man's Switch"` + Blackbox choice + Rust-Spire Radiant Job |
| 22 | **Sub-Level 04 (7 Rooms) & Hub** | M5 | Rooms 1–7 entities/triggers + `RustSpireOutpost.tscn` transition | Missing Keycard at Room 7 Cargo Lift rejected | Room 4 Path C (`JunctionBox`) alerts Room 5 Mining Drones | End-to-end Stealth, Tech, and Grit walkthroughs |

---

## 3. Test Architecture

```
/home/antigravity/tests/
├── validate_project.py        # Python 3.11 static/structural/logic validator (--milestone M1..M5|ALL)
├── run_tests.gd               # Godot 4.x --headless SceneTree runner (--tier=1..4|all --milestone=M1..M5|ALL)
├── test_helper.gd             # Assertions, deterministic helpers, singleton reset utilities
├── unit/
│   ├── test_m1_core_25d.gd    # M1: SubViewport, shader, Autoloads, PlayerController, Billboard8Dir
│   ├── test_m2_inventory_armor.gd # M2: ItemData, InventorySlot, Paper-Doll, Locational Armor
│   ├── test_m3_combat.gd      # M3: WeaponView2D, Blaster d100/heat, Directional Melee, Enemy FSM
│   ├── test_m4_subsystems_skills.gd # M4: Lockpicking, Hacking, XP/Attributes, 15-Skill Tree
│   └── test_m5_dialogue_quests.gd   # M5: DialogueUI gates, QuestManager, RadiantJobGenerator
└── e2e/
    ├── test_tier3_combinations.gd   # Tier 3: Cross-feature combinations
    └── test_tier4_scenarios.gd      # Tier 4: Full Sub-Level 04 (Rooms 1-7) & Rust-Spire scenarios
```

### Execution Commands

1. **Python Static & Structural Validator (no Godot required):**
   ```bash
   # Validate all existing files + milestone readiness summary:
   python3 /home/antigravity/tests/validate_project.py

   # Strictly gate a specific milestone (M1, M2, M3, M4, M5, or ALL):
   python3 /home/antigravity/tests/validate_project.py --milestone M1
   python3 /home/antigravity/tests/validate_project.py --milestone ALL
   ```

2. **Godot 4.x Headless Test Suite:**
   ```bash
   # Run full Tiers 1-4 test suite:
   godot --headless --path /home/antigravity --script res://tests/run_tests.gd --quit

   # Filter by tier or milestone:
   godot --headless --path /home/antigravity --script res://tests/run_tests.gd --quit -- --tier=1 --milestone=M1
   godot --headless --path /home/antigravity --script res://tests/run_tests.gd --quit -- --tier=3
   godot --headless --path /home/antigravity --script res://tests/run_tests.gd --quit -- --tier=4
   ```
