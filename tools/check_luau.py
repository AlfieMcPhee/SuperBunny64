"""Lightweight sanity check for the Luau sources (no Roblox tools required).

Tokenizes each file (skipping strings and comments) and verifies that
block keywords and brackets balance. It does not replace Studio's script
analysis, but it catches the most common structural typos.
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "src"

def tokens(src):
    i, n, line = 0, len(src), 1
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1; i += 1; continue
        if src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                close = "]" + m.group(1) + "]"
                j = src.find(close, i)
                if j < 0: raise SyntaxError(f"line {line}: unclosed block comment")
                line += src.count("\n", i, j); i = j + len(close); continue
            j = src.find("\n", i); i = n if j < 0 else j; continue
        m = re.match(r"\[(=*)\[", src[i:])
        if m:
            close = "]" + m.group(1) + "]"
            j = src.find(close, i)
            if j < 0: raise SyntaxError(f"line {line}: unclosed long string")
            line += src.count("\n", i, j); i = j + len(close); yield ("str", line); continue
        if c in "\"'`":
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == "\\": j += 1
                if src[j] == "\n": raise SyntaxError(f"line {line}: unterminated string")
                j += 1
            i = j + 1; yield ("str", line); continue
        m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", src[i:])
        if m:
            yield (m.group(0), line); i += len(m.group(0)); continue
        yield (c, line); i += 1

def check(path):
    src = path.read_text()
    stack = []
    pairs = {")": "(", "]": "[", "}": "{"}
    prev = None
    for tok, line in tokens(src):
        if tok in ("function", "if", "do", "repeat") or tok in "([{":
            # `for`/`while` headers are closed by their `do`
            if not (tok == "function" and prev == "."):
                stack.append((tok, line))
        elif tok == "end":
            if not stack or stack[-1][0] not in ("function", "if", "do"):
                raise SyntaxError(f"line {line}: unexpected 'end' (open: {stack[-1] if stack else None})")
            stack.pop()
        elif tok == "until":
            if not stack or stack[-1][0] != "repeat":
                raise SyntaxError(f"line {line}: unexpected 'until'")
            stack.pop()
        elif tok in pairs:
            if not stack or stack[-1][0] != pairs[tok]:
                raise SyntaxError(f"line {line}: unexpected '{tok}' (open: {stack[-1] if stack else None})")
            stack.pop()
        elif tok == "then":
            if not stack or stack[-1][0] != "if":
                raise SyntaxError(f"line {line}: 'then' without 'if'")
        prev = tok
    if stack:
        raise SyntaxError(f"unclosed {stack[-1][0]!r} opened on line {stack[-1][1]}")

ok = True
for f in sorted(ROOT.rglob("*.luau")):
    try:
        check(f)
        print("ok  ", f.relative_to(ROOT.parent))
    except SyntaxError as e:
        ok = False
        print("FAIL", f.relative_to(ROOT.parent), e)
sys.exit(0 if ok else 1)
