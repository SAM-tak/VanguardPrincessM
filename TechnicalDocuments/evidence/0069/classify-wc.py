import pathlib,re,bisect,json,collections
root=pathlib.Path('build')
syms=[]
for l in (root/'linkprobe/love.map').read_text(errors='replace').splitlines():
 m=re.match(r'\s*\w+:\w+\s+(\S+)\s+(000000018[0-9a-fA-F]+)\s',l)
 if m:syms.append((int(m[2],16)-0x180000000,m[1]))
syms.sort(); keys=[v[0] for v in syms]; out=[]
for l in (root/'wc-early-stacks.log').read_text().splitlines():
 m=re.search(r'love\.dll\+([0-9a-f]+)',l)
 if m:
  r=int(m[1],16);i=bisect.bisect_right(keys,r)-1;l=l.split('love.dll+')[0]+syms[i][1]+f'+{r-syms[i][0]}'
 out.append(l)
(root/'wc-early-symbolized.log').write_text('\n'.join(out))
events=[]
for p in '\n'.join(out).split('EVENT ')[1:]:
 m=re.match(r'(\d+) kind=(\d+) status=(\w+) tid=(\d+) base=(\w+) size=(\d+) protect=(\w+)',p)
 if int(m[2])!=9:continue
 stack=[l.strip() for l in p.splitlines()[1:] if 'nvoglv64.dll' not in l]
 category='image' if 'vmaCreateImage' in p else 'buffer' if 'vmaCreateBuffer' in p else 'descriptor' if 'allocateDescriptorSet' in p else 'other'
 events.append(dict(id=int(m[1]),base=int(m[5],16),size=int(m[6]),category=category,stack=stack))
regions=[r for r in json.loads((root/'wc-early-regions.json').read_text()) if r['protect']&0x400]
totals=collections.Counter(); details=[]
for r in regions:
 boundaries={r['base'],r['base']+r['size']}
 for e in events:
  lo=max(r['base'],e['base']);hi=min(r['base']+r['size'],e['base']+e['size'])
  if hi>lo:boundaries.update([lo,hi])
 boundaries=sorted(boundaries)
 for lo,hi in zip(boundaries,boundaries[1:]):
  matches=[e for e in events if e['base']<=lo and e['base']+e['size']>=hi]
  e=matches[-1] if matches else dict(id=-1,category='untraced',stack=[])
  totals[e['category']]+=hi-lo
  details.append(dict(size=hi-lo,event=e['id'],category=e['category'],stack=e['stack']))
print(dict(totals));print('total',sum(totals.values()))
(root/'wc-classified.json').write_text(json.dumps(dict(totals=dict(totals),details=details),indent=2))
for d in details:
 if d['category'] not in ['image']:print(d)
