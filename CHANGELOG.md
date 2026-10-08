# Changelog

All notable changes to Bifrost Attachments are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this app uses
Business Central release versioning (`major.minor.build.revision`).

## [Unreleased]



### Fixed (2026-10-08) - build gate completion and rejection custody (#78)

- Require the native action's exact completion marker before permitting compilation while preserving exact Foundation candidate identity, hash and provenance checks. Rejection receipts prioritize the package that failed parsing, including failures beyond the 128-item diagnostic cap. Native callback and genuine-package mutation regressions cover silent success and retained offending bytes. The proposed artifact pin and failure-receipt upload remain with the pipeline owner for infrastructure review. No AL objects or IDs change; actual runner manifest diagnosis, Windows trust and product/runtime verification remain pending.

### Fixed (2026-10-07) - bounded build-input evidence (#78)
