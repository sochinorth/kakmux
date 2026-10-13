# rc/workspace.kak, sourced by kakrc: pickers for lists (LSP, ripgrep, git),
# the git gutter and the workspace root.

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

# buffer: whether it's a file in HEAD ('' not known yet, pending: being
# found out, yes, no), its repository and path there, the timestamp of the
# latest run (the one whose flags count)
declare-option -hidden str git_gutter_state
declare-option -hidden str git_gutter_root
declare-option -hidden str git_gutter_path
declare-option -hidden int git_gutter_seen -1
declare-option -hidden int git_gutter_cmp

# (checks without a shell: these exist for the states they accept)
define-command -override -hidden git-gutter-known-yes nop
define-command -override -hidden git-gutter-known-no nop
define-command -override -hidden git-gutter-known-pending nop
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

# The session's temp dir (made on first use, removed when it ends, or by the
# next session if it ended without saying so) holds
# each run's copy of the buffer, at the buffer's prefix (a number per
# locate) and the run's: runs can overlap.
declare-option -hidden str git_gutter_dir
declare-option -hidden str git_gutter_file
declare-option -hidden int git_gutter_files
declare-option -hidden int git_gutter_seq
hook -group kakrc global KakEnd .* %{
	nop %sh{ [ -n "$kak_opt_git_gutter_dir" ] && rm -rf -- "$kak_opt_git_gutter_dir" }
}

# The workspace here, by tests alone (the status line shows it as soon as
# the buffer does); git (the status line's part, whether the file is in
# HEAD) in the background, which says back with git-gutter-located.
define-command -override -hidden git-gutter-locate %{
	set-option buffer git_gutter_state pending
	set-option -add global git_gutter_files 1
	evaluate-commands %sh{
		# kak-quoted, in $r (all in the shell, no other processes)
		kq() {
			r= rest=$1 q=\'
			while :; do
				case $rest in
				*"$q"*) r="$r${rest%%"$q"*}$q$q" rest=${rest#*"$q"} ;;
				*) r="'$r$rest'"; return ;;
				esac
			done
		}
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
		kq "$ws"; echo "set-option buffer workspace_root $r"
		kq "$rel"; echo "set-option buffer workspace_bufname $r"
		dir=$kak_opt_git_gutter_dir
		case $kak_buffile in /*)
			if [ -z "$dir" ] || [ ! -d "$dir" ]; then
				# (named after the server's pid: those of sessions that
				# ended without KakEnd, their terminal closed say, go now)
				for d in "${TMPDIR:-/tmp}"/kak-git-gutter.*.*; do
					p=${d#"${TMPDIR:-/tmp}"/kak-git-gutter.} p=${p%%.*}
					case $p in ''|*[!0-9]*) continue ;; esac
					kill -0 "$p" 2>/dev/null || rm -rf -- "$d"
				done
				dir=$(mktemp -d "${TMPDIR:-/tmp}/kak-git-gutter.$PPID.XXXXXX") &&
					{ kq "$dir"; echo "set-option global git_gutter_dir $r"; }
			fi ;;
		esac
		kq "$kak_buffile"; b=$r
		(
			# the status line's git part, for the workspace (no index
			# refresh: --no-optional-locks keeps git commands run meanwhile
			# from failing on its lock)
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
			# not in git, or not in HEAD (new), or no temp dir: nothing to
			# diff against
			root=
			case $kak_buffile in /*) root=$(git -C "${kak_buffile%/*}" rev-parse --show-toplevel 2>/dev/null) ;; esac
			path=${kak_buffile#"$root"/}
			if [ -z "$root" ] || [ -z "$dir" ] || ! git -C "$root" cat-file -e "HEAD:./$path" 2>/dev/null; then
				printf 'try %%{ evaluate-commands -buffer %s %%{ git-gutter-located no } }\n' "$b"
			else
				kq "$root"; root=$r; kq "$path"; path=$r; kq "$dir/$kak_opt_git_gutter_files"
				printf 'try %%{ evaluate-commands -buffer %s %%{ git-gutter-located yes %s %s %s } }\n' "$b" "$root" "$path" "$r"
			fi | kak -p "$kak_session"
		) >/dev/null 2>&1 </dev/null &
	}
}
# git-gutter-located no | yes ROOT PATH FILE: from git-gutter-locate, while
# pending (else it's been found out already: a no-op command for that)
define-command -override -hidden -params 1..4 git-gutter-located %{
	evaluate-commands -verbatim "git-gutter-located-%opt{git_gutter_state}-%arg{1}" %arg{@}
}
define-command -override -hidden -params .. git-gutter-located--no nop
define-command -override -hidden -params .. git-gutter-located--yes nop
define-command -override -hidden -params .. git-gutter-located-no-no nop
define-command -override -hidden -params .. git-gutter-located-no-yes nop
define-command -override -hidden -params .. git-gutter-located-yes-no nop
define-command -override -hidden -params .. git-gutter-located-yes-yes nop
define-command -override -hidden -params 1 git-gutter-located-pending-no %{
	set-option buffer git_gutter_state no
	unset-option buffer git_gutter_flags
}
define-command -override -hidden -params 4 git-gutter-located-pending-yes %{
	set-option buffer git_gutter_root %arg{2}
	set-option buffer git_gutter_path %arg{3}
	set-option buffer git_gutter_file %arg{4}
	set-option buffer git_gutter_state yes
	git-gutter-run
}

define-command -override -hidden git-gutter-update %{
	try %{ evaluate-commands "git-gutter-known-%opt{git_gutter_state}" } catch %{ git-gutter-locate }
	try %{
		evaluate-commands "git-gutter-on-%opt{git_gutter_state}"
		git-gutter-run
	}
}

# The buffer goes to its file for the run now, the diff runs in the
# background after (one shell). Its directory gone (a temp cleaner): the
# buffer is located again when keys next stop.
define-command -override -hidden git-gutter-run %{
	set-option buffer git_gutter_seen %val{timestamp}
	set-option -add buffer git_gutter_seq 1
	try %{
		evaluate-commands -no-hooks %{ write -force "%opt{git_gutter_file}.%opt{git_gutter_seq}.buf" }
		git-gutter-diff "%opt{git_gutter_file}.%opt{git_gutter_seq}" %val{timestamp} %val{buf_line_count}
	} catch %{
		set-option buffer git_gutter_state ''
		set-option buffer git_gutter_seen -1
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
# older one finishing later is dropped), and only if the buffer is still as
# that run saw it: git_gutter_seen, and the buffer's timestamp, less
# TIMESTAMP are 0 then. Flags for an older buffer would lose those of the
# lines edited since (Kakoune drops a line's flags as it's edited) while
# typing goes on; those keep theirs (see "decorations through edits"
# below), and the run the next pause starts brings the rest.
define-command -override -hidden -params 1.. git-gutter-set %{
	set-option -remove buffer git_gutter_seen %arg{1}
	set-option buffer git_gutter_cmp %val{timestamp}
	set-option -remove buffer git_gutter_cmp %arg{1}
	try %{
		evaluate-commands "git-gutter-same-%opt{git_gutter_seen}"
		evaluate-commands "git-gutter-same-%opt{git_gutter_cmp}"
		set-option buffer git_gutter_flags %arg{@}
		set-option -add buffer git_gutter_flags '0| '
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
	} catch %{
		# (located no more: the temp dir gone, see git-gutter-run)
		try %{ evaluate-commands "git-gutter-known-%opt{git_gutter_state}" } catch %{ git-gutter-update }
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
		# hunks: runs of consecutive lines, as start-end (line 0's blank flag
		# aside)
		cur=$kak_cursor_line best= start= prev=
		for e in "$@" ''; do
			l=${e%%|*}
			[ "$l" = 0 ] && continue
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
