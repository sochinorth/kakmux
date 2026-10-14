# palette: <space>? lists commands with their keys and docs; filtering; running
# one (config-reload, a prompt for lsp-rename, clipboard yank); user mode
# entries; tree-sitter entries
# golden
# covers: rc/*.kak bin/kak-picker
. "$(dirname "$0")/../lib/h.sh"
# (the entry count changes with every command added, here or in a plugin;
# column widths follow the widest entry on screen, and fzf truncates long
# docs at different points with them: blank runs squeezed, lines cut at 80)
_pcap() { tm "$1" capture-pane -p -t main:picker 2>/dev/null | sed -E 's#[0-9]+/[0-9]+ │#N/N │#; s/ {2,}/  /g; s/^(.{80}).+/\1…/'; }
pcap() { settle _pcap "$1"; }
LASTL() { cap pal | grep -v '^ *$' | tail -1; }
need fzf clangd kak-lsp
P=$R/p/proj; mkproj "$P"
CWD=$P start kakmux pal main.c
popwin pal
# palette-slow: that long between keys, typed or not
[ -n "${PAL_WAIT:-}" ] && WAIT2=$PAL_WAIT
keys pal Space ?; popen pal; pcap pal | head -14; pcap pal | tail -2
ptype pal 'vsplit'; pcap pal | sed -n 2,6p;
pclose pal Escape
keys pal Space ?; popen pal; ptype pal 'config-reload'; pclose pal Enter
expectw_match "config-reload ran" "config reloaded*" LASTL
popwin pal
keys pal Space ?; popen pal; ptype pal 'lsp-rename '; pcap pal | sed -n 3,5p; pclose pal Enter
expectw_match "lsp-rename-prompt prompts" "New name: *" LASTL
keys pal Escape
keys pal Space ?; popen pal; ptype pal 'yank main'; pcap pal | sed -n 3,5p; pclose pal Enter
expectw_match "clipboard-yank -main ran" "yanked 1 selection(s) to the clipboard*" LASTL
keys pal Space ?; popen pal; ptype pal 'surround add'; pcap pal | sed -n 3,5p; pclose pal Escape
keys pal Space ?; popen pal; ptype pal 'focus left'; pcap pal | sed -n 3,5p; pclose pal Escape
keys pal Space ?; popen pal; ptype pal 'tree-sitter-nav'; pcap pal | sed -n 3,6p; pclose pal Escape
dbge pal | grep -v '^Mappings:' | tail -5
