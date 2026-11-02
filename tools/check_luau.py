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
        m = re.match(r"0[xX][0-9a-fA-F_]+|\d[\d_]*(\.\d*)?([eE][+-]?\d+)?|\.\d+", src[i:])
        if m and not (c == "." and src.startswith("..", i)):
            yield ("num", line); i += len(m.group(0)); continue
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
if not ok:
    sys.exit(1)


# ---------------------------------------------------------------------------
# Second pass: names used but never declared anywhere in the file.
# (Scope-insensitive, so it only catches typos / missing locals, not shadowing.)
KEYWORDS = set("""and break continue do else elseif end false for function if in local nil not or
repeat return then true until while export type typeof""".split())
GLOBALS = set("""game workspace script Instance Vector3 Vector2 CFrame Color3 UDim UDim2 Enum Random
math string table task os print warn error pcall xpcall require pairs ipairs next select tostring tonumber
type typeof setmetatable getmetatable rawget rawset rawequal unpack assert tick time ColorSequence
ColorSequenceKeypoint NumberSequence NumberSequenceKeypoint NumberRange TweenInfo RaycastParams
PhysicalProperties Ray Region3 Rect BrickColor utf8 bit32 coroutine debug buffer delay spawn wait self
OverlapParams Font Axes Faces""".split())

def names_check(path):
    src = path.read_text()
    toks = [t for t in tokens(src) if not t[0].isspace()]
    declared = set()
    used = []
    brace_depth = []
    for i, (tok, line) in enumerate(toks):
        prev = toks[i - 1][0] if i else None
        nxt = toks[i + 1][0] if i + 1 < len(toks) else None
        if tok == "local":
            j = i + 1
            if j < len(toks) and toks[j][0] == "function":
                declared.add(toks[j + 1][0]); continue
            while j < len(toks):
                declared.add(toks[j][0])
                if j + 1 < len(toks) and toks[j + 1][0] == ",":
                    j += 2
                else:
                    break
        elif tok == "function":
            # parameters
            j = i + 1
            while j < len(toks) and toks[j][0] != "(":
                j += 1
            j += 1
            while j < len(toks) and toks[j][0] != ")":
                if re.match(r"[A-Za-z_]", toks[j][0]):
                    declared.add(toks[j][0])
                j += 1
            if i + 1 < len(toks) and re.match(r"[A-Za-z_]", toks[i + 1][0]) and (i + 2 < len(toks) and toks[i + 2][0] == "("):
                declared.add(toks[i + 1][0])
        elif tok == "for":
            j = i + 1
            while j < len(toks) and toks[j][0] not in ("=", "in"):
                if re.match(r"[A-Za-z_]", toks[j][0]):
                    declared.add(toks[j][0])
                j += 1
    stack = []
    for i, (tok, line) in enumerate(toks):
        prev = toks[i - 1][0] if i else None
        nxt = toks[i + 1][0] if i + 1 < len(toks) else None
        nxt2 = toks[i + 2][0] if i + 2 < len(toks) else None
        if tok in "({[":
            stack.append(tok)
        elif tok in ")}]":
            if stack: stack.pop()
        if not re.match(r"[A-Za-z_][A-Za-z0-9_]*$", tok) or tok in KEYWORDS or tok in ("str", "num"):
            continue
        if prev in (".", ":"):
            continue
        if stack and stack[-1] == "{" and nxt == "=" and nxt2 != "=":
            continue  # table constructor key
        if tok not in declared and tok not in GLOBALS:
            used.append((tok, line))
    return used

bad = False
for f in sorted(ROOT.rglob("*.luau")):
    for name, line in names_check(f):
        bad = True
        print(f"UNDECLARED {f.relative_to(ROOT.parent)}:{line}: {name}")
if bad:
    sys.exit(1)
