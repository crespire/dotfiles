#!/usr/bin/env ruby
# Copy every in-scope file to a dated snapshot directory outside the vault.
#
# This is the base of the audit trail. With no cap on how much a run may change, the snapshot
# is what the counter pass compares against and what makes a bad night recoverable, so it
# should not be a copy loop improvised at 4am across directory names containing spaces.
#
# Every in-scope file, not a predicted subset: which files a run modifies is not known at
# step 1, because the merge set is chosen in step 3 and the fold in step 4 reaches files the
# incremental check never selected.
#
# A second run on one day gets `-b`, `-c` and so on rather than overwriting the first — the
# earlier snapshot is the only remaining record of the state that run started from.
#
# Usage: ruby snapshot.rb [--write]

require "fileutils"
require "date"
require_relative "lib"

WRITE = ARGV.include?("--write")
ROOT = File.join(File.dirname(Dream::TERRITORY), "snapshots")

def next_free(root, date)
  return File.join(root, date) unless Dir.exist?(File.join(root, date))
  ("b".."z").each do |suffix|
    path = File.join(root, "#{date}-#{suffix}")
    return path unless Dir.exist?(path)
  end
  abort "snapshot: #{date} already has 25 snapshots; prune before running again"
end

target = next_free(ROOT, Date.today.to_s)
files = Dream.files

if WRITE
  files.each do |rel, _mode|
    dest = File.join(target, rel)
    FileUtils.mkdir_p(File.dirname(dest))
    FileUtils.cp(File.join(Dream.vault, rel), dest)
  end
end

puts "#{files.size} file(s) -> #{target}"
puts(WRITE ? "WROTE" : "DRY RUN — pass --write to copy")

if WRITE
  copied = Dir.glob(File.join(target, "**", "*.md")).size
  if copied != files.size
    warn "snapshot: copied #{copied} of #{files.size} — the counter pass has no baseline"
    exit 1
  end
end
