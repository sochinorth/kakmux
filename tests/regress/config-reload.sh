# config-reload: :config-reload three times: no errors, the same hooks run
# for the same events, state kept (diagnostics, gutter, modeline, bufferline),
# features still work. MODE=tmux|notmux to try other setups.
# covers: kakrc rc/*.kak colors/* kakmux.conf scripts/kakmux
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
P=$R/p/proj; mkproj "$P"
CWD=$P start "${MODE:-kakmux}" rl main.c
attach rl
waitdiags rl 0
# an error and a gutter change in main.c, a second buffer
send rl "execute-keys 'gg/return 0<ret>cundefined_x<esc>'"
send rl "edit point.c; buffer main.c"
waitdiags rl 1 || fail "no diagnostic"
# LD: line_diags_n/state/pending ("1//": the one listed, none asked for);
# quiet: that too, and no git gutter diff running (their .buf files gone)
LD() { qv rl '"%opt{line_diags_n}/%opt{line_diags_state}/%opt{line_diags_pending}"'; }
_nogutter() { ! ls "$R"/tmp/kak-git-gutter.*/*.buf > /dev/null 2>&1; }
quiet() { waitout 10 "$1//" LD; waitfor 10 _nogutter; idle rl; }
quiet 1
events() {
	send rl "echo -debug MARK-$1"
	keys rl j; keys rl k
	# (until kak has the new size)
	for w in 150 160; do tm rl resize-window -t main -x $w; waitout 5 $w qv rl '%val{window_width}'; idle rl; done
	keys rl i x Escape; keys rl u
	send rl "buffer point.c"; send rl "buffer main.c"
	send rl "evaluate-commands -buffer point.c write"
	send rl "echo -debug END-$1"
	quiet 1
}
# hooks that ran (group and event; a first display's WinCreate/WinResize
# only once, so names, not counts)
hooks() { dbg rl | sed -n "/^MARK-$1\$/,/^END-$1\$/p" | grep '^hook ' | sed 's/(.*)\(\/.*\)/\1/' | sort -u; }
state() {
	q rl '%opt{line_diags}'
	q rl '%opt{git_gutter_flags}' | sed "s/^'[0-9]*' //"
	q rl 'MF %opt{modelinefmt}'
	q rl 'PF %opt{plugin_faces}' | wc -c
	q rl 'BL %opt{bufferline_bufs} %opt{kakmux_clients} %opt{focused_client}'
}
send rl "set-option global debug hooks"
events 0
hooks 0 > "$R/o/hooks-0"
state > "$R/o/state-0"
cap rl > "$R/o/cap-0"
for i in 1 2 3; do send rl "config-reload"; quiet 1; done
expect_match "status: reloaded" "$(cap rl | tail -1)" "config reloaded*"
expect "debug errors after reloads" "$(dbg rl | grep -v '^hook \|^MARK\|^END' | grep -i 'error running\|^error\|fail')" ""
state > "$R/o/state-1"
events 1
hooks 1 > "$R/o/hooks-1"
cap rl > "$R/o/cap-1"
expect "hooks run for the same events" "$(git diff --no-index --no-color "$R/o/hooks-0" "$R/o/hooks-1" | tail -n +5)" ""
expect_ge "hooks seen" "$(wc -l < "$R/o/hooks-0")" 10
expect "state kept" "$(git diff --no-index --no-color "$R/o/state-0" "$R/o/state-1" | tail -n +5)" ""
expect "screen kept" "$(git diff --no-index --no-color "$R/o/cap-0" "$R/o/cap-1" | tail -n +5)" ""
expect "one tmux window" "$(tm rl list-windows -F '#{window_name}' | wc -l)" 1
send rl "set-option global debug ''"
echo "== new diagnostic after reload"
send rl "execute-keys 'gg/printf<ret>cprintfz<esc>'"
waitdiags rl 2
waitout 10 2// LD
expect "two errors" "$(qv rl '%opt{line_diags_n}')" 2
expectw_match "inline line drawn" "*└─Call to undeclared function 'printfz'*" cap rl
expect "debug errors at the end" "$(dbg rl | grep -v '^hook \|^MARK\|^END' | grep -i 'error running\|^error')" ""
