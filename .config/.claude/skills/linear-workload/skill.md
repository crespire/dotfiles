---
name: linear-workload
description: Summarize outstanding Linear tickets assigned to me across all teams in my workspace
user_invocable: true
---

Summarize the user's outstanding Linear workload — staleness-first, grouped by team, with a "Slipping" callout for prioritized tickets that have gone untouched. Renders inline by default; appends to the user's Obsidian Monday note when called with the `obsidian` argument.

All sorting and markdown formatting lives in `render.rb` next to this file. Don't reinvent it inline.

## Arguments

`$ARGUMENTS` — optional:
- *(empty)* — render the summary inline in chat (default).
- `obsidian` — insert the summary at the top of this week's Monday note at `~/repos/obsidian/daily/<year>/<monday>.md`.

## Steps

### 1. Fetch outstanding issues

Make one call to `mcp__claude_ai_Linear__list_issues`:
- `assignee: "me"`
- `limit: 250`
- `orderBy: "updatedAt"`
- `includeArchived: false`

The response will exceed the result token limit because Linear includes full descriptions. The runtime saves the full payload to a tool-results file and the error message tells you the path. Don't try to filter by `state` to make it fit — Linear's `state` parameter matches state name before state type, which silently drops issues whose status name doesn't match the canonical type word (e.g., `A0. Product Backlog`). Filter client-side instead.

```bash
mkdir -p ./tmp
jq -r '.[0].text' "$FILE" \
  | jq -c '.issues
            | map(select(.statusType != "completed" and .statusType != "canceled"))
            | map({id, title, url, priority: .priority.value, status, statusType, updatedAt, project, team, team_key: (.id | split("-")[0])})' \
  > ./tmp/linear_outstanding.json
```

**Pagination check.** Inspect the saved tool-results file's `hasNextPage` and the `updatedAt` of the **last** issue. If `hasNextPage` is true AND that timestamp is within the last 365 days, paginate with `cursor` and merge into `./tmp/linear_outstanding.json`. Otherwise the first page is complete (any further pages are stale completed/canceled).

If the JSON is `[]`, tell the user "Inbox zero — no outstanding Linear tickets assigned to you." and stop.

### 2. Render with `render.rb`

```bash
SKILL_DIR=~/.claude/skills/linear-workload
```

**No-arg invocation (inline):** run the script and read its stdout straight into the chat reply. No file needed.

```bash
ruby "$SKILL_DIR/render.rb" ./tmp/linear_outstanding.json \
  --mode=inline --date=$(date +%Y-%m-%d)
```

**`obsidian` invocation:** redirect to `./tmp/linear_workload_rendered.md` so the insertion step in step 3 can read it back. Use the most recent Monday as the date so the heading reads naturally inside the weekly note.

```bash
ruby "$SKILL_DIR/render.rb" ./tmp/linear_outstanding.json \
  --mode=obsidian --date=$(date -v-Mon +%Y-%m-%d) \
  > ./tmp/linear_workload_rendered.md
```

`--mode=obsidian` shifts every heading down one level so the summary nests cleanly under the weekly note's structure.

### 3. Output

**Default (no arguments):** put the script's stdout directly into the chat reply (your text response, not as a code block or tool output). Done.

**`obsidian` argument:** insert `./tmp/linear_workload_rendered.md` at the top of the Monday note.

1. Path: `~/repos/obsidian/daily/<monday-year>/<monday-date>.md`. If the file does not exist, stop and tell the user — do not create it (the user creates daily notes manually).
2. **Idempotency**: if the file already contains the string `Linear Workload`, warn the user that the note already has a summary and stop without modifying.
3. **Insert at top, after any title.** Read the first non-empty line of the existing note:
   - If it starts with `# ` (H1 title), insert the rendered markdown on the next line, separated by one blank line.
   - Otherwise, insert at line 1, followed by a blank line, then the original content.
4. Tell the user the path and a one-line count, e.g., "Added 54 outstanding issues, 22 slipping, to ~/repos/obsidian/daily/2026/2026-04-27.md". Pull the slipping count from the `⚠️ Slipping (N)` line in `./tmp/linear_workload_rendered.md` (`grep -oE 'Slipping \([0-9]+\)' ./tmp/linear_workload_rendered.md`).

## Rules

- Default output is inline. The `obsidian` argument is the only path that writes to the Obsidian vault.
- Do not mutate any Linear data (no status changes, no comments).
- If the Linear MCP is not connected, tell the user to run `/mcp` to authenticate and stop.
- All rendering logic lives in `render.rb`. To change the format, edit the script — don't reimplement formatting in the skill prose.
- Use `./tmp` for scratch files, not `/tmp`.
