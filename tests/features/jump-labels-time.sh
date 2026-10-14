# jump-labels-time: labelling a full screen of words is quick
# covers: rc/pickers.kak
. "$(dirname "$0")/../lib/h.sh"
P=$R/p/jl; mkdir -p "$P"
for i in $(seq 200); do echo "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron"; done > "$P/big.txt"
CWD=$P WAIT=2 start kakmux jl3 big.txt
for i in 1 2 3; do
	send jl3 "echo -debug T0 %sh{date +%s%N}; jump-labels; echo -debug T1 %sh{date +%s%N}"; keys jl3 Escape
done
dbg jl3 | grep '^T' | awk '{ if ($1=="T0") t=$2; else printf "%d\n", ($2-t)/1000000 }' > "$R/o/ms"
cat "$R/o/ms" | sed 's/$/ ms/'
expect_le "slowest of 3 (ms)" "$(sort -n "$R/o/ms" | tail -1)" 100
