# rc/editing.kak, sourced by kakrc: syntax tree, smart-case search,
# auto-pairs.

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
		# (entries that are the selection itself left out: <a-up> at the
		# root, or pressed again before its answer, gets the same again)
		eval set -- "$kak_quoted_opt_ts_history"
		rest= last=
		for e; do
			[ "$e" = "$kak_selections_desc" ] && continue
			[ -n "$last" ] && rest="$rest '$last'"
			last=$e
		done
		if [ -n "$last" ]; then
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
# from is that. Each request is answered once, in order (kak-tree-sitter
# 3.2.2-3, patched): the same answer again ends it.
declare-option -hidden str ts_collect_mode
declare-option -hidden str ts_collect_from
declare-option -hidden str ts_collect_last
declare-option -hidden str-list ts_collect_sels
declare-option -hidden int ts_collect_seq
declare-option -hidden str ts_collect_live
define-command -override -hidden -params 1 ts-select-all %{
	ts-has-tree
	execute-keys ,
	set-option window ts_collect_mode %arg{1}
	set-option window ts_collect_from %val{selection_desc}
	set-option window ts_collect_last ''
	set-option window ts_collect_sels
	try %{ unalias window select ts-collect-step }
	alias window select ts-collect-step
	ts-collect-timer
	ts-collect-first
}
# no answer for 2s (an error on the server's side): what's in, selected;
# each request (re)arms it, and only the last one armed counts
define-command -override -hidden ts-collect-timer %{
	set-option -add global ts_collect_seq 1
	set-option window ts_collect_live %opt{ts_collect_seq}
	nop %sh{
		(sleep 2; printf "evaluate-commands -client '%s' ts-collect-abort %s\n" \
			"$kak_client" "$kak_opt_ts_collect_live" |
			kak -p "$kak_session") >/dev/null 2>&1 </dev/null &
	}
}
define-command -override -hidden -params 1 ts-collect-abort %{
	evaluate-commands %sh{
		[ "$1" = "$kak_opt_ts_collect_live" ] || exit
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
			lohi "$kak_selection_desc"; rlo=$lo rhi=$hi
			if [ -z "$kak_opt_ts_collect_last" ]; then
				# the first answer
				lohi "$kak_opt_ts_collect_from"
				if [ "$rlo" -eq "$lo" ] && [ "$rhi" -eq "$hi" ]; then
					# the node itself: no children, or it's the first sibling
					[ "$kak_opt_ts_collect_mode" = children ] && { echo 'ts-collect-done'; exit; }
				elif [ "$rlo" -le "$lo" ] && [ "$hi" -le "$rhi" ]; then
					# the node around the selection: from it, again
					echo 'set-option window ts_collect_from %val{selection_desc}'
					echo "$again; ts-collect-first"; exit
				fi
			elif [ "$kak_selection_desc" = "$kak_opt_ts_collect_last" ]; then
				# no next sibling
				echo 'ts-collect-done'; exit
			fi
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
	}
}
try %{
	map global tree-sitter a ':ts-select-all siblings<ret>' -docstring 'select all siblings'
	map global tree-sitter i ':ts-select-all children<ret>' -docstring 'select all children'
}

# --- search: smart case --------------------------------------------------------
# Helix's search.smart-case: / ? <a-/> <a-?> (and z/ z?, see view mode above)
# are case-insensitive unless the pattern has an uppercase letter. Kakoune's search prompt can't be read
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
