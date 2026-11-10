"""Prepare game-compatible TGA textures from the approved logo master."""
from pathlib import Path
from io import BytesIO
import argparse
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(); p.add_argument('--check',action='store_true'); args=p.parse_args()
source=Image.open(ROOT/'art/UpgradeCrossroads-Round.png').convert('RGBA')
for name,size in [('IconRound',64),('LogoRound',256)]:
    output=ROOT/'UpgradeCrossroads/Media'/f'{name}.tga'
    buffer=BytesIO(); source.resize((size,size),Image.Resampling.LANCZOS).save(buffer,format='TGA',compression=None)
    if args.check:
        assert output.read_bytes()==buffer.getvalue(),f'Rebuild changed texture: {output.name}'
    else:
        output.parent.mkdir(exist_ok=True); output.write_bytes(buffer.getvalue())
print('Both logo textures match the approved source.' if args.check else 'Prepared IconRound.tga and LogoRound.tga.')
