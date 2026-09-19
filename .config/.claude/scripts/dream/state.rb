#!/usr/bin/env ruby
# Record a content hash per in-scope file, so the next run reads only what changed.
#
# Hashes live here rather than in each file's frontmatter because the harness rewrites
# frontmatter and would drop a key it does not recognise, which would silently mark every
# file as changed forever after.
#
# Run this LAST, after the counter pass, so the hashes describe the corrected tree. Hashing
# before the counter reverts anything records a state that was never on disk.
#
# Usage: ruby state.rb [--write]

require "digest"
require "json"
require "date"
require_relative "lib"

WRITE = ARGV.include?("--write")

# The state file sits beside the territory file it describes. Hardcoding the real path would
# make a run against a fixture config write its hashes over the live store's, so a test could
# silently reset the incremental state of the vault it was meant not to touch.
STATE = ENV["DREAM_STATE"] || File.join(File.dirname(Dream::TERRITORY), "state.json")

hashes = Dream.files.to_h do |rel, _mode|
  [rel, Digest::SHA256.file(File.join(Dream.vault, rel)).hexdigest]
end

# An unreadable state file means "nothing is known", which degrades to a full pass: slower,
# and correct. Raising instead would wedge every future run until someone deleted the file.
previous =
  begin
    File.exist?(STATE) ? JSON.parse(File.read(STATE))["hashes"] || {} : {}
  rescue JSON::ParserError => e
    warn "state.json unreadable (#{e.class}); treating every file as changed"
    {}
  end
added   = hashes.keys - previous.keys
removed = previous.keys - hashes.keys
changed = hashes.select { |rel, h| previous[rel] && previous[rel] != h }.keys

payload = {
  "last_run" => Date.today.to_s,
  "vault" => Dream.territory.fetch("vault"),
  "hashes" => hashes,
}

File.write(STATE, JSON.pretty_generate(payload) + "\n") if WRITE

# --list names the files a run should process, so the selection rule lives in one place
# instead of being reimplemented against state.json by whoever is reading SKILL.md.
# A file with no tags: key is included whatever its hash says, since the tag may have been
# dropped by an auto-memory rewrite that left the rest of the content alone.
if ARGV.include?("--list")
  # Empty counts as untagged. `tags: []`, or a list that lost its scope, returns [] rather
  # than nil — a file that then fails validate every night with nothing able to reselect it.
  untagged = Dream.files.select { |rel, _| Dream.tags_for(Dream.read(rel)).to_a.empty? }.map(&:first)
  puts((added + changed + untagged).uniq.sort)
  exit 0
end

puts "files hashed: #{hashes.size}"
puts "since last run — added: #{added.size}, changed: #{changed.size}, removed: #{removed.size}"
puts(WRITE ? "wrote #{STATE}" : "DRY RUN — pass --write to record")
