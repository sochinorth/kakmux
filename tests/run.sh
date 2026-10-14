#!/usr/bin/env bash
# run.sh [-a|-A] [-c REF] [-s] [-u] [-k] [-j N] [-v] [NAME|CATEGORY...]: run
# tests, PASS/FAIL each.
#   default        the tests that cover what changed against HEAD (tracked
#                  changes and untracked files), and regress/smoke always: a
#                  test's "# covers:" paths (globs) against the files changed;
#                  a test changed (NAME.sh, NAME.expected) runs; tests/lib or
#                  this file changed runs them all (-A). From regress and
#                  features, less the tests tagged slow.
#   -c REF         the same against REF (a branch's changes: -c trunk)
#   -A             all of regress and features, less the tests tagged slow
#   -a             every category (regress features perf visual kts), slow ones too
#   -s             leave out the tests tagged slow (with -a or CATEGORY)
#   NAME           a test by name (smoke, regress/smoke) or a whole CATEGORY
#   -u             write the normalised output as the new .expected (golden) file
#   -k             keep every run dir (default: only the failed ones)
#   -j N           N tests at once (default a quarter of the CPUs, 1 to 8); the
#                  tests tagged serial run after them, one at a time
#   -v             show each test's output as it finishes
# A test passes when it exits 0 (its own expect/expect_le... assertions) and,
# if it has NAME.expected next to it, its normalised output matches that.
# Env: KM_SRC=DIR runs the tests against another checkout's config (perf-diff).
set -u
T=$(cd "$(dirname "$0")" && pwd)
ROOT=$(dirname "$T")
ALL=0 UPDATE=0 KEEP=0 VERBOSE=0 NOSLOW=0 REF=
# (tests wait on kak, tmux and clangd more than they use a CPU)
JOBS=$(( $(nproc 2>/dev/null || echo 4) / 4 )); [ "$JOBS" -lt 1 ] && JOBS=1; [ "$JOBS" -gt 8 ] && JOBS=8
while getopts aAc:sukj:v o; do
	case $o in
	a) ALL=1 ;; A) ALL=2 ;; c) REF=$OPTARG ;; s) NOSLOW=1 ;; u) UPDATE=1 ;; k) KEEP=1 ;; j) JOBS=$OPTARG ;; v) VERBOSE=1 ;;
	*) sed -n '2,22p' "$0"; exit 2 ;;
	esac
done
shift $((OPTIND - 1))
CATS="regress features perf visual kts"

tag() { sed -n 's/^# tags: *//p' "$1" | head -1; }
# selection
sel=()
add() {
	local f
	for f; do
		[ -f "$f" ] || continue
		[ $NOSLOW = 1 ] && case " $(tag "$f") " in *" slow "*) continue ;; esac
		sel+=("$f")
	done
}
# the default set: regress and features, less slow
pool() {
	local f
	for f in "$T"/regress/*.sh "$T"/features/*.sh; do
		case " $(tag "$f") " in *" slow "*) ;; *) echo "$f" ;; esac
	done
}
# changed: the files changed against ${REF:-HEAD}, untracked ones too
changed() {
	git -C "$ROOT" diff --name-only "${REF:-HEAD}" -- || { echo "run.sh: git diff ${REF:-HEAD} failed" >&2; exit 2; }
	git -C "$ROOT" ls-files --others --exclude-standard
}
# bychange: the tests to run for what changed (the default)
bychange() {
	local files f t p pats
	files=$(changed) || exit 2
	declare -A want
	for f in $files; do
		case $f in
		tests/lib/*|tests/run.sh) pool; echo "changed: $f (the harness: every test)" >&2; return ;;
		tests/*/*.sh|tests/*/*.expected) t=$ROOT/${f%.*}.sh; [ -f "$t" ] && want[$t]=1 ;;
		esac
	done
	for t in $(pool); do
		pats=$(sed -n 's/^# covers: *//p' "$t" | head -1)
		[ -n "$pats" ] || continue
		for f in $files; do
			for p in $pats; do
				# shellcheck disable=SC2254
				case $f in $p) want[$t]=1; continue 3 ;; esac
			done
		done
	done
	echo "changed against ${REF:-HEAD}: $(echo $files | wc -w) files, ${#want[@]} tests cover them" >&2
	[ ${#want[@]} -eq 0 ] && echo "no test covers the changes: smoke only" >&2
	want[$T/regress/smoke.sh]=1
	for t in "${!want[@]}"; do echo "$t"; done | sort
}
if [ $# -eq 0 ]; then
	if [ $ALL = 1 ]; then
		for c in $CATS; do add "$T/$c"/*.sh; done
	elif [ $ALL = 2 ]; then
		# shellcheck disable=SC2046
		add $(pool)
	else
		bc=$(bychange) || exit 2
		# shellcheck disable=SC2086
		add $bc
	fi
else
	for a; do
		a=${a%.sh}
		if [ -d "$T/$a" ]; then add "$T/$a"/*.sh; continue; fi
		if [ -f "$T/$a.sh" ]; then add "$T/$a.sh"; continue; fi
		m=$(ls "$T"/*/"$a".sh 2>/dev/null)
		[ -n "$m" ] || { echo "no test $a" >&2; exit 2; }
		add $m
	done
fi
[ ${#sel[@]} -gt 0 ] || { echo "no tests" >&2; exit 2; }

for t in kak tmux script git; do command -v $t >/dev/null || { echo "missing: $t" >&2; exit 2; }; done
BASE=$(mktemp -d "${TMPDIR:-/tmp}/kmrun.XXXXXX")
echo "run dir: $BASE (${#sel[@]} tests, -j $JOBS, config from ${KM_SRC:-$ROOT})"

# one test: writes $BASE/NAME.{out,status,secs}
one() {
	local f=$1 cat name id dir to t0 st
	cat=$(basename "$(dirname "$f")"); name=$cat-$(basename "$f" .sh)
	id=km$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')
	dir=$BASE/$name; mkdir -p "$dir"
	echo "$id" > "$BASE/$name.id"
	to=$(sed -n 's/^# timeout: *//p' "$f" | head -1)
	t0=$(date +%s)
	env KM_RUN_ID=$id KM_RUN_DIR="$dir" timeout -k 20 "${to:-300}" sh "$f" > "$BASE/$name.out" 2> "$BASE/$name.err" < /dev/null
	st=$?
	echo $(( $(date +%s) - t0 )) > "$BASE/$name.secs"
	# leftovers, if the test was killed before its own cleanup
	(KM_RUN_ID=$id; . "$T/lib/sweep.sh"; km_sweep "$id")
	echo $st > "$BASE/$name.status"
}

report() {
	local f=$1 cat name exp st secs res=PASS why=
	cat=$(basename "$(dirname "$f")"); name=$cat-$(basename "$f" .sh)
	exp=${f%.sh}.expected
	st=$(cat "$BASE/$name.status"); secs=$(cat "$BASE/$name.secs")
	sh "$T/lib/norm.sh" "$BASE/$name" "$(cat "$BASE/$name.id")" < "$BASE/$name.out" > "$BASE/$name.norm"
	if [ "$st" = 124 ] || [ "$st" = 137 ]; then res=FAIL why="timed out"
	elif grep -q '^SKIP ' "$BASE/$name.out" && [ "$st" = 0 ]; then res=SKIP why=$(grep -m1 '^SKIP ' "$BASE/$name.out" | cut -c6-)
	elif [ "$st" != 0 ]; then res=FAIL why="exit $st"
	fi
	if [ $res = PASS ] && [ -f "$exp" ] && [ $UPDATE = 0 ]; then
		git diff --no-index --no-color -U2 "$exp" "$BASE/$name.norm" > "$BASE/$name.diff" || { res=FAIL why="output differs from $(basename "$exp")"; }
	fi
	if [ $UPDATE = 1 ] && [ $res = PASS ] && { [ -f "$exp" ] || grep -q '^# golden' "$f"; }; then
		cp "$BASE/$name.norm" "$exp"; why="expected updated"
	fi
	printf '%s %-26s %4ss%s\n' $res "$cat/$(basename "$f" .sh)" "$secs" "${why:+  ($why)}"
	if [ $res = FAIL ]; then
		grep -A2 '^FAIL' "$BASE/$name.out" | head -40 | sed 's/^/    /'
		[ -s "$BASE/$name.diff" ] && head -60 "$BASE/$name.diff" | tail -n +5 | sed 's/^/    /'
		[ -s "$BASE/$name.err" ] && tail -5 "$BASE/$name.err" | sed 's/^/    err: /'
		echo "    output: $BASE/$name.out, run dir: $BASE/$name"
		echo "$cat/$(basename "$f" .sh)" >> "$BASE/failed"
	else
		[ $KEEP = 1 ] || rm -rf "${BASE:?}/$name"
	fi
	[ $res = SKIP ] && echo x >> "$BASE/skipped"
	[ $VERBOSE = 1 ] && sed 's/^/    | /' "$BASE/$name.out"
	return 0
}

trap 'echo interrupted; for p in $(jobs -p); do kill $p 2>/dev/null; done; wait; for i in "$BASE"/*.id; do [ -e "$i" ] && (. "$T/lib/sweep.sh"; km_sweep "$(cat "$i")"); done; exit 130' INT TERM

# tests tagged serial (timing: CPU, latency) run alone, after the others
par=() ser=()
for f in "${sel[@]}"; do
	case " $(tag "$f") " in *" serial "*) ser+=("$f") ;; *) par+=("$f") ;; esac
done
if [ "$JOBS" -le 1 ]; then
	for f in "${sel[@]}"; do one "$f"; report "$f"; done
else
	running=0
	declare -A pidf
	for f in "${par[@]}"; do
		while [ $running -ge "$JOBS" ]; do
			wait -n -p fin; running=$((running - 1)); report "${pidf[$fin]}"
		done
		one "$f" & pidf[$!]=$f; running=$((running + 1))
	done
	while [ $running -gt 0 ]; do wait -n -p fin; running=$((running - 1)); report "${pidf[$fin]}"; done
	for f in "${ser[@]}"; do one "$f"; report "$f"; done
fi

n=${#sel[@]}; nf=0; ns=0
[ -f "$BASE/failed" ] && nf=$(wc -l < "$BASE/failed")
[ -f "$BASE/skipped" ] && ns=$(wc -l < "$BASE/skipped")
echo "$((n - nf - ns)) passed, $nf failed, $ns skipped"
if [ "$nf" -gt 0 ]; then sed 's/^/  failed: /' "$BASE/failed"; exit 1; fi
[ $KEEP = 1 ] || rm -rf "$BASE"
exit 0
