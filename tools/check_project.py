#!/usr/bin/env python3
"""Standard-library-only static sanity checks for the independent Godot UX project.
This DOES NOT parse GDScript or run the Godot runtime. Run Godot headless separately.
"""
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
errors = []
checks = 0

def check(condition, message):
    global checks
    checks += 1
    if not condition:
        errors.append(message)

for path in ROOT.rglob("*.gd"):
    source = path.read_text(encoding="utf-8")
    for kind, res in re.findall(r'\b(preload|load)\(\s*"(res://[^"]+)"\s*\)', source):
        check((ROOT / res[len('res://'):]).is_file(), f"missing {kind} target: {path.relative_to(ROOT)} -> {res}")
    for res in re.findall(r'^extends\s+"(res://[^"]+)"', source, flags=re.M):
        check((ROOT / res[len('res://'):]).is_file(), f"missing extends: {path.relative_to(ROOT)} -> {res}")
for path in ROOT.rglob("*.tscn"):
    for res in re.findall(r'path="(res://[^"]+)"', path.read_text(encoding="utf-8")):
        check((ROOT / res[len('res://'):]).is_file(), f"missing resource: {path.relative_to(ROOT)} -> {res}")

for page in ("hq", "auction", "expedition", "assembly", "market", "settlement"):
    check((ROOT / f"scenes/screens/{page}_screen.tscn").is_file(), f"missing screen scene {page}")
    check((ROOT / f"scenes/demos/{page}_demo.tscn").is_file(), f"missing demo scene {page}")
    check((ROOT / f"scripts/features/{page}/presentation/{page}_screen.gd").is_file(), f"missing feature presenter {page}")
    check((ROOT / f"assets/ux/previews/{ {'hq':'01_总部','auction':'02_矿区竞拍','expedition':'03_太空采矿','assembly':'04_火箭装配','market':'05_市场交易','settlement':'06_本轮结算'}[page] }.png").is_file(), f"missing wireframe preview {page}")

for svg in (ROOT / "assets/ux/wireframes").glob("*.svg"):
    try:
        ET.parse(svg)
    except ET.ParseError as exc:
        errors.append(f"invalid SVG {svg.name}: {exc}")
    checks += 1
check(len(list((ROOT / "assets/ux/wireframes").glob("*.svg"))) == 6, "expected six editable SVG wireframes")
for required in [
    "project.godot", "README.md", "AGENTS.md", "PROJECT_STATUS.md",
    "docs/gdd/Rocket_Prospectors_GDD_V1.0.md",
    "docs/gdd/DECISION_REGISTER.csv", "docs/ux/UX_V1.0.md",
    "docs/architecture/ARCHITECTURE_V1.0.md",
    "docs/architecture/INTERFACE_CONTRACTS.md",
    "docs/production/TASK_BOARD.md", "docs/production/UX_TEST_SCRIPT.md",
    "scripts/contracts/frontier_contracts.gd", "scripts/core/ux_session.gd", 
    "scripts/tests/test_ux_flow.gd", "scenes/main.tscn"
]:
    check((ROOT / required).is_file(), f"missing required deliverable {required}")
check(not (ROOT / "docs/archive").exists(), "obsolete legacy docs/archive should not be shipped")
check(not (ROOT / "docs/production/CODEX_HANDOFF_ORIGINAL.md").exists(), "obsolete old handoff should not be shipped")

print(f"Static project checks: {checks} checks; {len(errors)} failures")
for failure in errors:
    print("FAIL:", failure)
print("Note: this is NOT a Godot parser or runtime test")
sys.exit(1 if errors else 0)
