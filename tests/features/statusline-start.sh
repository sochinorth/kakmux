# statusline-start: the status line from the first frames on (git part, name),
# and its faces once diagnostics come
# golden
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
P=$R/p/proj; mkproj "$P"
CWD=$P WAIT=0 start kakmux sl main.c
for i in 1 2 3 4 5 6 7 8; do sleep 0.5; cap sl | grep -v '^ *$' | tail -1; done | uniq
send sl "execute-keys 'gg/twice = <ret>;ic<esc>'"; sleep 1
send sl "execute-keys 'gg/return 0<ret>xcreturn zz;<esc>gg'"; waitdiags sl 2; sleep 2
cap sl | grep -v "^ *$" | tail -1
tm sl capture-pane -e -p -t main | grep -v "^ *$" | tail -1 | cat -v | sed 's/^ *//'
