"""Render the committed Clockwork Pop progress/history as a standalone HTML artifact."""
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'doc/art/clockwork-pop'
data = json.loads((REPORT / 'progress.json').read_text(encoding='utf-8'))
esc = html.escape
cards = []
for asset in data['assets']:
    preview = asset.get('preview', asset['reference'])
    concept_link = f'<a href="http://localhost:3000/editor/{esc(asset["image_id"])}">Original concept</a> · ' if asset.get('image_id') else 'Created directly in 3D · '
    cards.append(f'''<article data-status="{esc(asset['status'])}">
    <a href="{esc(preview)}"><img src="{esc(preview)}" alt="{esc(asset['name'])}"></a>
    <div class="body"><span class="pill">{esc(asset['status'])}</span><h2>{esc(asset['name'])}</h2>
    <p>{esc(asset['notes'])}</p><small>{esc(asset.get('metrics', 'Geometry and runtime checks pending'))}</small>
    <p>{concept_link}<a href="{esc(preview)}">Full preview</a></p></div></article>''')
events = ''.join(f'<li><strong>{esc(e["stage"])}</strong><p>{esc(e["text"])}</p></li>' for e in reversed(data['events']))
checks = ''.join(f'<li><span>{esc(k)}</span><strong>{esc(v)}</strong></li>' for k,v in data['checks'].items())
captures = ''.join(f'<figure><a href="{esc(c["path"])}"><img style="width:100%;border-radius:12px" src="{esc(c["path"])}" alt="{esc(c["caption"])}"></a><figcaption>{esc(c["caption"])}</figcaption></figure>' for c in data.get('captures', []))
motion = ''
if data.get('motion_frames'):
    frames = data['motion_frames']
    motion = f'<section><h2>Sampled motion poses</h2><p>Scrub through imported-model poses: walking, hovering, wing motion, aiming, recoil and carrying. These are sampled poses, not a recording of frame rate.</p><input aria-label="Motion pose" type="range" min="0" max="{len(frames)-1}" value="0" oninput="document.getElementById(\'motion\').src=motionFrames[this.value]" style="width:100%"><img id="motion" style="width:100%" src="{esc(frames[0])}" alt="Animated roster pose"><script>const motionFrames={json.dumps(frames)};</script></section>'
performance = ''
if data.get('performance'):
    p = data['performance']
    rows = ''.join('<tr>' + ''.join(f'<td style="padding:10px">{esc(str(c))}</td>' for c in row) + '</tr>' for row in p['rows'])
    performance = f'<section><h2>Performance comparison</h2><p>{esc(p["method"])}</p><div style="overflow:auto"><table><thead><tr><th>Roster</th><th>Median frame time</th><th>Approx. FPS</th><th>p95 frame time</th></tr></thead><tbody>{rows}</tbody></table></div><p>{esc(p["interpretation"])}</p></section>'
launch = f'<section><h2>Playtest</h2><p>{esc(data["launch"])}</p></section>' if data.get('launch') else ''
page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Clockwork Pop · Playtest progress</title><style>
*{box-sizing:border-box}body{margin:0;background:#111e28;color:#e8eadf;font:16px/1.6 system-ui,sans-serif}main{max-width:1450px;margin:auto;padding:40px 28px}header{border-bottom:1px solid #36505c;padding-bottom:24px}h1{font-size:42px;margin:0}h2{font-size:21px;margin:8px 0}p{color:#c1cfd2}a{color:#72ded0}.eyebrow{color:#eba277;letter-spacing:.12em}nav{display:flex;gap:12px;margin:28px 0;flex-wrap:wrap}button{background:#254452;color:#eef5ef;border:1px solid #48707b;border-radius:30px;padding:10px 18px;cursor:pointer}button.active{background:#b97650;color:#fff}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(275px,1fr));gap:22px}article{border:1px solid #36505c;border-radius:18px;overflow:hidden;background:#1a2d38}article img{width:100%;aspect-ratio:1;object-fit:contain;background:#14232e}.body{padding:20px}.pill{color:#80e4d3;text-transform:uppercase;font-size:12px;letter-spacing:.08em}small{color:#edbc83}section{margin-top:38px}.checks{list-style:none;padding:0;display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:12px}.checks li{padding:16px;background:#213743;border-radius:10px;display:flex;flex-direction:column}.history{border-left:2px solid #568d8a;list-style:none;padding-left:24px}.history li{margin:22px 0}.muted{font-size:14px;color:#9bb2b9} [hidden]{display:none!important}
</style><main><header><div class="eyebrow">ART PRODUCTION / PLAYTEST READINESS</div><h1>Clockwork Pop</h1>
<p>The Clockwork roster and its evolving game visuals. This page records actual progress, decisions and verification; reference images are shown until reviewed 3D previews replace them.</p>
<div class="muted">Branch: BRANCH · Original assets retained · Refresh this file to see newly recorded progress</div></header>
<section><h2>Readiness gates</h2><ul class="checks">CHECKS</ul></section>
<nav aria-label="Filter assets"><button class="active" data-filter="all">All assets</button><button data-filter="queued">Queued</button><button data-filter="building">Building</button><button data-filter="review">Review</button><button data-filter="integrated">Integrated</button><button data-filter="verified">Verified</button></nav>
<div class="grid">CARDS</div><section><h2>In-game review</h2>CAPTURES</section><section><h2>Progress &amp; decisions</h2><ol class="history">EVENTS</ol></section>
<footer class="muted">Source of record: progress.json. Automated checks support, but do not replace, visual and gameplay review.</footer></main>
<script>document.querySelectorAll('button[data-filter]').forEach(b=>b.onclick=()=>{document.querySelectorAll('button').forEach(x=>x.classList.toggle('active',x===b));document.querySelectorAll('article').forEach(a=>a.hidden=b.dataset.filter!=='all'&&a.dataset.status!==b.dataset.filter)});</script></html>'''
page = page.replace('BRANCH',esc(data['branch'])).replace('CHECKS',checks).replace('CARDS',''.join(cards)).replace('EVENTS',events).replace('CAPTURES',captures)
page = page.replace('<nav aria-label=', launch + performance + motion + '<nav aria-label=')
(REPORT/'index.html').write_text(page,encoding='utf-8',newline='\n')
print(REPORT/'index.html')
