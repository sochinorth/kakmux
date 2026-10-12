# indent-filetype: tabstop/indentwidth follow the filetype (tabs kept for the
# ported filetypes) when a buffer's filetype changes back and forth
# golden
. "$(dirname "$0")/../lib/h.sh"
mktproj "$R/p/proj"
CWD=$R/p/proj WAIT=2 start kakmux b t.c
p() { printf '%s: ' "$1"; q b '%opt{filetype} %opt{tabstop} %opt{indentwidth}'; }
p start-c
send b 'set-option buffer filetype cpp'; p c-cpp
send b 'set-option buffer filetype python'; p cpp-python
send b 'set-option buffer filetype c'; p python-c
send b 'set-option buffer filetype python'; p c-python
send b 'set-option buffer filetype sh'; p python-sh
send b 'set-option buffer filetype markdown'; p sh-markdown
send b 'set-option buffer filetype ""'; p markdown-none
expect "c again: tabs" "$(send b 'set-option buffer filetype c'; qv b '%opt{tabstop} %opt{indentwidth}')" "4 0"
# known: kak-tree-sitter's rc removes window/<lang> itself, so the stock
# c-family hook's own removal fails on a filetype change (not this kakrc)
dbge b | grep -v "^error running hook WinSetOption(filetype=[a-z]*)/: 1:2: 'remove-highlighter': no such id: 'c'$"
