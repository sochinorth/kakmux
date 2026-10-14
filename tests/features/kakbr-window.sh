# kakbr-window: <c-w> in kakbr's broot shows its keys' legend (a popup,
# kakbr.conf and kakbr/window-keys) at the bottom right of broot's pane;
# l, → and w move to kak, q quits (z floats broot: kakbr-float), any other
# key (<esc> too) closes it and is dropped, as in kak's own <c-w>, which is
# still kak's in kak
# covers: kakbr/* scripts/kakbr-sidebar rc/splits.kak
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
waitkak kb; waitcap kb '\? for help' 15 "$K".0 || fail "broot not drawn"
tb select-pane -t "$K".0
# its client, in a pane of another tmux: that one's screen shows the popup
# (kakbr's own panes' don't)
tt() { TMUX= tmux -S "$R/s/$PFX-tmux-kbt" "$@"; }
tt -f /dev/null new-session -d -s main -x 160 -y 45 -- env TMUX= tmux -S "$S" attach -t "$K"
tt set-option -g status off
scr() { tt capture-pane -p -t main "$@"; }
waitcap kbt '\? for help' || fail "client not attached"
tk() { tt send-keys -t main "$@"; settle scr > /dev/null; }
active() { tb display-message -p -t "$K" '#{pane_index}'; }
broot_w=$(tb display-message -p -t "$K".0 '#{pane_width}')
legend() { scr | grep -c 'w: *next pane'; }
al() { echo "$(active) $(legend)"; }
# cw: <c-w>, until its legend is up (keys before it go to broot)
cw() { tk C-w; waitfor 5 legend > /dev/null; }
# sel PANE: focus PANE, the hooks' :refresh to broot done
sel() { tb select-pane -t "$1"; settle scr > /dev/null; }
# broot's screen (its pane's own, under any popup)
broot_scr() { tb capture-pane -p -t "$K".0; }

echo "== <c-w> in broot"
cw
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
expectw "l: legend gone" 0 legend
expectw "l: in kak" 1 active

echo "== <c-w> in kak: kak's own window mode"
kwm() { scr | grep -c 'focus right'; }
tk C-w
expectw "kak's window mode" 1 kwm
expect "no legend" "$(legend)" 0
tk i
expectw "kak: an unknown key closes it" 0 kwm
expect "kak: and is dropped (no insert mode)" "$(scr | grep -c ' INS ')" 0
expect "still in kak" "$(active)" 1

echo "== <esc>"
sel "$K".0
cw; expect "shown" "$(legend)" 1
tk Escape
expectw "<esc>: legend gone" 0 legend
expect "<esc>: still in broot" "$(active)" 0
expect "broot still there" "$(scr | grep -c '? for help')" 1

echo "== an unknown key"
before=$(broot_scr)
cw; expect "shown" "$(legend)" 1
tk x
expectw "x: legend gone" 0 legend
expect "x: still in broot" "$(active)" 0
expect "x: dropped (broot's screen as it was)" "$(broot_scr)" "$before"

echo "== → and w"
cw; tk Right
expectw "→: in kak, legend gone" "1 0" al
sel "$K".0
cw; tk w
expectw "w: in kak, legend gone" "1 0" al

# typed fast: 10 ms apart. (In one write, as send-keys C-w l, the popup's
# shell loses the l: it gets there before the shell has the terminal.)
echo "== <c-w> l 10 ms apart"
sel "$K".0
tt send-keys -t main C-w; sleep 0.01; tt send-keys -t main l
expectw "fast l: in kak, legend gone" "1 0" al

echo "== q"
sel "$K".0
cw; tk q
k=0; while printf 'nop\n' | kak -p "$K" 2>/dev/null && [ $k -lt 50 ]; do sleep 0.1; k=$((k + 1)); done
expect "q: kak ended" "$(printf 'nop\n' | kak -p "$K" 2>/dev/null && echo up || echo gone)" gone
k=0; while tb has-session 2>/dev/null && [ $k -lt 50 ]; do sleep 0.1; k=$((k + 1)); done
expect "q: kakbr ended" "$(tb has-session 2>/dev/null && echo up || echo gone)" gone
