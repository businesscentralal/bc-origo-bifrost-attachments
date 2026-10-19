"""Review-only workflow regression checks. Requires PyYAML 6; never applies the patch."""
import copy
from pathlib import Path
import sys
import unittest

import yaml

BUILD = "steps.DetermineBuildProject.outputs.BuildIt == 'True'"
SIGNED = BUILD + " && inputs.buildMode == 'Default' && inputs.signArtifacts"
UPLOAD = "steps.appSourcePipeline.outcome == 'success' && (inputs.buildMode != 'Default' || !inputs.signArtifacts || steps.appSourceSigned.outcome == 'success') && "


def verify(original, proposed):
    before = original['jobs']['BuildALGoProject']['steps']
    steps = proposed['jobs']['BuildALGoProject']['steps']
    build = next(i for i, s in enumerate(steps) if '/RunPipeline@' in s.get('uses', ''))
    sign = next(i for i, s in enumerate(steps) if s.get('id') == 'sign')
    for stage, index, stage_id, condition in [('Pipeline', build + 1, 'appSourcePipeline', BUILD), ('Signed', sign + 1, 'appSourceSigned', SIGNED)]:
        gate = steps[index]
        assert gate['id'] == stage_id, f'{stage} gate must immediately follow its producer'
        assert gate['run'] == "./tools/Assert-AppSourceBuild.ps1 -Stage " + stage + " -Root '${{ github.workspace }}'", f'{stage} entry point changed'
        assert gate['if'] == condition, f'{stage} may be skipped or run in the wrong mode'
        assert gate['env'] == {'BuildMode': '${{ inputs.buildMode }}'}, f'{stage} lacks actual mode'
        assert gate['shell'] == 'pwsh', f'{stage} shell changed'
        assert not gate.get('continue-on-error'), f'{stage} failure is ignored'
        assert sum(s.get('id') == stage_id for s in steps) == 1, f'Duplicate {stage} gate'
    for name in ['Build', 'Sign', 'Read settings', 'Read secrets', 'Record container identity', 'Cleanup']:
        assert next(s for s in before if s['name'] == name) == next(s for s in steps if s['name'] == name), f'Existing {name} contract changed'
    for name in ['Publish artifacts - apps', 'Publish artifacts - test apps']:
        old = next(s for s in before if s['name'] == name)
        actual = next(s for s in steps if s['name'] == name)
        assert actual['if'] == UPLOAD + old['if'], f'{name} may bypass final validation'
        assert actual['with']['if-no-files-found'] == 'error', f'{name} silently accepts absent output'
        assert not actual.get('continue-on-error'), f'{name} failure is ignored'
    receipts = next(s for s in steps if s['name'] == 'Publish artifacts - final AppSource receipts')
    assert '(success() || failure())' in receipts['if'], 'Failure receipts are lost'
    assert receipts['with']['path'].splitlines() == ["${{ inputs.project }}/.buildartifacts/AppSourceGate/**/" + name + '.json' for name in ['finalize', 'pipeline', 'signed']], 'Receipt allowlist changed'


class ProposalTests(unittest.TestCase):
    def test_proposal_and_negative_mutations(self):
        verify(ORIGINAL, PROPOSED)
        mutations = []
        for stage_id in ['appSourcePipeline', 'appSourceSigned']:
            for key, value in [('if', 'false'), ('continue-on-error', True), ('run', "Write-Host 'passed'"), ('env', {}), ('shell', 'bash')]:
                candidate = copy.deepcopy(PROPOSED)
                gate = next(s for s in candidate['jobs']['BuildALGoProject']['steps'] if s.get('id') == stage_id)
                gate[key] = value
                mutations.append((stage_id + ':' + key, candidate))
            candidate = copy.deepcopy(PROPOSED)
            steps = candidate['jobs']['BuildALGoProject']['steps']
            steps[:] = [s for s in steps if s.get('id') != stage_id]
            mutations.append((stage_id + ':missing', candidate))
        for name in ['Publish artifacts - apps', 'Publish artifacts - test apps']:
            candidate = copy.deepcopy(PROPOSED)
            next(s for s in candidate['jobs']['BuildALGoProject']['steps'] if s['name'] == name)['if'] = 'always()'
            mutations.append((name + ':bypass', candidate))
        candidate = copy.deepcopy(PROPOSED)
        next(s for s in candidate['jobs']['BuildALGoProject']['steps'] if s['name'] == 'Sign')['if'] = 'false'
        mutations.append(('sign:disabled', candidate))
        for name, candidate in mutations:
            with self.subTest(name=name):
                with self.assertRaises((AssertionError, KeyError, StopIteration, IndexError)):
                    verify(ORIGINAL, candidate)
        print(f'Proposed workflow accepted; {len(mutations)} negative mutations rejected.')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('Usage: verify_proposal.py <original.yaml> <proposed.yaml>; requires PyYAML 6')
    ORIGINAL, PROPOSED = [yaml.safe_load(Path(p).read_text(encoding='utf-8')) for p in sys.argv[1:]]
    unittest.main(argv=[sys.argv[0]], verbosity=2)
