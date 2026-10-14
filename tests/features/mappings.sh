# mappings: the whole keymap (debug mappings), so any change to it shows
# golden
# covers: kakrc rc/*.kak
. "$(dirname "$0")/../lib/h.sh"
mktproj "$R/p/proj"
CWD=$R/p/proj WAIT=2 start tmux dm t.c
send dm 'debug mappings'
dbg dm | sed -n '/^Mappings:$/,$p' | grep -v '^ *$'
