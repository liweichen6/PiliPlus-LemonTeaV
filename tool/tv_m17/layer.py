#!/usr/bin/env python3
"""layer.py DIR ID [FIRST]: the video layer's cadence over a run's latency samples (from sample FIRST on)."""
import glob,re,subprocess,sys,os
d,i=sys.argv[1],sys.argv[2]; first=int(sys.argv[3]) if len(sys.argv)>3 else 1
here=os.path.dirname(os.path.abspath(__file__))
n=k=0; fps=[]; worst=0
for f in sorted(glob.glob(f"{d}/latency-{i}-*.txt"), key=lambda p:int(re.search(r'-(\d+)\.txt$',p).group(1))):
    if int(re.search(r'-(\d+)\.txt$',f).group(1))<first: continue
    out=subprocess.run([sys.executable,f"{here}/cadence.py"],stdin=open(f),capture_output=True,text=True).stdout
    m=re.search(r'cadence: (\d+) intervals, median ([\d.]+) ms, over 25 ms (\d+) .*worst (\d+) ms, fps ([\d.]+)',out)
    if not m: continue
    n+=int(m.group(1)); k+=int(m.group(3)); worst=max(worst,int(m.group(4))); fps.append(float(m.group(5)))
print(f"layer {i}: {len(fps)} samples, long intervals {100*k/max(n,1):.1f}%, layer fps avg {sum(fps)/max(len(fps),1):.1f} min {min(fps):.1f}, worst gap {worst} ms")
