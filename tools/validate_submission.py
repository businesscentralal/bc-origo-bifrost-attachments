#!/usr/bin/env python3
"""Check Attachments preparation and sanitized validator smoke receipts locally.

This tool performs no network calls, installation, consent, signing or publication.
It checks evidence consistency, not the authenticity of an external QA verdict.
Exit 0: requested checks consistent; 1: malformed input; 2: acceptance gaps.
"""
import argparse
import base64
import csv
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / 'app/docs/appsource'
SHA = re.compile(r'^[a-f0-9]{40}$')
HASH = re.compile(r'^[a-f0-9]{64}$')
STEPS = ('setup', 'connection', 'account-list', 'help-create', 'help-get',
         'create-file', 'get-file', 'missing-storage', 'cleanup')
SAMPLE = b'Attachments validator sample'
MAX_BYTES = 2 * 1024 * 1024


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate key')
        result[key] = value
    return result


def load(path):
    data = Path(path).read_bytes()
    if len(data) > MAX_BYTES:
        raise ValueError('input too large')
    return json.loads(data, object_pairs_hook=unique)


def reference(value):
    if not isinstance(value, str) or len(value) >= 2048:
        return False
    url = urlsplit(value)
    return (url.scheme == 'https' and bool(url.hostname) and not url.username
            and not url.password and not url.query)


def preparation(root=ROOT):
    """Use the existing committed-source checker; curated claims need owner review."""
    docs = root / 'app/docs/appsource'
    inventory = load(docs / 'source-inventory.json')
    manifest = load(root / 'app/app.json')
    cop = load(root / 'app/AppSourceCop.json')
    with (docs / 'partner-center-markets.csv').open(newline='') as stream:
        markets = [r['code'] for r in csv.DictReader(stream)]
    gaps = []
    if len(markets) != len(set(markets)) or sorted(markets) != sorted(cop['supportedCountries']):
        gaps.append('market CSV differs from AppSourceCop')
    if inventory['app'] != {k: manifest[k] for k in inventory['app'] if k in manifest}:
        gaps.append('source app identity differs from inventory')
    types = inventory['messageTypes']
    if len({t['name'] for t in types}) != len(types):
        gaps.append('duplicate declared message type')
    plan = (docs / 'scenario-plan.md').read_text()
    for number in range(1, 13):
        if not re.search(r'\| P%02d\b' % number, plan):
            gaps.append('missing scenario family P%02d' % number)
    def configured_offer(value):
        if isinstance(value, dict):
            offer = value.get('deliverToAppSource', {})
            if offer.get('productId') or offer.get('continuousDelivery'):
                return True
            return any(configured_offer(v) for v in value.values())
        if isinstance(value, list):
            return any(configured_offer(v) for v in value)
        return False
    if any(configured_offer(load(root / name)) for name in
           ('.github/AL-Go-Settings.json', '.AL-Go/settings.json')):
        gaps.append('offer mapping/delivery configured; separate operator approval required')
    for file in docs.glob('*.md'):
        for target in re.findall(r'\]\(([^)]+)\)', file.read_text()):
            if '://' in target or target.startswith('#'):
                continue
            resolved = (file.parent / target.split('#', 1)[0]).resolve()
            if not resolved.is_relative_to(root.resolve()) or not resolved.is_file():
                gaps.append('missing or out-of-repository submission link')
    return gaps, {'declaredMessageTypes': len(types), 'markets': len(markets), 'scenarioFamilies': 12}


def smoke(receipt, package):
    """Reconcile a human-executed smoke run with inspected immutable package bytes."""
    from appsource_gate import package_info
    gaps = []
    info = package_info(package)
    candidate = receipt['candidate']
    sha = receipt['sourceCommit']
    if receipt.get('schema') != 1 or not SHA.fullmatch(sha):
        raise ValueError('invalid receipt schema/source')
    if (info['identity']['id'] != '672df32a-a0c5-4a22-b591-0efa38023e95'
            or candidate['sha256'] != info['sha256'] or sha != info['sourceCommit']
            or candidate['version'] != info['identity']['version'] or info['friends']):
        gaps.append('candidate/package/source/version/friends mismatch')
    environment = receipt['environment']
    if (environment.get('sandbox') is not True or environment.get('validatorOwned') is not True
            or not all(environment.get(k) for k in ('id', 'owner', 'company', 'bcVersion', 'country'))
            or environment.get('lcid') not in (1033, 1039)):
        gaps.append('missing owned sandbox identity or language')
    qa = receipt['qa']
    if (qa.get('outcome') != 'passed' or qa.get('sourceCommit') != sha
            or qa.get('candidateSha256') != candidate['sha256'] or not reference(qa.get('evidenceUrl'))):
        gaps.append('passing exact-candidate issue80 QA receipt missing')
    foundation = receipt['foundation']
    if (not HASH.fullmatch(foundation.get('sha256', '')) or not foundation.get('version')
            or qa.get('foundation') != foundation):
        gaps.append('installed Foundation version/hash differs from QA or is missing')
    signature = receipt['signature']
    if (signature.get('status') != 'Valid' or signature.get('realCertificate') is not True
            or signature.get('candidateSha256') != candidate['sha256']
            or signature.get('tamperRejected') is not True or not reference(signature.get('evidenceUrl'))):
        gaps.append('real-certificate NAVX trust/tamper receipt missing')
    rows = receipt['steps']
    ids = [r['id'] for r in rows]
    if len(ids) != len(set(ids)) or set(ids) != set(STEPS):
        gaps.append('smoke steps missing/duplicated/unknown')
    for row in rows:
        if row.get('outcome') != 'passed' or not reference(row.get('evidenceUrl')):
            gaps.append('unproved smoke step')
    if receipt.get('createsOwnData') is not True or receipt.get('nonSuperIdentity') is not True:
        gaps.append('self-created fixtures/restricted identity missing')
    content = base64.b64decode(receipt['readbackContentBase64'], validate=True)
    if content != SAMPLE:
        gaps.append('readback bytes differ from synthetic input')
    negative = receipt['negative']
    if (negative.get('status') != 'Error' or not negative.get('code')
            or not negative.get('parameter') or not negative.get('nextStep')
            or negative.get('stateUnchanged') is not True):
        gaps.append('structured missing-storage error and unchanged-state proof missing')
    cleanup = receipt['cleanup']
    created, removed, absent = [cleanup[k] for k in ('created', 'removed', 'verifiedAbsent')]
    if (not created or any(not isinstance(values, list) for values in (created, removed, absent))
            or any(not isinstance(x, str) or not x for values in (created, removed, absent) for x in values)
            or any(len(x) != len(set(x)) for x in (created, removed, absent))
            or set(created) != set(removed) or set(created) != set(absent)
            or not reference(cleanup.get('evidenceUrl')) or cleanup.get('containerRetained') is not True):
        gaps.append('owned fixture cleanup/absence or container retention not proved')
    return sorted(set(gaps)), {'stepsRecorded': len(rows), 'packageSha256': info['sha256'],
                              'scope': 'single sandbox smoke receipt; not full certification'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--smoke-receipt', type=Path, help='sanitized actual run JSON; requires --package')
    parser.add_argument('--package', type=Path, help='immutable signed Default .app for receipt comparison')
    args = parser.parse_args()
    if bool(args.smoke_receipt) != bool(args.package):
        parser.error('--smoke-receipt and --package are required together')
    try:
        gaps, summary = preparation()
        result = subprocess.run([sys.executable, str(ROOT / 'tools/generate_source_inventory.py'), '--check'],
                                cwd=ROOT, capture_output=True, text=True)
        if result.returncode:
            gaps.append('committed source inventory check failed')
        if args.smoke_receipt:
            smoke_gaps, smoke_summary = smoke(load(args.smoke_receipt), args.package)
            gaps.extend(smoke_gaps)
            summary['smoke'] = smoke_summary
        print(json.dumps({'checksConsistent': not gaps, 'gaps': gaps, 'summary': summary,
                          'smokeExecutedByTool': False, 'candidateCertified': False,
                          'releaseReady': False}, indent=2))
        return 2 if gaps else 0
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        # Never echo input, paths, responses or parser exceptions containing private data.
        print(json.dumps({'checksConsistent': False, 'error': 'malformed or unavailable input',
                          'candidateCertified': False, 'releaseReady': False}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
