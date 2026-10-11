"""Bounded local-only Foundation artifact staging; no download or trust verdict.

Run before Run-AlPipeline/AL-Go dependency extraction. The separate pipeline
owner must apply the returned local-file arrays; this tool installs no hooks.
"""
import argparse
import json
import re
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path, PurePosixPath
from appsource_gate import GateError, require, file_hash, package_info, rejected_receipt

FOUNDATION = '7505e808-6e52-4b96-a328-82573391297a'
SOURCE = '336b91d9fff11b71ae5cd75dee08186d4218bf07'
RUN = 37544940349
PIN = '5901bebe66b44e91ed6110620e62ee45d122ba9e0378dcfda4aeef4d00d3ae0f'
TEST_PIN = '72f58d821884f85e7f8fd078f8f909860d13cded7fa5eec8106f653d42c3cbc3'
ARTIFACTS = {
    'Apps': (11459147009, 'abb1a99fa84b3953cc6fe04f321fca3d6c330a118406b484a85371912bb9e47f'),
    'TestApps': (11459677378, 'e416c1674ac4b88e4ae8a13e278dbab2a6031c2ee2b87ac89b219523f96f9a3e'),
}
IDENTITY = dict(id=FOUNDATION, publisher='Origo', name='Bifrost Foundation', version='28.0.2.523')
TEST_FRIEND = dict(id='9db1a0c9-c503-4793-a9e4-bcda3d3f3c94', publisher='Origo', name='Bifrost Foundation - Tests')
BUILD_URL = f'https://github.com/OrigoSoftwareSolutions/bc-origo-bifrost-core/actions/runs/{RUN}'
MAX_FILES = 128
MAX_BYTES = 128 * 1024 * 1024

PROFILES = {
    'controlled523': dict(source=SOURCE, run=RUN, attempt=2, artifacts=ARTIFACTS,
                          identity=IDENTITY, pin=PIN, testPin=TEST_PIN, buildUrl=BUILD_URL),
    'candidate530': dict(source='8ec074f4ac69ac9bde15807cf16d21bee045332f', run=37679390622, attempt=1,
        artifacts={
            'Apps': (11508979803, '21c6331c47d3134d1f3c8c77f240d021fa47710f6fbdebc974b733e0b708bad8'),
            'TestApps': (11510930013, '0a4a24e4fa1afc56e60c00ea807d8cd9a91f55f21f144c81f458e14521bd0e73'),
        },
        identity=dict(id=FOUNDATION, publisher='Origo', name='Bifrost Foundation', version='28.0.3.530'),
        pin='b95e0eccf7a4038531cea08f0441e757ac176c7c4ff06b1b8eb9d25ac0dd3a88',
        testPin='391ba3df7917913ce4fd932096e0f8d5e474d45d0ee78c090f5abee37b1fbfe7',
        buildUrl='https://github.com/OrigoSoftwareSolutions/bc-origo-bifrost-core/actions/runs/37679390622'),
}


def profile_config(name):
    require(name in PROFILES, 'Unknown Foundation staging profile')
    return PROFILES[name]


def context_check(context):
    require(set(context) == {'run', 'attempt', 'sourceCommit', 'checkoutSha', 'mode'}, 'Unexpected/missing staging context fields')
    require(context['mode'] in ('Default', 'Test'), 'Unsupported staging mode')
    for key in ('sourceCommit', 'checkoutSha'):
        require(re.fullmatch('[a-f0-9]{40}', context[key]) is not None, 'Invalid staging source SHA')
    for key in ('run', 'attempt'):
        require(re.fullmatch('[1-9][0-9]*', str(context[key])) is not None, 'Invalid staging run/attempt')


def provenance_check(kind, provenance, archive, profile="controlled523"):
    config = profile_config(profile)
    artifact, sha = config["artifacts"][kind]
    expected = dict(repository='OrigoSoftwareSolutions/bc-origo-bifrost-core', sourceSha=config["source"],
                    run=config["run"], attempt=config["attempt"], artifactId=artifact, archiveSha256=sha, expired=False, conclusion='success')
    require(provenance == expected, 'Missing/expired/wrong-source artifact provenance')
    require(Path(archive).is_file() and Path(archive).stat().st_size <= MAX_BYTES, 'Missing/oversized artifact archive')
    require(file_hash(archive) == sha, 'Changed artifact archive')


def extract_archive(archive, destination):
    """Extract only bounded flat app files, never arbitrary artifact paths."""
    with zipfile.ZipFile(archive) as z:
        files = z.infolist()
        require(0 < len(files) <= MAX_FILES, 'Missing/too many artifact entries')
        require(sum(x.file_size for x in files) <= MAX_BYTES, 'Artifact expansion exceeds cap')
        require(len({x.filename.casefold() for x in files}) == len(files), 'Duplicate artifact paths')
        for item in files:
            path = PurePosixPath(item.filename)
            require(len(path.parts) == 1 and not path.is_absolute() and '\\' not in item.filename
                    and path.suffix.lower() == '.app' and not item.is_dir(), 'Unsupported artifact layout')
            require((item.external_attr >> 16) & 0o170000 != 0o120000, 'Artifact symlink refused')
            target = destination / item.filename
            target.write_bytes(z.read(item))


def inspect(paths):
    require(len(paths) <= MAX_FILES, 'Too many helper inputs')
    result = []
    total = 0
    for path in paths:
        value = str(path)
        wrapped = value.startswith('(') and value.endswith(')')
        path = Path(value[1:-1] if wrapped else value)
        require(path.is_file() and not path.is_symlink() and path.suffix.lower() == '.app', 'Only explicit local app files supported')
        total += path.stat().st_size
        require(total <= MAX_BYTES, 'Helper input bytes exceed cap')
        result.append({'path': str(path.resolve()), 'helperInput': '(' + str(path.resolve()) + ')' if wrapped else str(path.resolve()), **package_info(path)})
    return result


def select(app_paths, test_paths, profile="controlled523"):
    """Compose actual helper string[] file inputs; remove only verified collision."""
    config = profile_config(profile)
    apps, tests = inspect(app_paths), inspect(test_paths)
    require(all(x['helperInput'] == x['path'] for x in apps), 'Wrapped installApps unsupported by helper')
    foundation = [x for x in apps if x['identity']['id'].lower() == FOUNDATION]
    require(len(foundation) == 1, 'Missing/duplicate Apps Foundation candidates')
    approved = foundation[0]
    require(approved['identity'] == config['identity'] and approved['sha256'] == config['pin'] and approved['friends'] == []
            and approved['sourceCommit'] == config['source'] and approved['buildUrl'] == config['buildUrl'],
            'Unapproved Apps Foundation package/identity/friends/source')
    collisions = [x for x in tests if x['identity']['id'].lower() == FOUNDATION]
    require(len(collisions) == 1, 'Missing/duplicate TestApps Foundation candidates')
    collision = collisions[0]
    require(collision['identity'] == config['identity'] and collision['sha256'] == config['testPin']
            and collision['friends'] == [TEST_FRIEND] and collision['sourceCommit'] == config['source']
            and collision['buildUrl'] == config['buildUrl'], 'Unrecognized TestApps collision')
    selected_tests = [x for x in tests if x['identity']['id'].lower() != FOUNDATION]
    selected = apps + selected_tests
    ids = [x['identity']['id'].lower() for x in selected]
    require(len(ids) == len(set(ids)), 'Duplicate remaining helper AppId')
    names = [Path(x['path']).name.casefold() for x in selected]
    require(len(names) == len(set(names)), 'Remaining helper filename collision')
    key = lambda x: (x['identity']['id'].lower(), x['path'])
    return dict(before={'installApps': apps, 'installTestApps': tests},
                after={'installApps': sorted(apps, key=key), 'installTestApps': sorted(selected_tests, key=key)},
                excluded=[collision])


def validate(receipt_path, context, install_apps, install_tests, symbols=None):
    """Re-read actual consumed arrays/bytes immediately before helper or compiler."""
    context_check(context)
    require(Path(receipt_path).is_file(), 'Missing staging receipt')
    receipt = json.loads(Path(receipt_path).read_text())
    require(receipt['context'] == context and receipt['schema'] == 2, 'Stale/wrong staging receipt')
    profile = receipt['profile']
    config = profile_config(profile)
    for kind, paths in [('installApps', install_apps), ('installTestApps', install_tests)]:
        actual = inspect(paths)
        require(actual == receipt['selection']['after'][kind], 'Changed/substituted helper input array or package')
    for kind, entry in receipt['artifacts'].items():
        provenance_check(kind, entry['provenance'], entry['archive'], profile)
    # Validate exclusion and approved identity too; a receipt alone is not authority.
    original = receipt['selection']['before']
    selected = select([x['helperInput'] for x in original['installApps']], [x['helperInput'] for x in original['installTestApps']], profile)
    require(selected == receipt['selection'], 'Staging receipt inventory changed')
    if symbols is not None:
        candidates = [x for x in inspect(symbols) if x['identity']['id'].lower() == FOUNDATION]
        require(len(candidates) == 1 and candidates[0]['sha256'] == config['pin'], 'Changed/missing compiler Foundation input')
    return receipt


def stage(request, destination):
    """Use immutable archives and a fresh directory. Never delete another input."""
    profile = request.get('profile', 'candidate530')
    profile_config(profile)
    context = request['context']
    context_check(context)
    destination = Path(destination)
    require(not destination.exists(), 'Existing staging directory/receipts cannot be reused')
    require(set(request['artifacts']) == set(ARTIFACTS), 'Missing/unknown dependency artifact')
    for kind, entry in request['artifacts'].items():
        provenance_check(kind, entry['provenance'], entry['archive'], profile)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='foundation-stage-', dir=destination.parent) as temp:
        work = Path(temp)
        for kind in ARTIFACTS:
            folder = work / kind
            folder.mkdir()
            extract_archive(request['artifacts'][kind]['archive'], folder)
        # Validate before committing a staging result. Other genuine dependencies
        # are explicit files, never URLs, GUIDs, wildcards or secret-bearing settings.
        apps = sorted((work / 'Apps').glob('*.app')) + request.get('otherApps', [])
        tests = sorted((work / 'TestApps').glob('*.app')) + request.get('otherTestApps', [])
        select(apps, tests, profile)
        shutil.copytree(work, destination)
    selection = select(sorted((destination / 'Apps').glob('*.app')) + request.get('otherApps', []),
                       sorted((destination / 'TestApps').glob('*.app')) + request.get('otherTestApps', []), profile)
    receipt = dict(schema=2, profile=profile, context=context, artifacts=request['artifacts'], selection=selection, signatureTrustVerified=False)
    receipt_path = destination / 'selection.json'
    receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
    arrays = {kind: [x['helperInput'] for x in items] for kind, items in selection['after'].items()}
    validate(receipt_path, context, arrays['installApps'], arrays['installTestApps'])
    return arrays


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['stage', 'validate'])
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--destination', type=Path, required=True)
    args = parser.parse_args()
    request = {}
    try:
        request = json.loads(args.input.read_text())
        if args.action == 'stage':
            arrays = stage(request, args.destination)
            (args.destination / 'helper-inputs.json').write_text(json.dumps(arrays, indent=2) + '\n')
            for kind, paths in arrays.items():
                (args.destination / (kind + '.json')).write_text(json.dumps(paths, indent=2) + '\n')
        else:
            validate(args.destination / 'selection.json', request['context'], request['installApps'],
                     request['installTestApps'], request.get('symbols'))
        print('Foundation input ' + args.action + ' passed; signature trust not verified')
        return 0
    except (GateError, OSError, ValueError, KeyError, zipfile.BadZipFile):
        try:
            paths = request.get('installApps', []) + request.get('installTestApps', [])
            rejected_receipt(args.destination.parent / (args.destination.name + '-rejected.json'), request.get('context', {}), paths)
        except (OSError, ValueError, KeyError):
            pass
        print('Foundation input staging/selection failed; original failure retained', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
