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

## Rails console scripting & diagnostics

- **Buffer intermediate values.** Rails console interleaves SQL log output with expression return values, which makes multi-line diagnostics unreadable. When more than one query is involved, assign every intermediate value to a local or stuff them into a single hash, end the block with `nil` to suppress its return, then evaluate the hash on its own line. Don't expect users to mentally untangle SQL noise from results.
- **Verify properties and methods exist before suggesting them.** Don't guess column names, association names, or method names from convention or from analogy with other apps. Read the model file (`app/models/*.rb`) and/or the schema (`db/schema.rb`, `db/customer_schema.rb`) and confirm the names exist before putting them in a console snippet. A snippet that references a non-existent attribute is worse than no snippet — it makes the user run something that fails and erodes trust in the rest of the diagnostic.

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

## Drafting client and vendor replies

When I ask you to draft a reply to a client or vendor (typically an email or written response to a complaint, finding, or question), write it as a trusted technical partner addressing a counterpart who isn't deep in our internals. The reader cares about behavior and outcomes, not the names of our tools.

- **Generalize technical references.** "Our source data" beats "BigQuery." "A fix we shipped to resolve a bug with X" beats "PR #2404." Internal references — ticket IDs, PR numbers, table names, file paths, internal class/module names — belong in the *internal* writeup, not the outbound one.
- **Don't preamble explanations.** "And we can explain it" / "Here's what's going on" / "Let me walk you through this" are filler. The explanation follows the assertion that needs it; the reader knows to expect it. Cut the meta-signal and just deliver the explanation.
- **Question whether work is needed before offering to do it.** When the client has likely already adjusted on their end, ask whether they want us to do anything rather than declaring you'll do it. "Do we need to backfill if you've already corrected on your side?" beats "Happy to run the backfill." Offering work that may not be wanted reads as eager-to-please rather than collaborative.
- **Generally avoid em-dashes, and reshape sentences that "want" one.** Default to commas, semicolons, periods, or connectors ("as", "since", "because", "and"). When you catch yourself reaching for an em-dash to splice clauses, restructure with a connector: "Thanks for the examples as they helped us trace..." over "Thanks for the examples — they helped us trace..." For parenthetical asides, use actual parentheses, or just start a new sentence. The em-dash junction is the habit to break.

**Carries over from PR review style:** conversational contractions, inclusive "we", hedging the prescription rather than the claim, no severity tags or scaffolding.

**Different from PR review style:** outbound replies are full prose with structure and context, not 1–3 sentences. They invest more in explanation because the reader has less shared context than a code reviewer would. The internal-audience version of the same writeup (Slack-friendly, jargon-OK) is a separate artifact, not a substitute.
