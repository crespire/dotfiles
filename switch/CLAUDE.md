# Switch instructions

Apply to every Switch repository and worktree under `~/repos/switch/`. Claude Code loads this file because it sits in a parent directory of each checkout, so a new worktree needs no setup. The source lives in dotfiles at `./switch/CLAUDE.md`, and `install.sh` links it into place. Rules for every project stay in `~/.claude/CLAUDE.md`.

## Never do these

No judgment call, no exceptions, no "unless it seems right here."

- **Never hand-edit `db/schema.rb`** (or `db/customer_schema.rb`, `db/reporting_schema.rb`), and don't `git checkout`/`git restore` them to revert either — both make the dump diverge from what `db:migrate` produces. Change migrations and run them; roll back before deleting a migration file.
- **Never change a prod Postgres session setting with bare `SET`.** Connections are pooled, so the setting rides along to the next query, and a raised query skips the manual `RESET`. Wrap it: `SET LOCAL` inside a transaction ending in `raise ActiveRecord::Rollback`.
- **Never add an ActiveRecord lifecycle callback** (`before_validation`, `before_save`, `after_create` and the rest). A callback hides a derivation in the model, where the next reader mistakes the default for the rule. Set the value explicitly at every creation site, `spec/fixture_kit/` fixtures included, even when that means many edits.
- **Never commit a production record as a fixture without anonymizing it.** Substitute by value, not by field: names, emails, phones, postal codes, click IDs, IPs, user agents, Salesforce user IDs, and diagnostic blocks that list other records' IDs. Keep the subject record's own ID.
- **Never guard a mutation script with a substring match.** A script that changes remote or production state by an opaque ID takes `id => {from:, to:}`, raises `ArgumentError` at construction when either is missing, and matches the current value exactly.

## Rails console scripting & diagnostics

- **Verify columns, associations, and methods exist before suggesting them.** Read `app/models/*.rb` and `db/schema.rb` (or `db/customer_schema.rb`) — don't guess from convention. When a model has `serialize :data, coder: Switch::X`, the JSONB shape comes from that class, not arbitrary keys. When unsure of column names, dump `record.attributes` and let the schema reveal itself.
- **Buffer intermediate values.** SQL log output interleaves with return values, so assign each value into one hash, end the block with `nil`, then evaluate the hash.
- **Show a buffer whole; never chain sub-access.** `buffer` bare on its own line, or `File.write("tmp/…", JSON.pretty_generate(buffer))` and read it back. Never `buffer[:a]; buffer[:b]` — IRB echoes only the last expression and silently swallows the rest.
