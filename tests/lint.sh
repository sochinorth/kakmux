#!/bin/sh
# lint.sh: sh -n (and shellcheck, if installed) on the scripts; zsh -n on
# shell/kakmux.zsh; the kakrc loads with nothing in *debug* (plain kak and a
# kakmux), :config-reload three times adds nothing, and a kakrc sourced three
# times over loads clean too.
KM_LIB=$(cd "$(dirname "$0")/lib" && pwd)
ROOT=$(cd "$KM_LIB/../.." && pwd)
st=0
bad() { echo "FAIL $*"; st=1; }

echo "== sh -n"
files=$(cd "$ROOT" && ls bin/* scripts/* tests/run.sh tests/lint.sh tests/perf-diff.sh tests/lib/*.sh tests/lib/shwrap tests/lib/shtime tests/lib/fakebin/tmux tests/*/*.sh)
for f in $files; do
	case $(head -1 "$ROOT/$f") in *bash*) sh=bash ;; *) sh=sh ;; esac
	$sh -n "$ROOT/$f" || bad "$sh -n $f"
done
if command -v zsh >/dev/null; then zsh -n "$ROOT/shell/kakmux.zsh" || bad "zsh -n shell/kakmux.zsh"; fi
echo "ok   $(echo "$files" | wc -w) scripts parse"
if command -v shellcheck >/dev/null; then
	echo "== shellcheck"
	(cd "$ROOT" && shellcheck -S warning -s sh bin/* scripts/*) || bad "shellcheck (config scripts)"
	(cd "$ROOT" && shellcheck -S error -s sh tests/lib/*.sh tests/*/*.sh) || bad "shellcheck (tests)"
else
	echo "(shellcheck not installed: skipped)"
fi

echo "== kakrc load"
# each check in its own run dir, cleaned up by h.sh's trap
check() {
	( KM_LIB=$KM_LIB; . "$KM_LIB/h.sh"
	[ "${1:-}" = triple ] && mkcfg reload
	P=$R/p/proj; mkproj "$P" >/dev/null
	# known: kak-tree-sitter's rc removes window/<lang>, then the stock
	# c-family hook's own removal fails on a filetype change (not at load)
	errs() { dbge "$1" | grep -v '^MARK'; }
	CWD=$P WAIT=1 start notmux plain main.c
	waitdiags plain 0; sleep 2
	expect "plain kak${1:+ ($1)}: *debug* empty" "$(errs plain)" ""
	CWD=$P WAIT=1 start kakmux km main.c
	waitdiags km 0; sleep 2
	expect "kakmux${1:+ ($1)}: *debug* empty" "$(errs km)" ""
	if [ -z "${1:-}" ]; then
		send km 'echo -debug MARK'
		for i in 1 2 3; do send km config-reload; sleep 1; done
		expect "kakmux: config-reload x3: *debug* empty" "$(errs km)" ""
		keys km j; keys km k; keys km i x Escape; keys km u; sleep 1
		expect "kakmux: after reloads, keys: *debug* empty" "$(errs km)" ""
	fi
	)
}
out=$(check) || st=1; echo "$out"; echo "$out" | grep -q '^FAIL' && st=1
out=$(check triple) || st=1; echo "$out"; echo "$out" | grep -q '^FAIL' && st=1
[ $st = 0 ] && echo "lint: ok" || echo "lint: FAILED"
exit $st
