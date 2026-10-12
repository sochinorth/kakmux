# buffer-picker: <space>b time to fzf running, 61 buffers open, 6 tries
. "$(dirname "$0")/../lib/h.sh"
need fzf
P=$R/p/proj; mkproj "$P"; mkmany "$P"
CWD=$P WAIT=1 start kakmux bpm main.c
attachf bpm
sleep 3
i=1; while [ $i -le 60 ]; do WAIT2=0.05 send bpm "edit many/m$i.c"; i=$((i + 1)); done; sleep 3
expect "buffers" "$(qv bpm '%val{buflist}' | wc -w)" 62
# fzf of this run: a child of this run's tmux server
pk() { t0=$(date +%s%N); printf ' b' > "$R/o/in-bpm"; k=0; until [ -n "$(myfzf)" ] || [ $k -gt 300 ]; do k=$((k + 1)); sleep 0.01; done; t1=$(date +%s%N); echo $(( (t1 - t0) / 1000000 )); sleep 0.7; printf '\033' > "$R/o/in-bpm"; sleep 1; }
r=; for k in 1 2 3 4 5 6; do r="$r $(pk)"; done
med=$(echo $r | tr ' ' '\n' | sort -n | sed -n 3,4p | awk '{ s += $1 } END { print int(s / 2) }')
echo "time to fzf (ms):$r"
metric buffer-picker-ms "$med" ms
expect_le "buffer picker, 62 buffers: median time to fzf (ms)" "$med" 1000
