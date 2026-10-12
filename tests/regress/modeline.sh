# modeline: kakmux strips the modeline's client@[session] once (bufferline in
# tmux's status); plain kak keeps it; a customised modelinefmt is left alone
# golden
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
mktproj "$R/p/proj"
CWD=$R/p/proj WAIT=1 start kakmux o t.c
waitdiags o 3; sleep 0.5
cap o | tail -1
send o 'edit w.c'
sleep 2
cap o | tail -1
expect "strip done once (disarmed)" "$(qv o '%opt{modeline_kakmux}')" ""
expect_match "kakmux: no client@[session]" "$(cap o | tail -1)" "*w.c │ ● 1 │ 1:1"
stop o
CWD=$R/p WAIT=1 start notmux p proj/t.c
waitdiags p 3; sleep 0.5
cap p | tail -1
expect_match "plain kak: client@[session] kept" "$(cap p | tail -1)" "*client0@\[$PFX-p\]"
stop p
echo "== customised format left alone"
# (%val{client} is expanded when -E runs: empty)
CWD=$R/p/proj WAIT=2 start kakmux o2 t.c -E "'set-option global modelinefmt \"custom %val{client}@%val{session}\"'"
cap o2 | tail -1
expect_match "custom format kept" "$(cap o2 | tail -1)" "*custom @$PFX-o2"
