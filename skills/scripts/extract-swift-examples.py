#!/usr/bin/env python3
"""Extract the ```swift blocks of the skills, the README and the DocC articles into a scratch
Swift package (compile check).

Usage: extract-swift-examples.py <repo-root> <sources-dir>

Each block becomes its own module, `<sources-dir>/Sample_N/Sample_N.swift`, so two documents can
declare the same type name. Prints the module names last (`modules: Sample_1 Sample_2 ...`).

A block that declares a type or function becomes its own file. A block of statements is wrapped
in a throwing, main-actor function. A block with no import line gets `Foundation` and
`JSONRenderCore`. A block whose first line mentions `Package.swift` is a manifest snippet and is
skipped. A block whose first line starts with `// not compiled` (with a reason) is skipped: it
uses names that are internal to a package module. Prints one line per block and a total.
"""
import re
import sys
from pathlib import Path

repo = Path(sys.argv[1])
out = Path(sys.argv[2])
import shutil

for old in out.glob("Sample_*"):
    shutil.rmtree(old) if old.is_dir() else old.unlink()

decl = re.compile(
    r"^(public |private |internal |final |@MainActor |@Observable )*"
    r"(func|struct|enum|class|protocol|actor|extension|@JRComponent|@Test|#Preview)\b"
)
count = skipped = 0
report = []
files = (
    sorted(repo.glob("skills/*/**/*.md"))
    + sorted(repo.glob("skills/*/SKILL.md"))
    + [repo / "README.md"]
    + sorted(repo.glob("Sources/*/Documentation.docc/*.md"))
)
for md in files:
    text = md.read_text(encoding="utf-8")
    for index, match in enumerate(re.finditer(r"```swift\n(.*?)```", text, re.DOTALL)):
        body = match.group(1)
        label = f"{md.relative_to(repo)}#{index}"
        first = body.split("\n")[0]
        if "Package.swift" in first or first.startswith("// not compiled"):
            skipped += 1
            report.append(f"SKIP  {label}")
            continue
        lines = body.split("\n")
        imports = sorted({l for l in lines if l.startswith("import ")})
        if not imports:
            imports = ["import Foundation", "import JSONRenderCore"]
        rest = [l for l in lines if not l.startswith("import ")]
        while rest and not rest[0].strip():
            rest.pop(0)
        is_decl = any(decl.match(l) for l in rest)
        count += 1
        name = f"sample{count}"
        if is_decl:
            code = "\n".join(rest) + "\n"
        else:
            body_lines = "\n".join(("    " + l) if l.strip() else l for l in rest)
            code = f"@MainActor func {name}() async throws {{\n{body_lines}\n}}\n"
        header = f"// {label}\n" + "\n".join(imports) + "\n\n"
        module = out / f"Sample_{count}"
        module.mkdir()
        (module / f"Sample_{count}.swift").write_text(header + code, encoding="utf-8")
        report.append(f"BUILD {label} -> Sample_{count}.swift ({'decls' if is_decl else 'statements'})")
print("\n".join(report))
print(f"compiled blocks: {count}, skipped (manifest or module-internal snippets): {skipped}")
print("modules: " + " ".join(f"Sample_{i}" for i in range(1, count + 1)))
