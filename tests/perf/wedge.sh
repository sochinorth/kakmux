# wedge: steps after which kak once stopped answering (a big kak-tree-sitter
# highlight update racing the rest): 62 buffers, the 50k-line file, typing,
# pickers, then 30 rounds of switching and typing; kak must answer after
# every step. STEPS="..." to run others (see do_step).
# tags: slow serial
# covers: kakrc rc/*.kak bin/*
# timeout: 1800
. "$(dirname "$0")/../lib/h.sh"
need fzf kak-tree-sitter
P=$R/p/proj; mkproj "$P"; mkmany "$P"; mkbig "$P/big.c"
(cd "$P" && git add -A && git commit -qm big)
awk '/^\treturn x \+ 1;$/ && ++c % 250 == 1 { sub(/1;/, "2;") } { print }' "$P/big.c" > "$P/big.tmp" && mv "$P/big.tmp" "$P/big.c"
CWD=$P WAIT=1 start kakmux wg main.c
attachf wg
sleep 6
pid=$(kakpid wg)
pk() { printf "$1" > "$R/o/in-wg"; k=0; until [ -n "$(myfzf)" ] || [ $k -gt 500 ]; do k=$((k + 1)); sleep 0.01; done; sleep 0.7; printf '\033' > "$R/o/in-wg"; sleep 1; }
WAIT2=0.3
do_step() {
	case $1 in
	many) i=1; while [ $i -le 60 ]; do send wg "edit many/m$i.c"; i=$((i + 1)); done; sleep 3 ;;
	prof) send wg "set-option global debug profile" ;;
	noprof) send wg "set-option global debug ''" ;;
	big) send wg 'edit big.c'; sleep 8 ;;
	goto) send wg 'execute-keys 25004g'; sleep 2 ;;
	jj) for k in 1 2 3 4 5 6 7 8 9 10; do term wg j; done; sleep 1 ;;
	type) term wg A; for c in a b c d e f g h; do term wg $c; done; sleep 3 ;;
	burst) for c in a b c d e f g h i j k l m n o p q r s t; do printf $c > "$R/o/in-wg"; sleep 0.1; done; sleep 3 ;;
	esc) esc wg; sleep 1 ;;
	pickb) pk ' b' ;; pickf) pk ' f' ;; pickg) pk ' /' ;; pickp) pk ' ?' ;;
	idle) sleep 10 ;;
	m5) send wg 'buffer many/m5.c' ;;
	m6) send wg 'buffer many/m6.c' ;;
	main) send wg 'buffer main.c' ;;
	bigb) send wg 'buffer big.c' ;;
	pt) send wg 'buffer point.c' ;;
	omain) term wg o; for c in a b c d e; do term wg $c; done; esc wg; term wg u ;;
	abig) term wg A; for c in x y z; do term wg $c; done; esc wg; term wg u ;;
	*) echo "unknown step $1" ;;
	esac
}
rounds() { i=0; while [ $i -lt 30 ]; do printf ' m5 m6 main omain bigb abig'; i=$((i + 1)); done; }
STEPS=${STEPS:-prof many noprof pickb prof big noprof goto type burst esc pickb idle $(rounds)}
stepn=0
for s in $STEPS; do
	stepn=$((stepn + 1)); c0=$(cputicks "$pid"); t0=$(date +%s%N)
	do_step "$s"
	if ! alive wg; then
		sleep 5; c1=$(cputicks "$pid" 2>/dev/null); sleep 2
		fail "step $stepn ($s): no answer$(kill -0 "$pid" 2>/dev/null && echo ", kak cpu over 2 s after: $(( ($(cputicks "$pid") - c1) * 10 )) ms" || echo ': kak died')"
		cap wg | grep -i 'fatal\|error' | head -3
		break
	fi
done
echo "$stepn steps"
