#!/bin/bash
# UserPromptSubmit hook: inject a per-turn reminder so the model verifies
# AR model columns/methods against the model file and schema BEFORE drafting
# any snippet (chat output included — not just Write/Edit).
#
# Emits a small system-reminder via hookSpecificOutput.additionalContext.
# Fires on every user prompt. Cost: ~30 tokens per turn.

jq -nc '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: "Reminder (from ~/.claude/CLAUDE.md): before drafting any code snippet that references an ActiveRecord model — column, association, scope, method — Read the relevant app/models/*.rb file AND db/schema.rb (or db/customer_schema.rb) to confirm the reference exists. This applies to snippets emitted in chat as well as Write/Edit. Hallucinated column/method names erode trust."
  }
}'
