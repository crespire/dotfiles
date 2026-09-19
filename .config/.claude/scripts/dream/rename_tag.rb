#!/usr/bin/env ruby
# Fold one subject tag into another across every in-scope file.
#
# `apply_tags.rb` can only add: its merge is a union, so it cannot retire a spelling. Without
# this, the fold step is the one destructive operation done by hand, across the
# tag-only directories where hand-written prose lives — the single place the "frontmatter
# only" guarantee would stop being mechanical.
#
# Usage: ruby rename_tag.rb OLD NEW [--write]
#
# Files whose tags cannot be rewritten safely (ragged list, duplicate keys, unclosed
# frontmatter) are reported and left alone, exactly as apply_tags leaves them.

require_relative "lib"

WRITE = ARGV.include?("--write")
old_tag, new_tag = ARGV.reject { |a| a.start_with?("--") }
abort "usage: rename_tag.rb OLD NEW [--write]" if old_tag.nil? || new_tag.nil?

if old_tag.start_with?("scope/", "form/") || new_tag.start_with?("scope/", "form/")
  abort "refusing: scope/ and form/ are a fixed vocabulary, not emergent subject tags"
end

changed = []
problems = []

Dream.files.each do |rel, _mode|
  src = Dream.read(rel)
  fm = Dream.frontmatter(src)
  next unless fm[:ok] && fm[:close]

  block = Dream.tag_block(fm)
  next if block.nil?

  # Report an unwritable shape before filtering on the tag. A duplicate key or an unterminated
  # list yields no tags at all, so testing `include?` first drops the file silently and the
  # fold reports success over files it never touched.
  unless Dream.writable_tags?(block)
    problems << "#{block[:style].to_s.upcase} tags: #{rel}"
    next
  end

  next unless block[:tags].include?(old_tag)

  # Replace in place so the tag keeps its position, then drop a duplicate if the file already
  # carried the survivor. Appending instead would reorder the user's own vocabulary.
  renamed = block[:tags].map { |t| t == old_tag ? new_tag : t }.uniq

  lines = fm[:lines]
  lines[block[:first]..block[:last]] = Dream.render_tags(renamed, block[:style], block[:indent], block[:suffix])
  File.write(File.join(Dream.vault, rel), lines.join) if WRITE
  changed << rel
end

puts "#{old_tag} -> #{new_tag}: #{changed.size} file(s)"
changed.each { |r| puts "  #{r}" }
problems.each { |p| puts "  SKIPPED #{p}" }
puts(WRITE ? "WROTE" : "DRY RUN — pass --write to apply")

# Nothing matched means the tag was already folded or the name is a typo. Exiting 0 lets a run
# record a fold in DREAM.md that never happened, and no later check can catch that: validate
# has no way to know a fold was intended.
if changed.empty?
  warn "rename_tag: no file carries #{old_tag.inspect} — nothing folded"
  exit 1
end
exit(problems.empty? ? 0 : 1)
