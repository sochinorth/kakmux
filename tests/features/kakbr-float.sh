# kakbr-float: <c-w> z in kakbr's broot floats the same broot (its filter
# kept) over kak, 90% of the window (kakbr/float: a floating pane), kak
# taking the whole layout; <c-w> z again, <esc> with nothing left to undo,
# kak focused (a click), <c-w> l or a file opened dock it back at its width
# (its legend: z and q only); kak ending ends it all
# covers: kakbr/* scripts/kakbr-sidebar scripts/kakmux rc/splits.kak
. "$(dirname "$0")/../lib/h.sh"
need broot
P=$R/p/proj; mkproj "$P"
echo kf >> "$R/sessions"; echo kft >> "$R/sessions"
S=$R/s/$PFX-tmux-kf K=$PFX-kf
tb() { TMUX= tmux -S "$S" "$@"; }
tb -f "$KM_SRC/kakbr/kakbr.conf" new-session -d -s "$K" -x 160 -y 45 -c "$P" -- sh -c '"$@"; tmux kill-session -t "$TMUX_PANE"' sh kakmux -s "$K" main.c
tb split-window -h -b -d -t "$K".0 -c "$P" -l "$(tb display-message -p -t "$K" '#{E:@kakbr_width}')" -- env KAKBR_SESSION="$K" kakbr-sidebar
tb set-option -p -t "$K".0 @kakbr_sidebar 1
tb set-option -w -t "$K" @kakbr_kak "$(tb display-message -p -t "$K".1 '#{pane_id}')"
waitkak kf; waitcap kf '\? for help' 15 "$K".0 || fail "broot not drawn"
side=$(tb display-message -p -t "$K".0 '#{pane_id}')
tb select-pane -t "$side"
tt() { TMUX= tmux -S "$R/s/$PFX-tmux-kft" "$@"; }
tt -f /dev/null new-session -d -s main -x 160 -y 45 -- env TMUX= tmux -S "$S" attach -t "$K"
tt set-option -g status off
scr() { tt capture-pane -p -t main "$@"; }
waitcap kft '\? for help' || fail "client not attached"
# settled: no kakbr/float of this run running (floated, <esc> waits 150 ms
# to see what broot did with it, then may dock), the screen still
calm() {
	for p in $(pgrep -f '/kakbr/float '); do grep -qzx "KM_RUN_ID=$KM_RUN_ID" "/proc/$p/environ" 2>/dev/null && return 1; done
	return 0
}
settled() { waitfor 5 calm; settle scr > /dev/null; }
tk() { tt send-keys -t main "$@"; settled; }
# where broot's pane is: "docked WIDTH" (left of kak) or "floated WxH"
where() {
	set -- $(tb display-message -p -t "$side" '#{pane_floating_flag} #{pane_width} #{pane_height} #{pane_left}')
	if [ "$1" = 1 ]; then echo "floated $2x$3"; elif [ "$4" = 0 ]; then echo "docked $2"; else echo "? $*"; fi
}
tiled() { tb list-panes -t "$K:" -f '#{!:#{pane_floating_flag}}' -F '#{pane_id}' | tr '\n' ' '; }
active() { tb display-message -p -t "$K:" '#{pane_id}'; }
popup() { scr | grep -c '┌─* broot ─*┐'; }
legend() { scr | grep -c "$1"; }
filtered() { scr | grep -c "$1"'ma '; }
wpa() { echo "$(where) $(active) $(popup)"; }
w0=$(tb display-message -p -t "$side" '#{pane_width}')
kak=$(tb display-message -p -t "$K".1 '#{pane_id}')
# besc: <esc> to docked broot, until its screen shows it (what else it
# does: broot takes a while with a lone <esc>, a key sooner can be lost)
besc() {
	scr -e > "$R/o/esc0"; tt send-keys -t main Escape
	waitfor 3 sh -c '[ "$(TMUX= tmux -S "$0" capture-pane -ep -t main)" != "$(cat "$1")" ]' "$R/s/$PFX-tmux-kft" "$R/o/esc0"
	settled
}
floated() { where | grep -q '^floated'; }
# cwz: <c-w> z, once the legend is up (keys before it go to broot)
cwz() { tk C-w; waitfor 5 legend 'z: *' > /dev/null; tk z; }

echo "== <c-w> z: floated"
tk m a
waitcap kft '^ma ' 5
tk C-w
expectw "legend: z floats" 1 legend 'z: *float'
tk z
# 90% of 160x45, less the border
expectw "floated, 90% of the window" "floated 142x38" where
expectw "titled" 1 popup
expect "kak alone in the layout, the window's width" "$(tiled)$(tb display-message -p -t "$kak" '#{pane_width}')" "$kak 160"
expectw "the same broot, its filter kept" 1 filtered '│'
expect "focused" "$(active)" "$side"
expect_match "in kak's popup colours (border)" "$(scr -e | grep ' broot ')" "*171;178;191*44;50;60*┌*"
expect_match "in kak's popup colours (inside)" "$(scr -e | grep 'kefile')" "*48;2;44;50;60*kefile*"

# (broot's <esc> clears the filter, then goes back a state: here, to the
# root selected as it started)
echo "== <esc>: broot's first, then docks"
# (each: broot's screen changes first, then float esc decides)
tk Escape; waitfor 5 sh -c '! TMUX= tmux -S "$0" capture-pane -p -t main | grep -q "│ma "' "$R/s/$PFX-tmux-kft"; settled
expect "<esc>: filter cleared, still floated" "$(where) $(filtered '│')" "floated 142x38 0"
before=$(scr)
tk Escape; waitfor 5 sh -c '[ "$(TMUX= tmux -S "$0" capture-pane -p -t main)" != "$1" ]' "$R/s/$PFX-tmux-kft" "$before"; settled
expect "<esc>: back to broot's first state, still floated" "$(where)" "floated 142x38"
tk Escape
expectw "<esc> with nothing left: docked, at its width" "docked $w0" where
expectw "popup gone" 0 popup
expect "broot left of kak, focused" "$(tiled)$(active)" "$side $kak $side"
expect "its own colours again" "$(tb show-options -p -t "$side" window-style)" ""
tk m a
expectw "docked: a filter" 1 filtered '^'
besc
wf() { echo "$(where) $(filtered '^')"; }
expectw "docked: <esc> is broot's (filter cleared)" "docked $w0 0" wf
besc
expect "docked: <esc> stays docked" "$(where)" "docked $w0"

echo "== <c-w> z twice"
cwz
expectw "floated" "floated 142x38" where
tk C-w
expectw "legend: z docks" 1 legend 'z: *dock'
expect "legend: z and q only" "$(scr | grep -o -e '│ [^│]*: [^│]*│' | sed 's/  *│$//; s/^│ //' | tr '\n' ',')" "z: dock,q: quit all,"
tk z
wp() { echo "$(where) $(popup)"; }
expectw "docked" "docked $w0 0" wp
expect "broot focused" "$(active)" "$side"

echo "== a width set by hand kept"
tb resize-pane -t "$side" -x 33; settled
cwz; waitout 5 "floated 142x38" where
cwz; waitout 5 "docked 33" where
expect "docked at 33" "$(where)" "docked 33"
tb resize-pane -t "$side" -x "$w0"; settled

echo "== floated, kak focused (a click on it: select-pane): docked"
cwz; waitout 5 "floated 142x38" where
tb select-pane -t "$kak"
expectw "docked, in kak" "docked $w0 $kak 0" wpa
tb select-pane -t "$side"; settled

echo "== floated, <c-w> l: docked, kak focused"
cwz; waitout 5 "floated 142x38" where
tk C-w; waitfor 5 legend 'z: *' > /dev/null; tk l
expectw "docked, in kak" "docked $w0 $kak 0" wpa
tb select-pane -t "$side"; settled

echo "== floated, a file opened: docked, kak has it"
cwz; waitout 5 "floated 142x38" where
tk p o i n t . h; waitcap kft 'point\.h' 5; tk Enter
expectw "opened" point.h qv kf '%val{bufname}'
expectw "docked, in kak" "docked $w0 $kak 0" wpa
tb select-pane -t "$side"; settled
tt send-keys -t main Escape; waitfor 5 sh -c '! TMUX= tmux -S "$0" capture-pane -p -t main | grep -q "^point\.h"' "$R/s/$PFX-tmux-kft"; settled

echo "== the window resized while floated, then after"
cwz; waitout 5 "floated 142x38" where
tt resize-window -t main -x 140
waitout 5 140 tb display-message -p -t "$K:" '#{window_width}'; settled
expect "floated still" "$(where | cut -d' ' -f1)" floated
cwz
expectw "docked at the new window's width" "docked 35" where
tt resize-window -t main -x 120
expectw "120 columns: 30, as ever" "docked 30" where

echo "== floated, kak ends: kakbr ends"
cwz; waitfor 5 floated
printf 'kill!\n' | kak -p "$K"
k=0; while tb has-session 2>/dev/null && [ $k -lt 50 ]; do sleep 0.1; k=$((k + 1)); done
expect "server gone" "$(tb list-sessions 2>/dev/null | wc -l)" 0
