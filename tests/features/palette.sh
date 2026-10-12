# palette: <space>? lists commands with their keys and docs; filtering; running
# one (config-reload, a prompt for lsp-rename, clipboard yank); user mode
# entries; tree-sitter entries
# golden
. "$(dirname "$0")/../lib/h.sh"
# (the entry count changes with every command added, here or in a plugin)
pcap() { tm "$1" capture-pane -p -t main:picker 2>/dev/null | sed -E 's#[0-9]+/[0-9]+ │#N/N │#'; }
need fzf clangd kak-lsp
P=$R/p/proj; mkproj "$P"
CWD=$P WAIT=2 start kakmux pal main.c
waitdiags pal 0; sleep 1; popwin pal
WAIT2=${PAL_WAIT:-1.2}
keys pal Space ?; pcap pal | head -14; pcap pal | tail -2
pkeys pal 'vsplit'; pcap pal | sed -n 2,6p
pkeys pal Escape
keys pal Space ?; pkeys pal 'config-reload'; pkeys pal Enter; sleep 1
expect_match "config-reload ran" "$(cap pal | grep -v '^ *$' | tail -1)" "config reloaded*"
popwin pal
keys pal Space ?; pkeys pal 'lsp-rename '; pcap pal | sed -n 3,5p; pkeys pal Enter; sleep 0.5
expect_match "lsp-rename-prompt prompts" "$(cap pal | grep -v '^ *$' | tail -1)" "New name: *"
keys pal Escape
keys pal Space ?; pkeys pal 'yank main'; pcap pal | sed -n 3,5p; pkeys pal Enter; sleep 0.5
expect_match "clipboard-yank -main ran" "$(cap pal | grep -v '^ *$' | tail -1)" "yanked 1 selection(s) to the clipboard*"
keys pal Space ?; pkeys pal 'surround add'; pcap pal | sed -n 3,5p; pkeys pal Escape
keys pal Space ?; pkeys pal 'focus left'; pcap pal | sed -n 3,5p; pkeys pal Escape
keys pal Space ?; pkeys pal 'tree-sitter-nav'; pcap pal | sed -n 3,6p; pkeys pal Escape
sleep 0.5; dbge pal | grep -v '^Mappings:' | tail -5
