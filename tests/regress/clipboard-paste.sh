# clipboard-paste: one clipboard line per selection when the counts match,
# else the whole text in each
. "$(dirname "$0")/../lib/h.sh"
CWD=$R WAIT=1 start kakmux w
send w "set-option global clipboard_paste 'cat $R/o/clip'"
buf() { rm -f "$R/o/b"; send w "evaluate-commands -draft %{ execute-keys '%'; echo -to-file $R/o/b %val{selection} }"; cat -A "$R/o/b" | tr '\n' ' '; }
setbuf() { send w "edit -scratch *s*; execute-keys '%c$1<esc>'; select $2"; }
printf 'line\n' > "$R/o/clip"; setbuf 'X' 1.1,1.1; send w 'clipboard-paste p'
expect "1: one selection, 'line\\\\n', p" "$(buf)" 'X$ line$ '
printf 'a\nb\nc' > "$R/o/clip"; setbuf '1 2 3' '1.1,1.1 1.3,1.3 1.5,1.5'; send w 'clipboard-paste R'
expect "2: 3 selections, 3 lines, R" "$(buf)" 'a b c$ '
printf "a\nit's\nc\n" > "$R/o/clip"; setbuf '1 2 3' '1.1,1.1 1.3,1.3 1.5,1.5'; send w 'clipboard-paste R'
expect "3: same with a final newline" "$(buf)" "a it's c\$ "
printf 'a\nb\nc' > "$R/o/clip"; setbuf '1 2' '1.1,1.1 1.3,1.3'; send w 'clipboard-paste R'
expect "4: 2 selections, 3 lines: whole text each" "$(buf)" 'a$ b$ c a$ b$ c$ '
expect "debug" "$(dbge w)" ""
