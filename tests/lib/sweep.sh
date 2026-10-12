# tests/lib/sweep.sh: km_sweep (sourced by h.sh and run.sh)
# km_sweep ID: kill every process whose environment has KM_RUN_ID=ID, except
# this shell and its ancestors. TERM first, KILL what is left.
km_sweep() {
	anc=" $$ "; p=$$
	while [ "${p:-1}" -gt 1 ]; do
		p=$(sed 's/.*) //' "/proc/$p/stat" 2>/dev/null | cut -d' ' -f2)
		anc="$anc${p:-1} "
	done
	for sig in TERM TERM KILL; do
		pids=
		for f in $(grep -lzx "KM_RUN_ID=$1" /proc/[0-9]*/environ 2>/dev/null); do
			pid=${f#/proc/}; pid=${pid%/environ}
			case $anc in *" $pid "*) continue ;; esac
			pids="$pids $pid"
		done
		[ -z "$pids" ] && return 0
		# shellcheck disable=SC2086
		kill -s $sig $pids 2>/dev/null
		sleep 0.5
	done
}
