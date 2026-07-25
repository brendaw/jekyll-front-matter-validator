# Contributing to jekyll-front-matter-validator

Contributions are welcome — bug fixes, new features, documentation improvements, and translations.

For bug reports or feature requests, [open an Issue](https://github.com/brendaw/jekyll-front-matter-validator/issues) first so the approach can be discussed before you start coding.

## Prerequisites

- Ruby 2.7+
- Bundler
- Jekyll 3.5+ (for integration testing)

## How to contribute

1. [Fork the repository](https://github.com/brendaw/jekyll-front-matter-validator/fork) and clone your fork:

   ```bash
   git clone https://github.com/<your-username>/jekyll-front-matter-validator.git
   cd jekyll-front-matter-validator
   ```

2. Install dependencies:

   ```bash
   bundle install
   ```

3. Make your changes in `lib/`. The core validation logic is in
   `lib/jekyll/front_matter_validator/core.rb` (pure Ruby, no Jekyll dependency).
   The Jekyll integration is in `lib/jekyll/front_matter_validator/jekyll_hook.rb`.

4. Run tests and linter before opening a PR:

   ```bash
   bundle exec rspec
   bundle exec rubocop
   ```

5. Optionally, test the gem locally with a Jekyll site:

   ```bash
   gem build jekyll-front-matter-validator.gemspec
   gem install jekyll-front-matter-validator-0.2.0.gem
   ```

6. Open a Pull Request against `main` describing what changed and why.

You do not need to bump versions or update CHANGELOG.md — versioning and releases are handled by the maintainer after the PR is merged.

## Commit messages

This project uses [Conventional Commits](https://www.conventionalcommits.org/). Every commit message must follow the format:

```
type: short description
```

| Type | When to use |
|---|---|
| `feat` | New feature or behavior visible to users |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `chore` | Tooling, dependencies, configuration |
| `ci` | CI/CD workflow changes |
| `refactor` | Code restructuring without behavior change |
| `style` | Formatting, whitespace |
| `test` | Tests |

The type determines how the commit appears in the CHANGELOG and influences the version bump on the next release.

## Code style

The repository includes an `.editorconfig` file and RuboCop for linting. Most editors support both natively or via plugin.

**Editorconfig** enforces:

- UTF-8 encoding and LF line endings across all files
- 2-space indentation for `.rb`, `.gemspec`, `.yml`
- Tab indentation for `.sh` scripts
- Final newline and no trailing whitespace

**RuboCop** checks for style, naming, and best practices. Run before opening a PR:

```bash
bundle exec rubocop          # check only
bundle exec rubocop -A       # auto-correct safe offenses
```

## Project structure

```
lib/
  jekyll-front-matter-validator.rb              # entry point
  jekyll/front_matter_validator/
    version.rb
    core.rb            # all validation logic (no Jekyll dependency)
    jekyll_hook.rb      # hook :site, :pre_render (only loads if Jekyll exists)
exe/
  fmv-validate          # standalone CLI
examples/site-integration/   # files to copy into YOUR SITE's repo
```

## CI checks

Every pull request and push to `main` runs automated checks:

| Check | What it does |
|---|---|
| **Gem build** | Builds the `.gem` package to verify the gemspec is valid |
| **RuboCop** | Lints Ruby code for style, naming, and best practices |
| **Unit tests** | Runs RSpec tests against `spec/` (Ruby 2.7, 3.2, 3.3) |

All checks must pass before a PR can be merged.

---

Maintainers: see [RELEASING.md](RELEASING.md) for the release process.

[Back to README](README.md)
