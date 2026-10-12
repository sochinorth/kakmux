# dash-names: files named -dash.txt through :vsplit, the pickers' actions and
# a split's init; changed-file-picker outside a repo; :kakmux when tmux fails
# golden
. "$(dirname "$0")/../lib/h.sh"
D=$R/p/dash; mkdir -p "$D"; echo dash > "$D/-dash.txt"; echo other > "$D/o.txt"
CWD=$D WAIT=2 start kakmux l o.txt
echo "== vsplit -dash.txt"
send l 'vsplit -dash.txt'
sleep 1
expect "split on -dash.txt" "$(CL=client1 qv l '%val{client} %val{bufname}')" "client1 -dash.txt"
echo "== picker files action / buffers action commands"
kq() { printf "'%s'" "$(printf %s "$1" | sed "s/'/''/g")"; }
cmd="edit -- $(kq -dash.txt)"; send l "$cmd"; q l "$cmd -> %val{bufname}"
send l 'buffer o.txt'
cmd="buffer -- $(kq -dash.txt)"; send l "$cmd"; q l "$cmd -> %val{bufname}"
echo "== :vsplit from a buffer named -dash.txt (init: buffer -- ...)"
send l 'vsplit'
sleep 1
expect "split of -dash.txt" "$(CL=client2 qv l '%val{client} %val{bufname}')" "client2 -dash.txt"
echo "== changed-file-picker outside a repo"
send l 'try %{ changed-file-picker } catch %{ echo -debug "ERR: %val{error}" }'
expect "no picker dir left" "$(ls -d "$R"/tmp/kak-picker.* 2>/dev/null)" ""
dbge l
stop l
echo "== :kakmux with tmux failing: handoff removed"
CWD=$D KAKPRE="env KAKMUX_HANDOFF=$R/o/handoff PATH=$KM_LIB/fakebin:$PATH" WAIT=2 start notmux m o.txt
send m 'try %{ kakmux } catch %{ echo -debug "ERR: %val{error}" }'
expect "handoff file removed" "$(ls "$R/o/handoff" 2>/dev/null)" ""
dbge m | grep ERR
