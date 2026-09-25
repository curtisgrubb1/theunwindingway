import json,re
L=json.load(open('lessons.json'))
def ideas_for(day, reviewed):
    t=L[day-1]['text']
    out=[]
    pos=0
    for r in reviewed:
        title=L[r-1]['title'].rstrip('.').strip()
        words=title.split()
        found=None
        for k in range(len(words),2,-1):
            pre=' '.join(words[:k])
            i=t.find(pre,pos)
            if i<0: i=t.lower().find(pre.lower(),pos)
            if i>=0:
                # extend to end of sentence
                m=re.search(r'[.!?]', t[i+len(pre)-1:])
                end=i+len(pre)-1+(m.end() if m else 0)
                found=t[i:end].strip(); pos=end; break
        out.append((r,found))
    return out
if __name__=='__main__':
    for d in range(51,61):
        k=d-50; rv=range(5*k-4,5*k+1)
        for r,f in ideas_for(d,rv): print(d,r,f)
