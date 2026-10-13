# rc/pickers.kak, sourced by kakrc: pickers, command palette, jump labels,
# explorer.

# --- pickers (<space>b buffers, <space>f files) ------------------------------
# Helix-style fuzzy pickers in a tmux popup (so kakmux, or any tmux), coloured
# from the current colour scheme's menu faces. bin/kak-picker does the fzf and
# the actions; its legend lists the keys. picker-open hands it a temp dir
# holding the faces (and whatever else the picker kind needs).

# bat theme for the previews (bat can't follow kak's colour scheme)
declare-option str picker_bat_theme TwoDark

# :debug faces is the only way to read the faces' colours (the pickers' and
# the bufferline's). It appends to *debug* (which can't be edited, so dumps
# can't be cleaned up), so dump once and cache it, and only again after
# :colorscheme, which an alias wraps to drop the cache (and reset the faces
# that only some schemes set).
# It lists the faces of the scope it runs in; for a client that's its
# (usually empty) window scope, so it runs in *debug*'s buffer context.
declare-option -hidden str faces_cache

define-command -override -hidden faces-load %{
	evaluate-commands %sh{
		[ -n "$kak_opt_faces_cache" ] ||
			echo "evaluate-commands -buffer *debug* %{ debug faces; execute-keys 'ge<a-?>^Faces:<ret>'; set-option global faces_cache %val{selection} }"
	}
}

define-command -override -hidden -params 1 picker-colorscheme %{
	set-option global faces_cache ''
	set-option global bufferline_active ''
	# for schemes without them (default: the bufferline's fallbacks)
	evaluate-commands %opt{plugin_faces}
	evaluate-commands %opt{kakrc_faces}
	set-face global StatusLineInactive '+d@StatusLine'
	set-face global BufferLineActive default
	set-face global BufferLineInactive default
	unalias global colorscheme picker-colorscheme
	try %{
		colorscheme %arg{1}
	} catch %{
		alias global colorscheme picker-colorscheme
		fail %val{error}
	}
	alias global colorscheme picker-colorscheme
}
complete-command picker-colorscheme shell-script-candidates %{
	find -L "${kak_runtime}/colors" "${kak_config}/colors" -type f -name '*.kak' \
		| sed 's|.*/||; s|\.kak$||' | sort -u
}
alias global colorscheme picker-colorscheme

declare-option -hidden str-list buffer_mru
hook -group kakrc global WinDisplay .* %{
	set-option -remove global buffer_mru %val{bufname}
	set-option -add global buffer_mru %val{bufname}
}

# where each buffer's cursor last was: evaluate-commands -buffer, which the
# buffer picker reads buffers with, always starts at line 1
declare-option -hidden int picker_line 1
hook -group kakrc global NormalIdle .* %{ set-option buffer picker_line %val{cursor_line} }

# clients with a picker popup open: the popup takes the focus, but that isn't
# leaving the editor (no auto-save, no dimmed status line). Until FocusIn.
declare-option -hidden str-list picker_clients
hook -group kakrc global FocusIn     .* %{ set-option -remove global picker_clients %val{client} }
hook -group kakrc global ClientClose .* %{ set-option -remove global picker_clients %val{hook_param} }

# picker-open KIND DIR [CWD]: the popup (fzf, rg, git) runs in CWD, else
# kak's cwd. It keeps DIR at DIR/last when it closes, for picker-resume.
declare-option -hidden str picker_resume_from
define-command -override -hidden -params 2..3 picker-open %{
	evaluate-commands %sh{
		if [ -z "$kak_client_env_TMUX" ]; then
			rm -rf -- "${2:?}"
			echo "fail 'picker: needs tmux (:kakmux)'"; exit
		fi
		printf '%s\n' "${TMPDIR:-/tmp}/kak-picker-last.$kak_session" > "$2/last"
		if [ -n "$kak_opt_picker_resume_from" ]; then
			cp -- "$kak_opt_picker_resume_from/query" "$kak_opt_picker_resume_from/pos" "$2/" 2>/dev/null
			echo "set-option global picker_resume_from ''"
		fi
	}
	faces-load
	echo -to-file "%arg{2}/faces" %opt{faces_cache}
	set-option -remove global picker_clients %val{client}
	set-option -add global picker_clients %val{client}
	nop %sh{
		{
			TMUX="$kak_client_env_TMUX" tmux display-popup -t "$kak_client_env_TMUX_PANE" \
				-d "${3:-$PWD}" -e "BAT_THEME=$kak_opt_picker_bat_theme" -E -B -w 90% -h 80% -- \
				~/.config/kak/bin/kak-picker "$1" "${2:?}" "$kak_session" "$kak_client" "$kak_client_env_TMUX_PANE" \
				|| {
					rm -rf -- "${2:?}"
					printf "set-option -remove global picker_clients '%s'\n" "$(printf %s "$kak_client" | sed "s/'/''/g")" |
						kak -p "$kak_session"
				}
		} >/dev/null 2>&1 </dev/null &
	}
}

# Helix's <space>': the last picker again, with what was typed and the
# cursor where they were. kak-lsp's lists (references, diagnostics,
# symbols) as they were then, without asking the server again; the buffers,
# files, search results, changes and commands as they are now.
define-command -override picker-resume -docstring 'reopen the last picker as it was left' %{
	evaluate-commands %sh{
		kq() { printf "'%s'" "$(printf %s "$1" | sed "s/'/''/g")"; }
		last=${TMPDIR:-/tmp}/kak-picker-last.$kak_session
		[ -e "$last/kind" ] || { echo "fail 'no picker to reopen'"; exit; }
		IFS= read -r kind < "$last/kind"; IFS= read -r cwd < "$last/cwd"
		case $kind in
		buffers) echo "set-option global picker_resume_from $(kq "$last"); buffer-picker" ;;
		commands) echo "set-option global picker_resume_from $(kq "$last"); command-palette" ;;
		*)
			dir=$(mktemp -d "${TMPDIR:-/tmp}/kak-picker.XXXXXX") || exit
			cp -R -- "$last"/. "$dir"/ && rm -f -- "$dir/kind" "$dir/cwd"
			echo "picker-open $(kq "$kind") $(kq "$dir") $(kq "$cwd")" ;;
		esac
	}
}
hook -group kakrc global KakEnd .* %{
	nop %sh{ rm -rf -- "${TMPDIR:-/tmp}/kak-picker-last.$kak_session" }
}
map global user <quote> ':picker-resume<ret>' -docstring 'last picker again'

define-command -override buffer-picker -docstring 'fuzzy-pick a buffer (tmux popup)' %{
	evaluate-commands %sh{
		dir=$(mktemp -d "${TMPDIR:-/tmp}/kak-picker.XXXXXX") || exit
		# All in the shell, no process per buffer. STR with each A in it
		# made B, in $r
		rep() {
			r= rest=$3
			while :; do
				case $rest in
				*"$1"*) r="$r${rest%%"$1"*}$2" rest=${rest#*"$1"} ;;
				*) r=$r$rest; return ;;
				esac
			done
		}
		nl=$kak_opt_nl
		# each buffer once, but *debug*: B's files and the commands
		# writing its cursor line, modified flag and text there
		n=0 seen=$nl
		add() {
			case $seen in *"$nl$1$nl"*) return ;; esac
			seen="$seen$1$nl"
			[ "$1" != '*debug*' ] || return
			printf %s "$1" > "${dir:?}/${n:?}.name"
			# -buffer takes a comma-separated list: escape \ and , in the name
			rep '\' '\\' "$1"; rep , '\,' "$r"; rep "'" "''" "$r"
			printf "evaluate-commands -buffer '%s' %%{ echo -to-file '%s' %%opt{picker_line} %%val{modified}; execute-keys '%%'; echo -to-file '%s' %%val{selection} }\n" \
				"$r" "${dir:?}/${n:?}.meta" "${dir:?}/${n:?}"
			n=$((n + 1))
		}
		eval "set -- $kak_quoted_buflist"
		open=$nl; for b; do open="$open$b$nl"; done
		# most recent first (closed buffers left in the MRU skipped), then
		# any buffer never displayed yet
		eval "set -- $kak_quoted_opt_buffer_mru"
		i=$#
		while [ "$i" -gt 0 ]; do
			eval "b=\${$i}"; i=$((i - 1))
			case $open in *"$nl$b$nl"*) add "$b" ;; esac
		done
		eval "set -- $kak_quoted_buflist"
		for b; do add "$b"; done
		echo "picker-open buffers '${dir:?}'"
	}
}

define-command -override file-picker -params ..1 -docstring "file-picker [-cwd]: fuzzy-pick a file under the buffer's workspace root (or kak's cwd) (tmux popup)" %{
	evaluate-commands %sh{
		root=${kak_opt_workspace_root:-$PWD}; [ "$1" = -cwd ] && root=$PWD
		dir=$(mktemp -d "${TMPDIR:-/tmp}/kak-picker.XXXXXX") || exit
		printf "picker-open files '%s' '%s'\n" "${dir:?}" "$(printf %s "$root" | sed "s/'/''/g")"
	}
}

map global user b ':buffer-picker<ret>'   -docstring 'buffer picker'
map global user f ':file-picker<ret>'     -docstring 'file picker (workspace)'
map global user F ':file-picker -cwd<ret>' -docstring "file picker (kak's cwd)"

# --- command palette (<space>?) ------------------------------------------------
# Helix's: every command, with its keys and the first line of its docstring,
# and every mapping of the menus (user, goto, view, object, the user modes)
# that isn't just a command's key. Enter runs it; a command that needs
# arguments opens the prompt with its name typed. The commands are read
# from the scripts that define them (bin/kak-picker --parse: Kakoune's docs,
# the autoloaded scripts, the plugins' as they loaded, the kakrc and rc/),
# once, and each time those that exist just then are kept (modules load
# later: a command exists if an alias to it can be made). Mappings come from
# :debug mappings, which, like :debug faces, is dumped once and cached.
# Both are read again after :config-reload.
# (The plugins' scripts go to the parser in a file: an environment
# variable can't hold them.)
declare-option -hidden str palette_cmds
declare-option -hidden str palette_probe
declare-option -hidden str-list palette_ok
declare-option -hidden bool palette_loaded false
declare-option -hidden str mappings_cache
set-option global palette_loaded false
set-option global mappings_cache ''
define-command -override -hidden palette-load %{
	evaluate-commands %sh{
		[ -n "$kak_opt_mappings_cache" ] ||
			echo "evaluate-commands -buffer *debug* %{ debug mappings; execute-keys 'ge<a-?>^Mappings:<ret>'; set-option global mappings_cache %val{selection} }"
		[ "$kak_opt_palette_loaded" = true ] && exit
		f=$(mktemp "${TMPDIR:-/tmp}/kak-palette.XXXXXX") || exit
		echo "echo -to-file '$f' %opt{plugin_rc}; palette-parse '$f'"
	}
}
define-command -override -hidden -params 1 palette-parse %{
	evaluate-commands %sh{
		~/.config/kak/bin/kak-picker --parse "$kak_config" "$kak_runtime" "$1"
		rm -f -- "$1"
	}
	set-option global palette_loaded true
}
define-command -override command-palette -docstring 'run any command or mapping, found by name, key or docstring (picker)' %{
	palette-load
	set-option global palette_ok
	evaluate-commands %opt{palette_probe}
	evaluate-commands %sh{
		dir=$(mktemp -d "${TMPDIR:-/tmp}/kak-picker.XXXXXX") || exit
		echo "echo -to-file '$dir/cmds' %opt{palette_cmds}"
		echo "echo -to-file '$dir/ok' %opt{palette_ok}"
		echo "echo -to-file '$dir/mappings' %opt{mappings_cache}"
		echo "picker-open commands '$dir'"
	}
}
map global user ? ':command-palette<ret>' -docstring 'command palette'

# --- jump labels (<ret>) --------------------------------------------------------
# Helix's gw, on one key: <ret> labels every word on screen (two characters
# or more) with two letters, drawn over its first two, the nearest ones
# (after the cursor, before it, in turn) getting the first labels: aa, ab,
# ... az, ba ... Typing a label selects that word (and saves the selection
# before on the jump list); <s-ret> extends the main selection to it
# instead. Any other key cancels. Buffers whose <ret> does something of its
# own keep it: those that map it (kak-lsp's lists, diff, man, doc, git)
# outrank this global mapping, and grep and make, which watch for the key
# (a NormalKey hook, which a mapping hides), get it passed on. One shell
# works out the labels, one finds the word picked; the first key typed only
# narrows the labels down (an option per first letter).
declare-option -hidden range-specs jump_labels
declare-option -hidden str-list jump_targets
declare-option -hidden str jump_first
declare-option -hidden str jump_extend
declare-option -hidden str-list jump_descs
declare-option -hidden range-specs jump_labels_a; declare-option -hidden range-specs jump_labels_b
declare-option -hidden range-specs jump_labels_c; declare-option -hidden range-specs jump_labels_d
declare-option -hidden range-specs jump_labels_e; declare-option -hidden range-specs jump_labels_f
declare-option -hidden range-specs jump_labels_g; declare-option -hidden range-specs jump_labels_h
declare-option -hidden range-specs jump_labels_i; declare-option -hidden range-specs jump_labels_j
declare-option -hidden range-specs jump_labels_k; declare-option -hidden range-specs jump_labels_l
declare-option -hidden range-specs jump_labels_m; declare-option -hidden range-specs jump_labels_n
declare-option -hidden range-specs jump_labels_o; declare-option -hidden range-specs jump_labels_p
declare-option -hidden range-specs jump_labels_q; declare-option -hidden range-specs jump_labels_r
declare-option -hidden range-specs jump_labels_s; declare-option -hidden range-specs jump_labels_t
declare-option -hidden range-specs jump_labels_u; declare-option -hidden range-specs jump_labels_v
declare-option -hidden range-specs jump_labels_w; declare-option -hidden range-specs jump_labels_x
declare-option -hidden range-specs jump_labels_y; declare-option -hidden range-specs jump_labels_z
add-highlighter -override global/jump-labels replace-ranges jump_labels

define-command -override -hidden jump-labels-native-grep %{ execute-keys -with-hooks <ret> }
define-command -override -hidden jump-labels-native-make %{ execute-keys -with-hooks <ret> }
define-command -override -hidden -params ..1 jump-labels %{
	try %{
		evaluate-commands "jump-labels-native-%opt{filetype}"
	} catch %{
		set-option window jump_extend %arg{1}
		evaluate-commands -draft %{
			execute-keys gtGbx
			try %{
				execute-keys 's\b\w\w<ret>'
				set-option window jump_descs %val{selections_desc}
			} catch %{ set-option window jump_descs }
		}
		evaluate-commands %sh{
			eval set -- $kak_quoted_opt_jump_descs
			[ $# -gt 0 ] || { echo "fail 'jump: no words on screen'"; exit; }
			printf '%s\n' "$@" | LC_ALL=C awk -v cl="$kak_cursor_line" -v cc="$kak_cursor_column" '
			BEGIN { abc = "abcdefghijklmnopqrstuvwxyz" }
			{
				split($0, r, /[.,]/); l = r[1] + 0; c = r[2] + 0
				if (l > cl || (l == cl && c > cc)) F[++nf] = $0; else Bk[++nb] = $0
			}
			END {
				# after the cursor, nearest first, then before it, in turn
				n = 0; i = 1; j = nb
				while ((i <= nf || j >= 1) && n < 676) {
					if (i <= nf) W[n++] = F[i++]
					if (j >= 1 && n < 676) W[n++] = Bk[j--]
				}
				all = ""
				for (k = 0; k < n; k++) {
					lab = substr(abc, int(k / 26) + 1, 1) substr(abc, k % 26 + 1, 1)
					split(W[k], r, ","); spec = " \047" W[k] "|{JumpLabel}" lab "\047"
					all = all spec; ONE[substr(lab, 1, 1)] = ONE[substr(lab, 1, 1)] spec
					tg = tg " \047" lab "=" r[1] "\047"
				}
				print "set-option window jump_labels %val{timestamp}" all
				for (k = 1; k <= 26; k++) {
					f = substr(abc, k, 1)
					print "set-option window jump_labels_" f " %val{timestamp}" ONE[f]
				}
				print "set-option window jump_targets" tg
				print "on-key -mode-name jump %{ jump-labels-first %val{key} }"
			}'
		}
	}
}
define-command -override -hidden -params 1 jump-labels-first %{
	try %{
		evaluate-commands "set-option window jump_labels %%opt{jump_labels_%arg{1}}"
		set-option window jump_first %arg{1}
		on-key -mode-name jump %{ jump-labels-go %val{key} }
	} catch %{
		jump-labels-clear
	}
}
define-command -override -hidden -params 1 jump-labels-go %{
	set-option window jump_labels %val{timestamp}
	evaluate-commands %sh{
		want="$kak_opt_jump_first$1="
		eval set -- $kak_quoted_opt_jump_targets
		for t; do
			case $t in "$want"*) ;; *) continue ;; esac
			to=${t#"$want"}
			if [ -z "$kak_opt_jump_extend" ]; then
				echo "execute-keys <c-s>; select $to,$to; execute-keys <a-i>w"; exit
			fi
			# extend: from the main selection's anchor; past it, to the word's end
			a=${kak_selection_desc%%,*}
			al=${a%.*} ac=${a#*.} tl=${to%.*} tc=${to#*.}
			if [ "$tl" -gt "$al" ] || { [ "$tl" -eq "$al" ] && [ "$tc" -gt "$ac" ]; }; then
				echo "execute-keys <c-s>; select $a,$to; execute-keys E"
			else
				echo "execute-keys <c-s>; select $a,$to"
			fi
			exit
		done
	}
	set-option window jump_targets
}
define-command -override -hidden jump-labels-clear %{
	set-option window jump_labels %val{timestamp}
	set-option window jump_targets
}
map global normal <ret>   ': jump-labels<ret>'         -docstring 'jump to a word (labels)'
map global normal <s-ret> ': jump-labels -extend<ret>' -docstring 'extend to a word (labels)'

# --- explorer (<space>e, <space>E) ------------------------------------------------
# Helix's file explorer, as broot beside kak: in kakbr, its sidebar gets the
# focus (found out from the kakmux, as split-focus goes, by @outer_pane);
# elsewhere in tmux, broot opens in a split to the left, 25% of the window
# within 24..40 columns as kakbr's, at the buffer's workspace root (<space>e)
# or its file's directory (<space>E), or if one is open in this window
# already, that gets the focus. Files open in this kak: broot-open (Enter, and
# double-click through the opener dir put first on its PATH) finds the kak
# pane beside it. broot reads kakbr's broot.hjson (git on) when there is one.
# Under kakmux the split is weighted like the others (bin/kakmux-even).
define-command -override explorer -params ..1 -docstring "explorer [-buffer-dir]: broot beside kak at the workspace root (or the buffer's directory); in kakbr, its sidebar" %{
	evaluate-commands %sh{
		if [ -z "$kak_client_env_TMUX" ] || [ -z "$kak_client_env_TMUX_PANE" ]; then
			echo "fail 'explorer: needs tmux (:kakmux, kakbr)'"; exit
		fi
		socket=${kak_client_env_TMUX%%,*} pane=$kak_client_env_TMUX_PANE
		t() { tmux -S "$socket" "$@"; }
		s=$socket p=$pane
		while outer=$(tmux -S "$s" show-options -qv -t "$p" @outer_pane 2>/dev/null) && [ -n "$outer" ]; do
			s=${outer%% *} p=${outer#* }
			side=$(tmux -S "$s" show-options -wqv -t "$p" @kakbr_side 2>/dev/null)
			if [ -n "$side" ]; then
				tmux -S "$s" select-pane -t "$side" >/dev/null 2>&1; exit
			fi
		done
		ex=$(t list-panes -t "$pane" -F '#{pane_id} #{@kak_explorer}' 2>/dev/null | awk '$2 == 1 { print $1; exit }')
		if [ -n "$ex" ]; then t select-pane -t "$ex" >/dev/null 2>&1; exit; fi
		dir=${kak_opt_workspace_root:-$PWD}
		if [ "$1" = -buffer-dir ]; then
			case $kak_buffile in /*) dir=${kak_buffile%/*} ;; esac
		fi
		w=$(t display-message -p -t "$pane" '#{window_width}') || exit
		want=$((w / 4)); [ "$want" -lt 24 ] && want=24; [ "$want" -gt 40 ] && want=40
		case $socket in */kakmux-*)
			t set-option -w -t "$pane" @kakmux_ratio $((100 - want * 100 / w)) ;;
		esac
		conf=${XDG_CONFIG_HOME:-$HOME/.config}/kakbr/broot.hjson
		[ -e "$conf" ] || conf=
		id=$(t split-window -h -b -l "$want" -t "$pane" -c "$dir" -P -F '#{pane_id}' -- \
			env PATH="$HOME/.local/lib/broot-opener:$PATH" broot ${conf:+--conf "$conf"} "$dir" 2>/dev/null) || {
			t set-option -wu -t "$pane" @kakmux_ratio >/dev/null 2>&1
			echo "fail 'explorer: tmux split-window failed'"; exit
		}
		t set-option -p -t "$id" @kak_explorer 1 >/dev/null 2>&1
	}
}
map global user e ':explorer<ret>'             -docstring 'file explorer (workspace root)'
map global user E ':explorer -buffer-dir<ret>' -docstring "file explorer (buffer's directory)"
