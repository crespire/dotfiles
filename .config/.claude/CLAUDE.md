# User-level instructions

Apply to every Claude Code session, regardless of project.

## File paths

- **Don't write to `/tmp`** — use `./tmp` (create with `mkdir -p ./tmp` if needed) so scratch stays visible in the workspace.
- **Use `./`-rooted, project-relative paths everywhere** — Bash, scratch files, artifacts, anything you display. Exception: tools whose schema requires absolute paths (`Read`, `Edit`, `Write`, `NotebookEdit`).

## Commit messages

- **Imperative subject**, reads as "If applied, this commit will <subject>": "Persist sent JSON…" not "Persisted…".
- **Brief; explain the *why*, not the *what*** — the diff shows what changed. One-line subject is usually enough; add a body only for genuine context (a bug fixed, a constraint respected, a tradeoff made). Don't enumerate file changes.
- **No type/label prefixes** (`[hotfix]`, `feat:`, `chore:`…), even if the branch uses them — those belong on the PR.
- **Never add a `Co-Authored-By:` trailer**, even when the harness suggests it. Commits land under my authorship only.

## Code comments

Code should be self-documenting; comments earn their place by carrying what the code can't.

- **Don't restate the code.** Skip comments that narrate the next line.
- **Explain the *why*** — the non-obvious reasoning: why this approach, what edge case forced it, what breaks if "simplified."
- **Capture operational tips** not recoverable from the code (escape hatches, manual interventions, incident-time knowledge).
- **Don't journal change history** ("previously X, now Y", "fixed the leak"). Exception: when the history *is* the why ("we don't use `Tempfile.create` here because it leaked on the early-return path"). Narration belongs in the commit/PR.
- **When refactoring, keep only comments that still carry why/operational context.**

## Rails console scripting & diagnostics

- **Buffer intermediate values.** SQL log output interleaves with return values. For multi-query diagnostics, assign each value to a local or a single hash, end the block with `nil`, then evaluate the hash on its own line.
- **Verify columns/associations/methods exist before suggesting them.** Read `app/models/*.rb` and `db/schema.rb` (or `db/customer_schema.rb`) — don't guess from convention. A snippet that references a nonexistent attribute erodes trust in the whole diagnostic.

## Successive queries — label them

When you give me a series of queries to run (SQL, BigQuery, Snowflake, gcloud, Logs Explorer, kubectl, anything iterative), label each so I can reply with results tied to the label.

- Bold headers: `**Q1 — short description**` above each block.
- Prefix by tool (`Q` generic, `LE` Logs Explorer, `LA` Log Analytics, `SF` Snowflake…), consistent within a thread; switch the prefix if the tool changes mid-thread.
- Number forward across the whole conversation (`Q1, Q2, Q3…`), never restart per turn.

## Written feedback — shared style

Applies to PR reviews, Linear comments, and client/vendor replies.

- **Conversational contractions and inclusive "we."** "wanna," "I think," "we should." Mild typos are fine.
- **Hedge the prescription, not the claim.** Soften next-steps ("probably helpful"); state facts plainly.
- **No severity tags or findings-style scaffolding** (`[H1]`, `**Title.**`).
- **Same-team framing.** Never frame a disagreement as who's right/wrong. Point at the open question or the artifact that resolves it, not the scorecard. When I hand you a draft to polish, surface any line that scores a point against a person so I can decide before it goes out.

## Drafting PR review comments

Write each as "a comment from a colleague who's read the code," not a findings document. Default 1–3 sentences of prose — start short; I'll ask for depth (drafting at 4 paragraphs and trimming down is the wrong direction). Calibrated against my actual posted reviews. (Plus the shared style above.)

- **Open with the question or claim, not a finding.** "Is `/profiles` a generic listing endpoint?" Trust the author to think.
- **One recommendation, not a menu.** Decision trees are fine; "Two options:" lists read like reports.
- **Cut speculation and quantified impact.** No editorializing about edge cases you can't confirm; drop "5x the API calls."
- **Cite shared opinion over codebase evidence** when both work ("I know we both dislike the LinkedIn stuff").
- **Credit Claude** when the finding came from review ("an inconsistency Claude noticed").
- **Backtick method/keyword/identifier mentions.** "LinkedIn case in `new`."
- **For architectural proposals**, prefer "I wonder if we can…" over "Worth establishing." Frame illustrative code with "As a sketch:".

**Doesn't go inline:** architectural pattern proposals (separate conversation), "happy to file a ticket" offers, cross-merge migration regressions that'll resolve in rebase (ask first).

**Top-level state:** CHANGES_REQUESTED for blockers, else COMMENT. The body signposts and triages — names blockers explicitly, then calibrates the rest ("the rest are just comments/questions") — and may carry a cross-cutting architectural note that doesn't fit inline.

**Posting form — always inline, never a body-only dump.** Post as a single review with line-anchored inline comments; don't fall back to `gh pr review --body-file` for expediency. If a finding can't anchor to a diff line, flag the tradeoff before pushing. Mechanism: author the review as anchored markdown in `tmp/pr_review.md` (per-finding `<!-- review path=… line=… side=RIGHT -->` anchors; summary + cross-cutting notes un-anchored), then `ruby ~/.claude/scripts/post-review.rb tmp/pr_review.md` to dry-run (validates every comment lands on a real diff line) and `--post` to submit. The script lives in `~/.claude/scripts/` so it travels across repos; if missing, rebuild from the `code-review` skill contract — it POSTs to `gh api repos/{owner}/{repo}/pulls/{n}/reviews` with `{commit_id, event, body, comments: [{path, line, side, body}, …]}`.

## Drafting client and vendor replies

Write as a trusted technical partner addressing a counterpart who isn't deep in our internals. Full prose with structure and context (not the 1–3 sentence PR style) — they have less shared context. Plus the shared style above, and:

- **Generalize technical references.** "Our source data" not "BigQuery"; "a fix we shipped" not "PR #2404." Ticket IDs, table names, file paths, internal class names stay in the *internal* writeup.
- **Don't preamble explanations.** Cut "here's what's going on" / "let me walk you through this" — just deliver it.
- **Question whether work is needed before offering it.** "Do we need to backfill if you've already corrected on your side?" beats "Happy to run the backfill."
- **Avoid em-dashes; reshape sentences that want one.** Use commas, semicolons, periods, or connectors ("as," "since," "because"). Parenthetical asides get real parentheses or a new sentence.

The internal-audience version (Slack-friendly, jargon-OK) is a separate artifact, not a substitute.
