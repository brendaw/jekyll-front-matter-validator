# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
