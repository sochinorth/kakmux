# kakmux.zsh: the shell side of kakmux and kakbr. Source it from ~/.zshrc.
# Expects the deployed layout: ~/.local/bin/{kakmux,kakbr-sidebar,broot-open},
# ~/.config/kakbr/kakbr.conf, ~/.local/lib/broot-opener (see README.md).

# broot sends double-clicks to the system opener; give it one that opens kak
broot() { PATH=~/.local/lib/broot-opener:$PATH command broot "$@" }

# kak's :kakmux hands its session to a new kakmux and quits; this picks it up
# in the same terminal (the handoff file names the kakmux's tmux server).
# Windows' system dirs are left off kak's PATH, as in kakmux (see there).
kak() {
	local handoff=${XDG_RUNTIME_DIR:-/tmp}/kakmux-handoff-$$ name
	rm -f -- $handoff
	PATH=${(j.:.)path:#/mnt/?/[Ww][Ii][Nn][Dd][Oo][Ww][Ss](|/*)} KAKMUX_HANDOFF=$handoff command kak "$@"
	local rc=$?
	[[ -s $handoff ]] || return $rc
	name=$(<$handoff); rm -f -- $handoff
	TMUX= tmux -L "$name" attach \; set-option destroy-unattached on
}

# kakbr [file|dir]: broot as a sidebar beside Kakoune, as one pane wherever it
# runs (a terminal, or nested in another tmux): its own tmux server
# (kakbr-PID, ~/.config/kakbr/kakbr.conf) holding broot and a kakmux, so
# kak's splits and bufferline stay in the kak half. Files opened from broot go
# to kak (broot-open); <c-w> l/h move between the two. It lasts as long as kak:
# quitting kak (:qa, :q in its last split, or <c-w> q in broot) closes it all.
#   file        → kak opens it and gets focus; broot opens in $PWD if the
#                 file is under it, otherwise in the file's own directory
#   dir/nothing → broot in that dir (default $PWD) with focus, empty kak
kakbr() {
	emulate -L zsh
	local target=${1:-$PWD} root file
	if [[ -d $target ]]; then
		root=${target:A}
	else
		file=${target:A}
		[[ -d ${file:h} ]] || { print -u2 "kakbr: no such directory: ${file:h}"; return 1 }
		if [[ $file == $PWD/* ]]; then root=$PWD; else root=${file:h}; fi
	fi

	# kakbr's tmux server, and the session of the kak in it
	local session=kakbr-$$ ids side
	local -a t=(env -u TMUX -u TMUX_PANE tmux -L $session -f ~/.config/kakbr/kakbr.conf)
	# at this terminal's size (not tmux's default), so broot's width (25%,
	# within 24..40 columns: kakbr.conf, kakbr-sidebar) is right from the start
	local -a size=($(stty size 2>/dev/null)) dims
	(( $#size == 2 )) && dims=(-x $size[2] -y $size[1])
	# kak: a kakmux; when it ends, so does kakbr
	local q=\'
	local -a args=(-s $session)
	# opened with :edit (not as an argument) to show it relative to the cwd
	[[ -n $file ]] && args+=(-e "edit -- $q${file//$q/$q$q}$q")
	ids=("${(@f)$($t new-session -d -s $session -n ${root:t} -c $root $dims \
		-P -F $'#{session_id}\n#{pane_id}\n#{socket_path}' \
		-- sh -c '"$@"; tmux kill-session -t "$TMUX_PANE"' sh ~/.local/bin/kakmux $args)}") || return
	# broot left of it, born at its width: a resize while broot starts
	# (between reading its size and handling SIGWINCH) is lost on it, and it
	# keeps drawing at the size it read, garbled
	side=$($t split-window -h -b -d -t $ids[2] -c $root \
		-l $($t display-message -p -t $ids[2] '#{E:@kakbr_width}') -P -F '#{pane_id}' \
		-- env KAKBR_SESSION=$session ~/.local/bin/kakbr-sidebar) || return
	$t set-option -p -t $side @kakbr_sidebar 1
	# nested in another tmux: at the edges, <c-w> moves on there
	[[ -n $TMUX ]] && $t set-option -t $ids[1] @outer_pane "${TMUX%%,*} $TMUX_PANE"
	# for broot-open and <c-w> q, to focus kak
	$t set-option -w -t $side @kakbr_kak $ids[2]
	[[ -n $file ]] || $t select-pane -t $side

	# Closing the terminal would otherwise detach, leaving broot and kak
	# running in the background. (An explicit detach ends it too.) Set once
	# attached: on an unattached session it ends it there and then.
	$t attach -t $ids[1] \; set-option -t $ids[1] destroy-unattached on
}
