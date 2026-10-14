# edge: edits around a line with inline diagnostic lines drawn (dd, J, joins,
# Enter, o/O, undo, paste, empty line, backspacing it away): kak stays up and
# the screen settles to the right layout
# tags: slow
# covers: rc/inline-diagnostics.kak rc/decorations.kak
# timeout: 400
# golden
. "$(dirname "$0")/../lib/h.sh"
. "$KM_LIB/visual.sh"
need clangd kak-lsp
P=$R/p/edge; mkvproj "$P"
sed -i '11a\            aaaaaaaa x;' "$P/main.c"; printf '\n' >> "$P/main.c"
CWD=$P WAIT=1 start kakmux edge main.c
attachf edge
waitdiags edge 1; sleep 3
t() { # NAME KEYS...: reload, cursor on line 12's end, keys, look once settled
	name=$1; shift
	keys edge Escape; send edge 'edit!'; sleep 2.5; send edge 'execute-keys 12ggl'; sleep 1.2
	tm edge send-keys -t main "$@"; sleep 2.75
	printf 'nop\n' | kak -p "$PFX-edge" 2>/dev/null || fail "$name: kak died"
	echo "## $name"; cap edge | sed -n 11,14p | cut -c1-70
}
t dd x d
t dd-above k x d
t dd-below j x d
t J J
t join-del A Delete
t join-bs j i BSpace
t xc x c
t ret-eol A Enter
t ret-mid h h i Enter
t o o
t O O
t undo A z z Escape u
t paste-line x y p
t ghGld g h G l d
t empty-line x c Escape
t bs-all A BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace
expect "debug" "$(dbge edge | tail -5)" ""
