# picker-resume: <space>' reopens the last picker as it was left (query,
# position), for files, grep, references and buffers; nothing left behind
# golden
# covers: rc/pickers.kak rc/workspace.kak bin/kak-picker
. "$(dirname "$0")/../lib/h.sh"
need fzf fd rg clangd kak-lsp
P=$R/p/proj; mkproj "$P"
CWD=$P WAIT=2 start kakmux res main.c
waitdiags res 0; sleep 1; popwin res
B() { qv res '%val{bufname} %val{cursor_line}'; }
WAIT2=1.2
echo "== files: query 'po', down 1, esc; resume"
keys res Space f; pkeys res po; pkeys res Down; pcap res | sed -n 2,6p | cut -c1-64; pkeys res Escape
keys res Space "'"; pcap res | sed -n 1,6p | cut -c1-64; pkeys res Enter
expect "resumed files pick" "$(B)" "point.h 1"
echo "== grep"
# (a query with one match: rg's order varies)
keys res Space /; pkeys res 'define POINT_'; pkeys res Enter
expect "grep pick" "$(B)" "point.h 2"
keys res Space "'"; pcap res | sed -n 1,7p | cut -c1-72; pkeys res Escape
echo "== references: list reused"
send res "buffer main.c"; send res "execute-keys gg/point_dist2<ret>"; sleep 2
keys res g r; sleep 2; pkeys res Down; pkeys res Enter
# (clangd's order: any reference)
expect_match "references pick" "$(B)" "*.[ch] [0-9]*"
send res "evaluate-commands -buffer point.h %{ execute-keys 'ggO// moved<esc>' }"
keys res Space "'"; sleep 0.5; pcap res | sed -n 1,3p | cut -c1-72; pcap res | sed -n 4,7p | cut -c1-72 | sort; pkeys res Escape
echo "== buffers"
keys res Space b; pkeys res Down; pkeys res Escape; keys res Space "'"; pcap res | sed -n 3,7p | cut -c1-64; pkeys res Escape
ls -d "$R"/tmp/kak-picker*; ls "$R"/tmp/kak-picker-last.*
dbge res | tail -5
stop res
expect "nothing left after the session" "$(ls -d "$R"/tmp/kak-picker* 2>/dev/null)" ""
