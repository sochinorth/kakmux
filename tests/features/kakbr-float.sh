# kakbr-float: <c-w> z in kakbr's broot floats the same broot (its filter
# kept) over kak, 90% of the window (kakbr/float: a floating pane), kak
# taking the whole layout; <c-w> z again, <esc> with nothing left to undo,
# kak focused (a click), <c-w> l or a file opened dock it back at its width
# (its legend: z and q only); kak ending ends it all
. "$(dirname "$0")/../lib/h.sh"
need broot
P=$R/p/proj; mkproj "$P"
echo kf >> "$R/sessions"; echo kft >> "$R/sessions"
S=$R/s/$PFX-tmux-kf K=$PFX-kf
tb() { TMUX= tmux -S "$S" "$@"; }
tb -f "$KM_SRC/kakbr/kakbr.conf" new-session -d -s "$K" -x 160 -y 45 -c "$P" -- env KAKBR_SESSION="$K" kakbr-sidebar
tb set-option -p -t "$K".0 @kakbr_sidebar 1
tb split-window -h -t "$K".0 -c "$P" -- sh -c '"$@"; tmux kill-session -t "$TMUX_PANE"' sh kakmux -s "$K" main.c
tb set-option -w -t "$K" @kakbr_kak "$(tb display-message -p -t "$K".1 '#{pane_id}')"
waitkak kf; sleep 2
side=$(tb display-message -p -t "$K".0 '#{pane_id}')
tb select-pane -t "$side"
tt() { TMUX= tmux -S "$R/s/$PFX-tmux-kft" "$@"; }
tt -f /dev/null new-session -d -s main -x 160 -y 45 -- env TMUX= tmux -S "$S" attach -t "$K"
tt set-option -g status off
sleep 1
scr() { tt capture-pane -p -t main "$@"; }
tk() { tt send-keys -t main "$@"; sleep 0.6; }
# where broot's pane is: "docked WIDTH" (left of kak) or "floated WxH"
where() {
	set -- $(tb display-message -p -t "$side" '#{pane_floating_flag} #{pane_width} #{pane_height} #{pane_left}')
	if [ "$1" = 1 ]; then echo "floated $2x$3"; elif [ "$4" = 0 ]; then echo "docked $2"; else echo "? $*"; fi
}
tiled() { tb list-panes -t "$K:" -f '#{!:#{pane_floating_flag}}' -F '#{pane_id}' | tr '\n' ' '; }
active() { tb display-message -p -t "$K:" '#{pane_id}'; }
popup() { scr | grep -c '┌─* broot ─*┐'; }
w0=$(tb display-message -p -t "$side" '#{pane_width}')
kak=$(tb display-message -p -t "$K".1 '#{pane_id}')

echo "== <c-w> z: floated"
tk m a; sleep 0.5
tk C-w
expect "legend: z floats" "$(scr | grep -c 'z: *float')" 1
tk z; sleep 0.5
# 90% of 160x45, less the border
expect "floated, 90% of the window" "$(where)" "floated 142x38"
expect "titled" "$(popup)" 1
expect "kak alone in the layout, the window's width" "$(tiled)$(tb display-message -p -t "$kak" '#{pane_width}')" "$kak 160"
expect "the same broot, its filter kept" "$(scr | grep -c '│ma ')" 1
expect "focused" "$(active)" "$side"
expect_match "in kak's popup colours (border)" "$(scr -e | grep ' broot ')" "*171;178;191*44;50;60*┌*"
expect_match "in kak's popup colours (inside)" "$(scr -e | grep 'kefile')" "*48;2;44;50;60*kefile*"

# (broot's <esc> clears the filter, then goes back a state: here, to the
# root selected as it started)
echo "== <esc>: broot's first, then docks"
tk Escape
expect "<esc>: filter cleared, still floated" "$(where) $(scr | grep -c '│ma ')" "floated 142x38 0"
tk Escape
expect "<esc>: back to broot's first state, still floated" "$(where)" "floated 142x38"
tk Escape
expect "<esc> with nothing left: docked, at its width" "$(where)" "docked $w0"
expect "popup gone" "$(popup)" 0
expect "broot left of kak, focused" "$(tiled)$(active)" "$side $kak $side"
expect "its own colours again" "$(tb show-options -p -t "$side" window-style)" ""
tk m a
expect "docked: a filter" "$(scr | grep -c '^ma ')" 1
tk Escape
expect "docked: <esc> is broot's (filter cleared)" "$(where) $(scr | grep -c '^ma ')" "docked $w0 0"
tk Escape
expect "docked: <esc> stays docked" "$(where)" "docked $w0"

echo "== <c-w> z twice"
tk C-w; tk z; sleep 0.5
expect "floated" "$(where)" "floated 142x38"
tk C-w
expect "legend: z docks" "$(scr | grep -c 'z: *dock')" 1
expect "legend: z and q only" "$(scr | grep -o -e '│ [^│]*: [^│]*│' | sed 's/  *│$//; s/^│ //' | tr '\n' ',')" "z: dock,q: quit all,"
tk z; sleep 0.5
expect "docked" "$(where) $(popup)" "docked $w0 0"
expect "broot focused" "$(active)" "$side"

echo "== a width set by hand kept"
tb resize-pane -t "$side" -x 33; sleep 0.5
tk C-w; tk z; sleep 0.5
tk C-w; tk z; sleep 0.5
expect "docked at 33" "$(where)" "docked 33"
tb resize-pane -t "$side" -x "$w0"; sleep 0.5

echo "== floated, kak focused (a click on it: select-pane): docked"
tk C-w; tk z; sleep 0.5
tb select-pane -t "$kak"; sleep 0.5
expect "docked, in kak" "$(where) $(active) $(popup)" "docked $w0 $kak 0"
tb select-pane -t "$side"; sleep 0.3

echo "== floated, <c-w> l: docked, kak focused"
tk C-w; tk z; sleep 0.5
tk C-w; tk l; sleep 0.5
expect "docked, in kak" "$(where) $(active) $(popup)" "docked $w0 $kak 0"
tb select-pane -t "$side"; sleep 0.3

echo "== floated, a file opened: docked, kak has it"
tk C-w; tk z; sleep 0.5
tk p o i n t . h; sleep 0.5; tk Enter; sleep 1
expect "opened" "$(printf 'eval -client client0 %%{ echo -to-file %s %%val{bufname} }\n' "$R/o/buf" | kak -p "$K"; sleep 0.3; cat "$R/o/buf")" point.h
expect "docked, in kak" "$(where) $(active) $(popup)" "docked $w0 $kak 0"
tb select-pane -t "$side"; tk Escape

echo "== the window resized while floated, then after"
tk C-w; tk z; sleep 0.5
tt resize-window -t main -x 140; sleep 1
expect "floated still" "$(where | cut -d' ' -f1)" floated
tk C-w; tk z; sleep 0.5
expect "docked at the new window's width" "$(where)" "docked 35"
tt resize-window -t main -x 120; sleep 1
expect "120 columns: 30, as ever" "$(where)" "docked 30"

echo "== floated, kak ends: kakbr ends"
tk C-w; tk z; sleep 0.5
printf 'kill!\n' | kak -p "$K"
k=0; while tb has-session 2>/dev/null && [ $k -lt 50 ]; do sleep 0.1; k=$((k + 1)); done
expect "server gone" "$(tb list-sessions 2>/dev/null | wc -l)" 0
