#!/usr/bin/env ruby
# frozen_string_literal: true

# Mutation runner. Applies one deliberate breakage at a time to working code, runs the specs
# that ought to catch it, restores the file, and records whether the specs noticed.
#
# A mutant that leaves the suite green ("SURVIVED") is a claim nothing tests. It is either a
# coverage gap or an equivalent mutant, and the difference has to be argued, not assumed.
#
#   ruby ~/.claude/scripts/mutate.rb tmp/mutants/<work>/table.rb
#   ruby ~/.claude/scripts/mutate.rb tmp/mutants/<work>/table.rb --only M07
#   ruby ~/.claude/scripts/mutate.rb tmp/mutants/<work>/table.rb --check     # anchors only, no specs
#   ruby ~/.claude/scripts/mutate.rb tmp/mutants/<work>/table.rb --report    # rebuild the summary, run nothing
#   ruby ~/.claude/scripts/mutate.rb tmp/mutants/<work>/table.rb --clean     # drop scratch, keep the reproducible set
#
# Convention: each piece of work gets its own folder, ./tmp/mutants/<work>/, where <work> names
# the change (a Linear ref or PR descriptor, e.g. eng-1771-retry-budget). The runner writes every
# output next to the table, so separate folders keep separate ledgers and pristine copies:
#
#   tmp/mutants/<work>/table.rb            the mutant table (the input; the artifact worth keeping)
#   tmp/mutants/<work>/table.ledger.json   machine-readable results, merged across runs
#   tmp/mutants/<work>/mutations.md        the human write-up, regenerated from the ledger
#   tmp/mutants/<work>/pristine/           byte copies of each target before its first mutation (scratch)
#
# A table directly in tmp/mutants/ is refused: that shared folder is where runs overwrote each
# other's ledgers and pristine copies.
#
# Separate folders do not isolate the code. Every run mutates the checkout in place, so a second
# run in the same checkout loads the first run's mutants and reports garbage, and can capture a
# mutated file as its "pristine" copy. A mutating run therefore holds tmp/mutants/.run.lock for
# the checkout. To run two at once, run each in its own worktree.
#
# The table file is Ruby whose last expression is a Hash:
#
#   {
#     specs: %w[spec/jobs/some_job_spec.rb],
#     mutants: [
#       {id: "M01", label: "horizon boundary <= to <",
#        failure_mode: "drops the slot landing exactly on the horizon",
#        file: "app/jobs/some_job.rb", from: "slot <= horizon", to: "slot < horizon"},
#       {id: "M11", label: "pipeline id filter removed", equivalent: "the bucket key is the job's own
#        pipeline id, so dropping the filter only adds unread keys", ...}
#     ]
#   }
#
# Keys: id, label, file, from, to are required. Optional: failure_mode (prose, printed with the
# result), specs (overrides the table default), all (gsub instead of sub), equivalent (a proof
# string; a survivor is then expected rather than reported as a gap).

require "json"
require "fileutils"
require "digest"

# Every file we have touched, mapped to its pristine body, so a trap can put everything back.
PRISTINE = {}

def restore_all
  PRISTINE.each do |path, body|
    next unless File.exist?(path)
    next if File.read(path) == body

    File.write(path, body)
    # Bootsnap keys its bytecode cache on mtime, so a programmatic revert needs a touch or the
    # next process loads the mutated source.
    FileUtils.touch(path)
  end
end

["INT", "TERM"].each do |signal|
  Signal.trap(signal) do
    restore_all
    warn "\nInterrupted. All targets restored."
    exit 130
  end
end
at_exit { restore_all }

def load_table(path)
  table = eval(File.read(path), TOPLEVEL_BINDING, path) # rubocop:disable Security/Eval
  raise "#{path} must evaluate to a Hash with a :mutants key" unless table.is_a?(Hash) && table[:mutants]

  table
end

def validate!(mutants, default_specs)
  seen = {}
  mutants.each_with_index do |m, i|
    missing = [:id, :label, :file, :from, :to].reject { |k| m.key?(k) }
    raise "mutant ##{i + 1} is missing #{missing.join(", ")}" if missing.any?
    raise "duplicate mutant id #{m[:id]}" if seen[m[:id]]
    raise "mutant #{m[:id]} has no specs and the table sets no default" if Array(m[:specs] || default_specs).empty?

    seen[m[:id]] = true
  end
end

# Anchor drift is cheap to detect and expensive to discover forty minutes into a run, so every
# anchor is checked against the tree before the first spec executes.
def preflight(mutants, default_specs)
  problems = []
  mutants.each do |m|
    unless File.exist?(m[:file])
      problems << [m, "file does not exist"]
      next
    end

    count = File.read(m[:file]).scan(m[:from]).size
    if count.zero?
      problems << [m, "anchor not found"]
    elsif count > 1 && !m[:all]
      # sub would silently mutate the first occurrence, which may not be the line you meant.
      problems << [m, "anchor matches #{count}x (set all: true to mutate every one)"]
    end

    Array(m[:specs] || default_specs).each do |spec|
      problems << [m, "spec path does not exist: #{spec}"] unless File.exist?(spec.split("[").first.to_s)
    end
  end
  problems
end

def run_specs(specs, command, timeout_s, timeout_bin)
  prefix = timeout_bin ? "#{timeout_bin} #{timeout_s} " : ""
  output = `#{prefix}#{command} #{specs.join(" ")} 2>&1`
  [output, $?.exitstatus]
end

# Order matters. A suite that failed to load reports zero examples and a nonzero exit status,
# which reads as a kill on exit status alone and as a survivor on a naive failure count. It is
# neither: the mutant was never actually exercised.
def classify(output, exit_status, timeout_s)
  return ["INVALID", "timed out after #{timeout_s}s"] if exit_status == 124

  summary = output[/^\d+ examples?, \d+ failures?.*$/]
  return ["INVALID", "no rspec summary — the suite did not load"] if summary.nil?

  examples = summary[/\A(\d+) examples?/, 1].to_i
  failures = summary[/(\d+) failures?/, 1].to_i
  return ["INVALID", summary] if examples.zero? || summary.include?("outside of examples")
  return ["killed", summary] if failures.positive?

  ["SURVIVED", summary]
end

def caught_by(output)
  output.scan(/^rspec \S+ # (.+)$/).flatten.uniq
end

def git_context
  branch = `git rev-parse --abbrev-ref HEAD 2>/dev/null`.strip
  sha = `git rev-parse --short HEAD 2>/dev/null`.strip
  dirty = !`git status --porcelain 2>/dev/null`.strip.empty?
  return nil if branch.empty?

  "`#{branch}` at `#{sha}`#{dirty ? " (working tree has uncommitted changes)" : ""}"
end

# The write-up is regenerated from the ledger on every run, so it never drifts from the results.
# The triage prose is the part a person owns: the runner leaves a marked placeholder for each
# survivor rather than inventing a verdict.
def write_summary(path, table_path, rows, command, timeout_s)
  by_status = rows.group_by { |r| r["status"] }
  targets = rows.filter_map { |r| r["file"] }.uniq.sort
  out = +"# Mutation testing — #{File.basename(Dir.pwd)}\n\n"
  out << "Generated #{Time.now.utc.strftime("%Y-%m-%d %H:%M UTC")} by `mutate.rb` from `#{table_path}`.\n"
  ctx = git_context
  out << "Branch: #{ctx}\n" if ctx
  out << "\nNo mutation gem is installed here. Each mutant is a single deliberate edit that stands\n"
  out << "for a named failure mode. A mutant that turns the suite red is killed. One that leaves it\n"
  out << "green survived, which means the suite does not pin that behavior.\n\n"
  out << "Targets:\n"
  targets.each { |t| out << "- `#{t}`\n" }
  out << "\nRunner: `#{command}`, #{timeout_s}s timeout per mutant.\n\n"
  out << "## Result\n\n"
  out << "#{rows.size} mutants. " << by_status.map { |k, v| "#{v.size} #{k}" }.join(", ") << ".\n\n"

  if by_status["killed"]&.any?
    out << "## Killed\n\n| Mutant | Failure mode it stands for |\n|---|---|\n"
    by_status["killed"].each do |r|
      out << "| #{r["id"]} #{r["label"]} | #{r["failure_mode"] || "—"} |\n"
    end
    out << "\n"
  end

  if by_status["SURVIVED"]&.any?
    out << "## Survivors\n\n"
    out << "Each one is a genuine coverage gap or an equivalent mutant. Decide which, and record the\n"
    out << "argument — an unexplained survivor is worth nothing on the next run.\n\n"
    by_status["SURVIVED"].each do |r|
      out << "### #{r["id"]} — #{r["label"]}\n\n"
      out << "Stands for: #{r["failure_mode"]}\n\n" if r["failure_mode"]
      out << "<!-- TRIAGE: gap or equivalent? If a gap, name the spec that now closes it and re-run.\n"
      out << "     If equivalent, prove it — why can no test observe this change? Then move it into\n"
      out << "     the table as `equivalent:` so future runs stop reporting it. -->\n\n"
    end
  end

  if by_status["equivalent"]&.any?
    out << "## Equivalent mutants — not gaps\n\n"
    by_status["equivalent"].each do |r|
      out << "**#{r["id"]} #{r["label"]}.** #{r["equivalent"]}\n\n"
    end
  end

  refuted = rows.select { |r| r["status"].to_s.start_with?("CLAIM REFUTED") }
  if refuted.any?
    out << "## Equivalence claims refuted\n\n"
    out << "A spec killed a mutant the table declares unkillable. The proof is wrong, or the code moved.\n\n"
    refuted.each { |r| out << "- **#{r["id"]} #{r["label"]}** — claim was: #{r["equivalent"]}\n" }
    out << "\n"
  end

  stalled = rows.select { |r| ["INVALID", "NOT APPLIED"].include?(r["status"]) }
  if stalled.any?
    out << "## Never ran\n\n"
    out << "These are not results. Fix and re-run before trusting the tally above.\n\n"
    stalled.each { |r| out << "- **#{r["id"]} #{r["label"]}** — #{r["status"]}: #{r["detail"]}\n" }
    out << "\n"
  end

  out << "## Reproduce\n\n```\nruby ~/.claude/scripts/mutate.rb #{table_path}\n```\n\n"
  out << "`#{table_path}` is the input and the thing worth keeping. Scratch (`pristine/`) is removable\n"
  out << "with `--clean`.\n"
  File.write(path, out)
end

table_path = ARGV.find { |a| !a.start_with?("--") }
abort "usage: ruby #{File.basename(__FILE__)} <table.rb> [--only REGEX] [--check] [--report]" unless table_path
abort "no such table: #{table_path}" unless File.exist?(table_path)

only = ARGV.include?("--only") ? ARGV[ARGV.index("--only") + 1] : nil
check_only = ARGV.include?("--check")
report_only = ARGV.include?("--report")
skip_baseline = ARGV.include?("--no-baseline")
clean = ARGV.include?("--clean")

table = load_table(table_path)
default_specs = Array(table[:specs])
command = table[:command] || "bundle exec rspec"
timeout_s = (ARGV.include?("--timeout") ? ARGV[ARGV.index("--timeout") + 1] : table[:timeout] || 900).to_i

work_dir = File.dirname(table_path)
shared_root = File.expand_path("tmp/mutants")
if File.expand_path(work_dir) == shared_root
  abort "#{table_path} is in the shared folder #{shared_root}. Move it to tmp/mutants/<work>/table.rb, " \
        "where <work> names this change, so its ledger and pristine copies stay separate."
end
ledger_path = File.join(work_dir, "#{File.basename(table_path, ".rb")}.ledger.json")
backup_dir = File.join(work_dir, "pristine")
previous = File.exist?(ledger_path) ? JSON.parse(File.read(ledger_path)) : {}

summary_path = File.join(work_dir, "mutations.md")

if clean
  # Keep the reproducible set (table, ledger, write-up); drop the scratch. Refuse while any target
  # still differs from the pristine copy, because that copy is the only way back.
  if Dir.exist?(backup_dir)
    drifted = Dir.children(backup_dir).reject do |name|
      target = name.tr("%", "/")
      !File.exist?(target) || File.read(target) == File.read(File.join(backup_dir, name))
    end
    unless drifted.empty?
      warn "These targets differ from their pristine copies:"
      drifted.each { |n| warn "  #{n.tr("%", "/")}" }
      abort "Restore them first (the copies are in #{backup_dir}); refusing to delete the only backup."
    end
    FileUtils.rm_rf(backup_dir)
    puts "Removed #{backup_dir}."
  end
  kept = [table_path, ledger_path, summary_path].select { |f| File.exist?(f) }
  puts "Kept: #{kept.join(", ")}"
  exit 0
end

if report_only
  abort "no ledger yet at #{ledger_path}" if previous.empty?
  previous.each_value do |row|
    puts format("%-11s %-5s %s", row["status"], row["id"], row["label"])
    puts "              #{row["failure_mode"]}" if row["failure_mode"]
    puts "              equivalent: #{row["equivalent"]}" if row["equivalent"]
  end
  write_summary(summary_path, table_path, previous.values, command, timeout_s)
  puts "\nRewrote #{summary_path} from the ledger."
  exit 0
end

mutants = table[:mutants]
validate!(mutants, default_specs)
mutants = mutants.select { |m| "#{m[:id]} #{m[:label]}".match?(Regexp.new(only, Regexp::IGNORECASE)) } if only
abort "--only #{only} matched no mutants" if mutants.empty?

problems = preflight(mutants, default_specs)
unless problems.empty?
  warn "Preflight found #{problems.size} problem(s):"
  problems.each { |m, why| warn "  #{m[:id]}  #{why}" }
  abort "Fix the anchors before running. Nothing was mutated." unless check_only
end

if check_only
  puts "Preflight clean: #{mutants.size} anchors resolve uniquely." if problems.empty?
  exit(problems.empty? ? 0 : 1)
end

# The checkout is shared state, so only one mutating run may hold it. The kernel releases the
# flock when the process exits, even on a hard kill, so a stale lock file cannot block a later run.
FileUtils.mkdir_p(shared_root)
RUN_LOCK = File.open(File.join(shared_root, ".run.lock"), File::RDWR | File::CREAT)
unless RUN_LOCK.flock(File::LOCK_EX | File::LOCK_NB)
  holder = RUN_LOCK.read.strip
  abort "Another mutation run holds this checkout (#{holder.empty? ? "unknown table" : holder}). " \
        "Wait for it, or run this table in its own worktree."
end
RUN_LOCK.truncate(0)
RUN_LOCK.write("#{table_path} (pid #{Process.pid})")
RUN_LOCK.flush

timeout_bin = ["timeout", "gtimeout"].find { |b| system("command -v #{b} > /dev/null 2>&1") }
warn "No timeout binary found; specs will run unbounded." unless timeout_bin

# A red baseline makes every mutant a false kill, so prove the suite is green before breaking it.
unless skip_baseline
  baseline_specs = (default_specs + mutants.flat_map { |m| Array(m[:specs]) }).uniq
  warn "Baseline: #{command} over #{baseline_specs.size} spec path(s)..."
  output, status = run_specs(baseline_specs, command, timeout_s, timeout_bin)
  verdict, detail = classify(output, status, timeout_s)
  if verdict != "SURVIVED"
    warn output.lines.last(25).join
    abort "Baseline is not green (#{detail}). Every result would be meaningless. Fix the suite first."
  end
  warn "Baseline green (#{detail}).\n\n"
end

results = {}
mutants.each_with_index do |m, i|
  path = m[:file]
  original = File.read(path)

  unless PRISTINE.key?(path)
    PRISTINE[path] = original
    FileUtils.mkdir_p(backup_dir)
    File.write(File.join(backup_dir, path.tr("/", "%")), original)
  end

  specs = Array(m[:specs].nil? || m[:specs].empty? ? default_specs : m[:specs])
  mutated = m[:all] ? original.gsub(m[:from], m[:to]) : original.sub(m[:from], m[:to])

  if mutated == original
    results[m[:id]] = {"id" => m[:id], "label" => m[:label], "status" => "NOT APPLIED",
                       "detail" => "anchor drift"}
    warn format("  [%d/%d] %-11s %-5s %s", i + 1, mutants.size, "NOT APPLIED", m[:id], m[:label])
    next
  end

  status = nil
  detail = nil
  witnesses = []
  begin
    File.write(path, mutated)
    FileUtils.touch(path)
    output, exit_status = run_specs(specs, command, timeout_s, timeout_bin)
    status, detail = classify(output, exit_status, timeout_s)
    witnesses = caught_by(output).first(4)
  ensure
    File.write(path, original)
    FileUtils.touch(path)
    if File.read(path) != original
      abort "FAILED TO RESTORE #{path}. Pristine copy is in #{backup_dir}."
    end
  end

  if m[:equivalent]
    status = (status == "SURVIVED") ? "equivalent" : "CLAIM REFUTED (#{status})"
  end

  results[m[:id]] = {
    "id" => m[:id], "label" => m[:label], "file" => path,
    "failure_mode" => m[:failure_mode], "equivalent" => m[:equivalent],
    "status" => status, "detail" => detail, "caught_by" => witnesses,
    "ran_at" => Time.now.utc.iso8601
  }.compact

  warn format("  [%d/%d] %-11s %-5s %s  (%s)", i + 1, mutants.size, status, m[:id], m[:label], detail)
end

merged = previous.merge(results)
File.write(ledger_path, JSON.pretty_generate(merged))

puts "\n===== MUTATION REPORT ====="
results.each_value do |r|
  puts format("%-11s %-5s %s", r["status"], r["id"], r["label"])
  puts "              would mean: #{r["failure_mode"]}" if r["failure_mode"]
  Array(r["caught_by"]).each { |t| puts "              killed by: #{t}" }
end

transitions = results.filter_map do |id, r|
  was = previous.dig(id, "status")
  next if was.nil? || was == r["status"]

  "#{id}  #{was} -> #{r["status"]}"
end
unless transitions.empty?
  puts "\n----- CHANGED SINCE LAST RUN -----"
  transitions.each { |t| puts "  #{t}" }
end

write_summary(summary_path, table_path, merged.values, command, timeout_s)

tally = results.each_value.group_by { |r| r["status"] }.transform_values(&:size)
puts "\n#{tally.map { |k, v| "#{v} #{k}" }.join(", ")}"
puts "Ledger:  #{ledger_path}"
puts "Summary: #{summary_path}"

gaps = results.each_value.select { |r| r["status"] == "SURVIVED" }
refuted = results.each_value.select { |r| r["status"].to_s.start_with?("CLAIM REFUTED") }
invalid = results.each_value.select { |r| ["INVALID", "NOT APPLIED"].include?(r["status"]) }

unless invalid.empty?
  puts "\n#{invalid.size} mutant(s) never ran. Those are not results — fix them and re-run:"
  invalid.each { |r| puts "  #{r["id"]}  #{r["detail"]}" }
end
unless refuted.empty?
  puts "\n#{refuted.size} equivalence claim(s) refuted — a spec killed a mutant declared unkillable:"
  refuted.each { |r| puts "  #{r["id"]}  #{r["equivalent"]}" }
end
if gaps.empty?
  puts "\nNo survivors."
else
  puts "\n#{gaps.size} SURVIVOR(S) — each is a coverage gap or an equivalent mutant. Decide which, and say why:"
  gaps.each { |r| puts "  #{r["id"]}  #{r["label"]}" }
end

exit(gaps.empty? && refuted.empty? && invalid.empty? ? 0 : 1)
