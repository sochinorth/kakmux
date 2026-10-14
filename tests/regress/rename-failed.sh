# rename-failed: a rename that fails leaves no buffers behind (20 s timer);
# a good one through the prompt after it; diagnostics follow; :wa builds
# tags: slow
# covers: rc/lsp.kak
# golden
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp make cc
P=$R/p/proj; mkproj "$P"
CWD=$P WAIT=1 start "${MODE:-kakmux}" r4 main.c
waitdiags r4 0; sleep 4
send r4 "execute-keys gg/return<ret>"
send r4 "lsp-rename foo"
sleep 2
q r4 '%val{buflist}' '%opt{lsp_edit_armed}'
cap r4 | tail -1 | cut -c1-120
sleep 20
expect "opened buffers closed by the timer" "$(qv r4 '%val{buflist} %opt{lsp_edit_armed}')" "*debug* main.c "
send r4 "execute-keys gg/point_sum<ret>"
send r4 "lsp-rename-prompt"
keys r4 C-u
keys r4 p s u m Enter
sleep 3
q r4 '%val{buflist}' '%opt{lsp_edit_armed}'
cap r4 | tail -1 | cut -c1-120
expect "disk untouched" "$(cd "$P" && git status --short | tr '\n' ' ')" ""
sleep 3; q r4 %opt{line_diags} %opt{lsp_diag_warnings}; cap r4 | tail -1 | cut -c1-120
send r4 "write-all"; sleep 2; q r4 %opt{line_diags} %opt{lsp_diag_errors}; sleep 5; q r4 %opt{line_diags} %opt{lsp_diag_errors}
expect "builds" "$(cd "$P" && git status --short | tr '\n' ' '; make -s && ./points; make -s clean)" " M main.c  M point.c  M point.h c = (5, 8)
dist2 = 25
twice = 10"
dbge r4 | grep -v 'LSP: INFO' | head -30
