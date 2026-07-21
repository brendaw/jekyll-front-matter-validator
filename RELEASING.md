# Releasing

This document describes the release process for maintainers of jekyll-front-matter-validator.

## Prerequisites

- RubyGems account with push access
- `gem` CLI authenticated (`gem signin`)

## Versioning

This project follows [Semantic Versioning](https://semver.org/) (`MAJOR.MINOR.PATCH`).

## Creating a release

1. Update the version in `lib/jekyll/front_matter_validator/version.rb`:

   ```ruby
   VERSION = "0.3.0"
   ```

2. Update `CHANGELOG.md` — move items from `[Unreleased]` to a new versioned section:

   ```markdown
   ## [0.3.0](https://github.com/brendaw/jekyll-front-matter-validator/releases/tag/v0.3.0) - 2026-MM-DD

   ### Added
   - ...
   ```

3. Commit the changes:

   ```bash
   git add lib/jekyll/front_matter_validator/version.rb CHANGELOG.md
   git commit -m "chore: release v0.3.0"
   ```

4. Tag the release:

   ```bash
   git tag v0.3.0
   ```

5. Build and push to RubyGems:

   ```bash
   gem build jekyll-front-matter-validator.gemspec
   gem push jekyll-front-matter-validator-0.3.0.gem
   ```

6. Push the commit and tag:

   ```bash
   git push origin main
   git push origin v0.3.0
   ```

7. Create a GitHub Release from the tag with the CHANGELOG notes.

## When not to create a release

Changes that do not affect the gem's behavior — documentation updates, CI fixes, repository housekeeping — do not warrant a new release. Commit and push to `main` normally; they will be included in the next release when an actual code change is ready.

---

[Back to README](README.md)
