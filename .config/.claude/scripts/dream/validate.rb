#!/usr/bin/env ruby
# Assert every invariant the store depends on. Read-only; exits non-zero if any fails.
#
# Retrieval is grep against tags, so a tag that is misspelled, duplicated, or missing its
# scope is a memory nobody finds again — and nothing about the file looks wrong when you
# open it. These checks are the only thing that reports that class of fault, which is why
# the counter pass runs this rather than reading every file by hand.
#
# Usage: ruby validate.rb [--quiet]

require "yaml"
require_relative "lib"

QUIET = ARGV.include?("--quiet")

# --counts emits the catalog's tag lines, already counted and in the shape validate parses.
# Step 5 otherwise hand-counts 129 tags across 190 files, and step 7 fails the whole run on a
# single off-by-one — the most arithmetic-heavy step was the one with no script behind it.
COUNTS = ARGV.include?("--counts")
TAG_SYNTAX = %r{\A(scope/|form/)?[a-z0-9]+(-[a-z0-9]+)*\z}

failures = Hash.new { |h, k| h[k] = [] }
warnings = Hash.new { |h, k| h[k] = [] }
tag_counts = Hash.new(0)
file_tags = {}

Dream.files.each do |rel, _mode|
  src = Dream.read(rel)
  fm = Dream.frontmatter(src)

  unless fm[:ok]
    # not_a_mapping is usually a note opening with a horizontal rule, which no writer can
    # safely tag; unparseable is frontmatter already broken. Report them apart, because the
    # repairs differ.
    failures["frontmatter #{fm[:reason]}"] << rel
    next
  end

  if fm[:close].nil?
    failures["no frontmatter"] << rel
    next
  end

  # The YAML parse now lives in Dream.frontmatter, which every reader and writer shares, so a
  # file this check would reject is one no writer would have touched either. Reaching here
  # means the block parses as a mapping.
  tag_lines = (1...fm[:close]).count { |i| fm[:lines][i].start_with?("tags:") }
  failures["duplicate tags: lines"] << "#{rel} (#{tag_lines})" if tag_lines > 1

  block = Dream.tag_block(fm)
  if block.nil?
    failures["untagged"] << rel
    next
  end

  tags = block[:tags]
  file_tags[rel] = tags
  tags.each { |t| tag_counts[t] += 1 }

  dupes = tags.tally.select { |_t, n| n > 1 }.keys
  failures["duplicate tag values"] << "#{rel} #{dupes.inspect}" if dupes.any?

  bad = tags.reject { |t| t.match?(TAG_SYNTAX) }
  failures["malformed tag syntax"] << "#{rel} #{bad.inspect}" if bad.any?

  scopes = tags.count { |t| t.start_with?("scope/") }
  forms  = tags.count { |t| t.start_with?("form/") }
  failures["not exactly one scope/"] << "#{rel} (#{scopes})" if scopes != 1
  failures["not exactly one form/"]  << "#{rel} (#{forms})"  if forms != 1

  # Two characters is almost always an acronym the naming rule asks to spell out. A warning,
  # not a failure: `ci` and `db` are legitimately their own names.
  short = tags.reject { |t| t.start_with?("scope/", "form/") }.select { |t| t.length <= 2 }
  warnings["possible acronym"] << "#{rel} #{short.inspect}" if short.any?
end

if COUNTS
  scopes, forms, subjects = tag_counts.keys.partition { |t| t.start_with?("scope/") }
                                      .then { |s, r| [s, *r.partition { |t| t.start_with?("form/") }] }
  [["scope", scopes], ["form", forms], ["subjects", subjects]].each do |label, tags|
    next if tags.empty?
    puts "**#{label}**"
    puts tags.sort.map { |t| "- `#{t}` (#{tag_counts[t]})" }
    puts
  end
  exit 0
end

# Wikilinks resolve against every note in the vault, not just territory — a memory may
# legitimately link to a note the skill never touches.
targets = Dir.chdir(Dream.vault) do
  Dir.glob("**/*.md").to_h { |f| [File.basename(f, ".md"), f] }
     .merge(Dir.glob("**/*.png").to_h { |f| [File.basename(f), f] })
end

# A dangling link shaped like a memory name is a deliberate forward reference — the memory
# format treats it as a marker for a memory worth writing, not a fault. Report those as a
# wanted list. A dangling link shaped like anything else is usually a typo or a note that
# moved, so it warns.
MEMORY_NAME = /\A(project|reference|feedback|user)_[a-z0-9_]+\z/
wanted = Hash.new { |h, k| h[k] = [] }

Dream.files.each do |rel, _mode|
  Dream.read(rel).scan(/\[\[([^\]\|#]+)/).flatten.each do |raw|
    link = raw.strip
    next if targets.key?(link) || targets.key?("#{link}.png")
    if link.match?(MEMORY_NAME)
      wanted[link] << File.basename(rel, ".md")
    else
      warnings["dangling link, not a memory name"] << "[[#{link}]] in #{File.basename(rel)}"
    end
  end
end

# The catalog is the vocabulary the next run reads before coining a term. A tag missing from
# it is invisible to that check; a wrong count means the catalog was written from memory
# rather than measured.
catalog_path = File.join(Dream.vault, "knowledge", "MEMORY.md")
if File.exist?(catalog_path)
  body = File.read(catalog_path)
  section = body.split("## Tag catalog", 2)[1].to_s.split(/^## /, 2).first.to_s
  if section.strip.empty?
    failures["catalog"] << "no '## Tag catalog' section in MEMORY.md"
  else
    # The catalog prose quotes tags it is telling you NOT to coin ("spell terms out —
    # `salesforce` never `sf`"). A real entry carries a count, or is a ticket reference,
    # which is listed bare. Anything else in backticks is an example, not a claim.
    claimed = {}
    section.scan(/`([a-z0-9\/\-]+)`(?:\s*\((\d+)\))?/) do |tag, n|
      next if n.nil? && !tag.match?(/\A[a-z]+-\d+\z/)
      claimed[tag] = n&.to_i
    end

    (tag_counts.keys - claimed.keys).sort.each do |t|
      failures["tag used but not in catalog"] << "#{t} (#{tag_counts[t]} files)"
    end
    (claimed.keys - tag_counts.keys).sort.each do |t|
      failures["catalog tag used by nothing"] << t
    end
    claimed.each do |t, n|
      next if n.nil? || tag_counts[t] == n
      failures["catalog count wrong"] << "#{t}: says #{n}, actual #{tag_counts[t]}"
    end
  end
else
  failures["catalog"] << "MEMORY.md missing"
end

unless QUIET
  puts "files: #{file_tags.size} tagged of #{Dream.files.size} in scope"
  puts "distinct tags: #{tag_counts.size}"
  puts
end

unless wanted.empty?
  puts "WANTED — memories a sibling links to that do not exist yet (#{wanted.size})"
  wanted.sort.each { |name, from| puts "  #{name}  <- #{from.uniq.join(', ')}" }
  puts
end

warnings.each do |kind, items|
  puts "WARN #{kind} (#{items.size})"
  items.each { |i| puts "  #{i}" }
  puts
end

if failures.empty?
  puts "OK — all invariants hold"
  exit 0
end

failures.each do |kind, items|
  puts "FAIL #{kind} (#{items.size})"
  items.first(20).each { |i| puts "  #{i}" }
  puts "  … #{items.size - 20} more" if items.size > 20
end
exit 1
