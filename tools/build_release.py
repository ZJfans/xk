#!/usr/bin/env python3
"""Create and validate the clean Godot UX V1.0 source package.

No third-party dependencies. The release contains only the current UX project,
not legacy V4 sources or deprecated long-campaign planning documents.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT.parent / f"{ROOT.name}.zip"
EXCLUDE_PARTS = {".git", ".godot", "__pycache__", "docs/archive", ".DS_Store"}
EXCLUDE_NAMES = {"CODEX_HANDOFF_ORIGINAL.md", "MIGRATION_FROM_XK.md"}


def included(path: Path) -> bool:
    rel = path.relative_to(ROOT)
    if any(p in EXCLUDE_PARTS for p in rel.parts) or path.name in EXCLUDE_NAMES:
        return False
    return rel.as_posix() not in {"docs/archive"} and not path.name.endswith((".pyc", "~"))


def main() -> None:
    subprocess.run([sys.executable, str(ROOT / "tools/check_project.py")], check=True)
    files = sorted(p for p in ROOT.rglob("*") if p.is_file() and included(p))
    if not files:
        raise RuntimeError("No files to package")
    expected = {f"{ROOT.name}/{p.relative_to(ROOT).as_posix()}" for p in files}
    with ZipFile(OUTPUT, "w", compression=ZIP_DEFLATED, compresslevel=8) as zf:
        for path in files:
            zf.write(path, f"{ROOT.name}/{path.relative_to(ROOT).as_posix()}")
    with ZipFile(OUTPUT) as zf:
        packaged = set(zf.namelist())
        if expected != packaged:
            raise RuntimeError(f"Archive differs from source: missing={expected-packaged}, extra={packaged-expected}")
        if zf.testzip() is not None:
            raise RuntimeError("Archive CRC error")
        if any("docs/archive/" in name or "CODEX_HANDOFF_ORIGINAL" in name for name in packaged):
            raise RuntimeError("Archive still contains retired documents")
    checksum = hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
    print(f"PASS: archive verified, {len(files)} files, {OUTPUT.stat().st_size:,} bytes")
    print(f"File: {OUTPUT}")
    print(f"SHA256: {checksum}")
    print("Note: Godot engine parser and GUI tests are not available in this environment")


if __name__ == "__main__":
    main()
