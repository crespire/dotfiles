---
name: code-review
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
