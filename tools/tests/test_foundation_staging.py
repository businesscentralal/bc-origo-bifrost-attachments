"""Real approved/colliding artifact bytes; tooling tests, not runner/trust proof."""
import copy
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parents[1]))
import stage_foundation_inputs as S
import appsource_gate as G


class Staging(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.input_dir = Path(os.environ['FOUNDATION_STAGING_ARTIFACTS'])
        cls.fixtures = Path(os.environ['APPSOURCE_GATE_FIXTURES'])
        cls.archives = {'Apps': cls.input_dir / 'foundation-ci-apps523.zip',
                        'TestApps': cls.input_dir / 'foundation-ci-test523.zip'}
        for kind, path in cls.archives.items():
            if G.file_hash(path) != S.ARTIFACTS[kind][1]:
                raise AssertionError('Genuine pinned artifact missing/changed')
        for name in ('default', 'testApp'):
            G.package_info(cls.fixtures / (name + '.app'))

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.context = dict(run='1234', attempt='2', sourceCommit='3' * 40, checkoutSha='4' * 40, mode='Default')
        self.request = dict(profile='controlled523', context=self.context, artifacts={kind: dict(archive=str(path), provenance=dict(
            repository='OrigoSoftwareSolutions/bc-origo-bifrost-core', sourceSha=S.SOURCE, run=S.RUN,
            attempt=2, artifactId=S.ARTIFACTS[kind][0], archiveSha256=S.ARTIFACTS[kind][1],
            expired=False, conclusion='success')) for kind, path in self.archives.items()},
            otherApps=[str(self.fixtures / 'default.app')], otherTestApps=[str(self.fixtures / 'testApp.app')])
        dependencies = self.root / 'dependencies'
        dependencies.mkdir()
        for name in ('default', 'testApp'):
            shutil.copyfile(self.fixtures / (name + '.app'), dependencies / (name + '.app'))
        self.request['otherApps'] = [str(dependencies / 'default.app')]
        self.request['otherTestApps'] = [str(dependencies / 'testApp.app')]
        self.dependencies = dependencies
        self.destination = self.root / 'stage'

    def stage(self):
        arrays = S.stage(self.request, self.destination)
        return arrays, json.loads((self.destination / 'selection.json').read_text())

    def test_both_download_orders_and_modes_preserve_signed_pin_and_genuine_dependencies(self):
        for mode in ('Default', 'Test'):
            for order in (['Apps', 'TestApps'], ['TestApps', 'Apps']):
                with self.subTest(mode=mode, order=order):
                    shared = self.root / ('legacy-' + mode + order[0])
                    shared.mkdir()
                    for kind in order:
                        with zipfile.ZipFile(self.archives[kind]) as z:
                            z.extractall(shared)
                    legacy = G.package_info(next(shared.glob('*.app')))
                    self.assertEqual(S.PIN if order[-1] == 'Apps' else S.TEST_PIN, legacy['sha256'])
                    self.request['context']['mode'] = mode
                    self.request['artifacts'] = {kind: self.request['artifacts'][kind] for kind in order}
                    self.destination = self.root / (mode + order[0])
                    arrays, receipt = self.stage()
                    self.assertEqual(2, len(arrays['installApps']))
                    self.assertEqual([str((self.dependencies / 'testApp.app').resolve())], arrays['installTestApps'])
                    self.assertEqual(S.PIN, next(x for x in receipt['selection']['after']['installApps'] if x['identity']['id'] == S.FOUNDATION)['sha256'])
                    self.assertEqual(S.TEST_PIN, receipt['selection']['excluded'][0]['sha256'])
                    self.assertFalse(receipt['signatureTrustVerified'])
                    S.validate(self.destination / 'selection.json', self.context, **self.validate_args(arrays))

    def validate_args(self, arrays):
        return dict(install_apps=arrays['installApps'], install_tests=arrays['installTestApps'])

    def test_all_source_artifact_provenance_negative_fields(self):
        for kind in S.ARTIFACTS:
            for key, value in [('sourceSha','f'*40), ('run',1), ('attempt',1), ('artifactId',1),
                               ('expired',True), ('conclusion','failure'), ('repository','wrong/repo'), ('archiveSha256','0'*64)]:
                request = copy.deepcopy(self.request)
                request['artifacts'][kind]['provenance'][key] = value
                with self.subTest(kind=kind, key=key), self.assertRaises(G.GateError):
                    S.stage(request, self.destination)
                self.assertFalse(self.destination.exists())

    def test_missing_and_changed_archive(self):
        for value in (self.root / 'absent.zip', self.root / 'changed.zip'):
            if value.name == 'changed.zip': value.write_bytes(self.archives['Apps'].read_bytes() + b'changed')
            self.request['artifacts']['Apps']['archive'] = str(value)
            with self.assertRaises(G.GateError): self.stage()

    def test_missing_unknown_artifact_and_mode(self):
        request = copy.deepcopy(self.request)
        del request['artifacts']['TestApps']
        with self.assertRaises(G.GateError): S.stage(request, self.destination)
        self.context['mode'] = 'Unknown'
        with self.assertRaises(G.GateError): self.stage()

    def test_duplicate_apps_candidate(self):
        _, receipt = self.stage()
        paths = [x['path'] for x in receipt['selection']['before']['installApps']]
        tests = [x['path'] for x in receipt['selection']['before']['installTestApps']]
        with self.assertRaisesRegex(G.GateError, 'duplicate Apps'): S.select(paths + [paths[0]], tests)

    def test_missing_testapps_collision_and_duplicate_collision(self):
        _, receipt = self.stage()
        paths = [x['path'] for x in receipt['selection']['before']['installApps']]
        tests = [x['path'] for x in receipt['selection']['before']['installTestApps']]
        collision = receipt['selection']['excluded'][0]['path']
        for value in ([x for x in tests if x != collision], tests + [collision]):
            with self.assertRaisesRegex(G.GateError, 'TestApps Foundation'): S.select(paths, value)

    def test_wrong_testapps_bytes_and_apps_friend_bearing_bytes(self):
        _, receipt = self.stage()
        paths = [x['path'] for x in receipt['selection']['before']['installApps']]
        tests = [x['path'] for x in receipt['selection']['before']['installTestApps']]
        approved = next(x for x in paths if G.package_info(x)['identity']['id'] == S.FOUNDATION)
        collision = receipt['selection']['excluded'][0]['path']
        original = Path(collision).read_bytes()
        shutil.copyfile(approved, collision)
        with self.assertRaisesRegex(G.GateError, 'Unrecognized'): S.select(paths, tests)
        Path(collision).write_bytes(original)
        shutil.copyfile(collision, approved)
        with self.assertRaisesRegex(G.GateError, 'Unapproved'): S.select(paths, tests)

    def test_genuine_wrong_identity_and_remaining_duplicate(self):
        _, receipt = self.stage()
        paths = [x['path'] for x in receipt['selection']['before']['installApps']]
        tests = [x['path'] for x in receipt['selection']['before']['installTestApps']]
        with self.assertRaisesRegex(G.GateError, 'Duplicate remaining helper AppId'): S.select(paths, tests + [str(self.dependencies / 'default.app')])
        foundation = next(x for x in paths if G.package_info(x)['identity']['id'] == S.FOUNDATION)
        shutil.copyfile(self.fixtures / 'default.app', foundation)
        with self.assertRaises(G.GateError): S.select(paths, tests)
        with self.assertRaises(G.GateError): S.select(paths, tests + [str(self.dependencies / 'default.app')])

    def test_parenthesized_test_library_keeps_helper_skip_run_policy(self):
        self.request['otherTestApps'] = ['(' + str(self.dependencies / 'testApp.app') + ')']
        arrays, receipt = self.stage()
        self.assertEqual(['(' + str((self.dependencies / 'testApp.app').resolve()) + ')'], arrays['installTestApps'])
        S.validate(self.destination / 'selection.json', self.context, **self.validate_args(arrays))
        self.assertEqual(1, len(receipt['selection']['after']['installTestApps']))

    def test_later_array_substitution_omission_and_reordering(self):
        arrays, receipt = self.stage()
        for apps in (arrays['installApps'][:-1], arrays['installApps'][::-1], [receipt['selection']['excluded'][0]['path']] + arrays['installApps'][1:]):
            with self.assertRaises(G.GateError): S.validate(self.destination / 'selection.json', self.context, apps, arrays['installTestApps'])

    def test_later_package_mutation_and_symbol_substitution(self):
        arrays, receipt = self.stage()
        collision = receipt['selection']['excluded'][0]['path']
        with self.assertRaises(G.GateError): S.validate(self.destination / 'selection.json', self.context, **self.validate_args(arrays), symbols=[collision])
        S.validate(self.destination / 'selection.json', self.context, **self.validate_args(arrays), symbols=arrays['installApps'])
        Path(arrays['installApps'][0]).write_bytes(Path(arrays['installApps'][0]).read_bytes() + b'changed')
        with self.assertRaises(G.GateError): S.validate(self.destination / 'selection.json', self.context, **self.validate_args(arrays))

    def test_mutation_fixtures_cannot_change_retained_compiler_packages(self):
        original = G.file_hash(self.fixtures / 'default.app')
        arrays, receipt = self.stage()
        Path(arrays['installApps'][0]).write_bytes(b'negative-case')
        with self.assertRaises(G.GateError):
            S.validate(self.destination / 'selection.json', self.context, **self.validate_args(arrays))
        self.assertEqual(original, G.file_hash(self.fixtures / 'default.app'))

    def test_missing_stale_and_mutated_receipt(self):
        with self.assertRaises(G.GateError): S.validate(self.destination / 'selection.json', self.context, [], [])
        arrays, receipt = self.stage()
        for key, value in [('run','999'), ('attempt','3'), ('sourceCommit','f'*40), ('checkoutSha','e'*40), ('mode','Test')]:
            context = {**self.context, key:value}
            with self.subTest(key=key), self.assertRaises(G.GateError):
                S.validate(self.destination / 'selection.json', context, **self.validate_args(arrays))
        receipt['selection']['after']['installTestApps'] = []
        (self.destination / 'selection.json').write_text(json.dumps(receipt))
        with self.assertRaises(G.GateError): S.validate(self.destination / 'selection.json', self.context, **self.validate_args(arrays))

    def test_existing_stage_is_not_deleted(self):
        self.stage()
        before = (self.destination / 'selection.json').read_bytes()
        with self.assertRaises(G.GateError): self.stage()
        self.assertEqual(before, (self.destination / 'selection.json').read_bytes())

    def test_bounded_paths_counts_and_nonlocal_input_fail_closed(self):
        for paths in (['https://example.invalid/token.app'], ['*.app'], [str(self.fixtures / 'testApp.app')] * 129):
            with self.assertRaises(G.GateError): S.inspect(paths)
        symlink = self.root / 'linked.app'; symlink.symlink_to(self.fixtures / 'default.app')
        with self.assertRaises(G.GateError): S.inspect([symlink])

    def test_archive_traversal_and_duplicate_layout_refused(self):
        for names in (['../bad.app'], ['bad.app','bad.app'], ['folder/bad.app']):
            archive = self.root / 'bad.zip'
            with zipfile.ZipFile(archive,'w') as z:
                for index, name in enumerate(names):
                    if index and name in names[:index]:
                        with self.assertWarnsRegex(UserWarning, 'Duplicate name'): z.writestr(name,b'bad')
                    else: z.writestr(name,b'bad')
            with self.assertRaises(G.GateError): S.extract_archive(archive,self.root)

    def test_rejected_receipt_is_allowlisted_and_preserves_actual_disk_hash(self):
        _, receipt = self.stage()
        output = self.root / 'rejected.json'
        collision = receipt['selection']['excluded'][0]['path']
        G.rejected_receipt(output, {**self.context, 'Settings': {'password':'do-not-emit'}, 'credential':'do-not-emit'}, [collision])
        text = output.read_text(); self.assertNotIn('do-not-emit',text)
        data = json.loads(text)
        self.assertFalse(data['accepted']); self.assertEqual(S.TEST_PIN,data['inputs'][0]['sha256'])
        self.assertEqual([S.TEST_FRIEND],data['inputs'][0]['friends'])
        self.assertEqual(S.SOURCE,data['inputs'][0]['sourceCommit'])

    def test_original_beforecompile_failure_retains_receipt(self):
        arrays, receipt = self.stage()
        (self.root / 'app').mkdir(); (self.root / 'test').mkdir()
        for folder, fixture in [('app','default'),('test','testApp')]:
            shutil.copyfile(self.fixtures / fixture / 'app.json',self.root / folder / 'app.json')
        directory = self.root / '.buildartifacts/AppSourceGate/Default'; directory.mkdir(parents=True)
        (directory / 'state.json').write_text(json.dumps(dict(context=self.context, receipts={})))
        symbols = self.root / 'symbols'; symbols.mkdir()
        shutil.copyfile(receipt['selection']['excluded'][0]['path'],symbols / 'Foundation.app')
        compiler_symbols = self.root/'compiler-symbols'
        compiler_symbols.mkdir()
        request = dict(context=self.context, manifest=str(self.root/'app/app.json'), symbolsFolder=str(symbols), compilerSymbolsFolder=str(compiler_symbols), kind='fixture')
        with self.assertRaisesRegex(G.GateError,'(?i)unapproved Foundation'): G.before_compile(self.root,request)
        rejected=json.loads((directory/'rejected-input.json').read_text())
        self.assertEqual(S.TEST_PIN,rejected['inputs'][0]['sha256'])

    def test_cli_rejection_nonzero_and_no_secret_console_dump(self):
        self.request['artifacts']['Apps']['provenance']['expired'] = True
        self.request['Settings'] = {'password':'do-not-emit'}
        request_path = self.root / 'request.json'; request_path.write_text(json.dumps(self.request))
        result = subprocess.run([sys.executable,S.__file__,'stage','--input',str(request_path),'--destination',str(self.destination)],capture_output=True,text=True)
        self.assertEqual(1,result.returncode); self.assertNotIn('do-not-emit',result.stdout+result.stderr)
        self.assertTrue((self.root/'stage-rejected.json').exists())


class Candidate530(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.config = S.PROFILES['candidate530']
        inputs = Path(os.environ['FOUNDATION_CANDIDATE_ARTIFACTS'])
        context = dict(run='1234', attempt='1', sourceCommit='3' * 40, checkoutSha='4' * 40, mode='Default')
        artifacts = {}
        for kind, (artifact, sha) in self.config['artifacts'].items():
            archive = inputs / f'foundation530-{artifact}.zip'
            self.assertEqual(sha, G.file_hash(archive))
            artifacts[kind] = dict(archive=str(archive), provenance=dict(repository='OrigoSoftwareSolutions/bc-origo-bifrost-core',
                sourceSha=self.config['source'], run=self.config['run'], attempt=self.config['attempt'],
                artifactId=artifact, archiveSha256=sha, expired=False, conclusion='success'))
        # Default production staging profile is candidate530.523is only explicit controlled fixture.
        self.request = dict(context=context, artifacts=artifacts)

    def test_actual_candidate_staging_retains_signed_apps_and_excludes_only_exact_test_collision(self):
        arrays = S.stage(self.request, self.root / 'stage')
        self.assertEqual(1, len(arrays['installApps']))
        self.assertEqual([], arrays['installTestApps'])
        info = G.package_info(arrays['installApps'][0])
        G.check_foundation_candidate(info)
        receipt = S.validate(self.root / 'stage/selection.json', self.request['context'], arrays['installApps'], arrays['installTestApps'])
        self.assertEqual('candidate530', receipt['profile'])
        self.assertFalse(receipt['signatureTrustVerified'])
        self.assertEqual(self.config['testPin'], receipt['selection']['excluded'][0]['sha256'])
        self.assertEqual([S.TEST_FRIEND], receipt['selection']['excluded'][0]['friends'])

    def test_wrong_candidate_source_archive_swap_and_wrong_profile_fail_closed(self):
        for change in ('source', 'swap', 'profile'):
            request = copy.deepcopy(self.request)
            if change == 'source': request['artifacts']['Apps']['provenance']['sourceSha'] = '0' * 40
            elif change == 'swap': request['artifacts']['Apps']['archive'] = request['artifacts']['TestApps']['archive']
            else: request['profile'] = 'controlled523'
            with self.subTest(change=change), self.assertRaises(G.GateError): S.stage(request, self.root / change)
            self.assertFalse((self.root / change).exists())

    def test_test_candidate_cannot_be_swapped_into_apps_or_mutated_after_staging(self):
        arrays = S.stage(self.request, self.root / 'stage')
        excluded = json.loads((self.root / 'stage/selection.json').read_text())['selection']['excluded'][0]['path']
        with self.assertRaises(G.GateError): S.select([excluded], [excluded], 'candidate530')
        with open(arrays['installApps'][0], 'ab') as out: out.write(b'mutated-tail')
        with self.assertRaises(G.GateError):
            S.validate(self.root / 'stage/selection.json', self.request['context'], arrays['installApps'], arrays['installTestApps'])

    def test_receipt_cannot_omit_archive_provenance(self):
        arrays = S.stage(self.request, self.root / 'stage')
        path = self.root / 'stage/selection.json'
        receipt = json.loads(path.read_text())
        for kinds in ([], ['Apps'], ['TestApps'], ['Apps', 'TestApps', 'Unknown']):
            changed = copy.deepcopy(receipt)
            changed['artifacts'] = {kind: receipt['artifacts'].get(kind, {}) for kind in kinds}
            path.write_text(json.dumps(changed))
            with self.subTest(kinds=kinds), self.assertRaisesRegex(G.GateError, 'receipt artifact'):
                S.validate(path, self.request['context'], arrays['installApps'], arrays['installTestApps'])

    def test_retained_archive_mutation_cannot_be_hidden_by_receipt_omission(self):
        # Copy the genuine archives: never mutate shared immutable evidence.
        for kind, entry in self.request['artifacts'].items():
            archive = self.root / (kind + '.zip')
            shutil.copyfile(entry['archive'], archive)
            entry['archive'] = str(archive)
        arrays = S.stage(self.request, self.root / 'stage')
        path = self.root / 'stage/selection.json'
        receipt = json.loads(path.read_text())
        with open(self.request['artifacts']['TestApps']['archive'], 'ab') as out:
            out.write(b'mutated-archive')
        with self.assertRaisesRegex(G.GateError, 'Changed artifact archive'):
            S.validate(path, self.request['context'], arrays['installApps'], arrays['installTestApps'])
        del receipt['artifacts']['TestApps']
        path.write_text(json.dumps(receipt))
        with self.assertRaisesRegex(G.GateError, 'receipt artifact'):
            S.validate(path, self.request['context'], arrays['installApps'], arrays['installTestApps'])


    def publish_candidate(self, mode='Default', order=('Apps', 'TestApps')):
        self.request['context']['mode'] = mode
        self.request['artifacts'] = {kind: self.request['artifacts'][kind] for kind in order}
        fixtures = Path(os.environ['APPSOURCE_GATE_FIXTURES'])
        scan = self.root / '.dependencies'
        scan.mkdir()
        for name in ('default', 'testApp'):
            shutil.copyfile(fixtures / (name + '.app'), scan / (name + '.app'))
        self.request['otherApps'] = [str(scan / 'default.app')]
        self.request['otherTestApps'] = ['(' + str(scan / 'testApp.app') + ')']
        destination = self.root / 'retained-stage'
        arrays = S.stage(self.request, destination)
        receipt = destination / 'selection.json'
        published = S.publish(receipt, self.request['context'], arrays['installApps'], arrays['installTestApps'], scan)
        return receipt, published, scan

    def test_workflow_uses_all_four_selected_consumer_inputs_and_step_local_settings(self):
        text = (Path(S.__file__).parents[1] / '.github/workflows/_BuildALGoProject.yaml').read_text()
        for field, output in [('dependencyAppsJson','InstallApps'), ('dependencyTestAppsJson','InstallTestApps'),
                              ('installAppsJson','InstallApps'), ('installTestAppsJson','InstallTestApps')]:
            self.assertEqual(1, text.count(field + ': ${{ steps.StageFoundationInputs.outputs.' + output + ' }}'))
        for block in re.split(r'(?m)^      - name:', text)[1:]:
            keys = re.findall(r'(?m)^        ([A-Za-z][A-Za-z0-9_-]*):', block)
            self.assertEqual(len(keys), len(set(keys)), 'Duplicate workflow step key')
        self.assertEqual(4, text.count("Settings: '${{ steps.AcquireFoundationInputs.outputs.ResolverSettings }}'"))
        preparation=text[text.index('- name: Validate selected inputs before Compile Apps'):text.index('- name: Compile Apps')]
        self.assertIn("Settings: '${{ steps.AcquireFoundationInputs.outputs.ResolverSettings }}'", preparation)
        self.assertIn('-Stage WorkspaceInitialize',preparation)
        self.assertLess(preparation.index('-Action PrepareManifest'),preparation.index('-Stage WorkspaceInitialize'))
        self.assertIn('workspaceCompilation.enabled',preparation)
        self.assertLess(text.index('- name: Acquire Foundation inputs'), text.index('- name: Download Project Dependencies'))
        self.assertLess(text.index('- name: Stage Foundation inputs'), text.index('- name: Compile Apps'))
        self.assertLess(text.index('- name: Compile Apps'), text.index('- name: Build\n'))
        self.assertIn("fromJson(env.workspaceCompilation).enabled == true", text)
        self.assertNotIn('GITHUB_ENV', (Path(S.__file__).parent/'Acquire-FoundationInputs.ps1').read_text())

    def test_publication_preserves_unrelated_sources_markers_and_excludes_collision(self):
        receipt, arrays, scan = self.publish_candidate()
        observation = S.validate_publication(receipt, self.request['context'], **arrays)
        self.assertFalse(observation['consumedInputsCertified'])
        self.assertEqual(3, len(S.publication_files(scan)))
        self.assertEqual(['(' + str(scan / 'testApp.app') + ')'], arrays['installTestApps'])
        foundation = [x for x in S.inspect(S.publication_files(scan)) if x['identity']['id'] == S.FOUNDATION]
        self.assertEqual([self.config['pin']], [x['sha256'] for x in foundation])
        excluded = json.loads(receipt.read_text())['selection']['excluded'][0]
        self.assertNotIn(excluded['path'], S.publication_files(scan))
        self.assertEqual(self.config['testPin'], G.file_hash(excluded['path']))

    def test_publication_rejects_cache_residue_changed_bytes_duplicate_and_unknown_source(self):
        receipt, arrays, scan = self.publish_candidate()
        excluded = json.loads(receipt.read_text())['selection']['excluded'][0]['path']
        cache = self.root / 'cache'; cache.mkdir()
        for name in S.publication_files(scan): shutil.copyfile(name, cache / Path(name).name)
        S.validate_publication(receipt, self.request['context'], **arrays, cache_roots=[cache])
        foundation = next(x for x in S.inspect(S.publication_files(cache)) if x['identity']['id'] == S.FOUNDATION)
        shutil.copyfile(excluded, foundation['path'])
        with self.assertRaisesRegex(G.GateError, 'Changed selected cache'):
            S.validate_publication(receipt, self.request['context'], **arrays, cache_roots=[cache])
        # Mutated cache must fail at both translation/final boundary checks.
        for boundary in ('translation', 'final'):
            with self.subTest(boundary=boundary), self.assertRaises(G.GateError):
                S.validate_publication(receipt, self.request['context'], **arrays, cache_roots=[cache])
        shutil.copyfile(arrays['installApps'][0], scan / 'residue.app')
        with self.assertRaisesRegex(G.GateError, 'publication inventory'):
            S.validate_publication(receipt, self.request['context'], **arrays)

    def test_publication_rejects_changed_array_marker_context_inventory_and_receipt(self):
        receipt, arrays, scan = self.publish_candidate()
        for key in ('installApps', 'installTestApps'):
            changed = copy.deepcopy(arrays); changed[key] = []
            with self.subTest(key=key), self.assertRaises(G.GateError):
                S.validate_publication(receipt, self.request['context'], **changed)
        changed = {**arrays, 'installTestApps': [arrays['installTestApps'][0][1:-1]]}
        with self.assertRaises(G.GateError): S.validate_publication(receipt, self.request['context'], **changed)
        with self.assertRaises(G.GateError):
            S.validate_publication(receipt, {**self.request['context'], 'mode': 'Test'}, **arrays)
        data = json.loads(receipt.read_text())
        data['publication']['selection']['installApps'] = []
        receipt.write_text(json.dumps(data))
        with self.assertRaises(G.GateError): S.validate_publication(receipt, self.request['context'], **arrays)

    def test_publication_refuses_scan_root_containing_retained_exclusion_or_unknown_inputs(self):
        arrays = S.stage(self.request, self.root / 'stage')
        with self.assertRaisesRegex(G.GateError, 'beneath publication'):
            S.publish(self.root / 'stage/selection.json', self.request['context'], arrays['installApps'], arrays['installTestApps'], self.root)
        scan = self.root / 'scan'; scan.mkdir()
        shutil.copyfile(Path(os.environ['APPSOURCE_GATE_FIXTURES']) / 'default.app', scan / 'unknown.app')
        before = G.file_hash(scan / 'unknown.app')
        with self.assertRaisesRegex(G.GateError, 'Unselected publication residue'):
            S.publish(self.root / 'stage/selection.json', self.request['context'], arrays['installApps'], arrays['installTestApps'], scan)
        self.assertEqual(before, G.file_hash(scan / 'unknown.app'))

    def test_actual_prepare_script_and_stock_consumer_array_seams_all_modes_orders(self):
        upstream = Path(os.environ['FOUNDATION_ADAPTER_UPSTREAM'])
        pwsh = os.environ['FOUNDATION_ADAPTER_PWSH']
        fixtures = Path(os.environ['APPSOURCE_GATE_FIXTURES'])
        source = Path(S.__file__).parents[1]
        for mode in ('Default', 'Test'):
            for workspace in (False, True):
                for order in (('Apps','TestApps'), ('TestApps','Apps')):
                    with self.subTest(mode=mode, workspace=workspace, order=order):
                        root = self.root / (mode + str(workspace) + order[0]); root.mkdir()
                        (root / 'tools').mkdir()
                        for name in ('stage_foundation_inputs.py','appsource_gate.py','Prepare-FoundationInputs.ps1'):
                            shutil.copyfile(source / 'tools' / name, root / 'tools' / name)
                        subprocess.run(['git','init','-q',str(root)],check=True)
                        subprocess.run(['git','-C',str(root),'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-q','--allow-empty','-m','Local integration fixture'],check=True)
                        sha = subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip()
                        (root / '.dependencies').mkdir()
                        for name in ('default','testApp'):
                            shutil.copyfile(fixtures / (name + '.app'), root / '.dependencies' / (name + '.app'))
                        stock = {'Apps':[str(root / '.dependencies/default.app')], 'TestApps':['(' + str(root / '.dependencies/testApp.app') + ')']}
                        for kind, paths in stock.items(): (root / (kind + '.json')).write_text(json.dumps(paths))
                        manifest = root / 'archives.json'
                        manifest.write_text(json.dumps(dict(profile='candidate530', artifacts={k:self.request['artifacts'][k] for k in order})))
                        temp = root / 'runner-temp'; temp.mkdir()
                        output = root / 'outputs.txt'; output.touch()
                        env = {**os.environ, 'RUNNER_TEMP':str(temp),'GITHUB_WORKSPACE':str(root),'GITHUB_RUN_ID':'1234','GITHUB_RUN_ATTEMPT':'1',
                               'GITHUB_SHA':'3'*40,'BuildMode':mode,'GITHUB_OUTPUT':str(output),'PYTHONDONTWRITEBYTECODE':'1'}
                        prepare = [pwsh,'-NoProfile','-NonInteractive','-File',str(root / 'tools/Prepare-FoundationInputs.ps1')]
                        result = subprocess.run(prepare + ['-Action','Stage','-ArchiveManifestPath',str(manifest),'-DownloadedApps',str(root/'Apps.json'),'-DownloadedTestApps',str(root/'TestApps.json')],env=env,capture_output=True,text=True)
                        self.assertEqual(0,result.returncode,result.stdout+result.stderr)
                        selected = temp / f'foundation-selected-1234-1-{mode}'
                        receipt = json.loads((selected/'selection.json').read_text())
                        self.assertEqual(sha,receipt['context']['checkoutSha'])
                        arrays = {k:json.loads((selected/(k+'.json')).read_text()) for k in ('installApps','installTestApps')}
                        self.assertEqual(stock['TestApps'],arrays['installTestApps'])
                        result = subprocess.run(prepare + ['-Action','Validate'],env=env,capture_output=True,text=True)
                        self.assertEqual(0,result.returncode,result.stdout+result.stderr)
                        # Execute the exact stock read/copy statements on genuine selected
                        # inputs. External compilation/containers are not mocked as green.
                        compile_source=(upstream/'CompileApps/Compile.ps1').read_text()
                        reader=compile_source[compile_source.index('    $dependencyApps = @()'):compile_source.index('    # Set up a compiler folder')]
                        copier=compile_source[compile_source.index('    # Copy dependency apps'):compile_source.index('    # Incremental Builds')]
                        pipeline=(upstream/'RunPipeline/RunPipeline.ps1').read_text()
                        begin=pipeline.index('    if ($installAppsJson')
                        end=pipeline.index('    #',begin)
                        # RunPipeline reader block ends immediately before its following
                        # declaration; find by AST-balanced stock block using known marker.
                        tail=pipeline[begin:]
                        next_block=tail.index('    if ($settings.runTestsInAllInstalledTestApps)')
                        pipeline_reader=tail[:next_block]
                        cache=root/'workspace-cache';cache.mkdir()
                        script=root/'stock-consumers.ps1'
                        script.write_text("param($apps,$tests,$cache)\n$ErrorActionPreference='Stop'\nfunction OutputDebug { param($message) }\nfunction OutputWarning { param($message) throw $message }\n$dependencyAppsJson=$apps;$dependencyTestAppsJson=$tests;$packageCachePath=$cache\n" + reader + copier + "\n$install=@{Apps=@();TestApps=@()};$installAppsJson=$apps;$installTestAppsJson=$tests\n" + pipeline_reader + "\n@{apps=@($install.Apps);tests=@($install.TestApps)} | ConvertTo-Json -Depth 10\n")
                        result=subprocess.run([pwsh,'-NoProfile','-NonInteractive','-File',str(script),str(selected/'installApps.json'),str(selected/'installTestApps.json'),str(cache)],env=env,capture_output=True,text=True)
                        self.assertEqual(0,result.returncode,result.stdout+result.stderr)
                        loaded=json.loads(result.stdout)
                        self.assertEqual(arrays['installApps'],loaded['apps']);self.assertEqual(arrays['installTestApps'],loaded['tests'])
                        S.validate_publication(selected/'selection.json',receipt['context'],**arrays,cache_roots=[cache])
                        evidence_path = os.environ.get('FOUNDATION_ADAPTER_EVIDENCE')
                        if evidence_path:
                            record = dict(mode=mode, workspaceCompilation=workspace, archiveOrder=list(order),
                                          context=receipt['context'], selectedArrays=arrays, publication=receipt['publication'],
                                          observedCache=S.inspect(S.publication_files(cache)), stockConsumerArrays=loaded,
                                          compileExecuted=False, consumedInputsCertified=False)
                            with open(evidence_path, 'a') as out: out.write(json.dumps(record) + '\n')
                        state_dir = root / '.buildartifacts/AppSourceGate' / mode
                        state_dir.mkdir(parents=True)
                        (state_dir/'state.json').write_text(json.dumps(dict(context=receipt['context'], receipts={})))
                        result=subprocess.run(prepare + ['-Action','Validate','-CacheRoot',str(cache)],env=env,capture_output=True,text=True)
                        self.assertEqual(0,result.returncode,result.stdout+result.stderr)
                        # Excluded collision introduced after consumer observation fails.
                        foundation=next(x for x in S.inspect(S.publication_files(cache)) if x['identity']['id']==S.FOUNDATION)
                        shutil.copyfile(receipt['selection']['excluded'][0]['path'],foundation['path'])
                        result=subprocess.run(prepare + ['-Action','Validate','-CacheRoot',str(cache)],env=env,capture_output=True,text=True)
                        self.assertNotEqual(0,result.returncode)
                        self.assertEqual(self.config['pin'],G.file_hash(next(x for x in arrays['installApps'] if G.package_info(x)['identity']['id']==S.FOUNDATION)))


if __name__ == '__main__': unittest.main()
