# resize-spin: kak stays alive and idle in narrow windows.
# 1. A fresh window straight down to 9, 8 and 6 columns. Kakoune 2026.05.21's
#    wrap reads past a line's end when the wrap marker leaves no room for it
#    and the line ends in text not taken from the buffer (as show-whitespaces'
#    -lf ' ' drew the newline): std::length_error at 8 columns, a spin at 6.
#    rc/editor.kak leaves the newline as it is; once Kakoune has 1e703893
#    (after 2026.05.21) neither this nor that is needed.
# 2. Long wrapped lines with inline diagnostics, shrunk to a column and back,
#    then short, with the cursor moving over them.
# covers: rc/inline-diagnostics.kak rc/decorations.kak rc/editor.kak
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
P=$R/p/sp; mkdir -p "$P"; printf -- '-Wall\n' > "$P/compile_flags.txt"
{
	echo '#include <stdio.h>'
	echo 'int main(void)'
	echo '{'
	printf '\tint total = alpha_undefined_one + beta_undefined_two * gamma_undefined_three - delta_undefined_four + epsilon_undefined_five / zeta_undefined_six + eta_undefined_seven;\n'
	printf '\tprintf("%%d %%s\\n", total, "a very long string literal that goes on and on and on and on and on");\n'
	for i in $(seq 1 12); do printf '\tint v%d = unknown_%d(%d); /* a comment that makes the line long enough to wrap */\n' $i $i $i; done
	echo '}'
} > "$P/s.c"
# kakon NAME: the session's kak in $pid, $S; its pane stays when kak dies, so
# what kak said last shows
kakon() {
	S=$1 pid=$(kakpid "$1")
	[ -n "$pid" ] || { fail "no kak server for $1"; exit 1; }
	tm "$1" set-option -g remain-on-exit on
}
# alive LABEL: kak is still there, or the test stops with its last screen
alive() {
	kill -0 "$pid" 2>/dev/null && return
	fail "kak died at $1"
	tm "$S" capture-pane -p -t main 2>/dev/null | grep -v '^ *$' | tail -3
	exit 1
}
# idlecpu LABEL: under 20% of a CPU over half a second (a spin takes most of one)
idlecpu() {
	a=$(cputicks "$pid") && sleep 0.5 && b=$(cputicks "$pid") || alive "$1"
	expect_le "$1: cpu %" $(( (b - a) * 2 )) 20
}
# resize NAME -x|-y N...: each size in turn, kak alive after each
resize() {
	_n=$1 _d=$2; shift 2
	for _s; do tm "$_n" resize-window -t main "$_d" "$_s"; cap "$_n" > /dev/null; alive "${_d#-} $_s"; done
}

CWD=$P XW=70 XH=24 start tmux sq s.c
kakon sq
resize sq -x 9 8 6
idlecpu "fresh, width 6"
stop sq

CWD=$P XW=70 XH=24 start tmux sp s.c
waitdiags sp 10; idle sp
kakon sp
send sp 'execute-keys 4g'; keys sp j; keys sp k
resize sp -x 30 15 8 4 1 70
resize sp -y 6 3 24
idlecpu "after resizes"
tm sp resize-window -t main -x 30 -y 8; cap sp > /dev/null
for l in 4 5 6 7 4; do send sp "execute-keys ${l}g"; keys sp l; done
keys sp i x y z Escape
alive "moving, 30x8"
idlecpu "moving, 30x8"
expect "debug" "$(dbge sp)" ""
