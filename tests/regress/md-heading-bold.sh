# md-heading-bold: markdown headings are bold, in their colour: with
# kak-tree-sitter (ts_markup_heading*) and with Kakoune's own markdown
# highlighter (header, title)
# covers: rc/base.kak colors/*
. "$(dirname "$0")/../lib/h.sh"
mkdir -p "$R/p"
cat > "$R/p/t.md" <<'EOF'
# Top

## Order of operations, and why

Body text.

Setext
------

Title
=====
EOF
cp "$R/p/t.md" "$R/p/t.txt"
CWD=$R/p start notmux t t.md
sleep 1
# line: the text's (letters') attributes, b (bold) or -, and colour, one of
# each kind (the buffer's lines, past the line numbers' separator)
attrs() {
	tm t capture-pane -e -p -t main | head -11 | python3 -c '
import re, sys
for n, line in enumerate(sys.stdin, 1):
    fg, bold, seen, out = None, False, False, []
    for m in re.finditer(r"\033\[([0-9;]*)m|(.)", line):
        if m.group(1) is not None:
            p = m.group(1).split(";")
            i = 0
            while i < len(p):
                if p[i] in ("", "0"): fg, bold = None, False
                elif p[i] == "39": fg = None
                elif p[i] == "1": bold = True
                elif p[i] == "22": bold = False
                elif p[i] == "38" and p[i + 1] == "2": fg = ";".join(p[i + 2:i + 5]); i += 4
                elif p[i] in ("48", "58"): i += 4 if p[i + 1] == "2" else 2
                i += 1
        elif m.group(2) == "│": seen = True
        elif seen and m.group(2).isalnum():
            a = ("b" if bold else "-") + str(fg)
            if a not in out: out.append(a)
    print(n, *out)
'
}
red='b224;108;117'
attrs > "$R/ts"
cat "$R/ts"
expect "ts: # heading" "$(sed -n 1p "$R/ts")" "1 $red"
expect "ts: ## heading" "$(sed -n 3p "$R/ts")" "3 $red"
expect "ts: body" "$(sed -n 5p "$R/ts")" "5 -171;178;191"
expect "ts: setext -" "$(sed -n 7p "$R/ts")" "7 $red"
expect "ts: setext =" "$(sed -n 10p "$R/ts")" "10 $red"
# the same text with Kakoune's markdown highlighter, no tree-sitter
send t "edit t.txt; require-module markdown; add-highlighter buffer/ ref markdown"
attrs > "$R/kak"
cat "$R/kak"
expect "kak: # heading (header)" "$(sed -n 1p "$R/kak")" "1 $red"
expect "kak: ## heading (header)" "$(sed -n 3p "$R/kak")" "3 $red"
expect "kak: body" "$(sed -n 5p "$R/kak")" "5 -171;178;191"
expect "kak: setext - (header)" "$(sed -n 7p "$R/kak")" "7 $red"
expect "kak: setext = (title)" "$(sed -n 10p "$R/kak")" "10 $red"
expect "debug" "$(dbge t)" ""
