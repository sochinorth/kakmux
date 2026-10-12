# diag-inline: clangd's diagnostics drawn inline at the line ends (t.c: three errors)
# golden
. "$(dirname "$0")/../lib/h.sh"
need clangd kak-lsp
mktproj "$R/p/proj"
CWD=$R/p/proj WAIT=1 start kakmux a t.c
waitdiags a 3 || fail "no diagnostics from clangd"
sleep 1
cap a | head -10
q a '%opt{line_diags}'
expect "debug: no errors" "$(dbge a)" ""
s=$(cap a)
expect_match "line 5: dot and message" "$(echo "$s" | sed -n 5p)" '●*5│*int x = "str";*Incompatible pointer to integer conversion*'
expect_match "line 7: no dot" "$(echo "$s" | sed -n 7p)" '  7│*'
expect_match "line 8: fix available" "$(echo "$s" | sed -n 8p)" "●*Expected ';' after expression (fix available)"
