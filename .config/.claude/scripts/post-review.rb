#!/usr/bin/env ruby
# frozen_string_literal: true

# post-review.rb — turn an anchored-markdown review into a single GitHub PR
# review with line-anchored inline comments, and post it via `gh`.
#
# Durable home: ~/.claude/scripts/ (NOT tmp/, which gets wiped). Portable across
# repos — it shells out to `gh` and reads whatever review file you point it at.
#
# USAGE
#   ruby ~/.claude/scripts/post-review.rb [tmp/pr_review.md] [--pr N] [--event E] [--post]
#
#   Default is a DRY RUN: it parses, validates every comment against the PR diff,
#   and prints a preview. Nothing is sent until you pass --post (outward-facing).
#
# INPUT FORMAT (anchored markdown) — see the `code-review` skill for the contract.
#   - Optional metadata up top: `<!-- review event=REQUEST_CHANGES -->`
#     (or a `**State: CHANGES_REQUESTED**` line; CHANGES_REQUESTED maps to REQUEST_CHANGES).
#   - Preamble prose + any heading-section WITHOUT an anchor => the review BODY
#     (summary, cross-cutting/architectural notes, "looks good", follow-ups).
#   - Any heading-section whose first non-blank line is an anchor becomes one
#     INLINE comment on that line:
#         ### MIN_BASELINE_DAYS
#         <!-- review path=app/models/issues/x.rb line=15 side=RIGHT -->
#         The comment calls this "too new"...
#     `side` defaults to RIGHT. The `### heading` is organizational only and is
#     dropped from the posted comment body (inline comments carry no headline).

require "json"
require "open3"
require "set"

# --- arg parsing -------------------------------------------------------------

file = nil
pr_arg = nil
event_override = nil
do_post = false

ARGV.each do |a|
  case a
  when "--post", "--yes" then do_post = true
  when "--dry-run" then do_post = false
  when /\A--pr=(.+)\z/ then pr_arg = Regexp.last_match(1)
  when "--pr" then next # value picked up below
  when /\A--event=(.+)\z/i then event_override = Regexp.last_match(1)
  when /\A--/ then warn "ignoring unknown flag: #{a}"
  else
    # positional: either follows a bare --pr, or is the file path
    if ARGV[ARGV.index(a) - 1] == "--pr"
      pr_arg = a
    else
      file ||= a
    end
  end
end

file ||= "tmp/pr_review.md"
abort "review file not found: #{file}" unless File.file?(file)

def sh(*cmd)
  out, err, st = Open3.capture3(*cmd)
  abort "command failed: #{cmd.join(' ')}\n#{err}" unless st.success?
  out.strip
end

# --- resolve repo / PR / head commit via gh ----------------------------------

repo = sh("gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner")

pr_fields =
  if pr_arg
    JSON.parse(sh("gh", "pr", "view", pr_arg, "--json", "number,headRefOid,title"))
  else
    JSON.parse(sh("gh", "pr", "view", "--json", "number,headRefOid,title"))
  end
pr_number = pr_fields.fetch("number")
commit_id = pr_fields.fetch("headRefOid")
pr_title = pr_fields.fetch("title", "")

# --- build the set of RIGHT-side commentable lines from the PR diff ----------
# Inline review comments must land on a line that's part of the diff. Parse the
# unified diff into {path => Set[new_line_number]} so we can reject bad anchors
# BEFORE posting (a single invalid comment 422s the whole review).

diff = sh("gh", "pr", "diff", pr_number.to_s)
commentable = Hash.new { |h, k| h[k] = Set.new }
current_path = nil
new_line = nil
diff.each_line do |raw|
  line = raw.chomp
  if (m = line.match(%r{\A\+\+\+ b/(.*)\z}))
    current_path = (m[1] == "/dev/null") ? nil : m[1]
  elsif (m = line.match(/\A@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/))
    new_line = m[1].to_i
  elsif current_path && new_line
    case line[0]
    when "+" then commentable[current_path] << new_line; new_line += 1
    when " " then commentable[current_path] << new_line; new_line += 1
    when "-" then nil # left side only; doesn't advance the new-file counter
    when "\\" then nil # "\ No newline at end of file"
    end
  end
end

# --- parse the anchored markdown ---------------------------------------------

text = File.read(file)
event = event_override

# event from a top-of-file anchor or a **State:** line, if not overridden
if event.nil? && (m = text.match(/<!--\s*review\b([^>]*?)-->/m))
  attrs = m[1].scan(/(\w+)=("[^"]*"|\S+)/).to_h { |k, v| [k, v.delete_prefix('"').delete_suffix('"')] }
  event = attrs["event"]
end
if event.nil? && (m = text.match(/\*\*State:\s*([A-Za-z_]+)/))
  event = m[1]
end
event = (event || "COMMENT").upcase
event = "REQUEST_CHANGES" if event == "CHANGES_REQUESTED"
unless %w[REQUEST_CHANGES COMMENT APPROVE].include?(event)
  abort "unrecognized review event: #{event} (want REQUEST_CHANGES / COMMENT / APPROVE)"
end

ANCHOR = /\A<!--\s*review\s+(.*?)-->\s*\z/

def parse_anchor(line)
  inner = line.match(ANCHOR)[1]
  attrs = inner.scan(/(\w+)=("[^"]*"|\S+)/).to_h { |k, v| [k, v.delete_prefix('"').delete_suffix('"')] }
  attrs
end

# Split into sections on markdown headings. Everything before the first heading
# is the preamble. Each section is [heading_line_or_nil, [body_lines...]].
lines = text.lines.map(&:chomp)
sections = []
preamble = []
cur = nil
lines.each do |l|
  if l.match?(/\A#{'#'}{1,6}\s/)
    sections << cur if cur
    cur = {heading: l, lines: []}
  elsif cur
    cur[:lines] << l
  else
    preamble << l
  end
end
sections << cur if cur

# Strip metadata noise from preamble (top anchor, **State:** line, leading H1).
def clean_body_lines(arr)
  arr
    .reject { |l| l.match?(/\A<!--\s*review\b.*-->\s*\z/) }
    .reject { |l| l.match?(/\A\*\*State:/) }
end

comments = []
body_chunks = []
body_chunks << clean_body_lines(preamble).join("\n").strip

warnings = []

sections.each do |sec|
  first_real = sec[:lines].find { |l| !l.strip.empty? }
  if first_real && first_real.match?(ANCHOR)
    attrs = parse_anchor(first_real)
    path = attrs["path"]
    line_no = attrs["line"]&.to_i
    side = (attrs["side"] || "RIGHT").upcase
    abort "anchor missing path/line under heading: #{sec[:heading]}" if path.nil? || line_no.nil?

    # comment body = everything after the anchor line (heading dropped)
    idx = sec[:lines].index(first_real)
    body = sec[:lines][(idx + 1)..].join("\n").strip
    comments << {path: path, line: line_no, side: side, body: body}
  else
    # non-anchored section => part of the review body, heading preserved
    chunk = ([sec[:heading]] + clean_body_lines(sec[:lines])).join("\n").strip
    body_chunks << chunk unless chunk.empty?
    # gentle heuristic: a heading that looks like a file ref but has no anchor
    if sec[:heading].match?(/[\w\/.\-]+\.\w+(:\d+)?/) && !sec[:heading].match?(/blast radius|design note/i)
      warnings << "section looks like a finding but has no anchor (stays in body): #{sec[:heading]}"
    end
  end
end

body = body_chunks.reject(&:empty?).join("\n\n")

# --- validate comments against the diff --------------------------------------

problems = []
comments.each do |c|
  next unless c[:side] == "RIGHT" # LEFT-side validation not modeled here
  unless commentable.key?(c[:path])
    problems << "#{c[:path]}:#{c[:line]} — file not in PR diff"
    next
  end
  unless commentable[c[:path]].include?(c[:line])
    near = commentable[c[:path]].to_a.sort.select { |n| (n - c[:line]).abs <= 6 }
    hint = near.empty? ? "" : " (nearest commentable: #{near.join(', ')})"
    problems << "#{c[:path]}:#{c[:line]} — line not in diff#{hint}"
  end
end

# --- preview -----------------------------------------------------------------

puts "Repo:    #{repo}"
puts "PR:      ##{pr_number} #{pr_title}"
puts "Commit:  #{commit_id[0, 12]}"
puts "Event:   #{event}"
puts "Comments:#{comments.size}  Body:#{body.length} chars"
puts
comments.each { |c| puts "  • #{c[:path]}:#{c[:line]} #{c[:side]}  (#{c[:body].length} chars)" }
unless warnings.empty?
  puts
  warnings.each { |w| puts "  ! #{w}" }
end
unless problems.empty?
  puts
  puts "BLOCKING — these comments won't anchor and would 422 the whole review:"
  problems.each { |p| puts "  ✗ #{p}" }
  abort "\nFix the anchors above (or adjust the target lines) and re-run."
end

payload = {commit_id: commit_id, event: event, body: body, comments: comments}

unless do_post
  puts
  puts "DRY RUN — nothing sent. Re-run with --post to submit this review."
  exit 0
end

# --- post --------------------------------------------------------------------

api_path = "repos/#{repo}/pulls/#{pr_number}/reviews"
out, err, st = Open3.capture3(
  "gh", "api", "--method", "POST", api_path, "--input", "-",
  stdin_data: JSON.generate(payload)
)
unless st.success?
  warn out
  abort "POST failed:\n#{err}"
end
resp = JSON.parse(out) rescue {}
puts "Posted review #{resp['id']} (#{event}) with #{comments.size} inline comments → #{resp['html_url']}"
