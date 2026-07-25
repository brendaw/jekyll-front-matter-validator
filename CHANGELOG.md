# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Nested hash types validation with `keys` property and dot notation
- Dot notation support in asset validation (e.g. `cover.url` resolves nested fields)
- Warning for unknown type definitions during validation

### Fixed

- Deep merge of nested type definitions between defaults and collections (previously lost nested keys from defaults when collection overrode the parent hash)

### Changed

- Translate all logs, comments, and documentation to English
- Rename gem from `jekyll-front_matter_validator` to `jekyll-front-matter-validator` (Ruby gem naming convention)

## [0.2.0](https://github.com/brendaw/jekyll-front-matter-validator/releases/tag/v0.2.0) - 2026-07-21

### Added

- Initial release with front matter validation (required fields, types, enums, slugs)
- Asset existence checking (dir + extensions, pattern-based)
- Jekyll plugin hook (`:site, :pre_render`)
- Standalone CLI (`fmv-validate`) with `--staged` support
- Git pre-commit hook integration
