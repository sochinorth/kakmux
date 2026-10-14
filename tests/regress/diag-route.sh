# diag-route: inline diagnostics land in the right buffer when the buffer is
# switched while a list is pending, and for buffers clangd answers while hidden;
# diagnostics-picker without LSP fails cleanly
# golden
# covers: rc/inline-diagnostics.kak rc/workspace.kak rc/pickers.kak rc/lsp.kak
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
mktproj "$R/p/proj"
CWD=$R/p/proj start kakmux d t.c
waitdiags d 3
# LD NAME: line_diags_n/state/pending ("5//": all 5 listed, none asked for)
LD() { qv "$1" '"%opt{line_diags_n}/%opt{line_diags_state}/%opt{line_diags_pending}"'; }
waitout 10 5// LD d
echo "== t.c line_diags (n, state, pending):"; q d '%opt{line_diags_n} %opt{line_diags_state} %opt{line_diags_pending}'
echo "== misroute repro: stale + request, then switch to *debug* at once"
send d 'set-option buffer line_diags_state stale; line-diags-request; buffer *debug*'
# the list answered (and dropped: *debug* is shown now)
waitout 10 '' qv d '%opt{line_diags_pending}'
q d '%val{bufname} pending: %opt{line_diags_pending} pickers: %opt{picker_clients}'
send d 'buffer t.c'
waitout 10 5// LD d
q d 't.c: n: %opt{line_diags_n} state: %opt{line_diags_state} pending: %opt{line_diags_pending} pickers: %opt{picker_clients}'
echo "== background buffer: open w.c, leave before clangd publishes, come back"
send d 'edit w.c; buffer t.c'
q d 'now in %val{bufname}'
W() { rm -f "$R/o/w"; send d "evaluate-commands -buffer w.c %{ echo -to-file $R/o/w %opt{line_diags_n} %opt{line_diags_state} %opt{lsp_diagnostic_error_count} }"; cat "$R/o/w"; }
# until clangd has published w.c's error, w.c hidden
published() { case $(W) in *" 1") return 0 ;; esac; return 1; }
waitfor 20 published
echo "w.c while hidden: $(W)"
send d 'buffer w.c'
waitout 10 1// LD d
q d 'w.c shown: n: %opt{line_diags_n} state: %opt{line_diags_state} %opt{line_diags} pending: %opt{line_diags_pending}'
cap d | head -3
expect "w.c inline line" "$(cap d | sed -n 2p)" "  1│                      └─Use of undeclared identifier 'zz'"
echo "== diagnostics-picker in *scratch* (no LSP): entry cleaned"
send d 'edit -scratch *s*; try %{ diagnostics-picker } catch %{ echo -debug "ERR: %val{error}" }'
q d 'only: %opt{picker_only}'
send d 'buffer t.c'
echo "== diagnostics-picker in t.c (no client attached: no popup)"
send d 'diagnostics-picker'
# kak-lsp's answer: a picker dir, its popup failing (no client), dir gone
nodir() { ! ls -d "$R"/tmp/kak-picker.* > /dev/null 2>&1; }
waitout 10 // qv d '"%opt{picker_only}/%opt{picker_clients}/%opt{line_diags_pending}"' && waitfor 10 nodir
q d 'only: %opt{picker_only} pickers: %opt{picker_clients} pending: %opt{line_diags_pending}'
# and nothing comes back later (time has to pass for that)
sleep 3; q d 'later only: %opt{picker_only}'; pdirs
cap d | sed -n '1,9p'
keys d Escape
dbge d
