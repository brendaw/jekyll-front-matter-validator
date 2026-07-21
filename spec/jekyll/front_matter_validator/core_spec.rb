# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Jekyll::FrontMatterValidator do
  let(:base) { Jekyll::FrontMatterValidator }

  describe ".slugify" do
    it "downcases and replaces non-alphanumeric with hyphens" do
      expect(base.slugify("Hello World")).to eq("hello-world")
    end

    it "strips accents" do
      expect(base.slugify("Café com Açúcar")).to eq("cafe-com-acucar")
    end

    it "removes leading and trailing hyphens" do
      expect(base.slugify("--hello--")).to eq("hello")
    end

    it "collapses consecutive non-alphanumeric into single hyphen" do
      expect(base.slugify("a  b!! c")).to eq("a-b-c")
    end

    it "returns empty string for empty input" do
      expect(base.slugify("")).to eq("")
    end

    it "returns empty string for non-alphanumeric only" do
      expect(base.slugify("!!!")).to eq("")
    end

    it "handles already-slugified strings" do
      expect(base.slugify("my-cool-post")).to eq("my-cool-post")
    end

    it "handles numbers" do
      expect(base.slugify("post 2026")).to eq("post-2026")
    end

    it "converts to string before processing" do
      expect(base.slugify(123)).to eq("123")
    end
  end

  describe ".rules_for" do
    let(:schema) do
      {
        "defaults" => {
          "required" => %w[title],
          "types" => { "title" => "string" }
        },
        "collections" => {
          "posts" => {
            "path" => "_posts",
            "required" => %w[date slug],
            "types" => { "date" => "date" }
          }
        }
      }
    end

    it "returns collection rules when path matches" do
      rules = base.rules_for("_posts/2026-01-06-post.md", schema)
      expect(rules["required"]).to contain_exactly("title", "date", "slug")
      expect(rules["types"]).to include("date" => "date", "title" => "string")
    end

    it "falls back to defaults when no collection matches" do
      rules = base.rules_for("pages/about.md", schema)
      expect(rules["required"]).to eq(%w[title])
      expect(rules["types"]).to eq({ "title" => "string" })
    end

    it "handles path with leading slash in collection" do
      schema["collections"]["posts"]["path"] = "/_posts"
      rules = base.rules_for("_posts/2026-01-06-post.md", schema)
      expect(rules["required"]).to contain_exactly("title", "date", "slug")
    end

    it "returns merged defaults when collections is empty" do
      schema.delete("collections")
      rules = base.rules_for("anything.md", schema)
      expect(rules["required"]).to eq(%w[title])
    end

    it "returns empty rules when schema is empty" do
      rules = base.rules_for("anything.md", {})
      expect(rules["required"]).to eq([])
      expect(rules["types"]).to eq({})
    end
  end

  describe ".merge_defaults" do
    it "unions required fields from defaults and collection" do
      defaults = { "required" => %w[title] }
      collection = { "required" => %w[date] }
      schema = { "defaults" => defaults }

      result = base.merge_defaults(collection, schema)
      expect(result["required"]).to contain_exactly("title", "date")
    end

    it "merges types with collection overriding defaults" do
      defaults = { "types" => { "title" => "string", "date" => "string" } }
      collection = { "types" => { "date" => "date" } }
      schema = { "defaults" => defaults }

      result = base.merge_defaults(collection, schema)
      expect(result["types"]).to eq({ "title" => "string", "date" => "date" })
    end

    it "merges enum with collection overriding defaults" do
      defaults = { "enum" => { "layout" => %w[post page] } }
      collection = { "enum" => { "layout" => %w[post article] } }
      schema = { "defaults" => defaults }

      result = base.merge_defaults(collection, schema)
      expect(result["enum"]).to eq({ "layout" => %w[post article] })
    end

    it "merges assets with collection overriding defaults" do
      defaults = { "assets" => { "image" => { "dir" => "img" } } }
      collection = { "assets" => { "image" => { "dir" => "assets/img" } } }
      schema = { "defaults" => defaults }

      result = base.merge_defaults(collection, schema)
      expect(result["assets"]).to eq({ "image" => { "dir" => "assets/img" } })
    end

    it "handles missing defaults" do
      schema = {}
      result = base.merge_defaults({}, schema)
      expect(result["required"]).to eq([])
      expect(result["types"]).to eq({})
    end
  end

  describe ".validate" do
    let(:file) { "_posts/2026-01-06-post.md" }

    context "required fields" do
      it "reports missing required field" do
        rules = { "required" => %w[title] }
        issues = base.validate({}, rules, file: file)
        expect(issues.size).to eq(1)
        expect(issues.first.message).to eq("required field missing")
        expect(issues.first.field).to eq("title")
      end

      it "reports empty string as missing" do
        rules = { "required" => %w[title] }
        issues = base.validate({ "title" => "" }, rules, file: file)
        expect(issues.size).to eq(1)
      end

      it "does not report present required fields" do
        rules = { "required" => %w[title] }
        issues = base.validate({ "title" => "Hello" }, rules, file: file)
        expect(issues).to be_empty
      end

      it "handles nil front matter" do
        rules = { "required" => %w[title] }
        issues = base.validate(nil, rules, file: file)
        expect(issues.size).to eq(1)
      end
    end

    context "type checking" do
      it "passes when type matches" do
        rules = { "types" => { "title" => "string" } }
        issues = base.validate({ "title" => "Hello" }, rules, file: file)
        expect(issues).to be_empty
      end

      it "reports wrong type" do
        rules = { "types" => { "title" => "integer" } }
        issues = base.validate({ "title" => "Hello" }, rules, file: file)
        expect(issues.size).to eq(1)
        expect(issues.first.message).to include("expected type 'integer'")
        expect(issues.first.message).to include("got \"Hello\"")
      end

      it "skips type check for fields not present in front matter" do
        rules = { "types" => { "title" => "string" } }
        issues = base.validate({}, rules, file: file)
        expect(issues).to be_empty
      end

      it "validates date type with Date object" do
        rules = { "types" => { "date" => "date" } }
        issues = base.validate({ "date" => Date.new(2026, 1, 6) }, rules, file: file)
        expect(issues).to be_empty
      end

      it "validates date type with date string" do
        rules = { "types" => { "date" => "date" } }
        issues = base.validate({ "date" => "2026-01-06" }, rules, file: file)
        expect(issues).to be_empty
      end

      it "reports invalid date type" do
        rules = { "types" => { "date" => "date" } }
        issues = base.validate({ "date" => "not-a-date" }, rules, file: file)
        expect(issues.size).to eq(1)
      end

      it "validates slug type" do
        rules = { "types" => { "slug" => "slug" } }
        issues = base.validate({ "slug" => "my-cool-post" }, rules, file: file)
        expect(issues).to be_empty
      end

      it "reports invalid slug type" do
        rules = { "types" => { "slug" => "slug" } }
        issues = base.validate({ "slug" => "My Post!" }, rules, file: file)
        expect(issues.size).to eq(1)
        expect(issues.first.message).to include("slug-like value")
      end

      it "validates array type" do
        rules = { "types" => { "tags" => "array" } }
        issues = base.validate({ "tags" => %w[ruby jekyll] }, rules, file: file)
        expect(issues).to be_empty
      end

      it "validates boolean type" do
        rules = { "types" => { "published" => "boolean" } }
        expect(base.validate({ "published" => true }, rules, file: file)).to be_empty
        expect(base.validate({ "published" => false }, rules, file: file)).to be_empty
      end

      it "validates hash type" do
        rules = { "types" => { "meta" => "hash" } }
        issues = base.validate({ "meta" => { "key" => "val" } }, rules, file: file)
        expect(issues).to be_empty
      end

      it "validates integer type" do
        rules = { "types" => { "count" => "integer" } }
        expect(base.validate({ "count" => 42 }, rules, file: file)).to be_empty
        issues = base.validate({ "count" => "42" }, rules, file: file)
        expect(issues.size).to eq(1)
      end

      it "validates float type" do
        rules = { "types" => { "score" => "float" } }
        expect(base.validate({ "score" => 3.14 }, rules, file: file)).to be_empty
        expect(base.validate({ "score" => 42 }, rules, file: file)).to be_empty
      end
    end

    context "enum checking" do
      it "passes when value is in allowed list" do
        rules = { "enum" => { "layout" => %w[post article] } }
        issues = base.validate({ "layout" => "post" }, rules, file: file)
        expect(issues).to be_empty
      end

      it "reports value not in allowed list" do
        rules = { "enum" => { "layout" => %w[post article] } }
        issues = base.validate({ "layout" => "page" }, rules, file: file)
        expect(issues.size).to eq(1)
        expect(issues.first.message).to include("not in allowed list")
      end

      it "skips enum check for fields not present in front matter" do
        rules = { "enum" => { "layout" => %w[post article] } }
        issues = base.validate({}, rules, file: file)
        expect(issues).to be_empty
      end

      it "handles single value as allowed list" do
        rules = { "enum" => { "layout" => "post" } }
        expect(base.validate({ "layout" => "post" }, rules, file: file)).to be_empty
        issues = base.validate({ "layout" => "page" }, rules, file: file)
        expect(issues.size).to eq(1)
      end
    end

    context "combined rules" do
      it "reports multiple issues at once" do
        rules = {
          "required" => %w[title date],
          "types" => { "date" => "date" },
          "enum" => { "layout" => %w[post article] }
        }
        fm = { "layout" => "page" } # missing title, date, and bad layout
        issues = base.validate(fm, rules, file: file)
        expect(issues.size).to eq(3)
      end
    end
  end

  describe ".validate_assets" do
    let(:file) { "_posts/2026-01-06-post.md" }
    let(:tmpdir) { Dir.mktmpdir }

    after { FileUtils.remove_entry(tmpdir) }

    context "dir + extensions mode" do
      it "passes when asset file exists" do
        FileUtils.mkdir_p(File.join(tmpdir, "assets/images"))
        FileUtils.touch(File.join(tmpdir, "assets/images/cover.jpg"))

        rules = { "assets" => { "cover_image" => { "dir" => "assets/images", "extensions" => %w[jpg png] } } }
        issues = base.validate_assets({ "cover_image" => "cover" }, rules, file: file, project_root: tmpdir)
        expect(issues).to be_empty
      end

      it "reports missing asset file" do
        FileUtils.mkdir_p(File.join(tmpdir, "assets/images"))

        rules = { "assets" => { "cover_image" => { "dir" => "assets/images", "extensions" => %w[jpg png] } } }
        issues = base.validate_assets({ "cover_image" => "missing" }, rules, file: file, project_root: tmpdir)
        expect(issues.size).to eq(1)
        expect(issues.first.message).to include("no matching asset found")
      end

      it "skips when field value is nil" do
        rules = { "assets" => { "cover_image" => { "dir" => "assets/images", "extensions" => %w[jpg] } } }
        issues = base.validate_assets({}, rules, file: file, project_root: tmpdir)
        expect(issues).to be_empty
      end

      it "skips when field value is blank" do
        rules = { "assets" => { "cover_image" => { "dir" => "assets/images", "extensions" => %w[jpg] } } }
        issues = base.validate_assets({ "cover_image" => "  " }, rules, file: file, project_root: tmpdir)
        expect(issues).to be_empty
      end

      it "slugifies value when slugify is true" do
        FileUtils.mkdir_p(File.join(tmpdir, "assets/images"))
        FileUtils.touch(File.join(tmpdir, "assets/images/my-post.jpg"))

        rules = { "assets" => { "cover_image" => { "dir" => "assets/images", "extensions" => %w[jpg], "slugify" => true } } }
        issues = base.validate_assets({ "cover_image" => "My Post" }, rules, file: file, project_root: tmpdir)
        expect(issues).to be_empty
      end

      it "uses wildcard when extensions is empty" do
        FileUtils.mkdir_p(File.join(tmpdir, "assets/images"))
        FileUtils.touch(File.join(tmpdir, "assets/images/cover.webp"))

        rules = { "assets" => { "cover_image" => { "dir" => "assets/images", "extensions" => [] } } }
        issues = base.validate_assets({ "cover_image" => "cover" }, rules, file: file, project_root: tmpdir)
        expect(issues).to be_empty
      end
    end

    context "pattern mode" do
      it "passes when pattern matches" do
        FileUtils.mkdir_p(File.join(tmpdir, "assets/posts/my-post"))
        FileUtils.touch(File.join(tmpdir, "assets/posts/my-post/cover.jpg"))

        rules = { "assets" => { "slug" => { "pattern" => "assets/posts/{value}/cover.*" } } }
        issues = base.validate_assets({ "slug" => "my-post" }, rules, file: file, project_root: tmpdir)
        expect(issues).to be_empty
      end

      it "reports when pattern does not match" do
        FileUtils.mkdir_p(File.join(tmpdir, "assets/posts"))

        rules = { "assets" => { "slug" => { "pattern" => "assets/posts/{value}/cover.*" } } }
        issues = base.validate_assets({ "slug" => "my-post" }, rules, file: file, project_root: tmpdir)
        expect(issues.size).to eq(1)
        expect(issues.first.message).to include("assets/posts/my-post/cover.*")
      end

      it "slugifies value in pattern when slugify is true" do
        FileUtils.mkdir_p(File.join(tmpdir, "assets/posts/my-post"))
        FileUtils.touch(File.join(tmpdir, "assets/posts/my-post/cover.jpg"))

        rules = { "assets" => { "slug" => { "pattern" => "assets/posts/{value}/cover.*", "slugify" => true } } }
        issues = base.validate_assets({ "slug" => "My Post" }, rules, file: file, project_root: tmpdir)
        expect(issues).to be_empty
      end
    end
  end

  describe ".validate_all" do
    let(:file) { "_posts/2026-01-06-post.md" }
    let(:tmpdir) { Dir.mktmpdir }

    after { FileUtils.remove_entry(tmpdir) }

    it "combines validate and validate_assets results" do
      FileUtils.mkdir_p(File.join(tmpdir, "assets/images"))

      rules = {
        "required" => %w[title],
        "assets" => { "cover_image" => { "dir" => "assets/images", "extensions" => %w[jpg] } }
      }
      fm = { "cover_image" => "missing" }
      issues = base.validate_all(fm, rules, file: file, project_root: tmpdir)
      expect(issues.size).to eq(2)
    end

    it "returns empty when everything is valid" do
      FileUtils.mkdir_p(File.join(tmpdir, "assets/images"))
      FileUtils.touch(File.join(tmpdir, "assets/images/cover.jpg"))

      rules = {
        "required" => %w[title],
        "assets" => { "cover_image" => { "dir" => "assets/images", "extensions" => %w[jpg] } }
      }
      fm = { "title" => "Hello", "cover_image" => "cover" }
      issues = base.validate_all(fm, rules, file: file, project_root: tmpdir)
      expect(issues).to be_empty
    end
  end

  describe ".read_front_matter" do
    let(:tmpdir) { Dir.mktmpdir }

    after { FileUtils.remove_entry(tmpdir) }

    it "parses valid front matter" do
      path = File.join(tmpdir, "post.md")
      File.write(path, "---\ntitle: Hello\ndate: 2026-01-06\n---\nContent here\n")

      fm, error = base.read_front_matter(path)
      expect(error).to be_nil
      expect(fm).to eq({ "title" => "Hello", "date" => Date.new(2026, 1, 6) })
    end

    it "returns nil for file without front matter" do
      path = File.join(tmpdir, "plain.md")
      File.write(path, "Just content, no front matter\n")

      fm, error = base.read_front_matter(path)
      expect(fm).to be_nil
      expect(error).to be_nil
    end

    it "returns error for invalid YAML" do
      path = File.join(tmpdir, "bad.md")
      File.write(path, "---\ntitle: [unclosed\n---\n")

      fm, error = base.read_front_matter(path)
      expect(fm).to be_nil
      expect(error).not_to be_nil
    end

    it "returns empty hash for empty front matter" do
      path = File.join(tmpdir, "empty.md")
      File.write(path, "---\n---\nContent\n")

      fm, error = base.read_front_matter(path)
      expect(error).to be_nil
      expect(fm).to eq({})
    end

    it "handles Date objects in YAML" do
      path = File.join(tmpdir, "date.md")
      File.write(path, "---\ndate: 2026-01-06\n---\n")

      fm, _error = base.read_front_matter(path)
      expect(fm["date"]).to be_a(Date)
    end
  end

  describe ".load_schema" do
    let(:tmpdir) { Dir.mktmpdir }

    after { FileUtils.remove_entry(tmpdir) }

    it "loads front_matter_schema from config" do
      path = File.join(tmpdir, "_config.yml")
      File.write(path, "front_matter_schema:\n  defaults:\n    required: [title]\n")

      schema = base.load_schema(path)
      expect(schema).to eq({ "defaults" => { "required" => %w[title] } })
    end

    it "returns empty hash when file does not exist" do
      schema = base.load_schema("/nonexistent/_config.yml")
      expect(schema).to eq({})
    end

    it "returns empty hash when front_matter_schema is absent" do
      path = File.join(tmpdir, "_config.yml")
      File.write(path, "title: My Site\n")

      schema = base.load_schema(path)
      expect(schema).to eq({})
    end
  end

  describe ".has_rules?" do
    it "returns true when required fields exist" do
      expect(base.has_rules?({ "required" => %w[title] })).to be true
    end

    it "returns true when types exist" do
      expect(base.has_rules?({ "types" => { "date" => "date" } })).to be true
    end

    it "returns true when enum exists" do
      expect(base.has_rules?({ "enum" => { "layout" => %w[post] } })).to be true
    end

    it "returns true when assets exist" do
      expect(base.has_rules?({ "assets" => { "image" => { "dir" => "img" } } })).to be true
    end

    it "returns false when no rules" do
      expect(base.has_rules?({})).to be false
    end

    it "returns false when all rule arrays/hashes are empty" do
      expect(base.has_rules?({ "required" => [], "types" => {}, "enum" => {}, "assets" => {} })).to be false
    end
  end

  describe Jekyll::FrontMatterValidator::Issue do
    it "formats to_s correctly" do
      issue = base::Issue.new("_posts/post.md", "title", "required field missing", :error)
      expect(issue.to_s).to eq("[ERROR] _posts/post.md -> title: required field missing")
    end

    it "formats warning level" do
      issue = base::Issue.new("_posts/post.md", "layout", "invalid value", :warning)
      expect(issue.to_s).to eq("[WARNING] _posts/post.md -> layout: invalid value")
    end
  end
end
