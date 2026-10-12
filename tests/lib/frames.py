"""frames.py DIR...: jitter analysis of screen samples (capture-pane -p,
one file per sample, in name order) for each scenario DIR.

For consecutive distinct frames it counts:
  col   changes of the column a reference text starts at ("int total = 0;" or
        "int util_twice"): the text shifting sideways (gutter width changes)
  dot   ● (diagnostic) marks dropped from a line whose code didn't change
  git   git gutter flags dropped from a line whose code didn't change
  rev   reversals of the vertical direction "return total;" moves in (lines
        jumping up and back down while typing)
Lines are matched by their code (unique lines only; indent guides, inline
diagnostic text and lines under the completion menu left out), so a line
moved by an inserted line is still the same line. Prints one line per scenario:
  NAME frames=N col=N dot=N git=N rev=N
"""
import glob
import os
import re
import sys

GUT = re.compile(r'^(.)(\s*\d+)│(.)(.*)$')


def frames(d):
    out, prev = [], None
    for f in sorted(glob.glob(os.path.join(d, '*.p'))):
        with open(f, errors='replace') as fh:
            t = fh.read().split('\n')[:40]
        if t != prev:
            out.append(t)
            prev = t
    return out


def code(rest):
    # code text: inline diagnostic message (after 3 blanks) dropped, the
    # indent guides (│ in the leading blanks) blanked
    c = rest.split('   ')[0].rstrip()
    m = re.match(r'^[\s│]*', c)
    return ' ' * len(m.group(0)) + c[len(m.group(0)):]


def marks(t):
    """{code: (dot, git)} for lines whose code appears once on screen"""
    seen, res = {}, {}
    for line in t:
        m = GUT.match(line)
        if not m or not m.group(4).strip():
            continue
        if m.group(4).lstrip(' │').startswith('└─'):
            continue  # an inline diagnostic line
        if '█' in line or '░' in line:
            continue  # under the completion menu (its scrollbar)
        k = code(m.group(4))
        seen[k] = seen.get(k, 0) + 1
        res[k] = (m.group(1) == '●', m.group(3) in '▍▔')
    return {k: v for k, v in res.items() if seen[k] == 1}


def analyse(d):
    fr = frames(d)
    cols, rows = [], []
    for t in fr:
        c = r = None
        for i, line in enumerate(t):
            for ref in ('int total = 0;', 'int util_twice'):
                if ref in line and c is None:
                    c = line.index(ref)
            if 'return total;' in line and r is None:
                r = i
        cols.append(c)
        rows.append(r)
    col = sum(1 for a, b in zip(cols, cols[1:]) if a is not None and b is not None and a != b)
    mk = [marks(t) for t in fr]
    dot = git = 0
    for a, b in zip(mk, mk[1:]):
        for k, (ad, ag) in a.items():
            if k in b:
                bd, bg = b[k]
                dot += ad and not bd
                git += ag and not bg
    rev = last = 0
    for a, b in zip(rows, rows[1:]):
        if a is None or b is None or a == b:
            continue
        d_ = 1 if b > a else -1
        if last and d_ != last:
            rev += 1
        last = d_
    return len(fr), col, dot, git, rev


for d in sys.argv[1:]:
    n, col, dot, git, rev = analyse(d)
    print(f'{os.path.basename(d)} frames={n} col={col} dot={dot} git={git} rev={rev}')
