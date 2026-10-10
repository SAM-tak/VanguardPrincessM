import pathlib,subprocess,os,json,importlib,re,sys
root=pathlib.Path.cwd(); a=importlib.import_module('remote-memory-audit'); template=(root/'build/gc-tuning-template.lh').read_text(encoding='utf-8-sig');entry=root/'.gc-tuning.lh'
configs=[tuple(map(int,s.split(','))) for s in sys.argv[1:]] or [(200,200,10),(150,400,10),(120,800,10)]
for growth,mul,size in configs:
 label=f'{growth}-{mul}-{size}';entry.write_text(template.replace('GROWTH',str(growth)).replace('STEPMUL',str(mul)).replace('STEPSIZE',str(size)),encoding='utf-8')
 env=os.environ.copy();env.pop('LHATOVE_GC_STATS',None)
 p=subprocess.Popen(['C:/Users/Owner/source/repos/lhat-love/build/love/Release/lovec.exe','--no-error-screen',str(entry)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,encoding='utf-8',errors='replace',env=env)
 print('RUN',label,'PID',p.pid,flush=True);records=[];bins={};timing={}
 try:
  with (root/f'build/gc-tuning-{label}.log').open('w',encoding='utf-8') as f:
   for line in p.stdout:
    f.write(line)
    if line.startswith('SAMPLE'):
     v=dict(label=line.split()[1],**a.memory(p.pid));v.update(dict(re.findall(r'(\w+)=(\S+)',line)));records.append(v)
     if v['label']!='battle' or int(v['tick'])%900==0:print(label,v,flush=True)
    elif line.startswith('TIME'):timing=dict(re.findall(r'(\w+)=(\S+)',line))
    elif line.startswith('BIN'):
     _,b,n=line.split();bins[int(b)]=int(n)
    elif 'error:' in line:print(line.strip(),flush=True)
  code=p.wait();print('EXIT',label,code,flush=True)
 finally:
  if p.poll() is None:p.terminate();p.wait()
  entry.unlink(missing_ok=True)
 result=dict(config=[growth,mul,size],records=records,timing=timing,bins=bins)
 if records and timing:
  n=sum(bins.values());ordered=sorted(bins);percentiles={}
  for q in [.5,.95,.99]:
   at=0
   for b in ordered:
    at+=bins[b]
    if at>=n*q:percentiles[str(q)]=(b+1)/10;break
  result['summary']=dict(peakWS=max(r['workingSet'] for r in records),peakPrivate=max(r['private'] for r in records),meanMs=float(timing['sum'])/int(timing['frames']),maxMs=float(timing['max']),percentiles=percentiles,over16ms=sum(v for k,v in bins.items() if k>=167))
  print('SUMMARY',label,result['summary'],flush=True)
 (root/f'build/gc-tuning-{label}.json').write_text(json.dumps(result,indent=2))
 if code:break
