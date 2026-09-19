#!/usr/bin/env ruby
# Find subject tags that are probably the same term wearing two spellings.
#
# The vocabulary is emergent, so nothing stops two runs coining `salesforce` and `sfdc` for
# one thing. The failure is silent in both directions: each tag looks correct, each grep
# looks correct, and the match between them never happens. Read-only; proposes, never edits.
#
# Two kinds of evidence, because they catch different mistakes:
#   spelling — the strings are variants of each other (plural, separator, case, acronym)
#   coverage — the strings differ but cover the same files, which is what a true synonym does
#
# Usage: ruby synonyms.rb

require "set"
require_relative "lib"

sets = Hash.new { |h, k| h[k] = Set.new }

Dream.files.each do |rel, _mode|
  (Dream.tags_for(Dream.read(rel)) || []).each { |t| sets[t] << rel }
end

TICKET = /\A[a-z]+-\d+\z/

subjects = sets.keys.reject { |t| t.start_with?("scope/", "form/") }.sort

# A ticket reference names one piece of work, so it sits inside whatever topic that work
# touched by definition. Including them in the containment check reports the taxonomy
# working correctly as though it were a fault.
taxonomy = subjects.reject { |t| t.match?(TICKET) }
normal = ->(t) { t.downcase.tr("_", "-").sub(/s\z/, "") }

# Only normalised equality — plural, separator and case drift. A shared prefix is not
# evidence of anything: `sti` does not abbreviate `stimulus`, and `sql` does not abbreviate
# `sqlite`. Coining an acronym is prevented at write time and warned on by validate.rb,
# which is the right place for it; guessing at it here only produces confident false pairs.
spelling = []
subjects.combination(2) do |a, b|
  spelling << [a, b] if normal.call(a) == normal.call(b)
end

# A broad tag like `switch` covers most of the store, so almost every narrow tag is a subset
# of it — true but useless. A needless split shows up as two tags of comparable reach, so
# require the narrower to cover at least half the wider.
CONTAINMENT_RATIO = 0.5

identical = []
contained = []
taxonomy.combination(2) do |a, b|
  next if sets[a].size < 2 || sets[b].size < 2
  if sets[a] == sets[b]
    identical << [a, b]
    next
  end
  narrow, wide = sets[a].size < sets[b].size ? [a, b] : [b, a]
  next unless sets[narrow].subset?(sets[wide])
  contained << [narrow, wide] if sets[narrow].size.to_f / sets[wide].size >= CONTAINMENT_RATIO
end

puts "subjects: #{subjects.size}"
puts

puts "SPELLING VARIANTS — fold unless both are genuinely distinct terms (#{spelling.size})"
spelling.each { |a, b| puts format("  %-28s %-28s [%d / %d files]", a, b, sets[a].size, sets[b].size) }
puts "  (none)" if spelling.empty?
puts

puts "IDENTICAL COVERAGE — same files, so one of the two is redundant (#{identical.size})"
identical.each do |a, b|
  puts "  #{a} == #{b}  (#{sets[a].size} files)"
  sets[a].sort.each { |f| puts "      #{f}" }
end
puts "  (none)" if identical.empty?
puts

puts "CONTAINED — the narrower may be a needless split of the wider (#{contained.size})"
contained.each { |a, b| puts format("  %-28s (%d) inside %-28s (%d)", a, sets[a].size, b, sets[b].size) }
puts "  (none)" if contained.empty?
puts

puts "The survivor is the tag the naming rules would produce — spelled out, lowercase,"
puts "hyphenated, singular — EXCEPT where one spelling is the user's own, which always wins."
