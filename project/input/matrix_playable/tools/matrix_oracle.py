"""Independent union-find electrical oracle for every undioded 4x4 switch set."""
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'sim/matrix_oracle.txt'
ambiguous=0
with out.open('w') as f:
    for mask in range(65536):
        parent=list(range(8))
        def root(x):
            while parent[x]!=x:x=parent[x]
            return x
        for k in range(16):
            if mask>>k&1:parent[root(k//4)]=root(4+k%4)
        components={}
        for node in range(8):components.setdefault(root(node),[]).append(node)
        ghost=any(sum(n<4 for n in nodes)>=2 and sum(n>=4 for n in nodes)>=2 for nodes in components.values())
        ambiguous+=ghost
        f.write(f'{int(ghost):x}{0 if ghost else mask:04x}\n')
print(f'MATRIX_ORACLE states=65536 ambiguous={ambiguous} unique={65536-ambiguous}')
