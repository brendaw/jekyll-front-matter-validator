<p align="center">
  <img src="https://badgen.net/github/license/brendaw/jekyll-front-matter-validator">
  <img src="https://badgen.net/badge/status/active/green">
  <img alt="Ruby" src="https://img.shields.io/badge/Ruby-2.7%2B-CC342D?logo=ruby&logoColor=white"/>
  <img alt="Jekyll" src="https://img.shields.io/badge/Jekyll-3.5%2B%20%7C%20%3C5.0-red?logo=jekyll&logoColor=white"/>
  <a href="https://github.com/brendaw/jekyll-front-matter-validator/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/brendaw/jekyll-front-matter-validator/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/brendaw/jekyll-front-matter-validator/issues"><img alt="Issues" src="https://badgen.net/github/open-issues/brendaw/jekyll-front-matter-validator"></a>
</p>

# jekyll-front-matter-validator

Gem that validates the front matter of your Jekyll posts/pages and warns
(or breaks the build) when something is wrong.

## Features

- Required field missing
- Wrong type (`date` that isn't a date, `tags` that isn't an array...)
- Value outside an allowed list (`layout` is invalid, for example)
- Field that should be a **slug** (no accents, no spaces, no uppercase) but isn't
- Field whose value should have a **matching asset** on disk
  (e.g. `cover_image: "cute-cats"` should exist at
  `assets/images/cute-cats.jpg`) but the file doesn't exist
- Nested hash validation with `keys` property and dot notation
- Runs automatically on `jekyll build` and `jekyll serve`
- Standalone CLI for git `pre-commit` hooks

## Quick start

Get up and running in 5 minutes:

```bash
# 1. Add to your site's Gemfile
cat >> Gemfile <<'EOF'

group :jekyll_plugins do
  gem "jekyll-front-matter-validator", git: "https://github.com/brendaw/jekyll-front-matter-validator"
end
EOF

# 2. Install
bundle install

# 3. Add validation rules to _config.yml (see examples/site-integration/_config.yml.example)

# 4. Build — validation runs automatically
bundle exec jekyll build
```

If anything is wrong with your front matter, the build will stop and show
exactly what needs to be fixed. Set `fail_build_on_error: false` in
`_config.yml` to warn without breaking the build.

You can also validate files directly with the CLI:

```bash
bundle exec fmv-validate              # everything in the project
bundle exec fmv-validate --staged     # only git-staged files
bundle exec fmv-validate _posts/*.md  # specific files
```

> See [Installation](#1-installation-in-your-jekyll-site) for alternative
> install methods (git, RubyGems) and
> [Schema reference](#schema-reference-front_matter_schema-in-_configyml)
> for the full configuration reference.

## Gem structure

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
  Gemfile.example
  _config.yml.example
  .githooks/pre-commit
  bin/install-git-hooks.sh
```

## 1. Installation in your Jekyll site

### Option A — from GitHub (recommended)

In the site's `Gemfile` (see `examples/site-integration/Gemfile.example`):

```ruby
group :jekyll_plugins do
  gem "jekyll-front-matter-validator", git: "https://github.com/brendaw/jekyll-front-matter-validator"
end
```

```bash
bundle install
```

### Option B — vendored (local copy)

Clone or copy the gem into the site repo:

```bash
cp -r jekyll-front-matter-validator vendor/jekyll-front-matter-validator
```

In the site's `Gemfile`:

```ruby
group :jekyll_plugins do
  gem "jekyll-front-matter-validator", path: "vendor/jekyll-front-matter-validator"
end
```

```bash
bundle install
```

### Option C — RubyGems (after publishing)

```ruby
group :jekyll_plugins do
  gem "jekyll-front-matter-validator", "~> 0.2"
end
```

## 2. Validation on `build` and `serve`

No extra steps needed — Bundler loads the gem, and the
`:site, :pre_render` hook runs on both `jekyll build` and
`jekyll serve` (including on every `--watch` regeneration).

```bash
bundle exec jekyll build
# or
bundle exec jekyll serve
```

If something is invalid and `fail_build_on_error: true` (default), the
build stops with output like:

```
FrontMatterValidator: 3 issue(s) found in front matter
  [ERROR] _posts/2026-01-06-post.md -> slug: expected type 'slug' (expected a slug-like value, e.g. 'my-slug', no spaces/uppercase), got "My Post!"
  [ERROR] _posts/2026-01-06-post.md -> cover_image: no matching asset found at 'assets/images/cute-cats.{jpg,jpeg,png,webp}'
  [ERROR] _posts/2026-01-06-post.md -> layout: value "article" not in allowed list ["post", "article"]
```

To warn without breaking the build, use `fail_build_on_error: false`.

## 3. Git pre-commit hook

Copy the `.githooks/` folder and `bin/install-git-hooks.sh` from
`examples/site-integration/` into the site repo, then:

```bash
./bin/install-git-hooks.sh
```

This sets `core.hooksPath` to `.githooks/`. From then on, every
`git commit` runs `bundle exec fmv-validate --staged`, validating only
staged files, and blocks the commit if anything is wrong.

To disable: `git config --unset core.hooksPath`.

## 4. Manual CLI

```bash
bundle exec fmv-validate              # validates everything in the project
bundle exec fmv-validate --staged     # only git-staged files
bundle exec fmv-validate path.md      # specific file(s)
```

## Schema reference (`front_matter_schema` in `_config.yml`)

```yaml
front_matter_schema:
  fail_build_on_error: true   # false = warn only, don't break the build

  defaults:                   # applied to everything not matched by collections
    required: [title]
    types: { title: string }

  collections:
    posts:
      path: _posts             # path prefix that identifies this collection
      required: [title, date, slug]
      types:
        date: date
        tags: array
        slug: slug
        cover:
          type: hash
          keys:
            url: string
            width: integer
      enum:
        layout: [post, article]
      assets:
        cover_image:
          dir: assets/images
          extensions: [jpg, jpeg, png, webp]
        slug:
          pattern: "assets/posts/{value}/cover.*"
          slugify: true
        cover.url:                    # dot notation for nested fields
          dir: assets/images
          extensions: [jpg, jpeg, png, webp]
```

### Supported types in `types:`

`string`, `integer`, `float`, `boolean`, `array`, `hash`, `date`, `slug`.

`slug` validates against `/\A[a-z0-9]+(-[a-z0-9]+)*\z/` — i.e. lowercase
letters, digits, and hyphens only, no accents or spaces.

`hash` supports nested validation. You can declare sub-keys with the
`keys` property (explicit style) or dot notation (compact style) — both
can be mixed in the same config:

```yaml
types:
  # Explicit style
  cover:
    type: hash
    keys:
      url: string
      width: integer
      author:
        type: hash
        keys:
          name: string
          user: string

  # Dot notation (same result, more compact)
  # cover.url: string
  # cover.width: integer
  # cover.author.name: string
  # cover.author.user: string
```

Extra keys present in the hash but not declared in `keys` are accepted
without errors — validation only checks the fields you explicitly list.

### `assets:` — checking for matching files

For each field listed in `assets`, the validator builds an expected path
from the field value and checks whether a matching file exists. Two
configuration styles:

**`dir` + `extensions`** (simpler, a file directly in a folder):

```yaml
assets:
  cover_image:
    dir: assets/images
    extensions: [jpg, jpeg, png, webp]
```
`cover_image: "cute-cats"` → looks for `assets/images/cute-cats.{jpg,jpeg,png,webp}`.

**`pattern`** (more flexible, with `{value}` as a placeholder — useful
for subdirectory structures):

```yaml
assets:
  slug:
    pattern: "assets/posts/{value}/cover.*"
```
`slug: "my-post"` → looks for `assets/posts/my-post/cover.*`.

In both cases, `slugify: true` normalizes the field value (strips
accents, downcases, replaces spaces with hyphens) before building the
path — useful when the field used to derive the filename isn't itself a
slug (e.g. using `title` to find the image).

**Dot notation** is supported for nested front matter fields:

```yaml
assets:
  cover.url:
    dir: assets/images
    extensions: [jpg, jpeg, png, webp]
```
`cover: { url: "cute-cats" }` → looks for `assets/images/cute-cats.{jpg,jpeg,png,webp}`.

Dot notation works with both `dir` + `extensions` and `pattern` modes,
and can be combined with `slugify: true`.

### How rules are selected per file

For each file, the validator looks in `front_matter_schema.collections`
for an entry whose `path` is a prefix of the file's path (e.g. `_posts`
matches `_posts/2026-01-05-hello.md`). If none matches, it uses
`front_matter_schema.defaults`. The `defaults` rules are always merged
with the matched collection's rules (required fields are summed,
types/enums/assets are combined with the defaults).

For `types`, nested hash definitions are deep-merged — if both
`defaults` and a collection define the same hash field with different
sub-keys, all sub-keys are preserved (collection keys win on conflicts).

## Running the gem's own tests

```bash
bundle install
bundle exec rspec
```

Tests cover the core validation logic in `lib/jekyll/front_matter_validator/core.rb`
(slugify, required/type/enum validation, asset checking, rule matching, YAML parsing).

## Contributing

Contributions are welcome — bug fixes, new features, documentation improvements, and translations.
See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow.

The project uses GitHub Actions for CI (gem build, RuboCop linting, and unit tests across Ruby 2.7, 3.2, and 3.3).

[Issues](https://github.com/brendaw/jekyll-front-matter-validator/issues) and
[Pull Requests](https://github.com/brendaw/jekyll-front-matter-validator/pulls) are open for your contribution.

## Contributors

See the [AUTHORS](AUTHORS.md) file for the amazing contributors of this project.

## License

[MIT](LICENSE) — William Brendaw and the contributors — 2026
