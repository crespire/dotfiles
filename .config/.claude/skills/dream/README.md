# dream

A nightly maintenance pass over the Obsidian knowledge store. It tags every file for
grep-based recall, consolidates duplicate memories, regenerates the tag catalog, and checks
its own work with a second agent.

This file is for the operator. Claude never loads it — only `SKILL.md` enters context on
invocation, and only the `description` in that file's frontmatter enters context otherwise.

## Setup

### Parts

| Path | Purpose | Tracked |
|---|---|---|
| `~/.claude/skills/dream/SKILL.md` | Instructions to the agent. Loaded on every run. | yes |
| `~/.claude/skills/dream/territory.json` | Template: the shape, with placeholder paths. | yes |
| `~/.claude/skills/dream/territory.local.json` | Live config: real paths and modes. | no |
| `~/.claude/skills/dream/state.json` | Content hash per file, for incremental runs. | no |
| `~/.claude/skills/dream/snapshots/` | Pre-run copies. Pruned at 14 days. | no |
| `~/.claude/skills/dream/last-run.log` | stdout and stderr of the scheduled run. | no |
| `~/.claude/scripts/dream/` | The harness: eight scripts and a selftest. | yes |
| `$VAULT/knowledge/` | The store. Files are the system of record. | in the vault |

The four untracked paths are machine-local and appear in the dotfiles `.gitignore`.

This document writes `$VAULT` for the Obsidian vault and `$HOME` for the home directory,
because the dotfiles repository is public. `territory.local.json` holds the real paths and
is gitignored; `territory.json` is a committed template. The LaunchAgent is the exception —
launchd expands nothing, so its plist must carry absolute paths.

### First-time setup

1. Copy `territory.json` to `territory.local.json` and set `vault` and `directories` to real
   paths. The local file is gitignored and its top-level keys override the template.
2. Set `autoMemoryEnabled` and `autoMemoryDirectory` in `~/.claude/settings.json` (below).
3. Write the LaunchAgent (below), substituting real absolute paths.
4. Run the dry run (below). Do not skip it — it is the only check that the job works in
   launchd's empty environment rather than in a shell that has a profile.
5. `launchctl load` the agent.

The first run tags every file and takes far longer than a nightly pass. Run it by hand,
with Obsidian closed, and read `DREAM.md` afterwards.

### Store location

`~/.claude/settings.json` points auto-memory at the vault:

```json
"autoMemoryEnabled": true,
"autoMemoryDirectory": "$VAULT/knowledge"
```

Without `autoMemoryDirectory` the harness writes memories per project, under
`~/.claude/projects/<sanitized-cwd>/memory/`, and no project sees another project's
memories. One directory makes the store global.

### Territory

`territory.local.json` defines scope. Two modes:

- `consolidate` — machine-written memories. The run may merge, rewrite, retag and archive.
- `tag-only` — prose the operator wrote. The run may add or correct frontmatter only.

`exclude` lists paths the run never reads, each with its reason. To add a directory, add an
entry to `directories`; to protect a path, add one to `exclude`. Every script reads scope
from this file, so a change applies to all of them at once.

### Schedule

The LaunchAgent lives at `~/Library/LaunchAgents/com.<user>.claude-dream.plist` and runs
at 04:00. `StartCalendarInterval` runs a missed job on the next wake, and coalesces several
missed intervals into one run.

`caffeinate -is` wraps the harness because the scheduled hour is an hour the machine sleeps.
With the lid shut the system sleeps whatever `pmset sleep` says, and Power Nap then grants a
LaunchAgent about 45 seconds per dark wake. Without the assertion the run advances one step
per wake, every API stream dies mid-response, and the counter pass — a subagent that needs
several minutes — is killed. The wrapper holds the machine awake for the length of the run.

The job needs four environment variables, because launchd supplies no shell profile:

| Variable | Reason |
|---|---|
| `PATH` with `~/.asdf/shims` first | The harness needs the asdf Ruby. The shims path is stable across Ruby upgrades. |
| `LANG=en_US.UTF-8` | Subprocesses default to US-ASCII otherwise and raise on the first em-dash. |
| `USER`, `LOGNAME` | Keychain lookup needs them. Without them the run reports `Not logged in`. |

launchd expands no variables, so every path below is literal. Substitute `<user>` and
`<vault>`, then write the file:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.<user>.claude-dream</string>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>4</integer><key>Minute</key><integer>0</integer></dict>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/Users/<user>/.asdf/shims:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>LANG</key><string>en_US.UTF-8</string>
    <key>USER</key><string><user></string>
    <key>LOGNAME</key><string><user></string>
  </dict>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/caffeinate</string><string>-is</string>
    <string>/Users/<user>/.local/bin/claude</string>
    <string>-p</string><string>/dream</string>
    <string>--add-dir</string><string><vault></string>
    <string>--permission-mode</string><string>bypassPermissions</string>
    <string>--settings</string>
    <string>{"autoMemoryEnabled":false,"skipDangerousModePermissionPrompt":true}</string>
  </array>
  <key>WorkingDirectory</key><string><vault></string>
  <key>StandardOutPath</key><string>/Users/<user>/.claude/skills/dream/last-run.log</string>
  <key>StandardErrorPath</key><string>/Users/<user>/.claude/skills/dream/last-run.log</string>
  <key>RunAtLoad</key><false/>
</dict>
</plist>
```

Check it with `plutil -lint <path>`, then `launchctl load <path>`. Unload with
`launchctl unload <path>`. `RunAtLoad` is false deliberately: loading the agent should not
start a run.

### Requirements

- **The login keychain must be unlocked.** Credentials live there, not in a file. The
  keychain stays unlocked while the operator is logged in, including with the lid shut. After
  a restart the 04:00 run fails until the next login. `last-run.log` reports `Not logged in`.
- **The machine must be on AC power.** `caffeinate -s` asserts nothing on battery, so a run
  that starts on battery gets the 45-second dark-wake window and stalls partway.
- **Obsidian should be closed at the scheduled hour.** The obsidian-git plugin commits hourly
  while Obsidian runs. With Obsidian closed, the run holds the repository alone and produces
  one commit. With Obsidian open, the plugin may commit part of the run first, and one run
  then spans two commits.

### Dry run

Run the scheduled command by hand before loading the agent. `env -i` reproduces launchd's
empty environment:

```
cd "$VAULT" && env -i \
  PATH=$HOME/.asdf/shims:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin \
  LANG=en_US.UTF-8 HOME="$HOME" USER="$USER" LOGNAME="$USER" \
  "$(command -v claude)" -p /dream \
  --add-dir "$VAULT" \
  --permission-mode bypassPermissions \
  --settings '{"autoMemoryEnabled":false,"skipDangerousModePermissionPrompt":true}'
```

`--settings` applies to that process only and changes no file. `autoMemoryEnabled:false`
stops the run from writing memories into the store it maintains.

`bypassPermissions` skips the permission prompt, which an unattended job cannot answer. It
does not skip hooks: `block-rm.sh`, `block-bq.sh`, `block-never-rules.sh` and
`block-bash-file-edits.sh` all still run, and all four need `jq`, which sits at `/usr/bin/jq`
and stays on launchd's PATH.

## Execution

`state.rb --list` names the files a run processes: those whose content hash differs from the
last run's, plus any file with no `tags:` key. The first run after a reset processes
everything.

### 1. Snapshot

`snapshot.rb --write` copies every in-scope file to `snapshots/<date>/`, outside the vault —
not a predicted subset, since steps 3 and 4 touch files the hash check never selected. The
counter pass compares against these copies, and they survive a `git reset --hard`. `prune.rb`
removes directories older than 14 days.

### 2. Tag

Adds or merges a top-level `tags:` key. `apply_tags.rb` takes a TSV of path and tags and
rewrites frontmatter in whatever shape it finds.

The tag-only guarantee rests on refusal, not on care. A leading `---` is not proof of
frontmatter — a note may open with a horizontal rule, and the next rule then looks exactly
like a closing fence — so `Dream.frontmatter` requires the block to parse as a YAML mapping
and every writer skips a file that fails. Refused files are reported and left byte-identical,
and the script exits non-zero. Tagging has no cap.

Each file carries one `scope/` value, one `form/` value, and any number of subject tags:

```yaml
tags: [scope/portable, form/preference, ruby, code-style]
```

### 3. Consolidate

Applies to `consolidate` directories only. The run merges memories that state the same fact
and rewrites the survivor as a problem shape with its solution shape. Where two statements
disagree, the newer statement wins. Superseded memories move to `knowledge/archive/<date>/`.
No file is ever deleted.

There is no cap: the audit trail is the protection. Every touched file is snapshotted
outside the vault, the counter pass compares against it, and the run is one revertible commit.

### 4. Fold synonym tags

`synonyms.rb` proposes candidates from two kinds of evidence: spelling drift (plural,
separator, case) and tag coverage (two tags over the same files). It does not guess at
acronyms, because a shared prefix is not evidence — `sti` does not abbreviate `stimulus`.
Spotting `sfdc` against `salesforce` is the agent's job, from the catalog.

`rename_tag.rb OLD NEW --write` applies the fold. It is the only script that can retire a
tag, since `apply_tags` merges as a union. A tag the operator wrote by hand survives as the
target rather than being rewritten.

### 5. Regenerate the catalog

Rewrites `knowledge/MEMORY.md` as the tag catalog: every tag, its meaning, and its file
count. The next run reads this before it coins a term.

### 6. Write the change proposal

Overwrites `knowledge/DREAM.md`. One file at one path, so its git history is the run history.
It records merges, rewrites, tags, folds and archives.

### 7. Counter pass

A second agent with no access to the run's reasoning — one that inherits it ratifies its own
work. It runs `validate.rb`, then compares the snapshots against the current files.

- It restores content that a snapshot holds and the survivor lost.
- It records defensible merges the operator may disagree with, and changes nothing.
- It reports the wanted list: memories a sibling links to that do not exist yet.
- It appends its findings to `DREAM.md`.

### 8. Record state, then commit

`state.rb` records the content hashes. It runs after the counter pass, so the hashes
describe the corrected tree rather than a state that was never on disk. The run then commits
as `Finished dreaming: <counts>`, and never pushes.

## Checking a run

```
ruby ~/.claude/scripts/dream/validate.rb    # every invariant; exit 1 on failure
ruby ~/.claude/scripts/dream/synonyms.rb    # fold candidates
cd "$VAULT" && git show --stat HEAD         # what the run changed
```

`validate.rb` also reports two lists that are not failures: memories a sibling links to that
do not exist yet, and dangling links that do not match the memory naming convention.

A file the writers refuse — one opening with a horizontal rule, or whose frontmatter already
did not parse — shows as a failure, so a store holding one never exits clean. That is
deliberate: it is a file no run can tag until a human fixes it. Repair it by hand, or move it
out of territory.

## Changing the harness

| Script | Writes? | Role |
|---|---|---|
| `lib.rb` | — | Territory, scope, frontmatter and tag parsing. Everything requires it. |
| `validate.rb` | no | Every invariant, plus the wanted list. `--counts` emits the catalog lines. Exit 1 on failure. |
| `synonyms.rb` | no | Fold candidates from spelling drift and tag coverage. |
| `apply_tags.rb` | yes | Inserts and merges `tags:`. Frontmatter only, union only. |
| `rename_tag.rb` | yes | Retires one tag in favour of another. |
| `snapshot.rb` | yes | Copies every in-scope file to a dated directory outside the vault. |
| `state.rb` | yes | Content hashes. `--list` names the files a run should process. |
| `prune.rb` | yes | Removes snapshot directories past the retention window. `--days N` overrides the default 14. |

Every writer is dry-run by default, takes `--write`, and exits non-zero when it refused a
file. `DREAM_TERRITORY` and `DREAM_STATE` override the config and state paths; `lib.rb`
resolves both into constants at load time, so they must be set before it is required.

```
ruby ~/.claude/scripts/dream/selftest.rb
```

Checks the harness against a fixture vault in a temporary directory, with both env overrides
pointed at it, so it never reads or writes the real store. Run it after any change to a
script.

The fixtures deliberately include shapes the code has to refuse — zero-indent and ragged tag
lists, duplicate `tags:` keys, an unclosed fence, a filename full of YAML metacharacters —
because a suite built only from shapes that work proves nothing about the ones that do not.

The load-bearing check is that every written file still has parseable frontmatter. The
body-unchanged check cannot fail by construction: the writers only ever splice inside the
frontmatter, so a body survives no matter how badly the block above it is mangled.

## Recovery

Every run is one commit, so `git revert <sha>` undoes one night. `git reset --hard <sha>`
returns the vault to an earlier state, and the snapshots outside the vault survive it.
