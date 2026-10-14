# pickers: <space>f (workspace root) / <space>F (cwd), <space>/ grep,
# <space>g changed files, gr locations; picking opens the file
# golden
# covers: rc/pickers.kak rc/workspace.kak bin/kak-picker
. "$(dirname "$0")/../lib/h.sh"
need fzf fd rg bat clangd kak-lsp
P=$R/p/proj; mkproj "$P"
mkdir -p "$P/sub/deep"; echo x > "$P/sub/deep/a.txt"; echo 'point_dist2 here' > "$P/sub/s.txt"
CWD=$P/sub WAIT=2 start kakmux pk ../main.c
waitdiags pk 0; sleep 1; popwin pk
WAIT2=1.2
keys pk Space f; pcap pk | head -6 | cut -c1-64; pkeys pk 'point.c' Enter
expect "file picked" "$(qv pk '%val{bufname}')" "$P/point.c"
keys pk Space F; pcap pk | head -4 | cut -c1-64; pkeys pk Escape
keys pk Space /; pkeys pk 'point_dist2'; sleep 0.5; pcap pk | head -3 | cut -c1-72; pcap pk | sed -n '4,8p' | cut -c1-72 | sort; pkeys pk Escape
send pk 'execute-keys ggO<esc>'; send pk 'write'; sleep 1
keys pk Space g; pcap pk | head -4 | cut -c1-64; pkeys pk Escape
send pk "buffer ../main.c"; send pk "execute-keys gg/point_dist2<ret>"; sleep 2
keys pk g r; sleep 2; pcap pk | head -3 | cut -c1-72; pcap pk | sed -n '4,7p' | cut -c1-72 | sort; pkeys pk Escape
sleep 0.5; dbge pk | tail -5
