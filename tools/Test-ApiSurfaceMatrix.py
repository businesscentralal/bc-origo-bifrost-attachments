#!/usr/bin/env python3
"""Validate source identities and the issue77 table/page provider attribution.

This static guard does not resolve lexical consumers or prove AL compatibility.
"""
import argparse
import hashlib
import json
import pathlib
import re

HEADER = re.compile(r'^(codeunit|tableextension|table|pageextension|page|enumextension|enum|interface|permissionsetextension|permissionset)\s+(?:(\d+)\s+)?"([^"]+)"', re.M)


def validate(root, inventory, document):
    errors = []
    objects = inventory['objects']
    files = {p.relative_to(root).as_posix() for p in (root / 'app/src').rglob('*.al')}
    if {o['file'] for o in objects} != files or len(objects) != len(files):
        errors.append('Inventory must contain every shipping file exactly once')
    for obj in objects:
        path = root / obj['file']
        if not path.is_file():
            errors.append(f"Inventory path missing from current source: {obj['file']}")
            continue
        try:
            text = path.read_text(encoding='utf-8-sig')
        except OSError as error:
            errors.append(f"Inventory source unreadable: {obj['file']}: {error}")
            continue
        header = HEADER.search(text)
        namespace = re.search(r'^namespace\s+([^;]+);', text, re.M)
        if header is None or namespace is None:
            errors.append(f"Unrecognized source identity: {obj['file']}")
            continue
        actual = (namespace.group(1), header.group(1), int(header.group(2)) if header.group(2) else None, header.group(3))
        recorded = (obj.get('namespace'), obj['kind'], obj['id'], obj['name'])
        if recorded != actual:
            errors.append(f"Source identity mismatch: {obj['file']}")
        if hashlib.sha256(path.read_bytes()).hexdigest() != obj['sha256']:
            errors.append(f"Source hash mismatch: {obj['file']}")
        prefix = f"| {obj['kind']} {obj['id'] or '—'} [{obj['name']}]({obj['file']}) |"
        rows = [line for line in document.splitlines() if line.startswith(prefix) and not line.startswith(prefix + ' `')]
        if len(rows) != 1 or not rows[0].endswith(f"| {obj['decision']} |"):
            errors.append(f"Document matrix identity/decision mismatch: {obj['file']}")
        if obj['access'].startswith('Public'):
            for signature in re.findall(r'^\s*procedure\s+([^\n]+)', text, re.M):
                row = f"{prefix} `{signature.strip()}` |"
                if sum(line.startswith(row) for line in document.splitlines()) != 1:
                    errors.append(f"Document public member kind/identity mismatch: {obj['file']}: {signature.strip()}")
        if obj['name'] == 'Storage Setup ori':
            expected = {'table': 10035636, 'page': 10035637}
            if obj['kind'] not in expected or obj['id'] != expected[obj['kind']]:
                errors.append('Storage Setup table/page identity changed; review attribution')
            if obj['kind'] == 'page' and 'provider contract' in obj['decision'].lower():
                errors.append('Storage Setup page is UI, not the provider Record contract')
            if obj['kind'] == 'table' and obj['decision'] != 'KEEP Public: provider contract':
                errors.append('Storage Setup table provider contract attribution missing')
    interface_path = root / 'app/src/Storage/StorageConnector.Interface.al'
    try:
        interface = interface_path.read_text(encoding='utf-8-sig')
    except OSError as error:
        errors.append(f'Provider interface source missing or unreadable: {interface_path.relative_to(root)}: {error}')
        interface = ''
    signatures = re.findall(r'^\s*procedure\s+([^\n]+)', interface, re.M)
    if not signatures or any('Record "Storage Setup ori"' not in signature for signature in signatures):
        errors.append('Provider members no longer all require the Storage Setup Record; review matrix')
    if inventory.get('consumerSearch', {}).get('kindResolved') is not False:
        errors.append('Current lexical matches must not claim kind-resolved consumers')
    return errors


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=pathlib.Path, default=pathlib.Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    errors = validate(args.root, json.loads((args.root / 'api-surface-objects.json').read_text(encoding='utf-8-sig')), (args.root / 'API-SURFACE.md').read_text(encoding='utf-8-sig'))
    print(json.dumps({'staticOnly': True, 'objectsChecked': len(json.loads((args.root / 'api-surface-objects.json').read_text(encoding='utf-8-sig'))['objects']), 'errors': errors}, indent=2))
    raise SystemExit(bool(errors))
