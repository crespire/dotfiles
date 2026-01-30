---
name: debug
description: Investigate a bug, understand root cause, and plan a fix
---

Use the codebase-investigator agent to research and debug the following issue:

$ARGUMENTS

When investigating the bug:
1. First check for a CLAUDE.md file in the project root for project-specific context and conventions
2. Identify the affected code paths and trace the bug through the codebase
3. Find related tests, error handling, and edge cases
4. Determine the root cause of the issue
5. Reference specific file paths and line numbers

After investigation, provide:

**Summary**: A concise explanation of what the bug is and why it occurs

**Root Cause**: The specific code or logic causing the issue

**Fix Plan**: Step-by-step plan to resolve the bug, including:
- Which files need to be modified
- What changes are required
- Any tests that should be added or updated
- Potential side effects or risks to consider
