# big-file: a 50k-line C file: kak CPU per key typed (each followed by
# kak-tree-sitter's highlight update and the git gutter's diff), a burst, and
# how soon kak answers after it
# timeout: 400
# covers: rc/*.kak kakrc
. "$(dirname "$0")/../lib/h.sh"
need kak-tree-sitter
P=$R/p/proj; mkproj "$P"; mkbig "$P/big.c"
(cd "$P" && git add -A && git commit -qm big)
CWD=$P WAIT=1 start kakmux hl big.c
attachf hl
sleep 10
pid=$(kakpid hl)
echo "ts lang: $(qv hl '%opt{tree_sitter_lang}')"
send hl 'execute-keys 25004g'; sleep 2
term hl A; sleep 2
max=0
for c in a b c d e; do
	c0=$(cputicks "$pid"); printf $c > "$R/o/in-hl"; sleep 2.5
	ms=$(( ($(cputicks "$pid") - c0) * 10 )); [ $ms -gt $max ] && max=$ms
	echo "key $c: kak cpu $ms ms"
done
metric bigfile-key-cpu-max "$max" ms
expect_le "big file: kak cpu per key, worst of 5 (ms)" "$max" 1500
for c in f g h i j k l m n o; do printf $c > "$R/o/in-hl"; sleep 0.1; done
c0=$(cputicks "$pid"); printf p > "$R/o/in-hl"; t0=$(date +%s%N)
printf 'evaluate-commands -client client0 %%{ echo -to-file %s ok }\n' "$R/o/al" | kak -p "$PFX-hl"; t1=$(date +%s%N)
metric bigfile-burst-answer $(( (t1 - t0) / 1000000 )) ms
expect_le "big file: kak answers right after a burst (ms)" $(( (t1 - t0) / 1000000 )) 3000
sleep 4; c=$(( ($(cputicks "$pid") - c0) * 10 ))
metric bigfile-burst-cpu "$c" ms
expect_le "big file: burst of 11 keys settles, kak cpu (ms)" "$c" 6000
esc hl
printf 'nop\n' | kak -p "$PFX-hl" || fail "kak not answering"
