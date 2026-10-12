# diag-picker: <space>d's picker with a client attached: popup handed the
# list, only= this file; the inline lines stay
# golden
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp fzf
mktproj "$R/p/proj"
CWD=$R/p/proj WAIT=1 start kakmux d t.c
attach d
waitdiags d 3; sleep 1
WAIT2=2 send d 'diagnostics-picker'
pdirs
expect "picker list: 5 entries" "$(nlines "$R"/tmp/kak-picker.*/list)" 5
q d 'only: %opt{picker_only} pickers: %opt{picker_clients} pending: %opt{line_diags_pending}'
cap d | sed -n '1,9p'
keys d Escape
sleep 0.5
q d 'only: %opt{picker_only} pickers: %opt{picker_clients} pending: %opt{line_diags_pending}'
dbge d
