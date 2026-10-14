# jitter: typing in several ways (bursts, key by key, Enter in a block, file
# scope) while the screen is sampled as fast as tmux allows: the text never
# shifts sideways, no ● or git flag drops from an unchanged line, lines don't
# jump up and back down. The frames: $R/frames (run.sh -k keeps them).
# tags: slow
# covers: rc/inline-diagnostics.kak rc/decorations.kak rc/workspace.kak
# timeout: 400
. "$(dirname "$0")/../lib/h.sh"
. "$KM_LIB/visual.sh"
need clangd kak-lsp python3
P=$R/p/vis; mkvproj "$P"
CWD=$P WAIT=1 start kakmux vis main.c
attachf vis
waitdiags vis 0; sleep 4
T=$R/frames
B() { name=$1; shift; SECS=${SECS:-5} burst vis "$T/$name" "$@"; }
# s1: clean file, then one edit, then undo (clean again)
mkdir -p "$T"
cap vis > "$T/s1-clean.p"
send vis 'execute-keys 11gAy<esc>'; sleep 2.5; cap vis > "$T/s1-edited.p"
send vis 'execute-keys u'; sleep 2.5; cap vis > "$T/s1-undone.p"
flags() { grep -c '^.[ 0-9]*│[▍▔]' "$1"; }
expect "s1: clean: no git flags" "$(flags "$T/s1-clean.p")" 0
expect "s1: an edit: its flag" "$(flags "$T/s1-edited.p")" 1
expect "s1: undone: flag gone" "$(flags "$T/s1-undone.p")" 0
# s2: burst, no delay: open a line in the loop, type, escape
B s2 11 o a a a a a a a a Space x '\;' Escape
# s3: on that error line, append at EOL key by key (InsertIdle between keys)
DELAY=0.15 B s3 12 A BSpace b c d e f g
tm vis send-keys -t main Escape; sleep 1.5
# s4: same, faster than the idle timeout
DELAY=0.03 B s4 12 A h i j k l m n
tm vis send-keys -t main Escape; sleep 1.5
# s5: Enter in a block, key by key
send vis 'execute-keys 12gxd'; sleep 2
DELAY=0.15 B s5 10 o x Enter y '\;' Enter Enter z
tm vis send-keys -t main Escape; sleep 1.5
# s6: file scope, unknown type name, key by key
send vis 'edit!'; sleep 2.5
DELAY=0.12 SECS=6 B s6 4 o a a a a a a a a Space x '\;' Enter s t
tm vis send-keys -t main Escape; sleep 1.5
python3 -I "$KM_LIB/frames.py" "$T"/s[2-6] | while read -r sc fr col dot git rev; do
	echo "$sc $fr $col $dot $git $rev"
	[ "${fr#frames=}" -ge 2 ] || fail "$sc: the screen never changed"
	expect "$sc: no sideways shifts" "$col" col=0
	expect "$sc: no ● drops" "$dot" dot=0
	expect "$sc: no git flag drops" "$git" git=0
	expect "$sc: no vertical reversals" "$rev" rev=0
done
# s7: cursor at the end of an error line, normal and insert mode: the
# inline lines hang past the newline, the cursor stays at the line's end
send vis 'execute-keys 5ggl'; sleep 1; cap vis | sed -n 4,8p > "$T/s7-normal.p"
send vis 'execute-keys A'; sleep 1; cap vis | sed -n 4,8p > "$T/s7-insert.p"
cat "$T/s7-normal.p"
expect "s7: same layout in insert mode" "$(cat "$T/s7-insert.p")" "$(cat "$T/s7-normal.p")"
tm vis send-keys -t main Escape; sleep 0.5
expect "debug" "$(dbge vis)" ""
