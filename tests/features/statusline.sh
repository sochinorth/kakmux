# statusline: Helix's status line: git branch and counts, workspace-relative
# name, [+], diagnostics, mode names (INS USER GOTO), selection count; it
# shrinks with the window; detached HEAD shows the hash
# golden
# covers: rc/editor.kak rc/workspace.kak
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
P=$R/p/proj; mkproj "$P"
mkdir -p "$P/src"; echo 'x' > "$P/src/new.txt"; echo '// c' >> "$P/util.c"; (cd "$P" && git add util.c && echo '// d' >> point.h)
CWD=$P start "${MODE:-kakmux}" sl main.c
send sl "execute-keys gg"
st() { cap sl | grep -v "^ *$" | tail -1; }
expectw_match "git counts, name" "*⎇ trunk +1 ~1 ?1 │ main.c │ 1:1" st
send sl 'edit src/new.txt'
expectw_match "workspace-relative name" "*⎇ trunk +1 ~1 ?1 │ src/new.txt │ 1:1" st
send sl 'buffer main.c'
send sl "execute-keys 'gg/return 0<ret>cundefined_x<esc>'"; waitdiags sl 1
expectw_match "modified, an error" "*⎇ trunk +1 ~1 ?1 │ main.c \[+\] │ ● 1 │ 14:13" st
q sl '%opt{lsp_diag_errors}' '%opt{lsp_diagnostic_error_count}' '%opt{lsp_diag_sep}'
keys sl i; expectw_match "INS" "*INS  ⎇ trunk*" st; keys sl Escape
keys sl Space; expectw_match "USER" "*USER  ⎇ trunk*" st; keys sl Escape
keys sl g; expectw_match "GOTO" "*GOTO  ⎇ trunk*" st; keys sl Escape
keys sl '%' s int Enter; st; keys sl ,
tm sl resize-window -t main -x 80; idle sl; st
tm sl resize-window -t main -x 200; idle sl; st
(cd "$P" && git checkout -q --detach HEAD); send sl 'write'
waitcap sl '⎇ [0-9a-f]{7,} \+1 ~2 \?1 │'; st
q sl '%opt{git_branch}' '%opt{workspace_bufname}' '%opt{git_sep}'
dbge sl | tail -5
