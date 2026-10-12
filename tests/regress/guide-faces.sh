# guide-faces: indent guides keep their colour inside strings and heredocs
# (the syntax highlighter's faces, applied after them, used to recolour them)
. "$(dirname "$0")/../lib/h.sh"
mkdir -p "$R/p"
tab=$(printf '\t')
cat > "$R/p/t.sh" <<EOF
f() {
${tab}if true; then
${tab}${tab}cat <<-END
${tab}${tab}${tab}heredoc
${tab}${tab}END
${tab}${tab}x="a string
${tab}${tab}${tab}going on"
${tab}fi
}
EOF
CWD=$R/p start notmux t t.sh
send t 'execute-keys 3g; execute-keys gl'
sleep 1
# line: the foreground colour of each guide on it (the buffer's lines, past
# the line numbers' separator)
tm t capture-pane -e -p -t main | head -9 | python3 -c '
import re, sys
for n, line in enumerate(sys.stdin, 1):
    fg, seen, out = None, False, []
    for m in re.finditer(r"\033\[([0-9;]*)m|(.)", line):
        if m.group(1) is not None:
            p = m.group(1).split(";")
            i = 0
            while i < len(p):
                if p[i] in ("", "0", "39"): fg = None
                elif p[i] == "38" and p[i + 1] == "2": fg = ";".join(p[i + 2:i + 5]); i += 4
                elif p[i] in ("48", "58"): i += 4 if p[i + 1] == "2" else 2
                i += 1
        elif m.group(2) == "│":
            if seen: out.append(fg)
            seen = True
    print(n, *out)
' > "$R/fgs"
cat "$R/fgs"
# IndentGuide (gray) or IndentGuideActive (lgray), nothing else
expect "guide colours" "$(cut -d' ' -s -f2- "$R/fgs" | tr ' ' '\n' | sort -u | grep -cvx -e '62;68;82' -e '92;99;112')" 0
expect "guides in the heredoc" "$(sed -n 4p "$R/fgs" | cut -d' ' -s -f2- | wc -w)" 3
expect "guides in the string" "$(sed -n 7p "$R/fgs" | cut -d' ' -s -f2- | wc -w)" 3
