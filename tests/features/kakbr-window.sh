# kakbr-window: <c-w> in kakbr's broot shows its keys' legend (a popup,
# kakbr.conf and kakbr/window-keys) at the bottom right of broot's pane;
# l, → and w move to kak, q quits (z floats broot: kakbr-float), any other
# key (<esc> too) closes it and is dropped, as in kak's own <c-w>, which is
# still kak's in kak
. "$(dirname "$0")/../lib/h.sh"
need broot
P=$R/p/proj; mkproj "$P"
# a kakbr (shell/kakmux.zsh's kakbr()) on this run's config: broot's pane
# (@kakbr_sidebar) beside a kakmux, whose end ends it
echo kb >> "$R/sessions"; echo kbt >> "$R/sessions"
S=$R/s/$PFX-tmux-kb K=$PFX-kb
tb() { TMUX= tmux -S "$S" "$@"; }
tb -f "$KM_SRC/kakbr/kakbr.conf" new-session -d -s "$K" -x 160 -y 45 -c "$P" -- sh -c '"$@"; tmux kill-session -t "$TMUX_PANE"' sh kakmux -s "$K" main.c
tb split-window -h -b -d -t "$K".0 -c "$P" -l "$(tb display-message -p -t "$K" '#{E:@kakbr_width}')" -- env KAKBR_SESSION="$K" kakbr-sidebar
tb set-option -p -t "$K".0 @kakbr_sidebar 1
tb set-option -w -t "$K" @kakbr_kak "$(tb display-message -p -t "$K".1 '#{pane_id}')"
waitkak kb; sleep 2
tb select-pane -t "$K".0
# its client, in a pane of another tmux: that one's screen shows the popup
# (kakbr's own panes' don't)
tt() { TMUX= tmux -S "$R/s/$PFX-tmux-kbt" "$@"; }
tt -f /dev/null new-session -d -s main -x 160 -y 45 -- env TMUX= tmux -S "$S" attach -t "$K"
tt set-option -g status off
sleep 1
scr() { tt capture-pane -p -t main "$@"; }
tk() { tt send-keys -t main "$@"; sleep 0.6; }
active() { tb display-message -p -t "$K" '#{pane_index}'; }
broot_w=$(tb display-message -p -t "$K".0 '#{pane_width}')
legend() { scr | grep -c 'w: *next pane'; }
# broot's screen (its pane's own, under any popup)
broot_scr() { tb capture-pane -p -t "$K".0; }

echo "== <c-w> in broot"
tk C-w
scr | tail -8 | python3 -c 'import sys; [print(l.rstrip("\n")[:int(sys.argv[1])]) for l in sys.stdin]' "$broot_w"
expect "legend shown" "$(legend)" 1
expect "legend's keys" "$(scr | grep -o -e '│ [^│]*: [^│]*│' | sed 's/  *│$//; s/^│ //')" \
	"l,<right>: focus kak
w:         next pane
z:         float
q:         quit all"
# its right edge on broot's, above broot's two last lines
expect_match "legend at the bottom right" "$(scr | tail -3 | head -1)" "*╰─*─╯│*"
expect_match "titled" "$(scr | tail -8 | head -1)" "*╭─*window*─╮│*"
expect_match "legend in Information's colours" "$(scr -e | grep 'w: *next pane')" "*171;178;191*44;50;60*w: *next pane*"
expect "still in broot" "$(active)" 0
tk l
expect "l: legend gone" "$(legend)" 0
expect "l: in kak" "$(active)" 1

echo "== <c-w> in kak: kak's own window mode"
tk C-w
expect "no legend" "$(legend)" 0
expect "kak's window mode" "$(scr | grep -c 'focus right')" 1
tk i
expect "kak: an unknown key closes it" "$(scr | grep -c 'focus right')" 0
expect "kak: and is dropped (no insert mode)" "$(scr | grep -c ' INS ')" 0
expect "still in kak" "$(active)" 1

echo "== <esc>"
tb select-pane -t "$K".0; sleep 0.3
tk C-w; expect "shown" "$(legend)" 1
tk Escape
expect "<esc>: legend gone" "$(legend)" 0
expect "<esc>: still in broot" "$(active)" 0
expect "broot still there" "$(scr | grep -c '? for help')" 1

echo "== an unknown key"
before=$(broot_scr)
tk C-w; expect "shown" "$(legend)" 1
tk x
expect "x: legend gone" "$(legend)" 0
expect "x: still in broot" "$(active)" 0
expect "x: dropped (broot's screen as it was)" "$(broot_scr)" "$before"

echo "== → and w"
tk C-w; tk Right
expect "→: in kak, legend gone" "$(active) $(legend)" "1 0"
tb select-pane -t "$K".0; sleep 0.3
tk C-w; tk w
expect "w: in kak, legend gone" "$(active) $(legend)" "1 0"

# typed fast: 10 ms apart. (In one write, as send-keys C-w l, the popup's
# shell loses the l: it gets there before the shell has the terminal.)
echo "== <c-w> l 10 ms apart"
tb select-pane -t "$K".0; sleep 0.3
tt send-keys -t main C-w; sleep 0.01; tt send-keys -t main l; sleep 0.8
expect "fast l: in kak, legend gone" "$(active) $(legend)" "1 0"

echo "== q"
tb select-pane -t "$K".0; sleep 0.3
tk C-w; tk q
k=0; while printf 'nop\n' | kak -p "$K" 2>/dev/null && [ $k -lt 50 ]; do sleep 0.1; k=$((k + 1)); done
expect "q: kak ended" "$(printf 'nop\n' | kak -p "$K" 2>/dev/null && echo up || echo gone)" gone
sleep 0.5
expect "q: kakbr ended" "$(tb has-session 2>/dev/null && echo up || echo gone)" gone
