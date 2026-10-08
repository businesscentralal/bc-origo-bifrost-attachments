#!/usr/bin/env python3
"""Inventory immutable, local #80 evidence. Never certifies a runner or release."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

MAX_BYTES = 16 * 1024 * 1024
MAX_RECEIPTS = 512
PROVIDERS = ('AzureBlob', 'AzureFileShare', 'SharePoint')
PHASES = ('Default.postcompile', 'Default.postSign', 'Test.postcompile',
          'Test.runtime', 'source.guards', 'tools.guards', 'pipeline.identity',
          'restricted.runtime', 'lifecycle.runtime', 'MCP.runtime', 'UI.runtime',
          'cleanup')
FOUNDATION_ID = '7505e808-6e52-4b96-a328-82573391297a'
APP_ID = '672df32a-a0c5-4a22-b591-0efa38023e95'


class EvidenceError(ValueError):
    """A local evidence packet is malformed or inconsistent."""


def require(condition, message):
    if not condition:
        raise EvidenceError(message)


def hex_id(value, length):
    return isinstance(value, str) and re.fullmatch(r'[a-f0-9]{%d}' % length, value) is not None


def nonempty(value):
    return isinstance(value, str) and bool(value.strip())


def read_bytes(path):
    with Path(path).open('rb') as stream:
        data = stream.read(MAX_BYTES + 1)
    require(len(data) <= MAX_BYTES, 'Evidence file exceeds 16 MiB limit')
    return data


def decode(data):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, 'Duplicate JSON key')
            result[key] = value
        return result
    return json.loads(data.decode('utf-8-sig'), object_pairs_hook=unique)


def local_reference(root, reference):
    require(isinstance(reference, dict), 'Invalid local reference')
    relative = reference.get('path')
    require(nonempty(relative) and not Path(relative).is_absolute(), 'Reference must be relative')
    path = (root / relative).resolve()
    require(path.is_relative_to(root.resolve()), 'Reference escapes evidence directory')
    require(hex_id(reference.get('sha256'), 64), 'Missing reference SHA256')
    data = read_bytes(path)
    require(hashlib.sha256(data).hexdigest() == reference['sha256'], 'Reference hash mismatch')
    return data


def expected_rows(markets):
    return set(PHASES) | {'market.' + x for x in markets} | {'provider.' + x for x in PROVIDERS}


def collect(packet_path, appsourcecop_path):
    """Validate receipt custody and coverage, independently of runtime acceptance."""
    packet_path = Path(packet_path)
    packet_bytes = read_bytes(packet_path)
    packet = decode(packet_bytes)
    config = decode(read_bytes(appsourcecop_path))
    require(isinstance(packet, dict) and packet.get('schema') == 1, 'Unsupported packet schema')
    markets = config['supportedCountries']
    require(isinstance(markets, list) and len(markets) == 14 and
            all(isinstance(x, str) and re.fullmatch('[A-Z]{2}', x) for x in markets) and
            len(set(markets)) == 14, 'Expected the existing 14-market source inventory')
    require(packet.get('markets') == markets and packet.get('providers') == list(PROVIDERS),
            'Market/provider matrix differs from source contract')
    source = packet.get('sourceCommit')
    require(hex_id(source, 40), 'Missing exact source commit')
    references = packet.get('receipts')
    require(isinstance(references, list) and len(references) <= MAX_RECEIPTS, 'Invalid/bounded receipt list')
    gaps = []
    candidate = packet.get('candidate')
    if candidate is None:
        gaps.append('candidate: missing immutable signed Default package identity')
    else:
        require(isinstance(candidate, dict) and candidate.get('appId') == APP_ID and
                candidate.get('publisher') == 'Origo' and candidate.get('friends') == [],
                'Default candidate identity/friend mismatch')
        require(nonempty(candidate.get('version')) and hex_id(candidate.get('sha256'), 64) and
                hex_id(candidate.get('contentSha256'), 64), 'Incomplete candidate package identity')
        require(candidate.get('sourceCommit') == source, 'Candidate source mismatch')
        require(nonempty(candidate.get('buildUrl')), 'Missing candidate build provenance')
        foundation = candidate.get('foundation', {})
        require(foundation.get('appId') == FOUNDATION_ID and foundation.get('version') == '28.0.3.530'
                and hex_id(foundation.get('sha256'), 64) and foundation.get('friends') == [],
                'Current candidate requires genuine Foundation 28.0.3.530 identity/hash and no friends')
    rows = expected_rows(markets)
    seen = set()
    files = set()
    verified = []
    for reference in references:
        raw = local_reference(packet_path.parent, reference)
        receipt = decode(raw)
        require(isinstance(receipt, dict), 'Receipt must be an object')
        row = receipt.get('row')
        require(isinstance(row, str) and row in rows and row not in seen, 'Unknown/duplicate receipt row')
        resolved = (packet_path.parent / reference['path']).resolve()
        require(resolved not in files, 'Receipt file reused')
        files.add(resolved)
        seen.add(row)
        require(receipt.get('sourceCommit') == source, 'Stale receipt source commit')
        require(nonempty(receipt.get('owner')) and nonempty(receipt.get('observedAt')), 'Missing receipt custody')
        require(receipt.get('outcome') in ('passed', 'failed', 'blocked'), 'Invalid receipt outcome')
        require(receipt.get('evidenceKind') in ('actual', 'fixture', 'diagnostic'), 'Missing evidence classification')
        artifacts = receipt.get('rawOutputs')
        require(isinstance(artifacts, list) and 0 < len(artifacts) <= 64, 'Missing/bounded raw outputs')
        for artifact in artifacts:
            local_reference(packet_path.parent, artifact)
        if receipt['evidenceKind'] != 'actual' or receipt['outcome'] != 'passed':
            gaps.append(row + ': ' + receipt['evidenceKind'] + '/' + receipt['outcome'])
        if candidate is None:
            gaps.append(row + ': no candidate to match')
        else:
            require(receipt.get('candidateSha256') == candidate['sha256'], 'Receipt candidate hash mismatch')
            require(receipt.get('foundation') == candidate['foundation'], 'Receipt Foundation identity mismatch')
        # Language fixtures never substitute for real test counts, even when locally valid.
        if row.endswith('.runtime'):
            counts = receipt.get('counts', {})
            keys = ('discovered', 'selected', 'executed', 'passed', 'failed', 'skipped', 'aborted', 'notRun')
            require(set(counts) == set(keys) and all(type(counts[k]) is int and counts[k] >= 0 for k in keys),
                    'Missing/invalid complete runtime counts')
            require(counts['executed'] == counts['passed'] + counts['failed'] + counts['aborted'] and
                    counts['selected'] == counts['executed'] + counts['skipped'] + counts['notRun'] and
                    counts['discovered'] == counts['selected'], 'Inconsistent/incomplete runtime totals')
            if counts['passed'] == 0 or any(counts[k] for k in ('failed', 'skipped', 'aborted', 'notRun')):
                gaps.append(row + ': incomplete or unsuccessful runtime')
        verified.append({'row': row, 'sha256': reference['sha256'], 'owner': receipt['owner'],
                         'evidenceKind': receipt['evidenceKind'], 'outcome': receipt['outcome']})
    gaps.extend(row + ': missing receipt' for row in sorted(rows - seen))
    return {'schema': 1, 'sourceCommit': source, 'packetSha256': hashlib.sha256(packet_bytes).hexdigest(),
            'markets': markets, 'providers': list(PROVIDERS), 'receipts': verified, 'gaps': gaps,
            'inventoryComplete': not gaps, 'candidateCertified': False, 'runnerCertified': False,
            'releaseReady': False, 'independentAcceptanceRequired': True,
            'boundary': 'Local hash/identity/coverage checks only; receipt claims require owner-supported raw-output review. '
                        'No signature trust, compiler consumption, market builds, provider access or runtime is executed.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('packet', type=Path)
    parser.add_argument('--appsourcecop', type=Path, default=Path(__file__).resolve().parents[1] / 'app/AppSourceCop.json')
    args = parser.parse_args()
    try:
        result = collect(args.packet, args.appsourcecop)
    except (EvidenceError, OSError, ValueError, KeyError, TypeError):
        # Input paths/content may be sensitive; no raw parser/OS exception in reports.
        print(json.dumps({'inventoryComplete': False, 'candidateCertified': False,
                          'releaseReady': False, 'error': 'Invalid, missing, oversized or inconsistent evidence input'}))
        return 1
    print(json.dumps(result, indent=2))
    return 0 if result['inventoryComplete'] else 2


if __name__ == '__main__':
    sys.exit(main())
