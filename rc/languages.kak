# rc/languages.kak, sourced by kakrc: languages.toml, indentation.

# --- languages.toml, indentation ---------------------------------------------
# A buffer's indentation comes, as in Helix, from the first of: its
# .editorconfig (editorconfig-load, with the editorconfig tool installed),
# the file itself (detected as it's opened: tabs or spaces, and how many,
# over the first 1000 lines), its language's default from languages.toml:
# indent = { tab-width = 4, unit = "\t" } for C, C++, sh and markdown
# (Helix's "bash" is Kakoune's "sh"), else the global indentwidth and
# tabstop (4: tabs are 4 wide unless one of the others says otherwise). All
# per buffer; indent_width_from/tab_width_from say which one set
# indentwidth/tabstop, so a language default never overrides the other two,
# and goes again when the filetype changes to one without it.
set-option global tabstop 4
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
# line to the next (1 to 8; on a tie the smaller). Not indentation, left
# out: block comments' " * " lines, and lines inside parentheses left open
# above (aligned arguments: counted till a blank line; not in Lisps, all
# parentheses). The editorconfig tool is looked for once a session
# (editorconfig_tool: none, or the command; under WSL $PATH goes through
# Windows' directories, slow to look in).
declare-option -hidden str editorconfig_tool
define-command -override -hidden indent-detect %{
	evaluate-commands %sh{
		case $kak_buffile in /*) ;; *) exit ;; esac
		w=
		ec=$kak_opt_editorconfig_tool
		if [ -z "$ec" ]; then
			ec=$(command -v editorconfig 2>/dev/null) || ec=none
			printf "set-option global editorconfig_tool '%s'\n" "$(printf %s "$ec" | sed "s/'/''/g")"
		fi
		if [ "$ec" != none ]; then
			props=$("$ec" "$kak_buffile" 2>/dev/null)
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
		case $kak_buffile in
			*.el|*.lisp|*.lsp|*.cl|*.scm|*.ss|*.rkt|*.clj|*.cljs|*.cljc|*.edn|*.fnl|*.janet) parens=0 ;;
			*) parens=1 ;;
		esac
		awk -v parens="$parens" '
			NR > 1000 { exit }
			/^[ \t]*$/ { depth = 0; next }
			/^[ \t]*\*/ { next }
			{
				cont = parens && depth > 0
				depth += gsub(/\(/, "(") - gsub(/\)/, ")"); if (depth < 0) depth = 0
				if (cont) next
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
			}' < "$kak_buffile" 2>/dev/null
	}
}
hook -group kakrc global BufOpenFile .* indent-detect
hook -group kakrc global BufNewFile  .* indent-detect
