# profile: kak's own time (debug profile: hooks and the commands sent back to
# it) and CPU, typing 8 chars on a line with an error and moving j/k 10 times
# covers: kakrc rc/*.kak
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
P=$R/p/proj; mkproj "$P"
CWD=$P WAIT=1 start kakmux pp main.c
attach pp
waitdiags pp 0; sleep 4
pid=$(kakpid pp)
cpu() { sed 's/.*) //' "/proc/$pid/stat" | awk '{ print $12 + $13 + $14 + $15 }'; }
prof() { # the top-level hooks' and remote commands' times since MARK-$1
	dbg pp | sed -n "/^MARK-$1\$/,\$p" | awk '
		/^hook .* took [0-9]+ us/ { match($0, /took [0-9]+ us/); t = substr($0, RSTART + 5, RLENGTH - 8); h = $2; sub(/\(.*/, "", h); sub(/^\047/, "", h); H[h] += t; N[h]++; tot += t }
		/^command (lsp-show-goto-buffer|git-gutter-set|git-gutter-located|git-status-set) took/ { match($0, /took [0-9]+ us/); t = substr($0, RSTART + 5, RLENGTH - 8); H[$2] += t; N[$2]++; tot += t }
		END { for (h in H) printf "    %-34s %4d x %7.1f ms\n", h, N[h], H[h] / 1000; printf "total %d\n", tot / 1000 }' | sort -k4 -rn
}
send pp "execute-keys 'gg/return 0<ret>cundefined_x<esc>'"; waitdiags pp 1; sleep 1
send pp "execute-keys 'gk/undefined_x<ret>gl'"; sleep 1
keys pp a; sleep 1
send pp "set-option global debug profile; echo -debug MARK-1"
c0=$(cpu); for c in a b c d e f g h; do keys pp $c; sleep 0.3; done; sleep 2; c1=$(cpu)
send pp "set-option global debug ''"
prof 1 > "$R/o/p1"; grep -v '^total' "$R/o/p1"
t=$(sed -n 's/^total //p' "$R/o/p1")
metric typing-hook-ms "$t" ms; metric typing-cpu-ms $(( (c1 - c0) * 10 )) ms
expect_le "typing 8 chars on the error line: hook time (ms)" "$t" 400
expect_le "typing 8 chars on the error line: kak cpu (ms)" $(( (c1 - c0) * 10 )) 500
keys pp Escape; sleep 1
send pp "execute-keys gk"; sleep 0.5
send pp "set-option global debug profile; echo -debug MARK-2"
c0=$(cpu); for k in j j j j j k k k k k; do keys pp $k; sleep 0.3; done; sleep 1; c1=$(cpu)
send pp "set-option global debug ''"
prof 2 > "$R/o/p2"; grep -v '^total' "$R/o/p2"
t=$(sed -n 's/^total //p' "$R/o/p2")
metric jk-hook-ms "$t" ms; metric jk-cpu-ms $(( (c1 - c0) * 10 )) ms
expect_le "j/k x10: hook time (ms)" "$t" 150
expect_le "j/k x10: kak cpu (ms)" $(( (c1 - c0) * 10 )) 250
