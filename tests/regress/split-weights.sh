# split-weights: :vsplit 30 gives the pair 30/70; split-only resets the weights
# golden
# covers: rc/splits.kak bin/kakmux-even kakmux.conf
. "$(dirname "$0")/../lib/h.sh"
mktproj "$R/p/proj"
CWD=$R/p/proj start kakmux b t.c
send b 'vsplit 30'; panes b 2
widths() { tm b list-panes -t main -F '#{pane_width}' | tr '\n' ' '; }
waitout 10 '48 111 ' widths
tm b show-options -w -t main | grep weights
expect "pane widths 30/70" "$(tm b list-panes -t main -F '#{pane_width}' | tr '\n' ' ')" "48 111 "
CL=client0 send b 'split-only'
npanes() { tm b list-panes -t main -F x | grep -c .; }
waitout 10 1 npanes
waitout 10 client0 qv b '%val{client_list}'
tm b list-panes -t main -F '#{pane_id} [#{@kak_session}] #{@kak_client}' | sed "s/\[$PFX-b\]/[self]/"
echo weights:; tm b show-options -w -t main | grep weights
q b '%val{client_list}'
