# palette-args: entries that need arguments open a prompt; ' searches names
# exactly; user mappings show (and still do after config-reload)
# golden
. "$(dirname "$0")/../lib/h.sh"
# (the entry count changes with every command added, here or in a plugin;
# column widths follow the widest entry on screen, and fzf truncates long
# docs at different points with them: blank runs squeezed, lines cut at 80)
pcap() { tm "$1" capture-pane -p -t main:picker 2>/dev/null | sed -E 's#[0-9]+/[0-9]+ │#N/N │#; s/ {2,}/  /g; s/^(.{80}).+/\1…/'; }
need fzf
P=$R/p/proj; mkproj "$P"
CWD=$P WAIT=2 start kakmux pal main.c
sleep 2; popwin pal
WAIT2=1.2
keys pal Space ?; pkeys pal "'colorscheme"; pcap pal | sed -n 4,4p; pkeys pal Enter; sleep 0.5
expect_match "colorscheme prompts" "$(cap pal | grep -v '^ *$' | tail -1)" ":colorscheme *"
keys pal Escape
keys pal Space ?; pkeys pal "'lsp-rename "; pcap pal | sed -n 4,4p; pkeys pal Enter; sleep 0.5; cap pal | grep -v '^ *$'| tail -1 | cut -c1-40; keys pal Escape
keys pal Space ?; pkeys pal "tree-sitter parent"; pcap pal | sed -n 4,4p; pkeys pal Escape
keys pal Space ?; pkeys pal "ms"; pcap pal | sed -n 4,5p; pkeys pal Escape
send pal "map global user Z ':echo zz<ret>' -docstring 'zz test'"
keys pal Space ?; pkeys pal "zz test"; pcap pal | sed -n 4,4p; pkeys pal Escape
send pal "config-reload"; popwin pal
keys pal Space ?; pkeys pal "zz test"; pcap pal | sed -n 2,4p; pkeys pal Escape
