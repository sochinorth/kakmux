# typing: shells kak starts while typing (general, on a line with inline
# diagnostics, a fast burst), j/k moves, keystroke latency, idle (0 shells)
# covers: kakrc rc/*.kak
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
P=$R/p/proj; mkproj "$P"
SHW=1 CWD=$P WAIT=1 start kakmux pt main.c
attach pt
waitdiags pt 0; sleep 4
# lat CHARS: per char, us from send-keys to the screen changing
lat() {
	tot=0 nk=0 max=0
	for c in $(echo "$1" | sed 's/./& /g'); do
		before=$(tm pt capture-pane -p -t main | md5sum)
		t0=$(date +%s%N)
		tm pt send-keys -t main "$c"
		k=0; while [ "$(tm pt capture-pane -p -t main | md5sum)" = "$before" ] && [ $k -lt 3000 ]; do k=$((k+1)); done
		t1=$(date +%s%N); d=$(( (t1 - t0) / 1000 ))
		tot=$((tot + d)); nk=$((nk + 1)); [ $d -gt $max ] && max=$d
		sleep "${GAP:-0.3}"
	done
	metric "$2-latency-mean" $((tot / nk)) us; metric "$2-latency-max" $max us
	expect_le "$2: mean latency (us)" $((tot / nk)) 100000
	expect_le "$2: max latency (us)" $max 400000
}
echo "== 1: general typing, 8 chars on a new line 0.15 s apart, <esc>, 1 s"
: > "$KM_SHLOG"
WAIT2=0.15; keys pt g g; keys pt j j j j j j; keys pt o; for c in a b c d e f g h; do keys pt $c; done; keys pt Escape; sleep 1
metric typing-shells "$(shells)"; shtop
expect_le "general typing: shells for 8 keys" "$(shells)" 60
keys pt u; sleep 3
echo "== 2: on a line with an error (inline diagnostics drawn), 8 chars 0.3 s apart"
send pt "execute-keys 'gg/return 0<ret>cundefined_x<esc>'"; waitdiags pt 1; sleep 1
send pt "execute-keys 'gg/undefined_x<ret>gl'"; sleep 1
keys pt a; sleep 1
: > "$KM_SHLOG"
WAIT2=0.3; for c in a b c d e f g h; do keys pt $c; done; sleep 2
metric error-line-shells "$(shells)"; shtop
expect_le "error line: shells for 8 keys" "$(shells)" 50
keys pt Escape; sleep 1
echo "== 3: latency, insert on the error line, 8 chars"
keys pt a; sleep 1
GAP=0.3 lat abcdefgh insert
keys pt Escape; sleep 1
echo "== 4: normal-mode j/k, 10 keys"
send pt "execute-keys gk"; sleep 0.5
: > "$KM_SHLOG"
GAP=0.3 lat jjjjjkkkkk jk
metric jk-shells "$(shells)"; shtop 4
expect_le "j/k: shells for 10 keys" "$(shells)" 15
echo "== 5: fast burst: 20 chars 20 ms apart on a new line, + 2 s"
keys pt o; sleep 1
: > "$KM_SHLOG"
for c in a b c d e f g h i j k l m n o p q r s t; do tm pt send-keys -t main $c; sleep 0.02; done; sleep 2
metric burst-shells "$(shells)"; shtop 4
expect_le "burst: shells for 20 keys" "$(shells)" 60
keys pt Escape
echo "== 6: idle 5 s"
sleep 2; : > "$KM_SHLOG"
pid=$(kakpid pt)
c0=$(cputicks "$pid"); sleep 5; c1=$(cputicks "$pid")
metric idle-shells "$(shells)"; metric idle-cpu-ticks $((c1 - c0))
expect "idle: no shells" "$(shells)" 0
expect_le "idle: kak cpu ticks in 5 s" $((c1 - c0)) 5
expect "debug" "$(dbge pt | grep -i 'error\|fail')" ""
