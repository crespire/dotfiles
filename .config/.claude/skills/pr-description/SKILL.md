---
name: pr-description
description: Generate a PR description for the current branch and write it to ./tmp/pr_description.md
user_invocable: true
---

Generate a PR description for the current branch and write it to `./tmp/pr_description.md` (overwriting any existing file). Always write — never echo to chat.

## Steps

1. Run `git log <base>...HEAD` and `git diff <base>...HEAD` to read the actual changes. `<base>` is `main` (or `master` if the repo uses that).
2. Look for `.github/pull_request_template.md` (or `.github/PULL_REQUEST_TEMPLATE.md`, or files under `.github/PULL_REQUEST_TEMPLATE/`) and follow its section headers verbatim. If no template exists, use `## Summary` / `## Why` / `## Test plan`.
3. Scan the diff for deploy-time concerns and surface them in the appropriate section (the template's "Additional Information / Pre or Post Deployment Tasks" if present, otherwise a `## Deployment notes` section):
   - New env vars or `Rails.application.credentials` references
   - New or modified integrations / providers / platform configs that need an `integrations:sync` rake task
   - Changes to `mapped_fields.yml` (needs `rake mapped_fields:load` post-deploy)
   - Do **not** flag Rails database migrations as a deployment task — `bin/rails db:migrate` runs automatically as part of the deploy pipeline. Only call out a migration if it carries an unusual concern (long-running backfill, exclusive lock risk, manual ordering with a code change, etc.).
4. `mkdir -p ./tmp` and write the description to `./tmp/pr_description.md` via the Write tool (overwrite if it exists — the file is often stale from prior runs).
5. Reply with a one-line confirmation: the path, and a brief note on what the description covers. Don't paste the full content back.

## Style

- **Moderate detail.** Default length. The "why" gets 1-3 short paragraphs, the "what changed" gets a focused bulleted list, deployment notes are 1-2 bullets each.
- **No markdown fences around the whole document.** The file is meant to be opened, not copy-pasted from a chat block.
- **Don't hard-wrap prose.** Write each paragraph as a single continuous line and let the editor/renderer soft-wrap it. Never insert manual newlines mid-paragraph to hit a column width — hard breaks turn into ragged lines when the description is pasted into the GitHub PR box. (Bullet lists and code blocks are unaffected; this is about wrapping within a paragraph or a single bullet.)
- **No ceremony.** Don't ask the user for a detail level — moderate is the default. Don't ask whether to overwrite — always overwrite. Don't enumerate every changed file — group related changes.
- **Ground in the diff.** Don't speculate beyond what the commits and diff show. If context is genuinely needed (e.g., the "why" isn't obvious from the diff), ask the user one targeted question before writing.

## Rules

- Path is always `./tmp/pr_description.md`, project-relative.
- Match the repo's PR template structure exactly when one exists — section names, order, any HTML comments left in place stripped out.
- Use imperative-mood prose in the body (matches commit message style).
- Don't include a `Co-Authored-By` trailer or any AI attribution in the description body.
