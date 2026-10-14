# rename: lsp-rename edits buffers (opened as needed), not files on disk;
# undo per buffer gets back the disk text; redo + :write-all builds
# covers: rc/lsp.kak
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp make cc
P=$R/p/proj; mkproj "$P"
CWD=$P WAIT=1 start "${MODE:-kakmux}" r1 main.c
waitdiags r1 0; sleep 4   # clangd: background index
st() { (cd "$P" && git status --short | tr '\n' ' '); }
bufs() { for f in main.c point.c point.h util.c; do printf '%s: ' $f; rm -f "$R/o/m"; send r1 "try %{ evaluate-commands -buffer $P/$f %{ echo -to-file $R/o/m %val{modified} } } catch %{ echo -to-file $R/o/m closed }"; cat "$R/o/m"; printf ' '; done; }
expect "before: disk" "$(st)" ""
expect "before: buffers" "$(bufs)" "main.c: false point.c: closed point.h: closed util.c: closed "
send r1 "execute-keys gg/point_dist2<ret>"
send r1 "lsp-rename point_distsq"
sleep 3
expect "after rename: disk untouched" "$(st)" ""
expect "after rename: buffers modified" "$(bufs)" "main.c: true point.c: true point.h: true util.c: true "
for f in main.c point.c point.h util.c; do
	rm -f "$R/o/m"; send r1 "try %{ evaluate-commands -buffer $P/$f %{ evaluate-commands -draft %{ execute-keys '%'; echo -to-file $R/o/m %val{selection} } } }"
	expect "$f has the new name" "$(grep -c point_distsq "$R/o/m" 2>/dev/null)" "$(case $f in main.c|point.h|util.c) echo 1 ;; point.c) echo 1 ;; esac)"
done
q r1 '%opt{lsp_edit_armed} %opt{lsp_edit_opened} %opt{lsp_edit_touched}'
echo "== undo in each touched buffer"
for f in main.c point.c point.h util.c; do send r1 "try %{ evaluate-commands -buffer $P/$f %{ execute-keys u } }"; done
expect "after undo: buffers" "$(bufs)" "main.c: false point.c: false point.h: false util.c: false "
for f in main.c point.c point.h util.c; do
	rm -f "$R/o/m"; send r1 "try %{ evaluate-commands -buffer $P/$f %{ evaluate-commands -draft %{ execute-keys '%'; echo -to-file $R/o/m %val{selection} } } }"
	expect "$f same as disk after undo" "$(cat "$R/o/m")" "$(cat "$P/$f")"
done
echo "== redo the rename, then :wa and make"
for f in main.c point.c point.h util.c; do send r1 "try %{ evaluate-commands -buffer $P/$f %{ execute-keys U } }"; done
expect "after redo: disk" "$(st)" ""
send r1 "write-all"
expect "after :wa: disk" "$(st)" " M main.c  M point.c  M point.h  M util.c "
expect "after :wa: buffers" "$(bufs)" "main.c: false point.c: false point.h: false util.c: false "
expect "builds" "$(cd "$P" && make -s 2>&1 && ./points; make -s clean)" "c = (5, 8)
dist2 = 25
twice = 10"
expect "debug" "$(dbge r1 | grep -v 'LSP: INFO')" ""
