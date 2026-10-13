# rc/bufferline.kak, sourced by kakrc: the bufferline (tmux).

# --- bufferline (tmux) --------------------------------------------------------
# Kakoune can't draw a bufferline itself, so each client publishes its buffer
# list to its tmux pane as @kak_bufferline, which kakmux.conf draws as the
# status line. Like bufferline = "multiple", it only shows with 2+ buffers.
# Only under kakmux: in any other tmux the status line is the user's own.

declare-option -hidden str-list bufferline_bufs
# what each pane was last sent for, "pane|buffer|styles|buffers": the same
# again skips the shell and the tmux call. Per pane, not per window: a window
# comes back to a pane that has shown others since.
declare-option -hidden str-list bufferline_sent
declare-option -hidden str-list bufferline_key

# Colours: the faces BufferLineActive and BufferLineInactive (which also fills
# the rest of the line), or for colour schemes without them, MenuForeground
# (as the pickers' selected row) and StatusLine. Turned into tmux styles once
# per colour scheme, from the faces dump (see rc/pickers.kak).
declare-option -hidden str bufferline_active
declare-option -hidden str bufferline_inactive

define-command -override -hidden bufferline-load-styles %{
	faces-load
	evaluate-commands %sh{
		# All in the shell, no other processes. A dump line reads
		# ` * Name: fg,bg,underline[+attrs]`, the last one for a face counting;
		# references to other faces show as default, as if unset.
		while IFS= read -r l; do
			case $l in
			' * BufferLineActive: '*|' * BufferLineInactive: '*|' * MenuForeground: '*|' * StatusLine: '*)
				n=${l#' * '}; eval "face_${n%%: *}=\${n#*: }" ;;
			esac
		done <<-EOF
			$kak_opt_faces_cache
		EOF
		# kak colour -> tmux colour, in $v
		col() {
			case $1 in
			rgb:*) v="#${1#rgb:}" ;;
			rgba:*) v=${1#rgba:}; v="#${v%??}" ;;
			bright-*) v="bright${1#bright-}" ;;
			*) v=$1 ;;
			esac
		}
		# style FACE FALLBACK: FACE's tmux style, or FALLBACK's if FACE is
		# unset, in $s
		style() {
			eval "spec=\${face_$1:-}"
			case $spec in ''|default,default,default) eval "spec=\${face_$2:-}" ;; esac
			[ -n "$spec" ] || spec=default,default,default
			fg=${spec%%,*} rest=${spec#*,}
			bg=${rest%%,*} rest=${rest#*,}
			ul=${rest%%+*} attrs=
			case $rest in *+*) attrs=${rest#*+} ;; esac
			col "$fg"; s="fg=$v"; col "$bg"; s="$s,bg=$v"
			while [ -n "$attrs" ]; do
				a=${attrs%"${attrs#?}"} attrs=${attrs#?}
				case $a in
				u) s="$s,underscore" ;; c) s="$s,curly-underscore" ;; U) s="$s,double-underscore" ;;
				b) s="$s,bold" ;; i) s="$s,italics" ;; d) s="$s,dim" ;; r) s="$s,reverse" ;;
				s) s="$s,strikethrough" ;; B) s="$s,blink" ;;
				esac
			done
			[ "$ul" = default ] || { col "$ul"; s="$s,us=$v"; }
		}
		style BufferLineActive MenuForeground
		printf "set-option global bufferline_active '%s'\n" "$s"
		style BufferLineInactive StatusLine
		printf "set-option global bufferline_inactive '%s'\n" "$s"
	}
}

# This runs whenever keys stop, so the check whether anything changed is
# done without a shell: the key, less what was sent, is nothing (which
# bufferline-none, taking no arguments, accepts) when it was sent already.
define-command -override -hidden -params 0 bufferline-none nop
define-command -override -hidden bufferline-refresh %{
	set-option global bufferline_bufs
	evaluate-commands -buffer * %{
		set-option -add global bufferline_bufs "%val{modified}:%val{bufname}"
	}
	try %{
		set-option global bufferline_key "%val{client_env_TMUX_PANE}|%val{bufname}|%opt{bufferline_active}|%opt{bufferline_inactive}|%opt{bufferline_bufs}"
		set-option -remove global bufferline_key %opt{bufferline_sent}
		evaluate-commands -verbatim bufferline-none %opt{bufferline_key}
	} catch %{
		bufferline-send
	}
}
# (bufferline_key holds this pane's key)
define-command -override -hidden bufferline-send %{
	evaluate-commands %sh{
		case ${kak_client_env_TMUX%%,*} in */kakmux-*) ;; *) exit 0 ;; esac
		[ -n "$kak_client_env_TMUX_PANE" ] || exit 0
		if [ -z "$kak_opt_bufferline_active" ]; then
			echo 'bufferline-load-styles; bufferline-refresh'; exit 0
		fi
		# double C in S, in $r (all in the shell, no other processes)
		double() {
			r= rest=$2
			while :; do
				case $rest in
				*"$1"*) r="$r${rest%%"$1"*}$1$1" rest=${rest#*"$1"} ;;
				*) r=$r$rest; return ;;
				esac
			done
		}
		eval set -- "$kak_quoted_opt_bufferline_bufs"
		line=
		for e; do
			name=${e#*:} label=${e#*:}
			label=${label##*/}
			[ "${e%%:*}" = true ] && label="$label[+]"
			case $label in *'#'*) double '#' "$label"; label=$r ;; esac
			if [ "$name" = "$kak_bufname" ]; then
				line="$line#[$kak_opt_bufferline_active] $label #[default]"
			else
				line="$line#[$kak_opt_bufferline_inactive] $label "
			fi
		done
		[ $# -gt 1 ] || line=
		export TMUX="$kak_client_env_TMUX"
		status=off; [ -n "$line" ] && status=on
		tmux set-option -p -t "$kak_client_env_TMUX_PANE" @kak_bufferline "$line" \; \
			set-option -t "$kak_client_env_TMUX_PANE" status-style "$kak_opt_bufferline_inactive" \; \
			set-option -t "$kak_client_env_TMUX_PANE" status "$status" \
			>/dev/null 2>&1
		# this pane's key replaces what it was sent before
		eval set -- "$kak_quoted_opt_bufferline_sent"
		sent=
		for e; do
			case $e in "$kak_client_env_TMUX_PANE|"*) continue ;; esac
			double "'" "$e"; sent="$sent '$r'"
		done
		printf '%s\n' "set-option global bufferline_sent$sent"
		echo 'set-option -add global bufferline_sent %opt{bufferline_key}'
	}
}

# Idle hooks catch every change (new/closed buffer, switch, first edit, save)
# once keys stop; FocusIn catches changes another client made. Only for
# kakmux clients: kakmux_clients lists them (as each connects, client-hello
# in rc/splits.kak), and the check is without a shell (the client, less
# those, is nothing).
declare-option -hidden str-list kakmux_clients
declare-option -hidden str-list kakmux_cmp
define-command -override -hidden -params 0 kakmux-none nop
hook -group kakrc global ClientClose .* %{ set-option -remove global kakmux_clients %val{hook_param} }
define-command -override -hidden bufferline-idle %{
	try %{
		set-option window kakmux_cmp %val{client}
		set-option -remove window kakmux_cmp %opt{kakmux_clients}
		evaluate-commands -verbatim kakmux-none %opt{kakmux_cmp}
		bufferline-refresh
	}
}
hook -group kakrc global NormalIdle .* bufferline-idle
hook -group kakrc global InsertIdle .* bufferline-idle
hook -group kakrc global FocusIn    .* bufferline-idle

# :kakmux moves this client into a kakmux: it opens a client on the same session
# in a new, detached kakmux (its own tmux server, as each kakmux has), which
# quits this one once connected (quitting first could take the server down
# with the last client). kak (shell/kakmux.zsh's wrapper, which set
# KAKMUX_HANDOFF) then attaches it in this terminal, or inside another tmux,
# nested in this pane (see ~/.local/bin/kakmux).
define-command -override kakmux -docstring 'continue this session inside kakmux (tmux bufferline)' %{
	evaluate-commands %sh{
		case ${kak_client_env_TMUX%%,*} in */kakmux-*)
			echo "fail 'kakmux: already inside kakmux'"; exit ;;
		esac
		server=kakmux-$$
		buf=$(printf %s "$kak_bufname" | sed "s/'/''/g")
		init="buffer -- '$buf'; select $kak_selections_desc"
		# (the handoff is written first: the new client may quit this one,
		# and so end the wrapper's kak, before tmux returns)
		if [ -n "$kak_client_env_KAKMUX_HANDOFF" ]; then
			printf %s "$server" > "$kak_client_env_KAKMUX_HANDOFF"
			init="$init; evaluate-commands -client $kak_client quit"
		fi
		TMUX= tmux -L "$server" -f ~/.config/kak/kakmux.conf new-session -d -- \
			kak -c "$kak_session" -e "$init" || {
			[ -z "$kak_client_env_KAKMUX_HANDOFF" ] || rm -f -- "$kak_client_env_KAKMUX_HANDOFF"
			echo "fail 'kakmux: tmux failed'"; exit
		}
		# nested: at its edges, <c-w> moves on to this pane's neighbours
		[ -z "$kak_client_env_TMUX" ] ||
			TMUX= tmux -L "$server" set-option @outer_pane \
				"${kak_client_env_TMUX%%,*} $kak_client_env_TMUX_PANE" >/dev/null 2>&1
		[ -n "$kak_client_env_KAKMUX_HANDOFF" ] ||
			echo "echo -markup '{Information}not started via the kak wrapper; run: TMUX= tmux -L $server attach'"
	}
}
