#!/usr/bin/env python3
"""
Static, Structural & Interface Contract Validator for "Slag & Starlight" (Godot 4.x).

Runnable in environments without Godot 4.x installed (Python 3.11+).
Supports incremental milestone gating via --milestone M1|M2|M3|M4|M5|ALL|AUTO.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple


ROOT = Path(__file__).resolve().parent.parent

MILESTONE_ORDER = ["M1", "M2", "M3", "M4", "M5"]

MILESTONE_FILES: Dict[str, List[str]] = {
    "M1": [
        "project.godot",
        "tools/generate_assets.py",
        "shaders/retro_quantize_fog.gdshader",
        "scripts/autoload/EventBus.gd",
        "scripts/autoload/GameState.gd",
        "scripts/autoload/PlayerStats.gd",
        "scripts/player/PlayerController.gd",
        "scripts/visuals/Billboard8Dir.gd",
        "scenes/Main.tscn",
        "scenes/player/Player.tscn",
    ],
    "M2": [
        "scripts/resources/ItemData.gd",
        "scripts/ui/InventorySlot.gd",
        "scripts/ui/InventoryUI.gd",
        "scenes/ui/InventoryUI.tscn",
    ],
    "M3": [
        "scripts/player/WeaponView2D.gd",
        "scripts/combat/EnemyBase.gd",
        "scripts/combat/EnemyHitbox.gd",
        "scripts/combat/BreakableCrate.gd",
        "scenes/ui/HUD.tscn",
        "scenes/enemies/SlagTick.tscn",
        "scenes/enemies/MiningDrone.tscn",
        "scenes/enemies/FeralDriller.tscn",
        "scenes/enemies/SentryTurret.tscn",
        "scenes/enemies/Unit734B.tscn",
    ],
    "M4": [
        "scripts/ui/LockpickMinigame.gd",
        "scripts/ui/HackingMinigame.gd",
        "scripts/resources/SkillResource.gd",
        "scripts/ui/SkillNodeButton.gd",
        "scripts/ui/SkillTreeUI.gd",
        "scenes/ui/LockpickMinigame.tscn",
        "scenes/ui/HackingMinigame.tscn",
        "scenes/ui/SkillTreeUI.tscn",
    ],
    "M5": [
        "scripts/autoload/QuestManager.gd",
        "scripts/resources/QuestStage.gd",
        "scripts/resources/QuestResource.gd",
        "scripts/resources/DialogueData.gd",
        "scripts/ui/DialogueUI.gd",
        "scripts/world/Interactable.gd",
        "scripts/world/BlastDoor.gd",
        "scripts/world/JunctionBox.gd",
        "scripts/world/CargoLift.gd",
        "scripts/world/RadiantJobGenerator.gd",
        "scenes/ui/DialogueUI.tscn",
        "scenes/levels/SubLevel04.tscn",
        "scenes/levels/RustSpireOutpost.tscn",
    ],
}

MILESTONE_MIN_COUNTS: Dict[str, List[Tuple[str, str, int]]] = {
    "M2": [("resources/items", "*.tres", 1)],
    "M4": [("resources/skills", "*.tres", 15)],
    "M5": [("resources/quests", "*.tres", 1), ("resources/dialogue", "*.tres", 1)],
}

INTERFACE_CONTRACTS: Dict[str, Dict[str, List[str]]] = {
    "scripts/autoload/EventBus.gd": {
        "signals": [
            "item_picked_up",
            "quest_updated",
            "combat_log_entry",
            "minigame_requested",
            "minigame_completed",
            "player_stats_changed",
            "equipment_changed",
            "level_up",
            "enemy_killed",
            "dialogue_topic_visited",
        ],
    },
    "scripts/autoload/GameState.gd": {
        "vars": [
            "flags",
            "active_quests",
            "completed_quests",
            "faction_reputation",
            "world_state",
        ],
        "funcs": ["set_flag", "get_flag", "modify_reputation"],
    },
    "scripts/autoload/PlayerStats.gd": {
        "vars": [
            "level",
            "xp",
            "xp_to_next",
            "attribute_points",
            "skill_points",
            "attributes",
            "unlocked_skills",
            "equipped_items",
            "backpack_items",
            "hp",
            "max_hp",
            "suit_power",
            "max_suit_power",
            "total_armor",
            "credits",
        ],
        "funcs": [
            "add_xp",
            "has_skill",
            "recalculate_derived_stats",
            "apply_locational_damage",
        ],
    },
    "scripts/combat/EnemyHitbox.gd": {
        "vars": ["evasion", "enemy_id", "is_unaware"],
        "funcs": ["take_damage"],
    },
}


class ValidationResult:
    def __init__(self) -> None:
        self.errors: List[str] = []
        self.warnings: List[str] = []
        self.checked_files: int = 0

    def error(self, msg: str) -> None:
        self.errors.append(msg)

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)


def strip_gdscript_strings_and_comments(source: str) -> str:
    """Replace strings and comments with spaces to preserve line numbers for syntax/bracket checks."""
    out: List[str] = []
    i = 0
    n = len(source)
    while i < n:
        ch = source[i]
        # Comment
        if ch == "#":
            while i < n and source[i] != "\n":
                out.append(" ")
                i += 1
            continue
        # Triple-quoted string
        if source[i : i + 3] in ('"""', "'''"):
            quote = source[i : i + 3]
            out.extend([" ", " ", " "])
            i += 3
            while i < n and source[i : i + 3] != quote:
                out.append("\n" if source[i] == "\n" else " ")
                i += 1
            if i < n:
                out.extend([" ", " ", " "])
                i += 3
            continue
        # Single or double quoted string
        if ch in ('"', "'"):
            quote = ch
            out.append(" ")
            i += 1
            while i < n and source[i] != quote:
                if source[i] == "\\" and i + 1 < n:
                    out.extend([" ", " "])
                    i += 2
                    continue
                if source[i] == "\n":
                    out.append("\n")
                    i += 1
                    break
                out.append(" ")
                i += 1
            if i < n and source[i] == quote:
                out.append(" ")
                i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def check_balanced_delimiters(cleaned: str, rel_path: str, res: ValidationResult) -> None:
    pairs = {"(": ")", "[": "]", "{": "}"}
    closing = {")": "(", "]": "[", "}": "{"}
    stack: List[Tuple[str, int]] = []
    line = 1
    for ch in cleaned:
        if ch == "\n":
            line += 1
        elif ch in pairs:
            stack.append((ch, line))
        elif ch in closing:
            if not stack:
                res.error(f"{rel_path}:{line}: Unmatched closing '{ch}'")
                return
            top, top_line = stack.pop()
            if closing[ch] != top:
                res.error(
                    f"{rel_path}:{line}: Mismatched '{ch}' (expected closing for '{top}' from line {top_line})"
                )
                return
    if stack:
        top, top_line = stack[-1]
        res.error(f"{rel_path}:{top_line}: Unclosed '{top}'")


def validate_project_godot(path: Path, milestone: str, res: ValidationResult) -> None:
    rel = path.relative_to(ROOT).as_posix()
    res.checked_files += 1
    text = path.read_text(encoding="utf-8", errors="replace")

    if not re.search(r"(?m)^config_version=5\b", text):
        res.error(f"{rel}: Missing 'config_version=5'")

    if "gl_compatibility" not in text:
        res.error(f"{rel}: Missing 'gl_compatibility' renderer setting")

    if not re.search(r'window/stretch/mode\s*=\s*"viewport"', text):
        res.error(f"{rel}: Missing window/stretch/mode=\"viewport\"")

    if not re.search(r"textures/canvas_textures/default_texture_filter\s*=\s*0\b", text):
        res.warn(f"{rel}: Expected textures/canvas_textures/default_texture_filter=0 (Nearest)")

    required_autoloads = ["EventBus", "GameState", "PlayerStats"]
    if milestone in ("M5", "ALL"):
        required_autoloads.append("QuestManager")
    for autoload in required_autoloads:
        if not re.search(rf"(?m)^{autoload}\s*=", text):
            res.error(f"{rel}: Missing Autoload '{autoload}'")


def validate_gdscript(path: Path, res: ValidationResult) -> None:
    rel = path.relative_to(ROOT).as_posix()
    res.checked_files += 1
    text = path.read_text(encoding="utf-8", errors="replace")
    cleaned = strip_gdscript_strings_and_comments(text)

    check_balanced_delimiters(cleaned, rel, res)

    if not re.search(r"(?m)^\s*(extends|class_name)\s+\w+", cleaned):
        res.error(f"{rel}: Missing 'extends' or 'class_name' declaration")

    # Python/JS syntax leak checks on stripped code
    leak_patterns = [
        (r"(?m)^\s*def\s+\w+\s*\(", "Python 'def' keyword (use 'func')"),
        (r"(?m)^\s*import\s+\w+", "Python/JS 'import' statement"),
        (r"\bconsole\.log\s*\(", "JS 'console.log()'"),
        (r"===|!==", "JS strict equality '===' / '!=='"),
        (r"\b(True|False|None)\b", "Python literal 'True'/'False'/'None' (use true/false/null)"),
    ]
    for pattern, desc in leak_patterns:
        m = re.search(pattern, cleaned)
        if m:
            line_no = cleaned[: m.start()].count("\n") + 1
            res.error(f"{rel}:{line_no}: Syntax leak detected: {desc}")

    # Verify res:// path literals in GDScript exist on disk
    for m in re.finditer(r'"res://([^"\s%]+)"', text):
        rel_target = m.group(1)
        if not (ROOT / rel_target).exists():
            line_no = text[: m.start()].count("\n") + 1
            res.error(f"{rel}:{line_no}: Broken res:// path literal 'res://{rel_target}'")

    # Interface contract checks
    contract = INTERFACE_CONTRACTS.get(rel)
    if contract:
        for sig in contract.get("signals", []):
            if not re.search(rf"(?m)^\s*signal\s+{re.escape(sig)}\b", cleaned):
                res.error(f"{rel}: Contract violation: missing signal '{sig}'")
        for var_name in contract.get("vars", []):
            if not re.search(rf"(?m)^\s*(?:@export[^\n]*\s+)?var\s+{re.escape(var_name)}\b", cleaned):
                res.error(f"{rel}: Contract violation: missing var '{var_name}'")
        for func_name in contract.get("funcs", []):
            if not re.search(rf"(?m)^\s*func\s+{re.escape(func_name)}\s*\(", cleaned):
                res.error(f"{rel}: Contract violation: missing func '{func_name}()'")


def validate_scene_or_resource(path: Path, res: ValidationResult) -> None:
    rel = path.relative_to(ROOT).as_posix()
    res.checked_files += 1
    text = path.read_text(encoding="utf-8", errors="replace")

    expected_header = "[gd_scene" if path.suffix == ".tscn" else "[gd_resource"
    if not text.lstrip().startswith(expected_header):
        res.error(f"{rel}: Missing '{expected_header}' header")

    # Collect ext_resource IDs and verify res:// paths exist
    ext_ids: Set[str] = set()
    ext_paths_by_id: Dict[str, str] = {}
    for m in re.finditer(r'\[ext_resource\b([^\]]+)\]', text):
        attrs = m.group(1)
        path_m = re.search(r'path="res://([^"]+)"', attrs)
        id_m = re.search(r'id="([^"]+)"', attrs)
        if id_m:
            ext_ids.add(id_m.group(1))
            if path_m:
                ext_paths_by_id[id_m.group(1)] = path_m.group(1)
        if path_m:
            target = ROOT / path_m.group(1)
            if not target.exists():
                res.error(f"{rel}: Broken ext_resource path 'res://{path_m.group(1)}'")

    # Collect sub_resource IDs
    sub_ids: Set[str] = set()
    for m in re.finditer(r'\[sub_resource\b([^\]]+)\]', text):
        id_m = re.search(r'id="([^"]+)"', m.group(1))
        if id_m:
            sub_ids.add(id_m.group(1))

    # Verify load_steps header matches ext_resource + sub_resource + 1
    header_m = re.search(r"^\[(?:gd_scene|gd_resource)\b([^\]]*)\]", text.lstrip())
    if header_m:
        ls_m = re.search(r"\bload_steps=(\d+)", header_m.group(1))
        if ls_m:
            declared_steps = int(ls_m.group(1))
            expected_steps = len(ext_ids) + len(sub_ids) + 1
            if declared_steps != expected_steps:
                res.error(
                    f"{rel}: load_steps={declared_steps} does not match ext({len(ext_ids)}) + sub({len(sub_ids)}) + 1 = {expected_steps}"
                )

    # Verify ExtResource("...") and SubResource("...") references
    for m in re.finditer(r'ExtResource\(\s*"([^"]+)"\s*\)', text):
        ref_id = m.group(1)
        if ref_id not in ext_ids:
            res.error(f"{rel}: Undefined ExtResource(\"{ref_id}\")")

    for m in re.finditer(r'SubResource\(\s*"([^"]+)"\s*\)', text):
        ref_id = m.group(1)
        if ref_id not in sub_ids:
            res.error(f"{rel}: Undefined SubResource(\"{ref_id}\")")

    # Verify Billboard8Dir Sprite3D nodes in .tscn files specify hframes = 4 and vframes = 8
    if path.suffix == ".tscn":
        billboard_ext_ids = {
            eid for eid, epath in ext_paths_by_id.items() if epath.endswith("Billboard8Dir.gd")
        }
        if billboard_ext_ids:
            node_blocks = re.split(r"(?m)^\[node\b", text)[1:]
            for block in node_blocks:
                for bb_id in billboard_ext_ids:
                    if re.search(rf'script\s*=\s*ExtResource\(\s*"{re.escape(bb_id)}"\s*\)', block):
                        if not re.search(r"(?m)^hframes\s*=\s*4\b", block):
                            res.error(f"{rel}: Sprite3D with Billboard8Dir.gd is missing 'hframes = 4'")
                        if not re.search(r"(?m)^vframes\s*=\s*8\b", block):
                            res.error(f"{rel}: Sprite3D with Billboard8Dir.gd is missing 'vframes = 8'")


def validate_shader(path: Path, res: ValidationResult) -> None:
    rel = path.relative_to(ROOT).as_posix()
    res.checked_files += 1
    text = path.read_text(encoding="utf-8", errors="replace")
    if not re.search(r"(?m)^\s*shader_type\s+(canvas_item|spatial|particles|sky|fog)\s*;", text):
        res.error(f"{rel}: Missing valid 'shader_type ...;' declaration")
    check_balanced_delimiters(strip_gdscript_strings_and_comments(text), rel, res)


def milestones_up_to(target: str) -> List[str]:
    if target == "ALL":
        return list(MILESTONE_ORDER)
    if target in MILESTONE_ORDER:
        idx = MILESTONE_ORDER.index(target)
        return MILESTONE_ORDER[: idx + 1]
    return []


def check_milestone_completeness(target: str, res: ValidationResult) -> None:
    for ms in milestones_up_to(target):
        for rel_file in MILESTONE_FILES.get(ms, []):
            if not (ROOT / rel_file).exists():
                res.error(f"[{ms}] Missing required file: {rel_file}")
        for rel_dir, glob_pat, min_count in MILESTONE_MIN_COUNTS.get(ms, []):
            dir_path = ROOT / rel_dir
            found = len(list(dir_path.glob(glob_pat))) if dir_path.exists() else 0
            if found < min_count:
                res.error(
                    f"[{ms}] Expected at least {min_count} '{glob_pat}' in {rel_dir}/, found {found}"
                )


def print_milestone_summary() -> None:
    print("\n--- Milestone File Readiness ---")
    for ms in MILESTONE_ORDER:
        files = MILESTONE_FILES[ms]
        present = sum(1 for f in files if (ROOT / f).exists())
        status = "READY" if present == len(files) else "PENDING"
        print(f"  {ms}: {present}/{len(files)} required files present [{status}]")


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Validate Slag & Starlight Godot 4.x project.")
    parser.add_argument(
        "--milestone",
        choices=["AUTO", "M1", "M2", "M3", "M4", "M5", "ALL"],
        default="AUTO",
        help="Target milestone to enforce (default: AUTO validates all existing files).",
    )
    args = parser.parse_args(argv)

    res = ValidationResult()

    # 1. Milestone completeness if explicit milestone requested
    if args.milestone != "AUTO":
        check_milestone_completeness(args.milestone, res)

    # 2. Validate existing project.godot
    pg = ROOT / "project.godot"
    if pg.exists():
        validate_project_godot(pg, args.milestone, res)

    # 3. Validate all existing .gd files (excluding tests/ only? No, validate tests/ .gd too!)
    for gd_path in sorted(ROOT.rglob("*.gd")):
        if ".agents" in gd_path.parts or ".git" in gd_path.parts:
            continue
        validate_gdscript(gd_path, res)

    # 4. Validate all existing .tscn and .tres files
    for res_path in sorted(list(ROOT.rglob("*.tscn")) + list(ROOT.rglob("*.tres"))):
        if ".agents" in res_path.parts or ".git" in res_path.parts:
            continue
        validate_scene_or_resource(res_path, res)

    # 5. Validate all existing .gdshader files
    for sh_path in sorted(ROOT.rglob("*.gdshader")):
        if ".agents" in sh_path.parts or ".git" in sh_path.parts:
            continue
        validate_shader(sh_path, res)

    print(f"Slag & Starlight Validator (milestone={args.milestone})")
    print(f"Checked files: {res.checked_files}")

    if res.warnings:
        print(f"\nWarnings ({len(res.warnings)}):")
        for w in res.warnings:
            print(f"  [WARN] {w}")

    if res.errors:
        print(f"\nErrors ({len(res.errors)}):")
        for e in res.errors:
            print(f"  [FAIL] {e}")
    else:
        print("\n[PASS] All validated files passed structural & contract checks.")

    if args.milestone == "AUTO":
        print_milestone_summary()

    return 1 if res.errors else 0


if __name__ == "__main__":
    sys.exit(main())
