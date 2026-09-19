#!/bin/bash
# PreToolUse hook: deny a Bash command that would REPLACE the contents of a file that
# already exists — a heredoc truncating it, or a script calling File.write on it.
# Everything else about file handling is left to the auto-mode classifier rule in
# ~/.claude/settings.json (autoMode.soft_deny), which user intent can clear.
#
# Narrowed to clobbering because that is the failure this is actually about: a patch
# script rewrote a whole model from a string it built, the substitution missed, and the
# file was left syntactically broken with nothing raising. Edit anchors on exact text
# and fails loudly instead. Creating a file cannot destroy anything, and appending
# cannot either, so neither is blocked.
#
#   cat > app/models/x.rb <<'EOF' … EOF   blocked — truncates an existing file
#   ruby -e 'File.write("app/x.rb", s)'   blocked — same, from a script
#
#   cat > app/models/new.rb <<'EOF' … EOF allowed — creates, cannot clobber
#   cat >> CHANGELOG.md <<'EOF' … EOF     allowed — appends
#   sed -i '' 's/old/new/g' app/**/*.rb   allowed — strict find and replace
#   grep -rn foo app/ > findings.txt      allowed — exploration output
#   git commit -F - <<'MSG' … MSG         allowed — heredoc to stdin, no file target

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

ADVICE="Use Edit to change part of it, or Write to replace it — both act on the file the model has actually read, so a bad anchor fails instead of landing a half-rewritten file. Creating a new file this way, appending, sed -i find-and-replace, and redirection into new output are all still fine."

# Relative targets resolve against the project the hook was invoked for.
base="${CLAUDE_PROJECT_DIR:-$PWD}"

# The file exists and is not scratch, so writing over it destroys something.
clobbers_existing() {
  local t="$1" abs
  t=${t%\"}; t=${t#\"}; t=${t%\'}; t=${t#\'}

  case "$t" in
    ''|\&*|/dev/*) return 1 ;;
    "$TMPDIR"*|'$TMPDIR'*) return 1 ;;
    tmp/*|./tmp/*) return 1 ;;
    /tmp/claude-*|/private/tmp/claude-*) return 1 ;;
    /*) abs="$t" ;;
    '~'/*) abs="$HOME/${t#\~/}" ;;
    # Both candidate bases, because a relative path that resolves under neither is
    # a new file, but one that resolves under either is a file being replaced.
    *) [ -f "$base/$t" ] || [ -f "$PWD/$t" ]; return ;;
  esac

  [ -f "$abs" ]
}

# Hash rockets and arrows are not redirections, so `ruby -e 'h = {a => 1}'` must not
# read as a write to `1`.
scan=$(printf '%s' "$cmd" | sed -e 's/=>/__ROCKET__/g' -e 's/->/__ARROW__/g')

# --- a heredoc truncating an existing file --------------------------------
# Only `>` and `tee` without -a truncate. `>>` and `tee -a` append, and a heredoc
# fed to a command's stdin (git commit -F -, bash <<EOF) has no file to harm.
if printf '%s' "$scan" | grep -Eq '<<-?[[:space:]]*[A-Za-z_'"'"'"]'; then
  while IFS= read -r target; do
    [ -z "$target" ] && continue
    clobbers_existing "$target" || continue
    deny "Blocked by user policy (~/.claude/CLAUDE.md): this replaces the contents of \`$target\`, which already exists, with a heredoc. $ADVICE"
  done < <(printf '%s' "$scan" | grep -oE '(^|[^0-9>])>[[:space:]]*[^[:space:];&|)>]+' | sed -E 's/^[^>]*>[[:space:]]*//')

  while IFS= read -r target; do
    [ -z "$target" ] && continue
    clobbers_existing "$target" || continue
    deny "Blocked by user policy (~/.claude/CLAUDE.md): this tees a heredoc over \`$target\`, which already exists. $ADVICE"
  done < <(printf '%s' "$scan" | grep -oE '\btee[[:space:]]+[^[:space:];&|)-][^[:space:];&|)]*' | sed -E 's/^tee[[:space:]]+//')
fi

# --- a script truncating an existing file ---------------------------------
# File.write and IO.write always truncate; File.open is only a hazard in "w" mode.
while IFS= read -r target; do
  [ -z "$target" ] && continue
  clobbers_existing "$target" || continue
  deny "Blocked by user policy (~/.claude/CLAUDE.md): this script rewrites \`$target\`, which already exists, from a string it builds. $ADVICE"
done < <(
  {
    printf '%s' "$cmd" |
      grep -oE '(File\.write|IO\.write)[[:space:]]*\([[:space:]]*["'"'"'][^"'"'"']+' |
      sed -E 's/^(File\.write|IO\.write)[[:space:]]*\([[:space:]]*["'"'"']//'
    printf '%s' "$cmd" |
      grep -oE 'File\.open[[:space:]]*\([[:space:]]*["'"'"'][^"'"'"']+["'"'"'][[:space:]]*,[[:space:]]*["'"'"']w' |
      sed -E 's/^File\.open[[:space:]]*\([[:space:]]*["'"'"']//; s/["'"'"'][[:space:]]*,[[:space:]]*["'"'"']w$//'
  }
)

exit 0
