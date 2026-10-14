# rc/decorations.kak, sourced by kakrc: indent guides, decorations through
# edits.

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
# For the visible lines only, in one shell, whenever keys stop (in insert
# mode, after each key: see decorations through edits) and the
# buffer, the view, the indentation options or the cursor's block changed
# (compared without a shell). In insert mode, the buffer counts as changed
# only where typing changes the guides: the line count, the indentation (or
# blankness) of the lines being typed on, or an edit from elsewhere (a new
# undo step: typing makes none till insert mode ends); else they'd go
# again with every key. Tabs and spaces alike: a guide every indentwidth
# columns (tabstop for tabs, indentwidth 0).
declare-option -hidden range-specs indent_guides
declare-option -hidden str-list indent_guides_cache
declare-option -hidden str-list indent_guides_base
declare-option -hidden str-list indent_guides_cmp
declare-option -hidden int indent_guides_cursor
add-highlighter -override global/indent-guides replace-ranges indent_guides
define-command -override -hidden -params 0 indent-guides-none nop
# what the guides depend on, in indent_guides_base: a syntax tree (scoped or
# not), the view's first line and height, the widths
define-command -override -hidden -params 4 indent-guides-range %{
	set-option -add window indent_guides_base "r%arg{1}.%arg{3}"
}
define-command -override -hidden indent-guides-key %{
	try %{
		ts-has-tree
		set-option window indent_guides_base m1
	} catch %{
		set-option window indent_guides_base m0
	}
	evaluate-commands "indent-guides-range %val{window_range}"
	set-option -add window indent_guides_base "w%opt{indentwidth}.%opt{tabstop}"
}
define-command -override -hidden indent-guides-idle %{
	indent-guides-key
	set-option -add window indent_guides_base "t%val{timestamp}"
	indent-guides-check-line
}
define-command -override -hidden indent-guides-idle-insert %{
	indent-guides-key
	set-option -add window indent_guides_base "n%val{buf_line_count}" "i%val{history_id}"
	try %{
		evaluate-commands -draft %{
			execute-keys 'x'
			execute-keys 's\A\h*.<ret>'
			set-option -add window indent_guides_base %val{selections}
		}
	}
	indent-guides-check-line
}
# (the key, less the last render's, is nothing: indent-guides-none takes no
# arguments)
define-command -override -hidden indent-guides-check %{
	set-option window indent_guides_cmp %opt{indent_guides_base}
	set-option -remove window indent_guides_cmp %opt{indent_guides_cache}
	try %{
		evaluate-commands -verbatim indent-guides-none %opt{indent_guides_cmp}
	} catch %{
		indent-guides-render
	}
}
# (and the cursor's line: the cache has those of its block)
define-command -override -hidden indent-guides-check-line %{
	set-option -add window indent_guides_base "l%val{cursor_line}"
	indent-guides-check
}
hook -group kakrc global NormalIdle .* indent-guides-idle
hook -group kakrc global InsertIdle .* indent-guides-idle-insert
# a resize, only if the view's lines changed (Kakoune says so also when the
# gutter's width changes, as it does while typing: see inline diagnostics),
# in each client (WinResize runs without one, its cursor on line 1)
define-command -override -hidden indent-guides-resized %{
	indent-guides-key
	indent-guides-check
}
hook -group kakrc global WinResize .* %{
	try %{ evaluate-commands -verbatim each-client indent-guides-resized %val{client_list} }
}
# kak-tree-sitter taking the buffer on (scoped guides from then on) comes
# with no key to redraw them after: the same, in each client
hook -group kakrc global BufSetOption tree_sitter_buf_fifo_path=.+ %{
	try %{ evaluate-commands -verbatim each-client indent-guides-resized %val{client_list} }
}

# the visible lines and 30 more each side (for the scopes around them)
define-command -override -hidden indent-guides-render %{
	set-option window indent_guides_cursor %val{cursor_line}
	evaluate-commands -draft %{
		execute-keys 'gb30J<a-;>Gt30Kx'
		evaluate-commands %sh{
			first=${kak_selection_desc%%.*} last=${kak_selection_desc#*,}; last=${last%%.*}
			[ "$first" -le "$last" ] || { t=$first; first=$last; last=$t; }
			set -- $kak_window_range
			top=$(($1 + 1)) bot=$(($1 + $3))
			unit=$kak_opt_indentwidth; [ "$unit" -gt 0 ] || unit=$kak_opt_tabstop
			case $kak_opt_indent_guides_base in m1*) scoped=1 ;; *) scoped=0 ;; esac
			printf '%s' "$kak_selection" | awk -v first="$first" -v top="$top" -v bot="$bot" \
				-v cur="$kak_opt_indent_guides_cursor" -v unit="$unit" -v ts="$kak_opt_tabstop" \
				-v scoped="$scoped" -v stamp="$kak_timestamp" '
			# the scopes for the cursor on line C: the definition (rs to re,
			# none: rs 0) and the innermost block (as to ae) with its
			# guide (act, none: -1) brighter; as a string, to compare
			function scope(c,   n, s) {
				rs = 0; re = -1; act = -1; as = ae = 0
				if (!scoped) { rs = first; re = last; return "all" }
				if (eff[c] > 0) rs = re = c
				else if (!blank[c]) {
					# a header (and opening bracket lines), or a closing bracket
					s = text[c]
					if (s ~ /^[\])\175]/) { if (eff[c - 1] > 0) rs = re = c - 1 }
					else {
						n = c + 1
						while (n <= last && !blank[n] && eff[n] == 0 && text[n] ~ /^[[(\173][ \t]*$/) n++
						if (n <= last && eff[n] > 0) rs = re = n
					}
				}
				if (rs > 0) {
					while (rs > first && eff[rs - 1] > 0) rs--
					while (re < last && eff[re + 1] > 0) re++
					# the innermost block: around the cursor, at least as deep
					if (eff[c] > 0) {
						D = eff[c]; act = int((D - 1) / unit) * unit
						as = ae = c
						while (as > rs && eff[as - 1] >= D) as--
						while (ae < re && eff[ae + 1] >= D) ae++
					}
				}
				return rs " " re " " act " " as " " ae
			}
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
				# what the result depends on (indent_guides_base), and the
				# cursor anywhere the scopes come out the same (anywhere,
				# unscoped)
				me = scope(cur); key = ""
				for (l = first; l <= last; l++) if (l == cur || scope(l) == me) key = key " l" l
				scope(cur)
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
				print "set-option window indent_guides_cache %opt{indent_guides_base}" key
			}'
		}
	}
}

# --- decorations through edits -------------------------------------------------
# Helix keeps an edited line's gutter marks and diagnostics until the next
# diff (marking the line changed at once) or the server's next list.
# Kakoune drops a line's flags (line-specs: the git gutter's, kak-lsp's ●
# and end-of-line messages) the moment the line is edited, so every key
# blanked those of the line typed on until the diff and the server caught
# up, a pause later. So, after each key that edited the buffer (InsertKey,
# NormalKey, and entering insert mode, which o O c edit for), no shell:
# - edits within lines (the line count as it was): the flags as they were,
#   stamped with the buffer's new timestamp, so Kakoune keeps them; only
#   for an option stamped as of the previous key (else something else
#   edited in between, and Kakoune's own update, dropping, stands). The
#   end-of-line messages drawn (line_diags_eol), not kak-lsp's own list of
#   them: kak-lsp's next publish would often be that very value, which
#   sets nothing, and the inline diagnostics, which ask for their list as
#   it's set, would miss it;
# - in insert mode, a cursor line without a git flag gets Helix's mark at
#   once (changed, or added for a line just opened), and a line split by
#   <ret> (or two joined) gets its old git and diagnostic flags back, the
#   only ones known without a shell (its end-of-line message comes back
#   with the server's next list);
# - in insert mode, the indent guides are checked now (as InsertIdle does:
#   a shell only when what they depend on changed): the whitespace
#   c-indent strips from a line as <ret> leaves it collapses the guides
#   drawn over it onto its newline, joining two lines on screen until keys
#   stop;
# - the inline diagnostics' lines below follow the cursor line's end, and
#   with lines added or gone, are drawn again (or not) for the cursor's
#   line now: left hanging where a deleted line was, Kakoune draws them
#   over the next line's first character, and one left at a line's start
#   (a line break first) crashes it: an empty screen line, wrapped.
# (NormalKey also runs for the keys of execute-keys in hooks: a check of
# the timestamp each, nothing more.)
# window: the timestamp and line count after the last key, the lines this
# key added; scratch values
declare-option -hidden int decor_ts -1
declare-option -hidden int decor_lines
declare-option -hidden int decor_moved
declare-option -hidden int decor_cmp
declare-option -hidden int decor_prefix
declare-option -hidden str decor_kind
declare-option -hidden str-list decor_list
declare-option -hidden str-list decor_check
declare-option -hidden str-list decor_old_git
declare-option -hidden str-list decor_old_lsp
# (checks without a shell: a no-op command for 0, for no arguments, for
# three; the timestamp of a line-specs value, its first word)
define-command -override -hidden decor-same-0 nop
define-command -override -hidden -params 0 decor-none nop
define-command -override -hidden -params 3 decor-three nop
define-command -override -hidden -params 1.. decor-first %{
	set-option window decor_prefix %arg{1}
}
# decor-stamped OPTION: fails unless OPTION was stamped as of the last key
define-command -override -hidden -params 1 decor-stamped %{
	evaluate-commands "decor-first %%opt{%arg{1}}"
	set-option window decor_cmp %opt{decor_prefix}
	set-option -remove window decor_cmp %opt{decor_ts}
	evaluate-commands "decor-same-%opt{decor_cmp}"
}
# decor-keep SCOPE OPTION: OPTION's flags as they are, now
define-command -override -hidden -params 2 decor-keep %{
	try %{
		decor-stamped %arg{2}
		evaluate-commands "set-option window decor_list %%opt{%arg{2}}"
		set-option -remove window decor_list %opt{decor_prefix}
		evaluate-commands -no-hooks "set-option %arg{1} %arg{2} %%val{timestamp} %%opt{decor_list}"
	}
}
define-command -override -hidden decor-key-insert %{
	set-option window decor_moved %val{buf_line_count}
	set-option -remove window decor_moved %opt{decor_lines}
	set-option window decor_kind lines
	try %{
		evaluate-commands "decor-same-%opt{decor_moved}"
		set-option window decor_kind inline
	}
	evaluate-commands "decor-%opt{decor_kind}-insert"
	indent-guides-idle-insert
}
define-command -override -hidden decor-key-normal %{
	set-option window decor_moved %val{buf_line_count}
	set-option -remove window decor_moved %opt{decor_lines}
	try %{
		evaluate-commands "decor-same-%opt{decor_moved}"
		set-option window decor_kind inline
	} catch %{
		set-option window decor_kind lines
	}
	evaluate-commands "decor-%opt{decor_kind}-normal"
}
define-command -override -hidden decor-inline-normal %{
	decor-keep-all
	try %{ line-diags-follow }
}
define-command -override -hidden decor-lines-normal %{
	set-option window line_diags_seen 0
	line-diags-idle
}
define-command -override -hidden decor-keep-all %{
	decor-keep buffer git_gutter_flags
	decor-keep buffer lsp_diagnostic_lines
	decor-keep window line_diags_eol
}
define-command -override -hidden decor-inline-insert %{
	decor-keep-all
	try %{ decor-git-mark Modify }
	try %{ line-diags-follow }
}
# lines opened (o O <ret>) or joined: the old flags kept first (if stamped
# as of the last key: their line numbers are the old ones), then Kakoune's
# update; one line more, the cursor's is new and the one above it keeps
# its flags (<ret> at its end changed it, as Kakoune sees it); one less,
# the cursor's is the two joined
define-command -override -hidden decor-lines-insert %{
	set-option window decor_old_git
	set-option window decor_old_lsp
	try %{
		decor-stamped git_gutter_flags
		set-option window decor_old_git %opt{git_gutter_flags}
	}
	try %{
		decor-stamped lsp_diagnostic_lines
		set-option window decor_old_lsp %opt{lsp_diagnostic_lines}
	}
	try %{ update-option buffer git_gutter_flags }
	try %{ update-option buffer lsp_diagnostic_lines }
	try %{ evaluate-commands "decor-moved-%opt{decor_moved}" }
	set-option window line_diags_seen 0
	line-diags-idle
}
define-command -override -hidden decor-moved-1 %{
	set-option window decor_prefix %val{cursor_line}
	set-option -remove window decor_prefix 1
	decor-restore-line %opt{decor_prefix}
	try %{ decor-git-mark Add }
}
define-command -override -hidden decor-moved--1 %{
	decor-restore-line %val{cursor_line}
	try %{ decor-git-mark Modify }
}
# decor-restore-line LINE: its old git and diagnostic flags back
define-command -override -hidden -params 1 decor-restore-line %{
	decor-restore buffer git_gutter_flags decor_old_git "%arg{1}|{GitGutterAdd}▍"
	decor-restore buffer git_gutter_flags decor_old_git "%arg{1}|{GitGutterModify}▍"
	decor-restore buffer git_gutter_flags decor_old_git "%arg{1}|{GitGutterDelete}▔"
	try %{
		decor-restore buffer lsp_diagnostic_lines decor_old_lsp "%arg{1}|{LineFlagError}%opt{lsp_diagnostic_line_error_sign}"
		decor-restore buffer lsp_diagnostic_lines decor_old_lsp "%arg{1}|{LineFlagWarning}%opt{lsp_diagnostic_line_warning_sign}"
		decor-restore buffer lsp_diagnostic_lines decor_old_lsp "%arg{1}|{LineFlagInfo}%opt{lsp_diagnostic_line_info_sign}"
		decor-restore buffer lsp_diagnostic_lines decor_old_lsp "%arg{1}|{LineFlagHint}%opt{lsp_diagnostic_line_hint_sign}"
	}
}
# decor-restore SCOPE OPTION OLD FLAG: FLAG back into OPTION if OLD had it
# (OLD less FLAG is OLD then: FLAG less OLD is nothing)
define-command -override -hidden -params 4 decor-restore %{
	try %{
		set-option window decor_check %arg{4}
		evaluate-commands "set-option -remove window decor_check %%opt{%arg{3}}"
		evaluate-commands -verbatim decor-none %opt{decor_check}
		evaluate-commands -no-hooks %{
			set-option -remove %arg{1} %arg{2} %arg{4}
			set-option -add %arg{1} %arg{2} %arg{4}
		}
	}
}
# decor-git-mark Modify|Add: for the cursor's line, if it has no git flag
# (in a buffer the gutter diffs; none of its three flags is there: the
# three less the gutter's are still three)
define-command -override -hidden -params 1 decor-git-mark %{
	evaluate-commands "git-gutter-on-%opt{git_gutter_state}"
	update-option buffer git_gutter_flags
	set-option window decor_check "%val{cursor_line}|{GitGutterAdd}▍" "%val{cursor_line}|{GitGutterModify}▍" "%val{cursor_line}|{GitGutterDelete}▔"
	set-option -remove window decor_check %opt{git_gutter_flags}
	evaluate-commands -verbatim decor-three %opt{decor_check}
	set-option -add buffer git_gutter_flags "%val{cursor_line}|{GitGutter%arg{1}}▍"
}
# decor-key insert|normal: after a key (nothing to do unless it edited)
define-command -override -hidden -params 1 decor-key %{
	set-option window decor_cmp %val{timestamp}
	set-option -remove window decor_cmp %opt{decor_ts}
	try %{ evaluate-commands "decor-same-%opt{decor_cmp}" } catch %{
		evaluate-commands "decor-key-%arg{1}"
		set-option window decor_ts %val{timestamp}
		set-option window decor_lines %val{buf_line_count}
	}
}
hook -group kakrc global InsertKey .* %{ decor-key insert }
hook -group kakrc global NormalKey .* %{ decor-key normal }
hook -group kakrc global ModeChange (push|pop):.*:insert %{ decor-key insert }
