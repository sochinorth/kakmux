# Port of dotfiles/config/helix/{config,languages}.toml. Lines that don't carry over
# are kept as comments saying why.

# Sourcing this again in a running session (:config-reload, Helix's, at the
# end) redoes it all with no errors and nothing twice: commands are
# redefined (-override), highlighters replaced (-override, so they keep
# their place), user modes made once, and every hook is in a kakrc group,
# all of them removed here before they're added again. Options keep their
# values (the state below: diagnostics, gutter flags, bufferline caches)
# unless declared with one, which only settings are. The plugins load
# once: kakrc_loaded, set at the end.
declare-option -hidden bool kakrc_loaded
remove-hooks global kakrc(-.*)?
# the first time only: evaluate-commands "kakrc-first-%opt{kakrc_loaded}"
define-command -override -hidden kakrc-first-false nop

# --- tree-sitter, LSP --------------------------------------------------------
# Helix's built-ins, here kak-tree-sitter (highlighting, text objects) and
# kakoune-lsp; see [editor.lsp] below. Both set default faces as they load,
# so they come before the colour scheme. Those defaults are kept in
# plugin_faces for :colorscheme to reset to, for schemes that don't set them
# (and for :config-reload, which doesn't load the plugins again).
declare-option -hidden str plugin_faces
declare-option -hidden str plugin_rc
evaluate-commands %sh{
	[ "$kak_opt_kakrc_loaded" = true ] && exit
	command -v kak-tree-sitter >/dev/null || exit
	# Grammars are installed one language at a time (`ktsctl sync rust`).
	# kak-tree-sitter turns off Kakoune's highlighter for every language it
	# knows, grammar or not, so its config (written here, whenever the set
	# installed changes) leaves the others to Kakoune.
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
	rc=$(kak-tree-sitter -dks --init "$kak_session") || exit
	printf '%s\n' "$rc"
	# (kept for the command palette, which lists what it defines)
	printf "set-option -add global plugin_rc '%s\n'\n" "$(printf %s "$rc" | sed "s/'/''/g")"
	# ts_<scope> faces link to their parent scope's, some of which it leaves
	# undefined (ts_markup for ts_markup_bold, ...): define those too
	faces= names=' '
	while IFS= read -r l; do
		case $l in 'set-face global ts_'*) ;; *) continue ;; esac
		faces="$faces$l
"
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
			next="${next}set-face global $p $q
"
		done <<-EOF
			$missing
		EOF
		faces=$faces$next missing=$next
	done
	printf %s "$faces"
	printf "set-option -add global plugin_faces '%s'\n" "$faces"
}
evaluate-commands %sh{
	[ "$kak_opt_kakrc_loaded" = true ] && exit
	command -v kak-lsp >/dev/null || exit
	rc=$(kak-lsp) || exit
	printf '%s\n' "$rc"
	printf "set-option -add global plugin_rc '%s\n'\n" "$(printf %s "$rc" | sed "s/'/''/g")"
	faces=
	while IFS= read -r l; do
		case $l in 'set-face global '*) faces="$faces$l
" ;; esac
	done <<-EOF
		$rc
	EOF
	printf "set-option -add global plugin_faces '%s'\n" "$faces"
}

# Faces this kakrc draws with, for colour schemes that don't set them: the
# hover/completion docs kak-lsp writes in markup, the status line's mode,
# git and diagnostic counts, the git gutter. Kept beside the plugins' defaults above.
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
set-face global IndentGuideActive +d@Default
}
evaluate-commands %opt{plugin_faces}
evaluate-commands %opt{kakrc_faces}

# --- theme -------------------------------------------------------------------
# Kakoune ships no onedark; colors/onedark.kak is a port of Helix's, tree-sitter
# scopes and all. StatusLineInactive (see "inactive status lines" below) is set
# first so that colour schemes can override it.
set-face global StatusLineInactive '+d@StatusLine'
colorscheme onedark

# --- [editor] ----------------------------------------------------------------
# bufferline = "multiple": drawn in tmux's status line, see the bufferline
# section below and ~/.local/bin/kakmux.
# preview-completion-insert = false: can't be had. False is Helix only
# showing the candidate picked in the menu until it's accepted; Kakoune's
# <c-n>/<c-p>, the only keys that pick one (Tab, Enter and arrows never do),
# put it in the text straight away, as Helix's true does. Ignore the menu
# and nothing gets inserted.

# No completion menu straight after entering insert mode, only once something
# has been typed in it (<c-x> still asks for one). autocomplete can't do this:
# insert mode reads it once, before its ModeChange hook runs. completers is
# read each time, so it's emptied (in the window) until the first character
# typed. Then the window's own value comes back, or if it had none, it's
# unset again, so global and buffer ones (lsp-disable) still count after.
# It had one if unsetting it changes what's in effect, compared without a
# shell: what's left after removing one from the other must be nothing both
# ways (insert-completers-none takes no arguments).
declare-option -hidden str-list insert_completers
declare-option -hidden bool insert_completers_own
declare-option -hidden str-list insert_completers_diff
define-command -override -hidden -params 0 insert-completers-none nop
define-command -override -hidden insert-completers-own-true nop
hook -group kakrc global ModeChange push:.*:insert %{
	set-option window insert_completers %opt{completers}
	unset-option window completers
	set-option window insert_completers_own true
	try %{
		set-option window insert_completers_diff %opt{insert_completers}
		set-option -remove window insert_completers_diff %opt{completers}
		evaluate-commands -verbatim insert-completers-none %opt{insert_completers_diff}
		set-option window insert_completers_diff %opt{completers}
		set-option -remove window insert_completers_diff %opt{insert_completers}
		evaluate-commands -verbatim insert-completers-none %opt{insert_completers_diff}
		set-option window insert_completers_own false
	}
	set-option window completers
	hook -once -group insert-completers window InsertChar .* insert-completers-restore
	hook -once -group insert-completers window ModeChange pop:insert:.* insert-completers-restore
}
define-command -override -hidden insert-completers-restore %{
	remove-hooks window insert-completers
	unset-option window completers
	try %{
		evaluate-commands "insert-completers-own-%opt{insert_completers_own}"
		set-option window completers %opt{insert_completers}
	}
}

# auto-save.focus-lost = true (needs a terminal that reports focus events):
# when the terminal is left. Under kakmux, moving between splits moves the
# focus between clients too, so there tmux says when its terminal is left
# (kakmux.conf's client-focus-out hook runs auto-save-all); elsewhere it's
# kak's FocusOut. A picker's tmux popup takes the focus too, but that isn't
# leaving the editor (see picker_clients below); under kakbr, moving to broot
# is. A write that fails (read-only file, gone directory) says so: why in
# *debug*, that it did in the focused client.
define-command -override -hidden auto-save-all %{
	try %{ write-all } catch %{
		echo -debug "auto-save: %val{error}"
		try %{
			evaluate-commands -client %opt{focused_client} %{
				echo -markup '{Error}auto-save failed (see *debug*)'
			}
		}
	}
}
hook -group kakrc global FocusOut .* %{
	evaluate-commands %sh{
		case ${kak_client_env_TMUX%%,*} in */kakmux-*) exit ;; esac
		eval set -- "$kak_quoted_opt_picker_clients"
		for c; do [ "$c" = "$kak_client" ] && exit; done
		echo auto-save-all
	}
}

# indent-guides.render = true: see indent guides below (neither tabs nor
# show-whitespaces' own unscoped guides are drawn here). Named, so a change
# replaces it; the unnamed one an earlier kakrc added (tabs drawn as │)
# goes on reload.
try %{ remove-highlighter "global/show-whitespaces_-tab_│_-tabpad_ _-spc_ _-lf_ _-nbsp_⍽" }
add-highlighter -override global/whitespace show-whitespaces -tab ' ' -tabpad ' ' -spc ' ' -lf ' ' -nbsp '⍽' -indent ''

# soft-wrap.enable = true, wrap-indicator = "↪ " (named, see whitespace
# above: the unnamed one an earlier kakrc added goes)
try %{ remove-highlighter global/wrap_-word_-indent }
add-highlighter -override global/wrap wrap -word -indent -marker '↪ '

# scrolloff = 5 (lines; Kakoune's second number, columns, 0)
set-option global scrolloff 5,0

# Kakoune's own: Clippy (the assistant drawn beside info boxes) unless
# disable_clippy, Kakoune's spelling of ui_options' terminal_assistant=none
declare-option -docstring 'no Clippy beside info boxes (ui_options terminal_assistant)' \
	bool disable_clippy false
define-command -override -hidden clippy-false %{ set-option -add global ui_options terminal_assistant=clippy }
define-command -override -hidden clippy-true %{ set-option -add global ui_options terminal_assistant=none }
hook -group kakrc global GlobalSetOption disable_clippy=.* %{ evaluate-commands "clippy-%opt{disable_clippy}" }
evaluate-commands "clippy-%opt{disable_clippy}"

# Like Helix, opening a file over the blank startup *scratch* replaces it
# rather than leaving it behind (:e, pickers, anything that switches buffer).
# A *scratch* with anything in it, and edit -scratch buffers, are left alone,
# and so is one another client (another split) still shows: it goes once
# that one moves off it too.
# (Kakoune's regex lookarounds can't hold $, hence no anchor.)
define-command -override -hidden fail-if-on-scratch %{
	evaluate-commands %sh{ [ "$kak_bufname" = '*scratch*' ] && echo fail }
}
hook -group kakrc global WinDisplay (?!\*scratch\*).* %{
	try %{
		evaluate-commands -buffer *scratch* %{ execute-keys '%<a-k>\A\s*\z<ret>' }
		evaluate-commands %sh{
			eval set -- "$kak_quoted_client_list"
			for c; do
				printf "evaluate-commands -client '%s' fail-if-on-scratch\n" "$(printf %s "$c" | sed "s/'/''/g")"
			done
		}
		delete-buffer *scratch*
	}
}

# Helix's quit-all family. kill ends the session: every client, so in
# kakmux every split, and refuses while buffers have unsaved changes.
alias global qa       kill
alias global quit-all kill
alias global qa!      kill!
define-command -override write-quit-all -docstring 'write all buffers, then quit all clients' %{
	write-all
	kill
}
define-command -override -hidden write-quit-all-force %{
	write-all
	kill!
}
alias global wqa  write-quit-all
alias global xa   write-quit-all
alias global wqa! write-quit-all-force
alias global xa!  write-quit-all-force
alias global x    write-quit
alias global x!   write-quit!

# Inactive status lines, like Helix: a client whose terminal (its kakmux
# split) doesn't have focus draws its status line in StatusLineInactive. That
# defaults to the status line dimmed; colour schemes may set their own.
# Add to statusline_faces any face a custom modelinefmt uses.
declare-option str-list statusline_faces StatusLine StatusLineMode StatusLineInfo StatusLineValue StatusCursor StatusLineError StatusLineWarning StatusLineModeInsert StatusLineGit StatusLineGitAdded StatusLineGitModified StatusLineGitUntracked
declare-option -hidden str-list unfocused_clients

# faces live per window (client + buffer), so reapply on every buffer switch.
# Without a shell when there's nothing to do: the client isn't unfocused
# (removing the unfocused ones from it leaves one name: statusline-one takes
# one argument) and its window isn't dimmed, or the other way round.
declare-option -hidden bool statusline_dimmed false
declare-option -hidden str-list statusline_cmp
define-command -override -hidden -params 1 statusline-one nop
define-command -override -hidden -params 0 statusline-none nop
define-command -override -hidden statusline-dimmed-false nop
define-command -override -hidden statusline-dimmed-true-unfocused nop
define-command -override -hidden statusline-apply-focus %{
	try %{
		set-option window statusline_cmp %val{client}
		set-option -remove window statusline_cmp %opt{unfocused_clients}
		try %{
			evaluate-commands -verbatim statusline-one %opt{statusline_cmp}
			evaluate-commands "statusline-dimmed-%opt{statusline_dimmed}"
		} catch %{
			# or unfocused, dimmed already, and no picker popup of its own
			evaluate-commands -verbatim statusline-none %opt{statusline_cmp}
			evaluate-commands "statusline-dimmed-%opt{statusline_dimmed}-unfocused"
			set-option window statusline_cmp %val{client}
			set-option -remove window statusline_cmp %opt{picker_clients}
			evaluate-commands -verbatim statusline-one %opt{statusline_cmp}
		}
	} catch %{ evaluate-commands %sh{
		eval set -- "$kak_quoted_opt_unfocused_clients"
		dim=; for c; do [ "$c" = "$kak_client" ] && dim=1; done
		# its own picker popup having the focus doesn't count
		eval set -- "$kak_quoted_opt_picker_clients"
		for c; do [ "$c" = "$kak_client" ] && dim=; done
		eval set -- "$kak_quoted_opt_statusline_faces"
		for f; do
			if [ -n "$dim" ]; then
				echo "set-face window $f StatusLineInactive"
			else
				echo "try %{ unset-face window $f }"
			fi
		done
		if [ -n "$dim" ]; then echo 'set-option window statusline_dimmed true'
		else echo 'set-option window statusline_dimmed false'; fi
	} }
}
hook -group kakrc global FocusOut .* %{
	set-option -remove global unfocused_clients %val{client}
	set-option -add global unfocused_clients %val{client}
	statusline-apply-focus
}
hook -group kakrc global FocusIn .* %{
	set-option -remove global unfocused_clients %val{client}
	statusline-apply-focus
}
hook -group kakrc global WinDisplay .* statusline-apply-focus
hook -group kakrc global ClientClose .* %{ set-option -remove global unfocused_clients %val{hook_param} }

# --- status line ---------------------------------------------------------------
# Helix's, as far as Kakoune's (drawn right-aligned, after any message) goes:
#     INS  ⎇ main +1 ~2 ?1 │ src/point.c [+] │ ● 1 ● 3 │ ⣾ │ 3 sels │ 12:4
# each part only when there's something to show: the mode unless normal,
# the workspace's git branch (a short hash when detached) and its files
# staged/modified/untracked, the file from the workspace root, unsaved
# changes, warnings and errors (kak-lsp's counts, see inline diagnostics),
# language server progress, selections when more than one, the cursor.
# All of it is options set by hooks, none of it worked out as it's drawn:
# the git part in the background as the gutter locates the buffer (first
# shown, saved, focused: see git gutter), the rest without a shell. Set
# once; :config-reload leaves it as it is.
declare-option -hidden str modeline_ins
declare-option -hidden str modeline_mode
declare-option -hidden str modeline_sels
declare-option -hidden str modeline_modified
declare-option -hidden str modeline_lsp_sep
declare-option -hidden str workspace_bufname
declare-option -hidden str git_branch
declare-option -hidden str git_staged
declare-option -hidden str git_modified
declare-option -hidden str git_untracked
declare-option -hidden str git_sep
declare-option -hidden str lsp_diag_sep
# (kak-lsp's, should it not be there)
declare-option -hidden str lsp_modeline_progress
declare-option -hidden str lsp_modeline_message_requests
try %{
	evaluate-commands "kakrc-first-%opt{kakrc_loaded}"
	set-option global modelinefmt %{{StatusLineModeInsert}%opt{modeline_ins}{StatusLineMode}%opt{modeline_mode}{StatusLineGit}%opt{git_branch}{StatusLineGitAdded}%opt{git_staged}{StatusLineGitModified}%opt{git_modified}{StatusLineGitUntracked}%opt{git_untracked}{StatusLine}%opt{git_sep} %opt{workspace_bufname}%opt{modeline_modified}%opt{lsp_diag_sep}{StatusLineWarning}%opt{lsp_diag_warnings}{StatusLineError}%opt{lsp_diag_errors}{StatusLine}%opt{modeline_lsp_sep}{StatusLineInfo}%opt{lsp_modeline_progress}%opt{lsp_modeline_message_requests}{StatusLine}%opt{modeline_sels} │ %val{cursor_line}:%val{cursor_char_column} - %val{client}@[%val{session}]}
}

# The mode, Helix's colours: insert, and the menus Kakoune names (a user
# mode's own name isn't known: <space>, <c-w>, m... are all "user"). Prompts
# aren't named: the prompt shows at the left of the same line.
hook -group kakrc global ModeChange (push|pop):.*:normal %{
	set-option window modeline_ins ''
	set-option window modeline_mode ''
}
hook -group kakrc global ModeChange (push|pop):.*:insert %{ set-option window modeline_ins ' INS ' }
hook -group kakrc global ModeChange (push|pop):.*:next-key\[user-mapping\] %{ set-option window modeline_mode ' USER ' }
hook -group kakrc global ModeChange (push|pop):.*:next-key\[goto\] %{ set-option window modeline_mode ' GOTO ' }
hook -group kakrc global ModeChange (push|pop):.*:next-key\[view\] %{ set-option window modeline_mode ' VIEW ' }
hook -group kakrc global ModeChange (push|pop):.*:next-key\[object\] %{ set-option window modeline_mode ' OBJECT ' }

# Unsaved changes and the selection count, whenever keys stop (and as a
# window shows, a buffer is written): a command per value, no shell.
define-command -override -hidden modeline-modified-true %{ set-option buffer modeline_modified ' [+]' }
define-command -override -hidden modeline-modified-false %{ set-option buffer modeline_modified '' }
define-command -override -hidden modeline-sels-1 %{ set-option window modeline_sels '' }
define-command -override -hidden modeline-idle %{
	evaluate-commands "modeline-modified-%val{modified}"
	try %{ evaluate-commands "modeline-sels-%val{selection_count}" } catch %{
		set-option window modeline_sels " │ %val{selection_count} sels"
	}
}
hook -group kakrc global NormalIdle .* modeline-idle
hook -group kakrc global InsertIdle .* %{ evaluate-commands "modeline-modified-%val{modified}" }
hook -group kakrc global WinDisplay .* modeline-idle
hook -group kakrc global BufWritePost .* modeline-modified-false
# language server progress (kak-lsp's spinner, global)
hook -group kakrc global GlobalSetOption lsp_modeline_progress= %{ set-option global modeline_lsp_sep '' }
hook -group kakrc global GlobalSetOption lsp_modeline_progress=.+ %{ set-option global modeline_lsp_sep ' │ ' }

# git-status-set ROOT BRANCH STAGED MODIFIED UNTRACKED: from the background
# git status (git-gutter-locate), for every buffer of the workspace ROOT
# (its root, less ROOT, is nothing: git-status-none takes no arguments)
declare-option -hidden str-list git_status_cmp
define-command -override -hidden -params 0 git-status-none nop
define-command -override -hidden -params 5 git-status-set %{
	evaluate-commands -buffer * %{
		set-option buffer git_status_cmp %opt{workspace_root}
		set-option -remove buffer git_status_cmp %arg{1}
		try %{
			evaluate-commands -verbatim git-status-none %opt{git_status_cmp}
			set-option buffer git_branch %arg{2}
			set-option buffer git_staged %arg{3}
			set-option buffer git_modified %arg{4}
			set-option buffer git_untracked %arg{5}
			set-option buffer git_sep ' │'
		}
	}
}

# Under kakmux every split is a client of the same session, so the default
# status line's " - client@[session]" tail is just noise there: strip it from
# the global modelinefmt, once, when the first kakmux client connects (a
# session in kakmux has only those). A no-op once the format is customised.
hook -group kakrc-modeline-kakmux global ClientCreate .* %{
	evaluate-commands %sh{
		case ${kak_client_env_TMUX%%,*} in */kakmux-*) ;; *) exit ;; esac
		echo 'remove-hooks global kakrc-modeline-kakmux'
		fmt=$(printf %s "$kak_opt_modelinefmt" | sed 's/ - %val{client}@\[%val{session}\]$//')
		[ "$fmt" = "$kak_opt_modelinefmt" ] && exit
		printf "set-option global modelinefmt '%s'\n" "$(printf %s "$fmt" | sed "s/'/''/g")"
	}
}

# Helix defaults that Kakoune doesn't turn on by itself. The gutter's columns
# go right to left in the order they're added: the git gutter (see below)
# right of the line numbers, diagnostics (kak-lsp, later) left of them.
declare-option -hidden line-specs git_gutter_flags
add-highlighter -override global/git-gutter flag-lines Default git_gutter_flags
add-highlighter -override global/ number-lines -hlcursor
add-highlighter -override global/ show-matching

# --- [editor.lsp] / diagnostics -----------------------------------------------
# kakoune-lsp (loaded at the top), for every filetype it has a server for:
# its lsp_servers hooks (in kak-lsp's servers.kak) pick the server, which must
# be installed (C/C++: clangd; sh: bash-language-server; markdown: marksman).
try %{
	# (enabled already when this runs again: then only make sure kak-lsp is
	# there; its options are)
	try %{ lsp-enable } catch %{ nop %opt{lsp_snippet_support} }
	# lsp.snippets = false
	set-option global lsp_snippet_support false
	# Helix defaults: signature help while typing a call's arguments, and
	# no code-action indicator (kak-lsp's 💡 in the modeline, which asks the
	# server for actions whenever keys stop)
	lsp-auto-signature-help-disable
	lsp-auto-signature-help-enable
	set-option global lsp_auto_show_code_actions false
	# end-of-line-diagnostics: every severity, not just warnings and up
	# (kak-lsp can't filter them); like Helix, the worst one's message two
	# spaces after the line, no mark per diagnostic. Drawn by the inline
	# diagnostics below (which leave out the cursor's line), not kak-lsp.
	set-option global lsp_inlay_diagnostic_sign ''
	set-option global lsp_inlay_diagnostic_gap ' '
	# lsp.display-progress-messages: progress (and pending server messages)
	# in the status line (see "status line" above). Not the rest of kak-lsp's
	# modeline: no breadcrumbs (Helix has none, and they're a request
	# whenever keys stop).
	remove-hooks global lsp-breadcrumbs
	# Helix's gutter mark, coloured by severity
	set-option global lsp_diagnostic_line_error_sign   '●'
	set-option global lsp_diagnostic_line_warning_sign '●'
	set-option global lsp_diagnostic_line_info_sign    '●'
	set-option global lsp_diagnostic_line_hint_sign    '●'
	# Helix's keys: g d/D/y/r/i, ]d [d (see [ ] below), <space> k/r/a/h (and
	# s/S/d/D: pickers). gi is Kakoune's first non-blank, which moves to gs
	# (see goto mode below).
	map global goto d '<esc>:lsp-definition<ret>'      -docstring 'definition (LSP)'
	map global goto D '<esc>:lsp-declaration<ret>'     -docstring 'declaration (LSP)'
	map global goto y '<esc>:lsp-type-definition<ret>' -docstring 'type definition (LSP)'
	map global goto r '<esc>:lsp-references<ret>'      -docstring 'references (LSP)'
	map global goto i '<esc>:lsp-implementation<ret>'  -docstring 'implementation (LSP)'
	# a diagnostic as an object: ]]d [[d select to the next/previous one,
	# shift-] shift-[ d extend to it (]d [d jump: see [ and ] below)
	map global object d '<a-;>lsp-diagnostic-object error warning info hint<ret>' -docstring 'diagnostic (LSP)'
	map global user k ':lsp-hover<ret>'                -docstring 'hover (LSP)'
	map global user r ':lsp-rename-prompt<ret>'        -docstring 'rename (LSP)'
	map global user a ':lsp-code-actions<ret>'         -docstring 'code actions (LSP)'
	map global user h ':lsp-highlight-references<ret>' -docstring 'highlight references (LSP)'
	map global user l ':enter-user-mode lsp<ret>'      -docstring 'LSP mode (everything else)'
}

# --- rename, code actions: edits across files --------------------------------
# Helix applies a rename (or a code action's edit) to every file it touches
# as a modified buffer: nothing reaches the disk before :w/:wa, and u in each
# buffer takes it back. kak-lsp (21.0.2, no setting for it) does that only
# in the buffer it was asked from: other open buffers it edits and then
# writes (unless they had unsaved changes already), and files that aren't
# open it edits on disk itself, behind Kakoune's back. A rename from main.c
# would leave point.c and point.h renamed on disk, for good, and main.c not.
# So here, first, the files the edit may touch are opened (as buffers, out
# of sight: for a rename, the project's files that have the old name as a
# word, git grep, or the buffer's directory outside git; for a code
# action's edit, the files it names). Then, while the edit goes in, the
# write that follows it in each buffer is held: a one-time buffer alias of
# write to lsp-edit-hold, set as kak-lsp tells the server about the edited
# buffer (lsp-did-change, wrapped below), which it does just before. Once
# all of it is in, the buffers opened for nothing are closed again, and
# the client says "renamed: N edits in M files". A code action that runs a
# server command (clangd's tweaks) only says which files when the server
# sends the edit: open buffers are held all the same, files not open still
# get written by kak-lsp.
declare-option -hidden str lsp_edit_armed
declare-option -hidden str lsp_edit_what
declare-option -hidden str lsp_edit_client
declare-option -hidden str lsp_edit_from
declare-option -hidden int lsp_edit_seq
declare-option -hidden int lsp_edit_count
# buffiles: opened for this edit, and edited by it
declare-option -hidden str-list lsp_edit_opened
declare-option -hidden str-list lsp_edit_touched

# lsp-edit-arm WHAT: the next edit (until it's in, or 20s without one) is
# held. The edit's buffers make the client run lsp-edit-done once it's all
# in; the timer, in case it never comes (no edit, an error).
define-command -override -hidden -params 1 lsp-edit-arm %{
	try %{ lsp-edit-finish }
	set-option global lsp_edit_armed yes
	set-option global lsp_edit_what %arg{1}
	set-option global lsp_edit_client %val{client}
	set-option global lsp_edit_from %val{buffile}
	set-option global lsp_edit_count 0
	set-option global lsp_edit_opened
	set-option global lsp_edit_touched
	set-option -add global lsp_edit_seq 1
	nop %sh{
		(sleep 20; printf 'lsp-edit-done %s\n' "$kak_opt_lsp_edit_seq" | kak -p "$kak_session") >/dev/null 2>&1 </dev/null &
	}
}
# lsp-edit-open FILE: a buffer for FILE, opened out of sight (kak-lsp's
# BufCreate hook hands it to the server) unless there's one
define-command -override -hidden -params 1 lsp-edit-open %{
	try %{ evaluate-commands -buffer %arg{1} nop } catch %{
		evaluate-commands -draft %{ edit -existing -- %arg{1} }
		set-option -add global lsp_edit_opened %arg{1}
	}
}

# kak-lsp's lsp-did-change (21.0.2), and while armed, outside hooks
# (InsertIdle's while typing), that's an edit gone in. No shell otherwise.
define-command -override -hidden lsp-did-change -docstring 'Notify language server about buffer change' %{
	try %{ nop %val{hook_param} } catch %{
		evaluate-commands "lsp-edit-touched-%opt{lsp_edit_armed}"
	}
	lsp-unless-blocked lsp-if-changed-since lsp_timestamp %opt{lsp_timestamp} %{
		lsp-send-buffer textDocument/didChange
	}
}
define-command -override -hidden lsp-edit-touched- nop
# an edit has gone into this buffer: hold its write, count it (Kakoune's
# list of changes not yet in the undo history: a replacement is a deletion
# and its text typed after it, an insertion text typed from a place before
# the last one: kak-lsp goes from the end of the buffer up), and the first
# one has the client finish once the rest is in (a command sent now runs
# after the one kak-lsp sent)
define-command -override -hidden lsp-edit-touched-yes %{
	alias buffer write lsp-edit-hold
	evaluate-commands %sh{
		n=0 pl=-1 pc=-1 prev=
		eval set -- "$kak_quoted_uncommitted_modifications"
		for m; do
			p=${m%%|*} p=${p#?}
			l=${p%.*} c=${p#*.}
			case $m in
			-*) n=$((n + 1)) prev=- ;;
			+*)
				if [ "$prev" != - ] && { [ "$l" -lt "$pl" ] || { [ "$l" -eq "$pl" ] && [ "$c" -le "$pc" ]; } || [ "$pl" -lt 0 ]; }; then
					n=$((n + 1))
				fi
				prev=+ ;;
			esac
			pl=$l pc=$c
		done
		echo "set-option -add global lsp_edit_count $n"
		if [ -z "$kak_opt_lsp_edit_touched" ]; then
			(printf 'lsp-edit-done %s\n' "$kak_opt_lsp_edit_seq" | kak -p "$kak_session") >/dev/null 2>&1 </dev/null &
		fi
	}
	set-option -remove global lsp_edit_touched %val{buffile}
	set-option -add global lsp_edit_touched %val{buffile}
}
# kak-lsp's write after its edit; a write with arguments goes through,
# the hold kept (kak-lsp's own write -force to its fifo, with the buffer
# for the server)
define-command -override -hidden -params .. lsp-edit-hold %{
	unalias buffer write lsp-edit-hold
	evaluate-commands %sh{
		[ $# -gt 0 ] || exit
		echo 'try %{ write %arg{@} } catch %{ alias buffer write lsp-edit-hold; fail -- %val{error} }'
		echo 'alias buffer write lsp-edit-hold'
	}
}

# lsp-edit-done SEQ: from the edit, or the timer; only for the latest arm
define-command -override -hidden -params 1 lsp-edit-done %{
	evaluate-commands %sh{
		[ "$kak_opt_lsp_edit_armed" = yes ] && [ "$1" = "$kak_opt_lsp_edit_seq" ] && echo lsp-edit-finish
	}
}
define-command -override -hidden lsp-edit-finish %{
	set-option global lsp_edit_armed ''
	evaluate-commands %sh{
		nl='
'
		# holds left (in the buffer asked from, and ones that had unsaved
		# changes, kak-lsp writes nothing), and the buffers to reopen in
		# the server once written (below); buffers opened for nothing
		eval set -- "$kak_quoted_opt_lsp_edit_touched"
		m=$# touched= other=
		[ $# -gt 0 ] && echo 'evaluate-commands -buffer * %{ unset-option buffer lsp_edit_unsaved }'
		for f; do
			touched=$touched$nl$f
			[ "$f" = "$kak_opt_lsp_edit_from" ] || other=1
			printf "evaluate-commands -buffer '%s' %%{ try %%{ unalias buffer write lsp-edit-hold }; set-option buffer lsp_edit_unsaved yes }\n" \
				"$(printf %s "$f" | sed "s/'/''/g")"
		done
		[ $# -gt 0 ] && echo "set-option global lsp_edit_unsaved_n $m; set-option global lsp_edit_reopen %opt{lsp_edit_touched}"
		eval set -- "$kak_quoted_opt_lsp_edit_opened"
		for f; do
			case $touched$nl in *"$nl$f$nl"*) continue ;; esac
			printf "try %%{ delete-buffer '%s' }\n" "$(printf %s "$f" | sed "s/'/''/g")"
		done
		echo 'set-option global lsp_edit_opened; set-option global lsp_edit_touched'
		[ "$m" -gt 0 ] || exit
		n=$kak_opt_lsp_edit_count
		[ "$n" -eq 1 ] && e=edit || e=edits
		[ "$m" -eq 1 ] && f=file || f=files
		[ -n "$other" ] && w=' (unsaved: :wa writes them)' || w=
		printf "try %%{ evaluate-commands -client '%s' %%{ echo -markup '{Information}%s: %s %s in %s %s%s' } }\n" \
			"$(printf %s "$kak_opt_lsp_edit_client" | sed "s/'/''/g")" "$kak_opt_lsp_edit_what" "$n" "$e" "$m" "$f" "$w"
	}
}

# Once they're all written, the server reads the edited files afresh.
# clangd builds each file with the others as they are on disk, not as
# buffers, and kak-lsp doesn't tell it of saves (only servers that want the
# text get told): main.c would keep its errors about the old name from
# point.h until next edited. So once the last of them is written, the
# edited buffers are closed and reopened in the server (not in Kakoune).
# No shell for other writes.
declare-option -hidden str lsp_edit_unsaved
declare-option -hidden int lsp_edit_unsaved_n
declare-option -hidden str-list lsp_edit_reopen
hook -group kakrc global BufWritePost .* %{
	evaluate-commands "lsp-edit-written-%opt{lsp_edit_unsaved}"
}
define-command -override -hidden lsp-edit-written- nop
define-command -override -hidden lsp-edit-written-yes %{
	unset-option buffer lsp_edit_unsaved
	set-option -remove global lsp_edit_unsaved_n 1
	try %{ evaluate-commands "lsp-edit-reopen-%opt{lsp_edit_unsaved_n}" }
}
define-command -override -hidden lsp-edit-reopen-0 %{
	evaluate-commands %sh{
		eval set -- "$kak_quoted_opt_lsp_edit_reopen"
		for f; do
			printf "try %%{ evaluate-commands -buffer '%s' %%{ lsp-did-close; lsp-did-open } }\n" \
				"$(printf %s "$f" | sed "s/'/''/g")"
		done
		echo 'set-option global lsp_edit_reopen'
	}
}

# kak-lsp's lsp-rename, the files with the old name opened first
define-command -override lsp-rename -params 1 -docstring 'lsp-rename <new-name>: rename symbol under the main cursor' %{
	lsp-edit-arm renamed
	try %{
		evaluate-commands -draft %{
			execute-keys ,<semicolon><a-i>w
			lsp-edit-open-word %val{selection}
		}
	}
	lsp-send textDocument/rename %val{cursor_line} %val{cursor_column} %arg{1}
}
define-command -override -hidden -params 1 lsp-edit-open-word %{
	evaluate-commands %sh{
		case $kak_buffile in /*) ;; *) exit ;; esac
		dir=${kak_buffile%/*}
		if root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null); then
			git -C "$root" -c core.quotePath=false grep -lwIF --untracked -e "$1" 2>/dev/null |
				while IFS= read -r f; do printf '%s/%s\n' "$root" "$f"; done
		else
			grep -lwIF -e "$1" -- "$dir"/* 2>/dev/null
		fi | head -n 200 | sed "s/'/''/g; s/.*/lsp-edit-open '&'/"
	}
}

# kak-lsp's, the code action's edit held, and its files opened first
define-command -override -hidden lsp-apply-workspace-edit-request -params 2 %{
	lsp-edit-arm applied
	evaluate-commands %sh{
		# its files' URIs, %-escapes undone
		printf %s "$2" | grep -o '"file://[^"]*"' | sort -u | LC_ALL=C awk '
			BEGIN { for (i = 0; i < 256; i++) hex[sprintf("%02x", i)] = sprintf("%c", i) }
			{
				s = substr($0, 9, length($0) - 9); out = ""
				while ((i = index(s, "%")) > 0) {
					out = out substr(s, 1, i - 1) hex[tolower(substr(s, i + 1, 2))]
					s = substr(s, i + 3)
				}
				out = out s; gsub(/'\''/, "'\'''\''", out)
				print "lsp-edit-open '\''" out "'\''"
			}'
	}
	lsp-send apply-workspace-edit %arg{1} %arg{2}
}
# kak-lsp's, the edit the server sends back (if any) held
define-command -override -hidden lsp-execute-command-request -params 3..4 %{
	lsp-edit-arm applied
	lsp-send workspace/executeCommand %arg{1} %arg{2} %arg{3} %arg{4}
}
# --- inline diagnostics ------------------------------------------------------
# inline-diagnostics.cursor-line = "warning": the diagnostics on the cursor's
# line, each under the column it starts at, as lines below it:
#     foo(old, &tmp);
#         │     └─Use of undeclared identifier 'tmp'
#         └─Use of undeclared identifier 'old'
# kak-lsp only hands Kakoune each line's worst message, so whenever the
# diagnostics change (or, for a buffer not shown then, once it is) this
# asks it for the list :lsp-diagnostics shows, catching it before it opens
# that buffer (lsp-show-goto-buffer, wrapped below), and keeps this file's
# part in line_diags. The end-of-line messages are drawn here too, from
# kak-lsp's, less the cursor line's when it has lines below. Kakoune doesn't
# wrap those (flag-lines -after): one longer than the room left, as after a
# soft-wrapped line, is cut at the window's edge. Leaving them out on lines
# that wrap would need each line's width on screen, so they stay.

declare-option -docstring 'severities shown below the cursor''s line' \
	str-list inline_diagnostics_severities error warning
# buffer: "line|column|severity|message" (byte column, as Kakoune counts),
# and whether that's behind kak-lsp's (stale, or '')
declare-option -hidden str-list line_diags
declare-option -hidden int line_diags_n 0
declare-option -hidden str line_diags_state
# window: what's drawn, whether lines below are, for which cursor line
declare-option -hidden range-specs line_diags_view
declare-option -hidden line-specs line_diags_eol
declare-option -hidden int line_diags_drawn 0
declare-option -hidden int line_diags_seen 0
# the lists asked for and not back yet, as "client=bufname", one per list:
# kak-lsp answers in the client that asked, whatever buffer it shows by then
declare-option -hidden str-list line_diags_pending
declare-option -hidden str-list line_diags_dcols
declare-option -hidden int line_diags_eolcol
add-highlighter -override global/line-diags replace-ranges line_diags_view
add-highlighter -override global/line-diags-eol flag-lines -after Default line_diags_eol

# Helix's status line diagnostics: a coloured ● and the count, warnings
# then errors, each only when there are some. Set as kak-lsp publishes;
# the colours are in modelinefmt (markup in an option's value isn't read).
declare-option -hidden str lsp_diag_warnings
declare-option -hidden str lsp_diag_errors

# kak-lsp publishes into the buffer: the counts for the modeline, and the
# list is due. Each client showing it asks for it now; one that shows it
# later does then (WinDisplay, below).
hook -group kakrc global BufSetOption lsp_inlay_diagnostics=.* %{
	set-option buffer line_diags_state stale
	evaluate-commands %sh{
		w=$kak_opt_lsp_diagnostic_warning_count e=$kak_opt_lsp_diagnostic_error_count
		[ "${w:-0}" -gt 0 ] && w=" ● $w" || w=
		[ "${e:-0}" -gt 0 ] && e=" ● $e" || e=
		s=; [ -n "$w$e" ] && s=' │'
		printf '%s\n' "set-option buffer lsp_diag_warnings '$w'; set-option buffer lsp_diag_errors '$e'; set-option buffer lsp_diag_sep '$s'"
		double() {
			r= rest=$2
			while :; do
				case $rest in
				*"$1"*) r="$r${rest%%"$1"*}$1$1" rest=${rest#*"$1"} ;;
				*) r=$r$rest; return ;;
				esac
			done
		}
		eval set -- "$kak_quoted_client_list"
		for c; do
			double "'" "$c"
			printf "evaluate-commands -client '%s' line-diags-request\n" "$r"
		done
	}
}
# in a client: ask for the list if its buffer's is stale (whichever buffer
# that is: only one just published, or one never asked for, is). No shell.
define-command -override -hidden line-diags-stale-stale nop
define-command -override -hidden line-diags-request %{
	try %{
		evaluate-commands "line-diags-stale-%opt{line_diags_state}"
		set-option -add global line_diags_pending "%val{client}=%val{bufname}"
		try %{ lsp-diagnostics } catch %{
			set-option -remove global line_diags_pending "%val{client}=%val{bufname}"
			set-option buffer line_diags_state ''
		}
	}
}
hook -group kakrc global WinDisplay .* line-diags-request
# a client gone, its lists will never come (nor the pickers', below)
hook -group kakrc global ClientClose .* %{
	evaluate-commands %sh{
		eval set -- "$kak_quoted_opt_line_diags_pending" "$kak_quoted_opt_picker_only"
		for e; do
			case $e in "$kak_hook_param="*)
				e=$(printf %s "$e" | sed "s/'/''/g")
				printf '%s\n' "set-option -remove global line_diags_pending '$e'; set-option -remove global picker_only '$e'" ;;
			esac
		done
	}
}

# Where every kak-lsp list ends up (references, symbols, diagnostics, calls:
# `path:line:column:text` lines): a list asked for above is caught, or
# dropped if this client has moved to another buffer since (that one stays
# stale, so asks again when shown); one a workspace symbol picker asked for
# goes to it; the rest open in a picker (with tmux; else in kak-lsp's
# buffer, as before).
define-command -override -hidden lsp-show-goto-buffer -params 4..5 %{
	evaluate-commands %sh{
		double() {
			r= rest=$2
			while :; do
				case $rest in
				*"$1"*) r="$r${rest%%"$1"*}$1$1" rest=${rest#*"$1"} ;;
				*) r=$r$rest; return ;;
				esac
			done
		}
		title=$1
		if [ "$title" = '*diagnostics*' ] && [ -n "$kak_opt_line_diags_pending" ]; then
			# take off one entry: this buffer's, else any of this client's
			eval set -- "$kak_quoted_opt_line_diags_pending"
			mine=$kak_client=$kak_bufname take=
			for e; do [ "$e" = "$mine" ] && take=$e; done
			if [ -z "$take" ]; then
				for e; do case $e in "$kak_client="*) take=$e; break ;; esac; done
			fi
			if [ -n "$take" ]; then
				keep= done=
				for e; do
					if [ -z "$done" ] && [ "$e" = "$take" ]; then done=1; continue; fi
					double "'" "$e"; keep="$keep '$r'"
				done
				printf '%s\n' "set-option global line_diags_pending$keep"
				[ "$take" = "$mine" ] && echo 'line-diags-capture %arg{3} %arg{4}'
				exit
			fi
		fi
		if [ "$title" = '*symbols*' ] && [ -n "$kak_opt_picker_wsym_out" ]; then
			echo 'picker-wsym-deliver %arg{3} %arg{4}'
		elif [ -n "$kak_client_env_TMUX" ]; then
			echo 'picker-locations %arg{1} %arg{2} %arg{3} %arg{4}'
		else
			echo 'line-diags-goto-buffer %arg{@}'
		fi
	}
}
# kak-lsp's lsp-show-document-symbol: its additions to the goto buffer
# (`path` for gf on the file name, and the file <ret> jumps into) only when
# that's what was shown, not the picker (they'd land on the file's buffer)
define-command -override -hidden line-diags-shown-lsp-document-symbol nop
define-command -override -hidden lsp-show-document-symbol -params 4 %{
	lsp-show-goto-buffer *goto* lsp-document-symbol %arg{1} %arg{3} %arg{4}
	evaluate-commands -try-client %opt[toolsclient] %{
		try %{
			evaluate-commands "line-diags-shown-%opt{filetype}"
			set-option -add buffer path %arg{1}
			set-option buffer lsp_buffile %arg{2}
		}
	}
}
# kak-lsp's lsp-show-goto-buffer (21.0.2), as it was
define-command -override -hidden -params 4..5 line-diags-goto-buffer %{
	evaluate-commands -save-regs '"' -try-client %opt[toolsclient] %{
		edit! -scratch %arg{1}
		set-option buffer filetype %arg{2}
		set-option buffer jump_current_line 0
		set-option buffer lsp_project_root "%arg{3}/"
		set-register '"' %arg{4}
		execute-keys Rgg
	}
	try %{
		evaluate-commands -try-client %opt[toolsclient] %{
			set-option buffer jump_current_line %arg{5}
			execute-keys %arg{5} g
		}
	}
}

# line-diags-capture ROOT LIST: keep this file's lines of the list, which
# read `path:line:column: [severity][...] message` (path from ROOT on)
define-command -override -hidden -params 2 line-diags-capture %{
	set-option buffer line_diags_state ''
	evaluate-commands %sh{
		double() {
			r= rest=$2
			while :; do
				case $rest in
				*"$1"*) r="$r${rest%%"$1"*}$1$1" rest=${rest#*"$1"} ;;
				*) r=$r$rest; return ;;
				esac
			done
		}
		rel=${kak_buffile#"$1"/}
		out= n=0
		while IFS= read -r l; do
			case $l in
			"$rel:"*) l=${l#"$rel:"} ;;
			"$kak_buffile:"*) l=${l#"$kak_buffile:"} ;;
			*) continue ;;
			esac
			line=${l%%:*} l=${l#*:}
			col=${l%%:*} l=${l#*: }
			case $line$col in ''|*[!0-9]*) continue ;; esac
			# [severity], then [server][source][code], none with spaces
			case $l in '[error]'*|'[warning]'*|'[info]'*|'[hint]'*) ;; *) continue ;; esac
			sev=${l#\[} sev=${sev%%]*}
			while :; do
				case $l in
				'['*']'*) g=${l%%]*}; case $g in *' '*) break ;; esac; l=${l#*]} ;;
				*) break ;;
				esac
			done
			double "'" "$line|$col|$sev|${l# }"
			out="$out '$r'" n=$((n + 1))
		done <<-EOF
			$2
		EOF
		printf '%s\n' "set-option buffer line_diags $out"
		echo "set-option buffer line_diags_n $n"
		echo 'line-diags-render'
	}
}

# Draw for the cursor's line, in two steps: this one picks its diagnostics
# (rightmost first) and has Kakoune measure where on screen each one's column
# is (tabs, wide characters); line-diags-draw draws.
define-command -override -hidden line-diags-render %{
	set-option window line_diags_seen %val{cursor_line}
	set-option window line_diags_dcols
	evaluate-commands -draft %sh{
		double() {
			r= rest=$2
			while :; do
				case $rest in
				*"$1"*) r="$r${rest%%"$1"*}$1$1" rest=${rest#*"$1"} ;;
				*) r=$r$rest; return ;;
				esac
			done
		}
		cur=$kak_cursor_line
		eval set -- "$kak_quoted_opt_inline_diagnostics_severities"
		show=" $* "
		# this line's as "column|severity|message", in col_I and e_I
		n=0
		eval set -- "$kak_quoted_opt_line_diags"
		for e; do
			[ "${e%%|*}" = "$cur" ] || continue
			e=${e#*|} sev=${e#*|} sev=${sev%%|*}
			case $show in *" $sev "*) ;; *) continue ;; esac
			# insert by column, descending
			i=$n
			while [ "$i" -gt 0 ]; do
				eval "pc=\$col_$((i - 1))"
				[ "$pc" -lt "${e%%|*}" ] || break
				eval "col_$i=\$pc e_$i=\$e_$((i - 1))"
				i=$((i - 1))
			done
			eval "col_$i=\${e%%|*} e_$i=\$e"
			n=$((n + 1))
		done
		args= i=0
		while [ "$i" -lt "$n" ]; do
			eval "c=\$col_$i e=\$e_$i"
			echo "try %{ select $cur.$c,$cur.$c; set-option -add window line_diags_dcols %val{cursor_display_column} } catch %{ set-option -add window line_diags_dcols 1 }"
			double "'" "$e"; args="$args '$r'"
			i=$((i + 1))
		done
		# the whole line: the lines below hang from its end (and its width
		# says whether it wraps)
		echo "select $cur.1,$cur.1; execute-keys x; set-option window line_diags_eolcol %val{cursor_display_column}"
		printf '%s\n' "line-diags-draw$args"
	}
}

# line-diags-draw COLUMN|SEVERITY|MESSAGE...: rightmost first, their screen
# columns in line_diags_dcols; the main selection is the cursor's whole line
define-command -override -hidden -params .. line-diags-draw %{
	evaluate-commands %sh{
		double() {
			r= rest=$2
			while :; do
				case $rest in
				*"$1"*) r="$r${rest%%"$1"*}$1$1" rest=${rest#*"$1"} ;;
				*) r=$r$rest; return ;;
				esac
			done
		}
		# subst FROM TO S: S with each FROM replaced by TO, in $r
		subst() {
			r= rest=$3
			while :; do
				case $rest in
				*"$1"*) r="$r${rest%%"$1"*}$2" rest=${rest#*"$1"} ;;
				*) r=$r$rest; return ;;
				esac
			done
		}
		# markup text (\ and the left brace escaped), then a range-specs
		# element (\ and | escaped again), in $r. (The brace comes from
		# printf: kak's parser counts the braces in this block.)
		lb=$(printf '\173')
		esc() {
			subst '\' '\\\\' "$1"; subst "$lb" '\\'"$lb" "$r"; subst '|' '\|' "$r"
		}
		cur=$kak_cursor_line n=$#
		i=0
		for e; do
			sev=${e#*|} sev=${sev%%|*}
			case $sev in
			error) f=InlayDiagnosticError ;; warning) f=InlayDiagnosticWarning ;;
			info) f=InlayDiagnosticInfo ;; *) f=InlayDiagnosticHint ;;
			esac
			eval "f_$i=\$f m_$i=\${e#*|*|}"
			i=$((i + 1))
		done
		i=0
		eval set -- "$kak_quoted_opt_line_diags_dcols"
		for d; do eval "p_$i=\$((d - 1))"; i=$((i + 1)); done

		# the end-of-line messages, less this line's if it gets lines below
		eval set -- "$kak_quoted_opt_lsp_inlay_diagnostics"
		if [ $# -eq 0 ]; then
			echo 'set-option window line_diags_eol %val{timestamp}'
		else
			eol="'$1'"; shift
			for e; do
				[ "$n" -gt 0 ] && [ "${e%%|*}" = "$cur" ] && continue
				double "'" "$e"; eol="$eol '$r'"
			done
			printf '%s\n' "set-option window line_diags_eol $eol"
		fi
		if [ "$n" -eq 0 ]; then
			echo 'set-option window line_diags_view %val{timestamp}'
			echo 'set-option window line_diags_drawn 0'
			exit
		fi

		# blanks to column $2 with a │ at each diagnostic left of it still to
		# come (after the $1-th), in $lead
		blanks() { while [ "$1" -gt 0 ]; do lead="$lead "; set -- $(($1 - 1)); done; }
		mklead() {
			lead= at=0 j=$((n - 1))
			while [ "$j" -gt "$1" ]; do
				eval "pj=\$p_$j fj=\$f_$j"
				if [ "$pj" -lt "$2" ] && [ "$pj" -ge "$at" ]; then
					lead="$lead{Default}"; blanks $((pj - at))
					lead="$lead{$fj}│"; at=$((pj + 1))
				fi
				j=$((j - 1))
			done
			lead="$lead{Default}"; blanks $(($2 - at))
		}
		# text width: the window less the gutter (diagnostic flags, line
		# numbers, │, and the git gutter's column when it has any flags) and
		# the end-of-line mark show-whitespaces draws after each line (these
		# included: a line any wider wraps)
		digits=${#kak_buf_line_count}; [ "$digits" -ge 2 ] || digits=2
		width=$((kak_window_width - digits - 3))
		case $kak_opt_git_gutter_flags in *' '*) width=$((width - 1)) ;; esac
		# a line that wraps puts its columns elsewhere on screen, and one
		# too far right leaves too little room (under 20 columns) right of
		# it: then just the messages, from the left. No line drawn here may
		# be wider than the window: Kakoune 2026.05.21 spins (or crashes)
		# wrapping lines below wider than the window. One too narrow for
		# even that gets none.
		flat=
		[ "$kak_opt_line_diags_eolcol" -gt "$width" ] && flat=1
		i=0
		while [ "$i" -lt "$n" ]; do
			eval "p=\$p_$i"; [ $((width - p - 2)) -ge 20 ] || flat=1
			i=$((i + 1))
		done
		if [ -n "$flat" ]; then
			i=0; while [ "$i" -lt "$n" ]; do eval "p_$i=0"; i=$((i + 1)); done
		fi
		if [ "$width" -lt 12 ]; then
			echo 'set-option window line_diags_view %val{timestamp}'
			echo 'set-option window line_diags_drawn 0'
			exit
		fi
		text= i=0
		while [ "$i" -lt "$n" ]; do
			eval "p=\$p_$i f=\$f_$i m=\$m_$i"
			w=$((width - p - 2))
			first=1
			# word-wrapped to $w columns
			while [ -n "$m" ]; do
				chunk= rest=$m
				while [ -n "$rest" ]; do
					word=${rest%% *}
					case $rest in *' '*) rest=${rest#* } ;; *) rest= ;; esac
					# a word too long for a line: its first $w characters
					if [ "${#word}" -gt "$w" ]; then
						tail=$word head=
						while [ "${#head}" -lt "$w" ]; do
							head=$head${tail%"${tail#?}"} tail=${tail#?}
						done
						word=$head rest="$tail${rest:+ $rest}"
					fi
					if [ -z "$chunk" ]; then chunk=$word
					elif [ $((${#chunk} + 1 + ${#word})) -le "$w" ]; then chunk="$chunk $word"
					else rest="$word${rest:+ $rest}"; break
					fi
				done
				m=$rest
				mklead "$i" "$p"
				esc "$chunk"
				if [ -n "$first" ]; then
					text="$text
$lead{$f}└─$r"
				else
					text="$text
$lead{Default}  {$f}$r"
				fi
				first=
			done
			i=$((i + 1))
		done
		double "'" "${kak_selection_desc##*,}+0|$text"
		printf "set-option window line_diags_view %%val{timestamp} '%s'\n" "$r"
		echo 'set-option window line_diags_drawn 1'
	}
}

# Redraw when the cursor changes line. Done without a shell otherwise: a
# no-op command per unchanged line (line_diags_seen - cursor_line = 0), and
# per buffer with no diagnostics and nothing drawn.
define-command -override -hidden line-diags-same-0 nop
define-command -override -hidden line-diags-skip-0-0 nop
define-command -override -hidden line-diags-idle %{
	try %{
		evaluate-commands "line-diags-skip-%opt{line_diags_n}-%opt{line_diags_drawn}"
	} catch %{
		set-option -remove window line_diags_seen %val{cursor_line}
		try %{
			evaluate-commands "line-diags-same-%opt{line_diags_seen}"
			set-option window line_diags_seen %val{cursor_line}
		} catch %{
			line-diags-render
		}
	}
}
hook -group kakrc global NormalIdle .* line-diags-idle
hook -group kakrc global InsertIdle .* line-diags-idle
hook -group kakrc global WinDisplay .* %{ set-option window line_diags_seen 0 }
# and when the window changes size, now: the lines below were cut to the old
# width. Left wider than the window, Kakoune 2026.05.21 can crash on them
# ("cannot create std::vector larger than max_size()", shrinking a split
# showing a long wrapped line's diagnostics).
hook -group kakrc global WinResize .* %{
	set-option window line_diags_seen 0
	line-diags-idle
}

# kak-tree-sitter's text objects: <a-i>f, ]f etc. (f function, t type,
# a argument, T test), and tree navigation (Helix's A-o/A-i...) in its mode,
# sticky (see syntax tree below)
map global user t ':enter-user-mode -lock tree-sitter<ret>' -docstring 'tree-sitter mode (sticky)'

# --- pickers for lists ---------------------------------------------------------
# kak-lsp's lists (above), ripgrep, git: in kak-picker's popup, as
# `path:line:column:text` lines (bin/kak-picker's "locations").

# picker-locations BUFNAME FILETYPE ROOT LIST: kak-lsp's goto buffer arguments
# picker_only: "client=file" when the client's last diagnostics-picker was
# for just that file, until its diagnostics picker opens (wherever the
# client is by then)
declare-option -hidden str-list picker_only
define-command -override -hidden -params 4 picker-locations %{
	evaluate-commands %sh{
		dir=$(mktemp -d "${TMPDIR:-/tmp}/kak-picker.XXXXXX") || exit
		echo "echo -to-file '$dir/list' %arg{4}"
		echo "echo -to-file '$dir/root' %arg{3}"
		echo "echo -to-file '$dir/type' %arg{2}"
		echo "echo -to-file '$dir/title' %arg{1}"
		if [ "$2" = lsp-diagnostics ] && [ -n "$kak_opt_picker_only" ]; then
			eval set -- "$kak_quoted_opt_picker_only"
			for e; do
				[ "${e#"$kak_client="}" != "$e" ] || continue
				printf %s "${e#"$kak_client="}" > "$dir/only"
				printf "set-option -remove global picker_only '%s'\n" "$(printf %s "$e" | sed "s/'/''/g")"
			done
		fi
		printf %s "${kak_opt_workspace_root:-$PWD}" > "$dir/wsroot"
		echo "picker-open locations '$dir'"
	}
}

define-command -override diagnostics-picker -params ..1 -docstring 'diagnostics-picker [-workspace]: this file''s diagnostics (or every file''s) in a picker' %{
	# replaces what an earlier one left (one kak-lsp never answered); no
	# picker outside tmux: kak-lsp's buffer, with every file's
	evaluate-commands %sh{
		scope=$1
		eval set -- "$kak_quoted_opt_picker_only"
		for e; do
			[ "${e#"$kak_client="}" != "$e" ] || continue
			printf "set-option -remove global picker_only '%s'\n" "$(printf %s "$e" | sed "s/'/''/g")"
		done
		[ "$scope" = -workspace ] || [ -z "$kak_client_env_TMUX" ] ||
			echo 'set-option -add global picker_only "%val{client}=%val{buffile}"'
	}
	try %{ lsp-diagnostics } catch %{
		set-option -remove global picker_only "%val{client}=%val{buffile}"
		fail %val{error}
	}
}
define-command -override symbol-picker -docstring "this file's symbols in a picker" %{
	lsp-document-symbol
}

# The workspace symbol picker asks the server as you type (kak-picker
# --wsym): each answer goes to the file named here instead.
declare-option -hidden str picker_wsym_out
define-command -override -hidden -params 2 picker-wsym-deliver %{
	echo -to-file "%opt{picker_wsym_out}.root" %arg{1}
	echo -to-file "%opt{picker_wsym_out}" %arg{2}
	set-option window picker_wsym_out ''
}
define-command -override workspace-symbol-picker -docstring 'search the workspace''s symbols (picker)' %{
	evaluate-commands %sh{
		dir=$(mktemp -d "${TMPDIR:-/tmp}/kak-picker.XXXXXX") || exit
		printf %s "${kak_opt_workspace_root:-$PWD}" > "$dir/wsroot"
		echo "picker-open workspace-symbols '$dir'"
	}
}

# These start at the buffer's workspace root (see the git gutter below), and
# list paths from there; with -cwd, at kak's cwd.
define-command -override global-search -params ..1 -docstring 'global-search [-cwd]: search the workspace''s files (or the cwd''s) as you type (ripgrep, picker)' %{
	evaluate-commands %sh{
		root=${kak_opt_workspace_root:-$PWD}; [ "$1" = -cwd ] && root=$PWD
		dir=$(mktemp -d "${TMPDIR:-/tmp}/kak-picker.XXXXXX") || exit
		printf "picker-open grep '%s' '%s'\n" "$dir" "$(printf %s "$root" | sed "s/'/''/g")"
	}
}
define-command -override changed-file-picker -docstring "files changed since HEAD in the workspace's repository (git, picker)" %{
	evaluate-commands %sh{
		root=${kak_opt_workspace_root:-$PWD}
		git -C "$root" rev-parse --show-toplevel >/dev/null 2>&1 ||
			{ echo "fail 'changed files: not in a git repository'"; exit; }
		dir=$(mktemp -d "${TMPDIR:-/tmp}/kak-picker.XXXXXX") || exit
		printf "picker-open changed '%s' '%s'\n" "$dir" "$(printf %s "$root" | sed "s/'/''/g")"
	}
}

map global user s ':symbol-picker<ret>'                 -docstring 'symbols (LSP)'
map global user S ':workspace-symbol-picker<ret>'       -docstring 'workspace symbols (LSP)'
map global user d ':diagnostics-picker<ret>'            -docstring 'diagnostics (LSP)'
map global user D ':diagnostics-picker -workspace<ret>' -docstring 'workspace diagnostics (LSP)'
map global user / ':global-search<ret>'                 -docstring 'global search'
map global user g ':changed-file-picker<ret>'           -docstring 'changed files (git)'

# --- git gutter ----------------------------------------------------------------
# Helix's diff gutter: lines added (▍ green), changed (▍ yellow) and removed
# (▔ red, on the line after) since HEAD, for the buffer as it is, unsaved
# changes and all; ]g [g move between them. (Kakoune's git.kak has the like,
# but against the index, and needs diff(1).) Worked out in the background
# whenever the buffer has changed by the time keys stop, and on save and
# focus (a commit moves HEAD), so typing never waits on git.

# buffer: whether it's a file in HEAD ('' not known yet, yes, no), its
# repository and path there, and the timestamp of the latest run (the one
# whose flags count)
declare-option -hidden str git_gutter_state
declare-option -hidden str git_gutter_root
declare-option -hidden str git_gutter_path
declare-option -hidden int git_gutter_seen -1

# (checks without a shell: these exist for the states they accept)
define-command -override -hidden git-gutter-known-yes nop
define-command -override -hidden git-gutter-known-no nop
define-command -override -hidden git-gutter-on-yes nop

# Helix's workspace, per buffer: the nearest directory up from its file's
# with a .git, .jj, .hg, .svn or .helix in it, else kak's cwd (for buffers
# without a file, the cwd's own). The pickers start there (<space>f, /, g)
# and the status line names files from there. Worked out as the gutter
# locates the buffer's repository (when first shown, saved, focused), in
# the same shell, by tests alone. kak-lsp finds each server's root its own
# way (its root_globs: for clangd compile_commands.json, .clangd, .git, .hg,
# nearest first), which mostly comes to the same directory.
declare-option -hidden str workspace_root

define-command -override -hidden git-gutter-locate %{
	evaluate-commands %sh{
		case $kak_buffile in /*) d=${kak_buffile%/*} ;; *) d=$PWD ;; esac
		ws=$PWD
		while :; do
			if [ -e "$d/.git" ] || [ -e "$d/.jj" ] || [ -e "$d/.hg" ] || [ -e "$d/.svn" ] || [ -e "$d/.helix" ]; then
				ws=${d:-/}; break
			fi
			[ -n "$d" ] || break
			d=${d%/*}
		done
		rel=$kak_bufname
		case $kak_buffile in "$ws"/*) rel=${kak_buffile#"$ws"/} ;; esac
		printf "set-option buffer workspace_root '%s'; set-option buffer workspace_bufname '%s'\n" \
			"$(printf %s "$ws" | sed "s/'/''/g")" "$(printf %s "$rel" | sed "s/'/''/g")"
		# the status line's git part, for the workspace (no index refresh:
		# --no-optional-locks keeps git commands run meanwhile from failing
		# on its lock)
		(
			git -C "$ws" --no-optional-locks status --porcelain=v2 --branch 2>/dev/null |
				LC_ALL=C awk -v ws="$ws" '
				function q(t) { gsub(/\047/, "\047\047", t); return "\047" t "\047" }
				/^# branch\.oid / { oid = substr($3, 1, 7) }
				/^# branch\.head / { head = $3 }
				/^[12] / { if (substr($2, 1, 1) != ".") s++; if (substr($2, 2, 1) != ".") m++ }
				/^u / { m++ }
				/^\? / { u++ }
				END {
					if (head == "") exit
					if (head == "(detached)") head = oid
					printf "git-status-set %s %s %s %s %s\n", q(ws), q(" ⎇ " head), \
						q(s ? " +" s : ""), q(m ? " ~" m : ""), q(u ? " ?" u : "")
				}' | kak -p "$kak_session"
		) >/dev/null 2>&1 </dev/null &
		root=
		case $kak_buffile in
		/*) root=$(git -C "${kak_buffile%/*}" rev-parse --show-toplevel 2>/dev/null) ;;
		esac
		path=${kak_buffile#"$root"/}
		# not in git, or not in HEAD (new): nothing to diff against
		if [ -z "$root" ] || ! git -C "$root" cat-file -e "HEAD:./$path" 2>/dev/null; then
			echo 'set-option buffer git_gutter_state no; set-option buffer git_gutter_flags 0'
			exit
		fi
		printf "set-option buffer git_gutter_root '%s'\n" "$(printf %s "$root" | sed "s/'/''/g")"
		printf "set-option buffer git_gutter_path '%s'\n" "$(printf %s "$path" | sed "s/'/''/g")"
		echo 'set-option buffer git_gutter_state yes'
	}
}

define-command -override -hidden git-gutter-update %{
	try %{ evaluate-commands "git-gutter-known-%opt{git_gutter_state}" } catch %{ git-gutter-locate }
	try %{
		evaluate-commands "git-gutter-on-%opt{git_gutter_state}"
		git-gutter-run
	}
}

# the session's temp dir (made on first use, removed when it ends)
declare-option -hidden str git_gutter_dir
hook -group kakrc global KakEnd .* %{
	nop %sh{ [ -n "$kak_opt_git_gutter_dir" ] && rm -rf -- "$kak_opt_git_gutter_dir" }
}

define-command -override -hidden git-gutter-run %{
	set-option buffer git_gutter_seen %val{timestamp}
	evaluate-commands %sh{
		dir=$kak_opt_git_gutter_dir
		if [ -z "$dir" ] || [ ! -d "$dir" ]; then
			dir=$(mktemp -d "${TMPDIR:-/tmp}/kak-git-gutter.XXXXXX") || exit
			printf "set-option global git_gutter_dir '%s'\n" "$(printf %s "$dir" | sed "s/'/''/g")"
		fi
		# files per buffer and run (runs can overlap); the buffer goes there
		# now, the diff runs after
		f=$dir/$(printf %s "$kak_buffile" | cksum | cut -d' ' -f1).$kak_timestamp.$$
		printf "evaluate-commands -no-hooks write -force '%s'\n" "$(printf %s "$f.buf" | sed "s/'/''/g")"
		printf "git-gutter-diff '%s' %s %s\n" "$(printf %s "$f" | sed "s/'/''/g")" "$kak_timestamp" "$kak_buf_line_count"
	}
}
# git-gutter-diff FILES TIMESTAMP LINES: FILES.buf against HEAD
define-command -override -hidden -params 3 git-gutter-diff %{
	nop %sh{
		(
			f=$1 ts=$2 lines=$3
			trap 'rm -f -- "$f.base" "$f.buf"' EXIT
			cd "$kak_opt_git_gutter_root" || exit
			git show "HEAD:./$kak_opt_git_gutter_path" > "$f.base" 2>/dev/null || exit
			# (no diff.external, and line ends as Kakoune's eolformat
			# leaves them: CRLF files under core.autocrlf)
			flags=$(git diff --no-index --no-ext-diff --no-color --ignore-cr-at-eol -U0 -- "$f.base" "$f.buf" |
				awk -v lines="$lines" '
				/^@@/ {
					split($2, a, ","); split($3, b, ",")
					from = a[2] == "" ? 1 : a[2]; to_line = substr(b[1], 2) + 0
					to = b[2] == "" ? 1 : b[2]
					# on the line after, or the last one for lines gone at the end
					if (to == 0) {
						l = to_line + 1; if (l > lines) l = lines; if (l < 1) l = 1
						printf " %d|{GitGutterDelete}▔", l; next
					}
					for (i = 0; i < to; i++)
						printf " %d|{%s}▍", to_line + i, i < from ? "GitGutterModify" : "GitGutterAdd"
				}')
			b=$(printf %s "$kak_buffile" | sed "s/'/''/g")
			printf "evaluate-commands -buffer '%s' %%{ git-gutter-set %s%s }\n" "$b" "$ts" "$flags" |
				kak -p "$kak_session"
		) >/dev/null 2>&1 </dev/null &
	}
}
# git-gutter-set TIMESTAMP FLAGS...: from the latest run only (a slower,
# older one finishing later is dropped); git_gutter_seen less TIMESTAMP is
# 0 for that one
define-command -override -hidden -params 1.. git-gutter-set %{
	set-option -remove buffer git_gutter_seen %arg{1}
	try %{
		evaluate-commands "git-gutter-same-%opt{git_gutter_seen}"
		set-option buffer git_gutter_flags %arg{@}
	}
	set-option -add buffer git_gutter_seen %arg{1}
}

# per buffer when keys stop, if it changed since (no shell otherwise: the
# timestamp check is a no-op command when they're equal)
define-command -override -hidden git-gutter-same-0 nop
define-command -override -hidden git-gutter-idle %{
	try %{
		evaluate-commands "git-gutter-on-%opt{git_gutter_state}"
		set-option -remove buffer git_gutter_seen %val{timestamp}
		try %{
			evaluate-commands "git-gutter-same-%opt{git_gutter_seen}"
			set-option buffer git_gutter_seen %val{timestamp}
		} catch %{
			git-gutter-run
		}
	}
}
hook -group kakrc global NormalIdle .* git-gutter-idle
hook -group kakrc global InsertIdle .* git-gutter-idle
hook -group kakrc global WinDisplay .* git-gutter-update
# saved (it may be new to git no more), or back from elsewhere (a commit)
hook -group kakrc global BufWritePost .* %{ set-option buffer git_gutter_state ''; git-gutter-update }
hook -group kakrc global FocusIn .* %{ set-option buffer git_gutter_state ''; git-gutter-update }

# ]g [g: the next / previous change, from object mode (like ]d [d)
define-command -override -hidden git-hunk-object %{
	evaluate-commands %sh{
		case $kak_object_flags in *to_begin*) dir=prev ;; *) dir=next ;; esac
		eval set -- "$kak_quoted_opt_git_gutter_flags"
		shift
		# hunks: runs of consecutive lines, as start-end
		cur=$kak_cursor_line best= start= prev=
		for e in "$@" ''; do
			l=${e%%|*}
			if [ -n "$start" ] && { [ -z "$l" ] || [ "$l" -ne $((prev + 1)) ]; }; then
				if [ "$dir" = next ] && [ "$start" -gt "$cur" ]; then
					echo "select $start.1,$prev.1; execute-keys x"; exit
				fi
				[ "$dir" = prev ] && [ "$prev" -lt "$cur" ] && best="$start.1,$prev.1"
				start=
			fi
			[ -n "$l" ] || break
			[ -n "$start" ] || start=$l
			prev=$l
		done
		if [ -n "$best" ]; then echo "select $best; execute-keys x"; else echo "fail 'no more changes'"; fi
	}
}
map global object g '<a-;>git-hunk-object<ret>' -docstring 'git change'

# --- match mode: brackets, surrounds ------------------------------------------
# Helix's m: mm to the matching bracket (Kakoune's m; M, extending, is left
# as it is), mi/ma select inside/around an object (<a-i>/<a-a>), and the
# surrounds: ms( wraps the selections in ( ), mr([ turns the ( ) around each
# cursor into [ ], md( deletes them (so right after ms(, its own pair). A
# bracket and its closer are the same pair; any other character pairs with
# itself.
try %{ declare-user-mode match }
map global normal m ':enter-user-mode match<ret>' -docstring 'match mode'
map global match m m                       -docstring 'goto matching bracket'
map global match i <a-i>                   -docstring 'select inside object'
map global match a <a-a>                   -docstring 'select around object'
map global match s ':surround-add<ret>'     -docstring 'surround add'
map global match r ':surround-replace<ret>' -docstring 'surround replace'
map global match d ':surround-delete<ret>'  -docstring 'surround delete'

# surround-char KEY: KEY (as on-key names it) to the character, in $k
# (a shell function, prepended to the scripts below)
declare-option -hidden str surround_sh %{
	surround_char() {
		case $1 in
		'<esc>') exit ;;
		'<lt>') k='<' ;; '<gt>') k='>' ;; '<space>') k=' ' ;; '<minus>') k=- ;;
		'<plus>') k=+ ;; '<semicolon>') k=';' ;; '<percent>') k=% ;;
		'<dquote>') k='"' ;; '<quote>') k="'" ;; '<backtick>') k='`' ;;
		'<backslash>') k='\' ;; '<pipe>') k='|' ;;
		'<'?*) echo "fail 'surround: not a character: $1'"; exit ;;
		*) k=$1 ;;
		esac
		# (the braces from printf: kak's parser counts those in this block)
		lb=$(printf '\173') rb=$(printf '\175')
		case $k in
		'('|')') o='(' c=')' obj='(' ;;
		'['|']') o='[' c=']' obj='[' ;;
		"$lb"|"$rb") o=$lb c=$rb obj=$lb ;;
		'<'|'>') o='<' c='>' obj='<lt>' ;;
		'"'|"'"|'`') o=$k c=$k obj=$k ;;
		# any other: a custom object, the character on each side (regex
		# characters escaped, and the comma that separates the two)
		*) o=$k c=$k
		   e=$k; case $e in '<') e='<lt>' ;; [][\\.*+?^$\|\(\),]) e="\\$e" ;; esac
		   obj="c$e,$e<ret>" ;;
		esac
	}
	kq() { printf "'%s'" "$(printf %s "$1" | sed "s/'/''/g")"; }
	# around: kak commands selecting the pair around each selection, from
	# its cursor as Helix does (a selection that's a whole pair already, as
	# ms leaves it, would otherwise get the one outside it). On a bracket
	# the cursor picks that bracket's pair; a quote or other character
	# can't say which side it's on, so a selection that starts and ends
	# with it is taken as the pair itself.
	around() {
		if [ "$o" != "$c" ]; then
			printf '%s\n' "execute-keys $(kq ";<a-a>$obj")"; return
		fi
		ek=$(kq "<a-k>\\A\\Q$o\\E.*\\Q$c\\E\\z<ret>")
		printf '%s\n' "evaluate-commands -itersel $(kq "try %{ execute-keys $ek } catch %{ execute-keys $(kq ";<a-a>$obj") }")"
	}
}

define-command -override -hidden surround-add %{
	on-key -mode-name surround %{ evaluate-commands %sh{
		eval "$kak_opt_surround_sh"; surround_char "$kak_key"
		printf '%s\n' "surround-insert $(kq "$o") $(kq "$c")"
	} }
}
define-command -override -hidden -params 2 surround-insert %{
	evaluate-commands -save-regs oc %{
		set-register o %arg{1}
		set-register c %arg{2}
		# then the selections take in the opener too, so they cover the pair
		execute-keys 'i<c-r>o<esc>a<c-r>c<esc><a-;>H<a-;>'
	}
}
define-command -override -hidden surround-delete %{
	on-key -mode-name surround %{ evaluate-commands %sh{
		eval "$kak_opt_surround_sh"; surround_char "$kak_key"
		# the pair, its first and last characters, gone
		around; echo 'execute-keys <a-S>d'
	} }
}
define-command -override -hidden surround-replace %{
	on-key -mode-name surround %{ evaluate-commands %sh{
		eval "$kak_opt_surround_sh"; surround_char "$kak_key"
		around; echo 'execute-keys <a-S>'
		echo 'surround-replace-with'
	} }
}
# the selections are the old pairs' characters, opener then closer
define-command -override -hidden surround-replace-with %{
	on-key -mode-name surround %{ evaluate-commands %sh{
		eval "$kak_opt_surround_sh"; surround_char "$kak_key"
		pairs= i=0
		while [ "$i" -lt "$kak_selection_count" ]; do
			pairs="$pairs $(kq "$o") $(kq "$c")"; i=$((i + 2))
		done
		printf '%s\n' "surround-put$pairs"
	} }
}
# surround-put CHARACTER...: one per selection, in their place
define-command -override -hidden -params .. surround-put %{
	evaluate-commands -save-regs o %{
		set-register o %arg{@}
		execute-keys '"oR'
	}
}

# --- comments ----------------------------------------------------------------
# Helix's <space>c / <space>C: toggle line / block comments, with the comment
# tokens Kakoune's filetype scripts set (comment_line, comment_block_*).
# Helix's C-c can't be had: Kakoune keeps <c-c> for interrupting shells.
map global user c ':comment-line<ret>'  -docstring 'toggle line comments'
map global user C ':comment-block<ret>' -docstring 'toggle block comments'

# --- system clipboard ----------------------------------------------------------
# Helix's <space>y/Y/p/P/R. The clipboard is Windows' under WSL (win32yank),
# Wayland's, or X's.
declare-option -hidden str clipboard_copy
declare-option -hidden str clipboard_paste
evaluate-commands %sh{
	if command -v win32yank.exe >/dev/null; then
		copy='win32yank.exe -i --crlf' paste='win32yank.exe -o --lf'
	elif [ -n "$WAYLAND_DISPLAY" ] && command -v wl-copy >/dev/null; then
		copy='wl-copy' paste='wl-paste --no-newline'
	elif command -v xclip >/dev/null; then
		copy='xclip -selection clipboard -i' paste='xclip -selection clipboard -o'
	else
		exit
	fi
	echo "set-option global clipboard_copy '$copy'"
	echo "set-option global clipboard_paste '$paste'"
}
# clipboard-yank [-main]: the selections, one per line (or just the main one)
define-command -override -hidden -params ..1 clipboard-yank %{
	evaluate-commands %sh{
		[ -n "$kak_opt_clipboard_copy" ] || { echo "fail 'clipboard: no clipboard tool'"; exit; }
		if [ "$1" = -main ]; then
			printf %s "$kak_selection" | eval "$kak_opt_clipboard_copy" >/dev/null 2>&1
			n=1
		else
			eval set -- "$kak_quoted_selections"
			n=$# all= sep=
			for s; do all="$all$sep$s" sep='
'; done
			printf %s "$all" | eval "$kak_opt_clipboard_copy" >/dev/null 2>&1
		fi
		echo "echo -markup '{Information}yanked $n selection(s) to the clipboard'"
	}
}
# clipboard-paste KEYS: KEYS (p, P or R) with the clipboard as the register.
# With several selections and as many lines in the clipboard (a final
# newline aside), one line each, as clipboard-yank copied them; else all of
# it for each. (The text is kept whole, final newlines and all: a copied
# line stays one.)
define-command -override -hidden -params 1 clipboard-paste %{
	evaluate-commands -save-regs c %{
		evaluate-commands %sh{
			double() {
				r= rest=$2
				while :; do
					case $rest in
					*"$1"*) r="$r${rest%%"$1"*}$1$1" rest=${rest#*"$1"} ;;
					*) r=$r$rest; return ;;
					esac
				done
			}
			text=$(eval "$kak_opt_clipboard_paste" 2>/dev/null; echo .); text=${text%.}
			nl='
'
			if [ "$kak_selection_count" -gt 1 ]; then
				body=${text%"$nl"} n=1 left=$body
				while :; do
					case $left in *"$nl"*) n=$((n + 1)) left=${left#*"$nl"} ;; *) break ;; esac
				done
				if [ "$n" -eq "$kak_selection_count" ]; then
					regs= left=$body
					while :; do
						double "'" "${left%%"$nl"*}"; regs="$regs '$r'"
						case $left in *"$nl"*) left=${left#*"$nl"} ;; *) break ;; esac
					done
					printf '%s\n' "set-register c$regs"
					exit
				fi
			fi
			double "'" "$text"
			printf "set-register c '%s'\n" "$r"
		}
		execute-keys """c%arg{1}"
	}
}
map global user y ':clipboard-yank<ret>'       -docstring 'yank selections to clipboard'
map global user Y ':clipboard-yank -main<ret>' -docstring 'yank main selection to clipboard'
map global user p ':clipboard-paste p<ret>'    -docstring 'paste clipboard after'
map global user P ':clipboard-paste P<ret>'    -docstring 'paste clipboard before'
map global user R ':clipboard-paste R<ret>'    -docstring 'replace selections with clipboard'

# --- [keys] ------------------------------------------------------------------
# Kakoune has no select mode: the extending form of a motion is its shift
# variant, so [keys.select] folds into these. Helix's move_prev_word_end has no
# Kakoune motion; C-left goes to the previous word start (b) instead.

map global normal <c-right> w
map global normal <c-left>  b
map global normal <s-right> L
map global normal <s-left>  H

# Insert mode: <a-;> runs one normal-mode command. What's typed in insert
# mode never replaces the selection (after i it goes in before it, after a
# after it, and c has deleted it already), so S-left/S-right only matter
# once you leave insert mode.
map global insert <c-right> '<a-;>w<a-;>l'
map global insert <c-left>  '<a-;>b<a-;>;'
map global insert <s-right> '<a-;>L'
map global insert <s-left>  '<a-;>H'

# --- goto mode (g) -------------------------------------------------------------
# Kakoune's g, with Helix's letters where they differ: gs the first non-blank
# (Kakoune's gi; gi is LSP's implementation, above), ge the last line
# (Kakoune's gj; its ge, the buffer's very end, is now ge then gl), gk/gj a
# line up/down (Kakoune's gk was gg, its gj is ge), g| a column (prompted).
# Mapped to Kakoune's own goto keys where there's one, so G extends with
# them too. gf with nothing selected (one character) opens the path under
# the cursor, as Helix's does.
map global goto s i                   -docstring 'line start (non-blank)'
map global goto e j                   -docstring 'last line'
map global goto k '<esc>k'            -docstring 'line up'
map global goto j '<esc>j'            -docstring 'line down'
map global goto | '<esc>:goto-column<ret>' -docstring 'column'
map global goto f '<esc>:goto-file<ret>'   -docstring 'file under cursor (or selected)'
define-command -override -hidden goto-column %{
	prompt column: %{
		evaluate-commands -itersel %{
			try %{ select "%val{cursor_line}.%val{text},%val{cursor_line}.%val{text}" } catch %{ execute-keys gl }
		}
	}
}
# the path around the cursor: between the nearest characters on each side
# that can't be in one (spaces, quotes, brackets, : of file:line, ...)
define-command -override -hidden goto-file %{
	try %{
		execute-keys '<a-k>\A.\z<ret>'
		execute-keys '<a-i>c[^\w./~+@%-],[^\w./~+@%-]<ret>'
	}
	execute-keys gf
}

# --- view mode (z, Z) ----------------------------------------------------------
# Helix's z: a view menu, sticky as Z (until <esc>). Kakoune's v/V view mode
# stays as it is. Kakoune's z/Z (restore/save selections, register ^) move
# into it: zr and zs (<a-z>/<a-Z>, combining, keep their keys).
try %{ declare-user-mode zview }
map global normal z ':enter-user-mode zview<ret>'       -docstring 'view mode'
map global normal Z ':enter-user-mode -lock zview<ret>' -docstring 'view mode (sticky)'
map global zview z vc              -docstring 'center line vertically'
map global zview c vc              -docstring 'center line vertically'
map global zview t vt              -docstring 'line to top'
map global zview b vb              -docstring 'line to bottom'
map global zview m vm              -docstring 'center column horizontally'
map global zview k vk              -docstring 'scroll up'
map global zview j vj              -docstring 'scroll down'
map global zview <up> vk           -docstring 'scroll up'
map global zview <down> vj         -docstring 'scroll down'
map global zview h vh              -docstring 'scroll left'
map global zview l vl              -docstring 'scroll right'
map global zview <c-b> <c-b>       -docstring 'page up'
map global zview <c-f> <c-f>       -docstring 'page down'
map global zview <pageup> <c-b>    -docstring 'page up'
map global zview <pagedown> <c-f>  -docstring 'page down'
map global zview <c-u> <c-u>       -docstring 'half page up'
map global zview <c-d> <c-d>       -docstring 'half page down'
map global zview <backspace> <c-u> -docstring 'half page up'
map global zview <space> <c-d>     -docstring 'half page down'
map global zview / /               -docstring 'search forward'
map global zview ? <a-/>           -docstring 'search backward'
map global zview n n               -docstring 'next match'
map global zview N <a-n>           -docstring 'previous match'
map global zview s Z               -docstring 'save selections (Kakoune''s Z)'
map global zview r z               -docstring 'restore selections (Kakoune''s z)'

# --- [ and ] -------------------------------------------------------------------
# Helix's unimpaired-style jumps, ]x to the next x, [x to the previous:
# d diagnostic (D the last/first), g git change (G the last/first), f
# function, t type, a argument, c comment, e entry, T test (tree-sitter,
# needs a grammar), p paragraph, <space> a blank line below/above. Kakoune's
# [ and ] (select to an object's start/end) move to [[ and ]] (then the
# object key); { } <a-[> <a-]> are unchanged.
# ]d uses kak-lsp's lsp-find-error: the diagnostic object (above) only works
# from object mode, which a user mode's keys can't continue into. Its
# --previous counts one under the cursor, hence a step left first. Both wrap
# around at the ends, as Helix's do. ]D [D pick the last/first of the same
# list themselves (diagnostic-goto, below): lsp-find-error from the buffer's
# end or start misses one at the very first character, or past the last
# (clangd's "expected '}'" at the end of a file).
try %{ declare-user-mode next }
try %{ declare-user-mode prev }
map global normal ] ':enter-user-mode next<ret>' -docstring 'next (Helix ])'
map global normal [ ':enter-user-mode prev<ret>' -docstring 'previous (Helix [)'
map global next ] ]  -docstring 'select to object end (Kakoune''s ])'
map global prev [ [  -docstring 'select to object start (Kakoune''s [)'
map global next d ':lsp-find-error error warning info hint<ret>'               -docstring 'diagnostic'
map global prev d ';h:lsp-find-error --previous error warning info hint<ret>'  -docstring 'diagnostic'
map global next D ':diagnostic-goto last<ret>'   -docstring 'last diagnostic'
map global prev D ':diagnostic-goto first<ret>'  -docstring 'first diagnostic'
map global next g ':git-hunk-goto next<ret>'  -docstring 'git change'
map global prev g ':git-hunk-goto prev<ret>'  -docstring 'git change'
map global next G ':git-hunk-goto last<ret>'  -docstring 'last git change'
map global prev G ':git-hunk-goto first<ret>' -docstring 'first git change'
map global next f ':tree-sitter-text-objects function.around search_next<ret>'  -docstring 'function'
map global prev f ':tree-sitter-text-objects function.around search_prev<ret>'  -docstring 'function'
map global next t ':tree-sitter-text-objects class.around search_next<ret>'     -docstring 'type'
map global prev t ':tree-sitter-text-objects class.around search_prev<ret>'     -docstring 'type'
map global next a ':tree-sitter-text-objects parameter.around search_next<ret>' -docstring 'argument'
map global prev a ':tree-sitter-text-objects parameter.around search_prev<ret>' -docstring 'argument'
map global next c ':tree-sitter-text-objects comment.around search_next<ret>'   -docstring 'comment'
map global prev c ':tree-sitter-text-objects comment.around search_prev<ret>'   -docstring 'comment'
map global next e ':tree-sitter-text-objects entry.around search_next<ret>'     -docstring 'entry'
map global prev e ':tree-sitter-text-objects entry.around search_prev<ret>'     -docstring 'entry'
map global next T ':tree-sitter-text-objects test.around search_next<ret>'      -docstring 'test'
map global prev T ':tree-sitter-text-objects test.around search_prev<ret>'      -docstring 'test'
map global next p ]p      -docstring 'paragraph'
map global prev p [p      -docstring 'paragraph'
map global next <space> <a-o> -docstring 'add blank line below'
map global prev <space> <a-O> -docstring 'add blank line above'
# diagnostic-goto first|last: select the buffer's first or last diagnostic of
# kak-lsp's (its range, cursor at the start, as lsp-find-error does); one past
# the buffer's end ends up on its last character
define-command -override -hidden -params 1 diagnostic-goto %{
	evaluate-commands %sh{
		which=$1
		eval set -- "$kak_quoted_opt_lsp_inline_diagnostics"
		[ $# -gt 0 ] && shift
		hit= key=
		for e; do
			case $e in *'|DiagnosticError'|*'|DiagnosticWarning'|*'|DiagnosticInfo'|*'|DiagnosticHint') ;; *) continue ;; esac
			r=${e%|*} s=${e%%,*}
			k=$(( ${s%.*} * 1048576 + ${s#*.} ))
			if [ -z "$hit" ] || { [ "$which" = first ] && [ "$k" -lt "$key" ]; } || { [ "$which" = last ] && [ "$k" -ge "$key" ]; }; then
				hit=$r key=$k
			fi
		done
		# (as lsp-find-error says it)
		[ -n "$hit" ] || { echo "echo -markup '{Error}No diagnostics found of types: error warning info hint'"; exit; }
		echo "select ${hit#*,},${hit%,*}"
	}
}
# git-hunk-goto next|prev|first|last: select that change's lines (from the
# git gutter's flags; the git change object, <a-i>g ]]g, finds them alike)
define-command -override -hidden -params 1 git-hunk-goto %{
	evaluate-commands %sh{
		mode=$1
		eval set -- "$kak_quoted_opt_git_gutter_flags"
		[ $# -gt 0 ] && shift
		# hunks: runs of consecutive lines, as start-end
		cur=$kak_cursor_line hit= start= prev=
		for e in "$@" ''; do
			l=${e%%|*}
			if [ -n "$start" ] && { [ -z "$l" ] || [ "$l" -ne $((prev + 1)) ]; }; then
				case $mode in
				next) [ "$start" -gt "$cur" ] && { hit="$start.1,$prev.1"; break; } ;;
				prev) [ "$prev" -lt "$cur" ] && hit="$start.1,$prev.1" ;;
				first) hit="$start.1,$prev.1"; break ;;
				last) hit="$start.1,$prev.1" ;;
				esac
				start=
			fi
			[ -n "$l" ] || break
			[ -n "$start" ] || start=$l
			prev=$l
		done
		if [ -n "$hit" ]; then echo "select $hit; execute-keys x"; else echo "fail 'no more changes'"; fi
	}
}

# --- insert mode ---------------------------------------------------------------
# Helix's insert keys: <c-w> and <a-backspace> delete the word before the
# cursor, <a-d> the one after, <c-u> back to the line's first non-blank (or
# its start), <c-k> to its end, <c-h> <c-d> a character back/forward, <c-j> a
# new line; at a line's edge the deleting ones join it with the next or
# previous. Every selection, each on its own. Kakoune's <c-u> (start a new
# undo step) moves to <c-s>, Helix's for that. <tab> and <s-tab> insert one
# indent (indentwidth spaces up to the next stop, or a tab where indentwidth
# is 0): Helix's insert_tab (its smart_tab jump out of the syntax node isn't
# had). A literal tab is <c-v><tab>. Kakoune's <tab> never picks from the
# completion menu (<c-n>/<c-p> do), so there's nothing to lose there.
map global insert <c-w>         '<a-;>:insert-delete -word-before<ret>'
map global insert <a-backspace> '<a-;>:insert-delete -word-before<ret>'
map global insert <a-d>         '<a-;>:insert-delete -word-after<ret>'
map global insert <c-u>         '<a-;>:insert-delete -line-before<ret>'
map global insert <c-k>         '<a-;>:insert-delete -line-after<ret>'
map global insert <c-h>         <backspace>
map global insert <c-d>         <del>
map global insert <c-j>         <ret>
map global insert <c-s>         <c-u>
map global insert <tab>         '<tab><a-;>:insert-indent-expand<ret>'
map global insert <s-tab>       '<tab><a-;>:insert-indent-expand<ret>'
# insert-delete -word-before|-word-after|-line-before|-line-after: from each
# cursor (in insert mode, the character text goes in before)
define-command -override -hidden -params 1 insert-delete %{
	evaluate-commands -draft -itersel %{
		execute-keys ';'
		# (each a draft: a try that fails half way leaves the selection)
		try %{
			evaluate-commands "insert-delete%arg{1}"
		} catch %{
			# nothing on this line that way: the line break
			try %{ evaluate-commands "insert-delete%arg{1}-join" }
		}
	}
}
define-command -override -hidden insert-delete-word-before %{
	execute-keys -draft '<a-h>s(?:\w+\s*|[^\w\s]+\s*|\s+).\z<ret><a-:>H<a-d>'
}
define-command -override -hidden insert-delete-word-after %{
	execute-keys -draft '<a-l>s\A(?:\w+\h*|[^\w\s]+\h*|\h+)<ret><a-d>'
}
define-command -override -hidden insert-delete-line-before %{
	# from the first non-blank if the cursor is past it, else from the start
	try %{
		execute-keys -draft '<a-h>s\S.*.\z<ret><a-:>H<a-d>'
	} catch %{
		execute-keys -draft '<a-h>s\A.+.\z<ret><a-:>H<a-d>'
	}
}
define-command -override -hidden insert-delete-line-after %{
	execute-keys -draft '<a-l>s.+<ret><a-d>'
}
define-command -override -hidden insert-delete-word-before-join %{
	execute-keys -draft '<a-k>^<ret>H<a-k>\A\n.\z<ret><a-:><a-;>;<a-d>'
}
define-command -override -hidden insert-delete-line-before-join %{
	insert-delete-word-before-join
}
define-command -override -hidden insert-delete-word-after-join %{
	execute-keys -draft '<a-k>\n<ret><a-d>'
}
define-command -override -hidden insert-delete-line-after-join %{
	insert-delete-word-after-join
}
# the tab just typed before each cursor, as spaces up to the next multiple
# of indentwidth (none for 0: a tab it stays)
define-command -override -hidden insert-indent-expand-0 nop
define-command -override -hidden insert-indent-expand %{
	try %{ evaluate-commands "insert-indent-expand-%opt{indentwidth}" } catch %{
		execute-keys -draft ";h%opt{indentwidth}@"
	}
}

# --- normal mode ---------------------------------------------------------------
# Helix's keys where Kakoune's are the same idea under another key, or none:
# x selects the line and, pressed again on whole lines, the next one too
# (Kakoune's x, which this repeats, is also X); J joins lines (Kakoune's
# <a-j>), K keeps selections matching a regex (<a-k>), = formats the
# selections (LSP), <a-minus> merges all the selections into one, ~ swaps
# case and <a-`> upper-cases (Kakoune's the other way round), <c-a>/<c-x>
# add/subtract the count (1) to the number in each selection. Kakoune's J
# and K, extending down/up, are <s-down>/<s-up> (as <s-left>/<s-right> above);
# <a-j>, <a-k> and <a-J>, <a-K> keep their keys.
map global normal x       ':extend-line-below<ret>'
map global normal X       x
map global normal J       <a-j>
map global normal K       <a-k>
map global normal <s-down> J
map global normal <s-up>   K
map global normal =       ':lsp-range-formatting<ret>'
map global normal <a-minus> ':merge-selections<ret>'
map global normal ~       <a-`>
map global normal <a-`>   ~
map global normal <c-a>   ':increment %val{count}<ret>'
map global normal <c-x>   ':increment "-%val{count}"<ret>'

define-command -override -hidden extend-line-below %{
	evaluate-commands -itersel %{
		try %{
			# whole lines already: one more
			execute-keys -draft '<a-k>\A^.*\n\z<ret>'
			execute-keys Jx
		} catch %{
			execute-keys x
		}
	}
}
define-command -override merge-selections -docstring 'merge-selections: one selection from the first one''s start to the last one''s end (Helix A-minus)' %{
	evaluate-commands %sh{
		eval set -- $kak_selections_desc
		first=$1; eval "last=\${$#}"
		# each desc is anchor,cursor, either way round: the smaller and larger end
		lo() { a=${1%,*} b=${1#*,}; if [ "${a%.*}" -lt "${b%.*}" ] || { [ "${a%.*}" -eq "${b%.*}" ] && [ "${a#*.}" -le "${b#*.}" ]; }; then echo "$a"; else echo "$b"; fi; }
		hi() { a=${1%,*} b=${1#*,}; if [ "${a%.*}" -lt "${b%.*}" ] || { [ "${a%.*}" -eq "${b%.*}" ] && [ "${a#*.}" -le "${b#*.}" ]; }; then echo "$b"; else echo "$a"; fi; }
		echo "select $(lo "$first"),$(hi "$last")"
	}
}
# increment [N]: N (1, or -1 for a bare -; 0, an unset count, is 1) added to
# the number in or around each selection (Kakoune's number object); a
# selection with none is left as it is
define-command -override increment -params ..1 -docstring 'increment [<n>]: add <n> (1) to the number in each selection (Helix C-a; -<n> subtracts)' %{
	evaluate-commands -save-regs n -itersel %{
		try %{
			execute-keys <a-i>n
			set-register n %sh{
				d=${1:-1}
				case $d in -|-0) d=-1 ;; 0) d=1 ;; esac
				printf '%s\n' "$kak_selection" | awk -v d="$d" '
					# whole numbers keep their width when zero-padded (007, 010)
					/^-?[0-9]+$/ { n = $0 + d; w = sub(/^-/, "") ? length($0) + 1 : length($0)
						if ($0 ~ /^0./) printf "%0" w ".0f", n; else printf "%.0f", n; next }
					{ printf "%s", $0 + d }'
			}
			execute-keys '"nR'
		}
	}
}

# --- syntax tree ---------------------------------------------------------------
# Helix's syntax-tree keys on the arrows: <a-up> the parent node, <a-down>
# back down (the selection <a-up> came from, else the first child),
# <a-left>/<a-right> the previous/next sibling. Without a grammar for the
# buffer, <a-up> asks the language server instead (kak-lsp's selection range,
# its own sticky mode). Kakoune's <a-i> <a-o> <a-n> <a-p> keep their keys.
# <space>t is kak-tree-sitter's mode, sticky till <esc>, with a (all the
# siblings of the main selection's node) and i (all its children) added.
#
# kak-tree-sitter answers a request later, in a command of its own that
# selects the result. <a-up> keeps what it expanded from in ts_history (per
# window): <a-down> goes back to it while the selection is still around it.
declare-option -hidden str-list ts_history
declare-option -hidden str-list ts_cmp
define-command -override -hidden -params 1 ts-one nop
# fails without a syntax tree for the buffer (no kak-tree-sitter, no grammar)
define-command -override -hidden ts-has-tree %{
	set-option window ts_cmp /dev/null
	set-option -remove window ts_cmp %opt{tree_sitter_buf_fifo_path}
	evaluate-commands -verbatim ts-one %opt{ts_cmp}
}
define-command -override -hidden ts-expand %{
	try %{
		ts-has-tree
		set-option -add window ts_history "%val{selections_desc}"
		tree-sitter-nav '"parent"'
	} catch %{
		lsp-selection-range
	}
}
define-command -override -hidden ts-shrink %{
	try %{ ts-has-tree } catch %{ lsp-selection-range-select down }
	evaluate-commands %sh{
		# lo/hi DESC: a selection's first and last positions, as line*2^20+col
		key() { echo $(( ${1%.*} * 1048576 + ${1#*.} )); }
		lohi() {
			a=$(key "${1%,*}") b=$(key "${1#*,}")
			if [ "$a" -le "$b" ]; then lo=$a hi=$b; else lo=$b hi=$a; fi
		}
		eval set -- "$kak_quoted_opt_ts_history"
		if [ $# -gt 0 ]; then
			n=$# i=0 rest= last=
			for e; do
				i=$((i + 1))
				if [ "$i" -lt "$n" ]; then rest="$rest '$e'"; else last=$e; fi
			done
			# each selection still around the one it came from
			set -- $kak_selections_desc
			ok=1 m=0
			for d in $last; do
				m=$((m + 1))
				[ "$m" -le $# ] || { ok=; break; }
				eval "cur=\${$m}"
				lohi "$d"; plo=$lo phi=$hi
				lohi "$cur"
				[ "$lo" -le "$plo" ] && [ "$phi" -le "$hi" ] || { ok=; break; }
			done
			[ "$m" -eq $# ] || ok=
			if [ -n "$ok" ]; then
				echo "set-option window ts_history$rest"
				echo "select $last"
				exit
			fi
		fi
		echo 'set-option window ts_history'
		echo "tree-sitter-nav '\"first_child\"'"
	}
}
map global normal <a-up>    ':ts-expand<ret>'
map global normal <a-down>  ':ts-shrink<ret>'
map global normal <a-left>  ":tree-sitter-nav '{ ""prev_sibling"": { ""cousin"": false } }'<ret>"
map global normal <a-right> ":tree-sitter-nav '{ ""next_sibling"": { ""cousin"": false } }'<ret>"

# ts-select-all children|siblings: the main selection's node's children, or
# its siblings and itself, all selected (punctuation, unnamed nodes like
# brackets and commas, left out), one request per node. Each answer comes
# back as a select, which meanwhile is aliased (in the window) to
# ts-collect-step: a select from a hook (line-diags-render's) goes through
# as usual. A node the selection doesn't cover exactly is first taken whole
# (any request answers with it then): an answer around the selection asked
# from is that. kak-tree-sitter 3.2.2 sometimes answers a request twice, the
# second time late (it reads a client's socket again once it's closed), so
# an answer that would end it (the same again) is only taken on the second
# time running, and for a moment after, stray answers are dropped.
declare-option -hidden str ts_collect_mode
declare-option -hidden str ts_collect_from
declare-option -hidden str ts_collect_last
declare-option -hidden str-list ts_collect_sels
declare-option -hidden int ts_collect_same
declare-option -hidden int ts_collect_seq
declare-option -hidden int ts_collect_step
declare-option -hidden str ts_collect_live
define-command -override -hidden -params 1 ts-select-all %{
	ts-has-tree
	execute-keys ,
	set-option window ts_collect_mode %arg{1}
	set-option window ts_collect_from %val{selection_desc}
	set-option window ts_collect_last ''
	set-option window ts_collect_sels
	set-option window ts_collect_same 0
	set-option -add global ts_collect_seq 1
	set-option window ts_collect_live %opt{ts_collect_seq}
	try %{ unalias buffer select ts-collect-swallow }
	try %{ unalias window select ts-collect-step }
	alias window select ts-collect-step
	ts-collect-timer
	ts-collect-first
}
# no answer for 2s (an error on the server's side): what's in, selected
define-command -override -hidden ts-collect-timer %{
	set-option -add window ts_collect_step 1
	nop %sh{
		(sleep 2; printf "evaluate-commands -client '%s' ts-collect-abort %s %s\n" \
			"$kak_client" "$kak_opt_ts_collect_live" "$kak_opt_ts_collect_step" |
			kak -p "$kak_session") >/dev/null 2>&1 </dev/null &
	}
}
define-command -override -hidden -params 2 ts-collect-abort %{
	evaluate-commands %sh{
		[ "$1" = "$kak_opt_ts_collect_live" ] && [ "$2" = "$kak_opt_ts_collect_step" ] || exit
		echo 'try %{ unalias window select ts-collect-step }; ts-collect-done'
	}
}
define-command -override -hidden ts-collect-first %{
	evaluate-commands "ts-collect-first-%opt{ts_collect_mode}"
}
define-command -override -hidden ts-collect-first-children %{ tree-sitter-nav '"first_child"' }
define-command -override -hidden ts-collect-first-siblings %{ tree-sitter-nav '"first_sibling"' }
define-command -override -hidden ts-collect-next %{
	tree-sitter-nav '{ "next_sibling": { "cousin": false } }'
}
define-command -override -hidden -params .. ts-collect-step %{
	try %{
		nop %val{hook_param}
		unalias window select ts-collect-step
		select %arg{@}
		alias window select ts-collect-step
	} catch %{
		unalias window select ts-collect-step
		select %arg{@}
		evaluate-commands %sh{
			key() { echo $(( ${1%.*} * 1048576 + ${1#*.} )); }
			lohi() {
				a=$(key "${1%,*}") b=$(key "${1#*,}")
				if [ "$a" -le "$b" ]; then lo=$a hi=$b; else lo=$b hi=$a; fi
			}
			again='alias window select ts-collect-step; ts-collect-timer'
			once="set-option window ts_collect_same 1; $again"
			same=$kak_opt_ts_collect_same
			lohi "$kak_selection_desc"; rlo=$lo rhi=$hi
			if [ -z "$kak_opt_ts_collect_last" ]; then
				# the first answer
				lohi "$kak_opt_ts_collect_from"
				if [ "$rlo" -eq "$lo" ] && [ "$rhi" -eq "$hi" ]; then
					[ "$same" -ge 1 ] || { echo "$once; ts-collect-first"; exit; }
					# the node itself: no children, or it's the first sibling
					[ "$kak_opt_ts_collect_mode" = children ] && { echo 'ts-collect-done'; exit; }
				elif [ "$rlo" -le "$lo" ] && [ "$hi" -le "$rhi" ]; then
					# the node around the selection: from it, again
					echo 'set-option window ts_collect_from %val{selection_desc}'
					echo "set-option window ts_collect_same 0; $again; ts-collect-first"; exit
				fi
			elif [ "$kak_selection_desc" = "$kak_opt_ts_collect_last" ]; then
				# no next sibling
				[ "$same" -ge 1 ] || { echo "$once; ts-collect-next"; exit; }
				echo 'ts-collect-done'; exit
			fi
			echo 'set-option window ts_collect_same 0'
			echo 'set-option window ts_collect_last %val{selection_desc}'
			echo 'set-option -add window ts_collect_sels %val{selection_desc}'
			echo "$again; ts-collect-next"
		}
	}
}
# (no keys here: this runs from kak-tree-sitter's answer, and keys would go
# to whatever mode the client is in, the sticky tree-sitter one say)
define-command -override -hidden ts-collect-done %{
	set-option window ts_collect_live ''
	try %{ select %opt{ts_collect_sels} }
	evaluate-commands %sh{
		eval set -- "$kak_quoted_selections"
		keep= i=0
		for d in $kak_selections_desc; do
			i=$((i + 1)) text=
			eval "text=\${$i}"
			case $text in *[[:alnum:]_]*) keep="$keep $d" ;; esac
		done
		[ -n "$keep" ] && echo "select$keep"
		# stray answers still to come: dropped for a moment (in the buffer,
		# which unlike the window can be reached whatever the client shows)
		b=$(printf %s "$kak_bufname" | sed 's/\\/\\\\/g; s/,/\\,/g' | sed "s/'/''/g")
		(sleep 0.5; printf "evaluate-commands -buffer '%s' %%{ try %%{ unalias buffer select ts-collect-swallow } }\n" "$b" |
			kak -p "$kak_session") >/dev/null 2>&1 </dev/null &
	}
	alias buffer select ts-collect-swallow
}
define-command -override -hidden -params .. ts-collect-swallow %{
	try %{
		nop %val{hook_param}
		unalias buffer select ts-collect-swallow
		select %arg{@}
		alias buffer select ts-collect-swallow
	}
}
try %{
	map global tree-sitter a ':ts-select-all siblings<ret>' -docstring 'select all siblings'
	map global tree-sitter i ':ts-select-all children<ret>' -docstring 'select all children'
}

# --- search: smart case --------------------------------------------------------
# Helix's search.smart-case: / ? <a-/> <a-?> are case-insensitive unless the
# pattern has an uppercase letter. Kakoune's search prompt can't be read
# while typing, so the prompt opens with (?i) in it, which goes as soon as an
# uppercase letter is typed (a RawKey hook while it's open; a key run from a
# hook goes to the prompt). It stays in the pattern otherwise, and so in the
# search history and the / register, for n/N alike. Typing, then deleting
# back, is followed; any other edit of the prompt (cursor keys, history,
# completion, <c-r>) leaves it as it is from then on: (?i) or not, by hand.
# Kakoune's own incremental search, history and n/N are untouched.
map global normal /     ':smart-case-arm<ret>/(?i)'
map global normal ?     ':smart-case-arm<ret>?(?i)'
map global normal <a-/> ':smart-case-arm<ret><a-/>(?i)'
map global normal <a-?> ':smart-case-arm<ret><a-?>(?i)'
# the characters typed after (?i), less those deleted
declare-option -hidden int smart_case_typed
define-command -override -hidden smart-case-typed--1 smart-case-disarm
define-command -override -hidden smart-case-disarm %{ remove-hooks window smart-case }
# (RawKey for the key that ran this comes after it: the hooks start with the
# next one)
define-command -override -hidden smart-case-arm %{
	remove-hooks window smart-case
	hook -once -group smart-case window RawKey .* smart-case-arm-now
	hook -group smart-case window ModeChange pop:prompt:.* smart-case-disarm
}
define-command -override -hidden smart-case-arm-now %{
	set-option window smart_case_typed 0
	hook -group smart-case window RawKey [A-Z] %{
		smart-case-disarm
		execute-keys '<home><del><del><del><del><end>'
	}
	hook -group smart-case window RawKey '[^A-Z<]|<(?:space|lt|gt|minus|plus|semicolon|percent|dquote|quote|backtick|backslash|pipe)>' %{
		set-option -add window smart_case_typed 1
	}
	hook -group smart-case window RawKey <backspace> %{
		set-option -remove window smart_case_typed 1
		try %{ evaluate-commands "smart-case-typed-%opt{smart_case_typed}" }
	}
	hook -group smart-case window RawKey '<(?!space>)(?!lt>)(?!gt>)(?!minus>)(?!plus>)(?!semicolon>)(?!percent>)(?!dquote>)(?!quote>)(?!backtick>)(?!backslash>)(?!pipe>)(?!backspace>)(?!ret>)(?!esc>).+>' smart-case-disarm
}

# --- auto-pairs ----------------------------------------------------------------
# Helix's auto-pairs, for () [] {} "" '' ``: typing an opener adds its closer
# after the cursor when what follows is a blank, a closing bracket or the
# line's end (for a quote, also not right after a word character: an
# apostrophe); typing a closer, or a quote, that's next already steps over
# it; <backspace> in an empty pair deletes both. With several selections,
# only if that holds for every one. autopairs-toggle turns it off and on
# (the option can be set per buffer or window too). Keys run from an
# insert-mode hook go to insert mode, as if typed (without hooks).
declare-option -docstring 'auto-pairs: close brackets and quotes as they''re typed' \
	bool autopairs_enabled true
define-command -override autopairs-toggle -docstring 'autopairs-toggle: auto-pairs on/off' %{
	evaluate-commands %sh{
		[ "$kak_opt_autopairs_enabled" = true ] && v=false || v=true
		echo "set-option global autopairs_enabled $v; echo -markup '{Information}auto-pairs: $v'"
	}
}
define-command -override -hidden autopairs-on-true nop
declare-option -hidden int autopairs_n
define-command -override -hidden autopairs-none-0 nop
# autopairs-all KEYS REGEX: fails unless, KEYS from each cursor, every
# selection matches REGEX
define-command -override -hidden -params 2 autopairs-all %{
	evaluate-commands -draft %{
		execute-keys %arg{1}
		set-option window autopairs_n %val{selection_count}
		execute-keys "<a-k>%arg{2}<ret>"
		set-option -remove window autopairs_n %val{selection_count}
		evaluate-commands "autopairs-none-%opt{autopairs_n}"
	}
}
# an opener typed: its closer after it, if blank, a closer or the end is next
define-command -override -hidden -params 1 autopairs-open %{
	evaluate-commands "autopairs-on-%opt{autopairs_enabled}"
	autopairs-all ';' '[\s)\]\x7d]'
	execute-keys "%arg{1}<left>"
}
# a closer typed (or the opener deleted): the same one next, gone
define-command -override -hidden -params 1 autopairs-close %{
	evaluate-commands "autopairs-on-%opt{autopairs_enabled}"
	autopairs-all ';' "\Q%arg{1}\E"
	execute-keys <del>
}
define-command -override -hidden -params 1 autopairs-quote %{
	try %{ autopairs-close %arg{1} } catch %{
		autopairs-all ';hh' '\W'
		autopairs-open %arg{1}
	}
}
hook -group kakrc global InsertChar \(  %{ try %{ autopairs-open ')' } }
hook -group kakrc global InsertChar \[  %{ try %{ autopairs-open ']' } }
hook -group kakrc global InsertChar \{  %[ try %[ autopairs-open '}' ] ]
hook -group kakrc global InsertChar \)  %{ try %{ autopairs-close ')' } }
hook -group kakrc global InsertChar \]  %{ try %{ autopairs-close ']' } }
hook -group kakrc global InsertChar \}  %[ try %[ autopairs-close '}' ] ]
hook -group kakrc global InsertChar '"' %{ try %{ autopairs-quote '"' } }
hook -group kakrc global InsertChar "'" %{ try %{ autopairs-quote "'" } }
hook -group kakrc global InsertChar `   %{ try %{ autopairs-quote ` } }
hook -group kakrc global InsertDelete \( %{ try %{ autopairs-close ')' } }
hook -group kakrc global InsertDelete \[ %{ try %{ autopairs-close ']' } }
hook -group kakrc global InsertDelete \{ %[ try %[ autopairs-close '}' ] ]
hook -group kakrc global InsertDelete '"' %{ try %{ autopairs-close '"' } }
hook -group kakrc global InsertDelete "'" %{ try %{ autopairs-close "'" } }
hook -group kakrc global InsertDelete `   %{ try %{ autopairs-close ` } }

# --- indent guides -------------------------------------------------------------
# indent-guides.render = true, scoped: guides (IndentGuide) only in the
# top-level definition the cursor is in, the innermost block around it
# brighter (IndentGuideActive), none elsewhere; in buffers without a grammar,
# dim guides everywhere. The scopes come from indentation, not the syntax
# tree (kak-tree-sitter only answers later, a request at a time): a
# definition is the run of indented (or blank) lines between two lines at
# column 1, with its header line(s) and closing bracket; a block, the lines
# around the cursor indented at least as deep as its own line. Blank lines
# get the guides of the shallower of their neighbours, drawn after them.
# For the visible lines only, in one shell, whenever keys stop and the
# buffer, the view, the indentation options or the cursor's block changed
# (compared without a shell). Tabs and spaces alike: a guide every
# indentwidth columns (tabstop for tabs, indentwidth 0).
declare-option -hidden range-specs indent_guides
declare-option -hidden str-list indent_guides_cache
declare-option -hidden str-list indent_guides_cmp
declare-option -hidden int indent_guides_cursor
add-highlighter -override global/indent-guides replace-ranges indent_guides
define-command -override -hidden -params 0 indent-guides-none nop
define-command -override -hidden indent-guides-idle %{
	try %{
		ts-has-tree
		set-option window indent_guides_cmp m1
	} catch %{
		set-option window indent_guides_cmp m0
	}
	set-option -add window indent_guides_cmp "t%val{timestamp}" "r%val{window_range}" "w%opt{indentwidth}.%opt{tabstop}" "l%val{cursor_line}"
	set-option -remove window indent_guides_cmp %opt{indent_guides_cache}
	try %{
		evaluate-commands -verbatim indent-guides-none %opt{indent_guides_cmp}
	} catch %{
		indent-guides-render
	}
}
hook -group kakrc global NormalIdle .* indent-guides-idle
hook -group kakrc global InsertIdle .* indent-guides-idle
hook -group kakrc global WinResize .* indent-guides-idle

# the visible lines and 30 more each side (for the scopes around them)
define-command -override -hidden indent-guides-render %{
	set-option window indent_guides_cursor %val{cursor_line}
	try %{
		ts-has-tree
		set-option window indent_guides_cache m1
	} catch %{
		set-option window indent_guides_cache m0
	}
	evaluate-commands -draft %{
		execute-keys 'gb30J<a-;>Gt30Kx'
		evaluate-commands %sh{
			first=${kak_selection_desc%%.*} last=${kak_selection_desc#*,}; last=${last%%.*}
			[ "$first" -le "$last" ] || { t=$first; first=$last; last=$t; }
			set -- $kak_window_range
			top=$(($1 + 1)) bot=$(($1 + $3))
			unit=$kak_opt_indentwidth; [ "$unit" -gt 0 ] || unit=$kak_opt_tabstop
			case $kak_opt_indent_guides_cache in *m1*) scoped=1 ;; *) scoped=0 ;; esac
			printf '%s' "$kak_selection" | awk -v first="$first" -v top="$top" -v bot="$bot" \
				-v cur="$kak_opt_indent_guides_cursor" -v unit="$unit" -v ts="$kak_opt_tabstop" \
				-v scoped="$scoped" -v stamp="$kak_timestamp" -v range="$kak_window_range" \
				-v widths="$kak_opt_indentwidth.$kak_opt_tabstop" '
			{
				l = first + NR - 1; last = l; text[l] = $0
				match($0, /^[ \t]*/); lead[l] = substr($0, 1, RLENGTH)
				c = 0
				for (i = 1; i <= RLENGTH; i++)
					c += substr(lead[l], i, 1) == "\t" ? ts - c % ts : 1
				width[l] = c
				blank[l] = $0 ~ /^[ \t]*$/
			}
			END {
				# blank lines: the shallower neighbour
				p = 0
				for (l = first; l <= last; l++) { if (!blank[l]) p = width[l]; up[l] = p }
				p = 0
				for (l = last; l >= first; l--) {
					if (!blank[l]) { p = width[l]; eff[l] = p } else eff[l] = (up[l] < p ? up[l] : p)
				}
				rs = 0; re = -1; act = -1
				if (!scoped) { rs = first; re = last }
				else if (eff[cur] > 0) { rs = re = cur }
				else if (!blank[cur]) {
					# a header (and opening bracket lines), or a closing bracket
					s = text[cur]
					if (s ~ /^[\])\175]/) { if (eff[cur - 1] > 0) rs = re = cur - 1 }
					else {
						n = cur + 1
						while (n <= last && !blank[n] && eff[n] == 0 && text[n] ~ /^[[(\173][ \t]*$/) n++
						if (n <= last && eff[n] > 0) rs = re = n
					}
				}
				if (scoped && rs > 0) {
					while (rs > first && eff[rs - 1] > 0) rs--
					while (re < last && eff[re + 1] > 0) re++
					# the innermost block: around the cursor, at least as deep
					if (eff[cur] > 0) {
						D = eff[cur]; act = int((D - 1) / unit) * unit
						as = ae = cur
						while (as > rs && eff[as - 1] >= D) as--
						while (ae < re && eff[ae + 1] >= D) ae++
					}
				}
				out = ""
				for (l = (rs > top ? rs : top); l <= re && l <= bot; l++) {
					E = eff[l]; if (E <= 0) continue
					on = act >= 0 && l >= as && l <= ae
					# over the leading whitespace, a character at a time
					c = 0; n = length(lead[l])
					for (i = 1; i <= n; i++) {
						w = substr(lead[l], i, 1) == "\t" ? ts - c % ts : 1
						m = ""; hit = 0
						for (k = c; k < c + w; k++) {
							if (k < E && k % unit == 0) { m = m "{" (on && k == act ? "IndentGuideActive" : "IndentGuide") "}│"; hit = 1 }
							else m = m (hit ? "{Default} " : " ")
						}
						if (hit) out = out " '\''" l "." i "," l "." i "|" m "'\''"
						c += w
					}
					# a blank line short of its guides: the rest after it
					if (blank[l] && c < E) {
						m = ""; pad = ""
						for (k = c; k < E; k++) {
							if (k % unit == 0) { m = m pad "{" (on && k == act ? "IndentGuideActive" : "IndentGuide") "}│"; pad = "" }
							else pad = pad " "
						}
						if (m != "") out = out " '\''" l "." (n + 1) "+0|{Default}" m "'\''"
					}
				}
				print "set-option window indent_guides " stamp out
				# what the result depends on: the cursor anywhere in its block
				# (at the same depth), or anywhere, unscoped
				key = " '\''t" stamp "'\'' '\''r" range "'\'' '\''w" widths "'\''"
				if (!scoped) for (l = first; l <= last; l++) key = key " l" l
				else if (act >= 0) { for (l = as; l <= ae; l++) if (eff[l] == D) key = key " l" l }
				else key = key " l" cur
				print "set-option -add window indent_guides_cache" key
			}'
		}
	}
}

# --- Helix's typable commands ---------------------------------------------------
# The names Helix's : prompt takes, where Kakoune's differ or are missing
# (none of them is one of Kakoune's or a plugin's): aliases where a command
# does the same, else small commands. Kakoune's own :new (a new client) is
# left alone: Helix's :new, a new scratch buffer, is :n / :scratch-buffer.
# :theme is at the end (its command, the pickers' colorscheme, is later).
define-command -override scratch-buffer -docstring 'scratch-buffer: a new, empty scratch buffer (Helix :new, :n)' %{
	evaluate-commands %sh{
		eval set -- "$kak_quoted_buflist"
		i=1
		while :; do
			found=; for b; do [ "$b" = "*scratch-$i*" ] && found=1; done
			[ -z "$found" ] && break
			i=$((i + 1))
		done
		echo "edit -scratch '*scratch-$i*'"
	}
}
define-command -override goto -params 1 -docstring 'goto <line>: to that line (Helix :goto)' %{
	evaluate-commands %sh{
		case $1 in ''|*[!0-9]*) echo "fail 'goto: not a line number: $(printf %s "$1" | sed "s/'/''/g")'" ;; *) echo "execute-keys $1g" ;; esac
	}
}
define-command -override pwd -docstring "pwd: kak's working directory (Helix :pwd)" %{
	echo %sh{ pwd }
}
define-command -override -hidden update-true write
define-command -override -hidden update-false nop
define-command -override update -docstring 'update: write the buffer if it''s modified (Helix :update)' %{
	evaluate-commands "update-%val{modified}"
}
define-command -override wbc -docstring 'wbc: write the buffer and close it (Helix :write-buffer-close)' %{
	write
	delete-buffer
}
define-command -override cq -params ..1 -docstring 'cq [<status>]: quit this client with exit status <status> (1) (Helix :cquit)' %{
	evaluate-commands %sh{
		case ${1:-1} in *[!0-9]*) echo "fail 'cq: not an exit status: $1'" ;; *) echo "quit ${1:-1}" ;; esac
	}
}
define-command -override earlier -params ..1 -docstring 'earlier [<n>]: undo <n> (1) changes (Helix :earlier, steps only)' %{
	evaluate-commands %sh{
		case ${1:-1} in *[!0-9]*) echo "fail 'earlier: only a number of steps, not a time'" ;; *) echo "execute-keys ${1:-1}u" ;; esac
	}
}
define-command -override later -params ..1 -docstring 'later [<n>]: redo <n> (1) changes (Helix :later, steps only)' %{
	evaluate-commands %sh{
		case ${1:-1} in *[!0-9]*) echo "fail 'later: only a number of steps, not a time'" ;; *) echo "execute-keys ${1:-1}U" ;; esac
	}
}
define-command -override lang -params ..1 -docstring 'lang [<filetype>]: show or set the buffer''s filetype (Helix :set-language)' %{
	evaluate-commands %sh{
		if [ $# -eq 0 ]; then echo 'echo %opt{filetype}'; else echo 'set-option buffer filetype %arg{1}'; fi
	}
}
complete-command lang shell-script-candidates %{
	ls "$kak_runtime/rc/filetype" | sed -n 's/\.kak$//p'
}
define-command -override line-ending -params ..1 -docstring 'line-ending [lf|crlf]: show or set the buffer''s line ending (Helix :line-ending)' %{
	evaluate-commands %sh{
		if [ $# -eq 0 ]; then echo 'echo %opt{eolformat}'; else echo 'set-option buffer eolformat %arg{1}'; fi
	}
}
complete-command line-ending shell-script-candidates %{ printf 'lf\ncrlf\n' }
# indent-style [t|1-8]: tabs, or that many spaces (and it stays: see
# indentation above)
define-command -override indent-style -params ..1 -docstring 'indent-style [t|1-8]: show or set the buffer''s indentation, tabs or spaces (Helix :indent-style)' %{
	evaluate-commands %sh{
		case $1 in
		'') echo 'echo "indentwidth %opt{indentwidth} (0: tabs), tabstop %opt{tabstop}"' ;;
		t|tab|tabs) echo 'set-option buffer indentwidth 0; set-option buffer indent_width_from user' ;;
		[1-8]) echo "set-option buffer indentwidth $1; set-option buffer indent_width_from user" ;;
		*) echo "fail 'indent-style: t (tabs) or 1 to 8 (spaces)'" ;;
		esac
	}
}
define-command -override get-option -params 1 -docstring 'get-option <name>: show an option''s value (Helix :get-option)' %{
	evaluate-commands "echo -quoting kakoune -- %%opt{%arg{1}}"
}
define-command -override sh -params 1.. -docstring 'sh <command>: run a shell command, its output in an info box (Helix :run-shell-command)' %{
	evaluate-commands %sh{
		out=$(eval "$*" 2>&1 </dev/null)
		[ -n "$out" ] || out='(no output)'
		printf "info -title sh -- '%s'\n" "$(printf %s "$out" | sed "s/'/''/g")"
	}
}
complete-command sh shell
define-command -override pipe -params 1.. -docstring 'pipe <command>: replace each selection with its output through <command> (Helix :pipe)' %{
	evaluate-commands -save-regs p %{
		set-register p "%arg{@}"
		execute-keys '|<c-r>p<ret>'
	}
}
complete-command pipe shell
define-command -override reflow -params ..1 -docstring 'reflow [<width>]: rewrap the selections'' text at <width> (autowrap_column) columns (Helix :reflow)' %{
	evaluate-commands %sh{
		w=${1:-$kak_opt_autowrap_column}
		case $w in ''|*[!0-9]*) echo "fail 'reflow: not a width: $w'"; exit ;; esac
		echo "pipe fmt -w $w"
	}
}
define-command -override config-open -docstring 'config-open: open the kakrc (Helix :config-open)' %{
	edit "%val{config}/kakrc"
}
define-command -override log-open -docstring 'log-open: the *debug* buffer, Kakoune''s log (Helix :log-open)' %{
	buffer *debug*
}
define-command -override sort -params ..1 -docstring 'sort [-reverse]: sort the selections'' contents among them (Helix :sort, :rsort)' %{
	evaluate-commands -save-regs s %{
		evaluate-commands %sh{
			r=; case $1 in -reverse|-r) r=-r ;; '') ;; *) echo "fail 'sort: -reverse or nothing'"; exit ;; esac
			eval set -- "$kak_quoted_selections"
			printf 'set-register s'
			# (a dot after each keeps its final newlines through $())
			printf '%s\0' "$@" | LC_ALL=C sort -z $r | xargs -0 sh -c '
				for s; do q=$(printf %s. "$s" | sed "s/'\''/'\'''\''/g"); printf " '\''%s'\''" "${q%.}"; done' sh
			echo
		}
		execute-keys '"sR'
	}
}
alias global rsort sort
define-command -override -hidden -params 1 buffer-close-list %{
	evaluate-commands %sh{
		which=$1
		eval set -- "$kak_quoted_buflist"
		for b; do
			[ "$b" = '*debug*' ] && continue
			[ "$which" = others ] && [ "$b" = "$kak_bufname" ] && continue
			printf "try %%{ delete-buffer '%s' } catch %%{ set-option -add global buffer_close_kept '%s' }\n" \
				"$(printf %s "$b" | sed "s/'/''/g")" "$(printf %s "$b" | sed "s/'/''/g")"
		done
	}
}
declare-option -hidden str-list buffer_close_kept
define-command -override -hidden buffer-close-report %{
	evaluate-commands %sh{
		eval set -- "$kak_quoted_opt_buffer_close_kept"
		[ $# -gt 0 ] && echo "echo -markup '{Error}not closed (unsaved changes): $(printf '%s ' "$@" | sed "s/'/''/g")'"
		echo 'set-option global buffer_close_kept'
	}
}
define-command -override buffer-close-others -docstring 'buffer-close-others: close every other buffer, unsaved ones aside (Helix :bco)' %{
	buffer-close-list others
	buffer-close-report
}
define-command -override buffer-close-all -docstring 'buffer-close-all: close every buffer, unsaved ones aside (Helix :bca)' %{
	buffer-close-list all
	buffer-close-report
}
define-command -override yank-join -params ..1 -docstring 'yank-join [<separator>]: yank the selections joined by <separator> (a newline) (Helix :yank-join)' %{
	set-register dquote %sh{
		if [ $# -gt 0 ]; then sep=$1; else sep='
'; fi
		eval set -- "$kak_quoted_selections"
		out=$1; shift
		for s; do out=$out$sep$s; done
		printf '%s' "$out"
	}
	echo -markup "{Information}yanked %val{selection_count} selection(s), joined"
}
define-command -override character-info -docstring 'character-info: the character under the cursor (Helix :character-info, :char)' %{
	evaluate-commands %sh{
		c=$kak_cursor_char_value
		printf "echo 'U+%04X  Dec %d  Hex %X'\n" "$c" "$c" "$c"
	}
}
define-command -override toggle -params 1 -docstring 'toggle <option>: switch a true/false option (Helix :toggle), where it''s set' %{
	try %{ evaluate-commands "nop %%opt{%arg{1}}" } catch %{ fail "toggle: no such option: %arg{1}" }
	try %{
		evaluate-commands "evaluate-commands ""toggle-option-%%opt{%arg{1}}"" %arg{1}"
	} catch %{
		fail "toggle: %arg{1} isn't a true/false option"
	}
}
define-command -override -hidden -params 1 toggle-option-true %{
	set-option current %arg{1} false
	echo "%arg{1}: false"
}
define-command -override -hidden -params 1 toggle-option-false %{
	set-option current %arg{1} true
	echo "%arg{1}: true"
}
# (after the commands they name)
alias global o       edit
alias global open    edit
alias global bc      delete-buffer
alias global bc!     delete-buffer!
alias global bclose  delete-buffer
alias global bnext   buffer-next
alias global bprev   buffer-previous
alias global reload  edit!
alias global rl      edit!
alias global wa!     write-all
alias global quit-all!       kill!
alias global write-quit-all! write-quit-all-force
alias global noop    nop
alias global n       scratch-buffer
alias global bco     buffer-close-others
alias global bca     buffer-close-all
alias global char    character-info

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
# per colour scheme, from the faces dump (see pickers below).
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
# kakmux clients: kakmux_clients lists them (one shell as each connects), and
# the check is without one (the client, less those, is nothing).
declare-option -hidden str-list kakmux_clients
declare-option -hidden str-list kakmux_cmp
define-command -override -hidden -params 0 kakmux-none nop
hook -group kakrc global ClientCreate .* %{
	evaluate-commands %sh{
		case ${kak_client_env_TMUX%%,*} in */kakmux-*)
			echo 'set-option -add global kakmux_clients %val{client}' ;;
		esac
	}
}
hook -group kakrc global ClientRenamed .* %{
	evaluate-commands %sh{
		printf "set-option -remove global kakmux_clients '%s'\n" "$(printf %s "${kak_hook_param%:*}" | sed "s/'/''/g")"
		case ${kak_client_env_TMUX%%,*} in */kakmux-*)
			echo 'set-option -add global kakmux_clients %val{client}' ;;
		esac
	}
}
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
# with the last client). kak (the .zshrc wrapper that set KAKMUX_HANDOFF) then
# attaches it in this terminal, or inside another tmux, nested in this pane
# (see ~/.local/bin/kakmux).
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
		# most recent first, then any buffer never displayed yet
		{
			eval "set -- $kak_quoted_opt_buffer_mru"
			for b; do printf '%s\n' "$b"; done | tac
			eval "set -- $kak_quoted_buflist"
			for b; do printf '%s\n' "$b"; done
		} | awk '!seen[$0]++' > "${dir:?}/order"
		n=0
		while IFS= read -r b; do
			# skip names gone from the buflist (closed buffers left in the MRU)
			eval "set -- $kak_quoted_buflist"
			found=; for x; do [ "$x" = "$b" ] && found=1 && break; done
			[ -n "$found" ] && [ "$b" != '*debug*' ] || continue
			printf %s "$b" > "${dir:?}/${n:?}.name"
			# -buffer takes a comma-separated list: escape \ and , in the name
			q=$(printf %s "$b" | sed 's/\\/\\\\/g; s/,/\\,/g' | sed "s/'/''/g")
			printf "evaluate-commands -buffer '%s' %%{ echo -to-file '%s' %%opt{picker_line} %%val{modified}; execute-keys '%%'; echo -to-file '%s' %%val{selection} }\n" \
				"$q" "${dir:?}/${n:?}.meta" "${dir:?}/${n:?}"
			n=$((n + 1))
		done < "${dir:?}/order"
		rm -f -- "${dir:?}/order"
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
# the autoloaded scripts, the plugins' as they loaded, this kakrc), once,
# and each time those that exist just then are kept (modules load later:
# a command exists if an alias to it can be made). Mappings come from
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
# session (see pane-label below), not shells or other sessions' clients
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
define-command -override -hidden pane-label %{
	nop %sh{
		[ -n "$kak_client_env_TMUX_PANE" ] || exit
		TMUX="$kak_client_env_TMUX" tmux \
			set-option -p -t "$kak_client_env_TMUX_PANE" @kak_session "$kak_session" \; \
			set-option -p -t "$kak_client_env_TMUX_PANE" @kak_client "$kak_client" >/dev/null 2>&1
	}
}
hook -group kakrc global ClientCreate  .* pane-label
hook -group kakrc global ClientRenamed .* pane-label

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

# --- languages.toml, indentation ---------------------------------------------
# A buffer's indentation comes, as in Helix, from the first of: its
# .editorconfig (editorconfig-load, with the editorconfig tool installed),
# the file itself (detected as it's opened: tabs or spaces, and how many,
# over the first 1000 lines), its language's default from languages.toml:
# indent = { tab-width = 4, unit = "\t" } for C, C++, sh and markdown
# (Helix's "bash" is Kakoune's "sh"), else Kakoune's global indentwidth and
# tabstop. All per buffer; indent_width_from/tab_width_from say which one
# set indentwidth/tabstop, so a language default never overrides the other
# two, and goes again when the filetype changes to one without it.
declare-option -hidden str indent_width_from
declare-option -hidden str tab_width_from
define-command -override -hidden lang-indent-c nop
define-command -override -hidden lang-indent-cpp nop
define-command -override -hidden lang-indent-sh nop
define-command -override -hidden lang-indent-markdown nop
# (shell-free: these exist for the states they accept)
define-command -override -hidden indent-free- nop
define-command -override -hidden indent-undo-width-lang %{
	unset-option buffer indentwidth
	set-option buffer indent_width_from ''
}
define-command -override -hidden indent-undo-tab-lang %{
	unset-option buffer tabstop
	set-option buffer tab_width_from ''
}
define-command -override -hidden indent-lang %{
	try %{ evaluate-commands "indent-undo-width-%opt{indent_width_from}" }
	try %{ evaluate-commands "indent-undo-tab-%opt{tab_width_from}" }
	try %{
		evaluate-commands "lang-indent-%opt{filetype}"
		try %{
			evaluate-commands "indent-free-%opt{indent_width_from}"
			set-option buffer indentwidth 0
			set-option buffer indent_width_from lang
		}
		try %{
			evaluate-commands "indent-free-%opt{tab_width_from}"
			set-option buffer tabstop 4
			set-option buffer tab_width_from lang
		}
	}
}
hook -group kakrc global BufSetOption filetype=.* indent-lang

# At open (one shell): .editorconfig, else the file's own indentation. The
# detection is Helix's in short: lines indented with tabs against lines
# with spaces, and for spaces, the most common step up from one indented
# line to the next (1 to 8; on a tie the smaller).
define-command -override -hidden indent-detect %{
	evaluate-commands %sh{
		case $kak_buffile in /*) ;; *) exit ;; esac
		w=
		if command -v editorconfig >/dev/null 2>&1; then
			props=$(editorconfig "$kak_buffile" 2>/dev/null)
			case $props in *=*)
				echo 'try %{ editorconfig-load }'
				case $props in *indent_style=tab*|*indent_style=space*)
					w=1; echo 'set-option buffer indent_width_from editorconfig' ;;
				esac
				case $props in *tab_width=*|*indent_size=*)
					echo 'set-option buffer tab_width_from editorconfig' ;;
				esac ;;
			esac
		fi
		[ -z "$w" ] && [ -r "$kak_buffile" ] || exit
		head -n 1000 -- "$kak_buffile" 2>/dev/null | awk '
			/^[ \t]*$/ { next }
			{
				match($0, /^[ \t]*/); ws = substr($0, 1, RLENGTH)
				if (ws ~ /^\t/) { tabs++; prev = -1; next }
				if (ws ~ /\t/) { prev = -1; next }
				n = length(ws); if (n > 0) spaces++
				if (prev >= 0 && n > prev && n - prev <= 8) step[n - prev]++
				prev = n
			}
			END {
				if (tabs + spaces == 0) exit
				if (tabs > spaces) { w = 0 }
				else {
					w = -1; best = 0
					for (d = 1; d <= 8; d++) if (step[d] > best) { best = step[d]; w = d }
					if (w < 0) exit
				}
				print "set-option buffer indentwidth " w
				print "set-option buffer indent_width_from detected"
			}'
	}
}
hook -group kakrc global BufOpenFile .* indent-detect
hook -group kakrc global BufNewFile  .* indent-detect

# Helix's :theme (see typable commands above)
alias global theme picker-colorscheme

# Helix's :config-reload: this file again, in the running session (see the
# top). What it set per window or buffer as they were shown or typed in
# (tab widths, say) stays until they next are.
define-command -override config-reload -docstring 'config-reload: source the kakrc again' %{
	source "%val{config}/kakrc"
	echo -markup '{Information}config reloaded'
}

set-option global kakrc_loaded true
