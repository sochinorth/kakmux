# rc/splits.kak, sourced by kakrc: splits (tmux).

# --- splits (tmux) ------------------------------------------------------------
# A split is a tmux pane running another client of this session, so all
# splits share buffers. Helix's :vsplit/:hsplit and <c-w> (also <space>w)
# window mode; tmux's own prefix keys work on the same panes too.

# Splits are weighted (bin/kakmux-even, run by kakmux.conf's tmux hooks,
# for tmux's own split keys too): opening or closing one shares out the
# row/column it's in by weight, members that are split themselves scaling
# as a whole. A new split gets the weights of the one it came from, so plain
# splits stay even (a second :vs makes thirds); :vs/:hs R makes the original
# R% and the new one (100 - R)% of the pair. :weight reads/sets weights.

# split-with -h|-v INIT [RATIO]: new client in a split, running kak commands INIT
define-command -override -hidden -params 2..3 split-with %{
	evaluate-commands %sh{
		if [ -z "$kak_client_env_TMUX" ]; then
			echo "fail 'split: needs tmux (:kakmux)'"; exit
		fi
		export TMUX="$kak_client_env_TMUX"
		[ -n "$3" ] && tmux set-option -w -t "$kak_client_env_TMUX_PANE" @kakmux_ratio "$3"
		tmux split-window "$1" -t "$kak_client_env_TMUX_PANE" -- \
			kak -c "$kak_session" -e "$2" >/dev/null 2>&1 || {
			tmux set-option -wu -t "$kak_client_env_TMUX_PANE" @kakmux_ratio
			echo "fail 'split: tmux split-window failed'"
		}
	}
}
define-command -override -hidden splits-even %{
	nop %sh{ ~/.config/kak/bin/kakmux-even "${kak_client_env_TMUX%%,*}" "$kak_client_env_TMUX_PANE" all >/dev/null 2>&1 }
}
# split-impl -h|-v [RATIO] [FILE]
define-command -override -hidden -params 1..3 split-impl %{
	evaluate-commands %sh{
		kq() { printf "'%s'" "$(printf %s "$1" | sed "s/'/''/g")"; }
		dir=$1; shift
		ratio=
		case $1 in
		[1-9]|[1-9][0-9]) ratio=$1; shift ;;
		*[!0-9]*|'') ;;
		*) echo "fail 'split: ratio must be 1 to 99'"; exit ;;
		esac
		if [ $# -ge 1 ]; then
			init="edit -- $(kq "$1")"
		else
			init="buffer -- $(kq "$kak_bufname"); select $kak_selections_desc"
		fi
		printf '%s\n' "split-with $dir $(kq "$init") $ratio"
	}
}
define-command -override vsplit -params ..2 -docstring 'vsplit [<ratio>] [<file>]: split side by side, this one <ratio>% (1-99) of the pair' %{ split-impl -h %arg{@} }
define-command -override hsplit -params ..2 -docstring 'hsplit [<ratio>] [<file>]: split stacked, this one <ratio>% (1-99) of the pair' %{ split-impl -v %arg{@} }
complete-command vsplit file
complete-command hsplit file
alias global vs vsplit
alias global hs hsplit
alias global sp hsplit

define-command -override weight -params ..2 -docstring 'weight [-width|-height] [<w>]: set this split''s share of the row/column it''s directly in, or with -width (-height), the share of the part holding it in the next row (column) out; without <w>, show those' %{
	evaluate-commands %sh{
		if [ -z "$kak_client_env_TMUX" ]; then
			echo "fail 'weight: needs tmux (:kakmux)'"; exit
		fi
		axis=-
		case $1 in -width) axis=h; shift ;; -height) axis=v; shift ;; esac
		case $1 in
		'') ;;
		*[!0-9.]*|.|*.*.*) echo "fail 'weight: not a positive number: $1'"; exit ;;
		*) awk -v w="$1" 'BEGIN { exit !(w > 0) }' || { echo "fail 'weight: not a positive number: $1'"; exit; } ;;
		esac
		out=$(~/.config/kak/bin/kakmux-even "${kak_client_env_TMUX%%,*}" "$kak_client_env_TMUX_PANE" weight "$axis" "$1")
		[ -n "$1" ] || {
			set -- $out
			echo "echo 'weight: $1 here · -width $2 · -height $3'"
		}
	}
}

# close every other split: the window's other panes labelled with this
# session (see client-hello below), not shells or other sessions' clients
# sharing the window. With one pane left, the weights only name panes gone.
define-command -override -hidden split-only %{
	evaluate-commands %sh{
		if [ -z "$kak_client_env_TMUX" ] || [ -z "$kak_client_env_TMUX_PANE" ]; then
			echo "fail 'split: needs tmux (:kakmux)'"; exit
		fi
		export TMUX="$kak_client_env_TMUX"
		me=$kak_client_env_TMUX_PANE
		tmux list-panes -t "$me" -F '#{pane_id} #{@kak_session}' 2>/dev/null |
			while IFS=' ' read -r p s; do
				[ "$p" != "$me" ] && [ "$s" = "$kak_session" ] && tmux kill-pane -t "$p"
			done >/dev/null 2>&1
		[ "$(tmux display-message -p -t "$me" '#{window_panes}' 2>/dev/null)" = 1 ] &&
			tmux set-option -wu -t "$me" @kakmux_weights >/dev/null 2>&1
		exit 0
	}
}

# tmux-here ARGS: a tmux command on this client's tmux server (never the
# default one, for a client outside tmux)
define-command -override -hidden -params 1.. tmux-here %{
	evaluate-commands %sh{
		if [ -z "$kak_client_env_TMUX" ] || [ -z "$kak_client_env_TMUX_PANE" ]; then
			echo "fail 'split: needs tmux (:kakmux)'"; exit
		fi
		TMUX="$kak_client_env_TMUX" tmux "$@" >/dev/null 2>&1
		exit 0
	}
}
# split-focus -L|-R|-U|-D: unlike tmux, don't wrap around at the edges. At
# one, a tmux nested in another (kakmux, :kakmux) moves on there, by the same
# rule: its session option @outer_pane holds the other's socket and the pane
# it runs in, and that tmux's session may have one in turn.
define-command -override -hidden -params 1 split-focus %{
	nop %sh{
		case $1 in -L) edge=left ;; -R) edge=right ;; -U) edge=top ;; -D) edge=bottom ;; esac
		socket=${kak_client_env_TMUX%%,*} pane=$kak_client_env_TMUX_PANE
		while [ -n "$socket" ] && [ -n "$pane" ]; do
			if [ "$(tmux -S "$socket" display-message -p -t "$pane" "#{pane_at_$edge}" 2>/dev/null)" != 1 ]; then
				tmux -S "$socket" select-pane "$1" -t "$pane" >/dev/null 2>&1
				exit
			fi
			outer=$(tmux -S "$socket" show-options -qv -t "$pane" @outer_pane 2>/dev/null)
			socket=${outer%% *} pane=${outer#* }
		done
	}
}

# Each client labels its tmux pane with @kak_session and @kak_client, so tools
# outside kak can reach the client in a pane (broot-open opens files there).
# All that's done as a client connects (or is renamed) is in one shell: the
# label (in the background: nothing waits on tmux), kakmux_clients (see
# bufferline), the status line's kakmux tail (see status line).
define-command -override -hidden client-hello %{
	evaluate-commands %sh{
		# kak-quoted, in $r (all in the shell, no other processes)
		kq() {
			r= rest=$1 q=\'
			while :; do
				case $rest in
				*"$q"*) r="$r${rest%%"$q"*}$q$q" rest=${rest#*"$q"} ;;
				*) r="'$r$rest'"; return ;;
				esac
			done
		}
		if [ -n "$kak_hook_param" ] && [ "$kak_hook_param" != "$kak_client" ]; then
			# renamed: OLD:NEW
			kq "${kak_hook_param%:*}"; echo "set-option -remove global kakmux_clients $r"
		fi
		case ${kak_client_env_TMUX%%,*} in */kakmux-*)
			echo 'set-option -add global kakmux_clients %val{client}'
			if [ "$kak_opt_modeline_kakmux" = armed ]; then
				echo "set-option global modeline_kakmux ''"
				fmt=${kak_opt_modelinefmt%" - %val{client}@[%val{session}]"}
				[ "$fmt" = "$kak_opt_modelinefmt" ] || { kq "$fmt"; echo "set-option global modelinefmt $r"; }
			fi ;;
		esac
		[ -n "$kak_client_env_TMUX_PANE" ] || exit
		TMUX="$kak_client_env_TMUX" tmux \
			set-option -p -t "$kak_client_env_TMUX_PANE" @kak_session "$kak_session" \; \
			set-option -p -t "$kak_client_env_TMUX_PANE" @kak_client "$kak_client" >/dev/null 2>&1 </dev/null &
	}
}
hook -group kakrc global ClientCreate  .* client-hello
hook -group kakrc global ClientRenamed .* client-hello

# run-in-focused-client CMD: run kak commands CMD in the client focused last
# (else any), for tools outside kak that only know its session: broot-open
# opens files that way
declare-option -hidden str focused_client
hook -group kakrc global ClientCreate .* %{ set-option global focused_client %val{client} }
hook -group kakrc global FocusIn      .* %{ set-option global focused_client %val{client} }
define-command -override -hidden -params 1 run-in-focused-client %{
	evaluate-commands %sh{
		eval set -- "$kak_quoted_client_list"
		target=$1
		for c; do [ "$c" = "$kak_opt_focused_client" ] && target=$c; done
		[ -n "$target" ] || exit
		printf "evaluate-commands -client '%s' %%arg{1}\n" "$(printf %s "$target" | sed "s/'/''/g")"
	}
}

# split-swap -L|-R|-U|-D: this split and its neighbour that way trade
# places (not past the edge), the focus staying with this one. Weights go
# with the place (as Helix's sizes do): the two panes' names are swapped in
# them.
define-command -override -hidden -params 1 split-swap %{
	evaluate-commands %sh{
		if [ -z "$kak_client_env_TMUX" ] || [ -z "$kak_client_env_TMUX_PANE" ]; then
			echo "fail 'split: needs tmux (:kakmux)'"; exit
		fi
		export TMUX="$kak_client_env_TMUX"
		case $1 in -L) edge=left ;; -R) edge=right ;; -U) edge=top ;; -D) edge=bottom ;; esac
		me=$kak_client_env_TMUX_PANE
		[ "$(tmux display-message -p -t "$me" "#{pane_at_$edge}" 2>/dev/null)" = 0 ] || exit 0
		tmux select-pane -t "$me" "$1" >/dev/null 2>&1
		other=$(tmux list-panes -t "$me" -F '#{pane_active} #{pane_id}' 2>/dev/null | sed -n 's/^1 //p')
		[ -n "$other" ] && [ "$other" != "$me" ] || exit 0
		tmux swap-pane -s "$me" -t "$other" \; select-pane -t "$me" >/dev/null 2>&1
		w=$(tmux show-options -wqv -t "$me" @kakmux_weights 2>/dev/null)
		[ -n "$w" ] && w=$(printf %s "$w" | jq -c --arg a "$me" --arg b "$other" \
			'with_entries(.key |= (split(",") | map(if . == $a then $b elif . == $b then $a else . end) | sort | join(",")))' 2>/dev/null) &&
			tmux set-option -w -t "$me" @kakmux_weights "$w" >/dev/null 2>&1
		exit 0
	}
}
# split-goto-file -h|-v: gf (see goto-file) in a new split
define-command -override -hidden -params 1 split-goto-file %{
	evaluate-commands %sh{
		kq() { printf "'%s'" "$(printf %s "$1" | sed "s/'/''/g")"; }
		init="buffer -- $(kq "$kak_bufname"); select $kak_selections_desc; goto-file"
		printf '%s\n' "split-with $1 $(kq "$init")"
	}
}

# Helix's window mode: each key also with Ctrl held (<c-w><c-v>...), H J K L
# swap with the split that way, f / F gf in a split stacked / side by side.
try %{ declare-user-mode window }
map global window v ':vsplit<ret>'                         -docstring 'split side by side'
map global window s ':hsplit<ret>'                         -docstring 'split stacked'
map global window h ':split-focus -L<ret>'                 -docstring 'focus left'
map global window j ':split-focus -D<ret>'                 -docstring 'focus down'
map global window k ':split-focus -U<ret>'                 -docstring 'focus up'
map global window l ':split-focus -R<ret>'                 -docstring 'focus right'
map global window <left>  ':split-focus -L<ret>'           -docstring 'focus left'
map global window <down>  ':split-focus -D<ret>'           -docstring 'focus down'
map global window <up>    ':split-focus -U<ret>'           -docstring 'focus up'
map global window <right> ':split-focus -R<ret>'           -docstring 'focus right'
map global window w ':tmux-here select-pane -t :.+<ret>'   -docstring 'next split'
map global window q ':quit<ret>'                           -docstring 'close this split'
map global window o ':split-only<ret>'                     -docstring 'close other splits'
map global window z ':tmux-here resize-pane -Z -t %val{client_env_TMUX_PANE}<ret>' -docstring 'zoom this split (toggle)'
map global window = ':splits-even<ret>'                     -docstring 'even out all splits'
map global window H ':split-swap -L<ret>'                  -docstring 'swap with the split left'
map global window J ':split-swap -D<ret>'                  -docstring 'swap with the split below'
map global window K ':split-swap -U<ret>'                  -docstring 'swap with the split above'
map global window L ':split-swap -R<ret>'                  -docstring 'swap with the split right'
map global window f ':split-goto-file -v<ret>'             -docstring 'file under cursor, split stacked'
map global window F ':split-goto-file -h<ret>'             -docstring 'file under cursor, split side by side'
map global window <c-v> ':vsplit<ret>'                     -docstring 'split side by side'
map global window <c-s> ':hsplit<ret>'                     -docstring 'split stacked'
map global window <c-h> ':split-focus -L<ret>'             -docstring 'focus left'
map global window <c-j> ':split-focus -D<ret>'             -docstring 'focus down'
map global window <c-k> ':split-focus -U<ret>'             -docstring 'focus up'
map global window <c-l> ':split-focus -R<ret>'             -docstring 'focus right'
map global window <c-w> ':tmux-here select-pane -t :.+<ret>' -docstring 'next split'
map global window <c-q> ':quit<ret>'                       -docstring 'close this split'
map global window <c-o> ':split-only<ret>'                 -docstring 'close other splits'
map global normal <c-w> ':enter-user-mode window<ret>'
map global user   w     ':enter-user-mode window<ret>'     -docstring 'window mode'

# Helix's gn/gp: next/previous buffer
map global goto n '<esc>:buffer-next<ret>'     -docstring 'next buffer'
map global goto p '<esc>:buffer-previous<ret>' -docstring 'previous buffer'
