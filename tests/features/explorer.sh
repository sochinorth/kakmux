# explorer: <space>e/<space>E open broot beside kak (kakmux, plain tmux), focus
# it when open; refused without tmux; in kakbr, focus the sidebar
# golden
# covers: rc/pickers.kak rc/splits.kak kakbr/* scripts/kakmux
. "$(dirname "$0")/../lib/h.sh"
need broot
P=$R/p/proj; mkproj "$P"
mkdir -p "$P/sub"; echo hi > "$P/sub/s.txt"
CWD=$P WAIT=2 start kakmux ex sub/s.txt
panes() { tm ex list-panes -t main -F '#{pane_id} #{pane_active} #{pane_width} #{pane_current_command} #{@kak_explorer} #{pane_current_path}'; }
echo "== <space>e (kakmux, 160 cols)"; keys ex Space e; sleep 2; panes
expect "broot pane, 40 columns, focused" "$(panes | head -1 | cut -d' ' -f2-4)" "1 40 broot"
echo "== <space>e again: focus"
tm ex select-pane -t main.1; sleep 0.3
tm ex send-keys -t main.1 Space e; sleep 1
expect "broot focused again" "$(tm ex display-message -p -t main '#{pane_current_command}')" broot
tm ex kill-pane -t main.0; sleep 1; panes
echo "== <space>E (buffer dir)"; tm ex select-pane -t main.0; keys ex Space E; sleep 2; panes
expect_match "broot in sub" "$(panes | head -1)" "* broot 1 $P/sub"
tm ex kill-pane -t main.0; sleep 1
expect "debug" "$(dbge ex | tail -3)" ""
stop ex
echo "== plain tmux"
CWD=$P WAIT=2 start tmux ex2 main.c
keys ex2 Space e; sleep 2
tm ex2 list-panes -t main -F '#{pane_id} #{pane_active} #{pane_width} #{pane_current_command}'
stop ex2
echo "== no tmux"
CWD=$P WAIT=2 start notmux ex3 main.c
keys ex3 Space e; sleep 0.5
expect_match "refused" "$(cap ex3 | grep -v '^ *$' | tail -1)" "explorer: needs tmux (:kakmux, kakbr)*"
stop ex3
echo "== kakbr: sidebar focused"
S1=$R/s/$PFX-kakbr-1; echo kb1 >> "$R/sessions"
TMUX= tmux -S "$S1" -f /dev/null new-session -d -s kb -x 160 -y 40 -- sleep 1000
TMUX= tmux -S "$S1" split-window -h -t kb -- sleep 1000
TMUX= tmux -S "$S1" set-option -w -t kb @kakbr_side %0; TMUX= tmux -S "$S1" select-pane -t %1
CWD=$P WAIT=2 start kakmux ex4 main.c
tm ex4 set-option -t main @outer_pane "$S1 %1"
keys ex4 Space e; sleep 1
expect "outer sidebar pane focused" "$(TMUX= tmux -S "$S1" list-panes -t kb -F '#{pane_id} #{pane_active}' | tr '\n' ' ')" "%0 1 %1 0 "
expect "no explorer in the kakmux" "$(tm ex4 list-panes -t main -F '#{pane_id}')" "%0"
TMUX= tmux -S "$S1" kill-server
