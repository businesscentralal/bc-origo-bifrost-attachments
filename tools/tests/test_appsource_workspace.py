"""Workspace boundary regressions using genuine compiled packages and pinned sources.

Controlled compiler fixture bytes are not runtime/compiler/signature certification.
"""
import copy,json,os,shutil,sys,tempfile,time,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parents[1]))
import appsource_gate as G
import stage_foundation_inputs as S

class Workspace(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        # Optional evidence publication never changes assertions or omits tests.
        evidence=os.environ.get('FOUNDATION_WORKSPACE_EVIDENCE')
        if evidence:
            def retain():
                out=Path(evidence)/self.id();out.mkdir(parents=True,exist_ok=True)
                if hasattr(self,'request'):(out/'request.json').write_text(json.dumps(self.request,indent=2))
                for folder in ['.buildartifacts','app','test','out/Logs','errors']:
                    source=self.root/folder
                    if source.exists():shutil.copytree(source,out/folder,dirs_exist_ok=True)
            self.addCleanup(retain)
        self.fixtures=Path(os.environ['APPSOURCE_GATE_FIXTURES'])
        self.candidate=Path(os.environ['FOUNDATION_CANDIDATE_ARTIFACTS'])
        self.module=Path(os.environ['FOUNDATION_WORKSPACE_MODULE'])
        self.product=G.package_info(self.fixtures/'default.app')
        self.test=G.package_info(self.fixtures/'testApp.app')
        self.context=dict(mode='Default',run='1234',attempt='1',job='workspace-fixture',sourceCommit=self.product['sourceCommit'],checkoutSha='2'*40,buildUrl=self.product['buildUrl'])
        for name,info in [('app',self.product),('test',self.test)]:
            folder=self.root/name;folder.mkdir();(folder/'app.json').write_text(json.dumps(info['identity']))
            (folder/'fixture.al').write_text('codeunit 50100 "Fixture ori" {}')
        self.cache=self.root/'cache';self.cache.mkdir();self.out=self.root/'out';self.out.mkdir()
        self.workspace=self.root/'workspace.code-workspace'
        self.workspace.write_text(json.dumps(dict(folders=[dict(path='app')])))
        tool_dir=self.root/'compiler';tool_dir.mkdir();tools={}
        for name in ['compiler','altool','compilerPackage','CodeCop','UICop','AppSourceCop','Analyzers.Common']:
            p=tool_dir/name;p.write_bytes(name.encode());tools[name]=dict(path=str(p),sha256=G.file_hash(p),version=self.product['compilerVersion'])
        tools['workspaceModule']=dict(path=str(self.module),sha256=G.file_hash(self.module))
        params={k:None for k in G.WORKSPACE_KEYS}
        params.update(ALToolPath=tools['altool']['path'],WorkspaceFile=str(self.workspace),PackageCachePath=str(self.cache),OutFolder=str(self.out),Analyzers=['CodeCop','UICop','AppSourceCop'],MaxCpuCount=2,SourceCommit=self.context['sourceCommit'],ReportSuppressedDiagnostics=False,EnableExternalRulesets=False,GenerateReportLayout=True)
        settings=dict(workspaceCompilation=dict(enabled=True),enableCodeCop=True,enableUICop=True,enableAppSourceCop=True,enableCodeAnalyzersOnTestApps=True,failOn='warning',type='AppSource App')
        self.request=dict(context=self.context,appType='app',parameters=params,tools=tools,settings=settings)
        c=S.PROFILES['candidate530']
        artifacts={k:dict(archive=str(self.candidate/f'foundation530-{v[0]}.zip'),provenance=dict(repository='OrigoSoftwareSolutions/bc-origo-bifrost-core',sourceSha=c['source'],run=c['run'],attempt=c['attempt'],artifactId=v[0],archiveSha256=v[1],expired=False,conclusion='success')) for k,v in c['artifacts'].items()}
        self.stage_request=dict(profile='candidate530',context={k:self.context[k] for k in ('run','attempt','mode','sourceCommit','checkoutSha')},artifacts=artifacts,otherApps=[],otherTestApps=[])
        self.selection=self.root/'selected'
        self.publish()
    def publish(self):
        if self.selection.exists():shutil.rmtree(self.selection)
        publication=self.root/'.dependencies'
        if publication.exists():shutil.rmtree(publication)
        self.stage_request['context']={k:self.context[k] for k in ('run','attempt','mode','sourceCommit','checkoutSha')}
        arrays=S.stage(self.stage_request,self.selection)
        S.publish(self.selection/'selection.json',self.stage_request['context'],arrays['installApps'],arrays['installTestApps'],publication)
        self.request['selection']=str(self.selection/'selection.json')
        selected=json.loads((self.selection/'selection.json').read_text())
        source=selected['publication']['selection']['installApps'][0]['path']
        shutil.copyfile(source,self.cache/'foundation.app')
    def compile_fixture(self,name='default'):
        # Mimic current-run compiler cache and output-copy contract with actual
        # compiler-produced immutable packages. No compiler execution claimed.
        output=self.out/(name+'.app');cached=self.cache/(name+'.app')
        shutil.copyfile(self.fixtures/(name+'.app'),cached);shutil.copyfile(cached,output)
        log_dir=self.out/'Logs';log_dir.mkdir(exist_ok=True)
        shutil.copyfile(self.fixtures/(name+'.log'),log_dir/(name+'.log'))
        self.request['appFiles']=[str(output)]
    def test_default_boundary_and_baseline_inputs(self):
        # Real baseline file already present before hooks, unchanged after output.
        baseline=self.cache/'baseline.app';shutil.copyfile(self.fixtures/'testApp.app',baseline)
        # Unselected non-Microsoft baseline is refused rather than silently trusted.
        with self.assertRaises(G.GateError):G.workspace_before(self.root,self.request)
        baseline.unlink()
        before=G.workspace_before(self.root,self.request);self.compile_fixture()
        after=G.workspace_post(self.root,self.request)
        self.assertFalse(before['consumedInputsCertified']);self.assertFalse(after['consumedInputsCertified'])
        self.assertEqual([],after['outputs'][0]['friends'])
    def test_test_mode_product_then_test_and_exact_hash(self):
        self.context['mode']='Test'
        friend={k:self.test['identity'][k] for k in ('id','publisher','name')}
        (self.root/'app/app.json').write_text(json.dumps({**self.product['identity'],'internalsVisibleTo':[friend]}))
        self.publish();G.workspace_before(self.root,self.request);self.compile_fixture('friend')
        receipt=G.workspace_post(self.root,self.request)
        self.assertEqual([friend],receipt['outputs'][0]['friends'])
        self.workspace.write_text(json.dumps(dict(folders=[dict(path='test')])))
        self.request['appType']='testApp';G.workspace_before(self.root,self.request);self.compile_fixture('testApp')
        receipt=G.workspace_post(self.root,self.request);self.assertEqual([],receipt['outputs'][0]['friends'])
    def test_self_input_incremental_stale_output_refused(self):
        shutil.copyfile(self.fixtures/'default.app',self.cache/'stale.app')
        with self.assertRaises(G.GateError):G.workspace_before(self.root,self.request)
    def test_unexpected_types_and_unprepared_friend(self):
        for value in ('','bcptApp','unexpected'):
            request=copy.deepcopy(self.request);request['appType']=value
            with self.subTest(value=value),self.assertRaises(G.GateError):G.workspace_before(self.root,request)
        (self.root/'app/app.json').write_text(json.dumps({**self.product['identity'],'internalsVisibleTo':[self.test['identity']]}))
        with self.assertRaises(G.GateError):G.workspace_before(self.root,self.request)
    def test_actual_ref_parameters_changed_after_pre_refused(self):
        G.workspace_before(self.root,self.request);self.compile_fixture()
        self.request['parameters']['Features']=['changed']
        with self.assertRaises(G.GateError):G.workspace_post(self.root,self.request)
    def test_tools_analyzers_warning_and_module_negative_contracts(self):
        for mutate in [lambda r:r['parameters'].update(Analyzers=['CodeCop']),lambda r:r['settings'].update(failOn='none'),lambda r:r['parameters'].update(Ruleset='suppress.json'),lambda r:r['tools']['workspaceModule'].update(sha256='0'*64),lambda r:r['parameters'].update(CustomAnalyzers=['untrusted']),lambda r:r['parameters'].update(MaxCpuCount=0)]:
            request=copy.deepcopy(self.request);mutate(request)
            with self.assertRaises(G.GateError):G.workspace_before(self.root,request)
        # Classic remains strict, including direct workspace-refusal regression.
        with self.assertRaises(G.GateError):G.validate_parameters(dict(enableCodeCop=True,enableUICop=True,enableAppSourceCop=True,failOn='warning',escapeFromCops=False,workspaceCompilation=True))
    def test_new_unknown_cache_input_refused(self):
        G.workspace_before(self.root,self.request);self.compile_fixture()
        shutil.copyfile(self.fixtures/'testApp.app',self.cache/'unknown.app')
        with self.assertRaises(G.GateError):G.workspace_post(self.root,self.request)
    def test_warning_and_stale_log_refused(self):
        G.workspace_before(self.root,self.request);self.compile_fixture()
        log=self.out/'Logs/default.log';log.write_text(log.read_text()+'\nwarning AA0001: real refusal\n')
        with self.assertRaises(G.GateError):G.workspace_post(self.root,self.request)
    def test_ambiguous_multi_project_and_output_refused(self):
        self.workspace.write_text(json.dumps(dict(folders=[dict(path='app'),dict(path='app')])))
        with self.assertRaises(G.GateError):G.workspace_before(self.root,self.request)
        self.workspace.write_text(json.dumps(dict(folders=[dict(path='app')])))
        G.workspace_before(self.root,self.request);self.compile_fixture()
        self.request['appFiles']*=2
        with self.assertRaises(G.GateError):G.workspace_post(self.root,self.request)
    def test_mode_run_attempt_source_and_tool_changes_refused(self):
        G.workspace_before(self.root,self.request);self.compile_fixture()
        for key in ['mode','run','attempt','sourceCommit','checkoutSha']:
            request=copy.deepcopy(self.request);request['context'][key]='changed'
            with self.subTest(key=key),self.assertRaises(G.GateError):G.workspace_post(self.root,request)
        Path(self.request['tools']['CodeCop']['path']).write_bytes(b'changed')
        with self.assertRaises(G.GateError):G.workspace_post(self.root,self.request)

    def test_requested_sarif_is_fresh_and_clean(self):
        folder=self.root/'errors'
        self.request['parameters']['ErrorLogDirectory']=str(folder)
        G.workspace_before(self.root,self.request);self.compile_fixture()
        log=folder/'app.errorLog.json'
        log.write_text(json.dumps(dict(version='2.1.0',runs=[dict(results=[])])))
        receipt=G.workspace_post(self.root,self.request)
        self.assertEqual(1,len(receipt['errorLogs']))
    def test_requested_sarif_warning_and_missing_refused(self):
        folder=self.root/'errors'
        self.request['parameters']['ErrorLogDirectory']=str(folder)
        G.workspace_before(self.root,self.request);self.compile_fixture()
        with self.assertRaises(G.GateError):G.workspace_post(self.root,self.request)
        (folder/'app.errorLog.json').write_text(json.dumps(dict(version='2.1.0',runs=[dict(results=[dict(level='warning',message=dict(text='must refuse'))])])) )
        with self.assertRaises(G.GateError):G.workspace_post(self.root,self.request)
    def test_source_cache_mutation_and_stale_output_refused(self):
        G.workspace_before(self.root,self.request);self.compile_fixture()
        output=Path(self.request['appFiles'][0]);os.utime(output,ns=(1,1))
        with self.assertRaises(G.GateError):G.workspace_post(self.root,self.request)
        os.utime(output,None)
        (self.root/'app/fixture.al').write_text('altered source')
        with self.assertRaises(G.GateError):G.workspace_post(self.root,self.request)

if __name__=='__main__':unittest.main()
