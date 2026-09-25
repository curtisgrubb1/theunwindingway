# Builds the bundled lesson schedule the widget reads.
# Source of truth: lessons.json (from index.html) + map_*.json (hand-mapped, validated by validate.py).
import json,glob,re,os
L={o['day']:o for o in json.load(open('lessons.json'))}
M={}
for f in sorted(glob.glob('map_*.json')):
    for e in json.load(open(f)): M[e['d']]=e
def clean(s): return re.sub(r'\s+',' ',s).strip() if s else s
def cap(s):
    s=clean(s)
    return s[0].upper()+s[1:] if s else s
out=[]
for d in range(1,366):
    e=M[d]; x={}
    x['i']=clean(e.get('idea') or L[d]['title'])
    x['w']=e['when']; x['n']=e.get('n',0)
    if e.get('len'): x['len']=clean(e['len'])
    for k,kk in [('p','p'),('pe','pe'),('r','r'),('r2','r2'),('b','b'),('theme','th')]:
        if e.get(k): x[kk]=cap(e[k])
    if e.get('themeTitle'): x['tt']=e['themeTitle']
    x['f']=e['f']
    if e.get('ideas'): x['ideas']=[clean(i) for i in e['ideas']]
    out.append(x)
data=json.dumps(out,ensure_ascii=False,separators=(',',':'))
base='../../ios/App'
for t in ['TheWayWidget','TheWayMessages']:
    open(os.path.join(base,t,'lessons-widget.json'),'w').write(data)
print(len(out),'days,',len(data),'bytes')
