# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.3.0](https://github.com/brendaw/jekyll-front-matter-validator/releases/tag/v0.3.0) - 2026-07-26

### Added

- `slug_file` type for filename validation (validates name before extension as slug, accepts letters, digits, hyphens, and underscores)
- ANSI color output for validation errors (red) and success (green) in CLI and Jekyll hook

### Fixed

- Read from git index (`git show :path`) when validating staged files instead of disk, preventing incorrect validation with unstaged changes
- Replace `FatalException` with `exit!` to suppress Jekyll stack trace on validation failure
- Duplicate validation of posts collection in Jekyll hook (posts were added twice via `site.posts.docs` and `site.collections`)

## [0.2.0](https://github.com/brendaw/jekyll-front-matter-validator/releases/tag/v0.2.0) - 2026-07-25

### Added

- Initial release with front matter validation (required fields, types, enums, slugs)
- Asset existence checking (dir + extensions, pattern-based)
- Jekyll plugin hook (`:site, :pre_render`)
- Standalone CLI (`fmv-validate`) with `--staged` support
- Git pre-commit hook integration
- Nested hash types validation with `keys` property and dot notation
- Dot notation support in asset validation (e.g. `cover.url` resolves nested fields)
- Warning for unknown type definitions during validation
- Git installation as primary method (vendor and RubyGems as alternatives)

### Fixed

- Deep merge of nested type definitions between defaults and collections (previously lost nested keys from defaults when collection overrode the parent hash)
- Validate real date values when type is date (rejects invalid calendar dates like `2026-02-30`)

### Changed

- Translate all logs, comments, and documentation to English
- Rename gem from `jekyll-front_matter_validator` to `jekyll-front-matter-validator` (Ruby gem naming convention)
- Add RuboCop linting with strict defaults
- Require MFA for gem publishing
