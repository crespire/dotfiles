---
name: dream
description: Consolidate, tag and index the Obsidian knowledge store. Runs nightly; also invocable by hand. Merges machine-written memories into shapes, tags every memory for grep-based recall, and regenerates the tag catalog.
user_invocable: true
---

Auto-memory writes one file per fact and never looks back, so the store accumulates
duplicates, near-duplicates and facts that never got a name. This skill is the pass that
makes the store searchable: it consolidates what repeats, tags what is untagged, and
rebuilds the catalog that keeps the tag vocabulary honest.

Files are the system of record. There is no database. Two paths reach a memory, and this
skill maintains both: recall surfaces one automatically by matching its `description`, and
`grep` against `tags:` finds one deliberately. A vague description is a memory that never
surfaces on its own; an inconsistent tag is a memory nobody can look up.

## Territory

Get scope from `~/.claude/scripts/dream/lib.rb` — `Dream.files` returns every in-scope file
with its mode, and `Dream.vault` the vault root. Do not read the JSON directly:
`territory.json` is a committed template holding placeholder paths, and the real
configuration is `territory.local.json`, which overrides it. A run that reads only the
template raises `Errno::ENOENT` on a vault that does not exist.

Each directory has a mode. Never touch a directory that is not listed.

- **`consolidate`** — machine-written memories. Merge, rewrite, retag and archive freely.
- **`tag-only`** — prose the user wrote. Add or correct the frontmatter block and change
  nothing else. Never merge these, never rewrite a sentence, never archive one. The
  autonomy this skill has is over auto-memory's output, not over the user's own writing.

Walk each directory recursively — a listed directory may nest subdirectories.

**Ignore every path in `exclude`.** Each entry carries its own reason. Do not re-derive the
list: `~/.claude/scripts/dream/lib.rb` resolves it, and every script reads scope from there
so no two steps can disagree about what is in play.

Run snapshots live outside the vault (see Snapshot below), so they are never in territory
and never enter the vault's git history.

## Git

The vault has its own commit automation. Do not `git add`, `git commit`, `git stash` or
`git checkout` at any point while the run is working — a second writer races the
automation while files are still moving. Reading (`git diff`, `git log`) is always fine.

One exception, at the very end: after the counter pass has finished and the tree holds its
corrected state, commit the run as `Finished dreaming: <counts>`. One labelled commit per
run makes the history legible and the revert precise — a single night undone with
`git revert`, rather than picking the run out of a generic timestamped backup commit.

**Never push.** The vault automation syncs on its own schedule and carries the commit up.

Check `pgrep -x Obsidian` before committing. The automation is an Obsidian plugin, not a
daemon: with the app closed — the normal state at the scheduled hour — the run has the
repository to itself and the labelled commit lands clean. With the app open, its hourly
timer may already have committed part of the run, so one run spans two commits. Commit the
remainder anyway and note the split in the report.

Never pause the plugin to avoid this. Its configuration lives at
`.obsidian/plugins/obsidian-git/data.json`, which is tracked, so toggling it writes two
extra commits per run — and a run that dies between pause and resume leaves the vault
silently un-backed-up. A tidier history is not worth a guard that fails closed on backups.

If the index is locked because the automation is mid-commit, do not retry in a loop and do
not force. Leave the changes uncommitted and say so in the report: the automation sweeps
them into its next backup commit, which costs the label and nothing else.

## Harness

`~/.claude/scripts/dream/` holds the mechanics. Use them rather than writing equivalents: a
script with a selftest beats one improvised at 4am.

They also hold the tag-only guarantee, and it rests on refusal rather than care. A leading
`---` is not proof of frontmatter — a note may open with a horizontal rule, and the next rule
then looks exactly like a closing fence, so writing "above the closing fence" lands between
two lines of the user's prose. `Dream.frontmatter` therefore requires the block to parse as a
YAML mapping, and every writer skips a file that fails. Refused files are reported and left
byte-identical. Hand-editing frontmatter gives that up.

- `lib.rb` — territory, scope resolution, frontmatter and tag parsing. Everything requires it.
- `validate.rb` — asserts every invariant below, reports the wanted list. Read-only, exits
  non-zero on failure.
- `synonyms.rb` — proposes fold candidates from spelling drift and tag coverage. Read-only.
- `apply_tags.rb TABLE.tsv` — inserts or merges `tags:`. Frontmatter only.
- `rename_tag.rb OLD NEW` — folds one subject tag into another. The only script that can
  retire a tag; `apply_tags` merges as a union and cannot.
- `snapshot.rb` — copies every in-scope file to a dated directory outside the vault.
- `state.rb` — records the content hashes. `--list` names the files this run should process.
- `validate.rb --counts` — the catalog's tag lines, counted, in the shape `validate` parses.
- `prune.rb` — removes snapshot directories past the retention window.
- `selftest.rb` — the suite. Run it after changing any script.

**Two hooks will refuse the obvious shell form, and `bypassPermissions` does not lift a hook.**
`block-rm.sh` denies every `rm`, including through `find -exec` and `xargs` — use `prune.rb`.
`block-bash-file-edits.sh` denies a heredoc or `File.write` that replaces an existing file, so
write `MEMORY.md` and `DREAM.md` with the Write tool, not `cat >`.

Each applier defaults to a dry run and needs `--write` to touch anything, and each exits
non-zero when it refused a file. **Check the exit status**: a table whose paths do not
resolve prints per-file problems and applies nothing, which reads like success if you only
look at the last line. Generate the tag table for the run; the mechanics are the reusable
part, the tags are not.

Write scratch — the tag table included — under the vault's `tmp/`, which is gitignored.
Never under `~/.claude/skills/dream/`: that directory is the public dotfiles worktree, and
the table's first column is vault paths.

## Tag schema

Tags live in Obsidian's own `tags:` key so the vault's tag pane indexes them, using its
hierarchical `/` syntax so `grep -rl "scope/portable"` works unchanged.

```yaml
---
name: feedback-no-endless-methods
description: "Don't use Ruby endless method definitions; use full def/end bodies"
metadata:
  node_type: memory
  type: feedback
  originSessionId: f909042b-134d-4c3a-a6b4-0873f46d7973
tags: [scope/portable, form/preference, ruby, code-style]
---
```

Auto-memory owns writing. `name`, `description` and the whole `metadata` block are its
fields: never reorder, rename or remove them, and never write `type` at the top level —
it belongs under `metadata`. `tags:` is the key this skill adds, kept at the top level
because Obsidian indexes it there. It also writes a quoted `title:` when it prepends a block
to a file that had no frontmatter, since a note otherwise has no name inside the file.

Hand-written notes carry their own keys — `title:`, `date:`, and sometimes `tags:` already.
Preserve every key a file already has, and where `tags:` exists, add to it rather than
replacing it.

One tag is rewritten in place, and only in step 4: folding a near-synonym retires a spelling
across the store. That is a deliberate, named operation run through `rename_tag.rb`, and
where one of the two spellings is the user's own, theirs is the survivor. Outside that step,
an existing tag keeps the spelling it has.

Sharpen a `description` that does not say what the memory is for. Recall matches on that
field and ignores tags, so a vague description is the most common reason a good memory
never surfaces — and it is the one edit to an auto-memory field that is worth making.

Auto-memory may drop the `tags:` key when it rewrites a memory, since it does not know
about the key. This needs no defence: the incremental step below reprocesses any file with
no `tags:` key, so tags return on the next run, and recall covers the memory meanwhile.

### `scope/` — how far the knowledge travels

One value per memory.

- `scope/portable` — true anywhere, any job, any codebase. Style rules, review voice,
  hard rules about pushing or production.
- `scope/domain` — true across a context larger than one repository. Which context is a
  subject tag, never part of the scope value.
- `scope/local` — true of one codebase or one engagement only.

Scope is applicability, not origin. An employer name never appears in a scope value: a
fact learned at one job that holds across an industry is `scope/domain`, and the employer
is a subject tag. This is what lets the store outlive a job change without re-tagging.

### `form/` — what kind of thing it is

One value per memory.

- `form/pattern` — a shape of problem and the shape of solution that answers it. The most
  valuable kind; prefer it whenever a specific case can be generalised.
- `form/preference` — how the user wants work done.
- `form/artifact` — a specific outcome, report, decision or investigation result.

### Subject tags — no prefix

Everything that is not `scope/` or `form/` is a subject: `ruby`, `salesforce`, `boost`,
`pixel-capture`, and ticket references like `eng-1701`. They carry no prefix, which is how
the user already tags by hand, so dream's tags and theirs are one vocabulary rather than
two sitting side by side.

**Spell terms out; do not coin acronyms.** `salesforce`, not `sf` or `sfdc`.
`conversion-event`, not `ce`. `customer-predicate-destination`, not `cpd`. Two reasons: a
two-letter tag matches inside dozens of unrelated words on a substring grep, and a reader
scanning the catalog a year from now should not have to decode it.

The exception is a term whose acronym *is* its name, with no expansion anyone actually
uses: ticket references (`eng-1701`), product names (`cm360`), field names (`gclid`).
Those are identifiers, not abbreviations, and expanding them would make them wrong.

**One spelling per term.** Lowercase, hyphen-separated, singular: `pixel-capture`, not
`Pixel_Capture` or `pixel capture`; `runbook`, not `runbooks`. Case, separator and plural
drift each produce the same failure as an acronym — a tag that is right, a grep that is
right, and no match between them. This matches the tags already in the vault.

One or more per file, coined freely. Before coining a term, read the tag catalog in
`MEMORY.md` and reuse an existing tag that fits. New terms are expected; synonyms are the
failure. Fold near-synonyms together each run (see below).

## What each run does

`ruby ~/.claude/scripts/dream/state.rb --list` names the files to process: those whose
content hash differs from the last run's, plus any file with no `tags:` key. A full re-read
of an unchanged store wastes the run and risks churn. The hashes live in `state.json` rather
than in a frontmatter field, so incremental processing never depends on a key auto-memory
could overwrite.

### 1. Snapshot

`ruby ~/.claude/scripts/dream/snapshot.rb --write`.

It copies **every in-scope file**, not a predicted subset. Which files get modified is not
known yet: the merge set is chosen in step 3 and the synonym fold in step 4 reaches files the
hash check never selected. Snapshotting a guess leaves the counter agent no baseline for
exactly the edits most likely to lose content. A second run the same day gets its own
directory rather than overwriting the first.

This is the counter agent's ground truth. It cannot come from git, because the vault's
commit automation may have already committed the changes by the time the counter runs.

Snapshots live outside the vault deliberately. Inside it they would be territory the run
then walks over, and the vault's automation would commit a full copy of the store nightly.

Prune at the start of each run with `ruby ~/.claude/scripts/dream/prune.rb --write`. Do not
improvise a shell delete: `block-rm.sh` refuses any `rm` — including via `find -exec` and
`xargs` — and `bypassPermissions` does not lift a hook, so the run would stall waiting on a
denial nobody is there to clear.

### 2. Tag

Decide tags for the files this run selected, write them to a TSV of `path<TAB>tag tag tag`,
and apply with `ruby ~/.claude/scripts/dream/apply_tags.rb TABLE.tsv --write`.

It merges into an existing `tags:` in whatever shape it finds — inline, indented block or
zero-indent block — inserts one where the file has frontmatter without it, and prepends a
block with a quoted `title:` where the file has none.

It refuses, reports and leaves byte-identical: a fence that never closes, a block that is not
a YAML mapping, one that does not parse, a flow sequence that does not close on its line, a
duplicated `tags:` key, and a table row with no tags. **Read the output.** A refusal is a file
that stayed untagged, and the exit status is non-zero when any occurred.

Tagging is additive and reversible, and has no cap.

### 3. Consolidate — `consolidate` directories only

Merge memories that state the same fact. Rewrite the survivor as a pattern where a pattern
is available: name the situation by the signature that makes it recognisable again, then
the move that answers it. Keep the concrete case as evidence under the shape, not in place
of it. A memory that only ever describes one column of one model generalises to nothing.

Prefer patterns, preferences and shapes. Keep artifacts — a client investigation result is
worth having — but tag them `form/artifact` so they are distinguishable from knowledge
that transfers.

**Newest wins.** Memories accrete rather than get revised, so a status written while work
was in flight often contradicts content added after it shipped — an opening line saying
"not yet merged" above a later note giving the merge commit. When two statements in one
memory conflict, or when merging memories that disagree, the later statement is the fact
and the earlier one goes. Use the dates the memory gives you; where there are none, content
below an opening status is almost always newer than it.

Move superseded and stale memories to `knowledge/archive/<run-date>/`. Never delete a file.

**There is no cap.** Consolidate everything that warrants it in one run. The protection is
the audit trail, not a limit: every touched file is snapshotted outside the vault before the
run, the counter pass compares against those snapshots, `DREAM.md` records each merge and
why, and the whole run is one labelled commit that `git revert` undoes.

A cap would also break the incremental design rather than bound it — step 2 rewrites the
frontmatter of everything selected, so a deferred file records a fresh hash in step 8 and is
never reselected. Deferred work would be deferred permanently.

### 4. Fold synonym tags

Find subject tags that name the same thing and rewrite the files carrying the losers. The
vocabulary is emergent, so this step is what keeps it from drifting into a state where grep
silently misses two thirds of the matches.

Three kinds to look for, all producing the same silent miss: acronym against spelled-out
form (`sf`, `sfdc`, `salesforce`), plural against singular (`runbooks`, `runbook`), and
separator or case drift (`pixel_capture`, `pixel-capture`). The survivor is the one the
rules above would have produced — spelled out, lowercase, hyphenated, singular.

`synonyms.rb` detects the second and third kinds and deliberately does not guess at the
first: a shared prefix is not evidence, since `sti` does not abbreviate `stimulus`. **The
acronym kind is yours to spot**, from the catalog. `validate.rb` only warns at two
characters or fewer.

Apply a fold with `ruby ~/.claude/scripts/dream/rename_tag.rb OLD NEW --write`. It rewrites
in each file's own style and refuses the files `apply_tags` refuses. Do not hand-edit
frontmatter to fold a tag — `apply_tags` merges as a union and cannot retire one, and this
step reaches `tag-only` directories, where a free-hand edit is the one thing that could
break the guarantee that this skill never alters the user's prose.

Those naming rules govern the tags this skill coins. A tag the user wrote by hand outranks
them: where one of the near-synonyms is theirs, it survives even when it breaks a rule, and
this skill's spelling folds into it. Their vocabulary is not drift to be corrected.

`synonyms.rb` proposes the candidates. It reports spelling variants and tags whose file
coverage matches, and it stays read-only — the fold itself is a judgment.

### 5. Regenerate the catalog

Rewrite `knowledge/MEMORY.md` as the tag catalog: every tag in use, what it means, and how
many files carry it. The catalog is what the next run reads before coining a term, and what
the user greps to learn what the store knows about.

Keep the behavioural sections the catalog already carries — the rules that must be in
context whether or not anything greps for them.

**Do not count by hand.** `ruby ~/.claude/scripts/dream/validate.rb --counts` emits every tag
with its count, already grouped, in the shape below. Step 7 fails the whole run on a single
wrong number across a hundred-odd tags.

**`validate.rb` parses this section, so its shape is a contract.** Under a `## Tag catalog`
heading, up to the next `## `, write each tag as a backticked name followed by its count in
bare parentheses: `` `salesforce` (14) ``. Separators and prose around them are free. A
backticked name with no count is read as an example, not a claim — which is what lets the
naming rules quote `` `sf` `` as a term to avoid without registering it as a tag. Ticket
references are the exception and may appear bare. Reformat the section into a table and
every tag in the store reports as uncatalogued.

### 6. Write the change proposal

Overwrite `knowledge/DREAM.md`. One file, always the same path: its git history is the run
history, and the vault automation tracks it without new files accumulating.

Record what changed and why: merges performed with the files that went in, rewrites, tags
added, synonyms folded and archives. State the claims plainly —
the counter agent reads them.

### 7. Counter pass

Spawn a **fresh agent** with no access to this run's reasoning. Give it the snapshot
directory, the current files, and the claims in `DREAM.md`. An agent that inherits the
merge reasoning ratifies its own work; the check is only worth running if the checker
judges the result against the originals instead of the argument for the result.

Instruct it to:

- **Run `ruby ~/.claude/scripts/dream/validate.rb` first.** It asserts that every file's
  frontmatter parses as a YAML mapping, plus tag syntax, one scope and one form per file,
  duplicate tags, unresolved links and every catalog count. A clean exit clears the
  mechanical claims in seconds, which leaves the whole pass for judgment. Checking a few
  hundred files by hand for what a script checks exactly is where an unattended review gets
  skipped.
- **Separate a refusal from damage.** A file the writers refused — a horizontal rule read as
  a fence, frontmatter that already did not parse — is reported by `validate.rb` as a failure,
  so a store holding one never exits clean. Compare against the snapshot: unchanged since
  before the run means the run did not cause it, and it belongs in `DREAM.md` as a file
  needing a human, not as a regression. A file that parsed before and does not now is damage,
  and the run should not have been able to produce it.
- **Revert regressions.** Content present in a snapshot and absent from the survivor, with
  no merge claim covering it, is lost information. Restore it from the snapshot.
- **Flag judgment calls.** A defensible merge the user might not have made goes in
  `DREAM.md` under a findings section. Do not revert it.
- **Report the wanted list.** `validate.rb` names memories a sibling links to that do not
  exist. Those are gaps the store has identified in itself; they belong in `DREAM.md`.

Append its findings to `DREAM.md`.

If the counter agent dies rather than reports, spawn it again. The run is unattended, so a
question back to the operator ends it at step 7 with the tree uncommitted and `state.json`
still describing the previous night. Two failed attempts is enough: record the failure in
`DREAM.md`, then finish step 8 anyway. An uncommitted run is worse than an unchecked one.

### 8. Record state, then commit

Run `ruby ~/.claude/scripts/dream/state.rb --write`. It must run after the counter pass, so
the hashes describe the corrected tree rather than a state that was never on disk.

Then commit, following the Git section above: one labelled commit, and never a push. Stage
with `git add -A` from the vault root — step 3 creates files under `knowledge/archive/`, and
`git commit -a` alone does not pick up new paths.

## Output

Report the counts: files tagged, memories merged, archived, synonyms folded, and the
counter agent's verdict.
