# bufferline: kakmux's tmux status line lists the buffers, the active one and
# [+] marked, per pane; unfocused splits and terminals dim their status line
# golden
# covers: rc/bufferline.kak rc/editor.kak rc/splits.kak kakmux.conf scripts/kakmux colors/*
. "$(dirname "$0")/../lib/h.sh"
D=$R/p/m; mkdir -p "$D"; seq 1 40 > "$D/x.txt"; seq 1 40 > "$D/y.txt"; echo z > "$D/z.txt"
CWD=$D start kakmux v x.txt y.txt
attachf v
bl() { tm v show-options -p -t "main.$1" @kak_bufferline | sed 's/#\[[^]]*\]//g'; }
keys v j
echo "== bufferline, 2 buffers, on x"
bl 0
expect "status line on" "$(tm v show-options -t main status)" "status on"
send v 'edit z.txt'
keys v j
echo "== after edit z.txt"
bl 0
send v 'execute-keys ia<esc>'
keys v j
echo "== z modified"
expect "z modified" "$(bl 0)" '@kak_bufferline " x.txt  y.txt  z.txt[+] "'
echo "== split: client1 in the new pane; switch client0 between buffers and back"
send v 'vsplit'; panes v 2
CL=client1 send v 'buffer y.txt'
tm v select-pane -t main.1; keys v j
bl 1
tm v select-pane -t main.0; keys v -t main.0 j
send v 'buffer x.txt'; keys v -t main.0 j
send v 'buffer z.txt'; keys v -t main.0 j
echo "pane0 (should be z active):"
tm v show-options -p -t main.0 @kak_bufferline | sed "s/fg=#2c323c,bg=#61afef[^]]*/ACTIVE/g; s/fg=#5c6370,bg=#2c323c/in/g"
q v 'sent: %opt{bufferline_sent}'
echo "== status line dimming"
CL=client1 q v 'c1 dimmed %opt{statusline_dimmed} unfocused: %opt{unfocused_clients}'
q v 'c0 dimmed %opt{statusline_dimmed}'
term v '\033[O'
expectw "terminal focus out: c0 dimmed" "true client1 client0" qv v '%opt{statusline_dimmed} %opt{unfocused_clients}'
term v '\033[I'
expectw "focus in: c0 not dimmed" "false client1" qv v '%opt{statusline_dimmed} %opt{unfocused_clients}'
dbge v
send v 'buffer x.txt; execute-keys u'
