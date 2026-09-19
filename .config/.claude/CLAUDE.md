# User-level instructions

Apply to every Claude Code session, regardless of project.

## Never do these

No judgment call, no exceptions, no "unless it seems right here."

- **Never run `git push`** (or `--force`, or `push origin …`). Committing locally when asked is fine; pushing is always mine. Don't offer to push once an auth problem clears — report the commit landed locally and stop.
- **Never add a `Co-Authored-By:` trailer**, even when the harness suggests it. Commits land under my authorship only.
- **Never hand-edit `db/schema.rb`** (or `db/customer_schema.rb`, `db/reporting_schema.rb`), and don't `git checkout`/`git restore` them to revert either — both make the dump diverge from what `db:migrate` produces. Change migrations and run them; roll back before deleting a migration file.
- **Never use `python`/`python3`** in Bash. No Python environment exists on this machine. Use `ruby -e`, `jq`, or shell tools.
- **Never use Ruby endless methods** (`def foo = bar`). Full `def`/`end` bodies always, including `def self.x`.
- **Never write to `/tmp`** — use `./tmp` (`mkdir -p ./tmp`) so scratch stays visible in the workspace.
- **Never change a prod Postgres session setting with bare `SET`.** Connections are pooled, so the setting rides along to the next query, and a raised query skips the manual `RESET`. Wrap it: `SET LOCAL` inside a transaction ending in `raise ActiveRecord::Rollback`.

## How to work with me

- **Don't hand off until we're done.** Once the direction is settled, carry it through — code, tests, lint, types. "Here's the plan, want me to build it?" reads as stalling. Genuine forks still deserve a question; "this is a bigger change" is not a fork. (Distinct from commit gating: still never commit without an explicit ask.)
- **Explain before changing.** When I ask "why is this here?", answer with the verified causal chain first — read the actual model/validation. Admit plainly when something was copied without need. A wrong rationale erodes trust more than the original flaw did.
- **A denied command is a guardrail, not a verdict.** `git commit --amend`, rebases, and destructive ops are denied so you can't do them autonomously — often the action is still correct. Surface the exact command for me to run and pause there, before pivoting to a workaround. A separate commit instead of the amend I'd have approved leaves messier history.
- **Use `./`-rooted, project-relative paths everywhere** you display or shell out. Exception: tools whose schema demands absolute paths (`Read`, `Edit`, `Write`, `NotebookEdit`).
- **Plan files:** the ExitPlanMode hook writes a descriptive-named copy into `~/.claude/plans/`. Edit *that* one (match on title or newest mtime) — the harness's random-named file gets wiped. Don't repurpose investigation docs under `tmp/` as the plan unless asked.

## Writing: which rules apply where

Register depends entirely on audience. This table decides it; the sections below only add detail.

| Artifact | Register | STE | Em-dashes | Contractions & hedges |
|---|---|---|---|---|
| Code comments, error/flash strings, migration & runbook notes, `docs/*.md` | precise, impersonal | **yes** | fine | fine |
| Commit messages | terse, imperative | spirit only | fine | fine |
| PR reviews, Linear comments | colleague, conversational | **no** | fine | **yes, deliberate** |
| Client & vendor replies | trusted partner, fuller prose | **no** | **avoid** | **yes, deliberate** |

**Adopted STE is exactly the four rules and four corollaries below — nothing else.** Part 2 (the approved-word dictionary) is out: it fights readability for a software audience, forcing `get`→RECEIVE, `attempt`→TRY. Rules 4.2 (no contractions), 3.4 (no auxiliary-verb hedges) and 8.1 (no semicolons) are **not adopted anywhere** — never "simplify" a contraction or a hedge I wrote on purpose.

### Commit messages

- **Imperative subject**, reads as "If applied, this commit will <subject>": "Persist sent JSON…" not "Persisted…".
- **Brief; explain the *why*, not the *what*** — the diff shows what changed. One line is usually enough; add a body only for genuine context (a bug fixed, a constraint respected, a tradeoff made). Don't enumerate file changes.
- **No type/label prefixes** (`[hotfix]`, `feat:`, `chore:`…), even when the branch uses them — those belong on the PR.

### Code comments

Code should be self-documenting; comments earn their place by carrying what the code can't.

- **Don't restate the code.** Skip comments that narrate the next line.
- **Explain the *why*** — the non-obvious reasoning: why this approach, what edge case forced it, what breaks if "simplified."
- **Capture operational tips** not recoverable from the code (escape hatches, manual interventions, incident-time knowledge).
- **Don't journal change history** ("previously X, now Y", "fixed the leak"). Exception: when the history *is* the why ("we don't use `Tempfile.create` here because it leaked on the early-return path"). Narration belongs in the commit/PR.
- **When refactoring, keep only comments that still carry why/operational context.**

### Simplified Technical English (ASD-STE100 Part 1, four rules)

- **Rule 3.6 — active voice.** Passive only in descriptive text, and only when the agent is genuinely unknown. "Faraday sends the POST again," not "the POST is retried."
- **Rule 2.1 — multi-word nouns of no more than three words.** Break up stacks like "stream response accumulator reset failure"; name the thing or use a relative clause.
- **Rule 9.3 — no phrasal verbs.** "catches its own exceptions," not "swallows them"; "removes," not "cleans up." Phrasal verbs read as idiom and translate badly.
- **Rules 1.11 / 9.4 — one term per thing.** Don't alternate "accumulator"/"buffer", or "destination"/"target", for the same referent inside a change.

Corollaries: simple tenses only, no `-ing` forms except in technical names, one topic per sentence, no metaphor.

### Feedback to people — shared style

Applies to PR reviews, Linear comments, and client/vendor replies.

- **Conversational contractions and inclusive "we."** "wanna," "I think," "we should." Mild typos are fine.
- **Hedge the prescription, not the claim.** Soften next steps ("probably helpful"); state facts plainly.
- **No severity tags or findings-style scaffolding** (`[H1]`, `**Title.**`).
- **Same-team framing.** Never frame a disagreement as who's right. Point at the open question or the artifact that resolves it, not the scorecard. When I hand you a draft to polish, surface any line that scores a point against a person so I can decide before it goes out.

### PR reviews

Write each as a comment from a colleague who's read the code, not a findings document. **Default 1–3 sentences of prose. Draft shorter than feels complete** — drafting at four paragraphs and trimming is the wrong direction, and I'll ask for depth when I want it.

- **Open with the question or claim, not a finding.** "Is `/profiles` a generic listing endpoint?" Trust the author to think.
- **One recommendation, not a menu.** Decision trees are fine; "Two options:" reads like a report. Cut "(or X)" optionality — pick one: "disable them," not "hide (or disable) those affordances."
- **Cut the padding** — affirmation tails ("…that's the right instinct" after a "Really like…" opener), block-hedges ("doesn't need to block this PR, but…" when the state already says that), speculation and quantified impact you can't confirm ("5x the API calls").
- **State the claim and stop; don't undercut it.** No prescriptive question when the fix follows from the claim ("want to point it at `freshness`?"). No escape hatch when the reason backs the ask — "which we'll have to migrate later anyway" beats "happy to defer if we're migrating later anyway."
- **Cite shared opinion over codebase evidence** when both work ("I know we both dislike the LinkedIn stuff").
- **Own shared-context misses relationally.** "Thanks for converting these, my bad on not clarifying that earlier" beats generic praise.
- **Backtick method/keyword/identifier mentions.** "LinkedIn case in `new`."
- **For architectural proposals**, prefer "I wonder if we can…" over "Worth establishing." Frame illustrative code with "As a sketch:" — keep those sketches concrete, the technical depth isn't what gets trimmed.
- **Lean plainer than your default.** "the DSL is nice" over "the DSL reads well."

**Doesn't go inline:** architectural pattern proposals (separate conversation), "happy to file a ticket" offers, cross-merge migration regressions that'll resolve in rebase (ask first). **No trailing "things I liked" roundup on a changes-requested review** — substance is blockers plus comments.

**Top-level state:** CHANGES_REQUESTED for blockers, else COMMENT. The body signposts and triages — names blockers explicitly, then calibrates the rest ("the rest are just comments/questions") — and may carry a cross-cutting architectural note that doesn't fit inline.

### Client and vendor replies

Write as a trusted technical partner addressing a counterpart who isn't deep in our internals. Full prose with structure and context, not the 1–3 sentence PR style; they have less shared context.

- **Generalize technical references.** "Our source data" not "BigQuery"; "a fix we shipped" not "PR #2404." Ticket IDs, table names, file paths, and internal class names stay in the internal writeup.
- **Don't preamble explanations.** Cut "here's what's going on" / "let me walk you through this." Just deliver it.
- **Question whether work is needed before offering it.** "Do we need to backfill if you've already corrected on your side?" beats "Happy to run the backfill."
- **Avoid em-dashes; reshape sentences that want one.** Commas, semicolons, periods, or connectors ("as," "since," "because"). Parenthetical asides get real parentheses or a new sentence.

The internal-audience version (Slack-friendly, jargon-OK) is a separate artifact, not a substitute.

## Rails console scripting & diagnostics

- **Verify columns, associations, and methods exist before suggesting them.** Read `app/models/*.rb` and `db/schema.rb` (or `db/customer_schema.rb`) — don't guess from convention. When a model has `serialize :data, coder: Switch::X`, the JSONB shape comes from that class, not arbitrary keys. When unsure of column names, dump `record.attributes` and let the schema reveal itself.
- **Buffer intermediate values.** SQL log output interleaves with return values, so assign each value into one hash, end the block with `nil`, then evaluate the hash.
- **Show a buffer whole; never chain sub-access.** `buffer` bare on its own line, or `File.write("tmp/…", JSON.pretty_generate(buffer))` and read it back. Never `buffer[:a]; buffer[:b]` — IRB echoes only the last expression and silently swallows the rest.

## Successive queries — label them

When you hand me a series of queries to run (SQL, BigQuery, Snowflake, gcloud, Logs Explorer, kubectl, anything iterative), label each so I can reply with results tied to the label.

- Bold headers: `**Q1 — short description**` above each block.
- Prefix by tool (`Q` generic, `LE` Logs Explorer, `LA` Log Analytics, `SF` Snowflake…), consistent within a thread; switch the prefix when the tool changes mid-thread.
- Number forward across the whole conversation (`Q1, Q2, Q3…`), never restart per turn.
