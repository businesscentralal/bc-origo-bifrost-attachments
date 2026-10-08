"""Fail-closed compiler/NAVX evidence checks for the actual AL-Go hooks (#78).

This reader validates package content, not Authenticode trust. The PowerShell
entry point alone obtains a Windows NAVX signature verdict for shipping output.
"""

import argparse
import hashlib
import io
import json
import re
import struct
import sys
import zipfile
import zlib
from pathlib import Path
from xml.etree import ElementTree as ET


class GateError(ValueError):
    """Evidence is missing, incompatible, stale or not clean."""


def require(condition, message):
    if not condition:
        raise GateError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def file_hash(path):
    return digest(Path(path).read_bytes())


def read_log(data):
    """Decode actual compiler/Actions output, rejecting undecodable evidence."""
    encoding = "utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig"
    try:
        return data.decode(encoding)
    except UnicodeError as exc:
        raise GateError("Invalid compiler output encoding") from exc


def compile_spans(text):
    """Require a compiler banner and paired positive-count compile for each span.

    Multiple translation/final compiles are retained; only the last span can
    satisfy a PostCompileApp receipt. No old completion masks a later truncation.
    """
    require(text.strip(), "Empty compiler output")
    spans, opened, compiler = [], None, None
    for original in text.splitlines():
        line = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", original)
        line = re.sub(r"^\d{4}-\d{2}-\d{2}T\S+Z\s+", "", line).strip()
        diagnostic = (
            r"(?:^|\):\s*)(?:warning|error)\s+[A-Z]{2,3}\d{4}\s*:"
            r"|^::(?:warning|error)(?:\s|::)|^##\[(?:warning|error)\]"
            r"|^##vso\[task\.(?:logissue\s+type=(?:warning|error)|complete\s+result=(?:Failed|SucceededWithIssues))"
            r"|App generation failed|Retrying without Cops"
        )
        require(not re.search(diagnostic, line, re.I), "Compiler/pipeline diagnostic present")
        match = re.match(r"Microsoft \(R\) AL Compiler version (\S+)", line)
        if match:
            require(opened is None and compiler is None, "Unpaired compiler banner")
            compiler = match[1]
        match = re.match(r"Compilation started for project '([^']+)' containing '(\d+)' files", line)
        if match:
            require(opened is None and compiler is not None, "Missing compiler or nested compilation")
            require(int(match[2]) > 0, "Compilation contains no sources")
            opened = {"project": match[1], "sourceCount": int(match[2]), "compilerVersion": compiler}
            compiler = None
        if re.match(r"Compilation ended\b", line):
            require(opened is not None, "Orphan compiler completion")
            spans.append(opened)
            opened = None
    require(opened is None and compiler is None, "Truncated final compilation")
    require(spans, "No complete compilation")
    return spans


def package_info(path):
    """Read the declared NAVX payload, never search an arbitrary file for PK.

    The BC compiler's NAVX v2 header is 40 bytes, bracketed by NAVX, with
    little-endian uint64 payload size at offset 28. Signed packages append a
    signature after that payload. Its presence is NOT signature verification.
    """
    path = Path(path)
    require(path.is_file(), "Missing package")
    data = path.read_bytes()
    require(len(data) >= 40 and data[:4] == b"NAVX" and data[36:40] == b"NAVX", "Invalid NAVX header")
    header_size, version = struct.unpack_from("<II", data, 4)
    length = struct.unpack_from("<Q", data, 28)[0]
    require(header_size == 40 and version == 2, "Unsupported NAVX header version")
    require(0 < length <= len(data) - 40 and data[40:44] == b"PK\x03\x04", "Invalid NAVX payload length/header")
    try:
        with zipfile.ZipFile(io.BytesIO(data[40:40 + length])) as archive:
            names = archive.namelist()
            require(len(names) == len(set(names)), "Duplicate package entries")
            require(names.count("NavxManifest.xml") == 1, "Missing/duplicate NAVX manifest")
            require(archive.testzip() is None, "Corrupt package CRC")
            manifest = archive.read("NavxManifest.xml")
            require(b"<!DOCTYPE" not in manifest.upper() and b"<!ENTITY" not in manifest.upper(), "Unsafe manifest XML")
            root = ET.fromstring(manifest)
            namespace = "{http://schemas.microsoft.com/navx/2015/manifest}"
            require(root.tag == namespace + "Package", "Invalid manifest root/namespace")

            def one(name):
                nodes = root.findall(namespace + name)
                require(len(nodes) == 1, "Missing/duplicate manifest " + name)
                return nodes[0]

            app, friends = one("App"), one("InternalsVisibleTo")
            source_nodes, build_nodes = root.findall(namespace + "Source"), root.findall(namespace + "Build")
            require(len(source_nodes) <= 1 and len(build_nodes) <= 1, "Duplicate source/build metadata")
            source = source_nodes[0] if source_nodes else ET.Element("Source")
            build = build_nodes[0] if build_nodes else ET.Element("Build")
            identity = {key.lower(): app.get(key, "") for key in ("Id", "Publisher", "Name", "Version")}
            require(all(identity.values()), "Incomplete package identity")
            grants = []
            for friend in friends:
                require(friend.tag == namespace + "Module", "Unknown friend element")
                grant = {key.lower(): friend.get(key, "") for key in ("Id", "Publisher", "Name")}
                require(all(grant.values()), "Incomplete friend identity")
                grants.append(grant)
            entries = [{"name": item.filename, "sha256": digest(archive.read(item))}
                       for item in sorted(archive.infolist(), key=lambda item: item.filename)]
    except (zipfile.BadZipFile, ET.ParseError, RuntimeError, OSError, zlib.error) as exc:
        raise GateError("Invalid compiled NAVX payload/manifest") from exc
    return {"identity": identity, "friends": grants, "sourceCommit": source.get("Commit", ""),
            "compilerVersion": build.get("CompilerVersion", ""), "buildUrl": build.get("Url", ""),
            "sha256": digest(data), "contentSha256": digest(json.dumps(entries, sort_keys=True).encode()),
            "bytes": len(data), "signatureTailBytes": len(data) - 40 - length}


def check_package(info, expected, mode, app_type, friend, source_commit=None):
    require(info["identity"] == {k: expected[k] for k in ("id", "publisher", "name", "version")}, "Wrong package identity/version")
    expected_grants = [friend] if mode == "Test" and app_type == "app" else []
    require(info["friends"] == expected_grants, "Wrong/missing/surviving compiled friend grants")
    if source_commit is not None:
        require(info["sourceCommit"] == source_commit, "Wrong compiled source commit")


def validate_parameters(params):
    for cop in ("enableCodeCop", "enableUICop", "enableAppSourceCop"):
        require(params.get(cop) is True, "Final analyzer disabled/missing: " + cop)
    require(params.get("failOn") == "warning", "Final failOn must be warning")
    require(params.get("escapeFromCops") is False, "Analyzer fallback not ruled out")
    require(params.get("workspaceCompilation") is False, "Workspace hook bypass unsupported")
    require(params.get("rulesetValidated") is True, "Final ruleset not validated")
    for name in ("compiler", "CodeCop", "UICop", "AppSourceCop", "Analyzers.Common", "helper", "alpacaOverride"):
        item = params.get("tools", {}).get(name, {})
        require(re.fullmatch(r"[a-f0-9]{64}", item.get("sha256", "")) is not None,
                "Missing compiler/analyzer/helper hash: " + name)
    require(params.get("compilerVersion"), "Missing compiler version")


DEPENDENCY_SYMBOL_LIMIT = 128
COMPILER_SYMBOL_LIMIT = 512


def symbol_inventory(folder, limit=DEPENDENCY_SYMBOL_LIMIT):
    """Bound actual on-disk receipts; reject incomplete or duplicate identities."""
    folder = Path(folder)
    require(folder.is_dir(), "Actual symbol folder absent")
    paths = sorted(folder.glob("*.app"))
    require(len(paths) <= limit, f"Symbol inventory exceeds {limit} packages")
    result, identities = [], set()
    for path in paths:
        require(path.stat().st_size <= 128 * 1024 * 1024, "Symbol package exceeds 128 MiB")
        info = package_info(path)
        identity = tuple(info["identity"][k].lower() for k in ("id", "version"))
        require(identity not in identities, "Duplicate symbol identity/version")
        identities.add(identity)
        result.append({"file": path.name, **info})
    return result


def reconcile_symbols(snapshot, request, output):
    """Check boundary observations, not unobservable transient compiler consumption."""
    require(snapshot["symbolsFolder"] == str(Path(request["symbolsFolder"]).resolve()), "Changed symbol cache path")
    require(snapshot["compilerSymbolsFolder"] == str(Path(request["compilerSymbolsFolder"]).resolve()),
            "Changed compiler symbol path")
    compiler = symbol_inventory(request["compilerSymbolsFolder"], COMPILER_SYMBOL_LIMIT)
    require(compiler == snapshot["compilerSymbols"], "Compiler-folder inputs changed during helper call")
    final = symbol_inventory(request["symbolsFolder"])
    before = {s["file"]: s for s in snapshot["symbols"]}
    prepared = {s["file"]: s for s in compiler}
    after = {s["file"]: s for s in final}
    for name, info in before.items():
        require(after.get(name) == info, "Pre-existing symbol changed or disappeared: " + name)
    additions, copies = [], []
    for name, info in after.items():
        if name in before:
            continue
        if info["identity"]["id"].lower() == output["identity"]["id"].lower():
            require(info["sha256"] == output["sha256"], "Unexpected self/output symbol bytes")
            copies.append(info)
        else:
            require(prepared.get(name) == info, "Unattributed helper symbol addition: " + name)
            additions.append(info)
    require(len(copies) == 1, "Missing/ambiguous exact helper output-copy delta")
    return {"before": snapshot["symbols"], "compilerBeforeAndAfter": compiler,
            "after": final, "preparationAdditions": additions, "outputCopy": copies[0],
            "consumedInputsCertified": False}


def _before_compile(root, request):
    """Snapshot the symbol cache BEFORE helper CopyAppToSymbolsFolder changes it."""
    root = Path(root)
    context = request["context"]
    directory = root / ".buildartifacts/AppSourceGate" / context["mode"]
    state = json.loads((directory / "state.json").read_text(encoding="utf-8-sig"))
    require(state["context"] == context, "Wrong precompiler run context")
    manifest = json.loads(Path(request["manifest"]).read_text(encoding="utf-8-sig"))
    product = json.loads((root / "app/app.json").read_text(encoding="utf-8-sig"))
    test = json.loads((root / "test/app.json").read_text(encoding="utf-8-sig"))
    require(manifest["id"] in (product["id"], test["id"]), "Unexpected compilation project")
    app_type = "app" if manifest["id"] == product["id"] else "testApp"
    symbols = symbol_inventory(request["symbolsFolder"])
    compiler_symbols = symbol_inventory(request["compilerSymbolsFolder"], COMPILER_SYMBOL_LIMIT)
    for symbol in symbols + compiler_symbols:
        require(symbol["identity"]["id"].lower() != manifest["id"].lower(),
                "Product self-app in actual PRECOMPILE symbol cache")
    require(symbols, "Empty actual precompile symbol inventory")
    foundation = [s for s in symbols if s["identity"]["id"] == "7505e808-6e52-4b96-a328-82573391297a"]
    require(len(foundation) == 1 and foundation[0]["sha256"] ==
            "5901bebe66b44e91ed6110620e62ee45d122ba9e0378dcfda4aeef4d00d3ae0f",
            "Missing/ambiguous/unapproved Foundation input bytes")
    if app_type == "testApp":
        require("app" in state["receipts"], "Test compile before product receipt")
        products = [s for s in symbols if s["identity"]["id"] == product["id"]]
        require(len(products) == 1 and products[0]["sha256"] == state["receipts"]["app"]["package"]["sha256"],
                "Test does not consume exact just-built product")
    for symbol in compiler_symbols:
        if symbol["identity"]["id"].lower() == foundation[0]["identity"]["id"].lower():
            require(symbol["sha256"] == foundation[0]["sha256"], "Unapproved compiler-folder Foundation bytes")
        if app_type == "testApp" and symbol["identity"]["id"].lower() == product["id"].lower():
            require(symbol["sha256"] == state["receipts"]["app"]["package"]["sha256"], "Wrong compiler-folder Test product")
    snapshot = {"context": context, "kind": request["kind"], "appType": app_type, "symbols": symbols,
                "symbolsFolder": str(Path(request["symbolsFolder"]).resolve()),
                "compilerSymbolsFolder": str(Path(request["compilerSymbolsFolder"]).resolve()),
                "compilerSymbols": compiler_symbols}
    (directory / "before.json").write_text(json.dumps(snapshot, indent=2) + "\n")
    return snapshot
