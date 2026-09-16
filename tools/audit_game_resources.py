"""Check resource links after the 3D cutover. Run from any directory."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors = []
sources = [ROOT / "project.godot"]
for directory in ("scripts", "scenes", "resources", "tools"):
    sources.extend(p for p in (ROOT / directory).rglob("*") if p.suffix in (".gd", ".tscn", ".tres"))
for source in sources:
    for relative in re.findall(r'["\']res://([^"\'\n]+)["\']', source.read_text(encoding="utf-8-sig")):
        if "%" in relative or "{" in relative:
            continue  # Runtime templates are covered by import/integration tests.
        target = (ROOT / relative).resolve()
        if not target.is_relative_to(ROOT) or not target.exists():
            errors.append(f"{source.relative_to(ROOT)}: missing resource {relative}")
manifest = json.loads((ROOT / "assets/models/game/manifest.json").read_text())
for asset in manifest["assets"]:
    for key in ("source", "model", "reference"):
        if not (ROOT / asset[key]).is_file():
            errors.append(f"Asset {asset['id']}: missing {key}: {asset[key]}")
for relative in ("scenes/player.tscn", "scenes/enemy.tscn", "scripts/player.gd", "scripts/enemy.gd"):
    if (ROOT / relative).exists():
        errors.append(f"Retired 2D runtime restored: {relative}")
if errors:
    raise SystemExit("\n".join(errors))
print(f"Resource audit passed: {len(sources)} source files and {len(manifest['assets'])} model records.")
