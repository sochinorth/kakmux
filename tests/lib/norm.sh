#!/bin/sh
# norm.sh RUNDIR ID: stdin to stdout, with what changes from run to run
# replaced: the run dir, the checkout, $HOME, the session prefix, PIDs, temp
# name suffixes, clock times, git hashes; trailing blanks dropped, long runs of
# blanks (right-aligned status lines) shown as <pad>.
R=${1:?} ID=${2:?}
SRC=${KM_SRC:-$(cd "$(dirname "$0")/../.." && pwd)}
case $R in "$HOME"/*) RT="~${R#"$HOME"}" ;; *) RT=$R ;; esac
case $SRC in "$HOME"/*) ST="~${SRC#"$HOME"}" ;; *) ST=$SRC ;; esac
esc() { printf %s "$1" | sed 's/[][\.*^$|]/\\&/g'; }
sed -e "s|$(esc "$R")|@RUN|g" -e "s|$(esc "$RT")|@RUN|g" \
	-e "s|$(esc "$SRC")|@SRC|g" -e "s|$(esc "$ST")|@SRC|g" \
	-e "s|$(esc "$HOME")|~|g" -e "s|$(esc "$ID")|@P|g" |
sed -E \
	-e 's/PID=[0-9]+/PID=@/g; s/\(pid [0-9]+\)/(pid @)/g' \
	-e 's/kak-git-gutter\.[0-9]+\.[A-Za-z0-9]{6}/kak-git-gutter.@/g' \
	-e 's/kak-picker\.[A-Za-z0-9]{6}/kak-picker.@/g' \
	-e 's/\b[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?\b/@T/g' \
	-e 's/\b[0-9a-f]{7,40}\b/@H/g' \
	-e 's/[[:space:]]+$//' \
	-e 's/^ {20,}/<pad> /; s/ {20,}/ <pad> /g'
