"""Build Bunny64.rbxlx (a Roblox place file) from the src/ folder.

Mirrors default.project.json so you can open the game in Roblox Studio
without installing Rojo:  python3 tools/build_place.py
"""
import itertools, pathlib
from xml.sax.saxutils import escape

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "Bunny64.rbxlx"
_ref = itertools.count(1)


def ref():
    return f"RBX{next(_ref):08X}"


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(cls, name, props="", children=""):
    return (f'<Item class="{cls}" referent="{ref()}"><Properties>'
            f'<string name="Name">{escape(name)}</string>{props}</Properties>{children}</Item>')


def script(cls, name, source, children=""):
    props = f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
    if cls == "Script":
        props += '<token name="RunContext">0</token>'
    return item(cls, name, props, children)


def tree(path, name):
    """Turn a folder into Roblox instances following Rojo's conventions."""
    children = []
    init = None
    for f in sorted(path.iterdir()):
        if f.is_dir():
            children.append(tree(f, f.name))
        elif f.name in ("init.server.luau", "init.client.luau", "init.luau"):
            init = f
        elif f.name.endswith(".server.luau"):
            children.append(script("Script", f.name[:-len(".server.luau")], f.read_text()))
        elif f.name.endswith(".client.luau"):
            children.append(script("LocalScript", f.name[:-len(".client.luau")], f.read_text()))
        elif f.suffix == ".luau":
            children.append(script("ModuleScript", f.stem, f.read_text()))
    kids = "".join(children)
    if init is None:
        return item("Folder", name, children=kids)
    cls = {"init.server.luau": "Script", "init.client.luau": "LocalScript"}.get(init.name, "ModuleScript")
    return script(cls, name, init.read_text(), kids)


def main():
    src = ROOT / "src"
    body = "".join([
        item("Workspace", "Workspace",
             '<bool name="StreamingEnabled">false</bool><float name="Gravity">170</float>'),
        item("Lighting", "Lighting", '<token name="Technology">1</token>'),
        item("ReplicatedStorage", "ReplicatedStorage", children=tree(src / "shared", "Bunny64")),
        item("ServerScriptService", "ServerScriptService", children=tree(src / "server", "Bunny64Server")),
        item("StarterPlayer", "StarterPlayer",
             '<bool name="LoadCharacterAppearance">false</bool>'
             '<bool name="EnableMouseLockOption">false</bool>',
             item("StarterPlayerScripts", "StarterPlayerScripts", children=tree(src / "client", "Bunny64Client"))
             + item("StarterCharacterScripts", "StarterCharacterScripts",
                    children=script("LocalScript", "Animate", (src / "character" / "Animate.client.luau").read_text())
                    + script("Script", "Health", (src / "character" / "Health.server.luau").read_text()))),
    ])
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
           f'{body}</roblox>\n')
    OUT.write_text(xml)
    print(f"Wrote {OUT.relative_to(ROOT)} ({len(xml) // 1024} KB)")


if __name__ == "__main__":
    main()
