"""Create the install-only release ZIP used by GitHub/WowUp.

python tools/package_release.py [--tag v0.2.0]
"""
from pathlib import Path
import argparse, hashlib, json, re, zipfile

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--tag')
args=parser.parse_args()
addon=ROOT/'UpgradeCrossroads'
toc_path=addon/'UpgradeCrossroads.toc'
duplicates=[name for name in (toc_path.name,'Core','Data','UI','Media') if (ROOT/name).exists()]
if duplicates:
    parser.error('Install files found at repository root: '+', '.join(duplicates)+'. Use the complete development source tree.')
toc=toc_path.read_text()
version=re.search(r'^## Version:\s*(\S+)',toc,re.M).group(1)
assert re.fullmatch(r'\d+\.\d+\.\d+(?:-[\w.]+)?',version), 'Invalid release version'
bootstrap=(addon/'Core/Bootstrap.lua').read_text()
runtime_version=re.search(r'^XC\.version\s*=\s*"([^"]+)"',bootstrap,re.M)
if not runtime_version or runtime_version.group(1)!=version:
    parser.error(f'Runtime version {runtime_version.group(1) if runtime_version else "missing"} disagrees with TOC version {version}.')
if args.tag and args.tag!='v'+version:
    parser.error(f'Release tag {args.tag} must match {toc_path.relative_to(ROOT)} version v{version}.')
listed=[]
for line in toc.splitlines():
    if line and not line.startswith('#'):
        relative=Path(line.replace('\\','/'))
        assert not relative.is_absolute() and '..' not in relative.parts
        assert (addon/relative).is_file(), f'Missing TOC input: {line}'
        listed.append('UpgradeCrossroads/'+relative.as_posix())
out=ROOT/'dist'; out.mkdir(exist_ok=True)
archive=out/f'UpgradeCrossroads-v{version}-forever.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for path in sorted(addon.rglob('*')):
        if path.is_file(): z.write(path,path.relative_to(ROOT).as_posix())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert all(name.startswith('UpgradeCrossroads/') for name in z.namelist())
    assert all(name in z.namelist() for name in listed)
print(json.dumps({'file':str(archive),'version':version,'bytes':archive.stat().st_size,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest()},indent=2))
