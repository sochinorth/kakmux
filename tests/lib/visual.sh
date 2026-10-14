# tests/lib/visual.sh: the visual tests' project and frame sampling (after h.sh)
# mkvproj DIR: mkproj, main.c with a loop (scopes, guides), committed
mkvproj() {
	mkproj "$1" || return
	cat > "$1/main.c" <<'XEOF'
#include <stdio.h>
#include "point.h"

int util_twice(int v);

static int sum_rows(int n)
{
	int total = 0;
	for (int i = 0; i < n; i++) {
		if (i % 2 == 0) {
			total += i;
		} else {
			total -= i;
		}
	}
	return total;
}

int main(void)
{
	struct point a = { 1, 2 };
	struct point b = { 4, 6 };
	struct point c = point_sum(a, b);
	point_print("c", c);
	printf("dist2 = %d\n", point_dist2(a, b));
	printf("twice = %d\n", util_twice(c.x));
	printf("rows = %d\n", sum_rows(5));
	return 0;
}
XEOF
	(cd "$1" && git add -A && git commit -qm vis)
}
# settled NAME: kak has handled what it was sent, kak-lsp's inline
# diagnostics are for the buffer as it is now, or nothing has moved for 1.5 s
# (none coming: a reload isn't sent again), and the screen is still (10 s max)
settled() {
	idle "$1"; _vk=0 _vn=0 _vl=
	while [ $_vk -lt 100 ] && [ $_vn -lt 15 ]; do
		_vs=$(qv "$1" '%val{timestamp} %opt{lsp_inlay_diagnostics}')
		_vt=${_vs%% *} _vi=${_vs#* }; [ "$_vt" = "${_vi%% *}" ] && break
		_vs="$_vs $(tm "$1" capture-pane -p -t main | md5sum)"
		if [ "$_vs" = "$_vl" ]; then _vn=$((_vn + 1)); else _vn=0 _vl=$_vs; fi
		_vk=$((_vk + 1)); sleep 0.1
	done
	idle "$1"; cap "$1" > /dev/null
}
# frames NAME OUT SECS: capture-pane as fast as it goes for SECS, OUT/NNNNN.p
frames() {
	mkdir -p "$2"; s=$(sk "$1")
	end=$(( $(date +%s%N) + ${3:-3}000000000 )); i=0
	while [ "$(date +%s%N)" -lt $end ]; do
		i=$((i + 1)); TMUX= tmux -S "$s" capture-pane -p -t main > "$2/$(printf %05d $i).p"
	done
}
# burst NAME OUT LINE KEYS...: from normal mode at LINE, sample frames while
# KEYS are sent (all at once, or DELAY seconds apart)
burst() {
	n=$1 o=$2 l=$3; shift 3
	rm -rf "$o"
	send "$n" "execute-keys ${l}g"; settled "$n"
	frames "$n" "$o" "${SECS:-4}" &
	fp=$!
	sleep 0.15   # frames of the screen as it was, first
	if [ -n "${DELAY:-}" ]; then
		for k; do tm "$n" send-keys -t main "$k"; sleep "$DELAY"; done
	else
		tm "$n" send-keys -t main "$@"
	fi
	wait $fp
}
