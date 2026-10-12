# shells: shells per action, the scenario the numbers were first taken with:
# normal moves, 8 chars typed, mode changes and selections
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
P=$R/p/proj; mkproj "$P"
SHW=1 CWD=$P WAIT=1 start kakmux sc main.c
waitdiags sc 0; sleep 4
: > "$KM_SHLOG"
WAIT2=0.15
keys sc g g; for i in 1 2 3 4 5 6; do keys sc j; done; keys sc w; keys sc w; keys sc b
metric moves-shells "$(shells)"; shtop 4
expect_le "normal moves (10 keys)" "$(shells)" 15
: > "$KM_SHLOG"
keys sc o; for c in a b c d e f g h; do keys sc $c; done; keys sc Escape
sleep 1
metric insert-shells "$(shells)"; shtop 8
expect_le "insert typing (o, 8 chars, esc, idle)" "$(shells)" 60
: > "$KM_SHLOG"
keys sc Space; keys sc Escape; keys sc i; keys sc Escape; keys sc '%'; keys sc s 'int' Enter; keys sc ,
sleep 0.5
metric modes-shells "$(shells)"; shtop 4
expect_le "modes and selections" "$(shells)" 15
