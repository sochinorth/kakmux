# smoke: everyday flows end to end in a kakmux, keys typed into an attached
# client's terminal (so popups get them too): pickers, gd/gr, diagnostics,
# ]d ]g, surround, clipboard, splits and <c-w>, bufferline, auto-save
# golden
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp fzf fd rg
P=$R/p/proj; mkproj "$P"
CWD=$P WAIT=1 start kakmux sm main.c
attachf sm
sleep 3
B() { qv sm '%val{bufname} %val{cursor_line} %val{cursor_column}'; }
L() { rm -f "$R/o/l"; send sm "evaluate-commands -draft %{ execute-keys x; echo -to-file $R/o/l %val{selection} }"; cat "$R/o/l"; }
WAIT2=1.5

echo "== file picker: <space>f point.c"
term sm ' f'; term sm 'point.c'; term sm '\r'
expect "file picker" "$(B)" "point.c 1 1"
echo "== buffer picker: <space>b main"
term sm ' b'; term sm 'main'; term sm '\r'
expect "buffer picker" "$(B)" "main.c 1 1"
echo "== gd on point_dist2 (main.c -> point.c definition)"
send sm "execute-keys gg/point_dist2<ret>"
term sm 'gd'; sleep 1
expect "gd" "$(B)" "point.c 4 5"
echo "== gr from the definition: references picker"
term sm 'gr'; sleep 1.5
expect "references picker: 4 locations" "$(nlines "$R"/tmp/kak-picker.*/list)" 4
term sm '\r'; sleep 1
expect_match "gr + enter: a reference" "$(B)" "*.[ch] * *"
send sm "buffer main.c"
echo "== diagnostics: an error, inline lines, ]d"
send sm "execute-keys 'gg/twice = <ret>;ic<esc>'"
send sm "execute-keys 'gg/return 0<ret>xcreturn zz;<esc>gg'"
sleep 4
q sm '%opt{line_diags_n} %opt{lsp_diag_errors}'
term sm ']d'; sleep 1
expect "]d" "$(qv sm '%val{bufname} %val{selection_desc}')" "main.c 14.9,14.8"
cap sm | grep -n '└─\|●' | head -5
echo "== git gutter, ]g"
send sm 'execute-keys gg'
term sm ']g'; sleep 0.5
expect "]g: the hunk, lines 13-14" "$(qv sm '%val{bufname} %val{selection_desc}')" "main.c 13.1,14.12"
q sm '%opt{git_gutter_flags}'
echo "== surround: ms( on a word, mr([ , md["
send sm "execute-keys 'gg/util_twice<ret>'"
term sm 'ms('; sleep 0.5
expect "ms(" "$(L)" "int (util_twice)(int v);"
term sm 'mr(['; sleep 0.5
expect "mr([" "$(L)" "int [util_twice](int v);"
term sm 'md['; sleep 0.5
expect "md[" "$(L)" "int util_twice(int v);"
echo "== clipboard: <space>y then <space>R (copy/paste via a file)"
send sm "set-option global clipboard_copy 'cat > $R/o/clip'; set-option global clipboard_paste 'cat $R/o/clip'"
rm -f "$R/o/clip"
send sm "execute-keys 'gg/util_twice<ret>'"
term sm ' y'; sleep 0.5
expect "yank -> clip" "$(cat "$R/o/clip" 2>&1)" "util_twice"
send sm "execute-keys 'gg/printf<ret>'"
term sm ' R'; sleep 0.5
expect "paste R" "$(L)" '	util_twice("dist2 = %d\n", point_dist2(a, b));'
term sm 'u'
echo "== splits: :vs, :hs, <c-w> l/h/w/o"
send sm 'vsplit'; sleep 1.2
send sm 'hsplit'; sleep 1.2
tm sm list-panes -t main -F '#{pane_id} #{pane_active} #{@kak_client} #{pane_width}x#{pane_height}'
term sm '\027h'; sleep 0.6
expect "<c-w>h" "$(tm sm display-message -p -t main '#{@kak_client}')" client2
term sm '\027l'; sleep 0.6
expect "<c-w>l" "$(tm sm display-message -p -t main '#{@kak_client}')" client1
term sm '\027w'; sleep 0.6
expect "<c-w>w" "$(tm sm display-message -p -t main '#{@kak_client}')" client0
term sm '\027o'; sleep 1.2
expect "<c-w>o" "$(tm sm list-panes -t main -F '#{pane_id} #{@kak_client}')" "%0 client0"
echo "== bufferline"
term sm 'j'; sleep 0.5
tm sm show-options -p -t main @kak_bufferline | sed 's/#\[[^]]*\]//g'
echo "== auto-save on terminal focus-out"
expect "before focus-out: clean on disk" "$(cd "$P" && git status --short | tr '\n' ' ')" ""
term sm '\033[O'; sleep 1.5; term sm '\033[I'
expect "after focus-out: written" "$(cd "$P" && git status --short | tr '\n' ' ')" " M main.c "
expect "modified" "$(qv sm '%val{modified}')" false
echo "== debug"
dbge sm | grep -v 'LSP: INFO'
