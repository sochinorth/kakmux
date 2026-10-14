# symbol-picker: lsp-document-symbol's list (no tmux) and <ret> on it;
# symbol-picker in tmux leaves t.c's path option untouched
# golden
# covers: rc/workspace.kak rc/pickers.kak rc/lsp.kak bin/kak-picker
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
mktproj "$R/p/proj"
CWD=$R/p/proj start notmux g t.c
waitdiags g 3
send g 'lsp-document-symbol'
waitout 10 '*goto*' qv g '%val{bufname}'
q g '%val{bufname} ft: %opt{filetype} buffile: %opt{lsp_buffile} path: %opt{path}'
cap g | head -4
send g 'execute-keys 2g'; keys g Enter
expectw "<ret> jumps to main" "t.c 3 5" qv g '%val{bufname} %val{cursor_line} %val{cursor_column}'
dbge g
stop g
echo "== tmux: symbol picker, t.c's path untouched"
CWD=$R/p/proj start kakmux h t.c
attach h
waitdiags h 3
send h 'symbol-picker'; fzfready
pdirs
q h '%val{bufname} path: %opt{path} buffile: %opt{lsp_buffile} pickers: %opt{picker_clients}'
dbge h
