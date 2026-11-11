"""Render all exported Lua layouts and fail on fixed-height text overflow."""
from pathlib import Path
import subprocess,sys,json
ROOT=Path(__file__).resolve().parents[1]
views=[('layout.json','UpgradeCrossroads/PREVIEW.png'),('layout-guide.json','UpgradeCrossroads/GUIDE_PREVIEW.png')]
views += [(f'layout-{v}-min.json',f'research/{v}-minimum.png') for v in ['planner','guide','hunts','editor','help','appearance']]
views += [(f'layout-{v}.json',f'research/{v}.png') for v in ['readable-small','readable-largest','appearance','guide-readable']]
views += [(f'layout-{v}-spec-min.json',f'research/{v}-spec-minimum.png') for v in ['hunter','warlock']]
views += [('layout-journal.json','UpgradeCrossroads/PREVIEW.png')]
views += [(f'layout-journal-{v}.json',f'research/journal-{v}.png') for v in ['min-large','filtered','removed']]
reports=[]
for fixture,output in views:
    subprocess.run([sys.executable,str(ROOT/'tools/render_preview.py'),'--strict','--layout','research/'+fixture,'--output',output],cwd=ROOT,check=True,stdout=subprocess.DEVNULL)
    report=json.loads((ROOT/'research'/f'layout-review-{Path(fixture).stem}.json').read_text())
    reports.append(dict(fixture=fixture,**report))
(ROOT/'research/layout-review.json').write_text(json.dumps(dict(mode='offline preview; substitute fonts and approximate native skins',layouts=reports),indent=2)+'\n')
print(f'{len(views)} offline layouts pass strict text checks.')
