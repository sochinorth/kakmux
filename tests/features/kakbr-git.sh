# kakbr-git: the sidebar's git marks keep up: a file changed or added shows
# M / N by itself (broot's watch), and a commit (only .git changes) clears
# them as the focus moves, or comes back to kakbr's terminal (kakbr.conf's
# select-pane and client-focus-in hooks: :refresh sent to broot's server,
# kakbr-sidebar's --listen); that server's socket goes with kakbr
# covers: kakbr/* scripts/kakbr-sidebar
. "$(dirname "$0")/../lib/h.sh"
need broot
P=$R/p/proj; mkproj "$P"
echo kg >> "$R/sessions"; echo kgt >> "$R/sessions"
S=$R/s/$PFX-tmux-kg K=$PFX-kg
tb() { TMUX= tmux -S "$S" "$@"; }
tb -f "$KM_SRC/kakbr/kakbr.conf" new-session -d -s "$K" -x 160 -y 45 -c "$P" -- sh -c '"$@"; tmux kill-session -t "$TMUX_PANE"' sh kakmux -s "$K" main.c
tb split-window -h -b -d -t "$K".0 -c "$P" -l "$(tb display-message -p -t "$K" '#{E:@kakbr_width}')" -- env KAKBR_SESSION="$K" kakbr-sidebar
tb set-option -p -t "$K".0 @kakbr_sidebar 1
tb set-option -w -t "$K" @kakbr_kak "$(tb display-message -p -t "$K".1 '#{pane_id}')"
waitkak kg; sleep 2
side=$(tb display-message -p -t "$K".0 '#{pane_id}')
kak=$(tb display-message -p -t "$K".1 '#{pane_id}')
tb select-pane -t "$side"
tt() { TMUX= tmux -S "$R/s/$PFX-tmux-kgt" "$@"; }
tt -f /dev/null new-session -d -s main -x 160 -y 45 -- env TMUX= tmux -S "$S" attach -t "$K"
tt set-option -g status off
sleep 1
# broot's mark left of NAME in the sidebar ("" if none)
mark() { tb capture-pane -p -t "$side" | sed -n "s/^ *\([A-Z]\)[^A-Za-z]*[^ ]*  $1 *\$/\1/p; s/^ *[^A-Z]*  $1 *\$/-/p" | head -1; }
# wait up to 5 s for NAME's mark to be WANT
waitmark() { k=0; while [ "$(mark "$1")" != "$2" ] && [ $k -lt 50 ]; do sleep 0.1; k=$((k + 1)); done; mark "$1"; }
sock=/tmp/broot-server-$K.sock

echo "== broot's server, its watch"
expect "named after kak's session" "$(tb show-options -gv @kakbr_broot)" "$K"
expect "its socket" "$([ -S "$sock" ] && echo yes)" yes
expect "watch on" "$(tb capture-pane -p -t "$side" | grep -c '👁')" 1
expect "clean to start with" "$(mark point.h) $(mark util.c)" "- -"

echo "== a change, a new file: shown by themselves"
echo '/* changed */' >> "$P/point.h"
expect "changed: M" "$(waitmark point.h M)" M
echo new > "$P/new.txt"
expect "new: N" "$(waitmark new.txt N)" N

# from here broot's watch is off (alt-w), so that only the hook refreshes
# it: the watch would also see whatever else changes under the project
# (clangd's .cache)
echo "== a commit: when the focus moves"
tb send-keys -t "$side" M-w; sleep 0.5
expect "watch off" "$(tb capture-pane -p -t "$side" | grep -c '👁')" 0
git -C "$P" add -A; git -C "$P" commit -qm c; sleep 1
expect "a commit alone: still marked" "$(mark point.h)" M
tb select-pane -t "$kak"
expect "focus to kak: refreshed" "$(waitmark point.h -) $(mark new.txt)" "- -"

echo "== a commit elsewhere: when the terminal comes back"
echo '/* again */' >> "$P/point.h"
tb select-pane -t "$side"
expect "changed (and focus moved): M" "$(waitmark point.h M)" M
git -C "$P" commit -qam c2; sleep 1
expect "a commit alone: still marked" "$(mark point.h)" M
# the terminal reports focus out, then in (focus-events)
tt send-keys -t main -H 1b 5b 4f; sleep 0.3; tt send-keys -t main -H 1b 5b 49
expect "focus back: refreshed" "$(waitmark point.h -)" -

echo "== kakbr ends: the socket goes"
printf 'kill!\n' | kak -p "$K"
k=0; while tb has-session 2>/dev/null && [ $k -lt 50 ]; do sleep 0.1; k=$((k + 1)); done
sleep 0.5
expect "socket gone" "$([ -e "$sock" ] && echo left || echo gone)" gone
