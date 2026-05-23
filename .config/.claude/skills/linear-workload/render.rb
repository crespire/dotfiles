#!/usr/bin/env ruby
# Render the Linear workload summary as markdown.
#
# Usage:
#   ruby render.rb <input.json> [--mode=inline|obsidian] [--date=YYYY-MM-DD]
#
# Input is the compact JSON array of outstanding issues produced by skill.md step 1.
# Each issue must have: id, title, url, priority (int 0-4), status, statusType,
# updatedAt (ISO8601), project, team, team_key.
#
# --mode=inline (default) emits H1 + H2 sections; suitable as a top-level chat reply.
# --mode=obsidian shifts every heading one level deeper so the summary nests cleanly
# under the weekly note's existing structure.
#
# --date defaults to today UTC. Pass an explicit date for the obsidian path so the
# heading reads as the Monday date, not the day the script was run.

require "json"
require "time"

input_path = ARGV.find { |a| !a.start_with?("--") }
abort "usage: render.rb <input.json> [--mode=inline|obsidian] [--date=YYYY-MM-DD]" unless input_path

mode = ARGV.find { |a| a.start_with?("--mode=") }&.split("=", 2)&.last || "inline"
abort "--mode must be inline or obsidian" unless %w[inline obsidian].include?(mode)

date_arg = ARGV.find { |a| a.start_with?("--date=") }&.split("=", 2)&.last
ref_date = date_arg ? Time.parse(date_arg).utc : Time.now.utc

TEAM_PRIORITY = {"CS" => 0, "ENG" => 1}.freeze
TYPE_ORDER = {"started" => 0, "unstarted" => 1, "triage" => 2, "backlog" => 3}.freeze
PRIORITY_EMOJI = {1 => "🔴", 2 => "🟠", 3 => "🟡", 4 => "🟢", 0 => "⚪"}.freeze
PRIORITY_WEIGHT = {1 => 4, 2 => 3, 3 => 2, 4 => 1, 0 => 1}.freeze

def stale_days(issue, now)
  ((now - Time.parse(issue["updatedAt"])) / 86_400).floor
end

def relative_time(updated, now)
  hours = (now - Time.parse(updated)) / 3600.0
  return "today" if hours < 24
  "#{(hours / 24).round}d ago"
end

def slipping?(issue)
  p, s, t = issue["priority"], issue["stale_days"], issue["statusType"]
  (p && p.between?(1, 2) && s >= 30) ||
    (p == 3 && s >= 90) ||
    (t == "started" && s >= 14) ||
    (t == "triage" && s >= 7)
end

issues = JSON.parse(File.read(input_path))
issues.each { |i| i["stale_days"] = stale_days(i, ref_date) }

slipping = issues.select { |i| slipping?(i) && i["team_key"] != "ENG" }
                 .sort_by { |i| -PRIORITY_WEIGHT[i["priority"]] * [i["stale_days"], 365].min }

teams = issues.map { |i| i["team_key"] }.uniq.sort
date_str = ref_date.strftime("%Y-%m-%d")

# Heading levels shift in obsidian mode so the summary nests cleanly under the weekly note.
h1, h2, h3 = (mode == "obsidian" ? %w[## ### ####] : %w[# ## ###])
title = mode == "obsidian" ? "Linear Workload — #{date_str}" : "My Linear Workload — #{date_str}"

out = []
out << "#{h1} #{title}"
out << ""
out << "**#{issues.length} outstanding issues across #{teams.length} teams (#{teams.join(", ")})**"
out << ""

if slipping.any?
  out << "#{h2} ⚠️ Slipping (#{slipping.length})"
  out << ""
  slipping.first(15).each do |i|
    e = PRIORITY_EMOJI[i["priority"]]
    out << "- #{e} [#{i["id"]}](#{i["url"]}) #{i["title"]} — #{i["team_key"]} · #{i["status"]} · **#{i["stale_days"]}d cold**"
  end
  if slipping.length < 5
    out << ""
    out << "Backlog hygiene is healthy ✅"
  end
  out << ""
end

issues.group_by { |i| i["team_key"] }
      .sort_by { |k, _| [TEAM_PRIORITY[k] || 99, k] }
      .each do |team_key, team_issues|
  team_name = team_issues.first["team"]
  out << "#{h2} #{team_key} — #{team_name} (#{team_issues.length})"
  out << ""
  team_issues.group_by { |i| i["status"] }
             .sort_by { |s, list| [TYPE_ORDER[list.first["statusType"]] || 99, s] }
             .each do |status, list|
    out << "#{h3} #{status} (#{list.length})"
    list.sort_by { |i| [(i["priority"] == 0 ? 99 : i["priority"]), -Time.parse(i["updatedAt"]).to_i] }
        .each do |i|
      e = PRIORITY_EMOJI[i["priority"]]
      proj = i["project"].nil? || i["project"].to_s.empty? ? "—" : i["project"]
      out << "- #{e} [#{i["id"]}](#{i["url"]}) #{i["title"]} — #{proj} · updated #{relative_time(i["updatedAt"], ref_date)}"
    end
    out << ""
  end
end

urgent = issues.select { |i| i["priority"] == 1 }
busiest_team, busiest_count = issues.group_by { |i| i["team_key"] }
                                    .map { |k, v| [k, v.length] }
                                    .max_by { |_, c| c }
oldest_high = slipping.select { |i| i["priority"] && i["priority"].between?(1, 2) }
                      .max_by { |i| i["stale_days"] }

out << "#{h2} Highlights"
out << (urgent.any? ? "- 🔴 **#{urgent.length} urgent**: #{urgent.map { |i| i["id"] }.join(", ")}" : "- No urgent items.")
out << "- 📊 Heaviest load: **#{busiest_team}** with #{busiest_count} issues."
if oldest_high
  out << "- ⏳ Oldest slipping High-priority: [#{oldest_high["id"]}](#{oldest_high["url"]}) at **#{oldest_high["stale_days"]}d cold** — review priority or close."
end

puts out.join("\n")
