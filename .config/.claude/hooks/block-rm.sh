#!/bin/bash
# PreToolUse hook: deny any Bash command that invokes `rm` or `rmdir`, including
# when buried inside a compound command (after &&, ||, ;, |, newline, subshell)
# or reached via xargs / sh -c / bash -c / find -exec.
#
# The settings.json deny list ("Bash(rm:*)") only matches `rm` as the LEADING
# command; this closes the compound-command gap that let an `rm -rf` slip past.
#
# Recoverable git deletions (`git rm`) are intentionally NOT blocked.

input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // empty')

# Only inspect Bash tool calls; everything else passes through.
[ "$tool" != "Bash" ] && exit 0

cmd=$(echo "$input" | jq -r '.tool_input.command // empty')

# Match rm/rmdir at a command position: start of line, after a separator
# (; | & ( ) { } ` newline), after && / ||, or as an argument to
# xargs / sh -c / bash -c / find -exec. \b keeps "charm", "form_rm" etc. safe.
if printf '%s' "$cmd" | grep -Eq '(^|[;&|`(){}]|&&|\|\||\bxargs\b|\bsh[[:space:]]+-c\b|\bbash[[:space:]]+-c\b|-exec[[:space:]]+)[[:space:]]*(sudo[[:space:]]+)?\brm(dir)?\b'; then
  jq -nc '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Blocked by user policy: this command invokes `rm`/`rmdir`, including inside a compound command. File/dir deletion must be done by the user or explicitly re-authorized — surface what would be deleted and ask first."
    }
  }'
  exit 0
fi

exit 0
