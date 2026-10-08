#!/bin/bash
# PreToolUse hook: deny the items on the "Never do these" list in ~/.claude/CLAUDE.md
# that nothing else enforces. That list is explicitly "no judgment call, no exceptions",
# which makes it the wrong thing to leave to the model's memory of a file it read once
# at session start — a harness reminder injected later in the turn outranks it in
# practice.
#
# Covers: force push, scratch written to /tmp instead of ./tmp, and Python.
#
# The settings.json deny list matches only the LEADING command, so this closes the
# compound-command gap the same way block-rm.sh does.

input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // empty')

[ "$tool" != "Bash" ] && exit 0

cmd=$(echo "$input" | jq -r '.tool_input.command // empty')

deny() {
  jq -nc --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# A command position: start, after a separator, or as the argument of a wrapper.
POS='(^|[;&|`(){}]|&&|\|\||\bxargs\b|\bsh[[:space:]]+-c\b|\bbash[[:space:]]+-c\b|-exec[[:space:]]+)[[:space:]]*(sudo[[:space:]]+|env[[:space:]]+|timeout[[:space:]]+[^[:space:]]+[[:space:]]+)*'

# --- force push -----------------------------------------------------------
# A normal push is allowed. [^;&|]* keeps each match inside one segment, so global
# flags (-c, -C) are covered without letting a later segment's `push` attach to an
# earlier `git`. The flag check then runs only on the push segments themselves.
# A short-flag cluster counts when it contains f (-f, -uf).
FORCE='(^|[[:space:]])(--force([-=][^[:space:]]*)?|--mirror|-[a-zA-Z]*f[a-zA-Z]*|\+[^[:space:]]+)([[:space:]]|$)'
if printf '%s' "$cmd" | grep -oE "${POS}git[^;&|]*[[:space:]]push([[:space:]][^;&|]*)?" |
   grep -Eq "$FORCE"; then
  deny "Blocked by user policy (~/.claude/CLAUDE.md): never force-push (--force, -f, --force-with-lease, --force-if-includes, --mirror, or a + refspec). A normal push is fine. If the remote rejects a normal push as non-fast-forward, stop and report it to the user."
fi

# --- scratch files in /tmp ------------------------------------------------
# The harness scratchpad (/tmp/claude-*, /private/tmp/claude-*) is exempt: it is
# assigned per session rather than chosen, and is not the ad-hoc scratch the rule
# is about. Everything else under /tmp is denied in a writing context only, so
# reading a path someone else created still works.
#
# BSD grep has no -P, so the scratchpad carve-out is a second pass over the
# extracted paths rather than a negative lookahead.
# The leading boundary matters: ./tmp/ — the directory the rule steers toward —
# contains /tmp/ as a substring.
ABS_TMP='(^|[[:space:]"'"'"'=])/(private/)?tmp/'
if printf '%s' "$cmd" | grep -Eq "(>>?[[:space:]]*|\b(tee|cp|mv|touch|mkdir|install)\b[^;&|]*|File\.write|IO\.write|File\.open)[^;&|]*${ABS_TMP}"; then
  while IFS= read -r p; do
    p=${p#"${p%%/*}"}
    [ -z "$p" ] && continue
    printf '%s' "$p" | grep -Eq '^/(private/)?tmp/claude-' && continue
    deny "Blocked by user policy (~/.claude/CLAUDE.md): never write to /tmp — use ./tmp (mkdir -p ./tmp) so scratch stays visible in the workspace. This command writes to \`$p\`. The per-session scratchpad under /tmp/claude-* is exempt."
  done < <(printf '%s' "$cmd" | grep -oE "${ABS_TMP}[^[:space:];&|\")']*")
fi

# --- Python ---------------------------------------------------------------
# Scripts are Ruby here. Node and npm are deliberately NOT blocked — the project
# builds its assets with esbuild and tailwind.
if printf '%s' "$cmd" | grep -Eq "${POS}(python[0-9.]*|pip[0-9.]*|pipx|poetry)([[:space:]]|$)" ||
   printf '%s' "$cmd" | grep -Eq "${POS}[^[:space:];&|]*\.py([[:space:]]|$)"; then
  deny "Blocked by user policy (~/.claude/CLAUDE.md): never use python/python3 in Bash. Write scripts in Ruby (\`ruby -e\`), or use jq and shell tools."
fi

exit 0
