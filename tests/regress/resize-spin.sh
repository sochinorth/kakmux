# resize-spin: long wrapped lines with inline diagnostics in narrow, short
# windows, down to a column: kak stays alive and idle through resizes and
# moves
# tags: serial
# covers: rc/inline-diagnostics.kak rc/decorations.kak rc/editor.kak
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
P=$R/p/sp; mkdir -p "$P"; printf -- '-Wall\n' > "$P/compile_flags.txt"
{
	echo '#include <stdio.h>'
	echo 'int main(void)'
	echo '{'
	printf '\tint total = alpha_undefined_one + beta_undefined_two * gamma_undefined_three - delta_undefined_four + epsilon_undefined_five / zeta_undefined_six + eta_undefined_seven + theta_undefined_eight + iota_undefined_nine + kappa_undefined_ten + lambda_undefined_eleven;\n'
	printf '\tprintf("%%d %%s %%f\\n", total, "a very long string literal that goes on and on and on and on and on and on and on and on and on", 1);\n'
	for i in $(seq 1 30); do printf '\tint v%d = unknown_%d(%d); /* a comment that makes the line long enough to wrap in a narrow window, really */\n' $i $i $i; done
	echo '}'
} > "$P/s.c"
# cpu LABEL: % of one cpu over 2 s (time for a spin to show) of session
# $S's kak (pid $pid); fails over 20. Once kak is gone or spinning the
# test stops: nothing after would test anything
cpu() {
	a=$(cputicks "$pid") && sleep 2 && b=$(cputicks "$pid") || {
		fail "kak died at $1"
		tm "$S" capture-pane -p -t main 2>/dev/null | grep -v '^ *$' | tail -3
		exit 1
	}
	expect_le "$1: cpu %" $(( (b - a) / 2 )) 20
	[ $(( (b - a) / 2 )) -le 20 ] || { fail "kak spinning at $1"; exit 1; }
}
# kakon NAME: the session's kak in $pid, $S; its pane stays when kak
# dies, so what kak said last shows
kakon() {
	S=$1 pid=$(kakpid "$1")
	[ -n "$pid" ] || { fail "no kak server for $1"; exit 1; }
	tm "$1" set-option -g remain-on-exit on
}

# straight to a few columns, the first lines in sight: the wrap marker
# leaves no room for the line's end (Kakoune 2026.05.21 read past it:
# std::length_error at 8 columns, a spin at 6; see show-whitespaces in
# rc/editor.kak)
CWD=$P XW=70 XH=24 start tmux sq s.c
kakon sq
for w in 9 8 6; do
	tm sq resize-window -t main -x $w; cap sq > /dev/null
	cpu "fresh, width $w"
done
stop sq

CWD=$P XW=70 XH=24 start tmux sp s.c
waitdiags sp 10; idle sp
kakon sp
cpu idle
send sp 'execute-keys 4g'; keys sp j; keys sp k
cpu "on long line 4"
for w in 60 40 30 25 20 15 12 10 9 8 7 6 5 4 3 2 1 70 100 70; do
	tm sp resize-window -t main -x $w; cap sp > /dev/null
	cpu "width $w"
done
for h in 10 6 4 3 24; do
	tm sp resize-window -t main -y $h; cap sp > /dev/null
	cpu "height $h"
done
tm sp resize-window -t main -x 30 -y 8; cap sp > /dev/null
for l in 4 5 6 7 8 9 4 5; do send sp "execute-keys ${l}g"; keys sp l; done
cpu "moving, 30x8"
keys sp i x y z Escape
cpu "after insert, 30x8"
expect "debug" "$(dbge sp)" ""
