# Project: Slag & Starlight

**Setting:** Khoros-IV (arid, rust-choked strip-mining moon) — Starter Dungeon **Sub-Level 04: The Deep Bore** -> **Rust-Spire Outpost**.
**Engine:** Godot 4.x (`config_version=5`, `GL Compatibility` renderer, `320x200` `SubViewport`, `Nearest` texture filtering).
**Tooling Note:** Godot 4.x is not installed in the current sandbox; Python 3.11 + Pillow 9.4.0 + NumPy 1.24.2 are used for procedural pixel-art generation (`tools/generate_assets.py`) and static/structural/logic validation (`tests/validate_project.py`), alongside a full Godot `--headless` test runner (`tests/run_tests.gd`) for execution in Godot 4.x.

---

## Architecture

- **Decoupled 2.5D Presentation & Systemic RPG Rules:**
  - `Main.tscn` wraps `World3D` inside `SubViewportContainer` -> `SubViewport (320x200, Nearest)` with a `PostProcessLayer` (`CanvasLayer` + `retro_quantize_fog.gdshader` for 256-color rust/industrial quantization + fog) and `HUDLayer` (`CanvasLayer` for `WeaponView2D`, health/heat/suit power bars, combat log, and pop-up overlays).
  - Core singletons (`Autoload` in `project.godot`): `EventBus`, `GameState`, `PlayerStats`, `QuestManager`.
  - Data-driven `Resource` classes: `ItemData`, `SkillResource`, `QuestResource`, `QuestStage`, `DialogueResource`.

---

## Code Layout

```
/home/antigravity/
├── project.godot
├── PROJECT.md
├── tools/
│   └── generate_assets.py          # Procedural 256-color palette, textures, 8-dir sprites, HUD/UI art
├── assets/
│   ├── textures/                   # 64x64 & 128x128 nearest-neighbor environment textures
│   ├── sprites/                    # 8-row enemy/NPC sprite sheets, sparks, pickups
│   ├── weapons/                    # HUD AnimatedSprite2D weapon frames
│   └── ui/                         # Paper-doll layers, item icons, CRT frames
├── shaders/
│   └── retro_quantize_fog.gdshader # 256-color quantization + distance fog
├── scripts/
│   ├── autoload/
│   │   ├── EventBus.gd
│   │   ├── GameState.gd
│   │   ├── PlayerStats.gd
│   │   └── QuestManager.gd
│   ├── resources/
│   │   ├── ItemData.gd
│   │   ├── SkillResource.gd
│   │   ├── QuestStage.gd
│   │   ├── QuestResource.gd
│   │   └── DialogueData.gd
│   ├── player/
│   │   ├── PlayerController.gd
│   │   └── WeaponView2D.gd
│   ├── visuals/
│   │   └── Billboard8Dir.gd
│   ├── combat/
│   │   ├── EnemyBase.gd
│   │   ├── EnemyHitbox.gd
│   │   └── BreakableCrate.gd
│   ├── ui/
│   │   ├── InventorySlot.gd
│   │   ├── InventoryUI.gd
│   │   ├── SkillNodeButton.gd
│   │   ├── SkillTreeUI.gd
│   │   ├── LockpickMinigame.gd
│   │   ├── HackingMinigame.gd
│   │   ├── DialogueUI.gd
│   │   └── HUD.gd
│   └── world/
│       ├── Interactable.gd
│       ├── BlastDoor.gd
│       ├── JunctionBox.gd
│       ├── CargoLift.gd
│       └── RadiantJobGenerator.gd
├── resources/
│   ├── items/                      # .tres ItemData definitions
│   ├── skills/                     # 15 .tres SkillResource definitions
│   ├── quests/                     # Dead Man's Switch .tres
│   └── dialogue/                   # Kael & NPC dialogue .tres
├── scenes/
│   ├── Main.tscn
│   ├── player/Player.tscn
│   ├── enemies/                    # SlagTick.tscn, MiningDrone.tscn, FeralDriller.tscn, SentryTurret.tscn, Unit734B.tscn
│   ├── ui/                         # HUD.tscn, InventoryUI.tscn, SkillTreeUI.tscn, LockpickMinigame.tscn, HackingMinigame.tscn, DialogueUI.tscn
│   └── levels/
│       ├── SubLevel04.tscn         # 7-room starter dungeon
│       ├── RustSpireOutpost.tscn   # Surface hub + Radiant Job Terminal
│       └── modules/                # Reusable low-poly room/corridor/prop prefabs
└── tests/
    ├── validate_project.py         # Static, structural, reference & logic validator
    ├── run_tests.gd                # Godot --headless test runner
    ├── unit/                       # Per-system unit tests
    └── e2e/                        # Tiers 1-5 E2E tests
```

---

## Feature Inventory

Every feature from `ORIGINAL_REQUEST.md` is assigned to a milestone:

| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | 2.5D SubViewport Setup | `320x200` SubViewport, `viewport` stretch, `Nearest` texture filter, GL Compatibility | M1 | Sec 1 |
| 2 | Retro Post-Process Shader | Full-screen `CanvasLayer` 256-color rust/industrial quantization + distance fog | M1 | Sec 1 |
| 3 | Low-Poly Modular Geometry | Modular dungeon corridors/rooms, `64x64`/`128x128` `TEXTURE_FILTER_NEAREST`, unshaded/per-vertex | M1 | Sec 1 |
| 4 | Billboarded 8-Dir Sprites | `Sprite3D` `BILLBOARD_FIXED_Y` + dot/cross 8-row `frame_coords.y` updater | M1 | Sec 1 |
| 5 | Core Autoloads | `GameState.gd`, `EventBus.gd` (required signals), `PlayerStats.gd` | M1 | Sec 2 |
| 6 | Player Controller & Rays | `CharacterBody3D`, `Camera3D`, `InteractRay` (`2.5m`), `WeaponRay` (`50m`/`2.2m`) | M1 | Sec 3 |
| 7 | Procedural Retro Assets | Python/Pillow generator for palette, textures, 8-dir sheets, weapon/paper-doll/UI PNGs | M1 | Sec 1, 9 |
| 8 | `ItemData` Resource & Catalog | `id`, `name`, `icon`, `paper_doll_sprite`, `slot_type`, `weight`, `armor_rating`, `damage_range`, `durability` | M2 | Sec 4 |
| 9 | 7-Slot Paper-Doll & Grid UI | Pauses/slows world, Grid Backpack + 2D Paper-Doll, Z-index layering (`Under-suit->Greaves->Torso->Pauldrons->Helmet->Weapon`) | M2 | Sec 4 |
| 10 | Drag-and-Drop `InventorySlot` | `PanelContainer` overriding `_get_drag_data`, `_can_drop_data`, `_drop_data` + `total_armor` recalc | M2 | Sec 4 |
| 11 | Locational Armor Math | Weighted hit roll (`40% Torso, 25% Legs, 20% Arms, 15% Head`), damage reduction & durability loss | M2 | Sec 4 |
| 12 | 2D HUD Weapon View | `AnimatedSprite2D` bottom-right of HUD + velocity sine-wave weapon bobbing | M3 | Sec 1 |
| 13 | Ranged Blaster Combat | `WeaponRay` (50m) vs `Area3D`, `d100` hit roll, 2D spark / ricochet SFX, heat capacitor + `Power Cell` reload | M3 | Sec 3 |
| 14 | Directional Melee Combat | Hold attack + mouse drag threshold: Thrust (`+15%/-20%`), Overhead (`-15%/+30%`), Left/Right (`0%/0%`) | M3 | Sec 3 |
| 15 | Enemy FSM & Archetypes | `IDLE`/`CHASE`/`ATTACK`/`DEAD` FSM + Slag-Tick, Rogue Mining Drone, Feral Driller, Sentry Turret, Unit 734-B | M3 | Sec 8, 9 |
| 16 | Mag-Tumbler Lockpicking | CRT overlay, 3-5 oscillating cylinders, Left/Right + Spacebar, `Guile`/`Mag-Tumbler Sense`/`Servo-Grip`, `Mag-Pick` durability | M4 | Sec 6 |
| 17 | Node-Matrix Hacking | CRT overlay, `5x5`-`8x8` grid, Entry->Data Core, `Firewall`/`ICE Boost`/`Data Cache`/`Signal Dampener`, `Tech` + `Signal Bypass` | M4 | Sec 6 |
| 18 | XP, Leveling & 4 Attributes | XP awards -> level-up `+1 Attribute Pt`, `+2 Skill Pts`; `Grit`, `Reflex`, `Tech`, `Guile` | M4 | Sec 5 |
| 19 | 3-Branch Skill Tree (15 Skills) | `SkillResource`, `SkillNodeButton`, `Line2D` color connectors; Void-Scrapper, Cyber-Splicer, Tunnel-Rat (all 15 skills) | M4 | Sec 5 |
| 20 | Keyword Dialogue UI | *Morrowind*/*Daggerfall* style: animated portrait + text (left), clickable Topics + `[Tech 15]` / `Miner's Cant` gates (right) | M5 | Sec 7 |
| 21 | Quest Manager & Radiant Jobs | `QuestResource` + `QuestStage` (`KILL`/`FETCH`/`HACK`/`TALK`), `"Dead Man's Switch"`, Radiant Job Generator | M5 | Sec 7 |
| 22 | Sub-Level 04 (7 Rooms) & Hub | Rooms 1-7 (locker, crates, Kael, Room 4 Paths A/B/C, Room 5 catwalks, Room 6 turret/mainframe, Room 7 boss + Rust-Spire Outpost) | M5 | Sec 8 |

---

## Milestones

| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Greybox & 2.5D Controller | `project.godot`, Autoloads (`EventBus`, `GameState`, `PlayerStats`), `tools/generate_assets.py`, `Main.tscn` (`320x200` SubViewport + shader), `PlayerController`, `Billboard8Dir`, modular greybox rooms | none | DONE |
| M2 | Items & Paper-Doll UI | `ItemData.gd`, item `.tres` catalog, `InventorySlot.gd`, `InventoryUI.tscn`/`.gd`, Z-layered paper-doll, locational armor math | M1 | DONE |
| M3 | Combat Loop | `WeaponView2D.gd`, blaster `d100` hit-roll + heat/Power Cell, directional melee mouse-drag, `EnemyBase.gd` FSM + 5 enemy scenes + `BreakableCrate` | M1, M2 | DONE |
| M4 | Sub-Systems & Progression | `LockpickMinigame`, `HackingMinigame`, `SkillResource` + 15 `.tres` skills, `SkillNodeButton` + `SkillTreeUI`, XP/Attributes, skill perk hooks | M1, M2, M3 | DONE |
| M5 | Dialogue, Quests & Level Assembly | `DialogueUI`, `QuestResource`/`QuestStage`/`QuestManager`, `RadiantJobGenerator`, full 7-room `SubLevel04.tscn` + `RustSpireOutpost.tscn` | M1, M2, M3, M4 | DONE |
| E2E | E2E Testing Track | `TEST_INFRA.md`, `tests/validate_project.py`, `tests/run_tests.gd`, Tier 1-4 test suite, `TEST_READY.md` | none (parallel) | DONE |
| M6 | Final E2E Pass & Hardening | Pass 100% E2E Tiers 1-4 + Tier 5 adversarial coverage hardening | M5, E2E | DONE |

---

## Interface Contracts

### `EventBus` (`scripts/autoload/EventBus.gd`)
- `signal item_picked_up(item: ItemData, quantity: int)`
- `signal quest_updated(quest_id: String, stage_id: String)`
- `signal combat_log_entry(message: String, category: String)`
- `signal minigame_requested(minigame_type: String, difficulty: String, target_node: Node)`
- `signal minigame_completed(target_id: String, success: bool, bonus_data: Dictionary)`
- `signal player_stats_changed()`
- `signal equipment_changed(slot_type: int)`
- `signal level_up(new_level: int)`
- `signal enemy_killed(enemy_id: String)`
- `signal dialogue_topic_visited(npc_id: String, topic_id: String)`

### `GameState` (`scripts/autoload/GameState.gd`)
- `flags: Dictionary`, `active_quests: Dictionary`, `completed_quests: Array[String]`, `faction_reputation: Dictionary`, `world_state: Dictionary`
- `set_flag(key: String, value: Variant = true) -> void`
- `get_flag(key: String, default: Variant = false) -> Variant`
- `modify_reputation(faction_id: String, delta: int) -> void`

### `PlayerStats` (`scripts/autoload/PlayerStats.gd`)
- `level: int`, `xp: int`, `xp_to_next: int`, `attribute_points: int`, `skill_points: int`
- `attributes: Dictionary` (`"grit"`, `"reflex"`, `"tech"`, `"guile"`)
- `unlocked_skills: Array[String]`, `equipped_items: Dictionary`, `backpack_items: Array[ItemData]`
- `hp: int`, `max_hp: int`, `suit_power: float`, `max_suit_power: float`, `total_armor: int`, `credits: int`
- `add_xp(amount: int) -> void`, `has_skill(skill_id: String) -> bool`, `recalculate_derived_stats() -> void`, `apply_locational_damage(raw_damage: int) -> Dictionary`

### `EnemyHitbox` (`scripts/combat/EnemyHitbox.gd`)
- `evasion: int`, `enemy_id: String`, `is_unaware: bool`
- `take_damage(amount: int, damage_type: String, is_stagger: bool) -> void`
