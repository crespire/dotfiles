---
name: review
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
6. Pay special attention to code smells and antipatterns in code, particularly shotgun surgery and divergent change patterns make reasoning about code difficult, especially if we have to jump through many different files. Cohesion and coupling should feel intentional and planned, not haphazard.

When it comes to the content of a change set, after reviewing the points above, we want to ensure we take a look at the change set from a higher level of analysis. Often times, code local changes are fine, but look out of place in the larger picture.

Using a counter agent devoid of your context and reasoning, have them review the change set while asking these questions:
1. Does it tell one story? Are there artifacts or branches from a pivot or mid-run fork that caused a redesign?
2. Does each concept have one owner and one name?
3. Does the vocabulary agree across surfaces?
4. Do the comments still describe the code? A stale rationale is worse than no comment.
5. Does it look like the rest of the app? Sibling jobs, Thor tasks, existing conventions rather than invented ones.
6. Do the tests describe behaviour a reader would recognise, and do they fail if you break the thing they name?
7. Is the architecture and design of the code also coherent? Does it fit together in a way that suggests a deliberate design that answers the questions above as well?

## Triage, once the counter agent's findings are back

Wait for both the review and the counter agent to report, then triage all of their findings together, in one list. A verified finding is not automatically work for this branch. Each fix adds code the next review must read, and fixes to fixes are how a PR grows past its goal.

Put every finding in exactly one bucket:

1. **Blocker.** It breaks the PR's stated goal, crashes, corrupts persisted state, or blocks merge (lint, Sorbet, a commit that fails on its own). Fix it on this branch.
2. **In goal, not blocking.** It is inside the PR's stated goal, and the fix stays in the files the goal already touches. Fix it here only if it is cheap; otherwise it is a follow-up.
3. **Follow-up.** Everything else: behaviour outside the stated goal, older code the branch only moved, and any fix that reaches shared code the goal does not need (base classes, client factories, another controller's save path). Do not fix it here. Name it in the PR description or a reply, or propose a separate PR.

Rules for sorting:
- Take the stated goal from what the work set out to do, never from what the diff happens to touch. Look in this order, and say which source you used:
  1. The PR title and description (`gh pr view --json title,body`). A PR with only a title, or a description not yet written, doesn't count.
  2. The plan, if one exists: the descriptive-named copy in `~/.claude/plans/` (match on the branch's topic or the newest mtime), or a planning doc under the repo's `agent-context/` that the branch adds or references. A plan's "out of scope" or follow-ups section is as binding as its goal.
  3. If neither says it, ask the user for the goal in one sentence before triaging. Don't infer it from the commits: the commits are what is under review.
- When a fix for one finding would create a new surface (a new shared rule, a new race window, a new code path), say so beside it. That is the signal the next review will find more.
- A comment, spec name or doc line made stale by this branch's own change is in goal; one that was already stale on main is a follow-up.
- Two reviewers reporting the same problem is one finding, not two.
- If a bucket is unclear, say so and let the user decide. Don't default a finding into bucket 1.

Present the findings grouped by bucket, for discussion. Do not start making edits right away: the user decides which findings get fixed, even on your own branch.

## Reviews must not keep growing the change set

A review exists to converge a change on its goal. A review whose fixes invite another review, which invites more fixes, is how a two-commit PR becomes thirty-five. Guard against it:

- **Report the size first.** Open the results with the change set's size against its base: commits, files, and lines (`git rev-list --count <base>..HEAD`, `git diff --shortstat <base>...HEAD`), and the commit reviewed (`git rev-parse --short HEAD`). On a re-review, also give the growth since the last reviewed commit.
- **A re-review reviews the delta.** When this branch has been reviewed before, review only `git diff <last-reviewed>..HEAD`. A finding in code the earlier review already covered is a follow-up unless it is a blocker. Settled code is not reopened because a fresh reader would write it differently.
- **Prefer fixes that shrink.** Rank the fix options for each finding by their size. Deleting, narrowing, or reverting beats adding. A fix that needs a new file, a new abstraction, or a change to shared code is a follow-up by default, even for a bucket 2 finding.
- **Stop when it stops converging.** If a round of fixes produced as many new findings as it closed, or the new findings are mostly about the previous round's fixes, do not propose another round. Say so plainly, and recommend moving the open items to follow-ups.

## Output: write the artifact only for branches you don't own

First decide whose branch this is — it determines whether to write a file at all:

- **Your own branch / a self-review** — the commits under review are authored by the current git user (`git log` author matches `git config user.email`), or you've been working this branch yourself in-session. **Do NOT write a review artifact.** There's nothing to post to GitHub, so the artifact is just noise — present the triaged findings inline in the conversation for discussion, and act only on the ones the user picks.
- **Someone else's branch / PR** — you're reviewing work you didn't author, to post comments back. Capture the review as **anchored markdown** (create `tmp/` if needed) so `~/.claude/scripts/post-review.rb` can convert it into a single GitHub review with line-anchored inline comments. This is a working draft — `tmp/` gets wiped periodically — not the system of record.

When it's genuinely ambiguous who owns the branch, ask before writing the file.

### Naming the artifact

`tmp/pr<NUMBER>_review-<YYYY-MM-DD-HHMM>.md`, e.g. `tmp/pr3018_review-2026-09-21-1702.md`.

The PR number is what tells you which review a stale draft belongs to once several accumulate in `tmp/`. The time is not decoration: a submitted GitHub review is closed, so a second pass on the same PR — a deeper read, a late agent's findings, a re-review after the author pushes — goes up as its own review, and a date-only name would silently overwrite the first one's draft. Read the clock when you write the file, use local time, and keep that one filename for every edit and the dry-run/post cycle of that single review. Sorting the directory then reads as the review history.

With no PR number — a branch with no PR yet, or a path-scoped review — use the slugified branch name in place of `pr<NUMBER>`.

Either way, follow the PR-review voice/length rules in `~/.claude/CLAUDE.md` (conversational, 1–3 sentences per inline, no severity tags or headlines, backticks on identifiers).

When you do write the artifact, the contract the poster script parses:

- **Event metadata** at the top: `<!-- review event=REQUEST_CHANGES -->` (CHANGES_REQUESTED for blockers, COMMENT otherwise). A `**State: ...**` line also works.
- **Review body** = the preamble prose before the first heading, plus any heading-section that has *no* anchor. Put the signpost-and-triage summary here, along with genuinely cross-cutting / multi-file notes (architectural framing, "looks good", non-blocking follow-ups) that don't belong on one line.
- **Inline comments** = each heading-section whose first non-blank line is an anchor. The `###` heading is organizational only (dropped from the posted comment); the prose under the anchor is the comment body. `side` defaults to `RIGHT`.

```markdown
<!-- review event=REQUEST_CHANGES -->
<signpost-and-triage summary: name the blockers, calibrate the rest>

### MIN_BASELINE_DAYS
<!-- review path=app/models/issues/destination_low_deliveries.rb line=15 side=RIGHT -->
The comment calls this "too new", but `raw_baseline_days` measures active days...

### A cross-cutting design note
This section has no anchor, so it stays in the review body.
```

Anchor each inline finding to a line that's actually in the diff — the script validates this and will refuse to post otherwise.

## Posting (only when the user asks)

Never post automatically — present for discussion first. Post as a single review with line-anchored inline comments; never fall back to a body-only `gh pr review --body-file` dump for expediency. When a finding can't anchor to a diff line, flag the tradeoff before pushing. When the user asks to push the review up:

```
ruby ~/.claude/scripts/post-review.rb tmp/pr3018_review-2026-09-21-1702.md          # dry run: parse, validate, preview
ruby ~/.claude/scripts/post-review.rb tmp/pr3018_review-2026-09-21-1702.md --post   # actually submit
```

Always name the file explicitly, both times, and make it the one you just wrote — with several drafts in `tmp/` the argument is the only thing that says which review is going up. The dry run resolves the PR + head commit via `gh`, validates every comment against the diff, and previews the body + inline comments. Run it first, surface any anchor problems, then post with `--post` once the user confirms. Pass `--pr N` to target a specific PR. If the script is missing (fresh repo, wiped `tmp`, new machine), rebuild it from this contract — it shells out to `gh api .../pulls/{n}/reviews`.
