# many-buffers: opening 60 buffers one by one: shells, kak CPU and the hooks'
# time, RSS (some 10 shells and 35 ms of hooks a buffer, most of it the
# stock rc and plugins: filetype, autorestore, kak-tree-sitter, editorconfig)
# tags: serial
# covers: kakrc rc/*.kak
. "$(dirname "$0")/../lib/h.sh"
P=$R/p/proj; mkproj "$P"; mkmany "$P"
SHW=1 CWD=$P start kakmux pg main.c
attachf pg
pid=$(kakpid pg)
quiet 10
cpu() { sed 's/.*) //' "/proc/$pid/stat" | awk '{ print $12 + $13 + $14 + $15 }'; }
send pg "set-option global debug profile; echo -debug MARK"
: > "$KM_SHLOG"; c0=$(cpu)
# one every 0.3 s or so, then what they set off (counted)
i=1; while [ $i -le 60 ]; do WAIT2=0.2 send pg "edit many/m$i.c"; i=$((i + 1)); done; sleep 3
c1=$(cpu)
send pg "set-option global debug ''"
shtop 8
dbg pg | sed -n '/^MARK$/,$p' | awk '/^hook .* took [0-9]+ us/ { match($0, /took [0-9]+ us/); tot += substr($0, RSTART + 5, RLENGTH - 8) } END { print int(tot / 1000) }' > "$R/o/hooks"
metric open60-shells "$(shells)"; metric open60-cpu-ms $(( (c1 - c0) * 10 )) ms; metric open60-hooks-ms "$(cat "$R/o/hooks")" ms
metric rss "$(awk '/VmRSS/ { print $2 }' "/proc/$pid/status")" kB
expect_le "opening 60 buffers: shells" "$(shells)" 900
expect_le "opening 60 buffers: kak cpu (ms)" $(( (c1 - c0) * 10 )) 20000
