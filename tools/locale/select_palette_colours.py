"""Choose one representative colour index from each character's select sprite.

Prefer indices with six distinct colours, then frequent sprite colours that
change across the palettes, avoiding shared skin/outline colours.
Run from the repo root; only data/select-palettes.lton is generated.
"""
from collections import Counter
from pathlib import Path
import re
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
NAMES = ['ゆい', 'はるか', 'リリス', 'ルナ', 'くるみ', 'サキ', 'かえで', 'ナタリア', 'えり', 'あやね']


def main():
    lines = ['# Select swatches: tools/locale/select_palette_colours.py',
             '# One changing sprite index from the select sprite, six palette rows.']
    for name in NAMES:
        folder = ROOT / 'assets/characters' / name
        script = (ROOT / 'data/characters' / name / 'portrait.lton').read_text(encoding='utf-8')
        listing = (ROOT / 'data/characters' / name / 'images.lton').read_text(encoding='utf-8')
        entries = [l for l in listing.splitlines() if l.startswith('{') or l.startswith('nil^')]
        # The root portrait is an invisible 1x1 control image. Use the first
        # full-size indexed portrait/body image reached by its object scripts.
        image = next(int(n) for n in re.findall(r'\{ "I", (\d+),', script)
                     if int(n) < len(entries) and 'format = "indexed"' in entries[int(n)]
                     and int(re.search(r'width = (\d+)', entries[int(n)]).group(1)) >= 60
                     and int(re.search(r'height = (\d+)', entries[int(n)]).group(1)) >= 100)
        entry = entries[image]
        file = re.search(r'(?:file|shared|asset) = "([^"]+)"', entry)
        if 'shared =' in entry:
            source = ROOT / 'assets/shared' / file.group(1)
        elif 'asset =' in entry:
            source = ROOT / file.group(1)
        else:
            source = folder / file.group(1)
        raw = source.read_bytes()
        if source.suffix != '.dds':
            raise ValueError(f'Expected indexed select sprite: {source}')
        counts = Counter(raw[128:])
        palette = Image.open(folder / 'palettes.png').convert('RGBA')
        def score(index):
            rows = [palette.getpixel((index, n)) for n in range(6)]
            if any(c[3] == 0 for c in rows):
                return (-1, -1)
            spread = sum(max(c[k] for c in rows) - min(c[k] for c in rows) for k in range(3))
            distinct = len(set(c[:3] for c in rows))
            return (distinct, counts[index] * spread)
        index = max(counts, key=score)
        colours = [palette.getpixel((index, n))[:3] for n in range(6)]
        values = ', '.join('{ ' + ', '.join(f'{v / 255:.6f}' for v in c) + ' }' for c in colours)
        lines.append(f'["{name}"] = {{ {values} }}, # palette index {index}')
        print(name, index, colours)
    (ROOT / 'data/select-palettes.lton').write_text('\n'.join(lines) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
