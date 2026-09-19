#!/usr/bin/env ruby
# frozen_string_literal: true

# PreToolUse hook: `bq query` is the only permitted bq subcommand. Every other
# subcommand (ls, show, mk, rm, cp, load, extract, insert, update, the iam-policy
# family, ...) is denied, including inside a compound command or behind
# xargs / sh -c / bash -c / find -exec.
#
# A settings.json deny rule cannot express this: deny takes precedence over
# allow, so "Bash(bq:*)" would block `bq query` as well and no allow rule can
# carve it back out. Hence a hook.
#
# Fails closed: a bq invocation whose subcommand cannot be identified is denied.

require "json"

begin
  input = JSON.parse($stdin.read)
rescue StandardError
  exit 0
end

exit 0 unless input["tool_name"] == "Bash"

command = input.dig("tool_input", "command").to_s
exit 0 if command.empty?

# Every bq subcommand as of the current gcloud SDK. The first token from this
# set decides the subcommand, which tolerates space-separated global flags
# (`bq --project_id switch-prod query ...`) without treating the flag value as
# the subcommand.
SUBCOMMANDS = %w[
  add-iam-policy-binding cancel cp extract get-iam-policy head help init insert
  load ls mk mkdef partition query remove-iam-policy-binding rm set-iam-policy
  shell show truncate update version wait
].freeze

# `bq` at a command position: start of string, after a shell separator,
# immediately inside a quote (covers `sh -c "bq ls"`), or as the command handed
# to xargs / find -exec. Leading sudo / command / time / VAR=value are skipped.
BQ_AT_COMMAND_POSITION = %r{
  (?:
    \A | [;&|(){}`\n"'] | \$\(
    | (?:\bxargs\b|-exec)\s+(?:-\S+\s+)*
  )
  \s*
  (?:(?:sudo|command|time)\s+|\w+=\S+\s+)*
  (?<path>[\w./-]*\bbq)
  (?<rest>\s[^;&|(){}`\n]*|\z)
}x

offenders = []

command.scan(BQ_AT_COMMAND_POSITION) do
  match = Regexp.last_match
  path = match[:path]
  next unless path == "bq" || path.end_with?("/bq")

  tokens = match[:rest].to_s.split(/\s+/).reject(&:empty?)
  subcommand = tokens.map { |token| token.gsub(/\A['"]+|['"]+\z/, "") }
                     .find { |token| SUBCOMMANDS.include?(token) }
  offenders << (subcommand || "(none)") unless subcommand == "query"
end

exit 0 if offenders.empty?

reason = "Blocked by user policy: `bq` may only run the `query` subcommand. " \
         "This command uses #{offenders.uniq.join(', ')}. " \
         "Read BigQuery state with `bq query` instead (INFORMATION_SCHEMA covers most listing and metadata), " \
         "or surface the exact command and ask the user to run it."

puts JSON.generate(
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: reason
  }
)

exit 0
