# diag-route: inline diagnostics land in the right buffer when the buffer is
# switched while a list is pending, and for buffers clangd answers while hidden;
# diagnostics-picker without LSP fails cleanly
# golden
# covers: rc/inline-diagnostics.kak rc/workspace.kak rc/pickers.kak rc/lsp.kak
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
mktproj "$R/p/proj"
CWD=$R/p/proj WAIT=1 start kakmux d t.c
waitdiags d 3; sleep 1
echo "== t.c line_diags (n, state, pending):"; q d '%opt{line_diags_n} %opt{line_diags_state} %opt{line_diags_pending}'
echo "== misroute repro: stale + request, then switch to *debug* at once"
WAIT2=2 send d 'set-option buffer line_diags_state stale; line-diags-request; buffer *debug*'
q d '%val{bufname} pending: %opt{line_diags_pending} pickers: %opt{picker_clients}'
send d 'buffer t.c'
sleep 1.5
q d 't.c: n: %opt{line_diags_n} state: %opt{line_diags_state} pending: %opt{line_diags_pending} pickers: %opt{picker_clients}'
echo "== background buffer: open w.c, leave before clangd publishes, come back"
WAIT2=0.05 send d 'edit w.c; buffer t.c'
q d 'now in %val{bufname}'
sleep 3
send d "evaluate-commands -buffer w.c %{ echo -to-file $R/o/w %opt{line_diags_n} %opt{line_diags_state} %opt{lsp_diagnostic_error_count} }"
echo "w.c while hidden: $(cat "$R/o/w")"
WAIT2=2 send d 'buffer w.c'
q d 'w.c shown: n: %opt{line_diags_n} state: %opt{line_diags_state} %opt{line_diags} pending: %opt{line_diags_pending}'
cap d | head -3
expect "w.c inline line" "$(cap d | sed -n 2p)" "  1│                      └─Use of undeclared identifier 'zz'"
echo "== diagnostics-picker in *scratch* (no LSP): entry cleaned"
send d 'edit -scratch *s*; try %{ diagnostics-picker } catch %{ echo -debug "ERR: %val{error}" }'
q d 'only: %opt{picker_only}'
send d 'buffer t.c'
echo "== diagnostics-picker in t.c (no client attached: no popup)"
WAIT2=2 send d 'diagnostics-picker'
q d 'only: %opt{picker_only} pickers: %opt{picker_clients} pending: %opt{line_diags_pending}'
sleep 3; q d 'later only: %opt{picker_only}'; pdirs
cap d | sed -n '1,9p'
keys d Escape
sleep 0.5
dbge d
