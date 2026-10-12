# split-weights: :vsplit 30 gives the pair 30/70; split-only resets the weights
# golden
. "$(dirname "$0")/../lib/h.sh"
mktproj "$R/p/proj"
CWD=$R/p/proj WAIT=2 start kakmux b t.c
send b 'vsplit 30'
sleep 1
tm b show-options -w -t main | grep weights
expect "pane widths 30/70" "$(tm b list-panes -t main -F '#{pane_width}' | tr '\n' ' ')" "48 111 "
CL=client0 send b 'split-only'
sleep 1
tm b list-panes -t main -F '#{pane_id} [#{@kak_session}] #{@kak_client}' | sed "s/\[$PFX-b\]/[self]/"
echo weights:; tm b show-options -w -t main | grep weights
q b '%val{client_list}'
