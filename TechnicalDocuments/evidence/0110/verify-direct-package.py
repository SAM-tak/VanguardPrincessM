from pathlib import Path
import zipfile, hashlib
root=Path.cwd()
compiled=root/'build/package/compiled'
archive=root/'build/VanguardPrincessM.love'
with zipfile.ZipFile(archive) as z:
    names=z.namelist()
    assert len(names)==len(set(names))
    old={p.relative_to(root/'build/parallel-baseline').as_posix() for p in (root/'build/parallel-baseline').rglob('*') if p.is_file()}
    assert {n for n in names if not n.endswith('/')}==old
    units=assets=0
    for n in names:
        if n.endswith('/'):
            assert (root/n).is_dir()
            continue
        if n.endswith(('.lh','.lton')):
            expected=compiled/n
            units+=1
        else:
            expected=root/n
            assets+=1
        assert hashlib.sha256(z.read(n)).digest()==hashlib.sha256(expected.read_bytes()).digest(), n
    print(f'PASS: {units} compiled files, {assets} original assets; old file manifest matches; all ZIP bytes verified')
exe=root/'dist/VanguardPrincessM/VanguardPrincessM.exe'
engine=Path('C:/Users/Owner/source/repos/lhat-love/build-vmonly-shipping/love/Release/love.exe')
with exe.open('rb') as f:
    assert f.read(engine.stat().st_size)==engine.read_bytes()
    digest=hashlib.file_digest(f,'sha256').digest()
with archive.open('rb') as f:
    assert digest==hashlib.file_digest(f,'sha256').digest()
print('PASS: fused executable = shipping VM + verified archive')
