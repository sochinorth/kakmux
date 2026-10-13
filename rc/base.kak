# rc/base.kak, sourced by kakrc: the first part: what the others share (the
# kakrc hook group's reset, kakrc_loaded, nl, each-client), the plugins
# (kak-tree-sitter, kakoune-lsp), the faces this config draws with, the
# colour scheme.

declare-option -hidden bool kakrc_loaded
# a newline, for shells: $kak_opt_nl (sh has no "\n", $(printf) is a
# process, and one typed into a string puts a line at column 1 in the
# middle of its block)
declare-option -hidden str nl '
'
remove-hooks global kakrc(-.*)?
# the first time only: evaluate-commands "kakrc-first-%opt{kakrc_loaded}"
define-command -override -hidden kakrc-first-false nop
# each-client COMMAND CLIENT...: COMMAND in each CLIENT, one at a time
# (without a shell: the rest, less the first, again)
declare-option -hidden str-list each_client_rest
define-command -override -hidden -params 2.. each-client %{
	evaluate-commands -client %arg{2} %arg{1}
	set-option global each_client_rest %arg{@}
	set-option -remove global each_client_rest %arg{1} %arg{2}
	try %{ evaluate-commands -verbatim each-client %arg{1} %opt{each_client_rest} }
}

# --- tree-sitter, LSP --------------------------------------------------------
# Helix's built-ins, here kak-tree-sitter (highlighting, text objects) and
# kakoune-lsp; see [editor.lsp] below. Both set default faces as they load,
# so they come before the colour scheme. Those defaults are kept in
# plugin_faces for :colorscheme to reset to, for schemes that don't set them
# (and for :config-reload, which doesn't load the plugins again).
declare-option -hidden str plugin_faces
declare-option -hidden str plugin_rc
# Both print their Kakoune scripts as they start. What's made of those here
# (the scripts, plugin_rc, the faces) is kept in $XDG_CACHE_HOME/kak, a file
# per plugin, made again once it's older than the plugin's binary, this
# kakrc or (kak-tree-sitter) its config, or was made for another binary:
# else startup sources it, rather than running them and going through their
# output in the shell (some 40 ms). kak-tree-sitter is still told of the
# session (its server started, for the first one): in the background, as it
# answers by kak -p anyway.
evaluate-commands %sh{
	[ "$kak_opt_kakrc_loaded" = true ] && exit
	cache=${XDG_CACHE_HOME:-$HOME/.cache}/kak
	# source FILE, kak-quoted (all in the shell, no other processes)
	src() {
		r= rest=$1 q=\'
		while :; do
			case $rest in
			*"$q"*) r="$r${rest%%"$q"*}$q$q" rest=${rest#*"$q"} ;;
			*) printf "source '%s'\n" "$r$rest"; return ;;
			esac
		done
	}
	# fresh FILE BIN [FILE...]: FILE is made for BIN, and newer than it
	# and the others
	fresh() {
		f=$1 bin=$2; shift 2
		[ -r "$f" ] || return 1
		IFS= read -r first < "$f" && [ "$first" = "# $bin" ] || return 1
		for dep in "$bin" "$@"; do [ "$f" -nt "$dep" ] || return 1; done
	}
	# keep FILE BIN: the script on stdin to FILE (headed with BIN), sourced;
	# or, if it can't be written, as it is
	keep() {
		tmp=$1.$$
		if mkdir -p "$cache" 2>/dev/null && { echo "# $2"; cat; } > "$tmp" && mv -f -- "$tmp" "$1"; then
			src "$1"
		else
			rm -f -- "$tmp"; cat
		fi
	}
	if kts=$(command -v kak-tree-sitter); then
		# Grammars are installed one language at a time (`ktsctl sync
		# rust`). kak-tree-sitter turns off Kakoune's highlighter for every
		# language it knows, grammar or not, so its config (written here,
		# whenever the set installed changes) leaves the others to Kakoune.
		data=${XDG_DATA_HOME:-$HOME/.local/share}/kak-tree-sitter
		conf=${XDG_CONFIG_HOME:-$HOME/.config}/kak-tree-sitter/config.toml
		have=
		for d in "$data"/queries/*/; do
			[ -d "$d" ] || continue
			d=${d%/}; have="$have ${d##*/}"
		done
		head=; [ -r "$conf" ] && IFS= read -r head < "$conf"
		if [ "$head" != "# installed:$have" ]; then
			mkdir -p "${conf%/*}" && {
				echo "# installed:$have"
				echo "# Written by kakrc from what's installed in $data: don't edit."
				ktsctl default-config |
					sed -n 's/^\[language\."\([^"]*\)".*/\1/p; s/^\[language\.\([^]."]*\).*/\1/p' |
					sort -u |
					while IFS= read -r l; do
						case "$have " in *" $l "*) continue ;; esac
						printf '\n[language."%s"]\nfiletype_hook = false\nremove_default_highlighter = false\n' "$l"
					done
			} > "$conf.tmp" && mv -f -- "$conf.tmp" "$conf"
			# a server already running (one serves all sessions) rereads it
			kak-tree-sitter -r "{ \"metadata\": { \"session\": \"$kak_session\" }, \"payload\": { \"type\": \"reload\" } }" >/dev/null 2>&1
		fi
		# its server (started by the first session), which this session joins
		f=$cache/plugin-kak-tree-sitter.kak
		if fresh "$f" "$kts" "$conf" "$kak_config/kakrc"; then
			kak-tree-sitter -dks --init "$kak_session" >/dev/null 2>&1 </dev/null &
			src "$f"
		elif rc=$(kak-tree-sitter -dks --init "$kak_session"); then
			{
				printf '%s\n' "$rc"
				# (kept for the command palette, which lists what it defines)
				printf "set-option -add global plugin_rc '%s\n'\n" "$(printf %s "$rc" | sed "s/'/''/g")"
				# ts_<scope> faces link to their parent scope's, some of which
				# it leaves undefined (ts_markup for ts_markup_bold, ...):
				# define those too
				faces= names=' '
				while IFS= read -r l; do
					case $l in 'set-face global ts_'*) ;; *) continue ;; esac
					faces="$faces$l$kak_opt_nl"
					l=${l#set-face global }; names="$names${l%% *} "
				done <<-EOF
					$rc
				EOF
				missing=$faces
				while [ -n "$missing" ]; do
					next=
					while IFS= read -r l; do
						[ -n "$l" ] || continue
						p=${l##* }
						case $names in *" $p "*) continue ;; esac
						case $p in ts_*) ;; *) continue ;; esac
						q=${p#ts_}
						case $q in *_*) q=ts_${q%_*} ;; *) q=default ;; esac
						names="$names$p "
						next="${next}set-face global $p $q$kak_opt_nl"
					done <<-EOF
						$missing
					EOF
					faces=$faces$next missing=$next
				done
				printf %s "$faces"
				printf "set-option -add global plugin_faces '%s'\n" "$faces"
			} | keep "$f" "$kts"
		fi
	fi
	if lsp=$(command -v kak-lsp); then
		f=$cache/plugin-kak-lsp.kak
		if fresh "$f" "$lsp" "$kak_config/kakrc"; then
			src "$f"
		# (kak-lsp started with $kak_session set is a server for it)
		elif rc=$(unset kak_session; kak-lsp); then
			{
				printf '%s\n' "$rc"
				printf "set-option -add global plugin_rc '%s\n'\n" "$(printf %s "$rc" | sed "s/'/''/g")"
				faces=
				while IFS= read -r l; do
					case $l in 'set-face global '*) faces="$faces$l$kak_opt_nl" ;; esac
				done <<-EOF
					$rc
				EOF
				printf "set-option -add global plugin_faces '%s'\n" "$faces"
			} | keep "$f" "$lsp"
		fi
	fi
}

# Faces this kakrc draws with, for colour schemes that don't set them: the
# hover/completion docs kak-lsp writes in markup, the status line's mode,
# git and diagnostic counts, the git gutter, the inline diagnostics' lines
# below the cursor's, the pickers' background (a linked
# face reads as default in the faces dump, so kak-picker falls back to
# MenuBackground's colour). Kept beside the plugins' defaults above.
declare-option -hidden str kakrc_faces
set-option global kakrc_faces %{
set-face global InfoDefault Information
set-face global InfoHeader +b@Information
set-face global InfoMono Information
set-face global InfoBlock Information
set-face global InfoBlockQuote +i@Information
set-face global InfoBullet Information
set-face global InfoLink +u@Information
set-face global InfoLinkMono +u@Information
set-face global InfoRule Information
set-face global InfoDiagnosticError red
set-face global InfoDiagnosticWarning yellow
set-face global InfoDiagnosticInformation blue
set-face global InfoDiagnosticHint green
set-face global StatusLineError red
set-face global StatusLineWarning yellow
set-face global StatusLineModeInsert StatusLineMode
set-face global StatusLineGit StatusLineInfo
set-face global StatusLineGitAdded green
set-face global StatusLineGitModified yellow
set-face global StatusLineGitUntracked StatusLine
set-face global JumpLabel +b@Error
set-face global GitGutterAdd green
set-face global GitGutterModify yellow
set-face global GitGutterDelete red
set-face global IndentGuide Whitespace
set-face global InlineDiagnosticDefault Default
set-face global InlineDiagnosticError InlayDiagnosticError
set-face global InlineDiagnosticWarning InlayDiagnosticWarning
set-face global InlineDiagnosticInfo InlayDiagnosticInfo
set-face global InlineDiagnosticHint InlayDiagnosticHint
set-face global IndentGuideActive +df@Default
set-face global PickerBackground MenuBackground
}
evaluate-commands %opt{plugin_faces}
evaluate-commands %opt{kakrc_faces}

# --- theme -------------------------------------------------------------------
# Kakoune ships no onedark; colors/onedark.kak is a port of Helix's, tree-sitter
# scopes and all. StatusLineInactive (see "inactive status lines" below) is set
# first so that colour schemes can override it. Sourced straight from here
# when it's there, as :colorscheme would find it (that looks for it with
# find(1) in a shell).
set-face global StatusLineInactive '+d@StatusLine'
try %{
	evaluate-commands "nop %%file{%val{config}/colors/onedark.kak}"
	source "%val{config}/colors/onedark.kak"
} catch %{
	colorscheme onedark
}
