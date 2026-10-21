"""Remove AL-Go's previous self-app from the actual compile cache, before the gate.

This is cache preparation, not certification. The unchanged AppSource gate must
still inventory and validate every remaining actual input before compilation.
"""
import argparse
import json
from pathlib import Path
from appsource_gate import GateError, file_hash, package_info, require


def prune(root, project, symbols):
    root = Path(root).resolve()
    project = Path(project).resolve()
    symbols = Path(symbols)
    require(project in (root / 'app', root / 'test'), 'Unknown compiling project')
    require(not symbols.is_symlink() and symbols.resolve() == root / '.packages',
            'Self-cache cleanup requires the owned workspace .packages folder')
    manifest = json.loads((project / 'app.json').read_text(encoding='utf-8-sig'))
    expected = {key: manifest[key] for key in ('id', 'publisher', 'name')}
    require(symbols.is_dir(), 'Actual symbol cache missing')
    packages = sorted(path for path in symbols.iterdir() if path.suffix.lower() == '.app')
    require(len(packages) <= 128, 'Too many cache packages')
    # Inspect every input before deleting any; malformed or linked inputs fail closed.
    measured = [(path, package_info(path, allow_ready_to_run=True)) for path in packages]
    removals = []
    for path, info in measured:
        identity = info['identity']
        if identity['id'].lower() != expected['id'].lower():
            continue
        require(all(identity[key] == expected[key] for key in ('publisher', 'name')),
                'Self-app ID has unexpected publisher/name')
        require(not path.is_symlink() and file_hash(path) == info['sha256'],
                'Self-app changed after cache inspection')
        removals.append((path, info))
    for path, info in removals:
        path.unlink()
    return {'project': project.name, 'removed': [
        {'file': path.name, 'identity': info['identity'], 'sha256': info['sha256']}
        for path, info in removals]}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('root', 'project', 'symbols'):
        parser.add_argument('--' + name, required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(prune(args.root, args.project, args.symbols)))
    except (GateError, OSError, ValueError, KeyError) as error:
        parser.exit(1, f'Self-cache preparation failed: {error}\n')
