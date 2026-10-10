"""Check resource links after the 3D cutover. Run from any directory."""
import json
import hashlib
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
model_records = 0
for manifest_path in [ROOT / "assets/models/game/manifest.json", ROOT / "assets/models/clockwork/manifest.json"]:
    if not manifest_path.exists():
        if manifest_path.parent.name == "game":
            errors.append("Missing original game asset manifest")
        continue
    manifest = json.loads(manifest_path.read_text())
    model_records += len(manifest["assets"])
    for asset in manifest["assets"]:
        for key in ("source", "model", "reference"):
            if key == "reference" and not asset[key]:
                continue  # props with no 2D reference art (terrain zones) leave it empty
            target = (ROOT / asset[key]).resolve()
            if not target.is_relative_to(ROOT) or not target.is_file():
                errors.append(f"Asset {asset['id']}: missing {key}: {asset[key]}")
            elif key == "model" and asset.get("sha256"):
                if hashlib.sha256(target.read_bytes()).hexdigest() != asset["sha256"]:
                    errors.append(f"Asset {asset['id']}: model differs from reviewed manifest hash")
for relative in ("scenes/player.tscn", "scenes/enemy.tscn", "scripts/player.gd", "scripts/enemy.gd"):
    if (ROOT / relative).exists():
        errors.append(f"Retired 2D runtime restored: {relative}")
if errors:
    raise SystemExit("\n".join(errors))
print(f"Resource audit passed: {len(sources)} source files and {model_records} model records.")
