# explorer-open: <ret> on a file in <space>e's broot opens it in kak (broot-open)
. "$(dirname "$0")/../lib/h.sh"
need broot
P=$R/p/proj; mkproj "$P"
mkdir -p "$P/sub"; echo hi > "$P/sub/s.txt"
CWD=$P WAIT=2 start kakmux ex5 sub/s.txt
keys ex5 Space e; sleep 2
tm ex5 send-keys -t main.0 main.c; sleep 1; tm ex5 send-keys -t main.0 Enter; sleep 1.5
expect "opened in kak" "$(qv ex5 '%val{bufname}')" main.c
expect "kak focused, broot still there" "$(tm ex5 list-panes -t main -F '#{pane_id} #{pane_active} #{pane_current_command}' | tr '\n' ' ')" "%1 0 broot %0 1 kak "
