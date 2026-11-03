"""Check property / method / enum names against Roblox's API dump.

Catches the kind of mistake that only shows up inside Roblox at run time:
setting a property that doesn't exist on that class, calling a method a
class doesn't have, or naming an Enum item that isn't real.

Usage:
    python3 tools/check_roblox_api.py path/to/API-Dump.json

(The dump is published at
https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json)

It understands:
    local x = Instance.new("Class")      then x.Prop = ..., x:Method(...)
    B.make("Class", { Prop = ... })       (the world builder's helper)
    local S = game:GetService("Service") then S:Method(...), S.Event:...
    Enum.Type.Item
It's a heuristic (it follows the latest assignment of each name in a file),
so treat its output as "look here", not gospel.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "src"


def load(path):
    dump = json.loads(pathlib.Path(path).read_text())
    classes = {}
    for c in dump["Classes"]:
        classes[c["Name"]] = c
    members = {}

    def all_members(name):
        if name in members:
            return members[name]
        c = classes.get(name)
        if not c:
            return set()
        out = {m["Name"] for m in c.get("Members", [])}
        sup = c.get("Superclass")
        if sup and sup != "<<<ROOT>>>":
            out |= all_members(sup)
        members[name] = out
        return out

    for name in classes:
        all_members(name)
    enums = {e["Name"]: {i["Name"] for i in e.get("Items", [])} for e in dump["Enums"]}
    return members, enums


def strip(src):
    src = re.sub(r"--\[(=*)\[.*?\]\1\]", lambda m: "\n" * m.group(0).count("\n"), src, flags=re.S)
    src = re.sub(r"--[^\n]*", "", src)
    src = re.sub(r"\[(=*)\[.*?\]\1\]", lambda m: '""' + "\n" * m.group(0).count("\n"), src, flags=re.S)
    src = re.sub(r'"(\\.|[^"\\\n])*"', lambda m: m.group(0) if re.fullmatch(r'"[A-Za-z][A-Za-z0-9]*"', m.group(0)) else '""', src)
    src = re.sub(r"'(\\.|[^'\\\n])*'", "''", src)
    return src


def table_keys(src, start):
    """Top-level `key =` names of the table literal starting at src[start] == '{'."""
    depth, i, keys = 0, start, []
    while i < len(src):
        c = src[i]
        if c in "({[":
            depth += 1
        elif c in ")}]":
            depth -= 1
            if depth == 0:
                break
        elif depth == 1:
            m = re.match(r"([A-Za-z_]\w*)\s*=(?!=)", src[i:])
            if m and (i == 0 or not re.match(r"[\w.]", src[i - 1])):
                keys.append(m.group(1))
                i += len(m.group(0))
                continue
        i += 1
    return keys


def check_file(path, members, enums):
    problems = []
    src = strip(path.read_text())
    lines = src.split("\n")
    kinds = {}  # var name -> class name (latest assignment wins)
    for n, line in enumerate(lines, 1):
        for m in re.finditer(r"\b(?:local\s+)?([A-Za-z_]\w*)\s*=\s*Instance\.new\(\"(\w+)\"", line):
            kinds[m.group(1)] = m.group(2)
        for m in re.finditer(r"\b(?:local\s+)?([A-Za-z_]\w*)\s*=\s*game:GetService\(\"(\w+)\"\)", line):
            kinds[m.group(1)] = m.group(2)
        # a name reassigned to something else: forget what we knew
        for m in re.finditer(r"\b(?:local\s+)?([A-Za-z_]\w*)\s*=\s*(?!Instance\.new|game:GetService)[^=]", line):
            name = m.group(1)
            if name in kinds and not re.search(r"\b" + name + r"\s*=\s*(Instance\.new|game:GetService)", line):
                if not re.search(r"\.\s*" + name + r"\s*=", line):
                    del kinds[name]
        # loop variables and function parameters are something else entirely
        for m in re.finditer(r"\bfor\s+([\w\s,]+?)\s+in\b", line):
            for name in re.findall(r"\w+", m.group(1)):
                kinds.pop(name, None)
        for m in re.finditer(r"\bfunction\b[^(]*\(([^)]*)\)", line):
            for name in re.findall(r"\w+", m.group(1)):
                kinds.pop(name, None)
        for m in re.finditer(r"(?<![.\w])([A-Za-z_]\w*)\s*([.:])\s*([A-Za-z_]\w*)", line):
            var, sep, member = m.groups()
            cls = kinds.get(var)
            if cls and cls in members and member not in members[cls]:
                problems.append(f"{path.relative_to(ROOT.parent)}:{n}: {cls} has no member '{member}' ({var}{sep}{member})")
        for m in re.finditer(r"\bEnum\.(\w+)\.(\w+)", line):
            enum, item = m.groups()
            if enum not in enums:
                problems.append(f"{path.relative_to(ROOT.parent)}:{n}: unknown enum Enum.{enum}")
            elif item not in enums[enum] and item not in ("GetEnumItems", "FromName", "FromValue"):
                problems.append(f"{path.relative_to(ROOT.parent)}:{n}: Enum.{enum} has no item '{item}'")
    # B.make("Class", { Prop = ... }) and the Part-making helpers that take a props table
    helpers = [(m, m.group(1)) for m in re.finditer(r"\bB\.make\(\"(\w+)\",\s*\{", src)]
    helpers += [(m, "Part") for m in re.finditer(r"\bnewPart\(\{", src)]
    helpers += [(m, "Part") for m in re.finditer(r"\bpart\(model,\s*\{", src)]
    helpers += [(m, "Part") for m in re.finditer(r"\bdecorPart\(\{", src)]
    for m, cls in helpers:
        line_no = src.count("\n", 0, m.start()) + 1
        for key in table_keys(src, m.end() - 1):
            if cls in members and key not in members[cls]:
                problems.append(f"{path.relative_to(ROOT.parent)}:{line_no}: {cls} has no property '{key}' (B.make)")
    return problems


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    members, enums = load(sys.argv[1])
    problems = []
    for f in sorted(ROOT.rglob("*.luau")):
        problems += check_file(f, members, enums)
    for p in problems:
        print("API", p)
    print(f"{len(problems)} possible problem(s)")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
