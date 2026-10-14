# palette-args: entries that need arguments open a prompt; ' searches names
# exactly; user mappings show (and still do after config-reload)
# golden
# covers: rc/*.kak bin/kak-picker
. "$(dirname "$0")/../lib/h.sh"
# (the entry count changes with every command added, here or in a plugin;
# column widths follow the widest entry on screen, and fzf truncates long
# docs at different points with them: blank runs squeezed, lines cut at 80)
_pcap() { tm "$1" capture-pane -p -t main:picker 2>/dev/null | sed -E 's#[0-9]+/[0-9]+ │#N/N │#; s/ {2,}/  /g; s/^(.{80}).+/\1…/'; }
pcap() { settle _pcap "$1"; }
LASTL() { cap pal | grep -v '^ *$' | tail -1; }
need fzf
P=$R/p/proj; mkproj "$P"
CWD=$P start kakmux pal main.c
popwin pal
keys pal Space ?; popen pal; ptype pal "'colorscheme"; pcap pal | sed -n 4,4p; pclose pal Enter
expectw_match "colorscheme prompts" ":colorscheme *" LASTL
keys pal Escape
keys pal Space ?; popen pal; ptype pal "'lsp-rename "; pcap pal | sed -n 4,4p; pclose pal Enter; waitcap pal '^New name: '; LASTL | cut -c1-40; keys pal Escape
keys pal Space ?; popen pal; ptype pal "tree-sitter parent"; pcap pal | sed -n 4,4p; pclose pal Escape
keys pal Space ?; popen pal; ptype pal "ms"; pcap pal | sed -n 4,5p; pclose pal Escape
send pal "map global user Z ':echo zz<ret>' -docstring 'zz test'"
keys pal Space ?; popen pal; ptype pal "zz test"; pcap pal | sed -n 4,4p; pclose pal Escape
send pal "config-reload"; popwin pal
keys pal Space ?; popen pal; ptype pal "zz test"; pcap pal | sed -n 2,4p; pclose pal Escape
