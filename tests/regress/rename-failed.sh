# rename-failed: a rename that fails leaves no buffers behind (20 s timer);
# a good one through the prompt after it; diagnostics follow; :wa builds
# tags: slow
# covers: rc/lsp.kak
# golden
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp make cc
P=$R/p/proj; mkproj "$P"
CWD=$P start "${MODE:-kakmux}" r4 main.c
# clangd's background index written (a rename reaches the files not open)
idx() { [ "$(ls "$P"/.cache/clangd/index 2>/dev/null | grep -c '\.idx$')" -ge 4 ]; }
waitfor 20 idx || fail "clangd index not written"
send r4 "execute-keys gg/return<ret>"
send r4 "lsp-rename foo"
refused() { dbg r4 | grep -q 'Cannot rename symbol'; }
waitfor 10 refused
q r4 '%val{buflist}' '%opt{lsp_edit_armed}'
cap r4 | tail -1 | cut -c1-120
# the 20 s timer
EW=30 expectw "opened buffers closed by the timer" "*debug* main.c " qv r4 '%val{buflist} %opt{lsp_edit_armed}'
send r4 "execute-keys gg/point_sum<ret>"
send r4 "lsp-rename-prompt"
keys r4 C-u
keys r4 p s u m Enter
waitcap r4 'renamed: '
q r4 '%val{buflist}' '%opt{lsp_edit_armed}'
cap r4 | tail -1 | cut -c1-120
expect "disk untouched" "$(cd "$P" && git status --short | tr '\n' ' ')" ""
diagsin() { case $(qv r4 %opt{line_diags}) in *psum*Initializing*) return 0 ;; esac; return 1; }
waitfor 10 diagsin; q r4 %opt{line_diags} %opt{lsp_diag_warnings}; cap r4 | tail -1 | cut -c1-120
send r4 "write-all"; waitout 10 '' qv r4 %opt{line_diags}; q r4 %opt{line_diags} %opt{lsp_diag_errors}
# and they stay gone (no late publish brings them back)
sleep 5; q r4 %opt{line_diags} %opt{lsp_diag_errors}
expect "builds" "$(cd "$P" && git status --short | tr '\n' ' '; make -s && ./points; make -s clean)" " M main.c  M point.c  M point.h c = (5, 8)
dist2 = 25
twice = 10"
dbge r4 | grep -v 'LSP: INFO' | head -30
