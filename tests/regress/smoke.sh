# smoke: everyday flows end to end in a kakmux, keys typed into an attached
# client's terminal (so popups get them too): pickers, gd/gr, diagnostics,
# ]d ]g, surround, clipboard, splits and <c-w>, bufferline, auto-save
# golden
# covers: kakrc rc/*.kak bin/* kakmux.conf scripts/kakmux
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp fzf fd rg
P=$R/p/proj; mkproj "$P"
CWD=$P start kakmux sm main.c
attachf sm
B() { qv sm '%val{bufname} %val{cursor_line} %val{cursor_column}'; }
L() { rm -f "$R/o/l"; send sm "evaluate-commands -draft %{ execute-keys x; echo -to-file $R/o/l %val{selection} }"; cat "$R/o/l"; }

echo "== file picker: <space>f point.c"
term sm ' f'; fzfready; term sm 'point.c'; fzfready point.c; term sm '\r'
expectw "file picker" "point.c 1 1" B
echo "== buffer picker: <space>b main"
term sm ' b'; fzfready; term sm 'main'; fzfready main; term sm '\r'
expectw "buffer picker" "main.c 1 1" B
echo "== gd on point_dist2 (main.c -> point.c definition)"
send sm "execute-keys gg/point_dist2<ret>"
term sm 'gd'
expectw "gd" "point.c 4 5" B
echo "== gr from the definition: references picker"
term sm 'gr'; fzfready
expect "references picker: 4 locations" "$(nlines "$R"/tmp/kak-picker.*/list)" 4
term sm '\r'; pickerdone sm
expect_match "gr + enter: a reference" "$(B)" "*.[ch] * *"
send sm "buffer main.c"
echo "== diagnostics: an error, inline lines, ]d"
send sm "execute-keys 'gg/twice = <ret>;ic<esc>'"
send sm "execute-keys 'gg/return 0<ret>xcreturn zz;<esc>gg'"
waitdiags sm; waitout 10 "'1' ' ● 1'" q sm '%opt{line_diags_n} %opt{lsp_diag_errors}'
q sm '%opt{line_diags_n} %opt{lsp_diag_errors}'
term sm ']d'
expectw "]d" "main.c 14.9,14.8" qv sm '%val{bufname} %val{selection_desc}'
cap sm | grep -n '└─\|●' | head -5
echo "== git gutter, ]g"
send sm 'execute-keys gg'
waitout 10 "'13' '0| ' '13|{GitGutterModify}▍' '14|{GitGutterModify}▍'" q sm '%opt{git_gutter_flags}'
term sm ']g'
expectw "]g: the hunk, lines 13-14" "main.c 13.1,14.12" qv sm '%val{bufname} %val{selection_desc}'
q sm '%opt{git_gutter_flags}'
echo "== surround: ms( on a word, mr([ , md["
send sm "execute-keys 'gg/util_twice<ret>'"
term sm 'ms('
expectw "ms(" "int (util_twice)(int v);" L
term sm 'mr(['
expectw "mr([" "int [util_twice](int v);" L
term sm 'md['
expectw "md[" "int util_twice(int v);" L
echo "== clipboard: <space>y then <space>R (copy/paste via a file)"
send sm "set-option global clipboard_copy 'cat > $R/o/clip'; set-option global clipboard_paste 'cat $R/o/clip'"
rm -f "$R/o/clip"
send sm "execute-keys 'gg/util_twice<ret>'"
term sm ' y'
expectw "yank -> clip" "util_twice" cat "$R/o/clip"
send sm "execute-keys 'gg/printf<ret>'"
term sm ' R'
expectw "paste R" '	util_twice("dist2 = %d\n", point_dist2(a, b));' L
term sm 'u'
echo "== splits: :vs, :hs, <c-w> l/h/w/o"
send sm 'vsplit'; panes sm 2
send sm 'hsplit'; panes sm 3
settle tm sm list-panes -t main -F '#{pane_id} #{pane_active} #{@kak_client} #{pane_width}x#{pane_height}'
AC() { tm sm display-message -p -t main '#{@kak_client}'; }
term sm '\027h'
expectw "<c-w>h" client2 AC
term sm '\027l'
expectw "<c-w>l" client1 AC
term sm '\027w'
expectw "<c-w>w" client0 AC
term sm '\027o'
expectw "<c-w>o" "%0 client0" tm sm list-panes -t main -F '#{pane_id} #{@kak_client}'
echo "== bufferline"
BL() { tm sm show-options -p -t main @kak_bufferline | sed 's/#\[[^]]*\]//g'; }
term sm 'j'
waitout 10 '@kak_bufferline " main.c[+]  point.c "' BL
BL
echo "== auto-save on terminal focus-out"
expect "before focus-out: clean on disk" "$(cd "$P" && git status --short | tr '\n' ' ')" ""
ST() { cd "$P" && git status --short | tr '\n' ' '; }
term sm '\033[O'
expectw "after focus-out: written" " M main.c " ST
term sm '\033[I'
expect "modified" "$(qv sm '%val{modified}')" false
echo "== debug"
dbge sm | grep -v 'LSP: INFO'
