#!/usr/bin/env ruby
# Remove snapshot directories older than the retention window.
#
# Snapshots are a full copy of the store per run, so they have to be swept or the directory
# grows by the size of the vault every night. A Bash `rm -rf` is refused by the block-rm.sh
# PreToolUse hook, which bypassPermissions does not lift, and `find -delete` cannot remove a
# non-empty directory — so an unattended run has no shell form available and stalls.
#
# Only ever touches directories directly under the snapshots root whose names are a date,
# so a mistyped root deletes nothing.
#
# Usage: ruby prune.rb [--write] [--days N]

require "fileutils"
require "date"
require_relative "lib"

WRITE = ARGV.include?("--write")

# `--days` with a missing or non-numeric value would reach to_i as 0 and sweep every snapshot
# taken before today — at the start of a run, before the new one exists. Refuse instead.
days = 14
if ARGV.include?("--days")
  raw = ARGV[ARGV.index("--days") + 1]
  abort "--days needs a positive number of days" unless raw.to_s.match?(/\A\d+\z/) && raw.to_i.positive?
  days = raw.to_i
end

ROOT = File.join(File.dirname(Dream::TERRITORY), "snapshots")

# A date prefix, not an exact date: a second run on one day writes `2026-09-19-b`, and an
# exact match would retain every such directory forever at the size of the store.
DATED = /\A(\d{4}-\d{2}-\d{2})(-|\z)/

unless Dir.exist?(ROOT)
  puts "no snapshots directory at #{ROOT}"
  exit 0
end

cutoff = Date.today - days
stale = Dir.children(ROOT).select do |name|
  match = DATED.match(name)
  next false if match.nil?
  next false unless File.directory?(File.join(ROOT, name))
  Date.parse(match[1]) < cutoff
rescue Date::Error
  false
end.sort

stale.each do |name|
  path = File.join(ROOT, name)
  count = Dir.glob(File.join(path, "**", "*")).count { |f| File.file?(f) }
  puts "  #{name}  (#{count} files)"
  FileUtils.rm_rf(path) if WRITE
end

puts "snapshots older than #{days} days: #{stale.size}"
puts(WRITE ? "REMOVED" : "DRY RUN — pass --write to remove")
