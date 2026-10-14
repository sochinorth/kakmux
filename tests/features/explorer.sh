# explorer: <space>e/<space>E open broot beside kak (kakmux, plain tmux), focus
# it when open; refused without tmux; in kakbr, focus the sidebar
# golden
# covers: rc/pickers.kak rc/splits.kak kakbr/* scripts/kakmux
. "$(dirname "$0")/../lib/h.sh"
need broot
P=$R/p/proj; mkproj "$P"
mkdir -p "$P/sub"; echo hi > "$P/sub/s.txt"
CWD=$P start kakmux ex sub/s.txt
# PL: the panes (golden); PL1: the first one's active, width, command
PL() { tm ex list-panes -t main -F '#{pane_id} #{pane_active} #{pane_width} #{pane_current_command} #{@kak_explorer} #{pane_current_path}'; }
PL1() { PL | head -1 | cut -d' ' -f2-4; }
CMD() { tm ex display-message -p -t main '#{pane_current_command}'; }
NP() { tm ex list-panes -t main -F x | grep -c .; }
echo "== <space>e (kakmux, 160 cols)"; keys ex Space e; waitout 10 "1 40 broot" PL1; settle PL
expect "broot pane, 40 columns, focused" "$(PL1)" "1 40 broot"
echo "== <space>e again: focus"
tm ex select-pane -t main.1
tm ex send-keys -t main.1 Space e
expectw "broot focused again" broot CMD
tm ex kill-pane -t main.0; waitout 10 1 NP; settle PL
echo "== <space>E (buffer dir)"; tm ex select-pane -t main.0; keys ex Space E
waitfor 10 _outlike "* broot 1 $P/sub" eval 'PL | head -1'; settle PL
expect_match "broot in sub" "$(PL | head -1)" "* broot 1 $P/sub"
tm ex kill-pane -t main.0; waitout 10 1 NP
expect "debug" "$(dbge ex | tail -3)" ""
stop ex
echo "== plain tmux"
CWD=$P start tmux ex2 main.c
PL2() { tm ex2 list-panes -t main -F '#{pane_id} #{pane_active} #{pane_width} #{pane_current_command}'; }
keys ex2 Space e; waitout 10 "%1 1 40 broot" eval 'PL2 | head -1'
settle PL2
stop ex2
echo "== no tmux"
CWD=$P start notmux ex3 main.c
LAST() { cap ex3 | grep -v '^ *$' | tail -1; }
keys ex3 Space e
expectw_match "refused" "explorer: needs tmux (:kakmux, kakbr)*" LAST
stop ex3
echo "== kakbr: sidebar focused"
S1=$R/s/$PFX-kakbr-1; echo kb1 >> "$R/sessions"
TMUX= tmux -S "$S1" -f /dev/null new-session -d -s kb -x 160 -y 40 -- sleep 1000
TMUX= tmux -S "$S1" split-window -h -t kb -- sleep 1000
TMUX= tmux -S "$S1" set-option -w -t kb @kakbr_side %0; TMUX= tmux -S "$S1" select-pane -t %1
CWD=$P start kakmux ex4 main.c
tm ex4 set-option -t main @outer_pane "$S1 %1"
keys ex4 Space e
OP() { TMUX= tmux -S "$S1" list-panes -t kb -F '#{pane_id} #{pane_active}' | tr '\n' ' '; }
expectw "outer sidebar pane focused" "%0 1 %1 0 " OP
expect "no explorer in the kakmux" "$(tm ex4 list-panes -t main -F '#{pane_id}')" "%0"
TMUX= tmux -S "$S1" kill-server
