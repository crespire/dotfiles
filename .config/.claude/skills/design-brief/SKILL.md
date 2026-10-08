---
name: design-brief
description: Interview Simmon about a feature request or proposal and write a one-page design brief (goal, non-goals, glossary, ownership, worked example, shared-code impact, open questions) to ~/.claude/briefs/, before any implementation plan or code
user_invocable: true
---

Turn a feature request or proposal into a short design brief through an interview. The brief settles
**what** the feature does and **who owns each decision** before anyone decides **how**. Planning and
code come later and reference the brief.

Simmon's input (the request, a ticket, a rough proposal) arrives as the skill argument or in the next
message. If there is none, ask for it first.

## Rules

- **No implementation in the brief.** No file lists, no class or method designs, no step order, no
  migrations. If the interview drifts into "how", note it as a planning question and come back to
  "what". A brief that names files is turning back into a plan.
- **Ask about behaviour and ownership, not mechanics.** Good: "Should the source decide which state a
  destination keeps, or should the destination's rules?" Bad: "Should the key be a string or a hash?"
- **One topic per round, 1–3 questions per round.** Give a recommendation and the trade-off for each
  question when there is one. Use AskUserQuestion for a choice between named options; ask in prose
  for anything open.
- **Ground questions in the code, but read only.** Read enough of the codebase to know how things work
  today (on main), so questions are about real behaviour. Don't write code during the interview.
- **Name the reader of every new piece of data.** If the design adds a field, label, column or event,
  ask who reads it. If nothing does, it doesn't go in.
- **Flag shared code early.** If the design seems to need changes outside the feature's own area
  (delivery, dedup, uploaders, base classes, shared jobs), raise it as a question with the reason. The
  default answer is that it doesn't.
- **Keep it to about one page.** Simplicity is the point: Simmon must be able to read the brief, and
  later the code, and understand the design without reconstructing it.

## Interview order

Work through these in order, writing each section into the brief as it settles. Revisit an earlier
section when a later answer changes it.

1. **Goal.** One or two sentences: the behaviour wanted, in user terms. Confirm it back.
2. **Non-goals.** What deliberately stays as it is. Propose the obvious ones ("delivery behaves as on
   main") and ask what else.
3. **Glossary.** Every term that could mean two things. One definition each; use them consistently
   from here on.
4. **Who owns what.** Each decision the feature introduces, and the one place that owns it.
5. **Worked example.** One concrete record or request walked through today (main) and with the
   design. Tables, not prose. This is where misunderstandings show up; take time over it.
6. **What else this touches.** Shared code the design needs to change, each with a one-line reason.
   Ideally empty.
7. **Open questions.** Anything unresolved, phrased as a question with options and their costs.

## The artifact

Write the brief to `~/.claude/briefs/<YYYY-MM-DD>-<short-feature-slug>.md` (create the directory if
needed). Create the file after the goal is confirmed and update it as each section settles, so a
partial brief survives an interrupted session. Use this shape:

```markdown
# <Feature>: design brief

Status: draft | agreed   ·   Source: <ticket or request>   ·   Date: <YYYY-MM-DD>

## Goal
## Non-goals
## Glossary
| Term | Definition |
## Who owns what
| Decision | Owner | Why |
## Worked example
## What else this touches
## Open questions
## Planning notes
Implementation questions raised during the interview, for the plan to answer. Not decisions.
```

When every section is settled and Simmon agrees, set `Status: agreed`, give the path, and stop. Don't
start planning or coding unless asked. When a plan is written later, it starts by reading the brief,
and anything new that comes up during implementation goes back to the brief as an open question.
