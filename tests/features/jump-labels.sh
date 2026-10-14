# jump-labels: <ret> labels the words on screen (two letters), picking one
# selects it, <s-ret> extends; *grep* and lsp lists keep <ret> for the line
# golden
# covers: rc/pickers.kak
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp rg
P=$R/p/proj; mkproj "$P"
CWD=$P start kakmux jl main.c
S() { q jl '%val{selection}' '%val{selection_desc}'; }
_grepped() { [ "$(qv jl '%val{bufname} %val{buf_line_count}')" = "*grep* $NG" ]; }
_hasref() {
	rm -f "$R/o/goto"
	send jl2 "evaluate-commands -draft %{ execute-keys '%'; echo -to-file $R/o/goto %val{selection} }"
	grep -q '^point\.c:4:' "$R/o/goto" 2>/dev/null
}
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
# (rg done: as many lines in *grep* as it finds)
NG=$(cd "$P" && rg -n point_sum | grep -c .)
send jl "grep point_sum"; waitfor 10 _grepped; send jl "execute-keys gg"; q jl '%val{bufname}' '%opt{filetype}'
keys jl Enter
expectw "<ret> in *grep* jumps" "main.c 10" qv jl '%val{bufname} %val{cursor_line}'
dbge jl
stop jl
echo "== lsp lists keep <ret> (no tmux)"
CWD=$P start notmux jl2 main.c
send jl2 "execute-keys gg/point_dist2<ret>"
# clangd answers before it has read point.c: ask again until the list has it
for i in 1 2 3 4 5 6 7 8 9 10; do
	send jl2 "lsp-references"; waitout 10 '*goto*' qv jl2 '%val{bufname}'
	waitfor 2 _hasref && break
	send jl2 "buffer main.c"
done
q jl2 '%val{bufname}' '%opt{filetype}'
keys jl2 j; keys jl2 Enter
expectw "<ret> in *goto* jumps" "point.c 4" qv jl2 '%val{bufname} %val{cursor_line}'
send jl2 "buffer main.c"; keys jl2 Enter; keys jl2 Escape; q jl2 '%opt{jump_labels}'
keys jl2 Enter; keys jl2 '?'; q jl2 '%opt{jump_labels}' '%val{selection_desc}'
dbge jl2
