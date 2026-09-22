#!/usr/bin/env ruby
# Lift a `tags:` key out of the `metadata:` mapping and back to the top level, where every
# other script in this harness looks for it.
#
# Usage: ruby hoist_tags.rb [--write]
#
# Auto-memory rewrites a memory's frontmatter whenever it touches the file, and a top-level
# `tags:` comes back nested under `metadata:`. Nothing reports it: the file reads as untagged,
# so the run tags it from scratch and overwrites the judgement of the session that wrote the
# memory, while the buried copy stays behind for the next run to trip over again. Restoring
# the key is mechanical, so it runs before selection rather than as a tagging decision.
#
# The pass moves a key. It never invents, drops or rewrites a tag value, and it refuses every
# shape it cannot read exactly — a nested key with nothing under it, a flow sequence that does
# not close on its line, a list at ragged indentation, two keys where one belongs.

require_relative "lib"

WRITE = ARGV.include?("--write")

# The same two styles apply_tags will write. A shape outside them is reported for a human:
# guessing at it moves tags into a mapping that no longer parses, which loses every key the
# file had rather than only its tags.
HOISTABLE = %i[inline block].freeze

stats = Hash.new(0)
problems = []
moved = []

Dream.files.each do |rel, _mode|
  path = File.join(Dream.vault, rel)
  src = File.read(path)
  fm = Dream.frontmatter(src)

  unless fm[:ok]
    # Only report a file that actually carries a buried key. Unparseable frontmatter is
    # validate's finding to make, and repeating it here buries this pass's own output.
    problems << "#{fm[:reason].to_s.upcase} FRONTMATTER: #{rel}" if src.include?("tags:")
    next
  end

  nested = Dream.nested_tag_block(fm)
  next if nested.nil?

  unless HOISTABLE.include?(nested[:style])
    problems << "#{nested[:style].to_s.upcase} nested tags: #{rel}"
    stats[:skipped] += 1
    next
  end

  before = begin
    YAML.safe_load(fm[:lines][1...fm[:close]].join, permitted_classes: [Date, Time])
  rescue Psych::Exception
    nil
  end
  before = nil unless before.is_a?(Hash)

  lines = fm[:lines].dup
  lines.slice!(nested[:first]..nested[:last])

  # `metadata:` with no children left parses as nil, not as an empty mapping, so the hoist
  # would silently drop a key the file still declares. Nothing in the store has that shape
  # today; refusing costs one report and keeps the pass to moving a key.
  meta = lines.index { |l| l.start_with?("metadata:") }
  if meta && !lines[meta + 1].to_s.match?(/\A[ \t]+\S/)
    problems << "WOULD EMPTY metadata: #{rel}"
    stats[:skipped] += 1
    next
  end

  fm2 = Dream.frontmatter(lines.join)
  block = Dream.tag_block(fm2)
  unless Dream.writable_tags?(block)
    problems << "#{block[:style].to_s.upcase} top-level tags: #{rel}"
    stats[:skipped] += 1
    next
  end

  # Union, top-level order first. A file holding both keys means a run tagged it and
  # auto-memory then buried a second copy; the tags are the same set often enough, and
  # dropping either side would lose a considered tag.
  merged = (block ? block[:tags] : []) | nested[:tags]

  out = fm2[:lines]
  style =
    if block
      out[block[:first]..block[:last]] = Dream.render_tags(merged, block[:style], block[:indent], block[:suffix])
      :merged
    else
      out.insert(fm2[:close], *Dream.render_tags(merged, :inline))
      :hoisted
    end

  # The suite's standing worry: frontmatter that stops parsing loses every key silently, and
  # Obsidian then shows the note with no properties at all. Prove the block still reads, and
  # that this pass changed nothing in it but `tags`, before anything reaches disk. Counting
  # the file before this point would report a hoist the run then refused to make.
  fm3 = Dream.frontmatter(out.join)
  after = begin
    fm3[:close] && YAML.safe_load(out[1...fm3[:close]].join, permitted_classes: [Date, Time])
  rescue Psych::Exception
    nil
  end

  if before.nil? || !after.is_a?(Hash)
    problems << "WOULD NOT PARSE: #{rel}"
    stats[:skipped] += 1
    next
  end

  lost = (before.keys - after.keys) - ["metadata"]
  meta_lost = (before["metadata"] || {}).keys - (after["metadata"] || {}).keys - ["tags"]
  if lost.any? || meta_lost.any?
    problems << "WOULD LOSE KEYS #{(lost + meta_lost).inspect}: #{rel}"
    stats[:skipped] += 1
    next
  end

  # The tags are the point of the move, so assert they arrived rather than trusting the
  # splice: a writer that puts them where YAML drops them reports success having lost them.
  unless (merged - Array(after["tags"])).empty?
    problems << "TAGS DID NOT SURVIVE: #{rel}"
    stats[:skipped] += 1
    next
  end

  stats[style] += 1
  moved << "#{rel}  #{merged.join(', ')}"
  File.write(path, out.join) if WRITE
end

puts "buried tag keys: #{stats[:hoisted] + stats[:merged]}  (territory holds #{Dream.files.size})"
puts stats.sort.map { |k, v| "#{k}: #{v}" }.join("  ") unless stats.empty?
moved.each { |m| puts "  #{m}" }
problems.each { |p| puts "  #{p}" }
puts(WRITE ? "WROTE" : "DRY RUN — pass --write to apply")

# Unattended, a refusal that exits 0 reads as a clean store, and the file stays buried
# through every run that follows.
if problems.any?
  warn "hoist_tags: #{problems.size} file(s) not hoisted"
  exit 1
end
