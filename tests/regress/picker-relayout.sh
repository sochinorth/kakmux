# picker-relayout: kak-picker --layout run as fzf runs it, on events that
# come late: one for an older query (its matches, the query typed since),
# then one for the list a relayout is about to replace. Neither may keep the
# list on screen from being laid out for its own rows (the palette's
# `%val{cl…` was cut at 37 columns rather than 55 now and then); a key typed
# meanwhile asks for the reload again, which fzf may have dropped
# covers: bin/kak-picker
. "$(dirname "$0")/../lib/h.sh"
D=$R/p/picker; mkdir -p "$D"
# rows: hidden fields, widths, cells (\037 between); the widths of the rows
# (the first column's) call for 58, 37 and 55 columns
cell() { printf "%${1}s" '' | tr ' ' "${2:-x}"; }
row() { printf 'c\t%s\t0\t%s %s %s\t%s\037%s\037%s\n' "$1" "$2" "$3" "$4" "$(cell "$2" "$5")" "$(cell "$3" k)" "$(cell "$4" d)"; }
{ row vsplit 11 17 83 v; row a 58 9 47 a; row b 37 10 20 b; row c 55 6 24 c; printf '\036\n'; } > "$D/rows"
# the list fzf has: N rows as kak-picker lays them out (" @GEN" after the
# widths, when the version tags its lists), for the matched file
items() {
	g=$1; shift
	for n; do awk -F '\t' -v n="$n" -v g="${TAG:+ @$g}" '$2 == n { print $1 "\t" $2 "\t" $3 "\t" $4 g "\t" $5 }' "$D/rows"; done > "$R/o/matched"
}
# event QUERY: fzf's --layout transform (rows on screen in $R/o/matched)
event() {
	FZF_QUERY=$1 FZF_POS=1 FZF_MATCH_COUNT=$(wc -l < "$R/o/matched") FZF_COLUMNS=156 FZF_LINES=42 FZF_INPUT_STATE=enabled \
		"$C/bin/kak-picker" --layout "$D" rr 0.33 "$R/o/matched" | sed 's#reload-sync:cat .*/#reload-sync:#'
}
widths() { cut -f1 "$D/cols"; }
pending() { "$C/bin/kak-picker" --pending "$D" | sed 's#reload-sync:cat .*/#reload-sync:#'; }
# the list as emit leaves it (30,17, list number 1)
TAG=; grep -q ' @' "$C/bin/kak-picker" && TAG=1
printf '30,17,\t0\t\t\t0\t1\n' > "$D/cols"
# 1. the result for "vs" (the vsplit and "a" rows), FZF_QUERY already "vsplit"
items 1 vsplit a; event vsplit > /dev/null
expect "an older query's result lays out for its rows" "$(widths)" "58,17,"
# a key typed before that list is seen asks for its reload again (fzf drops
# a reload when the next key's search comes before it starts)
expect "a key typed asks for the reload to come" "$(pending)" "reload-sync:shown.1'"
# 2. "vsplit"'s result on that same list, before the reload came: no
# relayout from rows that won't be on screen
items 1 vsplit b; out=$(event vsplit)
expect "the list being replaced lays nothing out" "$out$(widths)" "58,17,"
# 3. on the list laid out (58): "vsplit"'s rows there call for 55
items 2 vsplit b c; event vsplit > /dev/null
expect "the list on screen lays out for its rows" "$(widths)" "55,17,"
items 3 vsplit b c; out=$(event vsplit)
expect "and then holds still" "$out$(widths)" "55,17,"
expect "with no reload to come" "$(pending)" ""
# flip-flop: widths that match other rows that call for the widths before
# (A's rows call for B, B's for A): back to A once, not again
printf '30,17,\t0\t\t\t0\t1\n' > "$D/cols"
items 1 vsplit b; event x > /dev/null                 # 30 -> 37
items 2 vsplit c; event x > /dev/null                 # 37 -> 55
items 3 vsplit b; out=$(event x)                      # 55 -> 37: been there
expect "no relayout back to widths the query had" "$out$(widths)" "55,17,"
