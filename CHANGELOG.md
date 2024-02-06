# isc.ipm.js

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.3] - 2024-02-06
### Fixed
- Added support for Angular 14+ by changing cli options to kebab-case

## [1.1.2] - 2023-02-17
### Fixed
- Web application file copy handles package manager operation ordering more robustly (#4)

## [1.1.1] - 2022-09-30
### Fixed
- Web application files are copied to proper target, not the current working directory

## [1.1.0] - 2022-08-08
### Added
- Added support for React project build/deployment
  
### Changed
- Refactored Angular-specific functionality into general-purpose/generic base class + toolset-specific implementations for Angular and React

## [1.0.1] - 2022-06-21
### Fixed
- Updated isc.json dependency to 2.0.0 (needed to work with latest isc.rest)

## [1.0.0] - 2022-06-21
- First released version

