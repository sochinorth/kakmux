# tests/lib/fixtures.sh: scratch projects (sourced by h.sh)

# mkproj DIR: a small C project in a git repo (branch trunk), committed,
# compile_commands.json for clangd. It builds clean (checked with make when
# make and cc are there).
mkproj() {
	P=${1:?}
	rm -rf "$P"; mkdir -p "$P"
	cat > "$P/Makefile" <<'EOF'
CFLAGS = -Wall -Wextra

points: main.o point.o util.o
	$(CC) -o $@ $^

clean:
	rm -f *.o points
EOF
	printf -- '-Wall\n-Wextra\n' > "$P/compile_flags.txt"
	cat > "$P/point.h" <<'EOF'
#ifndef POINT_H
#define POINT_H

struct point {
	int x;
	int y;
};

int point_dist2(struct point a, struct point b);
struct point point_sum(struct point a, struct point b);
void point_print(const char *label, struct point p);

#endif
EOF
	cat > "$P/point.c" <<'EOF'
#include <stdio.h>
#include "point.h"

int point_dist2(struct point a, struct point b)
{
	int dx = a.x - b.x, dy = a.y - b.y;
	return dx * dx + dy * dy;
}

struct point point_sum(struct point a, struct point b)
{
	struct point r = { a.x + b.x, a.y + b.y };
	return r;
}

void point_print(const char *label, struct point p)
{
	printf("%s = (%d, %d)\n", label, p.x, p.y);
}
EOF
	cat > "$P/main.c" <<'EOF'
#include <stdio.h>
#include "point.h"

int util_twice(int v);

int main(void)
{
	struct point a = { 1, 2 };
	struct point b = { 4, 6 };
	struct point c = point_sum(a, b);
	point_print("c", c);
	printf("dist2 = %d\n", point_dist2(a, b));
	printf("twice = %d\n", util_twice(c.x));
	return 0;
}
EOF
	cat > "$P/util.c" <<'EOF'
#include "point.h"

int util_twice(int v)
{
	struct point p = { v, v };
	return point_dist2(p, p) + 2 * v;
}
EOF
	printf '*.o\npoints\n.cache/\n' > "$P/.gitignore"
	printf '[{"directory":"%s","file":"main.c","command":"cc -Wall -Wextra -c main.c"},{"directory":"%s","file":"point.c","command":"cc -Wall -Wextra -c point.c"},{"directory":"%s","file":"util.c","command":"cc -Wall -Wextra -c util.c"}]\n' "$P" "$P" "$P" > "$P/compile_commands.json"
	(cd "$P" && git init -q -b trunk . && git add -A && git commit -qm init) || { fail "mkproj $P"; return 1; }
	if command -v make >/dev/null && command -v cc >/dev/null; then
		(cd "$P" && make -s >/dev/null 2>&1 && ./points >/dev/null && make -s clean >/dev/null) || fail "mkproj: $P does not build"
	fi
}

# mkmany DIR: 60 small files under DIR/many, committed
mkmany() {
	mkdir -p "$1/many"
	i=1; while [ $i -le 60 ]; do printf 'int f%d(int x)\n{\n\treturn x + %d;\n}\n' $i $i > "$1/many/m$i.c"; i=$((i + 1)); done
	(cd "$1" && git add -A && git commit -qm many)
}

# mkbig FILE: a 50k-line C file; every 125th function has an error (50 diagnostics)
mkbig() {
	awk 'BEGIN { print "#include <stdio.h>"; for (i = 0; i < 6250; i++) { printf "int big%d(int x)\n{\n\tif (x > %d) {\n\t\treturn x - %s;\n\t}\n\treturn x + 1;\n}\n\n", i, i, (i % 125 == 7) ? "undefined_" i : "1" } }' > "$1"
}

# mktproj DIR: one-file C project (-xc), t.c with three diagnostics, w.c with one
mktproj() {
	P=${1:?}
	rm -rf "$P"; mkdir -p "$P"
	printf -- '-xc\n' > "$P/compile_flags.txt"
	cat > "$P/t.c" <<'EOF'
#include <stdio.h>

int main(void)
{
	int x = "str";
	foo(old, &tmp);
	printf("%d\n", x)
	return 0;
}
EOF
	printf 'int w(void) { return zz; }\n' > "$P/w.c"
}

# mkweird DIR: a git repo with awkward file names, some changed, some new
mkweird() {
	P=${1:?}
	rm -rf "$P"; mkdir -p "$P"
	(
		cd "$P" || exit 1
		git init -q -b trunk .
		printf 'one\ntwo\nthree\n' > f.txt
		printf 'one\ntwo\nthree\n' > 'sp ace.txt'
		printf 'one\ntwo\nthree\n' > 'é.txt'
		printf 'one\r\ntwo\r\nthree\r\n' > crlf.txt
		git add -A && git commit -qm init
		printf 'one\nTWO\nthree\n' > 'sp ace.txt'
		printf 'zero\none\ntwo\nthree\n' > 'é.txt'
		printf 'one\r\ntwo\r\n' > crlf.txt
		printf 'x\n' > '50%d #{x}.txt'
		printf 'x\n' > 'new "q".txt'
		printf 'x\n' > "it's.txt"
	)
}
