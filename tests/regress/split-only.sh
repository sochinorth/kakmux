# split-only: <c-w>o / :split-only closes only this session's kak panes;
# tmux-here acts in the client's own tmux; both refuse without tmux
# golden
# covers: rc/splits.kak bin/kakmux-even kakmux.conf
. "$(dirname "$0")/../lib/h.sh"
mktproj "$R/p/proj"
CWD=$R/p/proj WAIT=2 start kakmux b t.c
send b 'vsplit'
send b 'hsplit'
sleep 1
# a plain shell pane, and a pane labelled as another session
tm b split-window -d -t main -- sh -c 'sleep 100000'
tm b split-window -d -t main -- sh -c 'sleep 100000'
P=$(tm b list-panes -t main -F '#{pane_id}' | tail -1)
tm b set-option -p -t "$P" @kak_session other
echo before; tm b list-panes -t main -F '#{pane_id} #{pane_active} [#{@kak_session}] #{@kak_client}' | sed "s/\[$PFX-b\]/[self]/"
q b '%val{client_list}'
# w from client2 (the last split, which has focus): next pane
CL=client2 send b 'tmux-here select-pane -t :.+'
echo after w from client2; tm b list-panes -t main -F '#{pane_id} #{pane_active} #{@kak_client}'
CL=client0 send b 'split-only'
sleep 1
echo after only; tm b list-panes -t main -F '#{pane_id} [#{@kak_session}] #{@kak_client} #{pane_current_command}' | sed "s/\[$PFX-b\]/[self]/"
tm b show-options -w -t main | grep weights
q b '%val{client_list}'
expect "client_list after split-only" "$(qv b '%val{client_list}')" "client0 client1"
expect "debug" "$(dbge b)" ""
stop b
WAIT=2 start notmux c "$R/p/proj/t.c"
send c 'try %{ split-only } catch %{ echo -debug "ERR: %val{error}" }; try %{ tmux-here display-message hi } catch %{ echo -debug "ERR: %val{error}" }'
dbge c
