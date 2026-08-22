import re, subprocess, pathlib

HERE = pathlib.Path(__file__).resolve().parent
IDX  = HERE.parents[1] / 'apps/api/public/index.html'
CSS0, CSS1 = '/* gf:css:start */', '/* gf:css:end */'
HTM0, HTM1 = '<!-- gf:html:start -->', '<!-- gf:html:end -->'
P = 'gf-'

subprocess.run(['python3', 'gen.py'], cwd=HERE, check=True)
src = (HERE / 'gif-full.html').read_text(encoding='utf-8')

style  = re.search(r'<style>(.*?)</style>', src, re.S).group(1)
markup = re.search(r'<!--STAGE-->(.*?)<!--/STAGE-->', src, re.S).group(1).strip()

urls = []
style = re.sub(r'url\([^)]*\)', lambda m: (urls.append(m.group(0)), f"\x00U{len(urls)-1}\x00")[1], style)

for n in sorted(set(re.findall(r'@keyframes\s+([A-Za-z][\w-]*)', style)), key=len, reverse=True):
    style  = re.sub(r'(?<![\w-])' + re.escape(n) + r'(?![\w-])', P + n, style)
    markup = re.sub(r'(?<![\w-])' + re.escape(n) + r'(?![\w-])', P + n, markup)

style  = re.sub(r'\.([A-Za-z][\w-]*)', lambda m: '.' + P + m.group(1), style)
markup = re.sub(r'class="([^"]*)"',
                lambda m: 'class="' + ' '.join(P + c for c in m.group(1).split()) + '"', markup)
for i, u in enumerate(urls):
    style = style.replace(f"\x00U{i}\x00", u)

root = re.search(r'(?<![\w.-]):root\s*\{([^}]*)\}', style).group(1).strip()
star = re.search(r'(?<![\w.-])\*\s*\{([^}]*)\}', style).group(1).strip()
for pat in (r'(?<![\w.-]):root\s*\{[^}]*\}', r'(?<![\w.-])\*\s*\{[^}]*\}', r'(?<![\w.-])body\s*\{[^}]*\}'):
    style = re.sub(pat, '', style, count=1)

scoped = (f".app-film{{{root}}}\n.app-film *{{{star}}}\n" + style.strip() +
          "\n.app-film .gf-stage{width:100%;height:100%;max-width:none;aspect-ratio:auto;"
          "border:0;border-radius:0;background:transparent;position:absolute;inset:0}")

leaks = [p.strip() for s in re.findall(r'([^{}]+)\{', re.sub(r'/\*.*?\*/', '', scoped, flags=re.S))
         for p in s.split(',')
         if p.strip() and not p.strip().startswith('@') and '%' not in p
         and not p.strip()[0].isdigit() and 'gf-' not in p and '.app-film' not in p]
if leaks:
    raise SystemExit(f"refusing to inject, global selectors would leak: {sorted(set(leaks))}")

site = IDX.read_text(encoding='utf-8')
body = "\n".join("      " + l if l.strip() else l for l in markup.splitlines())
site = re.sub(re.escape(CSS0) + r'.*?' + re.escape(CSS1), CSS0 + '\n' + scoped + '\n' + CSS1, site, flags=re.S)
site = re.sub(re.escape(HTM0) + r'.*?' + re.escape(HTM1), HTM0 + '\n' + body + '\n' + HTM1, site, flags=re.S)
IDX.write_text(site, encoding='utf-8')
print(f"injected: css={len(scoped)}  markup={len(markup)}")
