# rc/keys.kak, sourced by kakrc: [keys]: match mode, comments, clipboard,
# goto, view, [ and ], insert and normal modes.

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
# Wayland's, or X's: the tool is found on first use (not at startup: under
# WSL, $PATH goes through Windows' directories, which is slow to look in),
# unless clipboard_copy/clipboard_paste are set already.
declare-option -hidden str clipboard_copy
declare-option -hidden str clipboard_paste
# (for the scripts below: sets copy and paste, and says to keep them)
declare-option -hidden str clipboard_sh %{
	copy=$kak_opt_clipboard_copy paste=$kak_opt_clipboard_paste
	if [ -z "$copy" ] || [ -z "$paste" ]; then
		if command -v win32yank.exe >/dev/null; then
			c='win32yank.exe -i --crlf' p='win32yank.exe -o --lf'
		elif [ -n "$WAYLAND_DISPLAY" ] && command -v wl-copy >/dev/null; then
			c='wl-copy' p='wl-paste --no-newline'
		elif command -v xclip >/dev/null; then
			c='xclip -selection clipboard -i' p='xclip -selection clipboard -o'
		else
			c= p=
		fi
		[ -n "$copy" ] || { copy=$c; echo "set-option global clipboard_copy '$c'"; }
		[ -n "$paste" ] || { paste=$p; echo "set-option global clipboard_paste '$p'"; }
	fi
}
# clipboard-yank [-main]: the selections, one per line (or just the main one)
define-command -override -hidden -params ..1 clipboard-yank %{
	evaluate-commands %sh{
		# (kak_opt_clipboard_copy kak_opt_clipboard_paste)
		main=$1
		eval "$kak_opt_clipboard_sh"
		[ -n "$copy" ] || { echo "fail 'clipboard: no clipboard tool'"; exit; }
		if [ "$main" = -main ]; then
			printf %s "$kak_selection" | eval "$copy" >/dev/null 2>&1
			n=1
		else
			eval set -- "$kak_quoted_selections"
			n=$# all= sep=
			for s; do all="$all$sep$s" sep=$kak_opt_nl; done
			printf %s "$all" | eval "$copy" >/dev/null 2>&1
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
			# (kak_opt_clipboard_copy kak_opt_clipboard_paste)
			eval "$kak_opt_clipboard_sh"
			text=$(eval "$paste" 2>/dev/null; echo .); text=${text%.}
			nl=$kak_opt_nl
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
map global zview / ':smart-case-arm<ret>/(?i)'     -docstring 'search forward'
map global zview ? ':smart-case-arm<ret><a-/>(?i)' -docstring 'search backward'
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
		# hunks: runs of consecutive lines, as start-end (line 0's blank flag
		# aside)
		cur=$kak_cursor_line hit= start= prev=
		for e in "$@" ''; do
			l=${e%%|*}
			[ "$l" = 0 ] && continue
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
