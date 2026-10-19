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
| `KISTA_ENVIRONMENT` | variable | the GitHub environment of the publish job, when the binding below names one |
| `KISTA_API_KEY` | secret | a publisher's API key; without it, GitHub's OIDC token |

With OIDC, a kista administrator binds this workflow to a publisher (ids from
`gh api repos/<owner>/<repo> --jq '.owner.id, .id'`):

```text
kista admin publisher github add <tenant> <publisher> -owner-id <id> -repository-id <id> \
  -workflow <owner>/<repo>/.github/workflows/distribution.yml -ref 'refs/tags/v*' \
  [-environment <env>]   # with KISTA_ENVIRONMENT set to the same
```

Anyone who may push a `v*` tag, on any commit, publishes. To require more, set `KISTA_ENVIRONMENT` to
a GitHub environment with protection rules (required reviewers, the tags it allows), and bind the
publisher with the same `-environment`; protect `v*` tags with a ruleset.

kista checks each build and signs it with the channel's key: no signing key is needed in CI. wasm
builds are skipped until kista takes them. See kista's
[Publishing](https://hugr-lab.github.io/duckdb-extension-repository/publishing/) page.

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
