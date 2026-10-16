# indent-detect: a file's own indentation, detected at open: block
# comments' " * " lines and arguments aligned inside open parentheses are
# not indentation (they made tab-indented C headers come out 1 or 8 wide:
# a guide every column)
# covers: rc/languages.kak
. "$(dirname "$0")/../lib/h.sh"
mktproj "$R/p/proj"
P=$R/p/proj
# tabs, with more comment and aligned lines than tab-indented ones
{
	printf '/*\n * one\n * two\n * three\n */\n'
	printf 'int foo(int a,\n        int b);\nint bar(int a,\n        int b);\n'
	printf 'int baz(int a,\n        int b);\n\n'
	printf 'struct s {\n\tint x;\n\tint y;\n};\n'
} > "$P/tabs.h"
# 4 spaces, a block comment in a function
printf 'int f(void)\n{\n    /*\n     * a\n     * b\n     */\n    if (x) {\n        g();\n    }\n}\n' > "$P/spaces.c"
# a Lisp: its lines all inside parentheses, still counted
printf '(defun foo (x)\n  (let ((y 1))\n    (+ x y)))\n' > "$P/lisp.el"
CWD=$P start kakmux b t.c
w() { send b "edit -existing $P/$1"; qv b '%opt{indentwidth} %opt{indent_width_from}'; }
expect "tabs.h: tabs" "$(w tabs.h)" "0 detected"
expect "spaces.c: 4" "$(w spaces.c)" "4 detected"
expect "lisp.el: 2" "$(w lisp.el)" "2 detected"
dbge b
