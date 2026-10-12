# auto-save: kakmux writes when the terminal loses focus, not when moving
# between its own splits; a failed write is reported; plain tmux: kak's own
# FocusOut writes
# golden
. "$(dirname "$0")/../lib/h.sh"
D=$R/p/as; mkdir -p "$D/sub"; echo one > "$D/a.txt"; echo two > "$D/sub/b.txt"
CWD=$D WAIT=2 start kakmux r a.txt
attachf r
send r 'vsplit'
sleep 1
send r 'execute-keys "ia-edit<esc>"'
echo "== move between splits (tmux select-pane): no write"
tm r select-pane -t main.1; sleep 0.6; tm r select-pane -t main.0; sleep 0.6; tm r select-pane -t main.1; sleep 0.8
expect "a.txt not written" "$(cat "$D/a.txt")" one
q r 'modified: %val{modified}'
echo "== the terminal loses focus: written"
term r '\033[O'
sleep 1
expect "a.txt written on focus-out" "$(cat "$D/a.txt")" a-editone
term r '\033[I'
echo "== write fails (directory gone): reported"
send r 'edit sub/b.txt; execute-keys "ib-edit<esc>"'
rm -rf "$D/sub"
term r '\033[O'
sleep 1
term r '\033[I'
dbge r
cap r | tail -1
stop r
echo "== plain tmux (not kakmux): kak's FocusOut writes"
echo one > "$D/a.txt"
CWD=$D WAIT=2 start tmux t a.txt
tm t set -g focus-events on
tm t split-window -d -t main -- sleep 100000
attachf t
send t 'execute-keys "ia-edit<esc>"'
tm t select-pane -t main.1; sleep 1
expect "plain tmux: written on pane change" "$(cat "$D/a.txt")" a-editone
