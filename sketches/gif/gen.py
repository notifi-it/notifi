O=[0.0,100/3,200/3]
def g(p,x): return round(O[p]+x,3)
KARLA,RECUR=('/fonts/karla.woff2','/fonts/recursive-mono.woff2')
BODY,CLAP,BELL=('/bell-body.svg','/bell-clapper.svg','/bell.svg')
ANAGLYPH='/anaglyph-bell.png'

# ---- original composition (film.js): terminal centred, devices centred, dots on the 50% midline
TERM='left:4.17%;top:24.5%;width:38.43%;height:55%'
DOTY=50.0
DEV=[('left:64.25%;top:6.22%;width:18.5%;aspect-ratio:428/900'),
     ('left:53.15%;top:17.55%;width:40.7%;aspect-ratio:1292/916'),
     ('left:51.75%;top:18.96%;width:43.5%;aspect-ratio:1640/1040')]
TRAIL=[f'left:43.52%;width:19.91%;top:{DOTY}%',f'left:43.52%;width:8.79%;top:{DOTY}%',f'left:43.52%;width:7.41%;top:{DOTY}%']

SIG='<svg viewBox="0 0 25 18" class="ic" style="--w:{w}"><rect x="0" y="12" width="4" height="6" rx="1"/><rect x="7" y="8" width="4" height="10" rx="1"/><rect x="14" y="4" width="4" height="14" rx="1"/><rect x="21" y="0" width="4" height="18" rx="1"/></svg>'
WIFI='<svg viewBox="0 0 25 18" class="ic st" style="--w:{w}"><path d="M2.2 6.4a15.5 15.5 0 0 1 20.6 0"/><path d="M5.9 10.4a10 10 0 0 1 13.2 0"/><path d="M9.6 14.2a4.6 4.6 0 0 1 5.8 0"/><circle cx="12.5" cy="16.6" r="1.4" class="fl"/></svg>'
BATT='<svg viewBox="0 0 30 14" class="ic" style="--w:{w}"><rect x="0.75" y="0.75" width="24.5" height="12.5" rx="4" fill="none" stroke="currentColor" stroke-opacity=".5" stroke-width="1.5"/><path d="M27.5 4.5a3.2 3.2 0 0 1 0 5Z" fill-opacity=".5"/><rect x="2.6" y="2.6" width="15" height="8.8" rx="2.2"/></svg>'
def lock(st,dfs,tfs,date,time):
    return (f'<div class="lock" style="{st}">'
            f'<div class="ldate" data-clock="date" style="--fs:{dfs}">{date}</div>'
            f'<div class="ltime" data-clock="time" style="--fs:{tfs}">{time}</div></div>')
PH_LOCK=lock('left:0;right:0;top:13.5%','4.649','24.595','Tuesday 11 August','10:24')
PD_LOCK=lock('left:0;right:0;top:13%','1.474','7.985','Tuesday 11 August','10:24')
PHFIX=lambda h: h.replace('class="sbar"','class="sbar ph"',1)
def sbar(st,fs,l,ic): return f'<div class="sbar" style="{st};--fs:{fs}"><span>{l}</span><span class="icons">{ic}</span></div>'
PH_SB=PHFIX(sbar('left:7%;right:7%;top:2.3%;height:4.6%','5.946','',SIG.format(w=5.784)+WIFI.format(w=5.676)+BATT.format(w=8.757)))
PD_SB=sbar('left:7.5%;right:7.5%;top:5.4%;height:4.2%','1.769','',WIFI.format(w=3.145)+BATT.format(w=4.324))
MC_SB=('<div class="sbar mb" style="left:6.8%;right:8%;top:3.4%;height:4.6%;--fs:1.563">'
       '<svg class="amark" viewBox="0 0 24 24" aria-hidden="true"><path d="M16.4 12.7c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.1-2.8.9-3.5.9-.7 0-1.8-.9-3-.8-1.5 0-2.9.9-3.7 2.3-1.6 2.7-.4 6.8 1.1 9 .8 1.1 1.7 2.3 2.9 2.3 1.2 0 1.6-.7 3-.7s1.8.7 3 .7c1.3 0 2.1-1.1 2.8-2.2.9-1.3 1.3-2.5 1.3-2.6 0 0-2.5-1-2.5-3.6zM14.2 5.9c.6-.8 1-1.9.9-3-.9 0-2.1.6-2.7 1.4-.6.7-1.1 1.8-1 2.9 1 .1 2.1-.5 2.8-1.3z"/></svg><span class="icons"><span class="mbell"></span>'+BATT.format(w=3.218)+
       '<span class="dt" data-clock="menubar">Tue 11 Aug 10:24</span></span></div>')

CLAUDE_ORANGE='#D97757'
MASCOT=("""<svg class="mascot" viewBox="0 0 52 40" aria-hidden="true">
      <rect x="2" y="0" width="48" height="27" rx="3" fill="%s"/>
      <rect x="12" y="8" width="6" height="9" rx="1.2" fill="#1C1C1E"/>
      <rect x="34" y="8" width="6" height="9" rx="1.2" fill="#1C1C1E"/>
      <rect x="7"  y="32" width="5" height="5" rx="1" fill="%s"/>
      <rect x="15" y="32" width="5" height="5" rx="1" fill="%s"/>
      <rect x="32" y="32" width="5" height="5" rx="1" fill="%s"/>
      <rect x="40" y="32" width="5" height="5" rx="1" fill="%s"/>
    </svg>""" % ((CLAUDE_ORANGE,)*5))
CPROMPT=['Build a way to send notifications over HTTP',
         'to my iOS device and my macOS device.',
         'Make no mistakes.']
CREPLY='It already exists. Check your phone.'

PASSES=[
 dict(title='claude — ~/notifi',head=('Get a push notification to your device','from anything that can make an HTTP request.'),
  claude=True,lines=[],
  card=('notifi','No mistakes made.'),cardpos='left:73.5%;top:42.2%;width:15%',sb=PH_SB+PH_LOCK,clip=None),
 dict(title='run.sh — -zsh',head=('One key per device.','Each iPhone, iPad or Mac gets its own key.'),
  lines=['<span class="c">$</span> curl notifi.it/send \\',
         '    -d key=<span class="k">nk_live_8f3a</span> \\','    -d title=<span class="s">"Hello from notifi"</span> \\',
         '    -d message=<span class="s">"Your first notification."</span> \\',
         '    -d link=<span class="s">https://notifi.it/docs</span> \\',
         '    -d image=<span class="s">https://notifi.it/anaglyph-bell.png</span>'],
  card=('Hello from notifi','Your first notification.'),thumb=ANAGLYPH,cardpos='left:73.5%;top:45.5%;width:22%',sb=PD_SB+PD_LOCK,clip=None),
 dict(title='ci.yml — -zsh',head=('No signup, no SDK.','Install the app, copy your key, start sending.'),
  lines=['<span class="c"># a CI step fires only when the build fails</span>','<span class="s">- name:</span> notify',
         '  <span class="s">run:</span> <span class="c">|</span>','    curl notifi.it/send -d key=<span class="k">$NOTIFI_KEY</span> \\',
         '      -d title=<span class="s">"Build failed"</span> -d link=<span class="s">$RUN_URL</span>'],
  card=('Build failed','tests (3.11) exited 1'),cardpos='left:76%;top:19.5%;width:43.15%',sb=MC_SB,
  clip='left:54.38%;top:21.05%;width:38.24%;height:55.52%'),
]
SVG=["""<svg viewBox="0 0 428 900">
      <mask id="gfPhoneCut"><rect x="-20" y="-20" width="468" height="940" fill="#fff"/><rect x="151.5" y="24" width="125" height="37" rx="18.5" fill="#000"/></mask>
      <g mask="url(#gfPhoneCut)">
      <rect class="o" x="0" y="0" width="428" height="900" rx="75"/>
      <rect class="scr" x="13" y="13" width="402" height="874" rx="62"/>
      </g>
      <rect class="dot" x="145.5" y="870" width="137" height="5" rx="2.5"/>
    </svg>""",
"""<svg viewBox="0 0 1292 916">
      <rect class="o" x="0" y="0" width="1292" height="916" rx="42"/>
      <rect class="scr" x="41" y="41" width="1210" height="834" rx="18"/>
      <circle class="dot" cx="646" cy="20" r="5"/>
    </svg>""",
"""<svg viewBox="0 0 1640 1040">
      <mask id="gfMacCut"><rect x="-20" y="-20" width="1680" height="1080" fill="#fff"/><path d="M 727.5 32 L 727.5 65 Q 727.5 85 747.5 85 L 892.5 85 Q 912.5 85 912.5 65 L 912.5 32 Z" fill="#000"/></mask>
      <g mask="url(#gfMacCut)">
      <path class="o" d="M 64 1000 L 64 40 Q 64 0 104 0 L 1536 0 Q 1576 0 1576 40 L 1576 1000"/>
      <rect class="scr" x="99" y="35" width="1442" height="930" rx="16"/>
      <path d="M 99 85 L 99 51 Q 99 35 115 35 L 1525 35 Q 1541 35 1541 51 L 1541 85 Z" style="fill:#2E2E31;stroke:none"/>
      </g>
      <path class="o" d="M 0 1000 L 730 1000 C 752 1026 888 1026 910 1000 L 1640 1000 L 1640 1016 Q 1640 1040 1604 1040 L 36 1040 Q 0 1040 0 1016 Z"/>
    </svg>"""]

LN0,LN1=2.0,15.5
def lnspans(n):
    step=(LN1-LN0)/n
    return [(round(LN0+i*step,3),round(LN0+(i+1)*step,3)) for i in range(n)]
OPA=[.35,.5,.65,.8,1]
RS,RL=19.6,12.6   # ring window; longer hold after it before the pass fades
# ring tracks lifted from film.js (RING_BODY/RING_CLAP)
BF=[0,4.26,12.96,21.66,30.37,39.07,47.78,56.48,65.18,73.89,82.59,91.30,100]
BV=[0,-20,18,-16,14,-13,12,-10,8,-6,4,-2,0]
CF=[0,2.48,7.02,16.32,25.62,34.92,44.21,53.51,62.81,72.11,81.40,90.70,100]
CV=[0,0,-30,27,-24,20,-18,15,-12,9,-6,3,0]
kf=[]
for p in range(3):
    kf.append(f"@keyframes vis{p}{{0%,{g(p,0.5)}%{{opacity:0}} {g(p,2)}%,{g(p,32.2)}%{{opacity:1}} {g(p,33.3)}%,100%{{opacity:0}}}}")
    if PASSES[p].get('claude'):
        spans=[(3,7.6),(7.6,11.4),(11.4,14)]
        for i,(a,b) in enumerate(spans):
            n=len(CPROMPT[i])
            kf.append(f"@keyframes type{p}_{i}{{0%,{g(p,a)}%{{width:0;animation-timing-function:steps({n},end)}} {g(p,b)}%,100%{{width:{n}ch}}}}")
            last=(i==len(spans)-1)
            end=32.2 if last else b
            kf.append(f"@keyframes car{p}_{i}{{0%,{g(p,a)}%{{opacity:0}} {g(p,a+.01)}%,{g(p,end)}%{{opacity:1}} {g(p,end+.01)}%,100%{{opacity:0}}}}")
        kf.append(f"@keyframes reply{p}{{0%,{g(p,15.2)}%{{opacity:0}} {g(p,16.2)}%,{g(p,32.2)}%{{opacity:1}} {g(p,33.3)}%,100%{{opacity:0}}}}")
    else:
        for i,(s,e) in enumerate(lnspans(len(PASSES[p]['lines']))):
            kf.append(f"@keyframes ln{p}_{i}{{0%,{g(p,s)}%{{width:0;animation-timing-function:steps(30,end)}} {g(p,e)}%,100%{{width:100%}}}}")
    if not PASSES[p].get('claude'):
        kf.append(f"@keyframes rs{p}{{0%,{g(p,16.5)}%{{opacity:0}} {g(p,17.5)}%,{g(p,32.2)}%{{opacity:1}} {g(p,33.3)}%,100%{{opacity:0}}}}")
    for k in range(5):
        st,on,off,gone=16.5+k*.6,17.5+k*.6,21.5+k*.25,23+k*.25
        kf.append(f"@keyframes d{p}_{k}{{0%,{g(p,st)}%{{opacity:0}} {g(p,on)}%,{g(p,off)}%{{opacity:{OPA[k]}}} {g(p,gone)}%,100%{{opacity:0}}}}")
    if p<2:
        kf.append(f"@keyframes sp{p}{{0%,{g(p,17.8)}%{{opacity:0;transform:scale(.8)}} {g(p,18)}%{{opacity:1;transform:scale(.8);animation-timing-function:cubic-bezier(.2,1.4,.4,1)}} {g(p,20)}%,{g(p,32.2)}%{{opacity:1;transform:scale(1)}} {g(p,33.3)}%,100%{{opacity:0;transform:scale(1)}}}}")
    else:
        kf.append(f"@keyframes sp2{{0%,{g(2,17.6)}%{{opacity:0;transform:translateX(165%)}} {g(2,18)}%{{opacity:1;transform:translateX(165%);animation-timing-function:cubic-bezier(.17,.84,.44,1)}} {g(2,21)}%,{g(2,32.2)}%{{opacity:1;transform:translateX(0)}} {g(2,33.3)}%,100%{{opacity:0;transform:translateX(0)}}}}")
    for nm,F,V in (('rb',BF,BV),('rc',CF,CV)):
        stops="".join(f" {g(p,RS+f/100*RL)}%{{transform:rotate({v}deg)}}" for f,v in zip(F,V))
        kf.append(f"@keyframes {nm}{p}{{0%,{g(p,RS)}%{{transform:rotate(0deg)}}{stops} {g(p,RS+RL)}%,100%{{transform:rotate(0deg)}}}}")
ON,OFF="background:var(--chip);color:var(--fg)","background:#222224;color:var(--dim)"
kf+=[f"@keyframes tabA{{0%,32.9%{{{ON}}} 33.5%,99.6%{{{OFF}}} 100%{{{ON}}}}}",
     f"@keyframes tabB{{0%,32.9%{{{OFF}}} 33.5%,66.2%{{{ON}}} 66.8%,100%{{{OFF}}}}}",
     f"@keyframes tabC{{0%,66.2%{{{OFF}}} 66.8%,100%{{{ON}}}}}"]

BELLM='<span class="bell"><i class="bb"></i><i class="bc"></i></span>'
bh,dh,ch,th,hh,tih=[],[],[],[],[],[]
for p,P in enumerate(PASSES):
    if P.get('claude'):
        bh.append(f'<div class="body cbody bg{p}">'
                  f'<div class="cbanner">{MASCOT}'
                  f'<div class="cmeta"><div><b>Claude Code</b> <span class="c">v2.1.238</span></div>'
                  f'<div class="c">Fable 8</div></div></div>'
                  f'<div class="crule"></div>'
                  + ''.join(
                      f'<div class="cinput">'
                      f'<span class="cchev">{"&#10095;" if i==0 else "&nbsp;"}</span>'
                      f'<span class="ctype tp{p}_{i}">{ln}</span>'
                      f'<i class="ccar cr{p}_{i}"></i></div>' for i,ln in enumerate(CPROMPT))
                  + f'<div class="crule"></div>'
                  + f'<div class="creply rp{p}"><i class="cdot"></i>{CREPLY}</div></div>')
    else:
        lns="".join(f'<div class="l{p}_{i}">{t}</div>' for i,t in enumerate(P['lines']))
        bh.append(f'<div class="body bg{p}">{lns}<div class="resp r{p}"><span class="r">{{"ok":true}}</span></div></div>')
    dh.append(f'<div class="dev dv{p}">{SVG[p]}{P["sb"]}</div>')
    thumb=f'<img class="thumb" src="{P["thumb"]}" alt="">' if P.get('thumb') else ''
    card=(f'<div class="cardpos cp{p}"><div class="scard sc{p}">{BELLM}'
          f'<div style="min-width:0"><div class="t">{P["card"][0]}</div><div class="b">{P["card"][1]}</div></div>{thumb}</div></div>')
    ch.append(f'<div class="clip cl{p}">{card}</div>' if P['clip'] else card)
    dots="".join(f'<i class="dt{p}_{k}" style="--d:{0.30+k*0.09:.2f}"></i>' for k in range(5))
    th.append(f'<div class="trail tr{p}">{dots}</div>')
    hh.append(f'<div class="head hd{p}"><div class="l1">{P["head"][0]}</div><div class="l2">{P["head"][1]}</div></div>')
    tih.append(f'<span class="title ti{p}">{P["title"]}</span>')
geo=[]
for p,P in enumerate(PASSES):
    geo.append(f".dv{p}{{{DEV[p]}}}")
    geo.append(f".cp{p}{{{P['cardpos']}}}")
    geo.append(f".tr{p}{{{TRAIL[p]}}}")
    if P['clip']: geo.append(f".cl{p}{{{P['clip']}}}")
VERT_DEV=['left:19%;top:55%;width:62%;aspect-ratio:428/900',
          'left:4%;top:56%;width:92%;aspect-ratio:1292/916',
          'left:2%;top:57%;width:96%;aspect-ratio:1640/1040']
VERT_CARD=['left:50%;top:88.4%;width:50%','left:50%;top:73.5%;width:41%','left:50%;top:50%;width:92%']
VERT_CLIP=['','','left:48%;top:59.9%;width:46%;height:9%']
VERT_FS=[('.cp0',3.35),('.cp1',2.26),('.cp2',2.21)]
vgeo=[".stage{aspect-ratio:10/16}",
      ".head{left:4%;top:3.75%;width:92%}",
      ".head .l1{--fs:3.6}.head .l2{--fs:3.0}",
      ".term{left:4%;top:16.25%;width:92%;height:auto;aspect-ratio:830/528}",
      ".trail{display:none}"]
for sel,k in VERT_FS:
    vgeo.append(f"{sel} *{{font-size:calc(1cqw * var(--fs,1.5) * {k})}}")
    vgeo.append(f"{sel}{{--k:{k}}}")
for p in range(3):
    vgeo.append(f".dv{p}{{{VERT_DEV[p]}}}")
    vgeo.append(f".cp{p}{{{VERT_CARD[p]}}}")
    if VERT_CLIP[p]: vgeo.append(f".cl{p}{{{VERT_CLIP[p]}}}")
NLV=chr(10)
VERTICAL="@media(max-width:760px){"+NLV+NLV.join(vgeo)+NLV+"}"
still=[".stage *{animation:none}",
       ".hd0,.bg0,.dv0,.sc0,.rp0{opacity:1}",
       ".term .title.ti0{opacity:1}",
       ".tp0_0,.tp0_1,.tp0_2{width:auto}",
       ".ccar,.trail{display:none}",
       ".hd1,.hd2,.bg1,.bg2,.dv1,.dv2,.ti1,.ti2,.cl2{display:none}",
       ".term .tabs button.tabA{background:var(--chip);color:var(--fg)}"]
STILL="@media(prefers-reduced-motion:reduce){"+NLV+NLV.join(still)+NLV+"}"
anim=[]
for p in range(3):
    anim.append(f".hd{p},.bg{p},.dv{p},.ti{p},.cl{p}{{animation-name:vis{p}}}")
    if PASSES[p].get('claude'):
        for i in range(len(CPROMPT)):
            anim.append(f".tp{p}_{i}{{animation-name:type{p}_{i}}}")
            anim.append(f".cr{p}_{i}{{animation-name:car{p}_{i}}}")
        anim.append(f".rp{p}{{animation-name:reply{p}}}")
    else:
        for i in range(len(PASSES[p]['lines'])): anim.append(f".l{p}_{i}{{animation-name:ln{p}_{i}}}")
        anim.append(f".r{p}{{animation-name:rs{p}}}")
    for k in range(5): anim.append(f".dt{p}_{k}{{animation-name:d{p}_{k}}}")
    anim.append(f".sc{p}{{animation-name:sp{p}}}")
    anim.append(f".sc{p} .bb{{animation-name:rb{p}}}.sc{p} .bc{{animation-name:rc{p}}}")
LSEL="".join(f".l{p}_{i}," for p,P in enumerate(PASSES) for i in range(len(P["lines"])))
NL=chr(10)
html=f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>gif — full loop</title>
<style>
@font-face{{font-family:'Recursive Mono';font-style:normal;font-weight:300 800;font-display:block;src:url({RECUR}) format('woff2')}}
@font-face{{font-family:'Karla';font-style:normal;font-weight:400 500;font-display:block;src:url({KARLA}) format('woff2')}}
:root{{--bg:#1C1C1E;--surface:#262628;--line:#333;--chip:#3C3C3C;--fg:#EDEDED;--muted:#A1A1A1;--dim:#8A8A8A;--red:#DB4A4B;--blue:#7FA8E0;--stroke:#EDEDED;--stroke2:#55555A;
--mono:'Recursive Mono',ui-monospace,SFMono-Regular,Menlo,monospace;--sans:'Karla',-apple-system,BlinkMacSystemFont,system-ui,sans-serif;--ui:-apple-system,BlinkMacSystemFont,'SF Pro Text','SF Pro Display',system-ui,'Karla',sans-serif;--T:15s}}
*{{box-sizing:border-box;margin:0;padding:0}}
body{{background:#161618;min-height:100vh;display:grid;place-items:center;padding:24px;font-family:var(--sans);color:var(--fg)}}
.stage{{position:relative;width:min(96vw,1600px);aspect-ratio:2160/960;background:var(--bg);border:1px solid var(--line);border-radius:12px;overflow:hidden;container-type:inline-size}}
.stage *{{font-size:calc(1cqw * var(--fs,1.5))}}
.hd0,.hd1,.hd2,.bg0,.bg1,.bg2,.dv0,.dv1,.dv2,.ti0,.ti1,.ti2,.r0,.r1,.r2,.sc0,.sc1,.sc2,.cl2,
{LSEL}
.tp0_0,.tp0_1,.tp0_2,.cr0_0,.cr0_1,.cr0_2,.rp0,.trail i,.tabs button,.bell i{{animation-duration:var(--T);animation-timing-function:linear;animation-iteration-count:infinite}}
.head{{position:absolute;left:4.17%;top:9.2%;line-height:1.35;letter-spacing:-.01em;opacity:0}}
.head .l1{{--fs:2.0;font-family:var(--mono);font-weight:700;letter-spacing:-.03em;color:var(--fg)}}
.gif .l1{{--fs:2.3;color:var(--red)}}
.head .l2{{--fs:2.0;font-weight:400;color:var(--muted)}}
.term{{position:absolute;{TERM};container-type:inline-size;background:var(--surface);border-radius:1.1cqw;overflow:hidden}}
.term .bar{{position:relative;display:flex;align-items:center;gap:1.301cqw;padding:2.342cqw 3.123cqw}}
.term .bar i{{width:2.212cqw;height:2.212cqw;border-radius:50%;background:var(--chip)}}
.term .title{{--fs:2.602;position:absolute;left:15.092cqw;top:50%;transform:translateY(-50%);font-family:var(--mono);color:var(--dim);opacity:0}}
.term .tabs{{display:flex;gap:1.171cqw;padding:0 2.082cqw 1.821cqw}}
.term .tabs button{{--fs:2.602;flex:1;text-align:center;font-family:var(--mono);color:var(--dim);background:#222224;border-radius:0.85cqw;padding:0.989cqw 0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}}
@keyframes blink{{0%,49%{{opacity:1}}50%,100%{{opacity:.15}}}}
.term .tabs button{{border:0;cursor:pointer;font-family:var(--mono);line-height:inherit;-webkit-appearance:none;appearance:none}}
.term .tabs button:focus-visible{{outline:2px solid var(--fg);outline-offset:2px}}
.tabA{{animation-name:tabA}}.tabB{{animation-name:tabB}}.tabC{{animation-name:tabC}}
.bodywrap{{position:relative;height:calc(100% - 13.011cqw);border-top:1px solid var(--line)}}
.body{{position:absolute;inset:0;--fs:2.966;font-family:var(--mono);line-height:1.8;padding:3.123cqw 4.424cqw;white-space:pre;opacity:0}}
.body div{{width:0;overflow:hidden;white-space:pre}}
.body div.resp{{width:auto;opacity:0}}
.cbody{{white-space:normal;line-height:1.7;padding:3.383cqw 3.903cqw}}
.cbody div{{width:auto;overflow:visible;white-space:normal}}
.cbanner{{display:flex;align-items:flex-start;gap:2.862cqw;margin-bottom:2.862cqw}}
.mascot{{width:9.368cqw;height:auto;flex:none;margin-top:0.390cqw;overflow:visible}}
.cmeta{{--fs:2.732;line-height:1.5}}
.cmeta b{{font-weight:700;color:var(--fg)}}
.crule{{height:1px;background:var(--line);margin:1.301cqw 0}}
.cinput{{display:flex;align-items:baseline;gap:1.561cqw;padding:0.911cqw 0;white-space:pre}}
.cchev{{color:var(--dim);flex:none}}
.ctype{{display:inline-block;width:0;overflow:hidden;white-space:pre;vertical-align:bottom}}
.ccar{{display:inline-block;width:1.613cqw;height:3.253cqw;background:var(--fg);opacity:0;flex:none;align-self:center}}
.cinput+.cinput{{margin-top:-0.260cqw}}
.creply{{margin-top:2.342cqw;opacity:0;white-space:normal}}
.cdot{{display:inline-block;width:1.35cqw;height:1.35cqw;border-radius:50%;background:#D97757;vertical-align:middle;margin-right:1.0cqw;position:relative;top:-0.1cqw}}
.c{{color:var(--dim)}}.k{{color:var(--red)}}.s{{color:var(--blue)}}.r{{color:var(--dim)}}
.dev{{position:absolute;opacity:0;container-type:inline-size}}
.dev svg{{display:block;width:100%;height:100%;overflow:visible}}
.o{{fill:none;stroke:var(--stroke);stroke-width:3px;stroke-linejoin:round;vector-effect:non-scaling-stroke}}
.scr{{fill:var(--surface);stroke:none}}
.dot{{fill:var(--stroke2);stroke:none}}
.sbar{{position:absolute;display:flex;align-items:center;justify-content:space-between;font-family:var(--ui);font-weight:600;color:var(--fg)}}
.sbar .icons{{display:flex;align-items:center;gap:1.032cqw}}
.lock{{position:absolute;text-align:center;font-family:var(--ui);color:var(--fg)}}
.lock .ldate{{font-weight:600;opacity:.9;letter-spacing:.01em}}
.lock .ltime{{font-weight:600;line-height:1.02;letter-spacing:-.02em;margin-top:.25em}}
.sbar.ph .icons{{gap:1.838cqw;margin-right:1.730cqw}}
.sbar.mb .icons{{gap:1.425cqw}}
.sbar.ph>span:first-child{{flex:0 0 28.3%;text-align:center}}
.sbar svg.ic{{display:block;width:calc(1cqw * var(--w));height:auto;fill:currentColor;overflow:visible}}
.sbar svg.st path{{fill:none;stroke:currentColor;stroke-width:2.4;stroke-linecap:round}}
.sbar svg.st circle.fl{{fill:currentColor;stroke:none}}
.sbar .dt{{--fs:1.563;font-weight:400;color:var(--muted);margin-left:0.460cqw}}
.mbell{{width:1.85cqw;height:1.85cqw;transform:translateY(-0.02cqw);background:var(--fg);-webkit-mask:url({BELL}) center/contain no-repeat;mask:url({BELL}) center/contain no-repeat}}
.sbar svg.amark{{width:2.529cqw;height:2.529cqw;display:block;fill:var(--fg);opacity:.85;flex:none}}
.trail{{position:absolute;display:flex;align-items:center;justify-content:space-between;transform:translateY(-50%)}}
.trail i{{width:calc(1cqw * var(--d));height:calc(1cqw * var(--d));border-radius:50%;background:var(--dim);opacity:0}}
.clip{{position:absolute;overflow:hidden;border-radius:.6cqw;opacity:0}}
.cardpos{{position:absolute;transform:translate(-50%,-50%)}}
.scard{{font-family:var(--ui);background:var(--surface);border:1px solid var(--line);border-radius:.95cqw;padding:.8cqw 1cqw;display:flex;gap:.75cqw;align-items:center;overflow:hidden;box-shadow:0 .8cqw 2.4cqw rgba(0,0,0,.4);opacity:0;animation-duration:var(--T);animation-iteration-count:infinite}}
.bell{{position:relative;width:calc(1cqw * var(--k,1) * 1.95);height:calc(1cqw * var(--k,1) * 1.95);flex:none}}
.bell i{{position:absolute;inset:0;background:var(--fg);-webkit-mask-size:contain;mask-size:contain;-webkit-mask-repeat:no-repeat;mask-repeat:no-repeat;-webkit-mask-position:center;mask-position:center;transform-origin:50% 0}}
.bell .bb{{-webkit-mask-image:url({BODY});mask-image:url({BODY})}}
.bell .bc{{-webkit-mask-image:url({CLAP});mask-image:url({CLAP})}}
.scard .t{{--fs:1.05;font-weight:600;color:var(--fg);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;line-height:1.35}}
.scard .b{{--fs:.95;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;line-height:1.35}}
.scard .thumb{{width:calc(1cqw * var(--k,1) * 3.6);height:calc(1cqw * var(--k,1) * 3.6);border-radius:calc(1cqw * var(--k,1) * 0.5);object-fit:cover;flex:none;margin-left:auto;background:var(--chip)}}
{NL.join(geo)}
{NL.join(anim)}
{VERTICAL}
{STILL}
{NL.join(kf)}
</style>
</head>
<body>
<!--STAGE-->
<div class="stage">
  {NL.join(hh)}
  <div class="term">
    <div class="bar"><i></i><i></i><i></i>{"".join(tih)}</div>
    <div class="tabs"><button type="button" class="tabA" data-pass="0" aria-label="Play the Claude Hook scene">Claude Hook</button><button type="button" class="tabB" data-pass="1" aria-label="Play the run.sh scene">~/run.sh</button><button type="button" class="tabC" data-pass="2" aria-label="Play the ci.yml scene">workflows/ci.yml</button></div>
    <div class="bodywrap">
      {NL.join(bh)}
    </div>
  </div>
  {NL.join(th)}
  {NL.join(dh)}
  {NL.join(ch)}
<script>
(function () {{
  var film = document.currentScript.parentElement;
  if (!film) return;
  var L = 'en-GB';
  var fmt = {{
    date: {{ weekday: 'long', day: 'numeric', month: 'long' }},
    menubar: {{ weekday: 'short', day: 'numeric', month: 'short' }}
  }};
  function setClocks() {{
    var now = new Date();
    var hm = now.toLocaleTimeString(L, {{ hour: '2-digit', minute: '2-digit', hour12: false }});
    film.querySelectorAll('[data-clock]').forEach(function (el) {{
      var k = el.dataset.clock;
      if (k === 'time') el.textContent = hm;
      else if (k === 'date') el.textContent = now.toLocaleDateString(L, fmt.date);
      else el.textContent = now.toLocaleDateString(L, fmt.menubar) + ' ' + hm;
    }});
  }}
  try {{ setClocks(); setInterval(setClocks, 30000); }} catch (err) {{}}
  if (!film.getAnimations) return;
  film.addEventListener('click', function (e) {{
    var btn = e.target.closest('[data-pass]');
    if (!btn) return;
    var T = parseFloat(getComputedStyle(film).getPropertyValue('--T')) * 1000 || 15000;
    var at = (+btn.dataset.pass) * (T / 3);
    film.getAnimations({{ subtree: true }}).forEach(function (a) {{
      try {{ a.currentTime = at; a.play(); }} catch (err) {{}}
    }});
  }});
}})();
</script>
<!--/STAGE-->
</body>
</html>
"""
open('gif-full.html','w').write(html)
print('written',len(html))
