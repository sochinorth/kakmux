# diag-two-clients: workspace symbols routed to the asking window; an edit in
# client0 redraws the inline lines in both clients
# golden
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
mktproj "$R/p/proj"
cp "$R/p/proj/t.c" "$R/p/proj/t2.c"
CWD=$R/p/proj WAIT=1 start kakmux i t2.c
waitdiags i 3; sleep 1
send i 'vsplit'
sleep 1
CL=client1 send i 'select 6.1,6.1'
send i 'select 2.1,2.1'
echo "== wsym route"
WAIT2=2 send i "set-option window picker_wsym_out $R/o/wsym; lsp-workspace-symbol main"
echo "wsym file: $(head -1 "$R/o/wsym" 2>/dev/null)"; rm -f "$R"/o/wsym*
q i 'wsym_out: %opt{picker_wsym_out} pickers: %opt{picker_clients}'
echo "== edit in client0 (line 2: zzz;), both clients get it"
send i 'execute-keys "ozzz<semicolon><esc>"'
sleep 3
q i 'c0 n: %opt{line_diags_n} st: %opt{line_diags_state} pend: %opt{line_diags_pending}'
CL=client1 q i 'c1 line %val{cursor_line} drawn %opt{line_diags_drawn} seen %opt{line_diags_seen}'
cap i | sed -n 1,10p
dbge i | grep -v 'LSP: INFO'
