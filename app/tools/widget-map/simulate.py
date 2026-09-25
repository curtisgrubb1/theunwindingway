# Mirror of Practice.moment() in TheWayWidget.swift, for checking all 365 days.
import json,sys
P=json.load(open('../../ios/App/TheWayWidget/lessons-widget.json'))
def moment(day,minute,wake=420):
    p=P[day-1]; sleep=min(wake+900,1380); hour,m=divmod(minute,60); idea=p['i']
    plain=(f"LESSON {day}",idea,None)
    if minute<wake: return plain
    if minute>=sleep: return ("BEFORE SLEEP",p['b'],None) if p.get('b') else plain
    morning=range(wake,wake+90); evening=range(sleep-90,sleep)
    mt=p.get('p') or p.get('th') or idea; et=p.get('pe') or p.get('p') or idea
    ml=p['tt'].upper() if p.get('tt') else "MORNING PRACTICE"; L=p.get('len'); w=p['w']; mid=(wake+sleep)//2
    if w=='ampm':
        if minute in morning: return (ml,mt,L)
        if minute in evening: return ("EVENING PRACTICE",et,L)
    elif w=='wakesleep':
        if minute in morning: return ("AS YOU WAKE",mt,L)
        if minute in evening: return ("BEFORE SLEEP",p.get('b') or et,L)
    elif w=='wake':
        if minute in morning: return ("AS YOU WAKE",mt,L)
    elif w=='ampm1':
        if minute in morning: return ("MORNING PRACTICE",mt,L)
        if mid<=minute<mid+45: return ("PRACTICE · IN BETWEEN",mt,L)
        if minute in evening: return ("EVENING PRACTICE",et,L)
    elif w=='self':
        lab="ONCE TODAY · A TIME YOU CHOOSE" if p['n']<=1 else "AT A TIME YOU CHOOSE"
        if minute in morning: return (lab,mt,L)
        if p['n']>=2 and minute in evening: return (lab,et,L)
    elif w=='split':
        ideas=p.get('ideas',[])
        if minute in morning: return ("EARLIER PART OF THE DAY",ideas[0] if ideas else idea,L)
        if mid<=minute<mid+45: return ("LATTER PART OF THE DAY",ideas[1] if len(ideas)>1 else idea,L)
    elif w=='hourly5':
        if minute%60<5: return ("FIRST FIVE MINUTES OF THE HOUR",p.get('p') or idea,None)
    elif w=='spread':
        n=max(p['n'],1); first=wake+60; last=sleep-60
        for k in range(n):
            st=first if n==1 else first+k*(last-first)//(n-1)
            if st<=minute<st+30: return (f"PRACTICE · {k+1} OF {n}",p.get('p') or idea,L)
    f=p['f']; r=p.get('r')
    if f=='hourly': return ("AS THE HOUR STRIKES",r or idea,None) if m<5 else plain
    if f=='halfhour': return ("EVERY HALF HOUR",r or idea,None) if (m<5 or 30<=m<35) else plain
    if f=='hourhalf': return ("ON THE HOUR",r or idea,None) if m<30 else ("ON THE HALF HOUR",p.get('r2') or idea,None)
    if f=='quarter': return ("EVERY QUARTER HOUR",r or idea,None)
    if f=='twenty': return ("THREE TIMES AN HOUR",r or idea,None)
    if f=='ten': return ("EVERY TEN MINUTES",r or idea,None)
    if f=='often': return ("AS OFTEN AS YOU CAN",(r or idea) if hour%2 else idea,None)
    if f=='asneeded': return ("WHENEVER IT IS NEEDED",(r or idea) if hour%2 else idea,None)
    if f=='cycle':
        ids=p.get('ideas') or []
        if ids: k=hour%len(ids); return (f"REVIEW · {k+1} OF {len(ids)}",ids[k],None)
    if f=='cyclehour':
        ids=p.get('ideas') or []
        if len(ids)>=3: return ("AS THE HOUR STRIKES",ids[0],None) if m<5 else ("REVIEW",ids[1+hour%2],None)
    if f=='split':
        ids=p.get('ideas') or []
        if len(ids)>=2: return ("EARLIER PART OF THE DAY",ids[0],None) if minute<mid else ("LATTER PART OF THE DAY",ids[1],None)
    return plain
problems=0; longest=[]
for d in range(1,366):
    seen=[]
    for mn in range(0,1440,5):
        lab,txt,note=moment(d,mn)
        if not txt or 'Review of' in txt: print('BAD',d,mn,lab,txt); problems+=1
        if not seen or seen[-1][1:]!=(lab,txt): seen.append((mn,lab,txt))
        longest.append((len(txt),d,txt))
    if d in map(int,sys.argv[1:]):
        print(f"\n== Lesson {d}: {P[d-1]['i']}")
        for mn,lab,txt in seen: print(f"  {mn//60:02d}:{mn%60:02d}  {lab:32s} {txt[:90]}")
print('\nproblems',problems)
longest=sorted(set(longest),reverse=True)[:5]
for l in longest: print('long',l[0],'chars — lesson',l[1])
