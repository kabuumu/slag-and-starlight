# TEST_READY — Slag & Starlight E2E Testing Track

**Status:** READY  
**Date:** 2026-11-12T18:04:00Z  
**Track:** E2E Testing Track (`TEST_INFRA.md`, `tests/validate_project.py`, `tests/run_tests.gd`, Tiers 1–4 suite)

---

## Deliverables Created

1. **`/home/antigravity/TEST_INFRA.md`**
   - Opaque-box, requirement-driven test philosophy derived from `ORIGINAL_REQUEST.md` and `PROJECT.md`.
   - Complete **22-feature inventory matrix** mapping every feature in `PROJECT.md` to Tier 1, Tier 2, Tier 3, and Tier 4 tests.
   - Dual-layer test architecture (Python 3.11 static/structural/contract validator + Godot 4.x `--headless` SceneTree runner).

2. **`/home/antigravity/tests/validate_project.py`**
   - Validates `project.godot` (`config_version=5`, `gl_compatibility`, `viewport` stretch, Nearest filter, Autoloads).
   - Validates all `.gd` files (balanced delimiters, `extends`/`class_name`, syntax leak detection, `PROJECT.md` Interface Contracts for `EventBus`, `GameState`, `PlayerStats`, `EnemyHitbox`).
   - Validates all `.tscn` and `.tres` files (headers, `[ext_resource]` paths on disk, `ExtResource`/`SubResource` IDs).
   - Validates all `.gdshader` files (`shader_type` and balanced delimiters).
   - Supports `--milestone M1|M2|M3|M4|M5|ALL|AUTO` for incremental milestone gating.

3. **`/home/antigravity/tests/run_tests.gd`** & **`/home/antigravity/tests/test_helper.gd`**
   - Godot 4.x `extends SceneTree` headless runner supporting `--tier=1|2|3|4|all` and `--milestone=M1|M2|M3|M4|M5|ALL`.
   - **Unit Suites (Tiers 1 & 2):**
     - `tests/unit/test_m1_core_25d.gd`
     - `tests/unit/test_m2_inventory_armor.gd`
     - `tests/unit/test_m3_combat.gd`
     - `tests/unit/test_m4_subsystems_skills.gd`
     - `tests/unit/test_m5_dialogue_quests.gd`
   - **E2E Suites (Tiers 3 & 4):**
     - `tests/e2e/test_tier3_combinations.gd`
     - `tests/e2e/test_tier4_scenarios.gd`

---

## How to Run

### 1. Python Static, Structural & Contract Validator (Sandbox-Ready)
```bash
# Validate all existing files and show milestone readiness:
python3 /home/antigravity/tests/validate_project.py

# Strictly gate a milestone:
python3 /home/antigravity/tests/validate_project.py --milestone M1
python3 /home/antigravity/tests/validate_project.py --milestone ALL
```

### 2. Godot 4.x Headless Test Runner (Requires Godot 4.x)
```bash
# Run full Tiers 1-4 test suite:
godot --headless --path /home/antigravity --script res://tests/run_tests.gd --quit

# Run a specific milestone or tier:
godot --headless --path /home/antigravity --script res://tests/run_tests.gd --quit -- --tier=1 --milestone=M1
```

---

## Verification Results

- `python3 /home/antigravity/tests/validate_project.py`: **PASS** (22 files checked, 0 errors, 0 warnings; M1 10/10 READY, M2–M5 PENDING).
- `python3 /home/antigravity/tests/validate_project.py --milestone M1`: **PASS** (22 files checked, 0 errors).
- Godot `--headless` runner: Not executed in this sandbox (`godot` binary not installed).
