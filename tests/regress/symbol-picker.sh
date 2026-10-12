# symbol-picker: lsp-document-symbol's list (no tmux) and <ret> on it;
# symbol-picker in tmux leaves t.c's path option untouched
# golden
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
mktproj "$R/p/proj"
CWD=$R/p/proj WAIT=1 start notmux g t.c
waitdiags g 3
WAIT2=1.5 send g 'lsp-document-symbol'
q g '%val{bufname} ft: %opt{filetype} buffile: %opt{lsp_buffile} path: %opt{path}'
cap g | head -4
send g 'execute-keys 2g'; keys g Enter; sleep 0.5
expect "<ret> jumps to main" "$(qv g '%val{bufname} %val{cursor_line} %val{cursor_column}')" "t.c 3 5"
dbge g
stop g
echo "== tmux: symbol picker, t.c's path untouched"
CWD=$R/p/proj WAIT=1 start kakmux h t.c
attach h
waitdiags h 3
WAIT2=1.5 send h 'symbol-picker'
pdirs
q h '%val{bufname} path: %opt{path} buffile: %opt{lsp_buffile} pickers: %opt{picker_clients}'
dbge h
