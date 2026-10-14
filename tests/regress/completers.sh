# completers: kak-lsp's completer added in insert mode and restored after;
# a window's own value and later global changes are respected
# golden
# covers: rc/editor.kak rc/lsp.kak
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
mktproj "$R/p/proj"
CWD=$R/p/proj start kakmux n t.c
waitdiags n 3
q n 'start: %opt{completers}'
keys n i
q n 'insert, nothing typed: %opt{completers}'
keys n x Escape
q n 'after typing: %opt{completers}'
send n 'set-option global completers word=all'
q n 'global changed (as lsp-disable): %opt{completers}'
echo "== window with its own value"
send n 'set-option window completers filename word=buffer'
keys n i
q n 'insert: %opt{completers}'
keys n Escape
expect "own value back after insert" "$(qv n '%opt{completers}')" "filename word=buffer"
send n 'set-option global completers word=buffer'
q n 'global changed: %opt{completers} (own kept)'
send n 'execute-keys u'
dbge n
