#!/usr/bin/env python3
"""Validate one skill folder: frontmatter, links, size, examples, secrets.

Run it as `python3 -I skills/scripts/quick_validate.py skills/<name>` from the repository
root (use -I so the current directory is never searched for modules).

The frontmatter rules are the ones in skill-creator's quick_validate.py: only the keys
name, description, license, allowed-tools and metadata; name is hyphen-case, at most 64
characters and equal to the folder name; the description has no angle brackets and is at
most 1024 characters (this repository keeps it under 600). This copy needs no YAML
library: the frontmatter here is two plain keys, and a plain value that a YAML parser
would reject (a colon followed by a space, or a space followed by a hash) is refused.
The other checks are this repository's: SKILL.md body at most 500 lines, every reference
linked from SKILL.md and present, a Contents line in long references, no README or
CHANGELOG in the skill, examples that decode, and no secret or user path.
"""

import json
import re
import sys
from pathlib import Path

ALLOWED_KEYS = {"name", "description", "license", "allowed-tools", "metadata"}
FORBIDDEN_FILES = {"README.md", "CHANGELOG.md", "INSTALL.md", "INSTALLATION_GUIDE.md"}
SECRET_PATTERNS = [
    re.compile(r"sk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"gh[pousr]_[A-Za-z0-9]{30,}"),
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}"),
    re.compile(r"/Us" r"ers/[A-Za-z0-9._-]+"),  # a user home path
]
MAX_BODY_LINES = 500
MAX_DESCRIPTION = 600
LONG_REFERENCE_LINES = 100


def parse_frontmatter(text):
    match = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not match:
        return None, "No YAML frontmatter found"
    values = {}
    key = None
    for line in match.group(1).split("\n"):
        if not line.strip():
            continue
        if line[0] in " \t":
            if key is None:
                return None, "Indented line before any key"
            values[key] = (values[key] + " " + line.strip()).strip()
            continue
        head, sep, rest = line.partition(":")
        if not sep or not re.match(r"^[A-Za-z][A-Za-z0-9-]*$", head):
            return None, f"Cannot read frontmatter line: {line[:40]!r}"
        key = head
        value = rest.strip()
        if value[:1] in "\"'":
            quote = value[0]
            if len(value) < 2 or value[-1] != quote:
                return None, f"Unterminated quoted value for {key}"
            value = value[1:-1]
        else:
            if ": " in value or " #" in value:
                return None, f"Value of {key} has a colon-space or space-hash; quote it or reword"
        values[key] = value
    return values, None


def check_frontmatter(folder, text):
    values, error = parse_frontmatter(text)
    if error:
        return error
    extra = set(values) - ALLOWED_KEYS
    if extra:
        return f"Unexpected key(s) in frontmatter: {', '.join(sorted(extra))}"
    for required in ("name", "description"):
        if required not in values:
            return f"Missing '{required}' in frontmatter"
    name = values["name"].strip()
    if not re.match(r"^[a-z0-9-]+$", name):
        return f"Name {name!r} must be hyphen-case"
    if name.startswith("-") or name.endswith("-") or "--" in name:
        return f"Name {name!r} cannot start or end with a hyphen or hold '--'"
    if len(name) > 64:
        return f"Name is too long ({len(name)} characters)"
    if name != folder.name:
        return f"Name {name!r} must equal the folder name {folder.name!r}"
    description = values["description"].strip()
    if not description:
        return "Description is empty"
    if "<" in description or ">" in description:
        return "Description cannot contain angle brackets"
    if len(description) > MAX_DESCRIPTION:
        return f"Description is {len(description)} characters; keep it under {MAX_DESCRIPTION}"
    if "Use when" not in description:
        return "Description must say when to use the skill ('Use when ...')"
    return None


def body_lines(text):
    match = re.match(r"^---\n.*?\n---\n", text, re.DOTALL)
    return text[match.end():].count("\n") if match else text.count("\n")


def check_links(folder, skill_text):
    problems = []
    linked = set()
    for target in re.findall(r"\]\((references/[^)#\s]+)(?:#[^)]*)?\)", skill_text):
        linked.add(target)
        if not (folder / target).is_file():
            problems.append(f"SKILL.md links a missing file: {target}")
    refs = folder / "references"
    if refs.is_dir():
        for path in sorted(refs.glob("*")):
            rel = f"references/{path.name}"
            if path.is_dir():
                problems.append(f"{rel}: references must be one level deep")
            elif rel not in linked:
                problems.append(f"{rel} is not linked from SKILL.md")
            else:
                lines = path.read_text(encoding="utf-8").split("\n")
                if len(lines) > LONG_REFERENCE_LINES and not any(
                    l.startswith("Contents") for l in lines[:6]
                ):
                    problems.append(f"{rel} has {len(lines)} lines and no Contents line at the top")
    return problems


def check_examples(folder):
    problems = []
    examples = folder / "examples"
    if not examples.is_dir():
        return problems
    for path in sorted(examples.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except ValueError as error:
            problems.append(f"{path.name}: not valid JSON ({error})")
            continue
        if not isinstance(data, dict) or not {"root", "elements"} <= set(data):
            problems.append(f"{path.name}: not a spec (needs root and elements)")
            continue
        elements = data["elements"]
        if data["root"] not in elements:
            problems.append(f"{path.name}: root is not an element")
        for key, element in elements.items():
            for child in element.get("children", []):
                if child not in elements:
                    problems.append(f"{path.name}: {key} lists a missing child {child}")
    for path in sorted(examples.glob("*.jsonl")):
        for number, line in enumerate(path.read_text(encoding="utf-8").split("\n"), 1):
            if not line.strip():
                continue
            problems += patch_problems(path.name, number, line)
    for path in sorted(examples.glob("*.txt")):
        inside = False
        patches = 0
        for number, line in enumerate(path.read_text(encoding="utf-8").split("\n"), 1):
            stripped = line.strip()
            if not inside and stripped.startswith("```spec"):
                inside = True
            elif inside and stripped == "```":
                inside = False
            elif inside and stripped:
                patches += 1
                problems += patch_problems(path.name, number, stripped)
        if patches == 0:
            problems.append(f"{path.name}: no spec fence with patches")
    return problems


def patch_problems(name, number, line):
    try:
        patch = json.loads(line)
    except ValueError as error:
        return [f"{name}:{number}: not valid JSON ({error})"]
    ops = {"add", "remove", "replace", "move", "copy", "test"}
    if not isinstance(patch, dict) or patch.get("op") not in ops or "path" not in patch:
        return [f"{name}:{number}: not a patch (op and path)"]
    return []


def check_files(folder):
    problems = []
    for path in sorted(folder.rglob("*")):
        if path.is_dir():
            continue
        if path.name in FORBIDDEN_FILES:
            problems.append(f"{path.relative_to(folder)}: not allowed inside a skill")
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            problems.append(f"{path.relative_to(folder)}: not UTF-8 text")
            continue
        for number, line in enumerate(text.split("\n"), 1):
            for pattern in SECRET_PATTERNS:
                if pattern.search(line):
                    problems.append(
                        f"{path.relative_to(folder)}:{number}: matches {pattern.pattern[:24]}"
                    )
    return problems


def validate(folder):
    skill = folder / "SKILL.md"
    if not skill.is_file():
        return ["SKILL.md not found"]
    text = skill.read_text(encoding="utf-8")
    problems = []
    error = check_frontmatter(folder, text)
    if error:
        problems.append(error)
    lines = body_lines(text)
    if lines > MAX_BODY_LINES:
        problems.append(f"SKILL.md body has {lines} lines (limit {MAX_BODY_LINES})")
    problems += check_links(folder, text)
    problems += check_examples(folder)
    problems += check_files(folder)
    return problems


def main(argv):
    if len(argv) != 2:
        print("Usage: python3 -I quick_validate.py <skill_directory>")
        return 2
    folder = Path(argv[1])
    problems = validate(folder)
    if problems:
        for problem in problems:
            print(f"{folder.name}: {problem}")
        return 1
    print(f"{folder.name}: skill is valid")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
