"""Rebuild the full-colour 256-unit item illustrations, exported at 384px in Godot.

Geometry is curated by object motif, with item-specific inlays/colour and fittings.
No external images, fonts, SVG use/symbol features or raster filters are required.
"""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'scripts/registries/items/items_v3.gd').read_text(encoding='utf-8')
rows = json.loads(source.split('const ROWS: Array = ', 1)[1].split('\n\nstatic func', 1)[0])
study = (ROOT / 'doc/plans/shop-layout-study.html').read_text(encoding='utf-8')
defs = re.search(r'<defs>(.*?)<g id="bolt">', study, re.S)[1]
bolt = '<circle r="4.7" fill="url(#gold)" stroke="#77592e"/><path d="M-2 0h4" stroke="#635233"/>'
motifs = {}
for name in ['barrel', 'capacitor', 'charge']:
    body = re.search(r'<symbol id="'+name+r'"[^>]*>(.*?)</symbol>', study, re.S)[1]
    body = re.sub(r'<use href="#bolt" x="([^"]+)" y="([^"]+)"/>',lambda m: '<g transform="translate('+m[1]+' '+m[2]+')">'+bolt+'</g>',body)
    motifs[name] = body
motifs['magnet'] = '''<path d="M54 60h39v83q0 34 28 34t28-34V60h39v85q0 66-67 66t-67-66z" fill="url(#coral)" stroke="#5c3435" stroke-width="4"/><path d="M54 60h39v36H54zm95 0h39v36h-39z" fill="url(#steel)" stroke="url(#gold)" stroke-width="5"/><path d="M65 106v37q0 53 56 53" fill="none" stroke="#ffd2a3" stroke-width="4" opacity=".7"/><path d="M108 65l-10 25 15-4-7 21 26-35-16 4 12-21z" fill="url(#gold)"/>'''
motifs['shield'] = '''<path d="M121 28l77 28-9 96q-17 36-68 63-52-27-69-63l-8-96z" fill="url(#gold)" stroke="#705334" stroke-width="4"/><path d="M121 42l62 23-7 82q-19 34-55 53-37-19-56-53l-7-82z" fill="url(#teal)" stroke="#8adccb" stroke-width="2"/><path d="M120 50v139M66 77l111 1" stroke="#0e4b58" stroke-width="4"/><path d="M107 92h27v24h24v27h-24v24h-27v-24H83v-27h24z" fill="url(#steel)" stroke="url(#gold)" stroke-width="3"/><circle cx="73" cy="69" r="5" fill="#f6d992"/><circle cx="169" cy="69" r="5" fill="#f6d992"/>'''
motifs['gear'] = '''<path d="M96 34h48l5 24 21 13 25-9 24 40-19 16v24l19 17-24 39-25-8-21 12-5 24H96l-5-24-21-12-25 8-23-39 18-17v-24l-18-16 23-40 25 9 21-13z" fill="url(#gold)" stroke="#7f5c39" stroke-width="4"/><circle cx="120" cy="130" r="65" fill="url(#teal)" stroke="#a9e4d5" stroke-width="3"/><circle cx="120" cy="130" r="42" fill="url(#steel)" stroke="url(#gold)" stroke-width="9"/><circle cx="120" cy="130" r="25" fill="#0d2633"/><path d="M118 106l15 10v28l-15 10-15-10v-28z" fill="url(#coral)"/><path d="M64 105q22-56 74-32" fill="none" stroke="#d5f4d4" stroke-width="4" opacity=".6"/>'''
motifs['lens'] = '''<g transform="rotate(-28 120 120)"><path d="M46 73h137v100H46z" fill="url(#teal)" stroke="#103845" stroke-width="4"/><path d="M68 75v96m72-96v96" stroke="url(#gold)" stroke-width="14"/><path d="M73 174h60v26H73z" fill="url(#steel)"/><ellipse cx="183" cy="123" rx="32" ry="58" fill="url(#gold)" stroke="#68563a" stroke-width="3"/><ellipse cx="183" cy="123" rx="25" ry="47" fill="#062532" stroke="#8beed8" stroke-width="3"/><ellipse cx="181" cy="122" rx="18" ry="37" fill="url(#teal)"/><path d="M173 93q17-13 22 19" fill="none" stroke="#d1ffee" stroke-width="6"/><path d="M42 92H26v61h16" fill="url(#coral)"/></g>'''
motifs['weight'] = '''<g transform="rotate(30 120 120)"><rect x="110" y="109" width="24" height="99" rx="8" fill="url(#gold)" stroke="#745333" stroke-width="4"/><path d="M106 161h33m-33 12h33m-33 12h33" stroke="#214450" stroke-width="8"/><path d="M48 54l20-20h106l22 20v66l-22 22H68l-20-22z" fill="url(#steel)" stroke="url(#gold)" stroke-width="5"/><path d="M75 42h93v90H75z" fill="url(#teal)"/><path d="M92 55v63m18-63v63m18-63v63m18-63v63" stroke="#90dccc" stroke-width="4"/><circle cx="61" cy="86" r="7" fill="url(#coral)"/><circle cx="183" cy="86" r="7" fill="url(#coral)"/></g>'''
motifs['coil'] = '''<path d="M46 183l79-22 72 27-77 25z" fill="url(#gold)"/><path d="M110 62h24v119h-24z" fill="url(#steel)"/><path d="M82 83q43-25 78 0t-78 24 78 24-78 25 78 24" fill="none" stroke="#654227" stroke-width="18"/><path d="M82 80q43-25 78 0t-78 24 78 24-78 25 78 24" fill="none" stroke="url(#gold)" stroke-width="12"/><ellipse cx="122" cy="55" rx="36" ry="25" fill="url(#teal)" stroke="#81ecdb" stroke-width="4"/><path d="M124 15l-14 19 17-3-8 15 20-19-15 3z" fill="#9cf8e4"/>'''
motifs['blueprint'] = '''<path d="M40 54l152-21 11 163-154 21z" fill="#213c49" stroke="url(#gold)" stroke-width="9"/><path d="M60 80l125-17M62 108l125-17M65 136l125-17M67 164l125-17M81 63l11 131M113 58l11 131M145 53l11 131" stroke="#3d6571" stroke-width="2"/><path d="M82 146v-40l43-30 40 21v42l-41 31zM82 106l43 22 40-31m-40 31v42" fill="#206369" stroke="#b1f3d7" stroke-width="4"/><path d="M73 195l97-15" stroke="#e5b86f" stroke-width="5"/>'''
motifs['engine'] = '''<path d="M38 89l35-35h99l32 35v90l-32 21H70l-32-21z" fill="url(#teal)" stroke="url(#gold)" stroke-width="5"/><path d="M55 71h134v47H55z" fill="url(#steel)"/><path d="M73 73v44m20-44v44m20-44v44m20-44v44m20-44v44m20-44v44" stroke="#173b46" stroke-width="8"/><circle cx="121" cy="158" r="30" fill="url(#gold)"/><circle cx="121" cy="158" r="19" fill="#193c45"/><path d="M120 131l-11 25 15-4-10 25 23-29-16 3 11-20z" fill="#80eed2"/><path d="M40 136H24v38h17m162-38h15v38h-16" fill="url(#coral)"/>'''
motifs['orb'] = '''<path d="M60 178l62-18 63 23v22H61z" fill="url(#steel)" stroke="url(#gold)" stroke-width="4"/><circle cx="121" cy="111" r="62" fill="url(#teal)" stroke="#9deed5" stroke-width="4"/><ellipse cx="121" cy="111" rx="34" ry="87" fill="none" stroke="url(#gold)" stroke-width="10" transform="rotate(40 121 111)"/><ellipse cx="121" cy="111" rx="39" ry="83" fill="none" stroke="url(#gold)" stroke-width="7" transform="rotate(-40 121 111)"/><path d="M93 90q28-22 52 0t-50 26 45 29" stroke="#cfffea" stroke-width="3" fill="none"/>'''
groups = {
 'magnet':['scrap_magnet'], 'shield':['reinforced_hull','heavy_plating','last_stand','elite_forces'],
 'barrel':['polished_barrels','dense_rounds','piercing_rounds'], 'lens':['extended_barrel','overwatch_optics'],
 'gear':['quick_loader','rapid_coolant','killzone_bat','whirlwind_frame'],
 'capacitor':['budget_capacitor','capacitor_bank','faulty_wiring','superconductors'],
 'charge':['blast_charges','cluster_warheads','plasma_capacitor'], 'weight':['weighted_bat','spiked_bat','hardpoint','concrete_footings'],
 'coil':['static_grounding','arc_rod','storm_conductor'], 'engine':['tracked_chassis','overdrive_engine','heavy_hauler'],
 'orb':['reactor_overload','glass_cannon_core','elemental_conduit'],
 'blueprint':['compact_design','mass_production','ion_doctrine','plasma_doctrine','voltage_doctrine','bat_doctrine','army_doctrine','mono_type_mastery','quality_over_quantity'],
}
groups['barrel'] += ['opening_salvo']
groups['gear'] += ['return_address', 'follow_through']
groups['lens'] += ['slipstream_fletching']
groups['charge'] += ['cinder_reserve']
groups['coil'] += ['arc_insurance']
groups['weight'] += ['counterweight']
groups['engine'] += ['victory_lap']
groups['shield'] += ['rescue_beacon']
groups['capacitor'] += ['reserve_battery']
groups['orb'] += ['close_partnership']
lookup = {id: (motif, i) for motif, ids in groups.items() for i,id in enumerate(ids)}
assert set(lookup) == {r['id'] for r in rows}
out = ROOT / 'assets/ui/items'; out.mkdir(parents=True, exist_ok=True)
for row in rows:
    motif, variant = lookup[row['id']]
    body = motifs[motif]
    # Variations retain the object silhouette while changing material colors.
    if variant % 3 == 1: body = body.replace('url(#teal)', 'url(#coral)')
    if variant % 3 == 2: body = body.replace('url(#coral)', 'url(#teal)').replace('url(#teal)', 'url(#steel)')
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="384" height="384" viewBox="0 0 240 240"><defs>{defs}</defs><ellipse cx="120" cy="212" rx="77" ry="12" fill="#020d15" opacity=".3"/>{body}</svg>'
    (out/(row['id']+'.svg')).write_text(svg,encoding='utf-8')
print(f'Wrote {len(rows)} full-colour item illustrations.')
