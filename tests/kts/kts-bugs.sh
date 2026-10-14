# kts-bugs: kak-tree-sitter 3.2.2's server bugs, fixed in a patched build
# (3.2.2-3): (1) a request processed twice when its client
# half-closes, and a socket fd kept per request; (2) a node ending after a
# newline reported at column 0 (parent of 1.2 -> 1.1,2.1 instead of 1.1,1.8);
# (3) a session that quits before its init answer stays tracked, so the next
# session of that name gets nothing; a live session sending session_begin
# again keeps working. Stock kak-tree-sitter fails this test.
# golden
# covers: tests/kts/*
. "$(dirname "$0")/../lib/h.sh"
need kak-tree-sitter python3
[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/kak-tree-sitter/grammars" ] || skip "no kak-tree-sitter grammars (ktsctl sync)"
K=$(cd "$(dirname "$0")" && pwd)
export KTS_TEST_LOG=$R/o/kts.log; : > "$KTS_TEST_LOG"
KR=$XDG_RUNTIME_DIR/kak-tree-sitter
W=$R/p/kts; mkdir -p "$W"
printf '#include <stdio.h>\n\nint add(int a, int b)\n{\n\treturn a + b;\n}\n\nint main(void)\n{\n\tprintf("%%d\\n", add(1, 2));\n\treturn 0;\n}\n' > "$W/test.c"
SA=$PFX-ktsA SB=$PFX-ktsB
kak-tree-sitter -ds -vvvv >/dev/null 2>&1; waitfor 5 test -S "$KR/socket"
[ -s "$KR/pid" ] || { fail "kak-tree-sitter server did not start"; exit 1; }
cd "$W" || exit 1
setsid kak -n -ui dummy -s "$SA" test.c -e "source $K/test.kak" </dev/null >/dev/null 2>&1 &
# p SESSION CMDS [N]: CMDS in its client, until it's done them and N SEL lines
# more are logged (kak-tree-sitter's answers come back later)
p() {
	_n=$(($(grep -c '^SEL' "$KTS_TEST_LOG") + ${3:-0})); rm -f "$R/o/p"
	echo "evaluate-commands -client client0 %{ $2 }; echo -to-file $R/o/p ok" | kak -p "$1"
	waitfile "$R/o/p"; waitfor 10 _sels "$_n"
}
_sels() { [ "$(grep -c '^SEL' "$KTS_TEST_LOG")" -ge "$1" ]; }
# ready SESSION: until its buffer's set up with kak-tree-sitter (its fifo)
ready() {
	rm -f "$R/o/r"
	echo "evaluate-commands -client client0 %{ echo -to-file $R/o/r %opt{tree_sitter_buf_fifo_path} }" | kak -p "$1" 2>/dev/null &&
	waitfile "$R/o/r" 1 && [ -s "$R/o/r" ]
}
waitfor 10 ready "$SA"
log() { grep -E '^(SEL|ERR|STATE|---)' "$KTS_TEST_LOG"; }

echo "## bug 2: node ends after a newline"
echo "--- include: parent of 1.2" >> "$KTS_TEST_LOG"
p "$SA" "select 1.2,1.2; tree-sitter-nav '\"parent\"'" 2
p "$SA" logstate
echo "--- walk parents from 5.10 up to the root" >> "$KTS_TEST_LOG"
p "$SA" "select 5.10,5.10" 1
for i in 1 2 3 4 5 6; do p "$SA" "tree-sitter-nav '\"parent\"'" 1; done
p "$SA" logstate
echo "--- text objects: function around" >> "$KTS_TEST_LOG"
p "$SA" "select 3.1,6.1; tree-sitter-text-objects function.around select" 2
p "$SA" logstate
log
expect "parent of 1.2 is the include line" "$(grep -A2 'parent of 1.2' "$KTS_TEST_LOG" | sed -n 3p)" "SEL 1.1,1.8"

echo "## bug 1: half-closing client, rapid requests"
count() { grep -c "$1" "$2"; }
for i in 1 2; do
	a0=$(count '^SEL' "$KTS_TEST_LOG"); p0=$(count 'processing request' "$KR/stdout.txt")
	p "$SA" "select 1.1,1.1"
	python3 -I "$K/halfclose.py" "$KR/socket" "$SA" "$W/test.c" 5.10,5.10
	sleep 1   # time for a second processing of it to show
	a1=$(count '^SEL' "$KTS_TEST_LOG"); p1=$(count 'processing request' "$KR/stdout.txt")
	expect "half-close $i: processed once, answered once" "processed=$((p1 - p0)) answers=$((a1 - a0 - 1))" "processed=1 answers=1"
done
for i in 1 2; do
	c0=$(count 'client connected' "$KR/stdout.txt"); p0=$(count 'processing request' "$KR/stdout.txt"); a0=$(count '^SEL' "$KTS_TEST_LOG")
	cmd="select 5.10,5.10;"; j=0; while [ $j -lt 20 ]; do cmd="$cmd tree-sitter-nav '\"parent\"';"; j=$((j + 1)); done
	echo "evaluate-commands -client client0 %{ $cmd }" | kak -p "$SA"
	sleep 3   # time for them all, and any extra, to show
	c1=$(count 'client connected' "$KR/stdout.txt"); p1=$(count 'processing request' "$KR/stdout.txt"); a1=$(count '^SEL' "$KTS_TEST_LOG")
	fds=$(ls -l "/proc/$(cat "$KR/pid")/fd" | grep -c socket)
	expect "20 rapid requests ($i)" "connections=$((c1 - c0)) processed=$((p1 - p0)) answers=$((a1 - a0 - 1)) socket_fds=$fds" "connections=20 processed=20 answers=20 socket_fds=1"
done

echo "## bug 3: a session gone before its init answer"
kak -n -ui dummy -s "$SB" test.c -e "source $K/test.kak; quit!" </dev/null >/dev/null 2>&1
sleep 1   # the server's init answer to a session already gone
expect "first $SB exited" "$(kak -l | grep -cx "$SB")" 0
setsid kak -n -ui dummy -s "$SB" test.c -e "source $K/test.kak" </dev/null >/dev/null 2>&1 &
waitfor 10 ready "$SB"
p "$SB" logstate
expect "second $SB set up" "$(grep STATE "$KTS_TEST_LOG" | tail -1)" "STATE sel=1.1,1.1 lang=c fifo=set"
grep -E "already tracked|registering session $SB" "$KR/stdout.txt" | sed 's/^.*Z //; s/^ *//'

echo "## a live session sending session_begin again"
echo 'evaluate-commands -client client0 %{ tree-sitter-session-begin; tree-sitter-session-begin }' | kak -p "$SA"
sleep 1.5   # (no answer to wait on: the server takes both in)
p "$SA" "select 5.10,5.10; tree-sitter-nav %{\"parent\"}" 2
p "$SA" logstate
expect "still answers" "$(grep STATE "$KTS_TEST_LOG" | tail -1)" "STATE sel=5.9,5.13 lang=c fifo=set"
for s in "$SA" "$SB"; do echo kill | kak -p "$s" 2>/dev/null; done
