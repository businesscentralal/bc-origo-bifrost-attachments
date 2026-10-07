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
        text = path.read_text()
        header = HEADER.search(text)
        namespace = re.search(r'^namespace\s+([^;]+);', text, re.M)
        actual = (namespace.group(1), header.group(1), int(header.group(2)) if header.group(2) else None, header.group(3))
        recorded = (obj.get('namespace'), obj['kind'], obj['id'], obj['name'])
        if recorded != actual:
            errors.append(f"Source identity mismatch: {obj['file']}")
        if hashlib.sha256(path.read_bytes()).hexdigest() != obj['sha256']:
            errors.append(f"Source hash mismatch: {obj['file']}")
        prefix = f"| {obj['kind']} {obj['id'] or '—'} [{obj['name']}]({obj['file']}) |"
        rows = [line for line in document.splitlines() if line.startswith(prefix)]
        if len(rows) != 1 or not rows[0].endswith(f"| {obj['decision']} |"):
            errors.append(f"Document matrix identity/decision mismatch: {obj['file']}")
        if obj['name'] == 'Storage Setup ori':
            expected = {'table': 10035636, 'page': 10035637}
            if obj['kind'] not in expected or obj['id'] != expected[obj['kind']]:
                errors.append('Storage Setup table/page identity changed; review attribution')
            if obj['kind'] == 'page' and 'provider contract' in obj['decision'].lower():
                errors.append('Storage Setup page is UI, not the provider Record contract')
            if obj['kind'] == 'table' and obj['decision'] != 'KEEP Public: provider contract':
                errors.append('Storage Setup table provider contract attribution missing')
    interface = (root / 'app/src/Storage/StorageConnector.Interface.al').read_text()
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
    errors = validate(args.root, json.loads((args.root / 'api-surface-objects.json').read_text()), (args.root / 'API-SURFACE.md').read_text())
    print(json.dumps({'staticOnly': True, 'objectsChecked': len(json.loads((args.root / 'api-surface-objects.json').read_text())['objects']), 'errors': errors}, indent=2))
    raise SystemExit(bool(errors))
