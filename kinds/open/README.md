# Waddle

This extension, Waddle, allows you to ... <extension_goal>.

It was made from [hugr-lab/extension-template](https://github.com/hugr-lab/extension-template), DuckDB's
[extension template](https://github.com/duckdb/extension-template) with publication to a
[kista](https://github.com/hugr-lab/duckdb-extension-repository) channel. It builds with DuckDB's own
`extension-ci-tools`, exactly as DuckDB's community repository builds it.

## Building

```sh
git clone --recurse-submodules <this repository> && cd <it>
make            # or: GEN=ninja make release
```

The example links OpenSSL through vcpkg (`vcpkg.json`): set `VCPKG_TOOLCHAIN_PATH` as DuckDB's
[template guide](https://github.com/duckdb/extension-template/blob/main/docs/README.md) says, or remove
the dependency. The build writes:

```text
./build/release/duckdb                                       the shell
./build/release/test/unittest                                the test runner
./build/release/extension/waddle/waddle.duckdb_extension     the loadable extension
```

## Running and testing

```sh
./build/release/duckdb -unsigned -c "LOAD 'build/release/extension/waddle/waddle.duckdb_extension'; SELECT waddle('Jane');"
make test        # the SQL tests in test/sql
```

## CI and publishing

`.github/workflows/distribution.yml` builds every platform of DuckDB's matrix on each push and pull
request. On a `v*` tag it also publishes the builds to a kista channel, when the repository has the
`KISTA_URL` variable. Configuration is in the repository's variables and secrets, never in the code:

| Name | Kind | What |
| --- | --- | --- |
| `KISTA_URL` | variable | the kista's public URL, e.g. `https://kista.example.org` |
| `KISTA_TENANT`, `KISTA_CHANNEL` | variables | where the builds go |
| `KISTA_VISIBILITY` | variable | `private` (the default) or `public` |
| `KISTA_ENVIRONMENT` | variable | the GitHub environment of the publish job, whose secret holds the key |
| `KISTA_PUBLISHER_KEY` | secret | the publisher's private SSH key: each request is signed with it |

**The publisher key** (kista spec 0023). The publisher signs each request with an SSH key, as you
sign in to GitHub with one; kista holds only the public half. Once:

```sh
d=$(mktemp -d)    # the key stays out of the repository
ssh-keygen -t ed25519 -N '' -C waddle-ci -f "$d/publisher_key"

# kista's administrator: the publisher, what it may publish, and the key's public half
kista admin publisher add <tenant> <publisher>
kista admin grant add <tenant> -principal publisher:<publisher> -verb publish -channel <channel> -extension waddle
kista admin publisher key add <tenant> <publisher> "$d/publisher_key.pub" -expires 365d

# check the key and its grant: kista answers with the publisher and what it may publish
# the fork's publication script, at the commit distribution.yml pins (docs/UPDATING.md)
curl -fsSLo "$d/kista_publish.py" \
  https://raw.githubusercontent.com/hugr-lab/extension-ci-tools/c501c26be0c1fe484639138b449355ccc30b945a/scripts/kista_publish.py
KISTA_PUBLISHER_KEY="$d/publisher_key" python3 "$d/kista_publish.py" \
  --url <kista URL> --tenant <tenant> --channel <channel> --check

# an environment only v* tags may deploy to, the key as its secret, and the variables
gh api -X PUT repos/<owner>/<repo>/environments/release --input - \
  <<< '{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}'
gh api -X POST repos/<owner>/<repo>/environments/release/deployment-branch-policies -f name='v*' -f type=tag
gh secret set KISTA_PUBLISHER_KEY --env release < "$d/publisher_key"
gh variable set KISTA_ENVIRONMENT --body release
gh variable set KISTA_URL --body <kista URL>
gh variable set KISTA_TENANT --body <tenant>
gh variable set KISTA_CHANNEL --body <channel>
rm -r "$d"
```

Only a job of a `v*` tag may run in the `release` environment, so only it reads the key: a workflow
pushed on a branch cannot. Anyone who may push a `v*` tag, on any commit, still publishes: protect
`v*` tags with a ruleset, and add required reviewers to the environment. An environment without
such rules gives the key to any workflow of the repository. To replace the key, register the new
one, replace the secret, then remove the old one in kista.

kista checks each build and signs it with the channel's key: no signing key is needed in CI. wasm
builds are skipped until kista takes them. See kista's
[Publishing](https://hugr-lab.github.io/duckdb-extension-repository/publishing/) page.

The kista job also takes `catalogue: true` in place of `channel` (into the tenant's catalogue only,
for the channels' rules to take, with a tenant-wide publish grant; a publisher with a hold publishes
so), and `entry_summary` and `icon` (a square PNG of the repository, 64 to 512 pixels), which
set the catalogue entry's summary and icon after its builds; see the fork's
[KISTA.md](https://github.com/hugr-lab/extension-ci-tools/blob/main/KISTA.md).

To publish to DuckDB's community repository as well, submit the extension as the
[community extensions](https://github.com/duckdb/community-extensions) repository describes: it
builds this repository the same way.

## Installing from kista

DuckDB reads the channel's keys from its `.well-known` file through httpfs. A private release (the
default, `KISTA_VISIBILITY`) also needs a token that may install it, in an http secret scoped to the
channel; a public one does not:

```sql
SET allow_extension_repositories = 'allowed';
LOAD httpfs;
CREATE SECRET acme_token (TYPE http, BEARER_TOKEN '<token>',
  SCOPE 'https://kista.example.org/<tenant>/<channel>/');   -- private releases only
CREATE EXTENSION REPOSITORY acme WITH PREFIX 'https://kista.example.org/<tenant>/<channel>';
INSTALL waddle FROM acme;
LOAD waddle FROM acme;
```

See kista's [Using kista from DuckDB](https://hugr-lab.github.io/duckdb-extension-repository/duckdb/)
page, including how to get httpfs from kista itself.

## Updating DuckDB

DuckDB is the `duckdb` submodule's commit; see [docs/UPDATING.md](docs/UPDATING.md).

## Specs

`specs/` holds one short spec per feature (`specs/TEMPLATE.md`), written before the code.
