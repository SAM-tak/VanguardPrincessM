import os, pathlib, subprocess, time, re, importlib, json, threading
audit=importlib.import_module('remote-memory-audit')

root = pathlib.Path(__file__).resolve().parent.parent
entry = root / '.memory-map-audit.lh'
source = (root/'build/gc-audit.lh').read_text(encoding='utf-8-sig')
source = source.replace('import^love.math', 'import^love.math\nimport^love.graphics')
source = source.replace('import^love.graphics', 'import^love.graphics\nimport^love.filesystem')
source = source.replace('cycles = 3', 'cycles = 1')
source = source.replace('var^idle = 0', '''var^holdUntil = 0
let^snapshot = p^name:string^{
    L^.collectgarbage()
    let^g = love.graphics.getStats()
    print($"SNAPSHOT {name} textures={g.textures} textureBytes={g.texturememory} bufferBytes={g.buffermemory}")
    holdUntil := love.timer.getTime() + 12
}
var^idle = 0''')
source = source.replace('    vp.main.update(0.02)', '    if^love.timer.getTime() < holdUntil { return^ }\n    vp.main.update(0.02)', 1)
source = source.replace('var^holdUntil = 0', 'var^forceCollected = false^\nvar^holdUntil = 0')
source = source.replace('    if^love.timer.getTime() < holdUntil', '    if^!forceCollected and^love.filesystem.exists("build/force-gc.signal") { forceCollected := true^ snapshot("peakgc") }\n    if^love.timer.getTime() < holdUntil', 1)
source = source.replace('print("AUDIT boot collected")', 'print("AUDIT boot collected") snapshot("boot")')
source = source.replace('        phase := 6', '        snapshot($"battle{cycles}") phase := 6')
source = source.replace('if^idle = 30 or^idle = 90 { L^.collectgarbage() print($"AUDIT title cycle={cycles} idle={idle}") }', 'if^idle = 30 { snapshot($"title{cycles}") }')
engine = pathlib.Path('C:/Users/Owner/source/repos/lhat-love/build/love/Release/lovec.exe')
entry.write_text(source, encoding='utf-8')
(root/'build/force-gc.signal').unlink(missing_ok=True)
try:
    with (root/'build/memory-map-audit.log').open('w', encoding='utf-8') as log:
        p = subprocess.Popen([str(engine), '--no-error-screen', str(entry)], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding='utf-8', errors='replace')
        print('PID',p.pid,flush=True)
        def sample_peak():
            samples=[]; captured=False
            while p.poll() is None:
                try:
                    m=audit.memory(p.pid)
                    samples.append({'time':time.time(),**m})
                    if m['private']>1150000000 and not captured:
                        captured=True
                        audit.snapshot(p.pid,root/'build/heap-peak.csv')
                        (root/'build/regions-peak.json').write_text(json.dumps(audit.regions(p.pid)))
                        print('PEAK SNAPSHOT',m,audit.memory(p.pid),flush=True)
                        (root/'build/force-gc.signal').write_text('1')
                except OSError: pass
                time.sleep(0.2)
            (root/'build/memory-map-samples.json').write_text(json.dumps(samples))
        monitor=threading.Thread(target=sample_peak); monitor.start()
        for line in p.stdout:
            log.write(line); log.flush()
            if 'SNAPSHOT ' in line:
                print(line.strip(), flush=True)
                name = re.search(r'SNAPSHOT (\w+)',line)[1]
                out = root/f'build/map-{name}.csv'
                print('before map',audit.memory(p.pid),flush=True)
                for delay in [0, 1, 2]:
                    time.sleep(delay)
                    regions=audit.regions(p.pid)
                    (root/f'build/regions-{name}-{delay}.json').write_text(json.dumps(regions),encoding='utf-8')
                    wc=sum(r['size'] for r in regions if r['protect']&0x400)
                    print('delayed',delay,audit.memory(p.pid),'WC',wc,flush=True)
                audit.snapshot(p.pid,root/f'build/heap-{name}.csv')
                print('after heap',audit.memory(p.pid),flush=True)
                result = subprocess.run([str(root/'build/vmmap/vmmap64.exe'), '-accepteula', '-p', str(p.pid), str(out)], timeout=45, creationflags=subprocess.CREATE_NO_WINDOW)
                print('map',name,result.returncode,out.exists(),audit.memory(p.pid),flush=True)
        print('EXIT',p.wait(),flush=True)
        monitor.join()
finally:
    if 'p' in locals() and p.poll() is None:
        p.terminate(); p.wait()
    entry.unlink(missing_ok=True)
    (root/'build/force-gc.signal').unlink(missing_ok=True)
