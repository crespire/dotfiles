#!/usr/bin/env ruby
# Exercise the harness against a fixture vault. Never reads or writes the real store: it
# builds a throwaway vault, points DREAM_TERRITORY and DREAM_STATE at it, and removes both.
#
# The cases here are the ones where a bug corrupts a file rather than merely producing a
# wrong answer. Frontmatter is the whole attack surface: a tagging mistake is recoverable
# from git, but a file whose frontmatter stops parsing loses every key it had, silently, and
# Obsidian shows it with no properties at all.
#
# Fixtures cover the shapes the code does NOT handle as well as the ones it does. A suite
# built only from shapes that work proves nothing about the ones that do not.
#
# Usage: ruby selftest.rb

require "tmpdir"
require "json"
require "yaml"
require "open3"
require "fileutils"

HERE = __dir__
PASS = []
FAIL = []

def check(name)
  yield ? PASS << name : FAIL << name
rescue => e
  FAIL << "#{name} — raised #{e.class}: #{e.message}"
end

# As auto-memory writes one: three top-level keys, type nested, no tags.
MEMORY = <<~MD
  ---
  name: reference-example
  description: "A fact — with an em-dash, to catch encoding regressions"
  metadata:
    node_type: memory
    type: reference
  ---

  Body line one.

  Body line two — also em-dashed.
MD

BARE_NOTE = <<~MD
  ### A heading

  Prose the user wrote — untouchable.
MD

TAGGED_NOTE = <<~MD
  ---
  title: Already Tagged
  date: 2026-06-30
  tags: [switch, boost]
  ---

  Body stays put.
MD

# Obsidian's Properties panel writes this shape.
BLOCK_NOTE = <<~MD
  ---
  title: Block Style
  tags:
    - switch
    - boost
  ---

  Body of the block-style note.
MD

# A block sequence at zero indent is equally legal YAML and equally common by hand.
ZERO_INDENT = <<~MD
  ---
  title: Zero Indent
  tags:
  - alpha
  - beta
  ---

  Body of the zero-indent note.
MD

# Mixed indentation is already invalid YAML. A writer must refuse it, not normalise it.
RAGGED = <<~MD
  ---
  title: Ragged
  tags:
    - one
  - two
  ---

  Body of the ragged note.
MD

# A closing fence with a trailing space. Obsidian accepts it.
TRAILING_FENCE = "---\ntitle: Trailing Fence\ntags: [switch]\n--- \n\nBody after a loose fence.\n"

# Two tags keys: YAML takes the last, so merging into the first writes tags nothing reads.
DUPLICATE_KEYS = <<~MD
  ---
  title: Duplicate Keys
  tags: [one]
  tags: [two]
  ---

  Body.
MD

# What auto-memory leaves behind after it rewrites a memory it touched: the tags a session
# chose, absorbed into the metadata mapping where every reader here misses them.
BURIED = <<~MD
  ---
  name: feedback-buried
  description: "Tags a session chose, buried by a rewrite"
  metadata:
    node_type: memory
    tags:
      - scope/portable
      - form/preference
      - ruby
    type: feedback
    originSessionId: abc123
  ---

  Body of the buried note — em-dashed.
MD

# The same burial in flow style.
BURIED_INLINE = <<~MD
  ---
  name: feedback-buried-inline
  metadata:
    node_type: memory
    tags: [scope/local, form/artifact, switch]
    type: feedback
  ---

  Body.
MD

# A run tagged the file, then a rewrite buried a second copy. Neither side may be dropped:
# each holds a tag the other does not.
BURIED_AND_TOP = <<~MD
  ---
  name: feedback-both
  tags: [scope/portable, form/pattern, ruby]
  metadata:
    node_type: memory
    tags:
      - scope/portable
      - testing
    type: feedback
  ---

  Body.
MD

# A nested key with nothing under it. YAML reads the value as nil, so what the writer meant
# is a guess, and hoisting it would assert an empty tag list the file never declared.
BURIED_EMPTY = <<~MD
  ---
  name: feedback-empty
  metadata:
    node_type: memory
    tags:
    type: feedback
  ---

  Body.
MD

# `tags:` inside a mapping that is not `metadata:`. Lifting a value out of a mapping that
# meant something by it is not a repair, so this file must come through untouched.
NESTED_ELSEWHERE = <<~MD
  ---
  title: Elsewhere
  tags: [switch]
  frontmatter_of_something_else:
    tags:
      - not-ours
  ---

  Body.
MD

BROKEN = <<~MD
  ---
  name: broken
  description: "no closing fence"

  Body that is really still frontmatter, or is it.
MD

# A note opening with a horizontal rule. The second rule looks exactly like a closing fence,
# so a parser that trusts the markers alone writes tags between two lines of the user's prose.
HRULE = <<~MD
  ---
  Some prose the user wrote.

  ---
  More prose below the rule.
MD

# A flow sequence wrapped across lines: reading one line makes it look complete.
WRAPPED = <<~MD
  ---
  title: Wrapped
  tags: [scope/portable, form/pattern,
    ruby, rails]
  ---

  Body.
MD

# A trailing comment. Appending inside it parses away silently, so the merge reports success
# and changes nothing.
COMMENTED = <<~MD
  ---
  title: Commented
  tags: [switch] # revisit before folding
  ---

  Body.
MD

# Everything below the frontmatter, ignoring leading blank lines: prepending a block adds a
# blank separator, which is Markdown convention and not content.
def body_of(text)
  lines = text.lines
  body =
    if lines.first&.rstrip == "---"
      close = lines[1..].index { |l| l.rstrip == "---" }
      close.nil? ? lines : lines[(close + 2)..]
    else
      lines
    end
  body.join.sub(/\A\n+/, "")
end

def frontmatter_of(path)
  src = File.read(path)
  lines = src.lines
  return nil unless lines.first&.rstrip == "---"
  close = lines[1..].index { |l| l.rstrip == "---" }
  return nil if close.nil?
  YAML.safe_load(lines[1..close].join, permitted_classes: [Date, Time])
end

Dir.mktmpdir("dream-selftest") do |root|
  vault = File.join(root, "vault")
  %w[knowledge knowledge/archive Notes Notes/Nested].each { |d| Dir.mkdir(File.join(vault, d)) rescue Dir.mkdir(vault) && Dir.mkdir(File.join(vault, d)) }

  write = ->(rel, body) { File.write(File.join(vault, rel), body) }
  write.("knowledge/reference_example.md", MEMORY)
  write.("knowledge/buried.md", BURIED)
  write.("knowledge/buried_inline.md", BURIED_INLINE)
  write.("knowledge/buried_and_top.md", BURIED_AND_TOP)
  write.("knowledge/buried_empty.md", BURIED_EMPTY)
  write.("Notes/elsewhere.md", NESTED_ELSEWHERE)
  write.("knowledge/broken.md", BROKEN)
  write.("knowledge/dupkeys.md", DUPLICATE_KEYS)
  write.("knowledge/MEMORY.md", "# Memory\n\n## Tag catalog\n")
  write.("knowledge/DREAM.md", "# Dream\n")
  write.("knowledge/archive/old.md", MEMORY)
  write.("Notes/bare.md", BARE_NOTE)
  write.("Notes/block.md", BLOCK_NOTE)
  write.("Notes/zero.md", ZERO_INDENT)
  write.("Notes/ragged.md", RAGGED)
  write.("Notes/fence.md", TRAILING_FENCE)
  write.("Notes/[WIP] plan.md", BARE_NOTE)
  write.("Notes/hrule.md", HRULE)
  write.("Notes/wrapped.md", WRAPPED)
  write.("Notes/commented.md", COMMENTED)
  write.("Notes/Nested/tagged.md", TAGGED_NOTE)

  territory = File.join(root, "territory.json")
  File.write(territory, JSON.pretty_generate({
    "vault" => vault,
    "directories" => [
      {"path" => "knowledge", "mode" => "consolidate"},
      {"path" => "Notes", "mode" => "tag-only"},
    ],
    "exclude" => [
      {"path" => "knowledge/archive/**", "why" => "retired"},
      {"path" => "knowledge/MEMORY.md", "why" => "output"},
      {"path" => "knowledge/DREAM.md", "why" => "output"},
    ],
  }))

  # Must precede the require: lib.rb resolves TERRITORY into a constant at load time.
  # Reversed, the suite would run against the real store and apply_tags --write would tag it.
  ENV["DREAM_TERRITORY"] = territory
  ENV["DREAM_STATE"] = File.join(root, "state.json")
  require_relative "lib"

  unless Dream::TERRITORY == territory
    abort "selftest aborted: Dream::TERRITORY is #{Dream::TERRITORY.inspect}, not the fixture."
  end

  env = {"DREAM_TERRITORY" => territory, "DREAM_STATE" => File.join(root, "state.json")}
  run = ->(script, *args) { Open3.capture2e(env, "ruby", File.join(HERE, script), *args) }

  # --- scope -------------------------------------------------------------------------
  rels = Dream.files.map(&:first)
  expected = ["Notes/Nested/tagged.md", "Notes/[WIP] plan.md", "Notes/bare.md", "Notes/block.md",
              "Notes/commented.md", "Notes/elsewhere.md", "Notes/fence.md", "Notes/hrule.md",
              "Notes/ragged.md", "Notes/wrapped.md", "Notes/zero.md",
              "knowledge/broken.md", "knowledge/buried.md", "knowledge/buried_and_top.md",
              "knowledge/buried_empty.md", "knowledge/buried_inline.md",
              "knowledge/dupkeys.md", "knowledge/reference_example.md"]

  check("finds every in-scope file, and only those") { rels.sort == expected.sort }
  check("excludes an archive subtree") { rels.none? { |r| r.include?("archive/") } }
  check("excludes named output files") { rels.none? { |r| r =~ /(MEMORY|DREAM)\.md\z/ } }
  check("walks nested directories") { rels.include?("Notes/Nested/tagged.md") }
  check("lists a file once when directory entries overlap") { rels.size == rels.uniq.size }
  check("carries the mode for each file") do
    Dream.files.to_h["knowledge/reference_example.md"] == "consolidate" &&
      Dream.files.to_h["Notes/bare.md"] == "tag-only"
  end
  check("reads an em-dash without a locale") { Dream.read("knowledge/reference_example.md").include?("—") }

  # --- frontmatter parsing -----------------------------------------------------------
  check("parses closed frontmatter") { Dream.frontmatter(MEMORY)[:close] == 6 }
  check("reports unclosed frontmatter rather than guessing") { Dream.frontmatter(BROKEN)[:ok] == false }
  check("accepts a closing fence with a trailing space") { Dream.frontmatter(TRAILING_FENCE)[:ok] }
  check("refuses a horizontal rule posing as frontmatter") do
    Dream.frontmatter(HRULE)[:reason] == :not_a_mapping
  end
  check("refuses a flow sequence that does not close on its line") do
    Dream.tag_block(Dream.frontmatter(WRAPPED))[:style] == :unterminated
  end
  check("carries a trailing comment rather than writing into it") do
    b = Dream.tag_block(Dream.frontmatter(COMMENTED))
    b[:tags] == %w[switch] && b[:suffix].to_s.include?("# revisit")
  end
  check("treats a file with no frontmatter as body-only") { Dream.frontmatter(BARE_NOTE)[:close].nil? }

  check("parses an inline tag list") { Dream.tags_for(TAGGED_NOTE) == %w[switch boost] }
  check("parses an indented block list") { Dream.tags_for(BLOCK_NOTE) == %w[switch boost] }
  check("parses a zero-indent block list") { Dream.tags_for(ZERO_INDENT) == %w[alpha beta] }
  check("returns nil tags when the key is absent") { Dream.tags_for(MEMORY).nil? }
  check("reports the style so a writer can match it") do
    Dream.tag_block(Dream.frontmatter(TAGGED_NOTE))[:style] == :inline &&
      Dream.tag_block(Dream.frontmatter(BLOCK_NOTE))[:style] == :block &&
      Dream.tag_block(Dream.frontmatter(ZERO_INDENT))[:style] == :block
  end
  check("refuses to classify a ragged list as writable") do
    b = Dream.tag_block(Dream.frontmatter(RAGGED))
    b[:style] == :ragged && !Dream.writable_tags?(b)
  end
  check("refuses to classify duplicate tags keys as writable") do
    b = Dream.tag_block(Dream.frontmatter(DUPLICATE_KEYS))
    b[:style] == :duplicate && !Dream.writable_tags?(b)
  end

  # --- buried tags ---------------------------------------------------------------------
  # The failure this guards against is silent in both directions: a buried key reads as no
  # tags at all, and a hoist that splices carelessly loses every other frontmatter key.
  check("reads a buried block sequence") do
    b = Dream.nested_tag_block(Dream.frontmatter(BURIED))
    b[:style] == :block && b[:tags] == ["scope/portable", "form/preference", "ruby"]
  end
  check("reads a buried flow sequence") do
    b = Dream.nested_tag_block(Dream.frontmatter(BURIED_INLINE))
    b[:style] == :inline && b[:tags] == ["scope/local", "form/artifact", "switch"]
  end
  check("refuses a buried key with nothing under it") do
    Dream.nested_tag_block(Dream.frontmatter(BURIED_EMPTY))[:style] == :empty
  end
  check("ignores a tags key nested under some other mapping") do
    Dream.nested_tag_block(Dream.frontmatter(NESTED_ELSEWHERE)).nil?
  end
  check("reports no buried key on a file tagged at the top level") do
    Dream.nested_tag_block(Dream.frontmatter(BLOCK_NOTE)).nil? &&
      Dream.nested_tag_block(Dream.frontmatter(MEMORY)).nil?
  end
  check("a buried key still reads as untagged at the top level") do
    Dream.tag_block(Dream.frontmatter(BURIED)).nil?
  end

  ho1, hs1 = run.("hoist_tags.rb")
  check("hoist dry run changes nothing on disk") do
    File.read(File.join(vault, "knowledge/buried.md")) == BURIED
  end
  check("hoist dry run names every buried file") do
    %w[buried.md buried_inline.md buried_and_top.md].all? { |f| ho1.include?(f) }
  end
  check("hoist exits nonzero when it refuses a file") { !hs1.success? && ho1.include?("EMPTY") }

  run.("hoist_tags.rb", "--write")
  hoisted = frontmatter_of(File.join(vault, "knowledge/buried.md"))
  check("hoist lifts the tags to the top level") do
    hoisted["tags"] == ["scope/portable", "form/preference", "ruby"]
  end
  check("hoist removes the buried copy") do
    !hoisted["metadata"].key?("tags")
  end
  check("hoist keeps every other frontmatter key") do
    hoisted["name"] == "feedback-buried" &&
      hoisted["description"] == "Tags a session chose, buried by a rewrite" &&
      hoisted["metadata"]["node_type"] == "memory" &&
      hoisted["metadata"]["type"] == "feedback" &&
      hoisted["metadata"]["originSessionId"] == "abc123"
  end
  check("hoist leaves the body untouched") do
    body_of(File.read(File.join(vault, "knowledge/buried.md"))) == body_of(BURIED)
  end
  check("hoist unions a buried copy with the top-level one") do
    frontmatter_of(File.join(vault, "knowledge/buried_and_top.md"))["tags"] ==
      ["scope/portable", "form/pattern", "ruby", "testing"]
  end
  check("hoist refuses the empty key rather than writing tags: []") do
    fm = frontmatter_of(File.join(vault, "knowledge/buried_empty.md"))
    !fm.key?("tags") && fm["metadata"].key?("tags")
  end
  check("hoist does not touch a tags key under another mapping") do
    File.read(File.join(vault, "Notes/elsewhere.md")) == NESTED_ELSEWHERE
  end
  check("a hoisted file is tagged as far as every other script is concerned") do
    Dream.tags_for(Dream.read("knowledge/buried.md")) ==
      ["scope/portable", "form/preference", "ruby"]
  end

  ho2, hs2 = run.("hoist_tags.rb", "--write")
  check("hoist is idempotent") do
    hs2.success? == false && ho2.include?("buried tag keys: 0") &&
      frontmatter_of(File.join(vault, "knowledge/buried.md"))["tags"].size == 3
  end

  # --- apply_tags ---------------------------------------------------------------------
  table = File.join(root, "tags.tsv")
  File.write(table, [
    "knowledge/reference_example.md\tscope/portable form/pattern ruby",
    "knowledge/broken.md\tscope/local form/artifact",
    "knowledge/dupkeys.md\tscope/local form/artifact",
    # The hoisted files carry these already, so apply_tags must report them unchanged: the
    # run tags what hoist restored rather than writing over it.
    "knowledge/buried.md\tscope/portable form/preference ruby",
    "knowledge/buried_inline.md\tscope/local form/artifact switch",
    "knowledge/buried_and_top.md\tscope/portable form/pattern ruby testing",
    "knowledge/buried_empty.md\tscope/local form/artifact",
    "Notes/elsewhere.md\tscope/local form/artifact switch",
    "Notes/bare.md\tscope/local form/artifact runbook",
    "Notes/[WIP] plan.md\tscope/local form/artifact",
    "Notes/block.md\tscope/domain form/pattern boost",
    "Notes/zero.md\tscope/domain form/pattern",
    "Notes/ragged.md\tscope/local form/artifact",
    "Notes/fence.md\tscope/local form/artifact",
    "Notes/hrule.md\tscope/local form/artifact",
    "Notes/wrapped.md\tscope/local form/artifact",
    "Notes/commented.md\tscope/local form/artifact",
    "Notes/Nested/tagged.md\tscope/domain form/artifact boost",
    "knowledge/archive/old.md\tscope/local form/artifact",
    "Notes/no_tags_column.md\t",
  ].join("\n") + "\n")

  # Files no writer may touch: the fence never closes, the block is not valid YAML, the key is
  # duplicated, the leading `---` is a rule, or the flow sequence does not close on its line.
  REFUSED = %w[knowledge/broken.md knowledge/dupkeys.md
               Notes/ragged.md Notes/hrule.md Notes/wrapped.md].freeze

  before = Dream.files.to_h { |rel, _| [rel, body_of(Dream.read(rel))] }
  out, status = run.("apply_tags.rb", table, "--write")

  check("apply_tags refuses a path outside territory") { out.include?("NOT IN TERRITORY") }
  check("apply_tags skips unclosed frontmatter") { out.include?("UNCLOSED FRONTMATTER") }
  # Mixed indentation is invalid YAML, so Dream.frontmatter refuses the file before tag_block
  # ever classifies the list. The :ragged style stays as defence for a shape that parses.
  check("apply_tags skips a ragged list") { out.include?("UNPARSEABLE FRONTMATTER: Notes/ragged.md") }
  check("apply_tags skips duplicate tags keys") { out.include?("DUPLICATE tags") }
  check("apply_tags skips a horizontal rule posing as frontmatter") { out.include?("NOT_A_MAPPING") }
  check("apply_tags skips an unterminated flow sequence") { out.include?("UNTERMINATED tags") }
  check("apply_tags refuses a row with no tag column") { out.include?("NO TAGS IN TABLE") }
  check("apply_tags exits non-zero when any file was refused") { !status.success? }

  # The guarantee that tag-only mode rests on. Enforced by refusing the file rather than by
  # detecting damage after the fact, which is why the assertion is byte-identity.
  check("leaves a horizontal-rule note byte-identical") { Dream.read("Notes/hrule.md") == HRULE }
  check("leaves a wrapped flow sequence byte-identical") { Dream.read("Notes/wrapped.md") == WRAPPED }
  check("merges past a trailing comment, keeping the comment") do
    src = Dream.read("Notes/commented.md")
    src.include?("tags: [switch, scope/local, form/artifact] # revisit before folding") &&
      frontmatter_of(File.join(vault, "Notes/commented.md"))["tags"] ==
        %w[switch scope/local form/artifact]
  end

  check("inserts tags into existing frontmatter") do
    Dream.tags_for(Dream.read("knowledge/reference_example.md")) == %w[scope/portable form/pattern ruby]
  end
  check("keeps auto-memory's own keys and nesting") do
    src = Dream.read("knowledge/reference_example.md")
    src.include?("name: reference-example") && src.include?("  type: reference") && !src.match?(/^type:/)
  end
  check("prepends a block to a file with no frontmatter") do
    Dream.tags_for(Dream.read("Notes/bare.md")) == %w[scope/local form/artifact runbook]
  end
  check("quotes a prepended title so metacharacters cannot break it") do
    frontmatter_of(File.join(vault, "Notes/[WIP] plan.md"))["title"] == "[WIP] plan"
  end
  check("merges into an indented block without restyling it") do
    Dream.read("Notes/block.md").include?("  - scope/domain")
  end
  check("merges into a zero-indent block without re-indenting it") do
    src = Dream.read("Notes/zero.md")
    src.include?("\n- alpha\n- beta\n- scope/domain\n") && !src.include?("  - scope/domain")
  end
  check("merges preserving the user's own tags first") do
    Dream.tags_for(Dream.read("Notes/Nested/tagged.md")) == %w[switch boost scope/domain form/artifact]
  end
  check("leaves a refused file byte-identical") do
    Dream.read("knowledge/broken.md") == BROKEN && Dream.read("Notes/ragged.md") == RAGGED &&
      Dream.read("knowledge/dupkeys.md") == DUPLICATE_KEYS
  end
  check("NEVER changes a body") { before.all? { |rel, b| body_of(Dream.read(rel)) == b } }

  # The check that the body assertion cannot make: apply_tags only ever splices inside the
  # frontmatter, so no body can change however badly the block above it is mangled.
  check("EVERY written file still has parseable frontmatter") do
    Dream.files.all? do |rel, _|
      next true if REFUSED.include?(rel)
      fm = frontmatter_of(File.join(vault, rel))
      fm.is_a?(Hash) && fm["tags"].is_a?(Array)
    end
  end

  out2, _ = run.("apply_tags.rb", table, "--write")
  check("is idempotent — a second apply changes nothing") { out2.match?(/unchanged: 13/) }

  clean = File.join(root, "clean.tsv")
  File.write(clean, "Notes/bare.md\tscope/local form/artifact runbook\n")
  _, cstatus = run.("apply_tags.rb", clean, "--write")
  check("apply_tags exits zero when every row applied") { cstatus.success? }

  # --- state ---------------------------------------------------------------------------
  sout, _ = run.("state.rb", "--write")
  # The count is derived, not a literal: a hardcoded "removed: 19" was true in exactly the
  # failure mode it was named for, once the real store grew past 19 files.
  check("state.rb writes beside its own territory, not the real one") do
    File.exist?(env["DREAM_STATE"]) &&
      JSON.parse(File.read(env["DREAM_STATE"]))["vault"] == vault &&
      sout.include?("files hashed: #{Dream.files.size}")
  end
  check("state.rb records every in-scope file") do
    JSON.parse(File.read(env["DREAM_STATE"]))["hashes"].size == Dream.files.size
  end
  check("state.rb stamps today, not a baked-in date") do
    JSON.parse(File.read(env["DREAM_STATE"]))["last_run"] == Date.today.to_s
  end
  File.write(env["DREAM_STATE"], "not json")
  sout2, sstatus2 = run.("state.rb")
  check("state.rb survives a corrupt state file") { sstatus2.success? && sout2.include?("unreadable") }

  # --- synonyms -------------------------------------------------------------------------
  # The fixture must contain pairs the detector should find. Without them every section prints
  # "(none)" whatever the code does, and the only thing asserted is that headings exist —
  # gutting the comparison entirely would still pass.
  syn = File.join(root, "syn.tsv")
  File.write(syn, [
    "Notes/bare.md\trunbook",
    "Notes/block.md\trunbooks",
    "Notes/fence.md\tpaired-alpha paired-beta",
    "Notes/zero.md\tpaired-alpha paired-beta",
  ].join("\n") + "\n")
  run.("apply_tags.rb", syn, "--write")

  yout, ystatus = run.("synonyms.rb")
  check("synonyms.rb detects a plural against its singular") do
    ystatus.success? && yout.match?(/SPELLING VARIANTS.*\n.*runbook\s+runbooks/)
  end
  check("synonyms.rb detects two tags with identical coverage") do
    yout.include?("paired-alpha == paired-beta")
  end

  # --- rename_tag -------------------------------------------------------------------------
  rout, rstatus = run.("rename_tag.rb", "runbooks", "runbook", "--write")
  check("rename_tag folds a tag and reports the files") { rout.include?("1 file(s)") }
  # The fixture still holds shapes no writer may touch, and a fold that skipped a file must
  # say so and exit non-zero: filtering on the tag first would drop them without a word.
  check("rename_tag reports files it could not rewrite") do
    !rstatus.success? && rout.match?(/SKIPPED (DUPLICATE|UNPARSEABLE|UNTERMINATED)/)
  end
  check("rename_tag retires the old spelling") do
    Dream.files.none? { |rel, _| (Dream.tags_for(Dream.read(rel)) || []).include?("runbooks") }
  end
  check("rename_tag dedupes when the target is already present") do
    tags = Dream.tags_for(Dream.read("Notes/block.md"))
    tags.count("runbook") == 1
  end
  nout, nstatus = run.("rename_tag.rb", "never-used-tag", "other", "--write")
  check("rename_tag exits non-zero when nothing matched") { !nstatus.success? && nout.include?("0 file(s)") }
  gout, gstatus = run.("rename_tag.rb", "scope/local", "scope/domain")
  check("rename_tag refuses to fold a scope or form value") { !gstatus.success? && gout.include?("refusing") }

  # --- snapshot ---------------------------------------------------------------------------
  sn1, snstatus = run.("snapshot.rb", "--write")
  check("snapshot copies every in-scope file") do
    snstatus.success? && sn1.include?("#{Dream.files.size} file(s)")
  end
  snap_root = File.join(root, "snapshots")
  check("snapshot preserves relative paths, nesting included") do
    Dir.glob(File.join(snap_root, "**", "Nested", "tagged.md")).any?
  end
  sn2, _ = run.("snapshot.rb", "--write")
  check("a second snapshot the same day does not overwrite the first") do
    sn2.match?(/-b\b/) && Dir.children(snap_root).size == 2
  end

  # --- prune ------------------------------------------------------------------------------
  FileUtils.mkdir_p(File.join(snap_root, "2020-01-01", "knowledge"))
  File.write(File.join(snap_root, "2020-01-01", "knowledge", "x.md"), "old\n")
  FileUtils.mkdir_p(File.join(snap_root, "2020-01-02-b"))
  pout, pstatus = run.("prune.rb", "--write")
  check("prune removes a dated snapshot past the window") do
    pstatus.success? && !Dir.exist?(File.join(snap_root, "2020-01-01"))
  end
  check("prune matches a suffixed directory, not only a bare date") do
    !Dir.exist?(File.join(snap_root, "2020-01-02-b"))
  end
  check("prune keeps today's snapshots") { Dir.children(snap_root).size == 2 }
  _, dstatus = run.("prune.rb", "--days")
  check("prune refuses --days with no value rather than sweeping everything") { !dstatus.success? }
  _, d2status = run.("prune.rb", "--days", "abc")
  check("prune refuses a non-numeric --days") { !d2status.success? }

  # --- validate ---------------------------------------------------------------------------
  # Build the catalog from the tags actually present, so adding a fixture does not silently
  # break the clean-store assertion with a stale hand-written count.
  rebuild_catalog = lambda do
    counts = Hash.new(0)
    Dream.files.each { |rel, _| (Dream.tags_for(Dream.read(rel)) || []).each { |t| counts[t] += 1 } }
    File.write(File.join(vault, "knowledge", "MEMORY.md"),
               "# Memory\n\n## Tag catalog\n\n" +
               counts.sort.map { |t, n| "- `#{t}` (#{n})" }.join("\n") + "\n")
    counts
  end

  REFUSED.each { |r| File.delete(File.join(vault, r)) }
  rebuild_catalog.call

  o, s = run.("validate.rb")
  check("validate passes a clean store") { s.success? && o.include?("OK") }

  good = File.join(vault, "knowledge", "reference_example.md")
  saved = File.read(good)
  swap = ->(from, to) { File.write(good, saved.sub(from, to)) }
  inline = "tags: [scope/portable, form/pattern, ruby]"

  {
    "two scopes on one file" => ["not exactly one scope/", "tags: [scope/portable, scope/local, form/pattern, ruby]"],
    "a missing form/" => ["not exactly one form/", "tags: [scope/portable, ruby]"],
    "a duplicate tag value" => ["duplicate tag values", "tags: [scope/portable, form/pattern, ruby, ruby]"],
    "malformed tag syntax" => ["malformed tag syntax", "tags: [scope/portable, form/pattern, Ruby_Lang]"],
  }.each do |label, (expected_msg, replacement)|
    swap.(inline, replacement)
    o1, s1 = run.("validate.rb")
    check("validate catches #{label}") { !s1.success? && o1.include?(expected_msg) }
  end

  # A flow sequence followed by a bare scalar. `title: [WIP]` alone would be valid YAML —
  # it parses as a one-element list — so it proves nothing about the parser check.
  swap.(inline, "tags: [scope/portable, form/pattern, ruby]\ntitle: [WIP] plan")
  o2, s2 = run.("validate.rb")
  check("validate catches frontmatter that does not parse") { !s2.success? && o2.include?("unparseable") }

  File.write(good, saved)
  rebuild_catalog.call
  o3, s3 = run.("validate.rb")
  check("validate passes again once repaired") { s3.success? && o3.include?("OK") }

  counts = rebuild_catalog.call
  cat = File.join(vault, "knowledge", "MEMORY.md")
  File.write(cat, File.read(cat).sub("`ruby` (#{counts['ruby']})", "`ruby` (99)"))
  o4, s4 = run.("validate.rb")
  check("validate catches a wrong catalog count") { !s4.success? && o4.include?("catalog count wrong") }

  rebuild_catalog.call
  File.write(cat, "# Memory\n\n## Tag catalog\n\n| tag | n |\n|---|---|\n| `ruby` | 1 |\n")
  o5, s5 = run.("validate.rb")
  check("validate catches a catalog in the wrong format") { !s5.success? && o5.include?("not in catalog") }
end

puts "#{PASS.size} passed, #{FAIL.size} failed"
PASS.each { |n| puts "  ok   #{n}" }
FAIL.each { |n| puts "  FAIL #{n}" }
exit(FAIL.empty? ? 0 : 1)
