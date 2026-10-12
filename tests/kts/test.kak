# kts test rc (kak -n): logs every `select` kak-tree-sitter answers with, to $KTS_TEST_LOG
define-command -override logsel -params .. %{
  nop %sh{ printf 'SEL %s\n' "$*" >> "$KTS_TEST_LOG" }
  unalias window select logsel
  try %{ select %arg{@} } catch %{
    nop %sh{ printf 'ERR %s\n' "$kak_error" >> "$KTS_TEST_LOG" }
  }
  alias window select logsel
}
define-command -override logstate %{
  nop %sh{ printf 'STATE sel=%s lang=%s fifo=%s\n' "$kak_selections_desc" "$kak_opt_tree_sitter_lang" "${kak_opt_tree_sitter_buf_fifo_path:+set}" >> "$KTS_TEST_LOG" }
}
set-option buffer filetype c
evaluate-commands %sh{ kak-tree-sitter -dks --init "$kak_session" }
alias window select logsel
