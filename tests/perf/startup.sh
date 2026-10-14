# startup: ms from starting kak to its first paint (the status line showing
# 1:1) in a tmux pane; kak -n and the stock rc alone for scale; kak -c
# attaching to a running server. Median of N (default 10) each.
# tags: serial
# covers: kakrc rc/*.kak
. "$(dirname "$0")/../lib/h.sh"
N=${N:-10}
P=$R/p/proj; mkproj "$P"
S=$R/s/$PFX-tmux-st; echo st >> "$R/sessions"
TMUX= tmux -S "$S" -f /dev/null new-session -d -s main -x 160 -y 45 -- sleep 100000
waitfor 5 env TMUX= tmux -S "$S" has-session
run() { # CMD...: one timing, ms
	TMUX= tmux -S "$S" respawn-pane -k -t main "sleep 100000"
	sleep 0.3   # the last one's teardown out of the way of this timing
	t0=$(date +%s%N)
	TMUX= tmux -S "$S" respawn-pane -k -t main -c "$P" "$*; sleep 100000"
	k=0
	until TMUX= tmux -S "$S" capture-pane -p -t main | grep -q ' 1:1'; do k=$((k + 1)); [ $k -gt 5000 ] && break; done
	t1=$(date +%s%N)
	echo $(( (t1 - t0) / 1000000 ))
}
med() { sort -n | awk '{ a[NR] = $1 } END { print a[int((NR + 1) / 2)] }'; }
kill_st() {
	printf 'kill!\n' | kak -p "$PFX-st" 2>/dev/null
	waitfor 5 _gone
	d=$XDG_RUNTIME_DIR/kakoune-lsp/$PFX-st
	[ -e "$d/pid" ] && kill "$(cat "$d/pid")" 2>/dev/null; rm -rf "$d" "$d.ref"
}
# _gone: the st session's socket is gone (kak ends)
_gone() { [ ! -e "$XDG_RUNTIME_DIR/kakoune/$PFX-st" ]; }
timing() { i=0; while [ $i -lt "$N" ]; do run "$@"; kill_st; i=$((i + 1)); done | med; }
# a first run to fill the plugin cache (as after an install)
run kak -s "$PFX-st" main.c >/dev/null; kill_st
n=$(timing kak -n -s "$PFX-st" main.c); metric start-kak-n "$n" ms
stock=$(timing env KAKOUNE_CONFIG_DIR="$R/emptycfg" kak -s "$PFX-st" main.c); metric start-stock-rc "$stock" ms
full=$(timing kak -s "$PFX-st" main.c); metric start-kakrc "$full" ms
expect_le "first paint with the kakrc (ms, median of $N)" "$full" 600
# a server to attach to (warm: started, its idle work done)
(cd "$P" && kak -d -s "$PFX-st" main.c &)
waitkak st; pid=$(pgrep -f "^kak -d -s $PFX-st" | head -1)
quiet 10
i=0; while [ $i -lt "$N" ]; do run kak -c "$PFX-st" -e "'edit main.c'"; i=$((i + 1)); done | med > "$R/o/att"
kill_st
metric attach "$(cat "$R/o/att")" ms
expect_le "kak -c attach (ms, median of $N)" "$(cat "$R/o/att")" 300
