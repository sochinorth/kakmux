# surround-comma: md, mr and ms with a comma pair
# golden
# covers: rc/keys.kak
. "$(dirname "$0")/../lib/h.sh"
CWD=$R start kakmux k
buf() { rm -f "$R/o/b"; send k "evaluate-commands -draft %{ execute-keys '%'; echo -to-file $R/o/b %val{selection} }"; printf '%s  ' "$(cat "$R/o/b")"; q k '%val{selections_desc}'; }
setbuf() { send k "edit -scratch *s*; execute-keys '%c$1<esc>'; select $2"; }
echo "== raw object probes on 'x ,ab, y' cursor on a"
setbuf 'x ,ab, y' 1.5,1.5
send k 'try %{ execute-keys "<a-a>c\,,\,<ret>" } catch %{ echo -debug "probe1 ERR %val{error}" }'
q k 'probe \, : %val{selections_desc}'
echo "== md, (delete ,…, around a)"
setbuf 'x ,ab, y' 1.5,1.5
keys k m d ,
expect "md," "$(buf)" "x ab y  '1.5,1.5' '1.3,1.3'"
echo "== mr,( "
setbuf 'x ,ab, y' 1.5,1.5
keys k m r , \(
expect "mr,(" "$(buf)" "x (ab) y  '1.6,1.6' '1.3,1.3'"
echo "== ms, on ab"
setbuf 'x ab y' 1.3,1.4
keys k m s ,
expect "ms," "$(buf)" "x ,ab, y  '1.3,1.6'"
dbge k
