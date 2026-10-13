# rc/commands.kak, sourced by kakrc: Helix's typable commands.

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
# indentation in rc/languages.kak)
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
		if [ $# -gt 0 ]; then sep=$1; else sep=$kak_opt_nl; fi
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
