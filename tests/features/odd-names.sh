# odd-names: git gutter and the changed-files picker with awkward file names
# (spaces, UTF-8, %, #{}, quotes, apostrophes) and CRLF
# golden
. "$(dirname "$0")/../lib/h.sh"
need fzf
P=$R/p/weird; mkweird "$P"
CWD=$P WAIT=2 start kakmux on f.txt
popwin on
for f in 'sp ace.txt' 'é.txt' crlf.txt; do
	kq=$(printf %s "$f" | sed "s/'/''/g")
	send on "edit -- '$kq'"; sleep 1
	printf '%s: ' "$f"; q on '%opt{git_gutter_flags}' | sed "s/^'[0-9]*' //"
done
send on "edit -- 'it''s.txt'"; sleep 1
expect "untracked: no flags" "$(qv on '%opt{git_gutter_flags}' | cut -d' ' -f2-)" "0| "
WAIT2=1.5
keys on Space g; pcap on | sed -n '4,10p' | cut -c1-40 | sort
pkeys on 'new "q"' Enter; sleep 0.5
expect "picked from the changed files" "$(qv on '%val{bufname}')" 'new "q".txt'
expect "debug" "$(dbge on)" ""
