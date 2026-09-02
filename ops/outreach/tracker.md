# Outreach Tracker Operations

The outreach ledger runs in the dedicated Neon project
`codex-profiles-outreach`, branch `main`, database `neondb`, in Singapore. Neon
is authoritative after cutover. The shipped `codex-profile` Bash CLI does not
use this database.

## Provision Neon

1. In the Neon Console, create `codex-profiles-outreach` in Singapore. Use or
   rename the production branch to `main` and keep the database name `neondb`.
2. Generate the signing material from the repository root:

   ```sh
   node scripts/migrate-outreach-to-neon.mjs keygen
   ```

   This creates `~/.codex-outreach-neon-private.pem` as mode `0600` and writes
   only its public key to `docs/outreach-jwks.json`. Never commit the private
   key.
3. Publish the repository's Pages site, then enable the Data API for
   `main` / `neondb`. Configure a custom RS256 JWT provider with the public JWKS
   URL:

   ```text
   https://ducksss.github.io/codex-profiles/outreach-jwks.json
   ```

   Use audience `codex-profiles-outreach`. Tokens carry subject
   `codex-profiles-outreach-agent` and role `outreach_tracker`. Do not enable
   Neon's automatic public-schema grants; the checked-in schema grants only
   the RPC functions.
4. Copy the unpooled owner connection string and the branch Data API URL into
   the current shell without committing them:

   ```sh
   export NEON_DATABASE_URL='postgresql://.../neondb?sslmode=require'
   export NEON_DATA_API_URL='https://.../rest/v1'
   export NEON_JWT_KEY_FILE="$HOME/.codex-outreach-neon-private.pem" # optional default
   ```

5. Apply the schema as part of the first import. The schema enables RLS on all
   operational tables, gives `outreach_tracker` no table privileges, revokes
   RPC execution from `PUBLIC`, fixes function search paths, and checks
   `auth.user_id()` in every Data API entry point.

The Data API is a branch-scoped HTTP API. Neon documents that it validates the
JWT, supplies `auth.user_id()`, and requires RLS on exposed tables. See
[Data API/RLS guidance](https://neon.com/docs/guides/row-level-security) and
[project management](https://neon.com/docs/manage/projects).

## Tracker commands

All existing target, log, status, claim, and release commands retain their
output and exit-code contract. Claims default to a 15-minute lease; override
that only with `OUTREACH_CLAIM_TTL_MS`.

```sh
node scripts/outreach-tracker.mjs list --json
node scripts/outreach-tracker.mjs get <target-key> --json
node scripts/outreach-tracker.mjs claim <target-key> --by <workflow>
node scripts/outreach-tracker.mjs release <target-key> --by <workflow>
```

Merge Queue operations are:

```sh
node scripts/outreach-tracker.mjs queue list [--status Pending|Merged|Rejected] [--json]
node scripts/outreach-tracker.mjs queue enqueue <key> --by <workflow> \
  --target-data <text> [--linked-target <target-key>] [--notes <text>]
node scripts/outreach-tracker.mjs queue resolve <key> --by <workflow> \
  --status Merged|Rejected [--linked-target <target-key>] \
  [--duplicate-of <queue-key>] [--notes <text>]
```

The tracker signs five-minute JWTs locally with Node's standard crypto library.
It never sends the private key, and errors redact both the key and active JWT.

## Migration and recovery

Keep every snapshot outside the repository and mode `0600`. Export reads all
five Airtable tables, schema metadata, raw records, and relationship pairs,
then embeds a canonical SHA-256.

```sh
export AIRTABLE_TOKEN_FILE="$HOME/.codex-outreach-airtable-token"
node scripts/migrate-outreach-to-neon.mjs export \
  --out /secure/path/outreach-baseline.json
node scripts/migrate-outreach-to-neon.mjs import \
  --in /secure/path/outreach-baseline.json
node scripts/migrate-outreach-to-neon.mjs verify \
  --in /secure/path/outreach-baseline.json
```

`import` refuses any non-empty destination. It applies
`scripts/outreach-neon-schema.sql`, imports the snapshot in one transaction,
stores the complete source snapshot in the restricted
`outreach_private.migration_snapshots` table, and verifies raw records, counts,
nullable fields, and relationship sets before commit.

For final cutover, freeze Airtable writes and require zero active source claims.
Take a full second export because Airtable has no reliable last-modified field,
then sync it against the baseline:

```sh
node scripts/migrate-outreach-to-neon.mjs export \
  --out /secure/path/outreach-final.json
node scripts/migrate-outreach-to-neon.mjs sync \
  --in /secure/path/outreach-final.json \
  --against /secure/path/outreach-baseline.json
node scripts/migrate-outreach-to-neon.mjs verify \
  --in /secure/path/outreach-final.json \
  --against /secure/path/outreach-baseline.json
```

`sync` refuses source deletions, upserts changed and new raw records, rebuilds
all imported links, and is safe to repeat. Any schema, constraint, or comparison
failure rolls back the complete transaction. Before cutover, fix the source,
re-export, and retry. After live Neon writes begin, fix forward in Neon;
Airtable is a read-only historical archive, not a hot rollback target, and is
never dual-written.

After switching `NEON_DATA_API_URL`, run a tracker read, then concurrently claim
an existing `Dead` target from two workflows. Exactly one command must exit 0
and one must exit 3; release the winner before resuming outreach.

## Key rotation

Rotate without a JWT-validation gap:

1. Generate a new private key and JWKS to temporary paths with `keygen`.
2. Publish a JWKS containing both old and new public keys.
3. Wait for the provider's JWKS cache to refresh.
4. Atomically replace the local private key, keep mode `0600`, and run a read
   smoke test.
5. After the five-minute maximum token lifetime plus the provider cache window,
   remove the old public key and publish again.

If a private key is exposed, stop tracker writes, rotate immediately, remove
the compromised public key after the shortest safe overlap, and inspect the
append-only log for unexpected mutations.

## 30-day deletion gate

Keep the Airtable base, its token, and both local migration snapshots untouched
for 30 days after cutover. At the end of the observation window:

1. Re-run Neon verification against the final snapshot.
2. Confirm the live tracker and claim flow are healthy.
3. Request fresh, explicit destructive approval.

Only after that approval may the Airtable base be deleted, its token revoked,
and the temporary local snapshots removed. None of those destructive actions
is pre-authorized. The embedded Neon source snapshot remains, but there is no
independent permanent backup.
