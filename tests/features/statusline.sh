# statusline: Helix's status line: git branch and counts, workspace-relative
# name, [+], diagnostics, mode names (INS USER GOTO), selection count; it
# shrinks with the window; detached HEAD shows the hash
# golden
# covers: rc/editor.kak rc/workspace.kak
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
P=$R/p/proj; mkproj "$P"
mkdir -p "$P/src"; echo 'x' > "$P/src/new.txt"; echo '// c' >> "$P/util.c"; (cd "$P" && git add util.c && echo '// d' >> point.h)
CWD=$P WAIT=2 start "${MODE:-kakmux}" sl main.c
waitdiags sl 0; sleep 2; send sl "execute-keys gg"
st() { cap sl | grep -v "^ *$" | tail -1; }
expect_match "git counts, name" "$(st)" "*⎇ trunk +1 ~1 ?1 │ main.c │ 1:1"
send sl 'edit src/new.txt'; sleep 1
expect_match "workspace-relative name" "$(st)" "*⎇ trunk +1 ~1 ?1 │ src/new.txt │ 1:1"
send sl 'buffer main.c'
send sl "execute-keys 'gg/return 0<ret>cundefined_x<esc>'"; waitdiags sl 1; sleep 2
expect_match "modified, an error" "$(st)" "*⎇ trunk +1 ~1 ?1 │ main.c \[+\] │ ● 1 │ 14:13"
q sl '%opt{lsp_diag_errors}' '%opt{lsp_diagnostic_error_count}' '%opt{lsp_diag_sep}'
keys sl i; expect_match "INS" "$(st)" "*INS  ⎇ trunk*"; keys sl Escape
keys sl Space; expect_match "USER" "$(st)" "*USER  ⎇ trunk*"; keys sl Escape
keys sl g; expect_match "GOTO" "$(st)" "*GOTO  ⎇ trunk*"; keys sl Escape
keys sl '%' s int Enter; sleep 0.3; st; keys sl ,
tm sl resize-window -t main -x 80 ; sleep 0.5; st
tm sl resize-window -t main -x 200 ; sleep 0.5; st
(cd "$P" && git checkout -q --detach HEAD); send sl 'write'; sleep 1; st
q sl '%opt{git_branch}' '%opt{workspace_bufname}' '%opt{git_sep}'
dbge sl | tail -5
