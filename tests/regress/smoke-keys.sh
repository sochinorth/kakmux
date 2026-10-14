# smoke-keys: surround and clipboard typed key by key; gr's list
# golden
# covers: rc/keys.kak rc/workspace.kak rc/pickers.kak bin/kak-picker
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp fzf
P=$R/p/proj; mkproj "$P"
CWD=$P WAIT=1 start kakmux sm main.c
attachf sm
sleep 3
L() { rm -f "$R/o/l"; send sm "evaluate-commands -draft %{ execute-keys x; echo -to-file $R/o/l %val{selection} }"; printf '%-10s %s ' "$1" "$(cat "$R/o/l")"; q sm '%val{selection}'; }
send sm "execute-keys 'gg/util_twice<ret>'"
L start
term sm 'm'; term sm 's'; term sm '('; L 'ms('
term sm ';'; term sm 'm'; term sm 'r'; term sm '('; term sm '['; L ';mr(['
term sm ';'; term sm 'm'; term sm 'd'; term sm '['; L ';md['
term sm 'm'; term sm 'i'; term sm '('; L 'mi('
send sm "set-option global clipboard_copy 'cat > $R/o/clip'; set-option global clipboard_paste 'cat $R/o/clip'"
rm -f "$R/o/clip"
send sm "execute-keys 'gg/util_twice<ret>'"
term sm ' '; term sm 'y'
expect "clip" "$(cat "$R/o/clip")" util_twice
send sm "execute-keys 'gg/point_sum<ret>'"
term sm ' '; term sm 'R'; L 'paste R'
term sm ' '; term sm 'p'; L 'paste p'
echo "== gr list"
send sm "execute-keys 'gg/point_dist2<ret>'"
term sm 'g'; term sm 'r'; sleep 1.5
# (clangd's order)
cat "$R"/tmp/kak-picker.*/list | sort
term sm '\033'; sleep 0.5   # (to the popup's fzf)
# known (reported): ';' on a line whose inline diagnostics follow the cursor
# runs line-diags-follow's execute-keys ',;x' inside the NormalKey hook of
# that ';', which Kakoune refuses with this line in *debug*
dbge sm | grep -v '^recursive call of hook NormalKey/<semicolon>, not executing$'
