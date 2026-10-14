# kak-assumptions: Kakoune behaviours the kakrc relies on (stock rc, no
# kakrc): alias to a missing command fails; a <ret> mapping still fires
# NormalKey; ModeChange's names for prompts, user modes, counts
# golden
# covers:
. "$(dirname "$0")/../lib/h.sh"
mktproj "$R/p/proj"
CWD=$R/p/proj start tmux al -n t.c
send al "try %{ alias global pp no-such-cmd; echo -debug A1-ok } catch %{ echo -debug A1-fail %val{error} }"
send al "try %{ alias global pp edit; echo -debug A2-ok } catch %{ echo -debug A2-fail %val{error} }"
send al "try %{ alias global pp clang-enable-autocomplete; echo -debug A3-ok } catch %{ echo -debug A3-fail %val{error} }"
dbg al | grep 'A[0-9]'
echo "== NormalKey for a mapped <ret>"
send al "map global normal <ret> ':echo -debug MAPPED<ret>'; hook global NormalKey <ret> %{ echo -debug HOOK %val{hook_param} }"
keys al Enter
dbg al | grep 'MAPPED\|HOOK'
send al "unmap global normal <ret>"
echo "== ModeChange"
send al "hook global ModeChange .* %{ echo -debug MC %val{hook_param} }"
keys al ' '; keys al Escape; keys al i; keys al Escape; keys al ':'; keys al Escape; keys al g; keys al Escape; keys al '%' ; keys al s ; keys al Escape ; keys al Escape; keys al f; keys al Escape; keys al '"'; keys al a
keys al Escape
keys al 3; keys al Escape
keys al x; keys al C; keys al C
keys al i; keys al Escape
dbg al | grep '^MC'
