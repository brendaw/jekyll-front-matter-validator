# jekyll-front-matter-validator

Gem that validates the front matter of your Jekyll posts/pages and warns
(or breaks the build) when something is wrong:

- required field missing
- wrong type (`date` that isn't a date, `tags` that isn't an array...)
- value outside an allowed list (`layout` is invalid, for example)
- field that should be a **slug** (no accents, no spaces, no uppercase)
  but isn't
- field whose value should have a **matching asset** on disk
  (e.g. `cover_image: "cute-cats"` should exist at
  `assets/images/cute-cats.jpg`) but the file doesn't exist

Runs automatically on `jekyll build` and `jekyll serve`, and can also be
used as a standalone CLI (useful for git `pre-commit` hooks).

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

Not yet published on RubyGems, the simplest approach is to vendor the gem
inside the site repo:

```bash
cp -r jekyll-front-matter-validator vendor/jekyll-front-matter-validator
```

In the site's `Gemfile` (see `examples/site-integration/Gemfile.example`):

```ruby
group :jekyll_plugins do
  gem "jekyll-front-matter-validator", path: "vendor/jekyll-front-matter-validator"
end
```

```bash
bundle install
```

Then paste the contents of `examples/site-integration/_config.yml.example`
into the site's `_config.yml`, adjusting the rules.

> Alternatives: `git:` pointing to a repository, or publish to
> RubyGems and use `gem "jekyll-front-matter-validator", "~> 0.2"` normally.
> See `Gemfile.example` for all three formats.

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
      enum:
        layout: [post, article]
      assets:
        cover_image:
          dir: assets/images
          extensions: [jpg, jpeg, png, webp]
        slug:
          pattern: "assets/posts/{value}/cover.*"
          slugify: true
```

### Supported types in `types:`

`string`, `integer`, `float`, `boolean`, `array`, `hash`, `date`, `slug`.

`slug` validates against `/\A[a-z0-9]+(-[a-z0-9]+)*\z/` — i.e. lowercase
letters, digits, and hyphens only, no accents or spaces.

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

### How rules are selected per file

For each file, the validator looks in `front_matter_schema.collections`
for an entry whose `path` is a prefix of the file's path (e.g. `_posts`
matches `_posts/2026-01-05-hello.md`). If none matches, it uses
`front_matter_schema.defaults`. The `defaults` rules are always merged
with the matched collection's rules ( required fields are summed,
types/enums/assets are combined with the defaults).

## Running the gem's own tests

```bash
bundle exec rspec   # if you add specs in spec/
```

(The gem doesn't ship with ready-made specs — the core in
`lib/jekyll/front_matter_validator/core.rb` is pure Ruby and easy to
test in isolation with `require_relative` + front matter fixtures.)
