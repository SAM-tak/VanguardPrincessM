import json,sys,struct,hashlib,re,difflib
from pathlib import Path
sys.path.insert(0,str(Path('tools/fm2k_convert').resolve()))
from gen_script import block
from names import official
ROOT=Path('build/update-0117')
def clean(v):
 if isinstance(v,dict):return {k:clean(x) for k,x in v.items() if k not in ('pointer','offset','index')}
 if isinstance(v,list):return [clean(x) for x in v]
 return v
def differences(a,b,path=''):
 if type(a)!=type(b):return [{'path':path,'old':a,'new':b}]
 if isinstance(a,dict):
  out=[]
  for k in sorted(a.keys()|b.keys()):out+=differences(a.get(k),b.get(k),path+'.'+k)
  return out
 if isinstance(a,list):
  if len(a)!=len(b):return [{'path':path+'.length','old':len(a),'new':len(b)}]
  out=[]
  for i,(x,y) in enumerate(zip(a,b)):out+=differences(x,y,f'{path}[{i}]')
  return out
 return [] if a==b else [{'path':path,'old':a,'new':b}]
def runtime(name):
 s=Path(f'data/characters/{name}/script.lton').read_text(encoding='utf-8');out={}
 for part in re.split(r'(?m)^\{ name = ',s)[1:]:
  m=re.search(r'id = (\d+)',part.splitlines()[0]);n=int(m[1])
  out[n]=[json.loads('['+line.strip()[1:-2]+']') for line in part.splitlines()[1:] if line.strip().startswith('{ "')]
 return out
report=[]
for p in sorted((ROOT/'new-json').glob('*.json')):
 a=json.loads((ROOT/'old-json'/p.name).read_text(encoding='utf-8-sig'));b=json.loads(p.read_text(encoding='utf-8-sig'))
 cur=runtime(official(p.stem));row={'character':official(p.stem),'source':p.stem,'counts':{},'media':{},'metadata':{},'skills':[]}
 for k in ['images','sounds','globalPalettes']:
  x=a[k];y=b[k]
  if k=='globalPalettes':x=[v['data'] for v in x];y=[v['data'] for v in y]
  row['media'][k]={'old_count':len(x),'new_count':len(y),'changed_slots':[i for i,(v,w) in enumerate(zip(x,y)) if clean(v)!=clean(w)]}
 for k in a:
  if k not in ['images','sounds','globalPalettes','skills']:
   d=differences(clean(a[k]),clean(b[k]),k)
   if d:row['metadata'][k]=d
 row['counts']={'old_skills':len(a['skills']),'new_skills':len(b['skills'])}
 for i,(x,y) in enumerate(zip(a['skills'],b['skills'])):
  xx=[block(v) for v in x['blocks']];yy=[block(v) for v in y['blocks']]
  if xx==yy:continue
  changes=[]
  for tag,l,r,u,v in difflib.SequenceMatcher(None,[json.dumps(z) for z in xx],[json.dumps(z) for z in yy],autojunk=False).get_opcodes():
   if tag!='equal':changes.append({'kind':tag,'old_range':[l,r],'new_range':[u,v],'old':xx[l:r],'new':yy[u:v]})
  row['skills'].append({'id':i,'name':x['name'],'old_blocks':len(xx),'new_blocks':len(yy),'changes':changes,'runtime': 'old' if cur.get(i)==xx else 'new' if cur.get(i)==yy else 'modified' if i in cur else 'extracted'})
 report.append(row)
 print(row['character'],'skills',len(row['skills']),'metadata',list(row['metadata']),'media',[(k,len(v['changed_slots'])) for k,v in row['media'].items()],flush=True)
(ROOT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
