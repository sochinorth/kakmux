# rc/editor.kak, sourced by kakrc: [editor], the status line.

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
# (without a shell: the client, less the kakmux clients and those with a
# picker open, is still one: focus-out-one takes one)
declare-option -hidden str-list focus_out_cmp
define-command -override -hidden -params 1 focus-out-one nop
hook -group kakrc global FocusOut .* %{
	set-option window focus_out_cmp %val{client}
	set-option -remove window focus_out_cmp %opt{kakmux_clients} %opt{picker_clients}
	try %{
		evaluate-commands -verbatim focus-out-one %opt{focus_out_cmp}
		auto-save-all
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
# session in kakmux has only those; client-hello, see splits). A no-op once
# the format is customised.
declare-option -hidden str modeline_kakmux
set-option global modeline_kakmux armed

# Helix defaults that Kakoune doesn't turn on by itself. The gutter's columns
# go right to left in the order they're added: the git gutter (see below)
# right of the line numbers, diagnostics (kak-lsp, later) left of them.
# Each is always there, a column wide, as Helix's are: flag-lines is as wide
# as its widest flag, so each option holds a blank one for line 0 (which
# no line has, and which Kakoune never drops); kak-lsp's has its own.
# Else the text moves a column right when a file gets its first change,
# and back when it has none.
declare-option -hidden line-specs git_gutter_flags
set-option global git_gutter_flags 0 '0| '
add-highlighter -override global/git-gutter flag-lines Default git_gutter_flags
add-highlighter -override global/ number-lines -hlcursor
add-highlighter -override global/ show-matching
