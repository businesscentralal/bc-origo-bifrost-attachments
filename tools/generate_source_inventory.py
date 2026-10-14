#!/usr/bin/env python3
"""Regenerate the derived parts of app/docs/appsource/source-inventory.json from a commit.

Reads every input from the git object store at --ref (default HEAD), so hashes are the
committed LF bytes and do not depend on the working tree. Curated fields (offer plan,
decisions, owners, candidate evidence) are kept as they are. Never certifies anything.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

REPO = Path(__file__).resolve().parents[1]
INVENTORY = 'app/docs/appsource/source-inventory.json'
MANIFESTS = ('app/app.json', 'app/AppSourceCop.json', '.AL-Go/settings.json', 'test/app.json')
APP_KEYS = ('id', 'name', 'publisher', 'version', 'application', 'platform', 'runtime', 'target',
            'dependencies', 'idRanges', 'help', 'EULA', 'privacyStatement', 'url', 'logo',
            'screenshots', 'supportedLocales')
ENUM_EXT = re.compile(r'enumextension\s+\d+\s+"[^"]+"\s+extends\s+"Message Type ori"')
VALUE = re.compile(r'value\((\d+);\s*"([^"]+)"\)')
VOLATILE = ('refreshedAt',)


class InventoryError(ValueError):
    """The source at the requested ref cannot produce a consistent inventory."""


def git(*args):
    result = subprocess.run(['git', '-C', str(REPO), *args], capture_output=True, check=True)
    return result.stdout


def resolve(ref):
    return git('rev-parse', '--verify', ref + '^{commit}').decode().strip()


def blob(sha, path):
    return git('show', f'{sha}:{path}')


def tree(sha, prefix):
    return sorted(git('ls-tree', '-r', '--name-only', sha, '--', prefix).decode().splitlines())


def digest(data):
    return hashlib.sha256(data).hexdigest()


def load_json(data):
    return json.loads(data.decode('utf-8-sig'))


def message_types(sha):
    rows = []
    for path in tree(sha, 'app/src'):
        if not path.endswith('.EnumExt.al'):
            continue
        text = blob(sha, path).decode('utf-8-sig')
        if not ENUM_EXT.search(text):
            continue
        rows += [dict(name=name, ordinal=int(ordinal), source=path) for ordinal, name in VALUE.findall(text)]
    for key in ('ordinal', 'name'):
        seen = {}
        for row in rows:
            if row[key] in seen:
                raise InventoryError(f'Duplicate message-type {key} {row[key]}: {seen[row[key]]} and {row["source"]}')
            seen[row[key]] = row['source']
    return sorted(rows, key=lambda row: row['ordinal'])


def build(previous, sha, now):
    app = load_json(blob(sha, 'app/app.json'))
    cop = load_json(blob(sha, 'app/AppSourceCop.json'))
    logo_path = 'app/' + app['logo']
    files = {path: digest(blob(sha, path)) for path in (*MANIFESTS, logo_path)}
    product = {path: digest(blob(sha, path)) for path in tree(sha, 'app') if path.endswith('.al')}
    tests = {path: digest(blob(sha, path)) for path in tree(sha, 'test') if path.endswith('.al')}

    inventory = dict(previous)
    inventory.update(
        sourceSha=sha,
        app={key: app[key] for key in APP_KEYS if key in app},
        markets=cop['supportedCountries'],
        messageTypes=message_types(sha),
        files=files,
        refreshedAt=now,
        inventoryPreparedFromDocumentationHead=sha,
        productSourceBaselineUnchanged=product == previous.get('productSourceFiles'),
        productSourceFiles=product,
        testSourceFiles=tests,
    )
    logo = dict(inventory.get('listingAssets', {}).get('logo', {}))
    logo.update(source=logo_path, sha256=files[logo_path])
    inventory.setdefault('listingAssets', {})
    inventory['listingAssets'] = {**inventory['listingAssets'], 'logo': logo}
    return inventory


def comparable(inventory):
    return {key: value for key, value in inventory.items() if key not in VOLATILE}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--ref', default='HEAD', help='commit to inventory (default HEAD)')
    parser.add_argument('--check', action='store_true', help='fail if the committed inventory is stale')
    args = parser.parse_args(argv)

    sha = resolve(args.ref)
    path = REPO / INVENTORY
    previous = json.loads(path.read_text(encoding='utf-8'))
    try:
        inventory = build(previous, sha, datetime.now(timezone.utc).isoformat())
    except InventoryError as error:
        print(f'ERROR: {error}', file=sys.stderr)
        return 2

    if args.check:
        # sourceSha moves with every commit; staleness means the derived content differs.
        ignore = ('sourceSha', 'inventoryPreparedFromDocumentationHead', 'productSourceBaselineUnchanged')
        current = {k: v for k, v in comparable(previous).items() if k not in ignore}
        fresh = {k: v for k, v in comparable(inventory).items() if k not in ignore}
        stale = sorted(key for key in fresh.keys() | current.keys() if fresh.get(key) != current.get(key))
        if stale:
            print('Inventory is stale in: ' + ', '.join(stale), file=sys.stderr)
            return 1
        print(f'Inventory matches {sha} ({len(inventory["messageTypes"])} message types).')
        return 0

    path.write_text(json.dumps(inventory, indent=2, ensure_ascii=False) + '\n', encoding='utf-8', newline='\n')
    print(f'Wrote {INVENTORY} from {sha}: {len(inventory["messageTypes"])} message types, '
          f'{len(inventory["productSourceFiles"])} product and {len(inventory["testSourceFiles"])} test files.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
