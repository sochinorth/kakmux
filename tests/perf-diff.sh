#!/bin/sh
# perf-diff.sh REV [TEST...]: the perf tests (default: perf, less the slow
# ones) on REV's config (a temporary git worktree) and on this checkout's,
# their metrics side by side. The tests themselves are this checkout's.
REV=${1:?usage: perf-diff.sh REV [TEST...]}; shift
T=$(cd "$(dirname "$0")" && pwd); ROOT=$(dirname "$T")
[ $# -gt 0 ] || set -- perf
W=$(mktemp -d "${TMPDIR:-/tmp}/kmperf.XXXXXX")
git -C "$ROOT" worktree add -q --detach "$W/rev" "$REV" || { rm -rf "$W"; exit 2; }
trap 'git -C "$ROOT" worktree remove --force "$W/rev"; rm -rf "$W"' EXIT INT TERM
metrics() { # LABEL SRC TEST...: run, collect "metric" lines into $W/LABEL
	label=$1 src=$2; shift 2
	echo "== $label ($src)"
	KM_SRC=$src bash "$T/run.sh" -s -k "$@" 2>&1 | tee "$W/$label.log" | grep -v '^    '
	d=$(sed -n 's/^run dir: \([^ ]*\).*/\1/p' "$W/$label.log")
	for o in "$d"/*.out; do
		t=$(basename "$o" .out)
		sed -n "s/^metric /$t /p" "$o"
	done > "$W/$label"
	rm -rf "$d"
}
metrics old "$W/rev" "$@"
metrics new "$ROOT" "$@"
echo
printf '%-40s %12s %12s\n' metric "$REV" "worktree"
awk 'NR == FNR { k = $1 " " $2; old[k] = $3; u[k] = $4; next }
	{ k = $1 " " $2; printf "%-40s %12s %12s %s\n", k, (k in old ? old[k] : "-"), $3, $4; delete old[k] }
	END { for (k in old) printf "%-40s %12s %12s %s\n", k, old[k], "-", u[k] }' "$W/old" "$W/new"
