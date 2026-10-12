# gutter-diag-narrow: a 70-column window: git flag, scope guides and inline
# diagnostic lines (wrapped, hanging under their column) laid out together
# golden
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
W=$R/p/wrepo; mktproj "$W"
(cd "$W" && git init -q . && git add . && git commit -qm init)
sed -i '1s/^/\/\/ changed\n/' "$W/t.c"
CWD=$W XW=70 XH=30 WAIT=1 start tmux x t.c
waitdiags x 3; sleep 1
send x 'select 7.1,7.1'
keys x j; keys x k; sleep 1
cap x | sed -n '1,14p' | sed 's/$/|/'
expect "flags" "$(qv x '%opt{git_gutter_flags}')" "1 0|  1|{GitGutterAdd}▍"
q x '%opt{line_diags_view}' | cut -c1-600
