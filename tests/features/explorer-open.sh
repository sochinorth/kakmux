# explorer-open: <ret> on a file in <space>e's broot opens it in kak (broot-open)
# covers: rc/pickers.kak scripts/broot-open
. "$(dirname "$0")/../lib/h.sh"
need broot
P=$R/p/proj; mkproj "$P"
mkdir -p "$P/sub"; echo hi > "$P/sub/s.txt"
CWD=$P start kakmux ex5 sub/s.txt
# (broot's tree drawn: it takes keys; main.c found: <ret> opens it)
keys ex5 Space e; waitcap ex5 'Hit enter to go up' 10 main.0
tm ex5 send-keys -t main.0 main.c; waitcap ex5 '▶ .*main\.c' 10 main.0; tm ex5 send-keys -t main.0 Enter
expectw "opened in kak" main.c qv ex5 '%val{bufname}'
LP() { tm ex5 list-panes -t main -F '#{pane_id} #{pane_active} #{pane_current_command}' | tr '\n' ' '; }
expectw "kak focused, broot still there" "%1 0 broot %0 1 kak " LP
