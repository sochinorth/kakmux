# rename-edges: rename with a clean open buffer, a dirty one and a README
# mention; a rename that can't happen (buffers it opened closed by the 20 s
# timer); a workspace edit into an unopened file; a clangd quickfix
# tags: slow
# golden
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
P=$R/p/proj; mkproj "$P"
printf 'point_dist2 is documented here.\n' > "$P/README.md"
(cd "$P" && git add README.md && git commit -qm readme)
CWD=$P WAIT=1 start "${MODE:-kakmux}" r3 main.c
waitdiags r3 0; sleep 4
st() { (cd "$P" && git status --short | tr '\n' ' '); echo; }
mod() { for f in "$@"; do printf '%s: ' "$f"; rm -f "$R/o/m"; send r3 "try %{ evaluate-commands -buffer $P/$f %{ echo -to-file $R/o/m %val{modified} } } catch %{ echo -to-file $R/o/m closed }"; cat "$R/o/m"; printf '  '; done; echo; }
has() { rm -f "$R/o/m"; send r3 "try %{ evaluate-commands -buffer $P/$1 %{ evaluate-commands -draft %{ execute-keys '%'; echo -to-file $R/o/m %val{selection} } } }"; grep -c "$2" "$R/o/m" 2>/dev/null; }
echo "== 1: point.c open+clean, util.c open+dirty (unrelated edit), README has the word"
send r3 "evaluate-commands -draft %{ edit $P/point.c }; evaluate-commands -draft %{ edit $P/util.c; execute-keys 'ggO// dirty<esc>' }"
mod main.c point.c util.c point.h README.md
send r3 "execute-keys gg/point_dist2<ret>"
send r3 "lsp-rename point_distsq"
sleep 3
echo "disk:"; st
mod main.c point.c util.c point.h README.md
cap r3 | tail -1 | cut -c1-90
q r3 '%val{buflist}'
expect "util.c keeps its dirty line, has the new name" "$(has util.c dirty) $(has util.c point_distsq)" "1 1"
echo "== write in point.c buffer"
send r3 "evaluate-commands -buffer $P/point.c write"
st
echo "== 2: rename on a keyword (no rename possible); opened buffers closed after the 20s timer"
send r3 "execute-keys gg/return<ret>"
send r3 "lsp-rename foo"
sleep 2
q r3 '%val{buflist}' armed: '%opt{lsp_edit_armed}'
cap r3 | tail -1 | cut -c1-120
sleep 20
q r3 '%val{buflist}' armed: '%opt{lsp_edit_armed}'
echo "== 3: workspace edit (code action path) into an unopened file, held"
send r3 "write-all"
send r3 "delete-buffer $P/point.h"
q r3 '%val{buflist}'
send r3 "lsp-apply-workspace-edit '{\"changes\":{\"file://$P/point.h\":[{\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":0}},\"newText\":\"/* hdr */\\\\n\"}]}}'"
sleep 2
st; mod point.h
expect "point.h buffer has the edit" "$(has point.h hdr)" 1
cap r3 | tail -1 | cut -c1-90
echo "== 4: clangd quickfix (undeclared identifier typo), sync code action"
send r3 "edit $P/main.c; execute-keys 'gg/point_distsq<ret>cpoint_distsw<esc>'; write"
sleep 3
send r3 "execute-keys 'gg/point_distsw<ret>'"
send r3 "try %{ lsp-code-actions-sync quickfix } catch %{ echo -debug CA %val{error} }"
sleep 2
st; mod main.c
expect "main.c fixed" "$(has main.c point_distsq)" 1
cap r3 | tail -1 | cut -c1-90
echo "== debug"
dbge r3 | grep -v 'LSP: INFO' | head -30
