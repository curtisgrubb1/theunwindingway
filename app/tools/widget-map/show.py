import json,re,sys
L=json.load(open('lessons.json'))
kw=re.compile(r"\b(morning|evening|hour|hourly|half hour|minute|minutes|times today|times a day|throughout the day|as often|sleep|waking|wake|practice period|practice periods|each hour|every hour|frequent|remind|repeat|apply|application|close your eyes|search your mind|twice|three|four|five|six|seven)\b",re.I)
a,b=int(sys.argv[1]),int(sys.argv[2])
full = len(sys.argv)>3
for o in L:
    if a<=o['day']<=b:
        ps=o['text'].split('\n')
        print(f"\n### {o['day']} | {o['title']}  ({len(o['text'].split())}w)")
        if full:
            for p in ps: print("  >", p)
            continue
        keep=set()
        for i,p in enumerate(ps):
            if kw.search(p) or p.rstrip().endswith(':'):
                keep.add(i)
                if p.rstrip().endswith(':'):
                    j=i+1
                    while j<len(ps) and not ps[j].strip(): j+=1
                    if j<len(ps): keep.add(j)
        for i in sorted(keep): print("  >", ps[i])
