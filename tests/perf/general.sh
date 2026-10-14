# general: a long mixed session: buffer switching, 62 buffers (bufferline),
# idle, pickers' time to fzf, a 50k-line file with 25 gutter flags and 50
# errors (moves, typing, a burst, background jobs), pickers with it open, 30
# rounds of switching and typing (kak keeps answering, RSS), temp files
# tags: slow serial
# covers: kakrc rc/*.kak bin/*
# timeout: 1200
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp fzf fd rg
P=$R/p/proj; mkproj "$P"; mkmany "$P"; mkbig "$P/big.c"
(cd "$P" && git add -A && git commit -qm big)
# unsaved-to-git changes: 25 changed lines spread over the file (gutter flags)
awk '/^\treturn x \+ 1;$/ && ++c % 250 == 1 { sub(/1;/, "2;") } { print }' "$P/big.c" > "$P/big.tmp" && mv "$P/big.tmp" "$P/big.c"
SHW=1 CWD=$P WAIT=1 start kakmux pg main.c
attachf pg
waitdiags pg 0; sleep 4
pid=$(kakpid pg)
cpu() { sed 's/.*) //' "/proc/$pid/stat" | awk '{ print $12 + $13 + $14 + $15 }'; }
rss() { awk '/VmRSS/ { print $2 }' "/proc/$pid/status"; }
# kak's descendants now, less kak-lsp and its servers
desc() { ps -eo pid=,ppid=,comm= | awk -v root="$pid" '{ p[$1] = $2; c[$1] = $3 } END { for (x in p) { y = x; while (y in p && y != root && y > 1) y = p[y]; if (y == root && x != root && c[x] !~ /kak-lsp|clangd/) n++ } print n + 0 }'; }
# the most descendants seen, sampled every 50 ms until $R/o/stop-sample
sampler() { rm -f "$R/o/stop-sample"; echo 0 > "$R/o/max"; ( m=0; until [ -e "$R/o/stop-sample" ]; do n=$(desc); [ "$n" -gt $m ] && m=$n && echo $m > "$R/o/max"; sleep 0.05; done ) & }
mark() { : > "$KM_SHLOG"; c0=$(cpu); }
end() { echo "  shells $(shells), kak cpu $(( ($(cpu) - c0) * 10 )) ms, rss $(rss) kB"; metric "$1-shells" "$(shells)"; metric "$1-cpu" $(( ($(cpu) - c0) * 10 )) ms; }
pk() { t0=$(date +%s%N); printf "$1" > "$R/o/in-pg"; k=0; until [ -n "$(myfzf)" ] || [ $k -gt 500 ]; do k=$((k + 1)); sleep 0.01; done; t1=$(date +%s%N); ms=$(( (t1 - t0) / 1000000 )); echo "  $2: $ms ms"; metric "picker-$3" $ms ms; expect_le "$2: time to fzf (ms)" $ms "${4:-1500}"; sleep 0.7; printf '\033' > "$R/o/in-pg"; sleep 1; }
WAIT2=0.3
echo "== 1: buffer switching, 2 buffers, 10 switches (:buffer)"
send pg 'edit point.c'; send pg 'buffer main.c'; sleep 2
mark; for k in 1 2 3 4 5; do send pg 'buffer point.c'; sleep 0.3; send pg 'buffer main.c'; sleep 0.3; done; sleep 1; end switch2
expect_le "10 switches: shells" "$(shells)" 40
echo "== 2: opening 60 buffers"
mark; i=1; while [ $i -le 60 ]; do send pg "edit many/m$i.c"; i=$((i + 1)); done; sleep 3; end open60
echo "== 3: 62 buffers: j x10 in one, then 10 switches"
send pg 'buffer many/m30.c'; sleep 1
mark; for k in 1 2 3 4 5 6 7 8 9 10; do term pg 'j'; done; sleep 1; end j62
expect_le "j x10 with 62 buffers: shells" "$(shells)" 15
mark; for k in 1 2 3 4 5; do send pg 'buffer many/m1.c'; sleep 0.3; send pg 'buffer many/m2.c'; sleep 0.3; done; sleep 1; end switch62
expect_le "10 switches with 62 buffers: shells" "$(shells)" 40
echo "== 3b: idle 10 s with 62 buffers"
sleep 2; mark; sleep 10; end idle62
expect "idle, 62 buffers: no shells" "$(shells)" 0
echo "== 4: pickers: ms from the keys to fzf running (62 buffers)"
pk ' b' 'buffer picker' b; pk ' b' 'buffer picker again' b2; pk ' f' 'file picker' f; pk ' /' 'grep picker' g; pk ' ?' 'palette (first)' p 3000; pk ' ?' 'palette again' p2
echo "== 5: the 50k-line file: open, j x10 at line 25000, type 8 chars, a burst"
mark; send pg 'edit big.c'; sleep 8; end bigopen
expect "gutter flags in big.c" "$(qv pg '%opt{git_gutter_flags}' | wc -w)" 27
send pg 'execute-keys 25004g'; sleep 2
mark; for k in 1 2 3 4 5 6 7 8 9 10; do term pg 'j'; done; sleep 1; end bigj
term pg 'A'
sampler
mark; for c in a b c d e f g h; do term pg $c; done; sleep 3; end bigtype
touch "$R/o/stop-sample"; sleep 0.2; metric bigtype-max-children "$(cat "$R/o/max")"
expect_le "typing in big.c: most kak child processes at once" "$(cat "$R/o/max")" 10
sampler
mark; for c in a b c d e f g h i j k l m n o p q r s t; do printf $c > "$R/o/in-pg"; sleep 0.1; done; sleep 3; end bigburst
touch "$R/o/stop-sample"; sleep 0.2; metric bigburst-max-children "$(cat "$R/o/max")"
expect_le "burst in big.c: most kak child processes at once" "$(cat "$R/o/max")" 10
esc pg; sleep 1
echo "== 5b: pickers with big.c open"
pk ' b' 'buffer picker (62 + big.c)' bbig 2000; pk ' b' 'buffer picker again' bbig2 2000
echo "== 6: idle 10 s (big.c shown)"
sleep 2; mark; sleep 10; end idlebig
expect "idle, big.c: no shells" "$(shells)" 0
echo "== 7: long session: 30 rounds (switch x4, type+undo in main.c and big.c, buffer picker every 10)"
r=1; r0=$(rss); c0=$(cpu)
while [ $r -le 30 ]; do
	send pg 'buffer many/m5.c'; send pg 'buffer many/m6.c'; send pg 'buffer main.c'
	term pg 'o'; for c in a b c d e; do term pg $c; done; esc pg; term pg 'u'
	send pg 'buffer big.c'
	term pg 'A'; for c in x y z; do term pg $c; done; esc pg; term pg 'u'
	[ $((r % 10)) -eq 0 ] && { pk ' b' "  buffer picker, round $r" "round$r" 2000; echo "  rss round $r: $(rss) kB, gutter files $(ls "$R"/tmp/kak-git-gutter.*/ 2>/dev/null | wc -l)"; }
	alive pg || { fail "round $r: kak stopped answering$(kill -0 "$pid" 2>/dev/null || echo ' (it died)')"; cap pg | grep -i 'fatal\|error' | head -3; break; }
	r=$((r + 1))
done
metric session-cpu $(( ($(cpu) - c0) * 10 )) ms; metric session-rss-growth $(( $(rss) - r0 )) kB
expect_le "30 rounds: RSS growth (kB)" $(( $(rss) - r0 )) 200000
echo "== 8: temp files"
ls "$R/tmp" | sed 's/\.[^.]*$//' | sort | uniq -c
expect_le "gutter files" "$(ls "$R"/tmp/kak-git-gutter.*/ 2>/dev/null | wc -l)" 4
expect "debug" "$(dbge pg | grep -i 'error\|fail' | grep -v 'LSP:' | head -5)" ""
