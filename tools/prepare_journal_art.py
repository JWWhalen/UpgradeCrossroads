"""Build/check the continuous, power-of-two RGBA journal panorama.

python tools/prepare_journal_art.py [--check]
"""
from pathlib import Path
import argparse
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--check',action='store_true')
args=parser.parse_args()
for name in ('JournalPanorama',):
    source=ROOT/f'art/{name}.png'
    target=ROOT/f'UpgradeCrossroads/Media/{name}.tga'
    with Image.open(source) as image:
        expected=image.convert('RGBA').resize((1024,512),Image.Resampling.LANCZOS)
    if args.check:
        data=target.read_bytes()
        assert len(data)>=18 and data[2]==2 and data[16]==32, f'{name} must be uncompressed 32-bit TGA'
        with Image.open(target) as image:
            assert image.size==(1024,512), f'{name} must be 1024x512'
            assert image.convert('RGBA').tobytes()==expected.tobytes(), f'Rebuild {name} from its source'
        print(f'{name} matches its source: 1024x512 RGBA TGA.')
    else:
        expected.save(target,compression=None)
        print(target)
