"""Stage a reviewed Polestar data commit, validate it, then update local inputs.

This does not discover a fresh data source or publish anything. Read the guide.
"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from datetime import date
import argparse, hashlib, json, re, tempfile, urllib.request
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser()
p.add_argument('--commit',required=True,help='Full reviewed Polestar commit SHA')
p.add_argument('--expect-snapshot',required=True,help='Data date declared by that commit, YYYY-MM-DD')
p.add_argument('--reviewed-licenses',action='store_true',required=True,help='Confirm you reviewed the upstream license and third-party notices')
args=p.parse_args()
if not re.fullmatch(r'[a-fA-F0-9]{40}',args.commit): p.error('Use a full 40-character commit SHA, not main/latest.')
date.fromisoformat(args.expect_snapshot)
inputs={'Forever.lua':'addon/Polestar_ItemDB/Forever.lua','Items.lua':'addon/Polestar_ItemDB/Items.lua','LICENSE':'LICENSE','LICENSE-DATA.txt':'addon/Polestar_ItemDB/LICENSE-DATA.txt','THIRD_PARTY.md':'THIRD_PARTY.md','navigation/entrances.json':'data/codex/entrances.json'}
def fetch(pair):
    name,remote=pair; url=f'https://raw.githubusercontent.com/fitzforge/polestar/{args.commit}/{remote}'
    request=urllib.request.Request(url,headers={'User-Agent':'UpgradeCrossroads-data-maintenance'})
    with urllib.request.urlopen(request,timeout=30) as r: data=r.read(8_000_001)
    if len(data)>8_000_000: raise ValueError(f'{name}: input unexpectedly exceeds 8 MB')
    return name,url,data
with ThreadPoolExecutor(max_workers=4) as pool: fetched=list(pool.map(fetch,inputs.items()))
blobs={name:data for name,_,data in fetched}
text=blobs['Forever.lua'].decode('utf-8')
match=re.search(r'generated\s*=\s*"(\d{4}-\d{2}-\d{2})"',text)
if not match or match.group(1)!=args.expect_snapshot: raise SystemExit('Upstream data date does not match --expect-snapshot. No inputs changed.')
notice=blobs['LICENSE-DATA.txt'].decode('utf-8')
if 'MIT License' not in notice or 'Permission is hereby granted' not in notice:
    raise SystemExit('Expected data license notice changed. Review and update the integration; no inputs changed.')
entrances=json.loads(blobs['navigation/entrances.json'])
if not isinstance(entrances.get('entrances'),list): raise SystemExit('Entrance schema changed; no inputs changed.')
lock={'commit':args.commit.lower(),'snapshot':match.group(1),'files':{name:{'url':url,'sha256':hashlib.sha256(data).hexdigest()} for name,url,data in fetched}}
research=ROOT/'research'
with tempfile.TemporaryDirectory(prefix='uc-source-',dir=ROOT) as temp:
    stage=Path(temp)
    for name,_,data in fetched:
        target=stage/name; target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(data)
    for name,_,_ in fetched:
        target=research/name; target.parent.mkdir(parents=True,exist_ok=True); (stage/name).replace(target)
    (research/'ref.txt').write_text(args.commit.lower()+'\n')
    (research/'source-lock.json').write_text(json.dumps(lock,indent=2)+'\n')
print('Updated reviewed local inputs. Next: rebuild, audit, test, review the diff, and live-test. Nothing was published.')
