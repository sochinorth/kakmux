# jump-labels: <ret> labels the words on screen (two letters), picking one
# selects it, <s-ret> extends; *grep* and lsp lists keep <ret> for the line
# golden
# covers: rc/pickers.kak
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp rg
P=$R/p/proj; mkproj "$P"
CWD=$P WAIT=2 start kakmux jl main.c
waitdiags jl 0; sleep 1
S() { q jl '%val{selection}' '%val{selection_desc}'; }
send jl "execute-keys 7g"
keys jl Enter; cap jl | head -12
keys jl a; cap jl | sed -n 6,10p
keys jl b; S; cap jl | sed -n 6,8p
expect "picked ab: void" "$(qv jl '%val{selection} %val{selection_desc}')" "void 6.10,6.13"
keys jl Enter; keys jl Escape; cap jl | sed -n 6,8p; S
echo "== extend"
send jl "execute-keys 8gl"
keys jl S-Enter; cap jl | sed -n 8,9p; keys jl a a; S
expect "extended to aa" "$(qv jl '%val{selection_desc}')" "8.2,14.7"
keys jl Escape
echo "== grep buffer keeps <ret>"
send jl "grep point_sum"; sleep 1; send jl "execute-keys gg"; q jl '%val{bufname}' '%opt{filetype}'
keys jl Enter; sleep 0.5
expect "<ret> in *grep* jumps" "$(qv jl '%val{bufname} %val{cursor_line}')" "main.c 10"
dbge jl
stop jl
echo "== lsp lists keep <ret> (no tmux)"
CWD=$P WAIT=2 start notmux jl2 main.c
waitdiags jl2 0; sleep 3
send jl2 "execute-keys gg/point_dist2<ret>"; sleep 1
send jl2 "lsp-references"; sleep 2
q jl2 '%val{bufname}' '%opt{filetype}'
keys jl2 j; keys jl2 Enter; sleep 0.5
expect "<ret> in *goto* jumps" "$(qv jl2 '%val{bufname} %val{cursor_line}')" "point.c 4"
send jl2 "buffer main.c"; keys jl2 Enter; keys jl2 Escape; q jl2 '%opt{jump_labels}'
keys jl2 Enter; keys jl2 '?'; q jl2 '%opt{jump_labels}' '%val{selection_desc}'
dbge jl2
