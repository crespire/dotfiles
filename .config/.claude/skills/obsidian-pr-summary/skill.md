---
name: obsidian-pr-summary
description: Append a PR summary from the current repo's git history to an Obsidian weekly note
user_invocable: true
---

Generate a PR summary from the current repo's git history — plus any still-open PRs opened in the same week — and append it to the user's Obsidian weekly note.

## Arguments

`$ARGUMENTS` — an optional date string (e.g., `2026-02-23`) identifying the target weekly note. If omitted, default to the most recent Monday's date.

## Steps

### 1. Determine the repo name

Parse the repo name from `git remote get-url origin` — the last path segment, minus any
`.git` suffix (e.g. `git@github.com:acme/widget-api.git` → `widget-api`).

Do **not** use the working directory's basename. A git worktree's directory is named after the
branch, not the repo, so the basename would file the same repo's work under a different
heading depending on which checkout the command ran from — and the step 9 idempotency check
would miss the existing section.

Only if there is no `origin` remote, fall back to the working directory's basename.

### 2. Determine the target week and date range

- If `$ARGUMENTS` contains a date, use it as the **note date**.
- Otherwise, compute the most recent Monday (today if Monday, else the previous Monday).
- The **week range** for git log is: the **Saturday before** the note date (inclusive) through the **Friday of that week** (inclusive). For example, if the note date is `2026-02-23` (Monday), the range is `2026-02-21` (Saturday) to `2026-02-27` (Friday).
- Use these dates as `--since` and `--until` arguments (git log's `--since` is inclusive, `--until` is exclusive, so add one day to Friday for `--until`).

### 3. Get the user's git identity

Run `git config user.email` to get the author email for filtering commits.

### 4. Extract commits and identify PRs

Run a git log command to find all non-merge commits by the user in the date range:

```
git log --no-merges --author="<email>" --since="<saturday>" --until="<saturday-after-friday>" --format="%H %s"
```

From the subjects, extract PR numbers using the pattern `(#NNNN)` at the end of commit messages. Group commits by PR number. Commits without a PR number can be listed individually under an "Other" section if relevant.

### 5. For each PR, gather context

For each unique PR number, pick the merge/squash commit (the one whose subject contains the PR number) and run:

```
git log -1 --format="%B" <commit-hash>
```

This gets the full commit body which often contains "Because" / "This PR" context from the PR description.

### 6. Find still-open PRs opened in the same range

Merged PRs come from git history; open ones do not, so query GitHub for them. This step needs the `gh` CLI — if `command -v gh` finds nothing, or the `gh` call fails (not authenticated, no network, repo not on GitHub), **skip this step entirely** and continue with the merged PRs alone. Mention the skip once in the final report; never let it stop the run.

```
gh pr list --author "@me" --state open \
  --json number,title,createdAt,isDraft,url --limit 100
```

Keep only PRs whose `createdAt` date falls inside the same **Saturday through Friday** range (compare the `YYYY-MM-DD` prefix; `createdAt` is UTC). Drop any whose number already appears among the merged PRs from step 4.

For each remaining PR, pull the description for a one-line summary:

```
gh pr view <number> --json body
```

Use the "Because" / "This PR" lines the same way you would a commit body. Note which PRs have `isDraft: true`.

### 7. Categorize and format

Group the **merged** PRs into categories based on commit message prefixes and content:
- **Features**: New functionality, enhancements (look for `Feature`, `Add`, `ENG-` tickets that add new things)
- **Bugfixes & Hotfixes**: Bug fixes, hotfixes (look for `Fix`, `Bugfix`, `hotfix`, `CS-` tickets)
- **Infra & Tooling**: CI, tooling, refactoring, infrastructure changes

Open PRs do not get categorized — they all go in one **Pending Merge** section at the end, newest first, with drafts marked `(draft)`.

Format as a markdown section:

```markdown
## PR Summary (<repo-name>)
**Features**
- <ticket> <title> ([#NNNN](https://github.com/<org>/<repo>/pull/NNNN)) — <one-line summary from commit body>

**Bugfixes & Hotfixes**
- ...

**Infra & Tooling**
- ...

**Pending Merge**
- <ticket> <title> ([#NNNN](https://github.com/<org>/<repo>/pull/NNNN)) — <one-line summary from PR body>
- <ticket> <title> ([#NNNN](...)) (draft) — ...
```

Determine the GitHub org/repo from `git remote get-url origin` (parse the org and repo name from the remote URL). If the remote URL cannot be parsed, omit the PR links.

Only include sections that have entries. Each entry should have a concise one-line summary derived from the commit or PR body (the "Because" or "This PR" lines). If no body context is available, just use the title.

### 8. Find the Obsidian weekly note

Look for the vault in these locations (in order):
1. `~/repos/obsidian`
2. `~/Documents/Obsidian`
3. `~/Obsidian`

If none exist, ask the user for the vault path.

The weekly note path is: `<vault>/daily/<year>/<note-date>.md`

If the file doesn't exist, warn the user and stop.

### 9. Check idempotency

Read the target weekly note file. If it already contains `## PR Summary (<repo-name>)`, warn the user that a summary for this repo already exists in the note and **stop without modifying the file**.

### 10. Append the summary

Find the `---` separator line in the weekly note (the line that is exactly `---` and separates work from personal sections). Insert the PR summary section **immediately before** that `---` line, with a blank line above and below for readability.

If no `---` separator is found, append the summary to the end of the file.

### 11. Report to the user

Tell the user the path of the updated file and a brief count, split by state (e.g., "Added 12 PRs (9 merged, 3 pending merge) to ~/repos/obsidian/daily/2026/2026-02-23.md"). If step 6 was skipped, say so and why.

## Important

- Merged PRs come from `git log`. Open ones come from `gh`, which may be missing or unauthenticated — treat every `gh` call as best-effort and degrade to the git-only summary rather than failing.
- **Merged-only understates the week.** The merge cadence on these repos is slow, so a week's real output includes PRs that shipped for review but have not landed. That is what the Pending Merge section is for — include it whenever `gh` is available, even if it dwarfs the merged list.
- The window rule for open PRs is **opened** in the range, not last-updated. An older PR that merely picked up review comments this week is not this week's work.
- Do NOT output the summary inline in the chat — write it to the Obsidian file.
- Be idempotent: never duplicate a summary section for the same repo.
- If there are no commits **and** no open PRs by the user in the date range, inform them and stop without modifying the file.
