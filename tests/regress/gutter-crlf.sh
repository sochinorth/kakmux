# gutter-crlf: git gutter on a CRLF working tree (autocrlf), deletions at EOF,
# diff.external never called, stale results dropped; temp dir removed at the end
# golden
# covers: rc/workspace.kak
. "$(dirname "$0")/../lib/h.sh"
G=$R/p/grepo; mkdir -p "$G"; cd "$G" || exit 1
git init -q .
git config core.autocrlf true
printf 'one\ntwo\nthree\nfour\nfive\n' > a.txt
printf '#!/bin/sh\necho EXTDIFF >> %s/o/extdiff\n' "$R" > "$R/extdiff.sh"; chmod +x "$R/extdiff.sh"
git config diff.external "$R/extdiff.sh"
git add a.txt 2>/dev/null; git commit -qm init
# working tree with CRLF (as autocrlf checkouts on Windows do)
printf 'one\r\ntwo\r\nthree\r\nfour\r\nfive\r\n' > a.txt
git status --short 2>/dev/null
CWD=$G WAIT=2 start kakmux j a.txt
q j 'eol: %opt{eolformat} flags: %opt{git_gutter_flags}'
expect "diff.external not called" "$(cat "$R/o/extdiff" 2>/dev/null)" ""
echo "temp files left: $(ls "$R"/tmp/kak-git-gutter.*/ 2>/dev/null)"
echo "== delete the last two lines"
send j 'execute-keys 4gxJxd'
sleep 1.5
q j 'lines: %val{buf_line_count} flags: %opt{git_gutter_flags}'
cap j | head -5
echo "== stale result dropped, current accepted"
q j 'ts: %val{timestamp} seen: %opt{git_gutter_seen}'
send j 'git-gutter-set 1 1|{GitGutterAdd}X'
q j 'after old: %opt{git_gutter_flags} seen: %opt{git_gutter_seen}'
send j 'git-gutter-set %opt{git_gutter_seen} 2|{GitGutterAdd}Y'
q j 'after current: %opt{git_gutter_flags}'
dbge j
D=$(ls -d "$R"/tmp/kak-git-gutter.* 2>/dev/null)
expect "gutter dir while running" "$(echo "$D" | wc -w)" 1
# the dir goes at KakEnd (the buffer is modified: kill!)
printf 'kill!\n' | kak -p "$PFX-j"
waitfor 5 sh -c '! pgrep -f "^kak -s $PFX-j " >/dev/null' || fail "kak still running"
expect "gutter dir after the session ends" "$(ls -d "$R"/tmp/kak-git-gutter.* 2>/dev/null)" ""
