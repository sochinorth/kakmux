# auto-save: kakmux writes when the terminal loses focus, not when moving
# between its own splits; a failed write is reported; plain tmux: kak's own
# FocusOut writes
# golden
# covers: rc/editor.kak rc/splits.kak kakmux.conf scripts/kakmux
. "$(dirname "$0")/../lib/h.sh"
D=$R/p/as; mkdir -p "$D/sub"; echo one > "$D/a.txt"; echo two > "$D/sub/b.txt"
CWD=$D start kakmux r a.txt
attachf r
send r 'vsplit'; panes r 2
send r 'execute-keys "ia-edit<esc>"'
echo "== move between splits (tmux select-pane): no write"
# sel PANE: focus that split, until kak has had its FocusOut/FocusIn
sel() {
	tm r select-pane -t "main.$1"
	waitout 5 "$(tm r display-message -p -t "main.$1" '#{@kak_client}')" qv r '%opt{focused_client}'; idle r
}
sel 1; sel 0; sel 1
expect "a.txt not written" "$(cat "$D/a.txt")" one
q r 'modified: %val{modified}'
echo "== the terminal loses focus: written"
term r '\033[O'
expectw "a.txt written on focus-out" a-editone cat "$D/a.txt"
term r '\033[I'
echo "== write fails (directory gone): reported"
send r 'edit sub/b.txt; execute-keys "ib-edit<esc>"'
rm -rf "$D/sub"
term r '\033[O'
reported() { dbge r | grep -q '^auto-save:'; }
waitfor 10 reported
term r '\033[I'
dbge r
cap r | tail -1
stop r
echo "== plain tmux (not kakmux): kak's FocusOut writes"
echo one > "$D/a.txt"
CWD=$D start tmux t a.txt
tm t set -g focus-events on
tm t split-window -d -t main -- sleep 100000
attachf t
send t 'execute-keys "ia-edit<esc>"'
tm t select-pane -t main.1
expectw "plain tmux: written on pane change" a-editone cat "$D/a.txt"
