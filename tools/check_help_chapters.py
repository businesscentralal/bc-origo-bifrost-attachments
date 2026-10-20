"""Fail closed when a registered Attachments type omits first-call help (#160).

Checks source without a BC runtime. Native conformance also checks the actual
aggregated chapters. Live provenance is a separate acceptance requirement.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys


LITERAL = r"'((?:[^']|'')*)'"


def procedure(source: str, name: str) -> str:
    match = re.search(r"(?mi)^    (?:local )?procedure " + name + r"\(", source)
    if not match:
        return ""
    tail = source[match.end():]
    end = re.search(r"(?mi)^    (?:local )?procedure |^    \[EventSubscriber", tail)
    return source[match.start():match.end() + (end.start() if end else len(tail))]


def uncomment(source: str) -> str:
    # Preserve AL strings, including JSON and URLs, while removing comments.
    return re.sub(r"'(?:[^']|'')*'|//[^\n]*|/\*.*?\*/",
                  lambda m: m[0] if m[0].startswith("'") else "", source, flags=re.S)


def registrations(root: Path) -> dict[str, str]:
    result = {}
    for file in root.rglob("*.al"):
        source = uncomment(file.read_text(encoding="utf-8-sig"))
        if not re.search(r'enumextension\s+\d+.*extends\s+"Message Type ori"', source):
            continue
        for match in re.finditer(r'value\(\d+;\s*"([^"]+)"\)\s*\{([^{}]*)\}', source):
            binding = re.search(r'"Msg Contract ori"\s*=\s*"([^"]+)"', match[2])
            if not binding:
                raise ValueError(f"{match[1]} has no contract binding")
            if match[1] in result:
                raise ValueError(f"Duplicate message type {match[1]}")
            result[match[1]] = binding[1]
    if not result:
        raise ValueError("No registered message types found")
    return result


def chapter_present(source: str, objects: dict[str, str], chapter: str, name: str) -> bool:
    body = procedure(source, "Get" + chapter)
    # A stub, including a misleading success return after Clear(), is not a chapter.
    if not body or re.search(r"exit\(false\)", body, re.I):
        return False
    direct = r"Overview\s*:=\s*" + LITERAL if chapter == "Overview" else r"Examples\.Add\("
    if chapter == "Overview":
        literal = re.search(direct, body)
        if literal and literal[1].strip():
            return True
        label = re.search(r"Overview\s*:=\s*(\w+);", body)
        if label and re.search(r"\b" + label[1] + r"\s*:\s*Label\s+'[^']", body):
            return True
    elif re.search(direct, body):
        return bool(re.search(r"\.Example\(.*?'[^']", body, re.S))
    delegate = re.search(r"\b(\w+)\.Get" + chapter + r"\(\s*" + LITERAL + r"\s*\)", body)
    if not delegate or delegate[2].replace("''", "'") != name:
        return False
    owner = re.search(r"\b" + delegate[1] + r'\s*:\s*Codeunit\s+"([^"]+)"', body)
    if not owner or owner[1] not in objects:
        return False
    shared = procedure(objects[owner[1]], "Get" + chapter)
    # The shared builder must have a branch for this exact type, not just a fallback.
    branch = re.search(r"(?m)^            '" + re.escape(name) + r"':\s*\n(.*?)(?=^            '[^']+':|^        end;)", shared, re.S | re.M)
    if not branch:
        return False
    if chapter == "Overview":
        value = re.search(r"exit\(" + LITERAL + r"\)", branch[1])
        return bool(value and value[1].strip())
    return bool(re.search(r"Examples\.Add\(\w+\.Example\(", branch[1]))


def check(app: Path) -> tuple[int, list[str]]:
    root = app / "src"
    objects = {}
    for file in root.rglob("*.al"):
        source = uncomment(file.read_text(encoding="utf-8-sig"))
        obj = re.search(r'codeunit\s+\d+\s+"([^"]+)"', source)
        if obj:
            objects[obj[1]] = source
    types = registrations(root)
    problems = []
    for name, implementation in types.items():
        if implementation not in objects:
            problems.append(f"{name}: missing implementation {implementation}")
            continue
        for chapter in ("Overview", "Examples"):
            if not chapter_present(objects[implementation], objects, chapter, name):
                problems.append(f"{name}: missing or empty {chapter.lower()} chapter")
    return len(types), problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, default=Path(__file__).resolve().parents[1] / "app")
    args = parser.parse_args()
    try:
        count, problems = check(args.app)
    except (OSError, ValueError) as error:
        print(f"::error::{error}")
        return 1
    print(f"Checked {count} registered message types for overview and examples.")
    for problem in problems:
        print(f"::error::{problem}")
    return int(bool(problems))


if __name__ == "__main__":
    sys.exit(main())
