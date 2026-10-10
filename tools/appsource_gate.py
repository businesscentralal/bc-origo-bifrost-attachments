"""Fail-closed compiler/NAVX evidence checks for the actual AL-Go hooks (#78).

This reader validates package content, not Authenticode trust. The PowerShell
entry point alone obtains a Windows NAVX signature verdict for shipping output.
"""

import argparse
import concurrent.futures
import hashlib
import io
import json
import re
import shutil
import subprocess
import struct
import sys
import time
import tempfile
import uuid
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


CHUNK_BYTES = 1024 * 1024
PACKAGE_BYTES = 128 * 1024 * 1024
MANIFEST_BYTES = 16 * 1024 * 1024
PACKAGE_ENTRIES = 4096
INVENTORY_SECONDS = 60
MEASURED_PACKAGE_PROFILES = {
    "05d37036733b4df5ffaf31d3d779ec48af63465da6f694ff15a7e0b228abc1b8": {
        "identity": {"id": "437dbf0e-84ff-417a-965d-ed2bb9650972", "publisher": "Microsoft",
                     "name": "Base Application", "version": "29.0.54011.55935"},
        "maxEntries": 4096, "maxExpandedBytes": 512 * 1024 * 1024,
    },
    "10ebba923b6f8d3b6d676cc1f1db16a8a5d4519ff8ca4f45bbd2e778b52d289c": {
        "identity": {"id": "437dbf0e-84ff-417a-965d-ed2bb9650972", "publisher": "Microsoft",
                     "name": "Base Application", "version": "29.0.54011.55935"},
        "maxEntries": 16384, "maxExpandedBytes": 512 * 1024 * 1024,
    },
    "4e4aca03643b998452dc3c6e525ce9a611a804a7bd581bbe6734e33b22891c67": {
        "identity": {"id": "437dbf0e-84ff-417a-965d-ed2bb9650972", "publisher": "Microsoft",
                     "name": "Base Application", "version": "29.0.54011.55975"},
        "maxEntries": 4096, "maxExpandedBytes": 512 * 1024 * 1024,
    },
    "ab800f38121e7eda19d1fa65bee3915a8b31010f2d9a87800f4aeb023dba9d48": {
        "identity": {"id": "437dbf0e-84ff-417a-965d-ed2bb9650972", "publisher": "Microsoft",
                     "name": "Base Application", "version": "29.0.54011.55975"},
        "maxEntries": 16384, "maxExpandedBytes": 512 * 1024 * 1024,
    },
}
FOUNDATION_CANDIDATE = {
    "identity": {"id": "7505e808-6e52-4b96-a328-82573391297a", "publisher": "Origo",
                 "name": "Bifrost Foundation", "version": "28.0.3.530"},
    "sha256": "b95e0eccf7a4038531cea08f0441e757ac176c7c4ff06b1b8eb9d25ac0dd3a88",
    "sourceCommit": "8ec074f4ac69ac9bde15807cf16d21bee045332f",
    "buildUrl": "https://github.com/OrigoSoftwareSolutions/bc-origo-bifrost-core/actions/runs/37679390622",
    "compilerVersion": "18.1.43.7601",
    "artifactId": 11508979803,
    "archiveSha256": "21c6331c47d3134d1f3c8c77f240d021fa47710f6fbdebc974b733e0b708bad8",
}
SYMBOL_POLICIES = {
    "appCache": {"packages": 128, "bytes": 512 * 1024 * 1024},
    # Retained BC29 sample measures 1,863,664,153 expanded bytes across
    # envelope+embedded layers; keep compressed and expanded budgets distinct.
    "compilerCatalog": {"packages": 256, "bytes": 1024 * 1024 * 1024,
                        "expandedBytes": 4 * 1024 * 1024 * 1024},
}


def budget_check(deadline):
    require(time.monotonic() <= deadline, "Symbol measurement elapsed budget exceeded")


def file_hash(path, deadline=None):
    sha = hashlib.sha256()
    with Path(path).open("rb") as stream:
        while True:
            if deadline is not None:
                budget_check(deadline)
            chunk = stream.read(CHUNK_BYTES)
            if not chunk:
                break
            sha.update(chunk)
    return sha.hexdigest()


class PayloadView:
    """Seekable NAVX payload window; ZIP cannot inspect the signature tail."""

    def __init__(self, stream, offset, length):
        self.stream, self.offset, self.length, self.position = stream, offset, length, 0

    def seek(self, offset, whence=0):
        position = offset if whence == 0 else self.position + offset if whence == 1 else self.length + offset
        require(0 <= position <= self.length, "ZIP seek outside NAVX payload")
        self.position = position
        return position

    def tell(self):
        return self.position

    def seekable(self):
        return True

    def read(self, size=-1):
        size = self.length - self.position if size < 0 else min(size, self.length - self.position)
        self.stream.seek(self.offset + self.position)
        chunk = self.stream.read(size)
        require(len(chunk) == size, "Truncated NAVX payload")
        self.position += len(chunk)
        return chunk


def version_tuple(value):
    require(re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,3}", value or "") is not None,
            "Invalid dependency/package version")
    parts = tuple(int(part) for part in value.split("."))
    require(all(part <= 2147483647 for part in parts), "Version component out of range")
    return parts + (0,) * (4 - len(parts))


def identity_check(identity):
    require(all(identity.values()), "Incomplete package identity")
    try:
        uuid.UUID(identity["id"])
    except (ValueError, AttributeError) as exc:
        raise GateError("Invalid package/dependency AppId") from exc
    version_tuple(identity["version"])


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


def package_info(path, deadline=None, *, allow_ready_to_run=False):
    """Stream bounded NAVX content and metadata; signature presence is not trust."""
    path = Path(path)
    deadline = time.monotonic() + INVENTORY_SECONDS if deadline is None else deadline
    budget_check(deadline)
    require(path.is_file() and not path.is_symlink(), "Missing package or linked input")
    before = path.stat()
    require(before.st_size >= 40, "Invalid NAVX header")
    require(before.st_size <= PACKAGE_BYTES, "Package exceeds 128 MiB")
    try:
        with path.open("rb") as stream:
            header = stream.read(40)
            require(header[:4] == b"NAVX" and header[36:40] == b"NAVX", "Invalid NAVX header")
            header_size, version = struct.unpack_from("<II", header, 4)
            length = struct.unpack_from("<Q", header, 28)[0]
            require(header_size == 40 and version == 2, "Unsupported NAVX header version")
            require(0 < length <= before.st_size - 40 and stream.read(4) == b"PK\x03\x04",
                    "Invalid NAVX payload length/header")
            initial_hash = file_hash(path, deadline)
            profile = MEASURED_PACKAGE_PROFILES.get(initial_hash)
            max_entries = profile["maxEntries"] if profile else PACKAGE_ENTRIES
            max_expanded = profile["maxExpandedBytes"] if profile else PACKAGE_BYTES
            with zipfile.ZipFile(PayloadView(stream, 40, length)) as archive:
                items = archive.infolist()
                require(len(items) <= max_entries, "Package entry bound exceeded")
                names = [item.filename for item in items]
                require(len(names) == len(set(names)), "Duplicate package entries")
                require(not ("NavxManifest.xml" in names and "readytorunappmanifest.json" in names),
                        "Ambiguous NAVX/ReadyToRun manifests")
                if names.count("NavxManifest.xml") == 0 and allow_ready_to_run and "readytorunappmanifest.json" in names:
                    return ready_to_run_info(path, before, archive, items, initial_hash, length,
                                             deadline, max_expanded, profile)
                require(names.count("NavxManifest.xml") == 1, "Missing/duplicate NAVX manifest")
                expanded = sum(item.file_size for item in items)
                require(expanded <= max_expanded, "Package expanded-byte bound exceeded")
                require(archive.getinfo("NavxManifest.xml").file_size <= MANIFEST_BYTES,
                        "Manifest exceeds 16 MiB")
                entries, manifest = [], None
                for item in sorted(items, key=lambda item: item.filename):
                    sha, size, chunks = hashlib.sha256(), 0, []
                    with archive.open(item) as content:
                        while True:
                            budget_check(deadline)
                            chunk = content.read(CHUNK_BYTES)
                            if not chunk:
                                break
                            size += len(chunk)
                            require(size <= item.file_size and size <= max_expanded, "Expanded entry bound exceeded")
                            sha.update(chunk)
                            if item.filename == "NavxManifest.xml":
                                chunks.append(chunk)
                    require(size == item.file_size, "Truncated expanded entry")
                    entries.append({"name": item.filename, "sha256": sha.hexdigest()})
                    if item.filename == "NavxManifest.xml":
                        manifest = b"".join(chunks)
                xml_text = manifest.decode("utf-16" if manifest.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")
                require("<!DOCTYPE" not in xml_text.upper() and "<!ENTITY" not in xml_text.upper(), "Unsafe manifest XML")
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
                identity_check(identity)
                if profile:
                    require(identity == profile["identity"], "Measured package profile identity mismatch")
                grants = []
                for friend in friends:
                    require(friend.tag == namespace + "Module", "Unknown friend element")
                    grant = {key.lower(): friend.get(key, "") for key in ("Id", "Publisher", "Name")}
                    require(all(grant.values()), "Incomplete friend identity")
                    grants.append(grant)
                dependencies = []
                nodes = root.findall(namespace + "Dependencies")
                require(len(nodes) <= 1, "Duplicate dependency metadata")
                for node in nodes[0] if nodes else []:
                    require(node.tag == namespace + "Dependency", "Unknown dependency metadata")
                    dep = {key.lower(): node.get(key, "") for key in ("Id", "Publisher", "Name", "MinVersion")}
                    dep["id"] = dep["id"] or node.get("AppId", "")
                    dep["version"] = dep.pop("minversion") or node.get("Version", "")
                    identity_check(dep)
                    dependencies.append(dep)
                propagate = app.get("PropagateDependencies", "false").lower()
                require(propagate in ("true", "false"), "Invalid PropagateDependencies")
                # Build wall-clock timestamp is not a compiler input.
                # Translation packaging flags also differ between platform and
                # W1 artifacts without changing compiler symbols. Preserve all
                # other metadata, including Runtime/Target and feature flags.
                def compiler_manifest(node):
                    attrs = {k: v for k, v in node.attrib.items()
                             if not (node.tag == namespace + "Build" and k == "Timestamp")}
                    return [node.tag, sorted(attrs.items()), (node.text or "").strip(),
                            [compiler_manifest(child) for child in node
                             if not (node.tag == namespace + "Features" and
                                     child.tag == namespace + "Feature" and
                                     (child.text or "").strip() in ("TRANSLATIONFILE", "LCGTRANSLATIONFILE"))]]
                manifest_compiler_hash = digest(json.dumps(compiler_manifest(root), sort_keys=True).encode())
                application, platform = app.get("Application", ""), app.get("Platform", "")
                for value in (application, platform):
                    if value:
                        version_tuple(value)
        require(tuple(getattr(path.stat(), k) for k in ("st_dev", "st_ino", "st_size", "st_mtime_ns", "st_ctime_ns")) ==
                tuple(getattr(before, k) for k in ("st_dev", "st_ino", "st_size", "st_mtime_ns", "st_ctime_ns"))
                and file_hash(path, deadline) == initial_hash,
                "Package changed during measurement")
        budget_check(deadline)
    except (zipfile.BadZipFile, ET.ParseError, RuntimeError, OSError, zlib.error, UnicodeError) as exc:
        raise GateError("Invalid compiled NAVX payload/manifest") from exc
    return {"identity": identity, "friends": grants, "dependencies": dependencies,
            "application": application, "platform": platform, "propagateDependencies": propagate == "true",
            "sourceRepositoryUrl": source.get("RepositoryUrl", ""),
            "sourceCommit": source.get("Commit", ""), "compilerVersion": build.get("CompilerVersion", ""),
            "buildUrl": build.get("Url", ""), "sha256": initial_hash,
            "contentSha256": digest(json.dumps(entries, sort_keys=True).encode()),
            "symbolReferenceSha256": next((e["sha256"] for e in entries if e["name"] == "SymbolReference.json"), None),
            "compilerManifestSha256": manifest_compiler_hash,
            "bytes": before.st_size, "expandedBytes": expanded, "entryCount": len(items),
            "resourceProfile": initial_hash if profile else "generic",
            "signatureTailBytes": before.st_size - 40 - length}



def ready_to_run_info(path, before, archive, items, initial_hash, length, deadline, max_expanded, profile):
    """Read one bounded ReadyToRun envelope for dependency inventories only.

    Report the outer file hash consumed by the helper, and retain the embedded
    NAVX hash separately. No wrapper is accepted for shipping/postcompile output.
    """
    names = [item.filename for item in items]
    require(names.count("readytorunappmanifest.json") == 1, "Missing/duplicate ReadyToRun manifest")
    expanded = sum(item.file_size for item in items)
    require(expanded <= max_expanded, "Package expanded-byte bound exceeded")
    require(archive.getinfo("readytorunappmanifest.json").file_size <= MANIFEST_BYTES,
            "ReadyToRun manifest exceeds 16 MiB")
    def unique_object(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, "Duplicate ReadyToRun metadata key")
            result[key] = value
        return result
    metadata = json.loads(archive.read("readytorunappmanifest.json").decode("utf-8-sig"),
                          object_pairs_hook=unique_object)
    keys = {"EmbeddedAppId", "EmbeddedAppPublisher", "EmbeddedAppName", "EmbeddedAppVersion", "EmbeddedAppFileName"}
    require(isinstance(metadata, dict) and set(metadata) == keys and
            all(isinstance(value, str) and value for value in metadata.values()), "Invalid ReadyToRun metadata")
    expected = {key.lower(): metadata["EmbeddedApp" + key] for key in ("Id", "Publisher", "Name", "Version")}
    identity_check(expected)
    embedded = metadata["EmbeddedAppFileName"]
    require("/" not in embedded and "\\" not in embedded and ":" not in embedded and
            embedded not in (".", "..") and embedded.lower().endswith(".app"), "Invalid ReadyToRun embedded filename")
    require([name for name in names if name.lower().endswith(".app")] == [embedded],
            "Missing/ambiguous ReadyToRun embedded app")
    require(archive.getinfo(embedded).file_size <= PACKAGE_BYTES, "Embedded package exceeds 128 MiB")
    entries = []
    with tempfile.TemporaryDirectory(prefix="appsource-r2r-") as scratch:
        inner_path = Path(scratch) / "embedded.app"
        for item in sorted(items, key=lambda item: item.filename):
            sha, size = hashlib.sha256(), 0
            with archive.open(item) as content:
                with inner_path.open("wb") if item.filename == embedded else io.BytesIO() as target:
                    while True:
                        budget_check(deadline)
                        chunk = content.read(CHUNK_BYTES)
                        if not chunk:
                            break
                        size += len(chunk)
                        require(size <= item.file_size and size <= max_expanded, "Expanded entry bound exceeded")
                        sha.update(chunk)
                        if item.filename == embedded:
                            target.write(chunk)
            require(size == item.file_size, "Truncated expanded entry")
            entries.append({"name": item.filename, "sha256": sha.hexdigest()})
        inner = package_info(inner_path, deadline)
        require(inner["identity"] == expected, "ReadyToRun embedded identity mismatch")
        if profile:
            require(inner["identity"] == profile["identity"], "Measured package profile identity mismatch")
    require(tuple(getattr(path.stat(), key) for key in ("st_dev", "st_ino", "st_size", "st_mtime_ns", "st_ctime_ns")) ==
            tuple(getattr(before, key) for key in ("st_dev", "st_ino", "st_size", "st_mtime_ns", "st_ctime_ns")) and
            file_hash(path, deadline) == initial_hash, "Package changed during measurement")
    budget_check(deadline)
    # Count work at both compression layers in the aggregate inventory budget.
    return {**inner, "sha256": initial_hash, "contentSha256": digest(json.dumps(entries, sort_keys=True).encode()),
            "bytes": before.st_size, "expandedBytes": expanded + inner["expandedBytes"], "entryCount": len(items),
            "resourceProfile": initial_hash if profile else "generic", "signatureTailBytes": before.st_size - 40 - length,
            "readyToRun": {"embeddedSha256": inner["sha256"], "embeddedContentSha256": inner["contentSha256"],
                           "embeddedEntryCount": inner["entryCount"], "embeddedExpandedBytes": inner["expandedBytes"],
                           "outerExpandedBytes": expanded, "signatureTrustVerified": False}}


def check_package(info, expected, mode, app_type, friend, source_commit=None):
    require(info["identity"] == {k: expected[k] for k in ("id", "publisher", "name", "version")}, "Wrong package identity/version")
    expected_grants = [friend] if mode == "Test" and app_type == "app" else []
    require(info["friends"] == expected_grants, "Wrong/missing/surviving compiled friend grants")
    if source_commit is not None:
        require(info["sourceCommit"] == source_commit, "Wrong compiled source commit")


def check_foundation_candidate(info):
    """Exact development candidate content, not Windows signature acceptance."""
    for key in ("identity", "sha256", "sourceCommit", "buildUrl", "compilerVersion"):
        require(info[key] == FOUNDATION_CANDIDATE[key], "Unapproved Foundation candidate " + key)
    require(info["friends"] == [] and info["signatureTailBytes"] > 0,
            "Foundation candidate friend/signature-content mismatch")
    return {"candidate": "candidate530", "artifactId": FOUNDATION_CANDIDATE["artifactId"],
            "archiveSha256": FOUNDATION_CANDIDATE["archiveSha256"], "signatureTrustVerified": False,
            "runnerInputEqualityVerified": False}


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


class SymbolInventory(list):
    """List-compatible immutable receipt payload with local elapsed measurement."""


def symbol_inventory(folder, policy="appCache"):
    """Strict identity-unique inventory after any explicit catalog preparation."""
    return _symbol_inventory(folder, policy)


def _symbol_inventory(folder, policy, *, catalog_aliases=False):
    """Complete bounded measurement; duplicate collection is preparation-only."""
    require(policy in SYMBOL_POLICIES, "Unknown symbol resource policy")
    folder = Path(folder)
    require(folder.is_dir() and not folder.is_symlink(), "Actual symbol folder absent or linked")
    limit, started = SYMBOL_POLICIES[policy], time.monotonic()
    deadline = started + INVENTORY_SECONDS
    paths = []
    for path in folder.iterdir():
        budget_check(deadline)
        if path.suffix.lower() == ".app":
            paths.append(path)
            require(len(paths) <= limit["packages"], "Symbol inventory exceeds " + str(limit["packages"]) + " packages (" + policy + ")")
    paths.sort()
    require(sum(path.stat().st_size for path in paths) <= limit["bytes"], "Symbol aggregate-byte bound exceeded")
    result, identities, filenames, expanded = SymbolInventory(), set(), set(), 0
    for path in paths:
        try:
            info = package_info(path, deadline, allow_ready_to_run=True)
        except GateError as error:
            # Retain the actual failing input even beyond the diagnostic item cap.
            error.rejected_package = path
            raise
        identity = (info["identity"]["id"].lower(), version_tuple(info["identity"]["version"]))
        require(catalog_aliases or identity not in identities, "Duplicate symbol identity/version")
        require(path.name.casefold() not in filenames, "Case-insensitive symbol filename collision")
        identities.add(identity)
        filenames.add(path.name.casefold())
        expanded += info["expandedBytes"]
        require(expanded <= limit.get("expandedBytes", limit["bytes"]), "Symbol aggregate expanded-byte bound exceeded")
        result.append({"file": path.name, **info})
    budget_check(deadline)
    require(sorted(p.name for p in folder.iterdir() if p.suffix.lower() == ".app") == sorted(p.name for p in paths),
            "Symbol inventory membership changed during measurement")
    result.elapsed_seconds = time.monotonic() - started
    return result


def normalize_compiler_catalog(folder):
    """Remove compiler-equivalent Microsoft artifact aliases before strict inventory.

    Validate the entire bounded catalog and every duplicate group before any
    deletion. Different compiler symbols/metadata and non-Microsoft duplicates fail.
    Prefer the versioned filename; retain a receipt for each removed alias.
    """
    folder = Path(folder)
    measured = _symbol_inventory(folder, "compilerCatalog", catalog_aliases=True)
    groups = {}
    for item in measured:
        key = (item["identity"]["id"].lower(), version_tuple(item["identity"]["version"]))
        groups.setdefault(key, []).append(item)
    removals = []
    for items in groups.values():
        if len(items) == 1:
            continue
        require(all(item["identity"]["publisher"] == "Microsoft" for item in items),
                "Duplicate symbol identity/version: non-Microsoft catalog collision")
        fields = ("identity", "friends", "dependencies", "application", "platform",
                  "propagateDependencies", "sourceCommit", "compilerVersion", "buildUrl",
                  "symbolReferenceSha256", "compilerManifestSha256")
        require(items[0]["symbolReferenceSha256"] is not None and
                all(all(item[key] == items[0][key] for key in fields) for item in items),
                "Conflicting duplicate symbol identity/version compiler inputs")
        items.sort(key=lambda item: (not item["file"].lower().endswith(
            "_" + item["identity"]["version"] + ".app"), item["file"]))
        retained = items[0]
        for removed in items[1:]:
            removals.append({"identity": retained["identity"], "retainedSha256": retained["sha256"],
                             "removedSha256": removed["sha256"],
                             "symbolReferenceSha256": retained["symbolReferenceSha256"],
                             "compilerManifestSha256": retained["compilerManifestSha256"],
                             "compilerMetadataEqual": True,
                             "retained": retained["file"], "removed": removed["file"]})
    # Recheck all bytes/membership before performing the approved preparation.
    deadline = time.monotonic() + INVENTORY_SECONDS
    require(sorted(p.name for p in folder.iterdir() if p.suffix.lower() == ".app") ==
            sorted(item["file"] for item in measured), "Catalog changed before alias removal")
    for item in measured:
        path = folder / item["file"]
        require(not path.is_symlink() and file_hash(path, deadline) == item["sha256"],
                "Catalog changed before alias removal")
    for item in removals:
        (folder / item["removed"]).unlink()
    return {"aliasesRemoved": removals, "before": inventory_measurement(measured, "compilerCatalog"),
            "compilerSymbolEqualityVerified": True, "signatureTrustVerified": False}


def inventory_measurement(items, policy):
    return {"policy": policy, "limits": SYMBOL_POLICIES[policy], "packages": len(items),
            "bytes": sum(s["bytes"] for s in items), "expandedBytes": sum(s["expandedBytes"] for s in items),
            "inventorySha256": digest(json.dumps(items, sort_keys=True).encode()),
            "elapsedSeconds": getattr(items, "elapsed_seconds", None), "elapsedBudgetSeconds": INVENTORY_SECONDS,
            "runnerCapacityValidated": False}


def resolve_helper_inputs(manifest, existing, catalog):
    """Observe helper6.1.18 selection; never substitute its compiler/cache inputs.

    Existing highest compatible version wins; otherwise the helper copies ALL
    compatible catalog versions. Copied inputs follow all dependencies; existing
    inputs follow dependencies only when PropagateDependencies is true.
    Full identity checks deliberately refuse helper's AppId-only mismatches.
    """
    dependencies = []
    for field, app_id, name in (("application", "c1335042-3002-4257-bf8a-75c898ccb1b8", "Application"),
                               ("platform", "8874ed3a-0643-4247-9ced-7a7002f7135d", "System")):
        if manifest.get(field):
            dependencies.append(dict(id=app_id, publisher="Microsoft", name=name, version=manifest[field]))
    dependencies.extend(manifest.get("dependencies", []))
    available, copies, trace, queued = list(existing), [], [], set()
    index, edges = 0, len(dependencies)
    while index < len(dependencies):
        require(len(dependencies) <= 4096, "Dependency resolution bound exceeded")
        dep = dependencies[index]
        index += 1
        identity_check(dep)
        key = (dep["id"].lower(), dep["version"], dep["publisher"], dep["name"])
        if key in queued:
            continue
        queued.add(key)

        def matching(items):
            matches = [s for s in items if s["identity"]["id"].lower() == dep["id"].lower()
                       and version_tuple(s["identity"]["version"]) >= version_tuple(dep["version"])]
            require(all(s["identity"]["publisher"] == dep["publisher"] and s["identity"]["name"] == dep["name"]
                        for s in matches), "Wrong resolved dependency publisher/name")
            return sorted(matches, key=lambda s: version_tuple(s["identity"]["version"]), reverse=True)

        found = matching(available)
        chosen = found[:1] if found else matching(catalog)
        require(chosen, "Missing compatible dependency: " + dep["name"])
        trace.append({"dependency": dep, "source": "existing" if found else "compilerCatalog",
                      "selected": [{"file": s["file"], "identity": s["identity"], "sha256": s["sha256"]} for s in chosen]})
        for item in chosen:
            if not found:
                require(all(s["file"].casefold() != item["file"].casefold() for s in available),
                        "Helper copy would overwrite existing input")
                copies.append(item)
                available.append(item)
                if item["application"] and not any(d["name"] == "Application" for d in dependencies):
                    dependencies.append(dict(id="c1335042-3002-4257-bf8a-75c898ccb1b8", publisher="Microsoft",
                                             name="Application", version=item["application"]))
                if item["platform"] and not any(d["name"] == "System" and d["publisher"] == "Microsoft" for d in dependencies):
                    dependencies.append(dict(id="8874ed3a-0643-4247-9ced-7a7002f7135d", publisher="Microsoft",
                                             name="System", version=item["platform"]))
            if not found or item["propagateDependencies"]:
                # Helper queues every catalog version for a new transitive AppId.
                edges += len(item["dependencies"])
                require(edges <= 4096, "Dependency edge bound exceeded")
                for child in item["dependencies"]:
                    if not any(d["id"].lower() == child["id"].lower() for d in dependencies):
                        transitive = [s["identity"] for s in catalog if s["identity"]["id"].lower() == child["id"].lower()]
                        require(transitive, "Missing transitive catalog dependency: " + child["name"])
                        require(all(d["name"] == child["name"] and d["publisher"] == child["publisher"]
                                    and version_tuple(d["version"]) >= version_tuple(child["version"]) for d in transitive),
                                "Wrong/too-old transitive catalog dependency")
                        dependencies.extend(transitive)
    require(len(available) <= SYMBOL_POLICIES["appCache"]["packages"], "Resolved app cache package bound exceeded")
    require(sum(s["bytes"] for s in available) <= SYMBOL_POLICIES["appCache"]["bytes"],
            "Resolved app cache byte bound exceeded")
    return {"copies": copies, "trace": trace, "resolved": inventory_measurement(available, "appCache"),
            "helperEquivalenceVerified": False, "consumedInputsCertified": False}


CLASSIC_HELPER_SHA = '9835753336bc95bc3cac0813e50ef06da4b4132fa1aee116c65934751abdad2d'
CLASSIC_HELPERS = {
    CLASSIC_HELPER_SHA: ('6.1.18', 'eb9530bf1d757fde941010c3dfa8526dc0d09fd598d62e5866940c67f7ed1ab4'),
    '9bdc072429580d8b78ed68eabbc537e07df0e7c5d49bed1131f0bf5dbab672d7': ('6.1.19', 'e7be1168e145b942f01c5dce7735de5c9a05816816f919663d808d602fcc5ea9'),
}
CLASSIC_METADATA_SECONDS = 60
CLASSIC_COPY_LIMIT = 256


def classic_metadata(path, item, command, deadline):
    """Fresh genuine altool metadata, never helper cache injection."""
    remaining = deadline - time.monotonic()
    require(remaining > 0, 'Classic metadata elapsed bound exceeded')
    try:
        result = subprocess.run(command + ['GetPackageManifest', str(path)],
                                capture_output=True, timeout=min(15, remaining), check=False)
    except subprocess.TimeoutExpired as exc:
        raise GateError('Classic altool metadata timeout') from exc
    require(result.returncode == 0 and len(result.stdout) <= MANIFEST_BYTES, 'Classic altool metadata failed/bound exceeded')
    metadata = json.loads(result.stdout.decode('utf-8-sig'))
    require({k:metadata[k] for k in ('id','publisher','name','version')} == item['identity'], 'Altool/package identity differs')
    require(metadata.get('application','') == item['application'] and metadata.get('platform','') == item['platform']
            and metadata.get('propagateDependencies',False) == item['propagateDependencies']
            and metadata.get('dependencies',[]) == item['dependencies'], 'Altool/package dependency metadata differs')
    require(file_hash(path) == item['sha256'], 'Classic metadata input changed')
    return {'file':str(path), 'sha256':item['sha256'], 'metadata':metadata}


def classic_mutation_check(manifest, resolution, parameters):
    # Do not turn off the genuine flag or silently change a shipping floor.
    if parameters.get('UpdateDependencies'):
        selected = [x for t in resolution['trace'] for x in t['selected']]
        for dep in manifest.get('dependencies',[]):
            require(not any(x['identity']['id'].lower() == dep['id'].lower()
                            and version_tuple(x['identity']['version']) > version_tuple(dep['version']) for x in selected),
                    'Genuine updateDependencies would mutate manifest; scoped build-local transformation needs review')
        for field, name in (('application','Application'),('platform','System')):
            if manifest.get(field):
                require(not any(x['identity']['name'] == name and x['identity']['publisher'] == 'Microsoft'
                                and version_tuple(x['identity']['version']) > version_tuple(manifest[field]) for x in selected),
                        'Genuine updateDependencies would mutate ' + field)
    require(not any(parameters.get('customCodeCops') or []), 'Custom cop loading/download mutation unsupported')
    require(not parameters.get('assemblyProbingPaths'), 'Additional probing inputs need exact scoped inventory')
    require(parameters.get('GenerateReportLayout', 'NotSpecified') == 'No',
            'Helper layout generation source mutation is unsupported until scoped review')


def project_inputs(project):
    """Hash project configs, resources and AL; generated input changes refuse."""
    project = Path(project)
    files, total = [], 0
    excluded = {'.alpackages','output','.buildartifacts','.git'}
    for path in sorted(project.rglob('*')):
        if any(part in excluded for part in path.relative_to(project).parts): continue
        if path.is_file():
            total += path.stat().st_size
            require(not path.is_symlink() and len(files) < 4096 and total <= SYMBOL_POLICIES['appCache']['bytes'],
                    'Project config/resource/source bound/links')
            files.append({'file':str(path.relative_to(project)), 'sha256':file_hash(path)})
    return files


def classic_source_inventory(project):
    project = Path(project)
    result = [{'file':'app.json', 'sha256':file_hash(project / 'app.json')}]
    total = 0
    for path in sorted(project.rglob('*.al')):
        total += path.stat().st_size
        require(not path.is_symlink() and len(result) <= 4096 and total <= 128 * 1024 * 1024,
                'Classic source bound/links')
        result.append({'file':str(path.relative_to(project)), 'sha256':file_hash(path)})
    require(len(result) > 1, 'Missing classic source')
    return result


def classic_prepare(root, request):
    """Prepare bounded fixed point under caller's exclusive run-local custody."""
    root, project = Path(root), Path(request['appProjectFolder']).resolve()
    context = request['context']; mode = context['mode']
    require(mode in ('Default','Test') and project in ((root/'app').resolve(), (root/'test').resolve()),
            'Unapproved classic project')
    directory = root / '.buildartifacts/AppSourceGate' / mode
    state = json.loads((directory/'state.json').read_text(encoding='utf-8-sig'))
    require(state.get('backend','classic') == 'classic' and state['context'] == context, 'Wrong classic state/context')
    owned = Path(request['ownedRoot']).resolve()
    caches = [Path(request[k]).resolve() for k in ('symbolsFolder','compilerSymbolsFolder')]
    require(caches[0] != caches[1] and all(c.is_relative_to(owned) and not c.is_symlink() for c in caches),
            'Classic caches require exclusive run-local ownership')
    helper, altool = Path(request['helper']), Path(request['altool'])
    metadata_helper = Path(request['metadataHelper'])
    helper_sha = file_hash(helper)
    require(helper_sha in CLASSIC_HELPERS, 'Unpinned genuine classic helper')
    helper_version, metadata_sha = CLASSIC_HELPERS[helper_sha]
    require(file_hash(metadata_helper) == metadata_sha, 'Unpinned genuine metadata helper')
    extension = Path(request['compilerExtension'])
    compiler_tools = {}
    total = 0
    for path in sorted(extension.rglob('*')):
        if path.is_file():
            total += path.stat().st_size
            require(not path.is_symlink() and len(compiler_tools) < 4096 and total <= SYMBOL_POLICIES['compilerCatalog']['bytes'], 'Classic compiler tool inventory bound/links')
            compiler_tools[str(path)] = file_hash(path)
    extra_roots = []
    if request.get('compilerFolder'):
        compiler_root = Path(request['compilerFolder'])
        extra_roots = [compiler_root/'dlls', compiler_root/'manifest.json']
        for base in extra_roots:
            paths = sorted(base.rglob('*')) if base.is_dir() else [base]
            for path in paths:
                if path.is_file():
                    total += path.stat().st_size
                    require(not path.is_symlink() and len(compiler_tools) < 4096 and total <= SYMBOL_POLICIES['compilerCatalog']['bytes'], 'Classic probing/tool inventory bound/links')
                    compiler_tools[str(path)] = file_hash(path)
    require(compiler_tools and str(altool) in compiler_tools, 'Classic compiler/tool closure missing')
    require(file_hash(helper) == helper_sha, 'Genuine classic helper changed')
    require(file_hash(altool) == request['altoolSha256'], 'Classic altool changed')
    command = [str(altool)]
    if altool.suffix.lower() == '.dll':
        runtime = Path(request['dotnet'])
        require(file_hash(runtime) == request['dotnetSha256'], 'Classic metadata runtime changed')
        command = [str(runtime),str(altool)]
    manifest = json.loads((project/'app.json').read_text(encoding='utf-8-sig'))
    sources = classic_source_inventory(project)
    project_files = project_inputs(project)
    normalization = normalize_compiler_catalog(caches[1])
    existing, catalog = symbol_inventory(caches[0]), symbol_inventory(caches[1], 'compilerCatalog')
    require(all(i['identity']['id'] != manifest['id'] for i in existing + catalog), 'Classic self/stale input')
    foundation = [i for i in existing if i['identity']['id'] == FOUNDATION_CANDIDATE['identity']['id']]
    require(len(foundation) == 1, 'Classic selected Foundation absent/ambiguous');check_foundation_candidate(foundation[0])
    product = json.loads((root/'app/app.json').read_text(encoding='utf-8-sig'))
    if project == (root/'test').resolve():
        built = state['receipts'].get('app',{}).get('package',{})
        products = [i for i in existing if i['identity']['id'] == product['id']]
        require(len(products) == 1 and products[0]['sha256'] == built.get('sha256'), 'Classic Test current-run product missing/wrong')
    resolution = resolve_helper_inputs(manifest, existing, catalog)
    classic_mutation_check(manifest, resolution, request['parameters'])
    require(len(resolution['copies']) <= CLASSIC_COPY_LIMIT, 'Classic copy convergence bound exceeded')
    deadline = time.monotonic() + CLASSIC_METADATA_SECONDS
    work = [(folder/item['file'],item) for folder, inventory in zip(caches,(existing,catalog)) for item in inventory]
    # Four bounded read-only metadata processes share the unchanged total budget.
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures = [pool.submit(classic_metadata,path,item,command,deadline) for path,item in work]
        metadata = [future.result() for future in futures]
    # Invalidate only these owned caches. No metadata fabrication/stale reuse.
    for folder in caches:
        path = folder/'cache_AppInfo.json'
        if path.exists():
            require(path.is_file() and not path.is_symlink(), 'Unknown/linked metadata cache')
            path.unlink()
    for item in resolution['copies']:
        source, target = caches[1]/item['file'], caches[0]/item['file']
        require(not target.exists() and file_hash(source) == item['sha256'], 'Classic overwrite/source mutation')
        with source.open('rb') as inp, target.open('xb') as dest:
            shutil.copyfileobj(inp,dest,CHUNK_BYTES)
        require(file_hash(target) == item['sha256'], 'Classic copied bytes changed')
    final = symbol_inventory(caches[0]); replay = resolve_helper_inputs(manifest,final,catalog)
    require(not replay['copies'], 'Classic preparation did not converge')
    require(symbol_inventory(caches[1],'compilerCatalog') == catalog and classic_source_inventory(project) == sources,
            'Classic preparation source/catalog mutation')
    receipt = {'helperVersion':helper_version, 'context':context, 'sources':sources, 'projectInputs':project_files, 'appProjectFolder':str(project),
               'symbolsFolder':str(caches[0]), 'compilerSymbolsFolder':str(caches[1]),
               'cache':final, 'catalog':catalog, 'resolution':resolution, 'replay':replay,
               'catalogNormalization':normalization, 'metadata':metadata,
               'compilerTools':compiler_tools, 'compilerExtension':str(extension), 'extraToolRoots':[str(p) for p in extra_roots],
               'tools':{'metadataHelper':{'path':str(metadata_helper),'sha256':file_hash(metadata_helper)}, 'helper':{'path':str(helper),'sha256':helper_sha},
                        'altool':{'path':str(altool),'sha256':request['altoolSha256']}},
               'consumedInputsCertified':False, 'helperRuntimeEquivalenceVerified':False}
    if altool.suffix.lower() == '.dll': receipt['tools']['dotnet']={'path':request['dotnet'],'sha256':request['dotnetSha256']}
    (directory/'classic-prepared.json').write_text(json.dumps(receipt,indent=2)+'\n')
    return receipt


def classic_tools_unchanged(receipt):
    roots = [Path(receipt['compilerExtension'])] + [Path(p) for p in receipt['extraToolRoots']]
    files = {}
    for root in roots:
        for p in (sorted(root.rglob('*')) if root.is_dir() else [root]):
            if p.is_file(): files[str(p)] = file_hash(p)
    require(files == receipt['compilerTools'], 'Classic compiler/probing closure changed')


def classic_seal(root, request):
    directory = Path(root)/'.buildartifacts/AppSourceGate'/request['context']['mode']
    receipt = json.loads((directory/'classic-prepared.json').read_text())
    require(receipt['context'] == request['context'], 'Wrong classic seal context')
    require(classic_source_inventory(receipt['appProjectFolder']) == receipt['sources'] and project_inputs(receipt['appProjectFolder']) == receipt['projectInputs'], 'Classic source/config changed before helper')
    for item in receipt['tools'].values(): require(file_hash(item['path']) == item['sha256'], 'Classic tool changed before helper')
    classic_tools_unchanged(receipt)
    require(symbol_inventory(receipt['symbolsFolder']) == receipt['cache'] and
            symbol_inventory(receipt['compilerSymbolsFolder'],'compilerCatalog') == receipt['catalog'],
            'Classic cache changed before helper')
    for folder in (receipt['symbolsFolder'],receipt['compilerSymbolsFolder']):
        require(not (Path(folder)/'cache_AppInfo.json').exists(), 'Stale helper metadata cache reintroduced')
    return {'preparedSha256':file_hash(directory/'classic-prepared.json'), 'consumedInputsCertified':False}


def classic_after(root, request):
    directory = Path(root)/'.buildartifacts/AppSourceGate'/request['context']['mode']
    receipt = json.loads((directory/'classic-prepared.json').read_text())
    require(receipt['context'] == request['context'], 'Wrong classic after context')
    require(classic_source_inventory(receipt['appProjectFolder']) == receipt['sources'] and project_inputs(receipt['appProjectFolder']) == receipt['projectInputs'], 'Classic helper mutated manifest/source/config')
    for item in receipt['tools'].values(): require(file_hash(item['path']) == item['sha256'], 'Classic helper/tool mutation')
    classic_tools_unchanged(receipt)
    require(symbol_inventory(receipt['compilerSymbolsFolder'],'compilerCatalog') == receipt['catalog'], 'Classic helper catalog mutation')
    final = symbol_inventory(receipt['symbolsFolder'])
    baseline = {x['file']:x for x in receipt['cache']}
    for item in receipt['cache']: require(item in final, 'Classic helper changed prepared input')
    additions = [x for x in final if x['file'] not in baseline]
    if request['copyAppToSymbolsFolder']:
        require(len(additions) == 1 and additions[0]['identity']['id'] == json.loads((Path(receipt['appProjectFolder'])/'app.json').read_text(encoding='utf-8-sig'))['id'],
                'Classic helper added unaccounted dependency/output')
        require(len(request['appFiles']) == 1 and file_hash(request['appFiles'][0]) == additions[0]['sha256'], 'Classic output copy differs')
    else: require(not additions, 'Translation helper unexpectedly changed symbol cache')
    result = {'context':request['context'],'preparedSha256':file_hash(directory/'classic-prepared.json'),
              'after':final,'consumedInputsCertified':False}
    (directory/'classic-after.json').write_text(json.dumps(result,indent=2)+'\n')
    return result


def reconcile_symbols(snapshot, request, output):
    """Check boundary observations, not unobservable transient compiler consumption."""
    require(snapshot["symbolsFolder"] == str(Path(request["symbolsFolder"]).resolve()), "Changed symbol cache path")
    require(snapshot["compilerSymbolsFolder"] == str(Path(request["compilerSymbolsFolder"]).resolve()),
            "Changed compiler symbol path")
    compiler = symbol_inventory(request["compilerSymbolsFolder"], "compilerCatalog")
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
    require("resolution" in snapshot, "Missing bounded dependency resolution receipt")
    require(sorted(additions, key=lambda s: s["file"]) == sorted(snapshot["resolution"]["copies"], key=lambda s: s["file"]),
            "Actual helper additions differ from bounded dependency resolution")
    return {"before": snapshot["symbols"], "compilerBeforeAndAfter": compiler,
            "after": final, "preparationAdditions": additions, "outputCopy": copies[0],
            "measurements": {"compilerCatalog": inventory_measurement(compiler, "compilerCatalog"),
                             "appCache": inventory_measurement(final, "appCache")},
            "consumedInputsCertified": False}


def sanitized_inventory(items):
    result = []
    for info in items:
        item = dict(info)
        url = item["buildUrl"]
        item["buildUrl"] = url if re.fullmatch(r"https://github.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/actions/runs/[0-9]+", url) else "redacted-unrecognized-build-url"
        result.append(item)
    return result


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
    normalization = normalize_compiler_catalog(request["compilerSymbolsFolder"])
    (directory / (app_type + "-" + request["kind"] + "-catalog-normalization.json")).write_text(
        json.dumps({"context": context, **normalization}, indent=2) + "\n")
    compiler_symbols = symbol_inventory(request["compilerSymbolsFolder"], "compilerCatalog")
    # Keep successful boundary measurements even if later identity/pin/resolution refuses.
    measured = {"context": context, "measurements": {
        "appCache": inventory_measurement(symbols, "appCache"),
        "compilerCatalog": inventory_measurement(compiler_symbols, "compilerCatalog")},
        "inputs": {"appCache": sanitized_inventory(symbols), "compilerCatalog": sanitized_inventory(compiler_symbols)},
        "folders": {"appCache": str(Path(request["symbolsFolder"]).resolve()),
                    "compilerCatalog": str(Path(request["compilerSymbolsFolder"]).resolve())},
        "consumedInputsCertified": False}
    (directory / "symbol-measurements.json").write_text(json.dumps(measured, indent=2) + "\n")
    for symbol in symbols + compiler_symbols:
        require(symbol["identity"]["id"].lower() != manifest["id"].lower(),
                "Product self-app in actual PRECOMPILE symbol cache")
    require(symbols, "Empty actual precompile symbol inventory")
    foundation = [s for s in symbols if s["identity"]["id"] == "7505e808-6e52-4b96-a328-82573391297a"]
    require(len(foundation) == 1, "Missing/ambiguous/unapproved Foundation input bytes")
    foundation_candidate = check_foundation_candidate(foundation[0])
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
                "compilerSymbols": compiler_symbols, "catalogNormalization": normalization,
                "measurements": {"appCache": inventory_measurement(symbols, "appCache"),
                                 "compilerCatalog": inventory_measurement(compiler_symbols, "compilerCatalog")},
                "resolution": resolve_helper_inputs(manifest, symbols, compiler_symbols),
                "foundationCandidate": foundation_candidate}
    (directory / "before.json").write_text(json.dumps(snapshot, indent=2) + "\n")
    return snapshot


def rejected_receipt(output, context, paths=(), *, folders=None, offending=None):
    """Record bounded disk identities only; never dump Settings or credentials."""
    deadline = time.monotonic() + INVENTORY_SECONDS
    candidates = [(Path(path), None) for path in paths]
    require(len(candidates) <= 4096, "Diagnostic path bound exceeded")
    folder_receipts = []
    for source, folder in (folders or {}).items():
        folder = Path(folder)
        present = folder.is_dir()
        item = {"sourceFolder": source, "path": str(folder), "present": present,
                "packages": 0, "bytes": 0, "enumerationComplete": True}
        folder_receipts.append(item)
        if present:
            for path in folder.iterdir():
                if time.monotonic() > deadline:
                    item["enumerationComplete"] = False
                    break
                if path.suffix.lower() == ".app":
                    item["packages"] += 1
                    item["bytes"] += path.stat().st_size
                    candidates.append((path, source))
                    if len(candidates) >= 4096:
                        item["enumerationComplete"] = False
                        break
    if offending is not None:
        offending = Path(offending)
        prioritized = [(path, source) for path, source in candidates if path == offending]
        candidates = prioritized + [(path, source) for path, source in candidates if path != offending]
    inventory = []
    truncated = len(candidates) > 128 or any(not f["enumerationComplete"] for f in folder_receipts)
    hashed_bytes = 0
    for path, source in candidates[:128]:
        if time.monotonic() > deadline:
            truncated = True
            break
        item = {"path": str(path), "present": path.is_file()}
        if offending is not None and path == offending:
            item["triggeredRejection"] = True
        if source is not None:
            item["sourceFolder"] = source
        if item["present"]:
            size = path.stat().st_size
            item["bytes"] = size
            if size > PACKAGE_BYTES or hashed_bytes + size > SYMBOL_POLICIES["appCache"]["bytes"] or path.is_symlink():
                item["truncated"] = True
                truncated = True
            else:
                hashed_bytes += size
                try:
                    item["sha256"] = file_hash(path, deadline)
                except GateError:
                    item["truncated"] = True
                    truncated = True
                    inventory.append(item)
                    break
                try:
                    info = package_info(path, deadline)
                    item.update({k: info[k] for k in ("identity", "friends", "sourceCommit", "compilerVersion")})
                    # Build URLs may contain secrets in malformed/untrusted manifests.
                    url = info["buildUrl"]
                    item["buildUrl"] = url if re.fullmatch(r"https://github.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/actions/runs/[0-9]+", url) else "redacted-unrecognized-build-url"
                except (GateError, OSError, ValueError):
                    item["manifestValid"] = False
        inventory.append(item)
    allowed = {k: context[k] for k in ("run", "attempt", "job", "sourceCommit", "checkoutSha", "mode") if k in context}
    Path(output).write_text(json.dumps({"accepted": False, "context": allowed, "inputs": inventory,
                                      "folders": folder_receipts, "truncated": truncated,
                                      "consumedInputsCertified": False,
                                      "signatureTrustVerified": False}, indent=2) + "\n")


def before_compile(root, request):
    """Keep the original failure while recording bounded allowlisted disk inputs."""
    try:
        return _before_compile(root, request)
    except (GateError, OSError, KeyError, ValueError) as error:
        # Evidence failure must never replace or clear the original gate failure.
        try:
            context = request.get("context", {})
            directory = Path(root) / ".buildartifacts/AppSourceGate" / context.get("mode", "Unknown")
            directory.mkdir(parents=True, exist_ok=True)
            rejected_receipt(directory / "rejected-input.json", context, folders={
                key: request[key] for key in ("symbolsFolder", "compilerSymbolsFolder") if key in request},
                offending=getattr(error, "rejected_package", None))
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
    boundaries = reconcile_symbols(snapshot, request, info)
    symbols = snapshot["symbols"]
    receipt = {"context": context, "appType": app_type, "parameters": params, "package": info,
               "logSha256": digest(data[offset:]), "isolatedLogSha256": digest(isolated), "spans": spans, "symbols": symbols,
               "sourceFiles": request["sourceFiles"], "symbolBoundaries": boundaries}
    state["receipts"][app_type] = receipt
    state["logBytes"], state["logPrefixSha256"] = len(data), digest(data)
    state_path.write_text(json.dumps(state, indent=2) + "\n")
    return receipt


def validate_shipping_stage(directory, context, stage, shipping, result):
    # Direct fixture reconciliation without workflow policy proves only package
    # boundaries. Actual workflow always supplies shipping intent at Pipeline.
    if shipping is None:
        return
    require(stage in ('pipeline','signed') and type(shipping.get('signingRequired')) is bool
            and type(shipping.get('doNotSignApps')) is bool, 'Missing actual shipping policy')
    state = json.loads((directory / 'state.json').read_text(encoding='utf-8-sig'))
    require(shipping.get('effectiveSettings') == state['effectiveSettings'], 'Final merged settings changed')
    required = shipping['signingRequired']
    require(not required or (context['mode'] == 'Default' and not shipping['doNotSignApps']),
            'Shipping signing intent/settings mismatch')
    require(context['mode'] != 'Test' or shipping['doNotSignApps'], 'Test unsigned policy missing')
    if stage == 'signed':
        pipeline = json.loads((directory / 'pipeline.json').read_text())
        require(pipeline['context'] == context and pipeline['stateSha256'] == result['stateSha256']
                and pipeline.get('shipping', {}).get('signingRequired') is True
                and pipeline['shipping']['doNotSignApps'] is False
                and required and shipping['signOutcome'] == 'success',
                'Missing current Pipeline or skipped/failed required signing')
        require([v['contentSha256'] for v in pipeline['outputs']] == [v['contentSha256'] for v in result['outputs']],
                'Signed output displaced from Pipeline')
    result['shipping'] = shipping


def reconcile(root, context, stage, signature=None, shipping=None):
    """Check expected hooks and actual published artifact paths, also after Sign."""
    root = Path(root)
    directory = root / ".buildartifacts" / "AppSourceGate" / context["mode"]
    state = json.loads((directory / "state.json").read_text(encoding="utf-8-sig"))
    if state.get("backend") == "workspace":
        return workspace_reconcile(root, context, stage, signature, shipping)
    require(state.get("backend", "classic") == "classic", "Unknown receipt backend")
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
    validate_shipping_stage(directory, context, stage, shipping, result)
    if signature:
        result["signature"] = signature
    (directory / (stage + ".json")).write_text(json.dumps(result, indent=2) + "\n")
    return result


# Explicit backend state is created before workspace creation and adopted by
# the prebuilt pipeline. These observations do not certify internal consumption.
WORKSPACE_MODULE_SHA = 'fcf82a3a83f6925c26adcd0876d57f59ba3c29ad8b2e9a1c11c70eaa9aefb73e'
WORKSPACE_KEYS = {'ALToolPath', 'WorkspaceFile', 'PackageCachePath', 'OutFolder',
                  'LogDirectory', 'ErrorLogDirectory', 'AssemblyProbingPaths',
                  'Analyzers', 'CustomAnalyzers', 'PreprocessorSymbols', 'Features',
                  'GenerateReportLayout', 'Ruleset', 'SourceRepositoryUrl', 'SourceCommit',
                  'ReportSuppressedDiagnostics', 'EnableExternalRulesets', 'MaxCpuCount'}


WORKSPACE_HOOKS = ('.AL-Go/PipelineInitialize.ps1', '.AL-Go/PipelineFinalize.ps1',
                   '.AL-Go/PreCompileApp.ps1', '.AL-Go/PostCompileApp.ps1',
                   '.AL-Go/CompileAppWithBcCompilerFolder.ps1', '.AL-Go/settings.json',
                   'tools/Assert-AppSourceBuild.ps1', 'tools/appsource_gate.py',
                   'tools/Acquire-FoundationInputs.ps1', 'tools/Prepare-FoundationInputs.ps1',
                   'tools/stage_foundation_inputs.py', 'tools/Prepare-ClassicCompilerInputs.ps1')
WORKSPACE_IMPORTS = (('DebugLogHelper.psm1', './DebugLogHelper.psm1'), ('TelemetryHelper.psm1', '../TelemetryHelper.psm1'),
                     ('Github-Helper.psm1', '../Github-Helper.psm1'),
                     ('AL-Go-Helper.ps1', '../AL-Go-Helper.ps1'))


def workspace_prepared_projects(root, mode):
    """Bind the approved two-project graph before altool workspace creation."""
    root = Path(root)
    result = {}
    for app_type, folder in (('app', 'app'), ('testApp', 'test')):
        # workspace_projects validates the genuine workspace later; use the same
        # manifest/source inventory here without manufacturing compiler arguments.
        manifest = root / folder / 'app.json'
        require(manifest.is_file() and not manifest.is_symlink() and manifest.stat().st_size <= MANIFEST_BYTES,
                'Missing/linked/oversized prepared manifest')
        data = json.loads(manifest.read_text(encoding='utf-8-sig'))
        identity_check({k:data[k] for k in ('id', 'publisher', 'name', 'version')})
        sources, total = [], 0
        for path in sorted((root / folder).rglob('*.al')):
            total += path.stat().st_size
            require(not path.is_symlink() and len(sources) < 4096 and total <= 128 * 1024 * 1024,
                    'Prepared source bound/links')
            sources.append({'file':str(path.relative_to(root)), 'sha256':file_hash(path)})
        require(sources, 'Prepared project sources missing')
        result[app_type] = {'path':folder, 'manifest':data, 'manifestSha256':file_hash(manifest), 'sources':sources, 'inputs':project_inputs(root/folder)}
    friend = {k:result['testApp']['manifest'][k] for k in ('id', 'publisher', 'name')}
    require(result['app']['manifest'].get('internalsVisibleTo', []) == ([friend] if mode == 'Test' else []),
            'Workspace friendship not prepared before creation')
    require(not result['testApp']['manifest'].get('internalsVisibleTo'), 'Unexpected test friendship')
    return result


WORKSPACE_COMPILE_SHA = '16e2056d9fc88097bf10c504886ff2d2bfccf4d91796cc62cc271cf20df438d9'


def workspace_cop_configs(root):
    result = {}
    for folder in ('app', 'test'):
        path = Path(root) / folder / 'AppSourceCop.json'
        if path.exists():
            require(path.is_file() and not path.is_symlink() and path.stat().st_size <= MANIFEST_BYTES,
                    'Invalid original AppSourceCop input')
            value = json.loads(path.read_text(encoding='utf-8-sig'))
            require(isinstance(value, dict), 'Original AppSourceCop must be an object')
            result[folder] = value
    return result


def workspace_stock_manifest(original, settings, context):
    """Model unchanged pinned Get-VersionNumber + Update-AppJsonProperties only."""
    import copy
    expected = copy.deepcopy(original)
    require(all(k in settings for k in ('versioningStrategy','appBuild','appRevision')), 'Missing actual stock version settings')
    strategy = settings['versioningStrategy']
    require(type(strategy) is int, 'Missing actual versioning strategy')
    build, revision = settings['appBuild'], settings['appRevision']
    major_minor = None
    if strategy == -1:
        artifact = settings['artifact'].split('/')
        require(len(artifact) > 4, 'Missing versioned BC artifact')
        version = version_tuple(artifact[4])
        major_minor, build, revision = version[:2], version[2], version[3]
    elif strategy & 16:
        repo_version = settings['repoVersion'].split('.')
        require(2 <= len(repo_version) <= 4 and all(v.isdecimal() for v in repo_version), 'Invalid actual repoVersion')
        repo_version = tuple(int(v) for v in repo_version)
        major_minor = repo_version[:2]
        if strategy & 15 == 3:
            # Upstream emits a warning for absent build; warning is not acceptance.
            require(len(repo_version) >= 3, 'repoVersion emits stock missing-build warning')
            build = repo_version[2]
    require(type(build) is int and type(revision) is int and 0 <= build <= 2147483647
            and 0 <= revision <= 2147483647, 'Invalid actual stock build/revision')
    current = version_tuple(original['version'])
    major_minor = current[:2] if major_minor is None else major_minor
    if not (strategy == -1 or strategy & 16) and build == 0:
        build = current[2]
    expected['version'] = '.'.join(str(v) for v in (*major_minor, build, revision))
    expected['build'] = {'by':'AL-Go for GitHub', 'url':context['buildUrl']}
    return expected


def workspace_stock_cop(original, settings):
    """Only New-AppSourceCopJson managed fields without a baseline are allowed."""
    import copy
    expected = copy.deepcopy(original)
    affixes = settings.get('appSourceCopMandatoryAffixes')
    if affixes:
        require(isinstance(affixes, list) and len(affixes) <= 128
                and all(isinstance(v, str) for v in affixes), 'Invalid managed affixes')
        expected['mandatoryAffixes'] = affixes
    tag = settings.get('obsoleteTagMinAllowedMajorMinor')
    if tag:
        require(isinstance(tag, str), 'Invalid managed obsolete tag')
        expected['obsoleteTagMinAllowedMajorMinor'] = tag
    return expected


def workspace_reconcile_preparation(root, request):
    """Validate stock order at genuine precompile; never rewrite shipping inputs."""
    root = Path(root); context = request['context']
    directory = root / '.buildartifacts/AppSourceGate' / context['mode']
    state = json.loads((directory / 'state.json').read_text(encoding='utf-8-sig'))
    require(state.get('backend') == 'workspace' and state['context'] == context
            and state['effectiveSettings'] == request['settings'], 'Stock context/settings changed')
    # workspace_parameters has already byte-validated the pinned producer + imports.
    if 'generatedProjects' in state:
        receipt = json.loads((directory / 'stock-preparation.json').read_text())
        require(receipt['sha256'] == state['stockPreparationSha256']
                and receipt['sha256'] == hashlib.sha256(json.dumps(receipt['transformation'], sort_keys=True).encode()).hexdigest(),
                'Stock transformation receipt changed')
        workspace_state(root, context)
        return
    actual = workspace_prepared_projects(root, context['mode'])
    if actual == state['preparedProjects']:
        return  # Stable controlled/genuine primitive producer; no exclusion implied.
    require(not state['receipts'] and not state['adopted'], 'Late/duplicate stock transformation')
    settings = state['effectiveSettings']
    require(request['tools']['workspaceModule']['sha256'] == WORKSPACE_MODULE_SHA
            and request['tools']['AL-Go-Helper.ps1']['sha256'] == WORKSPACE_IMPORT_HASHES['AL-Go-Helper.ps1'],
            'Unpinned stock transformation producer')
    transformations = {}
    configs = workspace_cop_configs(root)
    for app_type, before in state['preparedProjects'].items():
        after = actual[app_type]; folder = before['path']
        require(after['path'] == folder and after['sources'] == before['sources'], 'Unknown stock source change')
        manifest = workspace_stock_manifest(before['manifest'], settings, context)
        require(after['manifest'] == manifest, 'Unexpected stock manifest property/version/build')
        expected_cop = workspace_stock_cop(state['originalCopConfigs'].get(folder, {}), settings)
        # Preserve user-managed settings; unknown baseline version/path is refused.
        require(configs.get(folder, {}) == expected_cop, 'Unexpected stock AppSourceCop/baseline change')
        require((folder in configs) == (folder in state['originalCopConfigs'] or bool(expected_cop)),
                'Unaccounted AppSourceCop creation/deletion')
        original_inputs = {v['file']:v['sha256'] for v in before['inputs']}
        actual_inputs = {v['file']:v['sha256'] for v in after['inputs']}
        for name in set(original_inputs) | set(actual_inputs):
            if name not in ('app.json','AppSourceCop.json'):
                require(original_inputs.get(name) == actual_inputs.get(name), 'Unknown generated config/resource/translation change')
        transformations[app_type] = {'original':before, 'generated':after,
                                    'copOriginal':state['originalCopConfigs'].get(folder), 'copGenerated':configs.get(folder)}
    # Pin every source implementing the stock order, not a downloaded mutable helper.
    module = Path(request['tools']['workspaceModule']['path'])
    compile_source = module.parent.parent / 'CompileApps/Compile.ps1'
    require(file_hash(compile_source) == WORKSPACE_COMPILE_SHA, 'Unpinned stock CompileApps orchestration')
    transformation = {'context':context, 'settings':settings, 'projects':transformations,
                      'producerHashes':{'CompileApps':WORKSPACE_COMPILE_SHA, 'CompileFromWorkspace':WORKSPACE_MODULE_SHA,
                                        'AL-Go-Helper':WORKSPACE_IMPORT_HASHES['AL-Go-Helper.ps1']},
                      'consumedInputsCertified':False}
    digest = hashlib.sha256(json.dumps(transformation, sort_keys=True).encode()).hexdigest()
    (directory / 'stock-preparation.json').write_text(json.dumps({'sha256':digest,'transformation':transformation}, indent=2)+'\n')
    state.update(generatedProjects=actual, stockPreparationSha256=digest,
                 stockProducerFiles={str(compile_source):WORKSPACE_COMPILE_SHA, str(module):WORKSPACE_MODULE_SHA,
                                    str(module.parent.parent / 'AL-Go-Helper.ps1'):WORKSPACE_IMPORT_HASHES['AL-Go-Helper.ps1']})
    (directory / 'state.json').write_text(json.dumps(state, indent=2)+'\n')
    workspace_state(root, context)


def workspace_state(root, context):
    require(context.get('mode') in ('Default', 'Test'), 'Unexpected workspace state mode')
    directory = Path(root) / '.buildartifacts/AppSourceGate' / context['mode']
    state = json.loads((directory / 'state.json').read_text(encoding='utf-8-sig'))
    require(state.get('schema') == 2 and state.get('backend') == 'workspace'
            and state['context'] == context, 'Missing/stale/untrusted workspace state')
    require(file_hash(state['selection']) == state['selectionSha256'], 'Selected workspace inputs changed')
    require(state.get('generatedProjects', state['preparedProjects']) == workspace_prepared_projects(root, context['mode']),
            'Prepared workspace sources/manifest changed')
    if 'generatedProjects' in state:
        receipt = json.loads((directory / 'stock-preparation.json').read_text())
        require(receipt['sha256'] == state['stockPreparationSha256']
                and receipt['sha256'] == hashlib.sha256(json.dumps(receipt['transformation'], sort_keys=True).encode()).hexdigest(),
                'Stock transformation receipt changed')
        for path, sha in state['stockProducerFiles'].items():
            require(file_hash(path) == sha, 'Stock producer source changed')
    require(set(state['hookHashes']) == set(WORKSPACE_HOOKS), 'Incomplete workspace hook inventory')
    for path, sha in state['hookHashes'].items():
        require(file_hash(Path(root) / path) == sha, 'Workspace hook/preparation tool changed')
    return directory, state


def workspace_initialize(root, request):
    context = request['context']
    require(context.get('mode') in ('Default', 'Test'), 'Unexpected initialization mode')
    for key in ('sourceCommit','checkoutSha'):
        require(re.fullmatch('[a-f0-9]{40}',context[key]), 'Workspace initialization SHA missing')
    for key in ('run','attempt','job'):
        require(context.get(key), 'Workspace initialization identity missing')
    require(request['settings'].get('workspaceCompilation', {}).get('enabled') is True,
            'Workspace backend not selected')
    require(re.fullmatch(r'https://github.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/actions/runs/[0-9]+', context['buildUrl']),
            'Missing canonical external run URL')
    directory = Path(root) / '.buildartifacts/AppSourceGate' / context['mode']
    require(not directory.exists(), 'Existing workspace receipts cannot be reused')
    hooks = {p:file_hash(Path(root) / p) for p in WORKSPACE_HOOKS}
    state = {'schema':2, 'backend':'workspace', 'context':context, 'startedNs':time.time_ns(),
             'hookHashes':hooks, 'effectiveSettings':request['settings'],
             'preparedProjects':workspace_prepared_projects(root, context['mode']),
             'originalCopConfigs':workspace_cop_configs(root),
             'selection':request['selection'], 'selectionSha256':file_hash(request['selection']),
             'receipts':{}, 'adopted':False, 'consumedInputsCertified':False}
    directory.mkdir(parents=True)
    (directory / 'state.json').write_text(json.dumps(state, indent=2) + '\n')
    return state


def workspace_adopt(root, request):
    directory, state = workspace_state(root, request['context'])
    require(not state['adopted'] and not (directory / 'before.json').exists(), 'Repeated/incomplete workspace adoption')
    require(state['effectiveSettings'] == request['settings'], 'Workspace settings changed before pipeline')
    require(set(state['receipts']) == ({'app','testApp'} if state['context']['mode'] == 'Test' else {'app'}),
            'Incomplete workspace compilation before prebuilt pipeline')
    require(re.fullmatch('[a-f0-9]{64}', request.get('alpacaArchiveSha256', '')), 'Missing Alpaca archive hash')
    workspace_validate_receipts(root, state)
    log = Path(root) / 'BuildOutput.txt'
    require(log.is_file(), 'Actual workspace aggregate build output missing')
    state['buildOutputSha256'] = file_hash(log)
    state.update(adopted=True, alpacaArchiveSha256=request['alpacaArchiveSha256'])
    (directory / 'state.json').write_text(json.dumps(state, indent=2) + '\n')
    return state


def workspace_check_metadata(info, manifest, context, app_type, friend, tools, parameters):
    check_package(info, manifest, context['mode'], app_type, friend, context['sourceCommit'])
    require(info['compilerVersion'] == tools['compiler']['version'], 'Workspace compiler metadata mismatch')
    require(info['sourceRepositoryUrl'] == parameters['SourceRepositoryUrl'], 'Workspace source repository mismatch')
    # This exact pinned producer has no BuildUrl parameter. Actual producer
    # omission is tested separately; the run link is an external hash attestation.
    require(not info['buildUrl'] or info['buildUrl'] == context['buildUrl'], 'Workspace nonempty build URL mismatch')


def workspace_validate_receipts(root, state, stage=None):
    require(set(state['receipts']) == ({'app','testApp'} if state['context']['mode'] == 'Test' else {'app'}),
            'Missing/unexpected workspace receipts')
    for app_type, receipt in state['receipts'].items():
        request = dict(context=state['context'], parameters=receipt['parameters'], tools=receipt['tools'], settings=state['effectiveSettings'])
        workspace_parameters(request)
        require(receipt['context'] == state['context'] and receipt['projects'] == [state.get('generatedProjects', state['preparedProjects'])[app_type]],
                'Stale/source-displaced workspace receipt')
        for output in receipt['outputs']:
            expected = {k:v for k,v in output.items() if k != 'file'}
            unsigned = Path(root) / '.buildartifacts/AppSourceGate' / state['context']['mode'] / 'unsigned' / (app_type + '.app')
            require(package_info(unsigned) == expected, 'Retained unsigned workspace bytes changed')
            actual = package_info(output['file'])
            final = Path(root) / '.buildartifacts' / ('Apps' if app_type == 'app' else 'TestApps') / Path(output['file']).name
            if stage == 'signed' and Path(output['file']).resolve() == final.resolve():
                require(actual['contentSha256'] == output['contentSha256'], 'Signed original workspace content changed')
            else:
                require(actual == expected, 'Original workspace output changed')
        for item in receipt['logs'] + receipt['errorLogs']:
            path = Path(item['file'])
            require(file_hash(path) == item['sha256'] and path.stat().st_mtime_ns == item['mtimeNs'],
                    'Workspace compiler log changed')
        for symbol in receipt['cacheAfter']:
            require(file_hash(Path(receipt['parameters']['PackageCachePath']) / symbol['file']) == symbol['sha256'],
                    'Workspace cache input/output changed')
    # No new cache bytes after last compile, including an unexpected second compile.
    last = state['receipts']['testApp' if state['context']['mode'] == 'Test' else 'app']
    require(symbol_inventory(last['parameters']['PackageCachePath'], 'compilerCatalog') == last['cacheAfter'],
            'Unreceipted workspace cache additions')


def workspace_reconcile(root, context, stage, signature=None, shipping=None):
    directory, state = workspace_state(root, context)
    require(state['adopted'] and not (directory / 'before.json').exists(), 'Workspace pipeline not adopted/incomplete')
    workspace_validate_receipts(root, state, stage)
    require(file_hash(Path(root) / 'BuildOutput.txt') == state['buildOutputSha256'], 'Unreceipted later workspace compiler output')
    outputs = []
    for app_type, receipt in sorted(state['receipts'].items()):
        folder = Path(root) / '.buildartifacts' / ('Apps' if app_type == 'app' else 'TestApps')
        files = list(folder.glob('*.app'))
        require(len(files) == len(receipt['outputs']) == 1, 'Missing/ambiguous prebuilt workspace copy')
        info = package_info(files[0]); original = receipt['outputs'][0]
        require(info['contentSha256'] == original['contentSha256'], 'Prebuilt workspace NAVX content changed')
        if stage == 'signed':
            require(context['mode'] == 'Default' and app_type == 'app', 'Unexpected workspace signing mode')
            require(signature and signature.get('status') == 'Valid' and signature.get('signerThumbprint')
                    and signature.get('provider') == 'Windows Get-AuthenticodeSignature' and signature.get('sha256') == info['sha256'],
                    'Missing/invalid workspace signature proof')
        else:
            require(info['sha256'] == original['sha256'], 'Unsigned prebuilt workspace bytes changed')
        outputs.append({'file':str(files[0].relative_to(root)), **info})
    if stage != 'finalize':
        finalized = json.loads((directory / 'finalize.json').read_text())
        require(finalized['context'] == context and finalized['stateSha256'] == file_hash(directory / 'state.json'),
                'Missing/stale workspace finalization')
    result = {'schema':2, 'backend':'workspace', 'context':context, 'stage':stage,
              'stateSha256':file_hash(directory / 'state.json'), 'outputs':outputs,
              'externalBuildAttestation':{'buildUrl':context['buildUrl'], 'sourceCommit':context['sourceCommit'],
                  'checkoutSha':context['checkoutSha'], 'unsignedHashes':[o['sha256'] for r in state['receipts'].values() for o in r['outputs']],
                  'outputHashes':[o['sha256'] for o in outputs]}, 'consumedInputsCertified':False}
    validate_shipping_stage(directory, context, stage, shipping, result)
    if signature: result['signature'] = signature
    (directory / (stage + '.json')).write_text(json.dumps(result, indent=2) + '\n')
    return result


WORKSPACE_IMPORT_HASHES = {'DebugLogHelper.psm1': '830abb97839a0d340deabc4e95fc23cf43205800c945c6f0635d240dd8eb2579', 'TelemetryHelper.psm1': '0914ad287a31efe80b43a34d02107e538ee7aa6a9f94cef8c6b385c6d9e96520', 'Github-Helper.psm1': 'b83916a0869106557371df3e819118b6cf3949a7c65b44b57cb41243be0e12ee', 'AL-Go-Helper.ps1': 'e3c5488ae4d52cd7b38867b50002752b75531bac71c4900cdd28e9aaf97c02f2'}


def workspace_parameters(request):
    p, settings = request['parameters'], request['settings']
    require(set(p) == WORKSPACE_KEYS, 'Unexpected/missing actual workspace parameters')
    require(settings.get('workspaceCompilation', {}).get('enabled') is True,
            'Workspace mode not enabled in actual merged settings')
    for name in ('enableCodeCop', 'enableUICop', 'enableAppSourceCop', 'enableCodeAnalyzersOnTestApps'):
        require(settings.get(name) is True, 'Workspace analyzer disabled: ' + name)
    require(settings.get('type') == 'AppSource App' and settings.get('failOn') == 'warning',
            'Workspace type/warning policy mismatch')
    require(not settings.get('escapeFromCops') and not settings.get('rulesetFile'),
            'Workspace fallback/custom ruleset unsupported')
    require(set(p['Analyzers'] or []) == {'CodeCop', 'UICop', 'AppSourceCop'}
            and len(p['Analyzers']) == 3 and not p['CustomAnalyzers'], 'Unexpected workspace analyzers')
    require(not p['Ruleset'] and p['ReportSuppressedDiagnostics'] is False
            and p['EnableExternalRulesets'] is False, 'Workspace suppression/ruleset unsupported')
    require(type(p['MaxCpuCount']) is int and 1 <= p['MaxCpuCount'] <= 128,
            'Workspace CPU bound unsupported')
    require(p['SourceCommit'] == request['context']['sourceCommit'], 'Workspace source commit mismatch')
    require(re.fullmatch(r'https://github.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', p['SourceRepositoryUrl'] or ''), 'Workspace source repository absent/unsupported')
    tools = request['tools']
    require(tools['workspaceModule']['sha256'] == WORKSPACE_MODULE_SHA, 'Unpinned workspace module')
    require(file_hash(Path(tools['workspaceModule']['path']).parent.parent / 'CompileApps/Compile.ps1') == WORKSPACE_COMPILE_SHA,
            'Unpinned stock CompileApps source')
    for name in ('compiler', 'altool', 'compilerPackage', 'CodeCop', 'UICop', 'AppSourceCop', 'Analyzers.Common', 'workspaceModule'):
        item = tools[name]
        require(file_hash(item['path']) == item['sha256'], 'Workspace tool hash changed: ' + name)
    module = Path(tools['workspaceModule']['path'])
    for name, relative in WORKSPACE_IMPORTS:
        require(file_hash(module.parent / relative) == tools[name]['sha256'] == WORKSPACE_IMPORT_HASHES[name]
                and Path(tools[name]['path']).resolve() == (module.parent / relative).resolve(),
                'Workspace upstream import missing/changed: ' + name)
    require(Path(p['ALToolPath']).resolve() == Path(tools['altool']['path']).resolve(), 'Workspace tool path mismatch')
    require(tools['compiler'].get('version') and tools['compilerPackage'].get('version'),
            'Workspace compiler versions absent')
    return p


def workspace_projects(root, request):
    root = Path(root).resolve()
    p, context, app_type = request['parameters'], request['context'], request['appType']
    require(app_type in ('app', 'testApp') and context['mode'] in ('Default', 'Test'), 'Unexpected workspace invocation')
    require(context['mode'] == 'Test' or app_type == 'app', 'Default workspace test invocation')
    for key in ('sourceCommit', 'checkoutSha'):
        require(re.fullmatch('[a-f0-9]{40}', context[key]) is not None, 'Missing workspace SHA')
    for key in ('run', 'attempt', 'job', 'buildUrl'):
        require(context.get(key), 'Missing workspace run identity: ' + key)
    workspace = Path(p['WorkspaceFile']).resolve()
    require(workspace.stat().st_size <= MANIFEST_BYTES, 'Workspace JSON bound exceeded')
    data = json.loads(workspace.read_text(encoding='utf-8-sig'))
    folders = data['folders']
    require(isinstance(folders, list) and 0 < len(folders) <= 32, 'Workspace project bound exceeded')
    projects, seen, total = [], set(), 0
    friend = json.loads((root / 'test/app.json').read_text(encoding='utf-8-sig'))
    friend = {k: friend[k] for k in ('id', 'publisher', 'name')}
    for folder in folders:
        path = (workspace.parent / folder['path']).resolve()
        require(path.is_relative_to(root) and not path.is_symlink(), 'Workspace project outside checkout')
        manifest_path = path / 'app.json'
        require(manifest_path.stat().st_size <= MANIFEST_BYTES, 'Project manifest bound exceeded')
        manifest = json.loads(manifest_path.read_text(encoding='utf-8-sig'))
        # This issue authorizes the retained product/test graph only. Other project
        # identities need scoped review; arbitrary downloaded project input refuses.
        expected_path = root / ('app' if app_type == 'app' else 'test') / 'app.json'
        expected = json.loads(expected_path.read_text(encoding='utf-8-sig'))
        require(path == expected_path.parent and all(manifest[k] == expected[k] for k in ('id', 'publisher', 'name', 'version')),
                'Unapproved workspace project graph')
        require(manifest['id'] not in seen, 'Duplicate workspace project identity')
        seen.add(manifest['id'])
        grants = [friend] if context['mode'] == 'Test' and app_type == 'app' else []
        require(manifest.get('internalsVisibleTo', []) == grants, 'Workspace product friendship not prepared')
        sources = []
        for source in sorted(path.rglob('*.al')):
            require(not source.is_symlink(), 'Linked workspace source')
            total += source.stat().st_size
            require(len(sources) < 4096 and total <= 128 * 1024 * 1024, 'Workspace source bound exceeded')
            sources.append({'file': str(source.relative_to(root)), 'sha256': file_hash(source)})
        require(sources, 'Workspace project has no sources')
        projects.append({'path': str(path.relative_to(root)), 'manifest': manifest,
                         'manifestSha256': file_hash(manifest_path), 'sources': sources, 'inputs':project_inputs(path)})
    return {'workspaceSha256': file_hash(workspace), 'projects': projects}


def workspace_logs(folder):
    folder = Path(folder)
    require(folder.is_dir() and not folder.is_symlink(), 'Workspace logs absent/linked')
    files, total = {}, 0
    for path in sorted(folder.rglob('*')):
        if path.is_file():
            require(not path.is_symlink() and len(files) < 128, 'Workspace log bound/links')
            total += path.stat().st_size
            require(total <= 32 * 1024 * 1024, 'Workspace log byte bound')
            files[str(path.relative_to(folder))] = {'sha256': file_hash(path), 'mtimeNs': path.stat().st_mtime_ns}
    return files


def workspace_before(root, request):
    p = workspace_parameters(request)
    workspace_reconcile_preparation(root, request)
    projects = workspace_projects(root, request)
    context, app_type = request['context'], request['appType']
    directory, state = workspace_state(root, context)
    require(not state['adopted'], 'Workspace recompilation after prebuilt adoption')
    require(request['settings'] == state['effectiveSettings'], 'Workspace settings changed since preparation')
    require(projects['projects'] == [state.get('generatedProjects', state['preparedProjects'])[app_type]], 'Workspace preparation displaced')
    state_path = directory / 'state.json'
    require(state['context'] == context and app_type not in state['receipts'], 'Stale/duplicate workspace state')
    require(not (directory / 'before.json').exists(), 'Unfinished workspace invocation cannot be reused')
    symbols = symbol_inventory(p['PackageCachePath'], 'compilerCatalog')
    foundation = [s for s in symbols if s['identity']['id'] == FOUNDATION_CANDIDATE['identity']['id']]
    require(len(foundation) == 1, 'Missing/ambiguous workspace Foundation')
    check_foundation_candidate(foundation[0])
    # Selected dependencies are revalidated by the preparation process and here;
    # shared baseline additions cannot introduce unproven non-Microsoft bytes.
    import stage_foundation_inputs as staging
    require(request['selection'] == state['selection'], 'Workspace selected input location changed')
    selection = json.loads(Path(request['selection']).read_text(encoding='utf-8-sig'))
    staging_context = {k:context[k] for k in ('run', 'attempt', 'sourceCommit', 'checkoutSha', 'mode')}
    arrays = selection['publication']['selection']
    staging.validate_publication(request['selection'], staging_context,
                                 [x['helperInput'] for x in arrays['installApps']],
                                 [x['helperInput'] for x in arrays['installTestApps']])
    known = {x['identity']['id']:x['sha256'] for items in arrays.values() for x in items}
    for receipt in state['receipts'].values():
        for output in receipt['outputs']:
            require(output['identity']['id'] not in known, 'Workspace generated/selected identity collision')
            known[output['identity']['id']] = output['sha256']
    for symbol in symbols:
        key = symbol['identity']['id']
        require(key in known, 'Unproven workspace baseline input')
        if key in known:
            require(symbol['sha256'] == known[key], 'Changed selected/current-run workspace input')
    product = json.loads((Path(root) / 'app/app.json').read_text(encoding='utf-8-sig'))
    for project in projects['projects']:
        require(all(s['identity']['id'] != project['manifest']['id'] for s in symbols), 'Workspace self/stale project input')
    if app_type == 'testApp':
        require('app' in state['receipts'], 'Workspace Test before product receipt')
        products = [s for s in symbols if s['identity']['id'] == product['id']]
        built = state['receipts']['app']['outputs']
        require(len(products) == len(built) == 1 and products[0]['sha256'] == built[0]['sha256'],
                'Workspace Test does not consume current-run product')
    logs = Path(p['LogDirectory']) if p['LogDirectory'] else Path(p['OutFolder']) / 'Logs'
    logs.mkdir(parents=True, exist_ok=True)
    error_logs = {}
    if p['ErrorLogDirectory']:
        error_folder = Path(p['ErrorLogDirectory'])
        error_folder.mkdir(parents=True, exist_ok=True)
        error_logs = workspace_logs(error_folder)
    before = {'errorLogs': error_logs, 'context': context, 'appType': app_type, 'parameters': p, 'tools': request['tools'],
              'settings': request['settings'], **projects, 'symbols': symbols,
              'logs': workspace_logs(logs), 'logDirectory': str(logs.resolve()),
              'startedNs': time.time_ns(), 'consumedInputsCertified': False}
    (directory / 'before.json').write_text(json.dumps(before, indent=2) + '\n')
    state_path.write_text(json.dumps(state, indent=2) + '\n')
    return before


def workspace_post(root, request):
    p = workspace_parameters(request)
    context = request['context']
    require(context.get('mode') in ('Default', 'Test'), 'Unexpected workspace post mode')
    directory, state = workspace_state(root, context)
    require(not state['adopted'], 'Workspace post after adoption')
    before = json.loads((directory / 'before.json').read_text())
    state = json.loads((directory / 'state.json').read_text())
    require(state['context'] == before['context'] == context and before['appType'] == request['appType'], 'Stale workspace post')
    require(before['parameters'] == p and before['tools'] == request['tools'] and before['settings'] == request['settings'],
            'Workspace effective parameters/tools/settings changed')
    project_data = workspace_projects(root, request)
    require(all(before[k] == project_data[k] for k in project_data), 'Workspace project/source mutation')
    files = request['appFiles']
    require(isinstance(files, list) and len(files) == len(before['projects']) and len(set(files)) == len(files),
            'Ambiguous/missing workspace output mapping')
    outputs, mapped = [], set()
    friend_manifest = json.loads((Path(root) / 'test/app.json').read_text(encoding='utf-8-sig'))
    friend = {k: friend_manifest[k] for k in ('id', 'publisher', 'name')}
    for file in files:
        path = Path(file).resolve()
        require(path.parent == Path(p['OutFolder']).resolve() and path.stat().st_mtime_ns >= before['startedNs'], 'Stale/outside workspace output')
        info = package_info(path)
        matches = [project for project in before['projects'] if project['manifest']['id'] == info['identity']['id']]
        require(len(matches) == 1 and info['identity']['id'] not in mapped, 'Unknown/duplicate workspace output')
        mapped.add(info['identity']['id'])
        workspace_check_metadata(info, matches[0]['manifest'], context, request['appType'], friend, request['tools'], p)
        outputs.append({'file': str(path), **info})
    symbols = symbol_inventory(p['PackageCachePath'], 'compilerCatalog')
    pre = {s['file']:s['sha256'] for s in before['symbols']}
    post = {s['file']:s['sha256'] for s in symbols}
    generated = {o['identity']['id']:o['sha256'] for o in outputs}
    for item in before['symbols']:
        require(post.get(item['file']) == item['sha256'], 'Workspace baseline input changed/disappeared')
    additions = [s for s in symbols if s['file'] not in pre]
    require(len(additions) == len(outputs) and all(generated.get(s['identity']['id']) == s['sha256'] for s in additions),
            'Unaccounted workspace cache/tool additions')
    logs = workspace_logs(before['logDirectory'])
    fresh = [name for name,meta in logs.items() if name not in before['logs'] or before['logs'][name] != meta]
    require(len(fresh) == len(before['projects']), 'Missing/ambiguous fresh workspace project logs')
    spans, log_receipts = [], []
    for name in fresh:
        path = Path(before['logDirectory']) / name
        require(path.stat().st_mtime_ns >= before['startedNs'], 'Stale workspace log timestamp')
        # altool per-project log lines carry [OUT] prefixes.
        raw = read_log(path.read_bytes())
        require(re.search(r'^Exit code: 0\s*$', raw, re.M) and not re.search(r'^\[ERR\]', raw, re.M), 'Workspace wrapper failed/incomplete')
        text = '\n'.join(line[6:] for line in raw.splitlines() if line.startswith('[OUT] '))
        found = compile_spans(text)
        require(len(found) == 1, 'Ambiguous workspace log span')
        spans.extend(found);log_receipts.append({'file':str(path), **logs[name]})
    require(len({s['project'] for s in spans}) == len(spans), 'Duplicate workspace log project')
    for project in before['projects']:
        matches = [s for s in spans if s['project'] == project['manifest']['name']]
        require(len(matches) == 1 and matches[0]['sourceCount'] == len(project['sources'])
                and matches[0]['compilerVersion'] == request['tools']['compiler']['version'], 'Workspace log/project/source mismatch')
    error_receipts = []
    if p['ErrorLogDirectory']:
        error_logs = workspace_logs(p['ErrorLogDirectory'])
        fresh_errors = [name for name,meta in error_logs.items() if before['errorLogs'].get(name) != meta]
        require(len(fresh_errors) == len(before['projects']), 'Missing fresh workspace error logs; unsupported compiler error-log option')
        for name in fresh_errors:
            path = Path(p['ErrorLogDirectory']) / name
            require(path.stat().st_mtime_ns >= before['startedNs'], 'Stale workspace error log')
            data = json.loads(path.read_text(encoding='utf-8-sig'))
            require(data.get('version') == '2.1.0' and data.get('runs'), 'Unexpected workspace SARIF schema')
            for run in data['runs']:
                require(isinstance(run.get('results'), list) and not run['results'], 'Workspace analyzer diagnostics present')
            error_receipts.append({'file':str(path), **error_logs[name]})
    receipt = {'context':context, 'appType':request['appType'], 'parameters':p, 'tools':request['tools'],
               **project_data, 'outputs':outputs, 'cacheBefore':before['symbols'], 'cacheAfter':symbols,
               'logs':log_receipts, 'errorLogs':error_receipts, 'spans':spans, 'consumedInputsCertified':False,
               'boundary':'supported workspace pre/post observations; altool internal preparation unverified'}
    unsigned = directory / 'unsigned'
    unsigned.mkdir(exist_ok=True)
    target = unsigned / (request['appType'] + '.app')
    require(len(outputs) == 1 and not target.exists(), 'Duplicate/ambiguous unsigned workspace retention')
    with Path(outputs[0]['file']).open('rb') as source, target.open('xb') as dest:
        shutil.copyfileobj(source, dest, CHUNK_BYTES)
    require(file_hash(target) == outputs[0]['sha256'], 'Unsigned workspace retention differs')
    state['receipts'][request['appType']] = receipt
    (directory / (request['appType'] + '-receipt.json')).write_text(json.dumps(receipt, indent=2) + '\n')
    (directory / 'state.json').write_text(json.dumps(state, indent=2) + '\n')
    (directory / 'before.json').unlink()
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["before", "post", "finalize", "pipeline", "signed", "package", "workspace-before", "workspace-post", "workspace-initialize", "workspace-adopt", "classic-prepare", "classic-seal", "classic-after"])
    parser.add_argument("--root", type=Path)
    parser.add_argument("--input", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.action == "package":
            result = package_info(args.input)
        else:
            request = json.loads(args.input.read_text(encoding="utf-8-sig"))
            if args.action == "classic-prepare":
                result = classic_prepare(args.root, request)
            elif args.action == "classic-seal":
                result = classic_seal(args.root, request)
            elif args.action == "classic-after":
                result = classic_after(args.root, request)
            elif args.action == "workspace-initialize":
                result = workspace_initialize(args.root, request)
            elif args.action == "workspace-adopt":
                result = workspace_adopt(args.root, request)
            elif args.action == "workspace-before":
                result = workspace_before(args.root, request)
            elif args.action == "workspace-post":
                result = workspace_post(args.root, request)
            elif args.action == "before":
                result = before_compile(args.root, request)
            elif args.action == "post":
                result = post_compile(args.root, request)
            else:
                result = reconcile(args.root, request["context"], args.action, request.get("signature"), request.get("shipping"))
        # Receipts are files, not console dumps of pipeline settings or paths.
        print(json.dumps(result) if args.action == "package" else "AppSource gate: " + args.action + " passed")
        return 0
    except (GateError, OSError, KeyError, ValueError) as exc:
        print("AppSource gate failed: " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
