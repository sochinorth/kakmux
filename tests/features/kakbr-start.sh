# kakbr-start: kakbr (shell/kakmux.zsh's kakbr(), as is, in a terminal: a
# pane of another tmux) starts with broot drawn at its pane's size: its
# status line, whole, right above its input line at the bottom. (Started
# alone at the window's width, then sized, broot missed the resize and drew
# at the old width, its status line wrapped: about 1 start in 3.) Six
# times: a race.
# covers: shell/kakmux.zsh kakbr/* scripts/kakbr-sidebar scripts/kakmux
. "$(dirname "$0")/../lib/h.sh"
need broot zsh
P=$R/p/proj; mkproj "$P"
# kakbr() on this run's paths
sed -e "s|~/.config/kakbr|$R/config/kakbr|g" -e "s|~/.local/bin|$R/bin|g" \
	"$KM_SRC/shell/kakmux.zsh" > "$R/kakmux.zsh"
echo 'set -g status off' > "$R/outer.conf"
echo kst >> "$R/sessions"
tt() { TMUX= tmux -S "$R/s/$PFX-tmux-kst" "$@"; }
socks=$R/tmux/tmux-$(id -u)

for i in $(seq ${KST_N:-6}); do
	echo "== start $i"
	tt -f "$R/outer.conf" new-session -d -s main -x 100 -y 50 -c "$P" -- \
		zsh -fc ". '$R/kakmux.zsh'; kakbr"
	# kakbr-PID: its tmux server's and kak's session's name (the earlier
	# ones' sockets are left behind)
	k=0; name=
	while [ -z "$name" ] && [ $k -lt 50 ]; do
		sleep 0.1; k=$((k + 1))
		for n in $(ls "$socks" 2>/dev/null | grep '^kakbr-'); do
			TMUX= tmux -L "$n" has-session 2>/dev/null && name=$n
		done
	done
	tb() { TMUX= tmux -L "$name" "$@"; }
	side=$(tb show-options -wv @kakbr_side 2>/dev/null)
	k=0; while ! tt capture-pane -p -t main | grep -q 'Hit enter' && [ $k -lt 100 ]; do
		sleep 0.1; k=$((k + 1)); side=$(tb show-options -wv @kakbr_side 2>/dev/null)
	done
	# until broot's status line sits right above its input line (as it
	# should; one that missed the resize stays wrapped: 5 s, then the expects)
	settled() {
		set -- $(tb display-message -p -t "$side" '#{pane_width} #{pane_height}')
		[ "$(tt capture-pane -p -t main | cut -c1-"$1" | grep -n 'Hit enter' | cut -d: -f1)" = $(($2 - 1)) ]
	}
	waitfor 5 settled
	set -- $(tb display-message -p -t "$side" '#{pane_width} #{pane_height}')
	expect "broot at its width" "$1" 25
	# the screen as the terminal shows it, broot's columns
	scr=$(tt capture-pane -p -t main | cut -c1-"$1")
	expect "status line right above the input line" "$(printf '%s\n' "$scr" | grep -n 'Hit enter' | cut -d: -f1)" $(($2 - 1))
	printf 'kill!\n' | kak -p "$name"
	k=0; while tt has-session 2>/dev/null && [ $k -lt 50 ]; do sleep 0.1; k=$((k + 1)); done
	expect "kakbr ended" "$(tt has-session 2>/dev/null && echo up || echo gone)" gone
done
