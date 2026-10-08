#!/bin/bash
# PreToolUse hook: deny the items on the "Never do these" list in ~/.claude/CLAUDE.md
# that nothing else enforces. That list is explicitly "no judgment call, no exceptions",
# which makes it the wrong thing to leave to the model's memory of a file it read once
# at session start — a harness reminder injected later in the turn outranks it in
# practice.
#
# Covers: force push, a push to a branch the user does not own, scratch written to
# /tmp instead of ./tmp, and Python.
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

# --- push to a branch the user doesn't own ---------------------------------
# A target branch counts as owned when the first matching check says so:
#   1. The user owns the repository (personal repos, such as these dotfiles).
#   2. An open PR has the branch as its head: the user must be its author.
#   3. No open PR: the branch must not be the default branch, and must be new on
#      the remote or carry only the user's commits past the default branch.
# The hook denies anything it can't resolve (a `cd` before the push, a gh error).
# It is a guardrail, so it fails closed.
ME=crespire

push_denied() {
  deny "Blocked by user policy (~/.claude/CLAUDE.md): push only to a branch the user owns. $1 Stop and report it to the user; they push it themselves if it is intended."
}

check_push_ownership() {
  local seg="git${1#*git}" cwd dir=. words args=() after_push=false i=1 w
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
  read -ra words <<<"$seg"

  while (( i < ${#words[@]} )); do
    w=${words[i]}
    if ! $after_push; then
      case $w in
        -C) dir=${words[i+1]/#\~/$HOME}; i=$((i + 2)); continue ;;
        -c) i=$((i + 2)); continue ;;
        push) after_push=true ;;
      esac
    else
      # Redirections such as 2>&1 leak in as words, since the segment stops at &.
      case $w in -*|*[\<\>]*) ;; *) args+=("$w") ;; esac
    fi
    i=$((i + 1))
  done

  local repo
  repo=$(git -C "$cwd" -C "$dir" rev-parse --show-toplevel 2>/dev/null) ||
    push_denied "Could not find the git repository for \`$seg\`."
  ghr() { (cd "$repo" && gh "$@"); }

  local owner default
  read -r owner default < <(ghr repo view --json owner,defaultBranchRef \
    --jq '.owner.login + " " + .defaultBranchRef.name' 2>/dev/null)
  [ -z "$owner" ] && push_denied "Could not read the repository owner with gh."
  [ "$owner" = "$ME" ] && return

  local refspecs=("${args[@]:1}") ref branch pr_author authors
  [ ${#refspecs[@]} -eq 0 ] && refspecs=(HEAD)
  for ref in "${refspecs[@]}"; do
    branch=${ref##*:}
    [ "$branch" = HEAD ] && branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD)
    branch=${branch#refs/heads/}

    pr_author=$(ghr pr list --head "$branch" --state open --json author \
      --jq '.[0].author.login // ""' 2>/dev/null) ||
      push_denied "Could not look up an open PR for \`$branch\` with gh."
    if [ -n "$pr_author" ]; then
      [ "$pr_author" = "$ME" ] && continue
      push_denied "The open PR for \`$branch\` belongs to $pr_author."
    fi

    [ "$branch" = "$default" ] &&
      push_denied "\`$branch\` is the default branch of a repository owned by $owner."

    if ! authors=$(ghr api "repos/{owner}/{repo}/compare/$default...$branch" \
      --jq '[.commits[].author.login // "an unlinked author"] | unique | join(", ")' 2>&1); then
      # 404: the branch doesn't exist on the remote yet, so this push creates it.
      grep -q 'HTTP 404' <<<"$authors" && continue
      push_denied "Could not compare \`$branch\` with \`$default\` with gh."
    fi
    [ -z "$authors" ] || [ "$authors" = "$ME" ] && continue
    push_denied "\`$branch\` has no open PR and carries commits by $authors."
  done
}

push_segments=$(printf '%s' "$cmd" | grep -oE "${POS}git[^;&|]*[[:space:]]push([[:space:]][^;&|]*)?")
if [ -n "$push_segments" ]; then
  printf '%s' "$cmd" | grep -Eq "${POS}cd([[:space:]]|$)" &&
    push_denied "A \`cd\` before the push hides which repository it targets. Use \`git -C <dir> push\` instead."
  while IFS= read -r seg; do
    check_push_ownership "$seg"
  done <<<"$push_segments"
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
