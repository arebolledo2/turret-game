"""Copy one frozen, reviewed harness export into the separate Clockwork asset collection.

Run from anywhere: python tools/promote_clockwork_asset.py ion --iteration 2
This checks the export contract; visual acceptance is the caller's responsibility.
"""
import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path

game = Path(__file__).resolve().parents[1]
repo = game.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('key', choices=['ion','plasma','tesla','shock','melee','basic','fast','tank','charger','hero','dropbox','exploder','machine_gun','scatter','saber','gatling','crossfire','siege','bow','flamethrower','bowling','gunblade'])
parser.add_argument('--iteration', required=True, type=int)
args = parser.parse_args()
key = args.key
run = repo / f'3d-eval/runs/cp_{key}-v1'
validation = run / f'renders/iter{args.iteration:02}/validate.json'
result = json.loads(validation.read_text())
if not result['passed']:
    raise SystemExit('Export contract has not passed.')
glb = run / f'cp_{key}.glb'
builder = run / f'build_cp_{key}.py'
if not glb.is_file() or not builder.is_file():
    raise SystemExit('Missing final GLB or deterministic builder.')
source_dir = game / f'art-source/clockwork-pop/{key}'
source_dir.mkdir(parents=True,exist_ok=True)
model_dir = game / 'assets/models/clockwork'
model_dir.mkdir(parents=True,exist_ok=True)
destination = model_dir / glb.name
shutil.copy2(glb,destination)
for file in run.iterdir():
    if file.is_file() and file.suffix in ('.py','.png','.blend','.md','.json'):
        shutil.copy2(file,source_dir/file.name)
(source_dir/'validate.json').write_text(validation.read_text(),encoding='utf-8',newline='\n')
config = run / 'contract.json'
if not config.exists():
    config = repo / f'3d-eval/harness/subjects/cp_{key}_soft.json'
shutil.copy2(config,source_dir/'contract.json')
reference = repo / f'3d-eval/ref/cp_{key}.png'
if reference.is_file():
    refs = game / 'art-source/clockwork-pop/references'
    refs.mkdir(parents=True, exist_ok=True)
    shutil.copy2(reference, refs / f'{key}.png')
import_file = destination.with_suffix('.glb.import')
if not import_file.exists():
    original = (game/'assets/models/game/spider_drone.glb.import').read_text()
    original = original.replace('assets/models/game/spider_drone.glb',f'assets/models/clockwork/{glb.name}')
    original = original.replace('spider_drone',f'cp_{key}')
    original = re.sub(r'^uid=.*\n','',original,flags=re.M)
    import_file.write_text(original)
manifest_path = model_dir/'manifest.json'
manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {'assets':[]}
entry = {'id':key,'source':str((source_dir/builder.name).relative_to(game)).replace('\\','/'),
         'model':str(destination.relative_to(game)).replace('\\','/'),
         'reference':f'art-source/clockwork-pop/references/{key}.png',
         'sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'triangles':result['triangles'],
         'meshes':result['mesh_objects'],'materials':result['materials'],'iteration':args.iteration}
manifest['assets']=[a for a in manifest['assets'] if a['id']!=key]+[entry]
manifest_path.write_text(json.dumps(manifest,indent=2),encoding='utf-8',newline='\n')
preview = run/f'renders/iter{args.iteration:02}/compare.png'
report=game/'doc/art/clockwork-pop'
(report/'previews').mkdir(exist_ok=True)
shutil.copy2(preview,report/'previews'/f'{key}.png')
progress=json.loads((report/'progress.json').read_text())
asset=next((a for a in progress['assets'] if a['key']==key), None)
if asset is None:
    asset={'key':key,'name':key.replace('_',' ').title(),'status':'review'}
    progress['assets'].append(asset)
asset.update(status='review',preview=f'previews/{key}.png',metrics=f"{entry['triangles']:,} triangles · {entry['meshes']} meshes · {entry['materials']} materials")
progress['events'].append({'stage':'Export: '+key,'text':f"Reviewed harness iteration {args.iteration}; contract passed. Copied source and export into game collection. Godot import and runtime review remain pending."})
(report/'progress.json').write_text(json.dumps(progress,indent=2),encoding='utf-8',newline='\n')
print(json.dumps(entry,indent=2))
