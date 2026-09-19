#!/bin/bash
# PostToolUse hook: warn when a newly written comment narrates the code's history.
# ~/.claude/CLAUDE.md asks for comments that carry why and resulting behaviour, and
# rules out change history — "previously X, now Y" belongs in the commit.
#
# Advisory: the edit stands and the turn continues. The warning goes back through
# additionalContext, the same channel the rails-verify reminder uses, because a rule
# restated inside the turn is the one that actually gets applied.
#
# The tells are past tense and contrast, which is what separates narration from a
# forward-looking why. False positives are expected and are the right trade for a
# warning that costs nothing to dismiss.

input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // empty')

case "$tool" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

# Edit carries new_string, Write carries content, and MultiEdit carries neither —
# its replacements are per-entry under edits[]. All three are gathered so a payload
# shape cannot make the hook silently inert.
added=$(echo "$input" | jq -r '
  [ .tool_input.new_string?, .tool_input.content?, (.tool_input.edits[]?.new_string) ]
  | map(select(. != null and . != ""))
  | join("\n")
')
[ -z "$added" ] && exit 0

# Two passes, because a comment is either the whole line or the tail of one.
#
# The tail pass keeps ONLY the comment portion, so a tell in surrounding code cannot
# trip it — `x = previously_known # fine` has no tell inside its comment. It also
# needs whitespace before the marker, which is what keeps Ruby interpolation
# (`"a #{b}"`, excluded by the [^{]) and URLs (`https://…`, no space before //) out.
full=$(printf '%s' "$added" | grep -E '^[[:space:]]*(#|//|<%#|/\*|\*)' || true)
tail=$(printf '%s' "$added" | grep -oE '[[:space:]](#[^{]|//).*$' || true)
comments=$(printf '%s\n%s' "$full" "$tail")
[ -z "$(printf '%s' "$comments" | tr -d '[:space:]')" ] && exit 0

TELLS='previously|used to|no longer|formerly|instead of|before this|this change|has been|had been|still [a-z]+ed|we (changed|removed|added|fixed|used)|\b(asked|issued|queried|re-?queried|loaded|fetched|walked|discarded|duplicated)\b'

hits=$(printf '%s' "$comments" | grep -iE "$TELLS" | sed '/^[[:space:]]*$/d' | head -3 || true)
[ -z "$hits" ] && exit 0

path=$(echo "$input" | jq -r '.tool_input.file_path // "the file just written"')

jq -nc --arg path "$path" --arg hits "$hits" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ("Comment check on \($path) — these lines read as change history rather than as why:\n\n\($hits)\n\nCLAUDE.md: state the why and the resulting behaviour, not the code'"'"'s history; narration belongs in the commit or PR. The test: would this sentence read the same to someone who never saw the earlier version? If it only makes sense as a contrast with what was there, cut it. Ignore this if the history IS the why (\"we do not use Tempfile.create here because it leaked on the early-return path\").")
  }
}'

exit 0
