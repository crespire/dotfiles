#!/usr/bin/env ruby
# Insert or merge a top-level `tags:` key. Touches frontmatter only — the body is copied
# through untouched, which is what makes the tag-only guarantee on hand-written notes
# structural rather than a promise the run has to keep.
#
# Usage: ruby apply_tags.rb TABLE.tsv [--write]
#   TABLE.tsv — one row per file: <path relative to vault>\t<tag> <tag> <tag>
#
# Four cases, and the fourth is the one that corrupts files when improvised:
#   no frontmatter        → prepend a block (title: from the filename, for prose notes)
#   frontmatter, no tags: → insert above the closing fence
#   frontmatter with tags → union, preserving the order already there
#   unclosed frontmatter  → skip and report; repairing it means guessing where it ends

require_relative "lib"

table_path = ARGV.find { |a| !a.start_with?("--") }
WRITE = ARGV.include?("--write")
abort "usage: apply_tags.rb TABLE.tsv [--write]" if table_path.nil?

rows = File.readlines(table_path).filter_map do |line|
  next if line.strip.empty? || line.start_with?("#")
  rel, tags = line.rstrip.split("\t", 2)
  [rel, tags.to_s.split(/[,\s]+/).map(&:strip).reject(&:empty?)]
end

in_scope = Dream.files.to_h
stats = Hash.new(0)
problems = []

rows.each do |rel, tags|
  # An empty tag column writes `tags: []`, which validate then fails for having no scope —
  # reading as a tagging misjudgement rather than as the malformed table it is.
  if tags.empty?
    problems << "NO TAGS IN TABLE: #{rel}"
    stats[:skipped] += 1
    next
  end

  unless in_scope.key?(rel)
    problems << "NOT IN TERRITORY: #{rel}"
    stats[:skipped] += 1
    next
  end

  path = File.join(Dream.vault, rel)
  src = File.read(path)
  fm = Dream.frontmatter(src)

  unless fm[:ok]
    # Name the actual reason. `not_a_mapping` usually means the file opens with a horizontal
    # rule rather than frontmatter, which needs a different response from a broken block.
    problems << "#{fm[:reason].to_s.upcase} FRONTMATTER: #{rel}"
    stats[:skipped] += 1
    next
  end

  if fm[:close].nil?
    # inspect, not interpolation: an Obsidian note is routinely called "[WIP] plan" or
    # "Sprint #4", and unquoted those are a YAML flow sequence and a comment. Either makes
    # the block we just wrote unreadable, taking the file's own keys down with it.
    # to_yaml, not inspect: Ruby escapes `#` before `{`, `$` or `@`, and YAML has no `\#`
    # escape, so a note called "Interp #{x}" would emit frontmatter YAML refuses to read.
    title = {"title" => File.basename(rel, ".md")}.to_yaml.sub(/\A---\n/, "").strip
                                                  .sub(/\Atitle:\s*/, "")
    header = ["---\n", "title: #{title}\n", "tags: [#{tags.join(', ')}]\n", "---\n", "\n"]
    File.write(path, (header + fm[:lines]).join) if WRITE
    stats[:prepended] += 1
    next
  end

  lines = fm[:lines]
  block = Dream.tag_block(fm)

  unless Dream.writable_tags?(block)
    problems << "#{block[:style].to_s.upcase} tags: #{rel}"
    stats[:skipped] += 1
    next
  end

  if block
    merged = block[:tags] | tags
    if merged == block[:tags]
      stats[:unchanged] += 1
      next
    end
    # Splice in the file's own style. Writing inline over a block list would leave the old
    # "  - value" lines orphaned under the new key, which is invalid YAML and loses the tags.
    lines[block[:first]..block[:last]] = Dream.render_tags(merged, block[:style], block[:indent], block[:suffix])
    stats[:merged] += 1
  else
    lines.insert(fm[:close], *Dream.render_tags(tags, :inline))
    stats[:inserted] += 1
  end

  File.write(path, lines.join) if WRITE
end

puts "table rows: #{rows.size}  (territory holds #{in_scope.size})"
puts stats.sort.map { |k, v| "#{k}: #{v}" }.join("  ")
problems.each { |p| puts "  #{p}" }
puts(WRITE ? "WROTE" : "DRY RUN — pass --write to apply")

# A table that resolved to nothing means the paths are wrong — absolute where they should be
# vault-relative, most often. Unattended, exit 0 here reads as a run that tagged everything.
if problems.any?
  warn "apply_tags: #{problems.size} file(s) not applied"
  exit 1
end
exit 1 if rows.any? && stats.values_at(:inserted, :merged, :prepended).sum.zero? && stats[:unchanged].zero?
