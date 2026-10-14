# pickers: <space>f (workspace root) / <space>F (cwd), <space>/ grep,
# <space>g changed files, gr locations; picking opens the file
# golden
# covers: rc/pickers.kak rc/workspace.kak bin/kak-picker
. "$(dirname "$0")/../lib/h.sh"
need fzf fd rg bat clangd kak-lsp
P=$R/p/proj; mkproj "$P"
mkdir -p "$P/sub/deep"; echo x > "$P/sub/deep/a.txt"; echo 'point_dist2 here' > "$P/sub/s.txt"
CWD=$P/sub start kakmux pk ../main.c
popwin pk
keys pk Space f; popen pk; pcap pk | head -6 | cut -c1-64; ptype pk 'point.c'; pclose pk Enter
expectw "file picked" "$P/point.c" qv pk '%val{bufname}'
keys pk Space F; popen pk; pcap pk | head -4 | cut -c1-64; pclose pk Escape
keys pk Space /; popen pk; ptype pk 'point_dist2'; pcap pk | head -3 | cut -c1-72; pcap pk | sed -n '4,8p' | cut -c1-72 | sort; pclose pk Escape
send pk 'execute-keys ggO<esc>'; send pk 'write'
keys pk Space g; popen pk; pcap pk | head -4 | cut -c1-64; pclose pk Escape
send pk "buffer ../main.c"; send pk "execute-keys gg/point_dist2<ret>"
# (clangd may still be starting: its answer opens the picker)
keys pk g r; fzfready '' 30; popen pk; pcap pk | head -3 | cut -c1-72; pcap pk | sed -n '4,7p' | cut -c1-72 | sort; pclose pk Escape
dbge pk | tail -5
