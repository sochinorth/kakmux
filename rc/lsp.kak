# rc/lsp.kak, sourced by kakrc: [editor.lsp], diagnostics, rename and code
# actions.

# --- [editor.lsp] / diagnostics -----------------------------------------------
# kakoune-lsp (loaded in rc/base.kak), for every filetype it has a server for:
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
	# diagnostics (rc/inline-diagnostics.kak, which leave out the cursor's
	# line), not kak-lsp.
	set-option global lsp_inlay_diagnostic_sign ''
	set-option global lsp_inlay_diagnostic_gap ' '
	# lsp.display-progress-messages: progress (and pending server messages)
	# in the status line (see "status line" in rc/editor.kak). Not the rest
	# of kak-lsp's modeline: no breadcrumbs (Helix has none, and they're a
	# request whenever keys stop).
	remove-hooks global lsp-breadcrumbs
	# clangd keeps its preambles (a PCH per open file) in memory, not as
	# $TMPDIR/preamble-*.pch: a clangd gone without kak-lsp's shutdown (kak
	# crashed or killed, kak-lsp killed) leaves those files behind, for good.
	# kak-lsp's C/C++ server table (21.0.2), with the flag added.
	remove-hooks global lsp-filetype-c-family
	hook -group kakrc global BufSetOption filetype=(?:c|cpp|objc) %{
		set-option buffer lsp_servers %{
			[clangd]
			args = ["--log=error", "--pch-storage=memory"]
			root_globs = ["compile_commands.json", ".clangd", ".git", ".hg"]
		}
	}
	# Helix's gutter mark, coloured by severity
	set-option global lsp_diagnostic_line_error_sign   '●'
	set-option global lsp_diagnostic_line_warning_sign '●'
	set-option global lsp_diagnostic_line_info_sign    '●'
	set-option global lsp_diagnostic_line_hint_sign    '●'
	# Helix's keys: g d/D/y/r/i, ]d [d (see [ ] in rc/keys.kak), <space>
	# k/r/a/h (and s/S/d/D: pickers). gi is Kakoune's first non-blank, which
	# moves to gs (see goto mode in rc/keys.kak).
	map global goto d '<esc>:lsp-definition<ret>'      -docstring 'definition (LSP)'
	map global goto D '<esc>:lsp-declaration<ret>'     -docstring 'declaration (LSP)'
	map global goto y '<esc>:lsp-type-definition<ret>' -docstring 'type definition (LSP)'
	map global goto r '<esc>:lsp-references<ret>'      -docstring 'references (LSP)'
	map global goto i '<esc>:lsp-implementation<ret>'  -docstring 'implementation (LSP)'
	# a diagnostic as an object: ]]d [[d select to the next/previous one,
	# shift-] shift-[ d extend to it (]d [d jump: see [ and ] in rc/keys.kak)
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
		nl=$kak_opt_nl
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
