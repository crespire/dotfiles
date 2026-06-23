---
name: code-review
description: Review the current changes and provide feedback.
---

Use the code-reviewer agent if available and review the current branch:

$ARGUMENTS

When reviewing:
1. Reference the CLAUDE.md and any supplementary documentation available.
2. Examine code execution paths, architecture and design patterns for consistency with the existing codebase.
3. For any changes in behaviour, ensure that changes are put under test in a concrete and effective way. It is also usually a good idea to put in regression testing at the integration level where appropriate.
4. For any suggestions in the code, provide supporting documentation as to why the change should be made, whether it's Ruby/Rails best practice, or some example in the codebase.
5. Remember that repositories have supporting tooling like Sorbet and Rubocop to help enforce style and convention.

After review, always present the results to the user for discussion. Do not start making edits right away.

## Output: write the artifact only for branches you don't own

First decide whose branch this is — it determines whether to write a file at all:

- **Your own branch / a self-review** — the commits under review are authored by the current git user (`git log` author matches `git config user.email`), or you've been working this branch yourself in-session. **Do NOT write `tmp/pr_review.md`.** There's nothing to post to GitHub, so the artifact is just noise — present the findings inline in the conversation for discussion and we'll act on them directly.
- **Someone else's branch / PR** — you're reviewing work you didn't author, to post comments back. Capture the review as **anchored markdown** in `tmp/pr_review.md` (create `tmp/` if needed) so `~/.claude/scripts/post-review.rb` can convert it into a single GitHub review with line-anchored inline comments. This is a working draft — `tmp/` gets wiped periodically — not the system of record.

When it's genuinely ambiguous who owns the branch, ask before writing the file.

Either way, follow the PR-review voice/length rules in `~/.claude/CLAUDE.md` (conversational, 1–3 sentences per inline, no severity tags or headlines, backticks on identifiers).

When you do write the artifact, the contract the poster script parses:

- **Event metadata** at the top: `<!-- review event=REQUEST_CHANGES -->` (CHANGES_REQUESTED for blockers, COMMENT otherwise). A `**State: ...**` line also works.
- **Review body** = the preamble prose before the first heading, plus any heading-section that has *no* anchor. Put the signpost-and-triage summary here, along with genuinely cross-cutting / multi-file notes (architectural framing, "looks good", non-blocking follow-ups) that don't belong on one line.
- **Inline comments** = each heading-section whose first non-blank line is an anchor. The `###` heading is organizational only (dropped from the posted comment); the prose under the anchor is the comment body. `side` defaults to `RIGHT`.

```markdown
<!-- review event=REQUEST_CHANGES -->
# Review — <branch>

<signpost-and-triage summary: name the blockers, calibrate the rest>

### MIN_BASELINE_DAYS
<!-- review path=app/models/issues/destination_low_deliveries.rb line=15 side=RIGHT -->
The comment calls this "too new", but `raw_baseline_days` measures active days...

### A cross-cutting design note
This section has no anchor, so it stays in the review body.
```

Anchor each inline finding to a line that's actually in the diff — the script validates this and will refuse to post otherwise.

## Posting (only when the user asks)

Never post automatically — present for discussion first. When the user asks to push the review up:

```
ruby ~/.claude/scripts/post-review.rb tmp/pr_review.md          # dry run: parse, validate, preview
ruby ~/.claude/scripts/post-review.rb tmp/pr_review.md --post   # actually submit
```

The dry run resolves the PR + head commit via `gh`, validates every comment against the diff, and previews the body + inline comments. Run it first, surface any anchor problems, then post with `--post` once the user confirms. Pass `--pr N` to target a specific PR. If the script is missing (fresh repo, wiped `tmp`, new machine), rebuild it from this contract — it shells out to `gh api .../pulls/{n}/reviews`.
