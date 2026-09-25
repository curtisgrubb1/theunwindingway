import json,glob,sys,re
L={o['day']:o for o in json.load(open('lessons.json'))}
I={o['title']:o['text'] for o in json.load(open('interludes.json'))}
def norm(x): return re.sub(r'\s+',' ',x).strip()
M={}
for f in sorted(glob.glob('map_*.json')):
    for e in json.load(open(f)): M[e['d']]=e
bad=0
for d,e in sorted(M.items()):
    t=norm(L[d]['text']+' '+I.get(e.get('src',''),'')+' '+(' '.join(I[k] for k in I if k.startswith('What') or k.startswith('Final')) if e.get('theme') or d>=361 else '')); tl=t.lower()
    for k in ['p','pe','r','r2','w','b','t','idea','theme']:
        v=e.get(k)
        if v and norm(v).lower() not in tl and norm(v).rstrip('.').lower()!=norm(L[d]['title']).rstrip('.').lower():
            print(d,k,'NOT VERBATIM:',v); bad+=1
    for v in e.get('ideas',[]):
        if norm(v).lower() not in tl: print(d,'idea NOT VERBATIM:',v); bad+=1
    for v in e.get('ev',[]):
        if norm(v).lower() not in tl: print(d,'ev NOT VERBATIM:',v); bad+=1
missing=[d for d in L if d not in M]
print(f'{len(M)} mapped, {bad} problems, missing {len(missing)}', missing[:20] if len(missing)<365 else '')
