import json,re,sys
L=json.load(open('lessons.json'))
kw=re.compile(r"\b(practice|say|tell (yourself|him|her|them)|repeat|remind|ask|each hour|hourly|minute|minutes|morning|night|today we|throughout the day|as often)\b",re.I)
a,b=int(sys.argv[1]),int(sys.argv[2])
for d in range(a,b+1):
    t=L[d-1]['text']; ps=[p.strip() for p in t.split('\n') if p.strip()]
    print(f"\n{d} | {L[d-1]['title']}")
    shorts=[p for p in ps[1:] if len(p)<240]
    for p in shorts: print('   S:', p)
    sents=re.split(r'(?<=[.!?:])\s+',' '.join(p for p in ps if len(p)>=240))
    for s in sents:
        if kw.search(s): print('   i:', s[:300])
