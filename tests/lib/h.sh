# tests/lib/h.sh: sourced by every test (". "$KM_LIB/h.sh"", see README.md).
#
# Gives the test a private world in one run dir ($R): its own XDG_RUNTIME_DIR
# (so kak sockets, kak-lsp and a kak-tree-sitter server of its own), cache,
# TMPDIR, TMUX_TMPDIR, git config, and a kak config dir built from the repo
# checkout ($KM_SRC). Every process it starts carries KM_RUN_ID in its
# environment; the EXIT trap stops the sessions, then kills whatever still
# carries that id (and nothing else).
#
# Environment it reads: KM_SRC (config source checkout, default: this repo),
# KM_RUN_DIR (run dir, made by tests/run.sh), KM_RUN_ID, KEEP=1 (keep the run
# dir of a standalone run).

KM_LIB=${KM_LIB:-$(cd "$(dirname "$0")/../lib" 2>/dev/null && pwd)}
[ -f "$KM_LIB/h.sh" ] || { echo "h.sh: can't find tests/lib (set KM_LIB)" >&2; exit 2; }
KM_ROOT=$(cd "$KM_LIB/../.." && pwd)
KM_SRC=$(cd "${KM_SRC:-$KM_ROOT}" && pwd)
KM_TEST=$(basename "$0" .sh)
export KM_LIB KM_ROOT KM_SRC

# --- run dir, ids -------------------------------------------------------------
if [ -n "${KM_RUN_DIR:-}" ]; then
	R=$KM_RUN_DIR; mkdir -p "$R"; KM_OWNDIR=
else
	R=$(mktemp -d "${TMPDIR:-/tmp}/kmtest.XXXXXX") || exit 1; KM_OWNDIR=1
fi
R=$(cd "$R" && pwd)
# kakmux is detected by "*/kakmux-*" in the tmux socket path: no run dir there
case $R in *kakmux-*) echo "run dir $R must not contain 'kakmux-'" >&2; exit 2 ;; esac
if [ -z "${KM_RUN_ID:-}" ]; then
	KM_RUN_ID=km$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')
fi
# PFX: the prefix of every session name of this run
PFX=$KM_RUN_ID
export KM_RUN_ID PFX R

mkdir -p "$R/s" "$R/o" "$R/p" "$R/tmp" "$R/cache" "$R/tmux" "$R/bin" "$R/config"
mkdir -p -m 700 "$R/xrt"
: > "$R/sessions"; : > "$R/pids"
F=$R            # old name: tests use $F/o, $F/tmp
export XDG_RUNTIME_DIR=$R/xrt XDG_CACHE_HOME=$R/cache XDG_CONFIG_HOME=$R/config
export TMPDIR=$R/tmp TMUX_TMPDIR=$R/tmux SHELL=/bin/sh
unset TMUX TMUX_PANE KAKMUX_HANDOFF KAKOUNE_POSIX_SHELL
export GIT_CONFIG_GLOBAL=$R/gitconfig GIT_CONFIG_NOSYSTEM=1
cat > "$R/gitconfig" <<EOF
[user]
	name = t
	email = t@t
[init]
	defaultBranch = trunk
[advice]
	detachedHead = false
EOF
export PATH="$R/bin:$PATH"
export KM_SHLOG=$R/o/shcount KM_SHTIME=$R/o/shtime
# every fzf (a picker's) answers on this socket, for fzfready (one at a time)
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:+$FZF_DEFAULT_OPTS }--listen=$R/o/fzf.sock"

# --- the config dir ---------------------------------------------------------------
# $XDG_CONFIG_HOME mirrors the real ~/.config (broot, ...) with symlinks,
# except kak (built here), kakbr (the checkout's) and kak-tree-sitter (a
# copy: the kakrc rewrites its config.toml when the grammars change).
real_config=${KM_REAL_CONFIG:-$HOME/.config}
for e in "$real_config"/* "$real_config"/.[!.]*; do
	[ -e "$e" ] || continue
	case ${e##*/} in
	kak|kakbr) ;;
	kak-tree-sitter) cp -RL "$e" "$R/config/" ;;
	*) ln -sfn "$e" "$R/config/${e##*/}" ;;
	esac
done
ln -sfn "$KM_SRC/kakbr" "$R/config/kakbr"
C=$R/config/kak
export KAKOUNE_CONFIG_DIR=$C

# mkcfg [reload]: (re)build $C from $KM_SRC, ~/.config/kak pointed at $C;
# scripts/ into $R/bin (first on PATH). reload: kakrc sources the real one
# three times (config-reload safety).
mkcfg() {
	rm -rf "$C"; mkdir -p "$C/bin" "$C/colors" "$C/rc"
	cp "$KM_SRC"/colors/*.kak "$C/colors/"
	for f in "$KM_SRC"/bin/*; do
		sed "s|~/.config/kak|$C|g" "$f" > "$C/bin/${f##*/}"; chmod +x "$C/bin/${f##*/}"
	done
	sed "s|~/.config/kak|$C|g" "$KM_SRC/kakrc" > "$C/kakrc"
	for f in "$KM_SRC"/rc/*.kak; do
		[ -e "$f" ] || continue   # (a checkout from before rc/, for perf-diff)
		sed "s|~/.config/kak|$C|g" "$f" > "$C/rc/${f##*/}"
	done
	sed "s|~/.config/kak|$C|g" "$KM_SRC/kakmux.conf" > "$C/kakmux.conf"
	for f in "$KM_SRC"/scripts/*; do
		sed "s|~/.config/kak|$C|g" "$f" > "$R/bin/${f##*/}"; chmod +x "$R/bin/${f##*/}"
	done
	if [ "${1:-}" = reload ]; then
		mv "$C/kakrc" "$C/kakrc.real"
		printf 'source "%%val{config}/kakrc.real"\n%.0s' 1 2 3 > "$C/kakrc"
	fi
}
mkcfg
mkdir -p "$R/emptycfg"

# --- cleanup ---------------------------------------------------------------------
. "$KM_LIB/sweep.sh"
km_cleanup() {
	# status: failed if an assertion failed or the shell was killed or timed
	# out; not by the last command's own status
	st=$?; [ "$st" -lt 124 ] && st=0
	trap - EXIT INT TERM HUP
	while read -r n; do stop "$n" 2>/dev/null; done < "$R/sessions"
	kts=$(cat "$XDG_RUNTIME_DIR/kak-tree-sitter/pid" 2>/dev/null)
	[ -n "$kts" ] && kill "$kts" 2>/dev/null
	km_sweep "$KM_RUN_ID"
	[ -e "$R/failed" ] && st=1
	if [ -n "$KM_OWNDIR" ] && [ -z "${KEEP:-}" ]; then rm -rf "$R"
	elif [ -n "$KM_OWNDIR" ]; then echo "kept: $R" >&2
	fi
	exit "$st"
}
trap km_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

# --- assertions -----------------------------------------------------------------------
# expect LABEL GOT WANT: equal strings
expect() {
	if [ "$2" = "$3" ]; then echo "ok   $1"
	else printf 'FAIL %s\n     got:  %s\n     want: %s\n' "$1" "$2" "$3"; : > "$R/failed"; fi
}
# expect_match LABEL GOT PATTERN: case pattern
expect_match() {
	# shellcheck disable=SC2254
	case $2 in $3) echo "ok   $1" ;; *) printf 'FAIL %s\n     got:  %s\n     want: %s\n' "$1" "$2" "$3"; : > "$R/failed" ;; esac
}
# expect_le LABEL NUMBER MAX / expect_ge LABEL NUMBER MIN: numbers
expect_le() {
	if [ "${2:-x}" -le "$3" ] 2>/dev/null; then echo "ok   $1 ($2 <= $3)"
	else echo "FAIL $1: $2, max $3"; : > "$R/failed"; fi
}
expect_ge() {
	if [ "${2:-x}" -ge "$3" ] 2>/dev/null; then echo "ok   $1 ($2 >= $3)"
	else echo "FAIL $1: $2, min $3"; : > "$R/failed"; fi
}
# expectw LABEL WANT CMD... / expectw_match LABEL PATTERN CMD...: expect /
# expect_match on CMD's output, once it is that (polled, ${EW:-10} s max):
# for what settles after the keys (a popup closing, kak-lsp answering)
expectw() {
	_el=$1 _ew=$2; shift 2
	waitfor "${EW:-10}" _outis "$_ew" "$@"
	expect "$_el" "$("$@")" "$_ew"
}
expectw_match() {
	_el=$1 _ew=$2; shift 2
	waitfor "${EW:-10}" _outlike "$_ew" "$@"
	expect_match "$_el" "$("$@")" "$_ew"
}
# waitout SECS WANT CMD...: until CMD prints WANT
waitout() { _wo=$2; _wos=$1; shift 2; waitfor "$_wos" _outis "$_wo" "$@"; }
_outis() { _ow=$1; shift; [ "$("$@")" = "$_ow" ]; }
# shellcheck disable=SC2254
_outlike() { _ow=$1; shift; case $("$@") in $_ow) return 0 ;; esac; return 1; }
fail() { echo "FAIL $*"; : > "$R/failed"; }
# skip REASON: the test can't run here (missing tool); not a failure
skip() { echo "SKIP $*"; : > "$R/skipped"; exit 0; }
need() { for t; do command -v "$t" >/dev/null 2>&1 || skip "needs $t"; done; }

# --- sessions -------------------------------------------------------------------------
# start MODE NAME [kak args]: kak in a fresh tmux server, waits for it. kak
# is the pane's process (exec), as with kakmux: when it ends, so does the pane.
#   kakmux: socket .../kakmux-$PFX-NAME with kakmux.conf (kakmux detection)
#   tmux:   plain tmux; notmux: kak in a tmux pane, TMUX unset
# Returns once client0 answers, its first idle hooks have run and its screen
# is still. CWD: kak's cwd (default $R); WAIT=SECS: just that long after the
# socket shows instead (WAIT=0: the first frames); SHW=1: counting
# KAKOUNE_POSIX_SHELL; KAKPRE: before kak (env ...); XW/XH: size (160x45)
start() {
	mode=$1 name=$2; shift 2
	case $mode in
	kakmux) sock=$R/s/kakmux-$PFX-$name; conf=$C/kakmux.conf ;;
	*) sock=$R/s/$PFX-tmux-$name; conf=/dev/null ;;
	esac
	nt=; [ "$mode" = notmux ] && nt=1
	grep -qx "$name" "$R/sessions" || echo "$name" >> "$R/sessions"
	rm -f "$XDG_RUNTIME_DIR/kakoune/$PFX-$name"
	TMUX= tmux -S "$sock" -f "$conf" new-session -d -s main -x "${XW:-160}" -y "${XH:-45}" -- \
		sh -c "cd '${CWD:-$R}' && exec env ${nt:+-u TMUX -u TMUX_PANE} ${SHW:+KAKOUNE_POSIX_SHELL=$KM_LIB/shwrap} ${KAKPRE:-} kak -s $PFX-$name $*"
	waitkak "$name" || return 1
	if [ -n "${WAIT:-}" ]; then sleep "$WAIT"; return 0; fi
	_sc=0
	until hasclient "$name" client0; do
		_sc=$((_sc + 1)); [ $_sc -gt 200 ] && { echo "session $name: no client0" >&2; return 1; }
		sleep 0.05
	done
	idle "$name"; cap "$name" > /dev/null
}
# hasclient NAME CLIENT: the session has that client
hasclient() {
	rm -f "$R/o/hc" "$R/o/hc.done"
	printf 'try %%{ evaluate-commands -client %s %%{ echo -to-file %s ok } }; echo -to-file %s.done ok\n' "$2" "$R/o/hc" "$R/o/hc" | kak -p "$PFX-$1" 2>/dev/null &&
	waitfile "$R/o/hc.done" 1 && [ -e "$R/o/hc" ]
}
# waitkak NAME: until the session answers (10 s max)
waitkak() {
	_wk=0
	until printf 'nop\n' | kak -p "$PFX-$1" 2>/dev/null; do
		_wk=$((_wk + 1)); [ $_wk -gt 200 ] && { echo "session $1 did not start" >&2; return 1; }
		sleep 0.05
	done
}
# sync NAME: until kak has handled all that was sent to it so far: a round
# trip through client $CL (default client0; the session's context if there's
# no such client). What kak -p sends runs in order, and keys typed through
# tmux reach the server well before a kak -p started after them. At once if
# the session is gone.
sync() {
	rm -f "$R/o/sync"
	printf 'try %%{ evaluate-commands -client %s %%{ echo -to-file %s ok } } catch %%{ echo -to-file %s ok }\n' \
		"${CL:-client0}" "$R/o/sync" "$R/o/sync" | kak -p "$PFX-$1" 2>/dev/null || return 1
	waitfile "$R/o/sync"
}
# idle NAME: sync, then again past kak's idle timeout (50 ms): the idle hooks
# what was typed or sent set off have run (not what they started in the background)
idle() { sync "$1" && sleep 0.07 && sync "$1"; }
# settle CMD...: until CMD's output (a screen) stays the same for 30 ms (5 s
# max); prints it
settle() {
	_sa=$("$@"); _sk=0
	while [ $_sk -lt 160 ]; do
		sleep 0.03; _sb=$("$@")
		[ "$_sa" = "$_sb" ] && break
		_sa=$_sb; _sk=$((_sk + 1))
	done
	printf '%s\n' "$_sa"
}
# sk NAME: tmux socket of a server started by start
sk() { for s in "$R/s/kakmux-$PFX-$1" "$R/s/$PFX-tmux-$1"; do [ -S "$s" ] && echo "$s" && return; done; }
tm() { n=$1; shift; TMUX= tmux -S "$(sk "$n")" "$@"; }
# attach NAME: an attached tmux client in a pty (popups need one)
attach() {
	s=$(sk "$1")
	script -qfc "stty rows ${XH:-45} cols ${XW:-160}; TMUX= tmux -S '$s' attach -t main" /dev/null >/dev/null 2>&1 </dev/null &
	echo $! >> "$R/pids"; attached "$1"
}
# attached NAME: until a tmux client is attached, and kak has heard of it
attached() {
	_ak=0; until [ -n "$(tm "$1" list-clients -F x 2>/dev/null)" ]; do
		_ak=$((_ak + 1)); [ $_ak -gt 200 ] && { echo "$1: no tmux client attached" >&2; return 1; }
		sleep 0.05
	done
	idle "$1"; cap "$1" > /dev/null
}
# attachf NAME: attached client reading its terminal input from the fifo
# $R/o/in-NAME (term NAME BYTES writes there: keys, focus events)
attachf() {
	s=$(sk "$1"); fifo=$R/o/in-$1
	rm -f "$fifo"; mkfifo "$fifo"
	# the fifo's writer, so the client never sees EOF
	sleep 100000 > "$fifo" &
	echo $! >> "$R/pids"
	script -qfc "stty rows ${XH:-45} cols ${XW:-160}; TMUX= tmux -S '$s' attach -t main" /dev/null >/dev/null 2>&1 < "$fifo" &
	echo $! >> "$R/pids"; attached "$1"
}
# The helpers that type or send (term send keys pkeys esc) return once it's
# handled (see sync, idle, settle); WAIT2=SECS: that much longer each.
term() { printf "$2" > "$R/o/in-$1"; idle "$1"; [ -z "${WAIT2:-}" ] || sleep "$WAIT2"; }
# send NAME CMDS: run in client0 (or $CL)
send() { printf 'evaluate-commands -client %s %%{ %s }\n' "${CL:-client0}" "$2" | kak -p "$PFX-$1"; idle "$1"; [ -z "${WAIT2:-}" ] || sleep "$WAIT2"; }
# q NAME EXPR...: EXPR evaluated in the client, shell-quoted
q() {
	n=$1; shift; rm -f "$R/o/q" "$R/o/q.done"
	printf 'evaluate-commands -client %s %%{ echo -quoting shell -to-file %s -- %s; echo -to-file %s.done ok }\n' "${CL:-client0}" "$R/o/q" "$*" "$R/o/q" | kak -p "$PFX-$n" && waitfile "$R/o/q.done"; cat "$R/o/q" 2>/dev/null; echo
}
# qv NAME EXPR...: as q, no trailing newline, raw (echo -to-file)
qv() {
	n=$1; shift; rm -f "$R/o/q" "$R/o/q.done"
	printf 'evaluate-commands -client %s %%{ echo -to-file %s -- %s; echo -to-file %s.done ok }\n' "${CL:-client0}" "$R/o/q" "$*" "$R/o/q" | kak -p "$PFX-$n" && waitfile "$R/o/q.done"; cat "$R/o/q" 2>/dev/null
}
# waitfile FILE [SECS]: until FILE exists (5 s max)
waitfile() { _fk=0; while [ ! -e "$1" ]; do _fk=$((_fk + 1)); [ $_fk -gt $((${2:-5} * 50)) ] && return 1; sleep 0.02; done; }
# dbg NAME: *debug* contents; dbge NAME: less the usual noise (startup
# lines, faces, remote client chatter, empty lines)
dbg() {
	rm -f "$R/o/d" "$R/o/d.done"
	printf 'evaluate-commands -client %s %%{ evaluate-commands -buffer *debug* %%{ execute-keys \047%%\047; echo -to-file %s %%val{selection} }; echo -to-file %s.done ok }\n' "${CL:-client0}" "$R/o/d" "$R/o/d" | kak -p "$PFX-$1" && waitfile "$R/o/d.done"; cat "$R/o/d"; echo
}
dbge() {
	dbg "$1" | grep -v -e '^ \* ' -e '^\*\*\* This is the debug buffer' -e '^Faces:$' -e '^Mappings:$' \
		-e '^LSP: INFO' -e 'offsetEncoding capability' -e '^remote client \(dis\)\?connected' \
		-e '^Error while transfering remote messages' -e '^no windowing module detected' \
		-e '^accepting connection failed' -e '^ *$'
	return 0
}
keys() { n=$1; shift; tm "$n" send-keys -t main "$@"; idle "$n"; [ -z "${WAIT2:-}" ] || sleep "$WAIT2"; }
# cap NAME [PANE]: the screen, once still
cap() { settle tm "$1" capture-pane -p -t "${2:-main}"; }
# stop NAME: the session, its tmux server, its kak-lsp (and language servers)
stop() {
	kp=$(kakpid "$1")
	printf 'kill!\n' | kak -p "$PFX-$1" 2>/dev/null
	# let its KakEnd hooks finish before the tmux server goes
	[ -n "$kp" ] && { k=0; while kill -0 "$kp" 2>/dev/null && [ $k -lt 30 ]; do sleep 0.1; k=$((k + 1)); done; }
	tm "$1" kill-server 2>/dev/null
	s=$(sk "$1"); [ -n "$s" ] && rm -f "$s"
	d=$XDG_RUNTIME_DIR/kakoune-lsp/$PFX-$1
	pid=$(cat "$d/pid" 2>/dev/null)
	if [ -n "$pid" ]; then
		kids=$(pgrep -P "$pid" 2>/dev/null)
		sleep 0.3
		kill "$pid" $kids 2>/dev/null
	fi
	rm -rf "$d" "$d.ref"
}
# pdirs: picker temp dirs (TMPDIR=$R/tmp), what the popup was handed
pdirs() {
	for d in "$R"/tmp/kak-picker.*; do
		[ -d "$d" ] && { echo "dir $d:"; ls "$d"; [ -e "$d/only" ] && echo "only=$(cat "$d/only")"; }
	done
}
# popwin NAME: pickers open in a tmux window "picker" instead of a popup
# (pcap shows it, pkeys types in it)
popwin() {
	awk '/^define-command -override -hidden -params 2..3 picker-open/,/^}/' "$C/rc/pickers.kak" |
		sed 's|tmux display-popup -t "$kak_client_env_TMUX_PANE"|tmux new-window -d -n picker|; s|-d "${3:-$PWD}" \(-e "BAT_THEME=[^"]*"\) -E -B -w 90% -h 80%|-c "${3:-$PWD}" \1|' > "$R/popwin.kak"
	grep -q 'new-window -d -n picker' "$R/popwin.kak" || fail "popwin: picker-open no longer matches the rewrite"
	send "$1" "source $R/popwin.kak"
}
pcap() { settle tm "$1" capture-pane -p -t main:picker 2>/dev/null; }
pkeys() { n=$1; shift; tm "$n" send-keys -t main:picker "$@"; pcap "$n" > /dev/null; [ -z "${WAIT2:-}" ] || sleep "$WAIT2"; }
# quiet [N]: until kak ($pid) has held still for N tenths of a second
# (default 5; a tick of CPU at most, no new shells; 20 s max): what was set
# off has run. No kak -p, so nothing added to what perf tests count.
quiet() {
	_qn=0 _qk=0 _qc0=$(cputicks "$pid") _qs0=$(shells)
	while [ $_qn -lt "${1:-5}" ] && [ $_qk -lt 200 ]; do
		sleep 0.1; _qk=$((_qk + 1)); _qc=$(cputicks "$pid") _qs=$(shells)
		if [ $((_qc - _qc0)) -gt 1 ] || [ "$_qs" != "$_qs0" ]; then _qc0=$_qc _qs0=$_qs _qn=0; else _qn=$((_qn + 1)); fi
	done
}
# kakpid NAME: the session's kak server pid
kakpid() { pgrep -f "^kak -s $PFX-$1( |\$)" | head -1; }
# cputicks PID: utime+stime ticks; fails, printing nothing, once PID is gone
cputicks() { _ct=$(sed 's/.*) //' "/proc/${1:-none}/stat" 2>/dev/null) && [ -n "$_ct" ] || return 1; echo "$_ct" | awk '{ print $12 + $13 }'; }
# waitfor TIMEOUT CMD...: until CMD succeeds (polls every 0.05 s)
waitfor() {
	_wt=$1; shift; _wn=0
	until "$@"; do _wn=$((_wn + 1)); [ $_wn -gt $((_wt * 20)) ] && return 1; sleep 0.05; done
}
# panes NAME N: until window main has N panes, each with a kak client in it
panes() { waitfor 10 _panes "$1" "$2"; idle "$1"; }
_panes() { [ "$(tm "$1" list-panes -t main -F '#{@kak_client}' 2>/dev/null | grep -c .)" = "$2" ] && [ "$(tm "$1" list-panes -t main -F x | grep -c .)" = "$2" ]; }
# waitcap NAME PATTERN [SECS] [PANE]: until the screen has a line matching
# PATTERN (grep -E; 10 s max)
waitcap() { waitfor "${3:-10}" _capgrep "$1" "$2" "${4:-main}"; }
_capgrep() { tm "$1" capture-pane -p -t "$3" 2>/dev/null | grep -qE -- "$2"; }
# waitdiags NAME [N]: until the buffer has diagnostics (lsp_diagnostic_error_count
# + warnings >= N, default 1; 20 s max)
waitdiags() {
	_dk=0
	while :; do
		_dn=$(qv "$1" '%sh{ echo $((kak_opt_lsp_diagnostic_error_count + kak_opt_lsp_diagnostic_warning_count)) }')
		[ "${_dn:-0}" -ge "${2:-1}" ] 2>/dev/null && return 0
		_dk=$((_dk + 1)); [ $_dk -gt 200 ] && return 1
		sleep 0.1
	done
}

. "$KM_LIB/fixtures.sh"

# nlines FILE...: lines, a last one without newline counted too
nlines() { cat "$@" 2>/dev/null | grep -c ''; }
# metric NAME VALUE [UNIT]: a number for perf-diff (one "metric" line)
metric() { echo "metric $1 $2${3:+ $3}"; }
# shells: lines in the shell log since it was emptied; shtop [N]: the commonest
shells() { nlines "$KM_SHLOG"; }
shtop() { sort "$KM_SHLOG" | cut -c1-"${W:-100}" | uniq -c | sort -rn | head -"${1:-6}"; }
# myfzf: pid of an fzf of this run (a picker popup's), if any
myfzf() { for p in $(pgrep -x fzf); do grep -qzx "KM_RUN_ID=$KM_RUN_ID" "/proc/$p/environ" 2>/dev/null && { echo "$p"; return; }; done; }
# fzfst [JQ]: the picker's fzf's state (its GET /, through jq), if one is up
fzfst() { curl -s -m 2 --unix-socket "$R/o/fzf.sock" 'http://localhost/?limit=0' 2>/dev/null | jq -r "${1:-.}" 2>/dev/null; }
# fzfready [QUERY [SECS]]: until a picker's fzf is up (SECS, default 10),
# its list read and QUERY (default none) searched. Asked twice: a list laid
# out in columns is laid out again on fzf's result event, by a transform
# that runs in fzf's event loop, as the answers do, so the second comes once
# that ran (and the reload it may start). fzf can say it's still reading
# after such a reload for good: 2 s of that is taken as done.
fzfready() {
	waitfor "${2:-10}" _fzfq "${1-}" || { echo "fzfready: no fzf with query '${1-}': $(fzfst '"\(.reading) \(.progress) \(.query)"')" >&2; return 1; }
	waitfor 2 _fzfis "${1-}"; waitfor 2 _fzfis "${1-}" || _fzfq "${1-}"
}
_fzfq() { [ "$(fzfst '"\(.progress) \(.query)"')" = "100 $1" ]; }
_fzfis() { [ "$(fzfst '"\(.reading) \(.progress) \(.query)"')" = "false 100 $1" ]; }
# popwin pickers: popen NAME [QUERY]: up (fzfready), its screen still; ptype
# NAME TEXT: TEXT typed and searched; pclose NAME KEY: KEY closes it
# (pickerdone)
popen() { fzfready "${2-}" && pcap "$1" > /dev/null; }
ptype() { pkeys "$1" "$2"; popen "$1" "$2"; }
pclose() { pkeys "$1" "$2"; pickerdone "$1"; }
# pickerdone NAME: until no picker popup of the run is left (its last
# command sent to kak), then idle NAME
pickerdone() { waitfor 10 _nopicker; idle "$1"; }
_nopicker() {
	for _pp in $(pgrep -f 'bin/kak-picker '); do
		grep -qzx "KM_RUN_ID=$KM_RUN_ID" "/proc/$_pp/environ" 2>/dev/null && return 1
	done
	return 0
}
# alive NAME: the session answers within 5 s
alive() {
	rm -f "$R/o/alive"
	(printf 'evaluate-commands -client client0 %%{ echo -to-file %s ok }\n' "$R/o/alive" | timeout 5 kak -p "$PFX-$1" &)
	k=0; while [ ! -s "$R/o/alive" ] && [ $k -lt 50 ]; do sleep 0.1; k=$((k + 1)); done
	[ -s "$R/o/alive" ]
}
# esc NAME: <esc> to kak (send-keys: a raw \033 written to an attachf
# client's terminal reaches kak as the prefix of the next key, <a-u> say)
esc() { tm "$1" send-keys -t main Escape; idle "$1"; [ -z "${WAIT2:-}" ] || sleep "$WAIT2"; }
