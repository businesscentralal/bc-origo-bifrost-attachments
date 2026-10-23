# Issue175 developer verification

Code candidate `50d12e421ef8bc59148c4eb01ed5fa200ce2d1ad`; this branch contains evidence only and does not change the candidate.

Read [acceptance-matrix.json](acceptance-matrix.json) for each criterion. F1 remains a retained worker6 PR174 dependency. Gunnar approved F6a in issue comment6367540500; F2/F3 H2 disposition remains pending before merge. Independent Claude/Grok verification, CI, merge, deployment and UAT are separate pending gates. This is not issue completion.

Current-tip results: three compile phases0errors0warnings with required cops and released28.3.0.122 baseline; full native462/462/0/0; targeted MCP56/56 plus shared-reader all39types x2languages78/78; help12/12; UI10/10 in1033/1039.

Owned COSMO f074e1d6af1d removed: DELETE204 then GET404. All fixtures were worker-created; destruction removed them. No customer/shared environment, consent/licensing/backend write or field guard bypass.

Microsoft documented Online-compatible `DisableWriteInsideTryFunctions=false` was configured only on the owned Docker instance. Fresh native/MCP/UI results followed alignment. Earlier failed attempts remain distinct historical evidence, not successful passes. PowerShell module import emits an unapproved-verbs warning; compiler diagnostic counts are separate and zero.

The standards scanner reported16/23 checks passing; inherited findings and false positives are disclosed in pr-gateway-triage.json. No suppression was added. Original private source, inputs and failures remain retained. No credentials or app packages are included.
