# diag-picker: <space>d's picker with a client attached: popup handed the
# list, only= this file; the inline lines stay
# golden
# covers: rc/inline-diagnostics.kak rc/workspace.kak rc/pickers.kak bin/kak-picker
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp fzf
mktproj "$R/p/proj"
CWD=$R/p/proj start kakmux d t.c
attach d
# attaching can move the cursor (to line 9) and so the view, depending on when
# the window takes the client's size: the cursor in main, on a line with no
# diagnostic, the view at the top
send d 'execute-keys gg 7g'
waitdiags d 3
# LD NAME: line_diags_n/state/pending ("5//": all 5 listed, none asked for)
LD() { qv "$1" '"%opt{line_diags_n}/%opt{line_diags_state}/%opt{line_diags_pending}"'; }
waitout 10 5// LD d
send d 'diagnostics-picker'; fzfready
pdirs
expect "picker list: 5 entries" "$(nlines "$R"/tmp/kak-picker.*/list)" 5
q d 'only: %opt{picker_only} pickers: %opt{picker_clients} pending: %opt{line_diags_pending}'
cap d | sed -n '1,9p'
keys d Escape
q d 'only: %opt{picker_only} pickers: %opt{picker_clients} pending: %opt{line_diags_pending}'
dbge d
