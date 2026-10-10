"""Owner-local fixed-point tooling tests; no shipping/runtime certification."""
import copy,json,os,shutil,sys,tempfile,time,unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).parents[1]))
import appsource_gate as G

class ClassicPreparation(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)/'checkout';self.root.mkdir()
        self.owned=Path(self.temp.name)/'owned';self.owned.mkdir()
        self.cache=self.owned/'appCache';self.cache.mkdir()
        self.catalog=self.owned/'compilerSymbols';self.catalog.mkdir()
        source=Path(os.environ['FOUNDATION_CLASSIC_CATALOG'])
        # Keep the positive test on the entire retained catalog. Negative cases
        # use its complete five-package product closure to avoid re-reading
        # unrelated test-library bytes; every test/assertion still executes.
        closure={'System.app','Microsoft_Application_29.0.54011.55935.app','Microsoft_System Application_29.0.54011.55816.app','Microsoft_Business Foundation_29.0.54011.55935.app','Microsoft_Base Application_29.0.54011.55935.app'}
        for p in source.glob('*.app'):
            if self._testMethodName == 'test_actual_product_manifest_graph_fresh_metadata_and_fixed_point' or p.name in closure:
                shutil.copyfile(p,self.catalog/p.name)
        foundation=Path(os.environ['FOUNDATION_CLASSIC_PACKAGE']);shutil.copyfile(foundation,self.cache/'foundation.app')
        repo=Path(__file__).parents[2]
        for name in ('app','test'):
            folder=self.root/name;folder.mkdir();shutil.copyfile(repo/name/'app.json',folder/'app.json')
            (folder/'Fixtureori.Codeunit.al').write_text('namespace Origo.Tooling;\ncodeunit 50100 "Fixture ori" {}')
        self.context=dict(mode='Default',run='1234',attempt='1',job='classic-fixture',sourceCommit='1'*40,checkoutSha='2'*40,project='.',buildUrl='https://github.com/businesscentralal/bc-origo-bifrost-attachments/actions/runs/1234')
        state=self.root/'.buildartifacts/AppSourceGate/Default';state.mkdir(parents=True)
        (state/'state.json').write_text(json.dumps(dict(context=self.context,backend='classic',receipts={})))
        self.state=state
        self.helper=Path(os.environ['FOUNDATION_CLASSIC_HELPER_SOURCE'])/'CompilerFolderHandling/Compile-AppWithBcCompilerFolder.ps1'
        self.altool=Path(os.environ['FOUNDATION_CLASSIC_ALTOOL']);self.dotnet=Path(os.environ['FOUNDATION_CLASSIC_DOTNET'])
        self.request=dict(compilerExtension=str(self.altool.parent.parent),metadataHelper=str(self.helper.parents[1]/'GetAppInfo-source.ps1'),context=self.context,ownedRoot=str(self.owned),appProjectFolder=str(self.root/'app'),symbolsFolder=str(self.cache),compilerSymbolsFolder=str(self.catalog),helper=str(self.helper),altool=str(self.altool),altoolSha256=G.file_hash(self.altool),dotnet=str(self.dotnet),dotnetSha256=G.file_hash(self.dotnet),parameters=dict(UpdateDependencies=False,GenerateReportLayout='No'))
    def test_actual_product_manifest_graph_fresh_metadata_and_fixed_point(self):
        (self.cache/'cache_AppInfo.json').write_text('stale-incorrect-metadata')
        (self.catalog/'cache_AppInfo.json').write_text('stale-incorrect-metadata')
        receipt=G.classic_prepare(self.root,self.request)
        self.assertGreater(len(receipt['resolution']['trace']),3)
        self.assertGreater(len(receipt['resolution']['copies']),3)
        self.assertEqual([],receipt['replay']['copies'])
        self.assertFalse(receipt['consumedInputsCertified'])
        self.assertEqual(2+len(receipt['catalog'])-1,len(receipt['metadata']))
        self.assertFalse((self.cache/'cache_AppInfo.json').exists())
        G.classic_seal(self.root,dict(context=self.context))
        G.classic_after(self.root,dict(context=self.context,copyAppToSymbolsFolder=False,appFiles=[]))
        evidence=os.environ.get('FOUNDATION_CLASSIC_EVIDENCE')
        if evidence:
            out=Path(evidence);out.mkdir(parents=True,exist_ok=True)
            (out/'prepared-request.json').write_text(json.dumps(self.request,indent=2))
            (out/'prepared-receipt.json').write_text(json.dumps(receipt,indent=2))
        second=G.classic_prepare(self.root,self.request)
        self.assertEqual([],second['resolution']['copies'])
        self.assertEqual(receipt['cache'],second['cache'])
        (self.root/'app/Fixtureori.Codeunit.al').write_text('changed')
        with self.assertRaises(G.GateError):G.classic_seal(self.root,dict(context=self.context))
        with self.assertRaises(G.GateError):G.classic_after(self.root,dict(context=self.context,copyAppToSymbolsFolder=False,appFiles=[]))
    def test_actual_update_dependencies_refuses_instead_of_changing_flag_or_floor(self):
        self.request['parameters']['UpdateDependencies']=True
        before=(self.root/'app/app.json').read_bytes()
        with self.assertRaisesRegex(G.GateError,'updateDependencies'):G.classic_prepare(self.root,self.request)
        self.assertEqual(before,(self.root/'app/app.json').read_bytes());self.assertTrue(self.request['parameters']['UpdateDependencies'])
    def test_missing_dependency_fails_without_silent_omission(self):
        (self.catalog/'System.app').unlink()
        with self.assertRaisesRegex(G.GateError,'Missing compatible dependency'):G.classic_prepare(self.root,self.request)
    def test_no_shared_cache_or_layout_source_mutation(self):
        request=copy.deepcopy(self.request);request['ownedRoot']=str(self.root)
        with self.assertRaisesRegex(G.GateError,'exclusive run-local'):G.classic_prepare(self.root,request)
        request=copy.deepcopy(self.request);request['parameters']['GenerateReportLayout']='Yes'
        with self.assertRaisesRegex(G.GateError,'layout generation'):G.classic_prepare(self.root,request)
    def test_test_current_run_product_is_required(self):
        self.request['appProjectFolder']=str(self.root/'test')
        with self.assertRaisesRegex(G.GateError,'current-run product'):G.classic_prepare(self.root,self.request)
    def test_metadata_timeout_and_wrong_identity_fail(self):
        item=G.package_info(self.cache/'foundation.app')
        with patch('appsource_gate.subprocess.run',side_effect=G.subprocess.TimeoutExpired('altool',1)):
            with self.assertRaisesRegex(G.GateError,'timeout'):G.classic_metadata(self.cache/'foundation.app',item,[str(self.dotnet),str(self.altool)],time.monotonic()+1)
        result=G.subprocess.CompletedProcess([],0,b'{"id":"wrong","publisher":"Origo","name":"wrong","version":"1.0.0.0"}',b'')
        with patch('appsource_gate.subprocess.run',return_value=result):
            with self.assertRaisesRegex(G.GateError,'identity differs'):G.classic_metadata(self.cache/'foundation.app',item,[str(self.dotnet),str(self.altool)],time.monotonic()+1)
    def test_selection_highest_existing_multiple_catalog_and_cycle_bound(self):
        # Controlled metadata tests complement genuine full-graph execution.
        def item(version,filename):
            return dict(identity=dict(id='a'*8+'-'+ 'a'*4+'-'+ 'a'*4+'-'+ 'a'*4+'-'+ 'a'*12,publisher='Fixture',name='Dependency',version=version),file=filename,sha256='1'*64,bytes=1,expandedBytes=1,entryCount=1,resourceProfile='generic',application='',platform='',propagateDependencies=False,dependencies=[])
        low,high=item('1.0.0.0','low.app'),item('2.0.0.0','high.app')
        manifest=dict(dependencies=[low['identity']])
        self.assertEqual(['high.app','low.app'],[x['file'] for x in G.resolve_helper_inputs(manifest,[],[low,high])['copies']])
        result=G.resolve_helper_inputs(manifest,[low,high],[low,high]);self.assertEqual('high.app',result['trace'][0]['selected'][0]['file']);self.assertEqual([],result['copies'])
        high['propagateDependencies']=True;high['dependencies']=[high['identity']]
        self.assertEqual([],G.resolve_helper_inputs(manifest,[high],[high])['copies'])
        high['dependencies']=[high['identity']]*4097
        with self.assertRaisesRegex(G.GateError,'edge bound'):G.resolve_helper_inputs(manifest,[high],[high])
    def test_collision_and_wrong_publisher_are_not_overwritten(self):
        symbol=G.symbol_inventory(self.cache)[0]
        changed=copy.deepcopy(symbol);changed['identity']['publisher']='Wrong'
        with self.assertRaises(G.GateError):G.resolve_helper_inputs(dict(dependencies=[symbol['identity']]),[],[changed])
        other=copy.deepcopy(symbol);other['identity']['id']='1'*8+'-'+ '1'*4+'-'+ '1'*4+'-'+ '1'*4+'-'+ '1'*12
        with self.assertRaisesRegex(G.GateError,'overwrite'):G.resolve_helper_inputs(dict(dependencies=[symbol['identity']]),[other],[symbol])

if __name__=='__main__':unittest.main()
