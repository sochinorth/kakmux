# picker-resume: <space>' reopens the last picker as it was left (query,
# position), for files, grep, references and buffers; nothing left behind
# golden
# covers: rc/pickers.kak rc/workspace.kak bin/kak-picker
. "$(dirname "$0")/../lib/h.sh"
need fzf fd rg clangd kak-lsp
P=$R/p/proj; mkproj "$P"
CWD=$P start kakmux res main.c
popwin res
B() { qv res '%val{bufname} %val{cursor_line}'; }
echo "== files: query 'po', down 1, esc; resume"
keys res Space f; popen res; ptype res po; pkeys res Down; fzfready po; pcap res | sed -n 2,6p | cut -c1-64; pclose res Escape
keys res Space "'"; popen res po; pcap res | sed -n 1,6p | cut -c1-64; pclose res Enter
expectw "resumed files pick" "point.h 1" B
echo "== grep"
# (a query with one match: rg's order varies)
keys res Space /; popen res; ptype res 'define POINT_'; pclose res Enter
expectw "grep pick" "point.h 2" B
keys res Space "'"; popen res 'define POINT_'; pcap res | sed -n 1,7p | cut -c1-72; pclose res Escape
echo "== references: list reused"
send res "buffer main.c"; send res "execute-keys gg/point_dist2<ret>"
# (clangd may still be starting: its answer opens the picker)
keys res g r; fzfready '' 30; popen res; pkeys res Down; fzfready ''; pclose res Enter
# (clangd's order: any reference)
expect_match "references pick" "$(B)" "*.[ch] [0-9]*"
send res "evaluate-commands -buffer point.h %{ execute-keys 'ggO// moved<esc>' }"
keys res Space "'"; popen res; pcap res | sed -n 1,3p | cut -c1-72; pcap res | sed -n 4,7p | cut -c1-72 | sort; pclose res Escape
echo "== buffers"
keys res Space b; popen res; pkeys res Down; fzfready ''; pclose res Escape; keys res Space "'"; popen res; pcap res | sed -n 3,7p | cut -c1-64; pclose res Escape
ls -d "$R"/tmp/kak-picker*; ls "$R"/tmp/kak-picker-last.*
dbge res | tail -5
stop res
expect "nothing left after the session" "$(ls -d "$R"/tmp/kak-picker* 2>/dev/null)" ""
