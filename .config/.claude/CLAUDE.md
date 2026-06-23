# User-level instructions

These apply to every Claude Code session, regardless of project.

## File paths

- **Do not write to `/tmp`.** Use `./tmp` (project-relative) instead. Create the directory with `mkdir -p ./tmp` if it doesn't exist. This keeps scratch artifacts visible inside the workspace and avoids cluttering the system temp directory.
- **Always use `./`-rooted, project-relative paths when working with the file system.** This applies to `Bash` commands, scratch files, saved artifacts, and any path you display or pass around. The only exception is tools whose schema requires absolute paths (`Read`, `Edit`, `Write`, `NotebookEdit`) — there, an absolute path is unavoidable, but everywhere else prefer `./path/to/thing` over `/Users/<you>/.../path/to/thing`.

## Commit messages

- **Use imperative mood in the subject line.** Write the subject as a command: "Persist sent JSON to DeliveryAttempt.request" not "Persisted ..." / "Persists ..." / "Persisting ...". The convention reads naturally as "If applied, this commit will <subject>."
- **Be brief and focus on the *why*, not the *what*.** The diff already shows what changed; the commit message should explain motivation, context, or the reasoning that isn't obvious from the code. Don't enumerate file changes, list renamed methods, or restate what a reader can see by running `git show`.
- A one-line subject is often enough. Add a short body only when there's genuine context worth preserving (a bug being fixed, a constraint being respected, a tradeoff being made).
- **Skip type/label prefixes in the subject.** Don't prepend things like `[hotfix]`, `[PRD-123]`, `[fix]`, `feat:`, `chore:`, etc. to the subject line, even if recent commits on the branch use that style — those belong to the PR title / labels, not to individual commits. Write the subject as a plain, descriptive sentence in imperative mood.
- **Never add a `Co-Authored-By:` trailer.** Do not append `Co-Authored-By: Claude ...` (or any other co-author trailer) to commits, even when the harness's default instructions suggest it. Commits should land under my authorship only.

## Code comments

Code should be self-documenting; comments earn their place by carrying what the code can't.

- **Don't restate what's obvious from the code.** Skip comments that narrate the next line ("compute the checksum", "find the most recent execution"). If a reader gets it from the method name and the statement, the comment is noise — delete it.
- **Explain the *why*, not the *what*.** Comment the non-obvious reasoning behind a choice: why this approach over the alternative, what constraint or edge case forced it, what would break if someone "simplified" it. Example: why we order by `id` rather than `imported_at` (the latter is set inconsistently across flows).
- **Capture operational tips where relevant.** Note escape hatches, manual interventions, and incident-time knowledge that isn't recoverable from reading the code — e.g. "to force a byte-identical file through, clear `file_checksum` on the prior execution."
- **Don't journal the history of a change.** Comments describe the code as it is now, not how it got here ("previously we did X, now we do Y", "changed to fix the leak", "added in the hotfix"). The exception is when the history *is* the why — e.g. "we don't use `Tempfile.create` here because it leaked the handle on the early-return path." Change narration belongs in the commit message and PR, not the source.
- **When refactoring, keep only the comments that still carry why/operational context; drop the rest.** Don't preserve a comment just because it was there before.

## Rails console scripting & diagnostics

- **Buffer intermediate values.** Rails console interleaves SQL log output with expression return values, which makes multi-line diagnostics unreadable. When more than one query is involved, assign every intermediate value to a local or stuff them into a single hash, end the block with `nil` to suppress its return, then evaluate the hash on its own line. Don't expect users to mentally untangle SQL noise from results.
- **Verify properties and methods exist before suggesting them.** Don't guess column names, association names, or method names from convention or from analogy with other apps. Read the model file (`app/models/*.rb`) and/or the schema (`db/schema.rb`, `db/customer_schema.rb`) and confirm the names exist before putting them in a console snippet. A snippet that references a non-existent attribute is worse than no snippet — it makes the user run something that fails and erodes trust in the rest of the diagnostic.

## Successive queries — label them

When you ask me to run a series of queries — SQL, BigQuery, Snowflake, gcloud logging, Logs Explorer, Log Analytics, kubectl, anything iterative — **label each query** so I can reply with results tied to the label. Without labels, results come back as "here are the results" and we both lose track of which query a given output is from, especially when I run them out of order or there's interleaved discussion between asks.

- Use bold headers like `**Q1 — short description**` above each query block.
- Pick a prefix appropriate to the tool (`Q` for generic SQL/console, `LE` for Logs Explorer, `LA` for Log Analytics, `SF` for Snowflake, etc.) and stay consistent within a thread.
- Number forward across the whole conversation — `Q1, Q2, Q3 ...` — don't restart from `Q1` each turn.
- When I reply with `Q3: <output>`, thread off that specific query.
- If the tool changes mid-thread (e.g. gcloud → Logs Explorer UI), switch the prefix to match the new environment so the source of each result stays unambiguous.

## Drafting PR review comments

When I ask you to draft inline PR review comments, write them as "PR comment from a colleague who's read the code," not as a structured findings document. Default to 1–3 sentences of conversational prose. Calibrated against my actual posted reviews.

- **No severity tags, no bold headlines, no findings-style scaffolding.** Skip `[H1]` / `[BLOCKER]` / `**Title.**` openings. Severity goes in the top-level review state (CHANGES_REQUESTED) plus a one-line summary that names the blocker, not on each inline.
- **Open with the question or the claim, not a finding.** "Is `/profiles` a generic profile listing endpoint?" / "Is it intentional to let X fall through to the default?" Trust the author to think. Open questions outperform prescriptive findings.
- **Pick one recommendation; don't enumerate options.** Decision trees ("If A, then X; if B, then Y") are fine; bulleted "Two options:" lists read like reports.
- **Cut speculation.** If I don't have ground truth (whether an edge case actually fires, what an API does), don't editorialize.
- **Skip quantified impact.** "5x the API calls" / "fewer per-request fixed costs" — drop. The actionable change communicates without the math.
- **Conversational contractions and inclusive "we".** "wanna," "I think," "we should," "we have a few other integrations that do this too." Mild typos are fine — don't sweat polish.
- **Hedge the prescription, not the claim.** Soften next-steps ("probably helpful," "I think the practical impact is..."), not facts. For architectural proposals specifically, prefer "I wonder if we can't establish..." or "I wonder if we can..." over "Worth establishing."
- **Cite shared opinion with the recipient over codebase evidence when both work.** "I know we both dislike the LinkedIn specific stuff" beats "the LinkedIn case has a `# FIX:` comment about Y." Relational framing is more collegial when the recipient is a known collaborator.
- **Credit Claude when the finding came from review.** "An inconsistency Claude noticed." Transparent about provenance.
- **Practical heads-up over architectural prose.** "This will probably require some spec updates too" — short footnote, not theorizing.
- **Frame illustrative code with "As a sketch:"** — makes the proposal-vs-prescription line clear. Combine related code blocks rather than fencing each piece separately.
- **Maintain inline backticks on method, keyword, and identifier mentions.** "LinkedIn case in `new`" not "LinkedIn case in new". If a posted comment is missing them, that's an oversight not a stylistic choice.

**What does NOT go in PR review comments:**
- Architectural pattern proposals (polymorphic refactors, abstraction sweeps) — those are a separate conversation, not a review-block.
- "Happy to file a ticket" offers.
- Cross-merge migration regressions if they'll resolve in rebase — ask before pre-flagging as a blocker.

**Top-level review state:** Use CHANGES_REQUESTED for blockers. The summary signposts and triages — names blockers explicitly ("Another blocker is the X comment below"), then calibrates the rest ("The rest are just comments/questions"). Routes the author's attention without repeating inline content. The summary CAN be longer when it carries an architectural proposal that doesn't fit inline; in that case, end with the signpost-and-triage line.

**Default starting length:** 1–3 sentences per inline. If more depth is needed, the user will ask. Drafting at 4 paragraphs and trimming down is the wrong direction — start short.

**Posting form — always inline, never a body-only dump.** When the review actually goes up to GitHub, post it as a *single review with line-anchored inline comments*, not the whole writeup pasted into the review body. This is the default; don't fall back to `gh pr review --body-file` for expediency, and if some finding genuinely can't be anchored to a diff line, flag that tradeoff before pushing rather than deciding it silently. State is CHANGES_REQUESTED for blockers (per above), COMMENT otherwise. The review **body** carries only the signpost-and-triage summary plus any genuinely cross-cutting / multi-file architectural notes that don't belong on one line; every other finding rides inline on its line.

The mechanism: I author the review as **anchored markdown** in `tmp/pr_review.md` (the format the `code-review` skill prescribes — per-finding `<!-- review path=… line=… side=RIGHT -->` anchors, with the summary and cross-cutting notes as un-anchored body), then run the durable poster `~/.claude/scripts/post-review.rb` to convert and submit it. Dry-run first (`ruby ~/.claude/scripts/post-review.rb tmp/pr_review.md`) — it resolves the PR + head commit via `gh`, validates every comment lands on a real diff line, and previews; then `--post` to submit. The script lives in `~/.claude/scripts/` (not `tmp/`, which gets wiped) so it travels across repos; if it's ever missing, rebuild it from the contract in the `code-review` skill — it ultimately POSTs to `gh api repos/{owner}/{repo}/pulls/{n}/reviews` with `{commit_id, event, body, comments: [{path, line, side, body}, …]}`.

## Drafting client and vendor replies

When I ask you to draft a reply to a client or vendor (typically an email or written response to a complaint, finding, or question), write it as a trusted technical partner addressing a counterpart who isn't deep in our internals. The reader cares about behavior and outcomes, not the names of our tools.

- **Generalize technical references.** "Our source data" beats "BigQuery." "A fix we shipped to resolve a bug with X" beats "PR #2404." Internal references — ticket IDs, PR numbers, table names, file paths, internal class/module names — belong in the *internal* writeup, not the outbound one.
- **Don't preamble explanations.** "And we can explain it" / "Here's what's going on" / "Let me walk you through this" are filler. The explanation follows the assertion that needs it; the reader knows to expect it. Cut the meta-signal and just deliver the explanation.
- **Question whether work is needed before offering to do it.** When the client has likely already adjusted on their end, ask whether they want us to do anything rather than declaring you'll do it. "Do we need to backfill if you've already corrected on your side?" beats "Happy to run the backfill." Offering work that may not be wanted reads as eager-to-please rather than collaborative.
- **Generally avoid em-dashes, and reshape sentences that "want" one.** Default to commas, semicolons, periods, or connectors ("as", "since", "because", "and"). When you catch yourself reaching for an em-dash to splice clauses, restructure with a connector: "Thanks for the examples as they helped us trace..." over "Thanks for the examples — they helped us trace..." For parenthetical asides, use actual parentheses, or just start a new sentence. The em-dash junction is the habit to break.

**Carries over from PR review style:** conversational contractions, inclusive "we", hedging the prescription rather than the claim, no severity tags or scaffolding.

**Different from PR review style:** outbound replies are full prose with structure and context, not 1–3 sentences. They invest more in explanation because the reader has less shared context than a code reviewer would. The internal-audience version of the same writeup (Slack-friendly, jargon-OK) is a separate artifact, not a substitute.

## Same-team framing (all written feedback — PR reviews, Linear, replies)

Never frame a disagreement as "who's right" / "who's wrong" / "this settles which of us is correct." Focus on the problem, not the people — we're on the same team. Even when correcting a teammate's mistaken claim, point at the open question or the artifact that will resolve it ("that one answer settles where the problem lies"), not at the scorecard. Applies to PR review comments, Linear comments and replies, client/vendor replies, and any internal written feedback. When I hand you a draft to polish, surface any line that scores a point against a person so I can decide before it goes out.
