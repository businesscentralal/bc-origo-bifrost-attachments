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
            # Microsoft symbol packages may have no build/source provenance. The
            # produced product/test MUST have it (checked against current context).
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
    symbols = []
    for path in sorted(Path(request["symbolsFolder"]).glob("*.app")):
        symbol = package_info(path)
        require(app_type != "app" or symbol["identity"]["id"].lower() != product["id"].lower(),
                "Product self-app in actual PRECOMPILE symbol cache")
        symbols.append({"file": path.name, **symbol})
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
    snapshot = {"context": context, "kind": request["kind"], "appType": app_type, "symbols": symbols}
    (directory / "before.json").write_text(json.dumps(snapshot, indent=2) + "\n")
    return snapshot


def rejected_receipt(output, context, paths):
    """Record bounded disk identities only; never dump Settings or credentials."""
    inventory = []
    for path in list(paths)[:128]:
        path = Path(path)
        item = {"path": str(path), "present": path.is_file()}
        if path.is_file() and path.stat().st_size <= 128 * 1024 * 1024:
            item.update(sha256=file_hash(path), bytes=path.stat().st_size)
            try:
                info = package_info(path)
                item.update({k: info[k] for k in ("identity", "friends", "sourceCommit", "compilerVersion")})
                # Build URLs may contain secrets in malformed/untrusted manifests.
                url = info["buildUrl"]
                item["buildUrl"] = url if re.fullmatch(r"https://github.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/actions/runs/[0-9]+", url) else "redacted-unrecognized-build-url"
            except (GateError, OSError, ValueError):
                item["manifestValid"] = False
        inventory.append(item)
    allowed = {k: context[k] for k in ("run", "attempt", "job", "sourceCommit", "checkoutSha", "mode") if k in context}
    Path(output).write_text(json.dumps({"accepted": False, "context": allowed, "inputs": inventory,
                                      "truncated": len(paths) > 128, "signatureTrustVerified": False}, indent=2) + "\n")


def before_compile(root, request):
    """Keep the original failure while recording bounded allowlisted disk inputs."""
    try:
        return _before_compile(root, request)
    except (GateError, OSError, KeyError, ValueError):
        # Evidence failure must never replace or clear the original gate failure.
        try:
            context = request.get("context", {})
            directory = Path(root) / ".buildartifacts/AppSourceGate" / context.get("mode", "Unknown")
            directory.mkdir(parents=True, exist_ok=True)
            rejected_receipt(directory / "rejected-input.json", context,
                             sorted(Path(request["symbolsFolder"]).glob("*.app")))
        except (OSError, ValueError, KeyError):
            pass
        raise


def post_compile(root, request):
    """Consume only allowlisted data collected inside the actual post hook."""
    root = Path(root)
    context = request["context"]
    state_path = root / ".buildartifacts" / "AppSourceGate" / context["mode"] / "state.json"
    require(state_path.is_file(), "PipelineInitialize receipt missing")
    state = json.loads(state_path.read_text(encoding="utf-8-sig"))
    require(state["context"] == context, "Stale/wrong run, SHA, attempt, job or mode")
    require(context["mode"] in ("Default", "Test"), "Unsupported build mode")
    params = request["parameters"]
    validate_parameters(params)
    app_type = request["appType"]
    require(app_type in ("app", "testApp"), "Unexpected app type")
    require(context["mode"] == "Test" or app_type == "app", "Unexpected Default test compile")
    require(app_type not in state["receipts"], "Duplicate postcompile receipt")
    expected_path = root / ("app" if app_type == "app" else "test") / "app.json"
    expected = json.loads(expected_path.read_text(encoding="utf-8-sig"))
    friend_manifest = json.loads((root / "test" / "app.json").read_text(encoding="utf-8-sig"))
    friend = {k: friend_manifest[k] for k in ("id", "publisher", "name")}
    data = (root / "BuildOutput.txt").read_bytes()
    offset = state["logBytes"]
    require(len(data) > offset, "Missing/new compiler output")
    require(digest(data[:offset]) == state["logPrefixSha256"], "Compiler output replaced/truncated")
    spans = compile_spans(read_log(data[offset:]))
    require(spans[-1]["project"] == expected["name"], "Wrong final compilation project")
    require(spans[-1]["compilerVersion"] == params["compilerVersion"], "Compiler/banner mismatch")
    require(request["sourceFiles"] and spans[-1]["sourceCount"] == len(request["sourceFiles"]), "Source count/inventory mismatch")
    info = package_info(request["appFile"])
    check_package(info, expected, context["mode"], app_type, friend, context["sourceCommit"])
    require(info["compilerVersion"] == params["compilerVersion"], "Package/compiler mismatch")
    require(info["buildUrl"] == context["buildUrl"], "Stale package from different run")
    require(Path(request["appFile"]).stat().st_mtime_ns >= state["startedNs"], "Stale package timestamp")
    snapshot = json.loads((state_path.parent / "before.json").read_text(encoding="utf-8-sig"))
    require(snapshot["context"] == context and snapshot["appType"] == app_type and snapshot["kind"] == "final",
            "Missing/stale/translation-only actual precompile snapshot")
    isolated = (state_path.parent / "current-compile.txt").read_bytes()
    isolated_spans = compile_spans(read_log(isolated))
    require(len(isolated_spans) == 1 and isolated_spans[0] == spans[-1], "Wrong/missing isolated final compiler output")
    symbols = snapshot["symbols"]
    receipt = {"context": context, "appType": app_type, "parameters": params, "package": info,
               "logSha256": digest(data[offset:]), "isolatedLogSha256": digest(isolated), "spans": spans, "symbols": symbols,
               "sourceFiles": request["sourceFiles"]}
    state["receipts"][app_type] = receipt
    state["logBytes"], state["logPrefixSha256"] = len(data), digest(data)
    state_path.write_text(json.dumps(state, indent=2) + "\n")
    return receipt


def reconcile(root, context, stage, signature=None):
    """Check expected hooks and actual published artifact paths, also after Sign."""
    root = Path(root)
    directory = root / ".buildartifacts" / "AppSourceGate" / context["mode"]
    state = json.loads((directory / "state.json").read_text(encoding="utf-8-sig"))
    require(state["context"] == context, "Stale finalize context")
    expected = {"app", "testApp"} if context["mode"] == "Test" else {"app"}
    require(set(state["receipts"]) == expected, "Skipped/missing/unexpected compile hook")
    require(file_hash(root / "BuildOutput.txt") == state["logPrefixSha256"], "Unreceipted later compiler output")
    for relative, sha in state["hookHashes"].items():
        require(file_hash(root / relative) == sha, "Hook/tool displaced during pipeline")
    outputs = []
    for app_type in sorted(expected):
        receipt = state["receipts"][app_type]
        require(receipt["context"] == context, "Wrong receipt mode/run/SHA")
        validate_parameters(receipt["parameters"])
        for item in receipt["sourceFiles"]:
            require(file_hash(root / item["file"]) == item["sha256"], "Compiled AL source changed after receipt")
        folder = root / ".buildartifacts" / ("Apps" if app_type == "app" else "TestApps")
        files = list(folder.glob("*.app"))
        require(len(files) == 1, "Missing/ambiguous final package output")
        info = package_info(files[0])
        require(info["contentSha256"] == receipt["package"]["contentSha256"], "Final package content changed")
        require(stage == "signed" or info["sha256"] == receipt["package"]["sha256"], "Unsigned package bytes changed")
        if stage == "signed":
            require(context["mode"] == "Default", "Only Default shipping is signed")
            require(signature and signature.get("status") == "Valid" and signature.get("signerThumbprint")
                    and signature.get("provider") == "Windows Get-AuthenticodeSignature" and signature.get("sha256") == info["sha256"],
                    "Missing/invalid/unsupported NAVX signature verification")
        outputs.append({"file": str(files[0].relative_to(root)), **info})
    if stage != "finalize":
        finalized = json.loads((directory / "finalize.json").read_text(encoding="utf-8-sig"))
        require(finalized["context"] == context and finalized["stateSha256"] == file_hash(directory / "state.json"),
                "Missing/stale/displaced PipelineFinalize")
    result = {"context": context, "stage": stage, "stateSha256": file_hash(directory / "state.json"), "outputs": outputs}
    if signature:
        result["signature"] = signature
    (directory / (stage + ".json")).write_text(json.dumps(result, indent=2) + "\n")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["before", "post", "finalize", "pipeline", "signed", "package"])
    parser.add_argument("--root", type=Path)
    parser.add_argument("--input", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.action == "package":
            result = package_info(args.input)
        else:
            request = json.loads(args.input.read_text(encoding="utf-8-sig"))
            if args.action == "before":
                result = before_compile(args.root, request)
            elif args.action == "post":
                result = post_compile(args.root, request)
            else:
                result = reconcile(args.root, request["context"], args.action, request.get("signature"))
        # Receipts are files, not console dumps of pipeline settings or paths.
        print(json.dumps(result) if args.action == "package" else "AppSource gate: " + args.action + " passed")
        return 0
    except (GateError, OSError, KeyError, ValueError) as exc:
        print("AppSource gate failed: " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
