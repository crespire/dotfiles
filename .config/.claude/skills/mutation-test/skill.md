---
name: mutation-test
description: Mutation-test a change set — break its load-bearing expressions one at a time and confirm a spec fails. Use when a guard carries the correctness of a change, when a spec "looks like" coverage, or when asked to prove behaviour is pinned.
---

Reading a spec proves nothing about coverage. Breaking the code and watching the suite stay
green proves a great deal. This skill covers the judgment; `~/.claude/scripts/mutate.rb` covers
the mechanics.

$ARGUMENTS

## Reach for this when

- A single expression carries the correctness of a change: a `||` fallback, a type filter, an
  ordering clause, a scoping `where`, a retry budget, an ambiguity guard.
- A spec exists and looks like coverage, but nobody has confirmed it fails when the code breaks.
- Review or a bug report claims something is tested. Verify rather than argue from reading.

Do not mutation-test a whole file for its own sake. Target the expressions the current change
makes load-bearing.

## Workflow

1. **Read the diff and name the failure modes** (free-form — see below).
2. **Write the table** to `./tmp/mutants/table.rb`.
3. **Preflight**: `ruby ~/.claude/scripts/mutate.rb tmp/mutants/table.rb --check`.
4. **Run**: `ruby ~/.claude/scripts/mutate.rb tmp/mutants/table.rb`. It proves the baseline is
   green first, then applies one mutant at a time and restores between each.
5. **Triage every survivor**, close real gaps, re-run to confirm the kill.
6. **Finish**: the runner regenerates `tmp/mutants/mutations.md`. Fill in the triage prose, then
   `--clean` to drop scratch. `table.rb` plus `mutations.md` make the run reproducible.

The runner never guesses. It reports `killed`, `SURVIVED`, `equivalent`, `INVALID` (the suite did
not load — not a result), and `NOT APPLIED` (anchor drift — also not a result).

**Mutate in place.** Do not copy the target into `tmp/` and point rspec at the copy; Rails
autoload resolves by path, so the copy is never loaded and every mutant "survives". The runner
keeps a byte copy in `tmp/mutants/pristine/` purely for recovery from a hard kill.

## Discovering mutants — deliberately free-form

There is no checklist that produces good mutants. The question to hold is:

> What is the plausible wrong version of this line that a careful person would actually write?

A good mutant is a change someone could ship by accident — an inverted guard, a boundary moved
by one, a filter dropped during a "simplification", a fallback removed as dead code. Random
syntactic noise is not worth running.

Some shapes that repeatedly hide gaps:

- **Guards and early returns** — remove it, invert it, make it unconditional.
- **Boundaries** — `<=` to `<`, `>` to `>=`, inclusive range to exclusive.
- **Scoping clauses** — drop the `where(account_id:)`, drop the `batch_id` in a status update.
  These fail silently in tests that only ever have one record.
- **Ordering** — reverse a `sort_by`, swap two arguments, move a step in a chain.
- **Breadth of a `rescue`** — narrow `rescue =>` to `rescue SomeSpecificError`, to check that
  per-item failure isolation is actually exercised.
- **Collection quantifiers** — `all?` to `any?`, `first` to `last`.
- **Constants** — a warmup window to zero, a chunk size to something else, a retry budget to one.
- **Deletions of work** — a line that computes a value but the mutant never writes it.

Write each one as a **named failure mode**, not a description of the edit. `"a manual rerun is
mistaken for a slot, so the real slot is skipped"` earns its place; `"changed <= to <"` does not.
The `failure_mode:` field carries this into the write-up, and the name is what makes a survivor
legible six weeks later.

### Make exactly one guard load-bearing

A scenario that trips two guards at once proves neither. When two guards both survive, suspect a
symmetric test: if either guard alone blocks the case, killing one changes nothing. Write the
asymmetric scenario before concluding the guards are redundant.

### The most common gap shape

**Every existing example stubs the method you are trying to pin, so the real code never runs.**
If a mutant inside a method survives, check whether any spec actually executes it before looking
anywhere else.

## Scoping the specs

List the specs that *ought* to catch the mutant. Too narrow gives false survivors; too wide makes
the sweep slow enough that you stop running it. Start with the covering spec file, and widen only
when triaging a survivor. Per-mutant `specs:` overrides the table default.

## Triaging a survivor

A survivor is a coverage gap **or** an equivalent mutant. The difference has to be argued.

1. **Re-run with a wider spec scope** before calling it a gap. Cheap insurance against bad scoping.
2. **Try to state the observable difference.** If you can describe an input where mutated and
   original produce different output, state, or side effects, it is a gap.
3. **If you cannot, prove equivalence** — an argument about why *no* test could observe it. Not
   "the tests don't happen to cover it"; that is a gap. Record the proof as `equivalent:` in the
   table, so future runs report it as expected rather than crying wolf. If a later run kills it,
   the runner reports `CLAIM REFUTED` and you revisit the proof.

Being wrong here is normal and worth recording. On PR 2581 an equivalence call went the other
way: an analysis claimed a survivor meant "another pipeline's job suppresses this one's slot",
and the two-pipeline test written to catch it **did not kill the mutant**. The claim was wrong.
That is why the next step is not optional.

## Closing a gap

Write the spec, then **re-run the mutant and confirm it now dies**. A test written from a theory
about the gap frequently fails to kill it.

- **Assert the outcome, not the mechanism** — the resulting set, the surviving row id, the value
  delivered. A future rewrite that reintroduces the fault should fail regardless of how it is
  written.
- **Prefer a round-trip over a bounds assertion.** Assert the property the code's own comment
  claims, so the spec stays green under a benign variation and red under the real fault.
- **Make the kill deterministic.** If the fault only manifests for some inputs, pin the input to
  the worst case rather than leaving it to chance, or the guard is flaky.

## The write-up

`tmp/mutants/mutations.md` is regenerated from the ledger every run, so the tally never drifts.
What it cannot write is the triage: each survivor gets a `<!-- TRIAGE -->` placeholder. Replace it
with the argument. A survivor with no argument is worth nothing on the next run.

Keep `table.rb` and `mutations.md`; `--clean` removes the rest. Re-running later is one command,
and the ledger reports what changed (`SURVIVED -> killed` when a gap closes, `killed -> SURVIVED`
when a spec regresses).

## Worked example

PR 2581, `QueueIntervalPipelinesJob`: 14 mutants, 11 killed, 3 survived — 1 real gap, 2 provably
equivalent.

The gap: widening `rand(0..15)` to `rand(0..120)` left the suite green. The comment on
`jitter_mins` states the constraint — jitter stays under 60 minutes so `at.beginning_of_hour`
uniquely recovers slot intent. At 60+, a job lands in the next hour's bucket, the slot is never
recognised as fulfilled, and every run re-enqueues it. Double delivery.

Nothing pinned it because every pre-existing example stubbed `jitter_mins`, so `rand(0..15)` never
executed. It was closed with an idempotency round-trip at worst-case jitter rather than a bounds
assertion, pinning `rand` to the range maximum so the kill is deterministic:

```ruby
allow_any_instance_of(QueueIntervalPipelinesJob).to receive(:jitter_mins).and_call_original
allow_any_instance_of(QueueIntervalPipelinesJob).to receive(:rand) { |_job, range| range.max }
```

That asserts the property the comment claims, so it stays green under a benign `rand(0..59)` and
red under the real fault.
