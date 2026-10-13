# rc/inline-diagnostics.kak, sourced by kakrc: inline diagnostics.

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
# This runs as kak-lsp publishes (each pause in typing) and as the cursor
# changes line, so it's kept to a shell per list caught (and drawn in the
# same go) and per move onto a line with diagnostics; publishes with none,
# and moves onto lines without, need none.
# The lines below are a replace-ranges insertion (Kakoune has no other way
# to add lines), hung just past the line's newline (the column after it,
# an empty range): inserted before the newline instead, they'd push it,
# and the cursor at the line's end on it, to the end of the last of them,
# and whatever is typed there would show after them until the next list.
# Each edit hangs them again at the new end (see line-diags-follow), as
# Kakoune doesn't move them along reliably. Hung at the next line's start
# instead, they'd take that line's number and gutter flags. Past the
# newline they count as under the cursor at the line's end (its range
# reaches the next line), and a selection over the line, and take their
# faces: theirs (InlineDiagnostic*) are final in onedark (+F, colours
# spelt out), and its end-of-line cursor faces aren't (a final cursor face
# would still win); other colour schemes get the end-of-line messages'
# faces, and the cursor's there.

declare-option -docstring 'severities shown below the cursor''s line' \
	str-list inline_diagnostics_severities error warning
# buffer: "line|column|severity|message" (byte column, as Kakoune counts),
# their lines, and whether that's behind kak-lsp's (stale, or '')
declare-option -hidden str-list line_diags
declare-option -hidden int line_diags_n 0
declare-option -hidden str-list line_diags_lines
declare-option -hidden str line_diags_state
# window: what's drawn (the lines below, their text, the pad: see
# line-diags-hang), whether lines below are, for which cursor line
declare-option -hidden range-specs line_diags_view
declare-option -hidden str line_diags_spec
declare-option -hidden range-specs line_diags_pad
declare-option -hidden line-specs line_diags_eol
declare-option -hidden int line_diags_drawn 0
declare-option -hidden int line_diags_seen 0
declare-option -hidden int line_diags_at
# the lists asked for and not back yet, as "client=bufname", one per list:
# kak-lsp answers in the client that asked, whatever buffer it shows by then
declare-option -hidden str-list line_diags_pending
declare-option -hidden str-list line_diags_dcols
declare-option -hidden int line_diags_eolcol
# window: the cursor's line, and what the drawing was for (size, git gutter
# column, line count: see WinResize below)
declare-option -hidden str line_diags_text
declare-option -hidden str line_diags_size
declare-option -hidden str-list line_diags_cmp
# (the pad first: the first time, line-diags goes again after it)
try %{
	add-highlighter global/line-diags-pad replace-ranges line_diags_pad
	try %{ remove-highlighter global/line-diags }
}
add-highlighter -override global/line-diags replace-ranges line_diags_view
add-highlighter -override global/line-diags-eol flag-lines -after Default line_diags_eol

# The shell side, in functions the scripts below share (each script names
# the kak_ values these read, so Kakoune passes them: it only passes those
# a script mentions).
declare-option -hidden str line_diags_sh %{
	# double C S: S with each C doubled, in $r (all in the shell, no
	# other processes)
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

	# capture ROOT LIST: keep this file's lines of the list, which read
	# `path:line:column: [severity][...] message` (path from ROOT on), as
	# line_diags (and in $diags, shell-quoted as $kak_quoted_ values are)
	# and the lines they're on
	capture() {
		rel=${kak_buffile#"$1"/}
		out= diags= n=0 lines=' '
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
			subst "'" "'\\''" "$line|$col|$sev|${l# }"
			diags="$diags '$r'"
			case $lines in *" $line "*) ;; *) lines="$lines$line " ;; esac
		done <<-EOF
			$2
		EOF
		echo "set-option buffer line_diags_state ''"
		printf '%s\n' "set-option buffer line_diags $out"
		echo "set-option buffer line_diags_n $n"
		echo "set-option buffer line_diags_lines$lines"
	}

	# pick QUOTED: of the diagnostics (line_diags, quoted), the cursor
	# line's of the severities shown, by column, descending: $n of them, in
	# col_I and e_I ("column|severity|message")
	pick() {
		cur=$kak_cursor_line all=$1
		eval set -- "$kak_quoted_opt_inline_diagnostics_severities"
		show=" $* "
		n=0
		eval set -- "$all"
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
	}

	# measure TEXT: the screen columns (from 1) of the picked ones on the
	# cursor's line TEXT (newline included), into dcols, and of its end
	# (the newline), into eolcol, as Kakoune counts them: tabs to the next
	# tabstop, a column past the end at the end. Only for a line all ASCII
	# and not too long (else fails: Kakoune measures, see render);
	# lineend is where the lines below hang from.
	measure() {
		text=$1
		[ "${#text}" -le 1000 ] || return 1
		# (bytes, not characters, whatever the shell's locale)
		lc=${LC_ALL-unset}; LC_ALL=C
		case $text in *[![:print:]"$tab$nl"]*) ascii= ;; *) ascii=1 ;; esac
		len=${#text}
		if [ "$lc" = unset ]; then unset LC_ALL; else LC_ALL=$lc; fi
		[ -n "$ascii" ] || return 1
		lineend="$kak_cursor_line.$len"
		ts=$kak_opt_tabstop
		# the screen column at each byte column, up to the newline's
		rest=$text i=1 w=0
		while [ "$i" -le "$len" ]; do
			eval "dc_$i=$((w + 1))"
			ch=${rest%"${rest#?}"} rest=${rest#?}
			if [ "$ch" = "$tab" ]; then w=$((w + ts - w % ts)); else w=$((w + 1)); fi
			i=$((i + 1))
		done
		eval "eolcol=\$dc_$len"
		dcols= i=0
		while [ "$i" -lt "$n" ]; do
			eval "c=\$col_$i"
			if [ "$c" -lt 1 ]; then d=1
			elif [ "$c" -gt "$len" ]; then d=$eolcol
			else eval "d=\$dc_$c"; fi
			dcols="$dcols $d"
			i=$((i + 1))
		done
		echo "set-option window line_diags_dcols$dcols"
		echo "set-option window line_diags_eolcol $eolcol"
	}

	# render QUOTED [TEXT]: draw for the cursor's line (TEXT, or Kakoune
	# measures it: the commands for that, for a draft whose main selection
	# is the cursor, then line-diags-draw; or with $redraft, just
	# line-diags-render, which makes that draft)
	render() {
		pick "$1"
		if [ "$n" -gt 0 ] && { [ $# -lt 2 ] || ! measure "$2"; }; then
			# from a list caught: in a draft of its own
			[ -n "$redraft" ] && { echo line-diags-render; return; }
			echo 'set-option window line_diags_dcols'
			i=0 args=
			while [ "$i" -lt "$n" ]; do
				eval "c=\$col_$i e=\$e_$i"
				echo "try %{ select $cur.$c,$cur.$c; set-option -add window line_diags_dcols %val{cursor_display_column} } catch %{ set-option -add window line_diags_dcols 1 }"
				double "'" "$e"; args="$args '$r'"
				i=$((i + 1))
			done
			# the whole line: the lines below hang from its end (and its
			# width says whether it wraps)
			echo "select $cur.1,$cur.1; execute-keys x; set-option window line_diags_eolcol %val{cursor_display_column}"
			printf '%s\n' "line-diags-draw$args"
			return
		fi
		i=0; set --
		while [ "$i" -lt "$n" ]; do eval "set -- \"\$@\" \"\$e_$i\""; i=$((i + 1)); done
		draw "$@"
	}

	# draw COLUMN|SEVERITY|MESSAGE...: rightmost first, their screen
	# columns in $dcols, the line's end's in $eolcol, its last position
	# (the newline) in $lineend
	draw() {
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
			error) f=InlineDiagnosticError ;; warning) f=InlineDiagnosticWarning ;;
			info) f=InlineDiagnosticInfo ;; *) f=InlineDiagnosticHint ;;
			esac
			eval "f_$i=\$f m_$i=\${e#*|*|}"
			i=$((i + 1))
		done
		i=0
		for d in $dcols; do eval "p_$i=\$((d - 1))"; i=$((i + 1)); done

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
			echo line-diags-unhang
			return
		fi

		# blanks to column $2 with a │ at each diagnostic left of it still to
		# come (after the $1-th), in $lead
		blanks() { while [ "$1" -gt 0 ]; do lead="$lead "; set -- $(($1 - 1)); done; }
		mklead() {
			lead= at=0 j=$((n - 1))
			while [ "$j" -gt "$1" ]; do
				eval "pj=\$p_$j fj=\$f_$j"
				if [ "$pj" -lt "$2" ] && [ "$pj" -ge "$at" ]; then
					lead="$lead{InlineDiagnosticDefault}"; blanks $((pj - at))
					lead="$lead{$fj}│"; at=$((pj + 1))
				fi
				j=$((j - 1))
			done
			lead="$lead{InlineDiagnosticDefault}"; blanks $(($2 - at))
		}
		# text width: the window less the gutter (diagnostic flags, line
		# numbers, │, the git gutter's column) and the end-of-line mark
		# show-whitespaces draws after each line (these included: a line
		# any wider wraps)
		digits=${#kak_buf_line_count}; [ "$digits" -ge 2 ] || digits=2
		width=$((kak_window_width - digits - 4))
		# a line that wraps puts its columns elsewhere on screen, and one
		# too far right leaves too little room (under 20 columns) right of
		# it: then just the messages, from the left. No line drawn here may
		# be wider than the window: Kakoune 2026.05.21 spins (or crashes)
		# wrapping lines below wider than the window. One too narrow for
		# even that gets none.
		flat=
		[ "$eolcol" -gt "$width" ] && flat=1
		i=0
		while [ "$i" -lt "$n" ]; do
			eval "p=\$p_$i"; [ $((width - p - 2)) -ge 20 ] || flat=1
			i=$((i + 1))
		done
		if [ -n "$flat" ]; then
			i=0; while [ "$i" -lt "$n" ]; do eval "p_$i=0"; i=$((i + 1)); done
		fi
		if [ "$width" -lt 12 ]; then
			echo line-diags-unhang
			return
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
					text="$text$nl$lead{$f}└─$r"
				else
					text="$text$nl$lead{InlineDiagnosticDefault}  {$f}$r"
				fi
				first=
			done
			i=$((i + 1))
		done
		double "'" "$text"
		printf "line-diags-hang %s '%s'\n" "${lineend%.*}.$((${lineend#*.} + 1))" "$r"
	}
	nl=$kak_opt_nl
	tab=$(printf '\t')
}

# Helix's status line diagnostics: a coloured ● and the count, warnings
# then errors, each only when there are some. Set as kak-lsp publishes;
# the colours are in modelinefmt (markup in an option's value isn't read).
declare-option -hidden str lsp_diag_warnings
declare-option -hidden str lsp_diag_errors

# kak-lsp publishes into the buffer: the counts for the modeline, and the
# list is due. Each client showing it asks for it now; one that shows it
# later does then (WinDisplay, below). None at all, and none before either:
# nothing to ask for. No shell: a no-op command for each count that's 0 (or
# all of them), the clients one at a time.
define-command -override -hidden line-diags-zero-0 nop
define-command -override -hidden line-diags-zero-0-0 nop
define-command -override -hidden line-diags-zero-0-0-0-0-0 nop
hook -group kakrc global BufSetOption lsp_inlay_diagnostics=.* %{
	try %{
		evaluate-commands "line-diags-zero-%opt{lsp_diagnostic_warning_count}"
		set-option buffer lsp_diag_warnings ''
	} catch %{
		set-option buffer lsp_diag_warnings " ● %opt{lsp_diagnostic_warning_count}"
	}
	try %{
		evaluate-commands "line-diags-zero-%opt{lsp_diagnostic_error_count}"
		set-option buffer lsp_diag_errors ''
	} catch %{
		set-option buffer lsp_diag_errors " ● %opt{lsp_diagnostic_error_count}"
	}
	try %{
		evaluate-commands "line-diags-zero-%opt{lsp_diagnostic_warning_count}-%opt{lsp_diagnostic_error_count}"
		set-option buffer lsp_diag_sep ''
	} catch %{
		set-option buffer lsp_diag_sep ' │'
	}
	try %{
		evaluate-commands "line-diags-zero-%opt{lsp_diagnostic_error_count}-%opt{lsp_diagnostic_warning_count}-%opt{lsp_diagnostic_info_count}-%opt{lsp_diagnostic_hint_count}-%opt{line_diags_n}"
		set-option buffer line_diags_state ''
	} catch %{
		set-option buffer line_diags_state stale
		try %{ evaluate-commands -verbatim each-client line-diags-request %val{client_list} }
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
# a client gone, its lists will never come (nor the pickers', see
# rc/workspace.kak)
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
# `path:line:column:text` lines): a list asked for above is caught, and
# drawn from straight away (with the cursor's line, picked up first), or
# dropped if this client has moved to another buffer since (that one stays
# stale, so asks again when shown); one a workspace symbol picker asked for
# goes to it; the rest open in a picker (with tmux; else in kak-lsp's
# buffer, as before).
define-command -override -hidden lsp-show-goto-buffer -params 4..5 %{
	try %{ evaluate-commands -draft %{ execute-keys ',;x'; set-option window line_diags_text %val{selection} } }
	evaluate-commands %sh{
		# (read by line_diags_sh: kak_opt_nl kak_buffile kak_cursor_line kak_window_width
		# kak_buf_line_count kak_opt_tabstop
		# kak_quoted_opt_lsp_inlay_diagnostics
		# kak_quoted_opt_inline_diagnostics_severities)
		eval "$kak_opt_line_diags_sh"
		title=$1 root=$3 list=$4
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
				if [ "$take" = "$mine" ]; then
					capture "$root" "$list"
					echo 'set-option window line_diags_seen %val{cursor_line}'
					redraft=1
					render "$diags" "$kak_opt_line_diags_text"
				fi
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

# Draw for the cursor's line: its diagnostics (rightmost first) and where on
# screen each one's column is (worked out in the shell for a line of plain
# ASCII, tabs and all; else Kakoune measures, in a draft, and line-diags-draw
# draws).
define-command -override -hidden line-diags-render %{
	set-option window line_diags_seen %val{cursor_line}
	evaluate-commands -draft %{
		execute-keys ',;x'
		evaluate-commands %sh{
			# (read by line_diags_sh: kak_opt_nl kak_cursor_line kak_window_width
			# kak_buf_line_count kak_opt_tabstop
			# kak_quoted_opt_lsp_inlay_diagnostics
			# kak_quoted_opt_inline_diagnostics_severities)
			eval "$kak_opt_line_diags_sh"
			render "$kak_quoted_opt_line_diags" "$kak_selection"
		}
	}
}
# line-diags-draw COLUMN|SEVERITY|MESSAGE...: rightmost first, their screen
# columns measured into line_diags_dcols; the main selection is the cursor's
# whole line
define-command -override -hidden -params .. line-diags-draw %{
	evaluate-commands %sh{
		# (read by line_diags_sh: kak_opt_nl kak_cursor_line kak_window_width
		# kak_buf_line_count kak_quoted_opt_lsp_inlay_diagnostics)
		eval "$kak_opt_line_diags_sh"
		dcols=; eval "for d in $kak_quoted_opt_line_diags_dcols; do dcols=\"\$dcols \$d\"; done"
		eolcol=$kak_opt_line_diags_eolcol lineend=${kak_selection_desc##*,}
		draw "$@"
	}
}

# line-diags-hang AT TEXT: the lines below (TEXT, as in a range-specs
# value) hung at AT, the column past the cursor line's newline, see above.
# Lines a replace-ranges insertion makes count as the line of the first
# buffer position after the insertion on its screen line, and with none
# (past a newline), as line 1: its number, its flags. So a blank (the pad)
# goes there first (its own highlighter, before), and each line below gets
# it in turn, ending on the last.
define-command -override -hidden -params 2 line-diags-hang %{
	set-option window line_diags_spec %arg{2}
	set-option window line_diags_pad %val{timestamp} "%arg{1}+0|{InlineDiagnosticDefault} "
	set-option window line_diags_view %val{timestamp} "%arg{1}+0|%arg{2}"
	set-option window line_diags_drawn 1
}
define-command -override -hidden line-diags-unhang %{
	set-option window line_diags_pad %val{timestamp}
	set-option window line_diags_view %val{timestamp}
	set-option window line_diags_drawn 0
}
# after an edit within lines (see decorations through edits), lines below
# the cursor's line hung again past its newline (Kakoune's own update of
# an insertion past a newline can leave it where it was as the line grows,
# with what's typed shown after it)
define-command -override -hidden line-diags-follow %{
	try %{
		evaluate-commands "line-diags-clear-%opt{line_diags_drawn}"
	} catch %{
		set-option window line_diags_at %opt{line_diags_seen}
		set-option -remove window line_diags_at %val{cursor_line}
		evaluate-commands "line-diags-same-%opt{line_diags_at}"
		evaluate-commands -draft %{
			execute-keys ',;x'
			set-option window line_diags_at %val{cursor_column}
			set-option -add window line_diags_at 1
			line-diags-hang "%val{cursor_line}.%opt{line_diags_at}" %opt{line_diags_spec}
		}
	}
}

# Redraw when the cursor changes line. Done without a shell otherwise: a
# no-op command per unchanged line (line_diags_seen - cursor_line = 0), per
# buffer with no diagnostics and nothing drawn, and per line without any
# (the cursor's line, less those with some, is still one: line-diags-
# elsewhere takes one argument), where what's drawn just goes.
define-command -override -hidden line-diags-same-0 nop
define-command -override -hidden line-diags-skip-0-0 nop
define-command -override -hidden -params 1 line-diags-elsewhere nop
define-command -override -hidden line-diags-clear-0 nop
define-command -override -hidden line-diags-idle %{
	try %{
		evaluate-commands "line-diags-skip-%opt{line_diags_n}-%opt{line_diags_drawn}"
	} catch %{
		set-option -remove window line_diags_seen %val{cursor_line}
		try %{
			evaluate-commands "line-diags-same-%opt{line_diags_seen}"
			set-option window line_diags_seen %val{cursor_line}
		} catch %{
			try %{
				set-option window line_diags_cmp %val{cursor_line}
				set-option -remove window line_diags_cmp %opt{line_diags_lines}
				evaluate-commands -verbatim line-diags-elsewhere %opt{line_diags_cmp}
				set-option window line_diags_seen %val{cursor_line}
				# (as line-diags-draw leaves it with none to draw)
				try %{ evaluate-commands "line-diags-clear-%opt{line_diags_drawn}" } catch %{
					line-diags-unhang
					set-option window line_diags_eol %opt{lsp_inlay_diagnostics}
				}
			} catch %{
				line-diags-render
			}
		}
	}
}
hook -group kakrc global NormalIdle .* line-diags-idle
hook -group kakrc global InsertIdle .* line-diags-idle
hook -group kakrc global WinDisplay .* %{ set-option window line_diags_seen 0 }
# and when the window changes size, now: the lines below were cut to the old
# width. Left wider than the window, Kakoune 2026.05.21 can crash on them
# ("cannot create std::vector larger than max_size()", shrinking a split
# showing a long wrapped line's diagnostics). Kakoune says so too when only
# the gutter's width changes (the line numbers' digits): so only when the
# size or the line count (its digits) are not what they were (compared
# without a shell: the key less the last one is nothing then, as
# line-diags-none takes).
# (In each client: WinResize runs without one, its cursor on line 1.)
define-command -override -hidden -params 0 line-diags-none nop
define-command -override -hidden line-diags-resized %{
	set-option window line_diags_cmp "%val{window_height}.%val{window_width}|%val{buf_line_count}"
	set-option -remove window line_diags_cmp %opt{line_diags_size}
	try %{
		evaluate-commands -verbatim line-diags-none %opt{line_diags_cmp}
	} catch %{
		set-option window line_diags_size "%val{window_height}.%val{window_width}|%val{buf_line_count}"
		set-option window line_diags_seen 0
		line-diags-idle
	}
}
hook -group kakrc global WinResize .* %{
	try %{ evaluate-commands -verbatim each-client line-diags-resized %val{client_list} }
}

# kak-tree-sitter's text objects: <a-i>f, ]f etc. (f function, t type,
# a argument, T test), and tree navigation (Helix's A-o/A-i...) in its mode,
# sticky (see syntax tree in rc/editing.kak)
map global user t ':enter-user-mode -lock tree-sitter<ret>' -docstring 'tree-sitter mode (sticky)'
