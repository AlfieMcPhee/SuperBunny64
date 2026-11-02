"""A real (if small) Luau syntax checker - a recursive-descent parser for
Lua 5.1 plus the Luau additions this project uses: compound assignment
(+= -= *= /= //= %= ^= ..=), `continue`, if-then-else expressions,
interpolated `backtick` strings and simple type annotations.

It reports the first syntax error in each file with a line number:
    python3 tools/luau_syntax.py
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "src"

KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in",
    "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
}
OPS = sorted([
    "...", "..=", "//=", "==", "~=", "<=", ">=", "..", "//", "::", "+=", "-=", "*=", "/=", "%=", "^=", "->",
    "+", "-", "*", "/", "%", "^", "#", "<", ">", "=", "(", ")", "{", "}", "[", "]", ";", ":", ",", ".", "?", "|", "&",
], key=len, reverse=True)
COMPOUND = {"+=", "-=", "*=", "/=", "//=", "%=", "^=", "..="}
BINARY = {
    "or": 1, "and": 2, "<": 3, ">": 3, "<=": 3, ">=": 3, "~=": 3, "==": 3,
    "..": 5, "+": 6, "-": 6, "*": 7, "/": 7, "//": 7, "%": 7, "^": 10,
}
RIGHT_ASSOC = {"..", "^"}
UNARY_PRIORITY = 8


class LuauSyntaxError(Exception):
    pass


def tokenize(src):
    toks = []
    i, n, line = 0, len(src), 1
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c in " \t\r":
            i += 1
            continue
        if src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                close = "]" + m.group(1) + "]"
                j = src.find(close, i)
                if j < 0:
                    raise LuauSyntaxError(f"line {line}: unfinished long comment")
                line += src.count("\n", i, j)
                i = j + len(close)
            else:
                j = src.find("\n", i)
                i = n if j < 0 else j
            continue
        m = re.match(r"\[(=*)\[", src[i:])
        if m:
            close = "]" + m.group(1) + "]"
            j = src.find(close, i)
            if j < 0:
                raise LuauSyntaxError(f"line {line}: unfinished long string")
            toks.append(("string", None, line))
            line += src.count("\n", i, j)
            i = j + len(close)
            continue
        if c in "\"'`":
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == "\\":
                    j += 1
                elif src[j] == "\n":
                    raise LuauSyntaxError(f"line {line}: unfinished string")
                j += 1
            if j >= n:
                raise LuauSyntaxError(f"line {line}: unfinished string")
            toks.append(("string", None, line))
            i = j + 1
            continue
        m = re.match(r"0[xX][0-9a-fA-F_]+|0[bB][01_]+|(\d[\d_]*(\.[\d_]*)?|\.\d[\d_]*)([eE][+-]?\d+)?", src[i:])
        if m and m.group(0):
            toks.append(("number", None, line))
            i += len(m.group(0))
            continue
        m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", src[i:])
        if m:
            w = m.group(0)
            toks.append(("keyword" if w in KEYWORDS else "name", w, line))
            i += len(w)
            continue
        for op in OPS:
            if src.startswith(op, i):
                toks.append(("op", op, line))
                i += len(op)
                break
        else:
            raise LuauSyntaxError(f"line {line}: unexpected character {c!r}")
    toks.append(("eof", None, line))
    return toks


class Parser:
    def __init__(self, toks):
        self.t = toks
        self.p = 0
        self.loop_depth = 0

    # helpers -----------------------------------------------------------------
    def peek(self, k=0):
        return self.t[min(self.p + k, len(self.t) - 1)]

    def is_(self, value, k=0):
        tok = self.peek(k)
        return tok[0] in ("op", "keyword") and tok[1] == value

    def accept(self, value):
        if self.is_(value):
            self.p += 1
            return True
        return False

    def expect(self, value, what=None):
        if not self.accept(value):
            tok = self.peek()
            got = tok[1] if tok[1] else tok[0]
            raise LuauSyntaxError(f"line {tok[2]}: expected '{value}'{' ' + what if what else ''} but found '{got}'")

    def name(self):
        tok = self.peek()
        if tok[0] != "name":
            got = tok[1] if tok[1] else tok[0]
            raise LuauSyntaxError(f"line {tok[2]}: expected a name but found '{got}'")
        self.p += 1
        return tok[1]

    def error(self, msg):
        raise LuauSyntaxError(f"line {self.peek()[2]}: {msg}")

    # types (skipped loosely) ------------------------------------------------------
    def skip_type(self):
        depth = 0
        while True:
            tok = self.peek()
            if tok[0] == "eof":
                return
            if tok[0] == "op" and tok[1] in "({[<":
                depth += 1
            elif tok[0] == "op" and tok[1] in ")}]>":
                if depth == 0:
                    return
                depth -= 1
            elif depth == 0 and tok[0] == "op" and tok[1] in (",", "=", ";"):
                return
            elif depth == 0 and tok[0] == "keyword":
                return
            elif depth == 0 and tok[0] in ("name", "keyword") and self.p > 0 and self.t[self.p - 1][0] in ("name",) and tok[2] != self.t[self.p - 1][2]:
                return
            self.p += 1

    def maybe_type(self):
        if self.accept(":"):
            self.skip_type()

    # blocks -----------------------------------------------------------------------
    def block(self, terminators):
        while True:
            tok = self.peek()
            if tok[0] == "eof" or (tok[0] == "keyword" and tok[1] in terminators):
                return
            if self.is_("return"):
                self.p += 1
                if not (self.peek()[0] == "eof" or (self.peek()[0] == "keyword" and self.peek()[1] in terminators) or self.is_(";")):
                    self.explist()
                self.accept(";")
                tok = self.peek()
                if not (tok[0] == "eof" or (tok[0] == "keyword" and tok[1] in terminators)):
                    self.error("'return' must be the last statement in a block")
                return
            self.statement()
            self.accept(";")

    def statement(self):
        tok = self.peek()
        if tok[0] == "keyword":
            kw = tok[1]
            if kw == "if":
                self.p += 1
                self.expr()
                self.expect("then", "after 'if' condition")
                self.block({"elseif", "else", "end"})
                while self.accept("elseif"):
                    self.expr()
                    self.expect("then", "after 'elseif' condition")
                    self.block({"elseif", "else", "end"})
                if self.accept("else"):
                    self.block({"end"})
                self.expect("end", "to close 'if'")
                return
            if kw == "while":
                self.p += 1
                self.expr()
                self.expect("do", "after 'while' condition")
                self.loop_depth += 1
                self.block({"end"})
                self.loop_depth -= 1
                self.expect("end", "to close 'while'")
                return
            if kw == "do":
                self.p += 1
                self.block({"end"})
                self.expect("end", "to close 'do'")
                return
            if kw == "for":
                self.p += 1
                self.name()
                self.maybe_type()
                if self.accept("="):
                    self.expr()
                    self.expect(",", "in numeric 'for'")
                    self.expr()
                    if self.accept(","):
                        self.expr()
                else:
                    while self.accept(","):
                        self.name()
                        self.maybe_type()
                    self.expect("in", "in generic 'for'")
                    self.explist()
                self.expect("do", "in 'for'")
                self.loop_depth += 1
                self.block({"end"})
                self.loop_depth -= 1
                self.expect("end", "to close 'for'")
                return
            if kw == "repeat":
                self.p += 1
                self.loop_depth += 1
                self.block({"until"})
                self.loop_depth -= 1
                self.expect("until", "to close 'repeat'")
                self.expr()
                return
            if kw == "function":
                self.p += 1
                self.name()
                while self.accept("."):
                    self.name()
                if self.accept(":"):
                    self.name()
                if not self.is_("("):
                    self.error("function names can only be dotted names (use `t[\"x\"] = function() ... end` for other keys)")
                self.funcbody()
                return
            if kw == "local":
                self.p += 1
                if self.accept("function"):
                    self.name()
                    self.funcbody()
                    return
                self.name()
                self.maybe_type()
                while self.accept(","):
                    self.name()
                    self.maybe_type()
                if self.accept("="):
                    self.explist()
                return
            if kw == "break":
                if self.loop_depth == 0:
                    self.error("'break' outside a loop")
                self.p += 1
                return
            self.error(f"unexpected '{kw}'")
        if tok[0] == "name" and tok[1] == "continue" and not (self.peek(1)[0] == "op" and self.peek(1)[1] in ("=", "(", ".", ":", "[", ",") or self.peek(1)[1] in COMPOUND):
            if self.loop_depth == 0:
                self.error("'continue' outside a loop")
            self.p += 1
            return
        if tok[0] == "name" and tok[1] in ("type", "export") and self.peek(1)[0] == "name":
            # type alias: type Foo = ...
            while self.peek()[0] != "eof" and not (self.peek()[0] == "op" and self.peek()[1] == "="):
                self.p += 1
            self.expect("=")
            self.skip_type()
            return
        # expression statement: assignment, compound assignment or call
        kind = self.suffixedexp()
        if self.is_("=") or self.is_(","):
            if kind != "var":
                self.error("cannot assign to a function call")
            while self.accept(","):
                if self.suffixedexp() != "var":
                    self.error("cannot assign to this expression")
            self.expect("=")
            self.explist()
            return
        nxt = self.peek()
        if nxt[0] == "op" and nxt[1] in COMPOUND:
            if kind != "var":
                self.error("compound assignment needs a variable")
            self.p += 1
            self.expr()
            return
        if kind != "call":
            self.error("syntax error: expected a statement (an assignment or a function call)")

    def funcbody(self):
        self.expect("(", "to start function parameters")
        if not self.is_(")"):
            while True:
                if self.accept("..."):
                    self.maybe_type()
                    break
                self.name()
                self.maybe_type()
                if not self.accept(","):
                    break
        self.expect(")", "to end function parameters")
        if self.accept(":"):
            self.skip_type()
        saved = self.loop_depth
        self.loop_depth = 0
        self.block({"end"})
        self.loop_depth = saved
        self.expect("end", "to close 'function'")

    # expressions --------------------------------------------------------------------
    def explist(self):
        self.expr()
        while self.accept(","):
            self.expr()

    def expr(self, limit=0):
        tok = self.peek()
        if (tok[0] == "keyword" and tok[1] == "not") or (tok[0] == "op" and tok[1] in ("-", "#")):
            self.p += 1
            self.expr(UNARY_PRIORITY)
        else:
            self.simpleexp()
        while True:
            tok = self.peek()
            op = tok[1] if tok[0] in ("op", "keyword") else None
            prec = BINARY.get(op)
            if prec is None or prec <= limit:
                break
            self.p += 1
            self.expr(prec - 1 if op in RIGHT_ASSOC else prec)
        # type assertion: expr :: Type
        if self.accept("::"):
            self.skip_type()

    def simpleexp(self):
        tok = self.peek()
        if tok[0] in ("number", "string"):
            self.p += 1
            return
        if tok[0] == "keyword" and tok[1] in ("nil", "true", "false"):
            self.p += 1
            return
        if self.accept("..."):
            return
        if self.accept("function"):
            self.funcbody()
            return
        if self.is_("{"):
            self.table()
            return
        if self.accept("if"):
            self.expr()
            self.expect("then", "in if-expression")
            self.expr()
            while self.accept("elseif"):
                self.expr()
                self.expect("then", "in if-expression")
                self.expr()
            self.expect("else", "in if-expression")
            self.expr()
            return
        self.suffixedexp()

    def primaryexp(self):
        tok = self.peek()
        if tok[0] == "name":
            self.p += 1
            return "var"
        if self.accept("("):
            self.expr()
            self.expect(")", "to close '('")
            return "paren"
        got = tok[1] if tok[1] else tok[0]
        self.error(f"unexpected '{got}' in expression")

    def suffixedexp(self):
        kind = self.primaryexp()
        while True:
            if self.accept("."):
                self.name()
                kind = "var"
            elif self.accept("["):
                self.expr()
                self.expect("]")
                kind = "var"
            elif self.accept(":"):
                self.name()
                self.args()
                kind = "call"
            elif self.is_("(") or self.is_("{") or self.peek()[0] == "string":
                self.args()
                kind = "call"
            else:
                return kind

    def args(self):
        if self.peek()[0] == "string":
            self.p += 1
        elif self.is_("{"):
            self.table()
        else:
            self.expect("(")
            if not self.is_(")"):
                self.explist()
            self.expect(")", "to close call arguments")

    def table(self):
        self.expect("{")
        while not self.is_("}"):
            if self.accept("["):
                self.expr()
                self.expect("]")
                self.expect("=")
                self.expr()
            elif self.peek()[0] == "name" and self.is_("=", 1):
                self.p += 2
                self.expr()
            else:
                self.expr()
            if not (self.accept(",") or self.accept(";")):
                break
        self.expect("}", "to close table")


def check(path):
    toks = tokenize(path.read_text())
    parser = Parser(toks)
    parser.block(set())
    if parser.peek()[0] != "eof":
        tok = parser.peek()
        raise LuauSyntaxError(f"line {tok[2]}: unexpected '{tok[1]}'")


def main():
    ok = True
    for f in sorted(ROOT.rglob("*.luau")):
        try:
            check(f)
        except LuauSyntaxError as e:
            ok = False
            print(f"SYNTAX {f.relative_to(ROOT.parent)}: {e}")
    if ok:
        print("syntax ok")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
