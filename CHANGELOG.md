# Changelog

All notable changes to Bifrost Attachments are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this app uses
Business Central release versioning (`major.minor.build.revision`).

## [Unreleased]


### Fixed

- Data Exchange refusal and discovery text now supports English and Icelandic in DataExch Type Set Impl ori (70013531), DataExch Export Run Impl ori (70013534), DataExch Def Export Impl ori (70013536), DataExch Entry Del Impl ori (70013544) and DataExch Def Import Impl ori (70013545). Attachments Build Tests ori (96274) asserts exact discovery text in both locales. Storage Setup Page Tests (96207) orders record declarations before TestPage variables without changing assertions. Generated shipping translations and runtime verification remain pending (#72, #74). (2026-10-07) - canonical compilation and regression fixtures (#74)
