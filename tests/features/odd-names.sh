# odd-names: git gutter and the changed-files picker with awkward file names
# (spaces, UTF-8, %, #{}, quotes, apostrophes) and CRLF
# golden
# covers: rc/workspace.kak rc/pickers.kak bin/kak-picker
. "$(dirname "$0")/../lib/h.sh"
need fzf
P=$R/p/weird; mkweird "$P"
CWD=$P start kakmux on f.txt
popwin on
# the gutter's run done: the buffer located, its diff's shell gone (it
# removes its .buf copy last, after sending kak the flags)
_gutter() {
	case $(qv on '%opt{git_gutter_state}') in yes|no) ;; *) return 1 ;; esac
	[ -z "$(find "$(qv on '%opt{git_gutter_dir}')" -name '*.buf' 2>/dev/null)" ]
}
for f in 'sp ace.txt' 'é.txt' crlf.txt; do
	kq=$(printf %s "$f" | sed "s/'/''/g")
	send on "edit -- '$kq'"; waitfor 10 _gutter; idle on
	printf '%s: ' "$f"; q on '%opt{git_gutter_flags}' | sed "s/^'[0-9]*' //"
done
send on "edit -- 'it''s.txt'"; waitfor 10 _gutter; idle on
expect "untracked: no flags" "$(qv on '%opt{git_gutter_flags}' | cut -d' ' -f2-)" "0| "
keys on Space g; fzfready; pcap on | sed -n '4,10p' | cut -c1-40 | sort
pkeys on 'new "q"'; fzfready 'new "q"'; pkeys on Enter; pickerdone on
expectw "picked from the changed files" 'new "q".txt' qv on '%val{bufname}'
expect "debug" "$(dbge on)" ""
