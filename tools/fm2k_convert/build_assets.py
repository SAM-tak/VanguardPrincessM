"""Build release-compatible assets from the original SFX/7z or game directory.

Only media is generated. Shipped game definitions are never regenerated.
"""
import argparse
from collections import defaultdict
import json
import locale
import os
from pathlib import Path, PurePosixPath
import sys
import tempfile
import zipfile
import py7zr
from PIL import Image

from extract_original import extract
from raw_media import media
from share_assets import content_key, dds_pixels

DEFAULT_RECIPE = Path(__file__).with_name('assets-recipe.json')


def japanese():
    """Follow the OS display language: Windows UI language, else the locale."""
    if sys.platform == 'win32':
        try:
            import ctypes
            return ctypes.windll.kernel32.GetUserDefaultUILanguage() & 0x3ff == 0x11
        except (AttributeError, OSError):
            pass
    for name in ('LC_ALL', 'LC_MESSAGES', 'LANG'):
        if os.environ.get(name):
            return os.environ[name].lower().startswith('ja')
    return (locale.getlocale()[0] or '').lower().startswith(('ja', 'japanese'))


MESSAGES = {
    'usage': ('Drag and drop vanpri108.exe (or the extracted original folder) onto BuildAssets.',
              'vanpri108.exe（または解凍済みの原作フォルダ）を BuildAssets にドラッグ＆ドロップしてください。'),
    'close': ('Press Enter to close.', 'Enter キーで閉じます。'),
    'exists': ('{path} already exists. Delete or rename it, then try again.',
               '{path} は既に存在します。削除するか名前を変えてから、やり直してください。'),
    'no_game': ('Expected one original game (.kgt) in {path}, found {count}.',
                '{path} に原作のゲームデータ（.kgt）が1つだけ必要ですが、{count} 個見つかりました。'),
    'missing': ('{count} assets could not be reconstructed; this is not the expected original game version. Examples: {examples}',
                '{count} 個の素材を作れませんでした。対応する版の原作ではありません。例: {examples}'),
    'built': ('Built {count} verified files: {path}', '{count} 個の素材を確認して作成しました: {path}'),
    'failed': ('Asset build failed: {error}', '素材の作成に失敗しました: {error}'),
}


def message(key, **values):
    return MESSAGES[key][japanese()].format(**values)


def write_recipe(assets, destination):
    """Developer operation: capture the current organized media layout."""
    groups = defaultdict(list)
    for path in sorted(assets.rglob('*')):
        if not path.is_file():
            continue
        if path.name == 'palettes.png' or (path.parent.name in ('images', 'sounds') and path.suffix in ('.png', '.dds', '.wav')):
            groups[content_key(path)].append(path.relative_to(assets).as_posix())
    destination.write_text(json.dumps({'version': 1, 'media': dict(sorted(groups.items()))}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(f'Recipe: {sum(map(len, groups.values()))} files, {len(groups)} unique contents')


def load_recipe(path):
    recipe = json.loads(path.read_text(encoding='utf-8'))
    if recipe.get('version') != 1 or not recipe.get('media'):
        raise ValueError('Unsupported or empty assets recipe')
    seen = set()
    for key, paths in recipe['media'].items():
        if len(key) != 40 or any(c not in '0123456789abcdef' for c in key) or not paths:
            raise ValueError('Invalid recipe content key')
        for value in paths:
            p = PurePosixPath(value)
            if p.is_absolute() or '\\' in value or ':' in value or any(part in ('', '.', '..') for part in value.split('/')):
                raise ValueError(f'Invalid output path: {value}')
            if value.casefold() in seen:
                raise ValueError(f'Duplicate output path: {value}')
            seen.add(value.casefold())
    return recipe['media']


def game_directory(source):
    games = sorted(source.rglob('*.kgt'))
    if len(games) != 1:
        raise ValueError(message('no_game', path=source, count=len(games)))
    return games[0].parent


def write_archive(directory, archive):
    """Store (not deflate) every file: images are read often, and one archive
    avoids per-file anti-malware scans that stall first loads on Windows."""
    files = sorted(p for p in directory.rglob('*') if p.is_file())
    with zipfile.ZipFile(archive, 'x', zipfile.ZIP_STORED) as z:
        for path in files:
            z.write(path, path.relative_to(directory).as_posix())
    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        if names != [p.relative_to(directory).as_posix() for p in files]:
            raise ValueError('Archive entries do not match generated assets')
        for path, name in zip(files, names):
            if z.read(name) != path.read_bytes():
                raise ValueError(f'Archive content mismatch: {name}')


def build(source, destination, recipe_path=DEFAULT_RECIPE):
    source = Path(source).resolve(strict=True)
    destination = Path(destination).absolute()
    if destination.exists() or destination.is_symlink():
        raise FileExistsError(message('exists', path=destination))
    required = load_recipe(recipe_path)
    remaining = dict(required)
    parent = destination.parent.resolve()
    parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='vanpri-assets-', dir=parent) as temporary:
        staging = Path(temporary).resolve()
        assert staging.parent == parent
        original = source
        if source.is_file():
            original = staging / 'original'
            extract(source, original)
        game = game_directory(original)
        output = staging / 'assets'
        output.mkdir()
        files = sorted(p for p in game.iterdir() if p.suffix.lower() in ('.kgt', '.player', '.stage', '.demo'))
        for i, path in enumerate(files):
            print(f'[{i + 1}/{len(files)}] {path.name}', flush=True)
            for key, payload in media(path):
                targets = remaining.pop(key, [])
                for relative in targets:
                    target = output / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    if isinstance(payload, bytes) and payload.startswith(b'DDS ') and target.suffix == '.png':
                        w, h, pixels = dds_pixels(payload)
                        Image.frombytes('L', (w, h), pixels).save(target, optimize=True)
                    elif isinstance(payload, bytes):
                        target.write_bytes(payload)
                    else:
                        payload.save(target, optimize=True)
                    if content_key(target) != key:
                        raise ValueError(f'Generated content mismatch: {relative}')
        if remaining:
            missing = [p for paths in remaining.values() for p in paths]
            raise ValueError(message('missing', count=len(missing), examples=missing[:10]))
        if destination.suffix.lower() == '.zip':
            # Loose files stay in the temporary directory and are removed with it.
            archive = staging / 'assets.zip'
            write_archive(output, archive)
            output = archive
        if destination.exists():
            raise FileExistsError(f'Output appeared during build: {destination}')
        output.rename(destination)
    print(message('built', count=sum(map(len, required.values())), path=destination), flush=True)


def default_destination():
    """assets.zip beside the frozen BuildAssets executable, which ships in the game folder."""
    base = Path(sys.executable).parent if getattr(sys, 'frozen', False) else Path.cwd()
    return base / 'assets.zip'


def run(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='vanpri108.exe, .7z, or extracted original directory')
    parser.add_argument('destination', type=Path, nargs='?', help='New assets.zip (or assets directory; recipe JSON with --write-recipe). Default: assets.zip beside BuildAssets')
    parser.add_argument('--recipe', type=Path, default=DEFAULT_RECIPE)
    parser.add_argument('--write-recipe', action='store_true', help='Developer only: source is an organized assets directory')
    args = parser.parse_args(argv)
    try:
        if args.write_recipe:
            if args.destination is None:
                parser.error('--write-recipe needs a destination')
            write_recipe(args.source, args.destination)
        else:
            build(args.source, args.destination or default_destination(), args.recipe)
    except (OSError, ValueError, py7zr.exceptions.ArchiveError) as error:
        parser.exit(1, message('failed', error=error) + '\n')


def main():
    # Dropping a file or folder onto the executable passes it as the only
    # argument and opens a console that closes on exit, so keep it open.
    dropped = getattr(sys, 'frozen', False) and len(sys.argv) <= 2
    if dropped and len(sys.argv) == 1:
        print(message('usage'))
    try:
        if not dropped or len(sys.argv) == 2:
            run(sys.argv[1:])
    finally:
        if dropped:
            try:
                input(message('close'))
            except EOFError:
                pass


if __name__ == '__main__':
    main()
