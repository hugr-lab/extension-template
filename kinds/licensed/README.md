# Waddle

This extension, Waddle, allows you to ... <extension_goal>. It is licensed: what it does depends on a
licence that the [kista](https://github.com/hugr-lab/duckdb-extension-repository) it is installed
from serves, or a licence file beside it.

It was made from [hugr-lab/extension-template](https://github.com/hugr-lab/extension-template), DuckDB's
[extension template](https://github.com/duckdb/extension-template) with the kista developer kit. Its
`extension-ci-tools` submodule is [hugr-lab/extension-ci-tools](https://github.com/hugr-lab/extension-ci-tools)
(DuckDB's ci-tools with the kista C++ SDK, see its
[KISTA.md](https://github.com/hugr-lab/extension-ci-tools/blob/main/KISTA.md)).

## Before the first release: the licence key

`license-key.pem` is the public key this build trusts licences from. **As the template made it, it is
the kista SDK's test key**, whose private half is public: anyone can sign a licence for it. Put the
public key of the issuer that signs your licences there (`openssl pkey -pubout` writes one; RSA-2048).
Until then, a local build warns, and a tag build in CI fails (`scripts/check-license-key.sh`).

## Building

```sh
git clone --recurse-submodules <this repository> && cd <it>
make release                                              # trusts license-key.pem
make release KISTA_LICENSE_KEYS='/keys/a.pem;/keys/b.pem' # trusts these (one to four), not license-key.pem
make test
```

This is the build contract: Enterest's builders run exactly this, with `KISTA_LICENSE_KEYS` set to
the extension's registered keys, and read the keys back from the binary. Take keys only from
`KISTA_LICENSE_KEYS` or `license-key.pem`, as `CMakeLists.txt` does.

The example links OpenSSL through vcpkg (`vcpkg.json`): set `VCPKG_TOOLCHAIN_PATH` as DuckDB's
[template guide](https://github.com/duckdb/extension-template/blob/main/docs/README.md) says, or remove
the dependency. The loadable extension is `build/release/extension/waddle/waddle.duckdb_extension`.

## The licence in the code

`src/waddle_extension.cpp` shows the SDK's use:

- `kista::License::Register(loader, "waddle")` in the load function. It adds `waddle_license()`, a
  table function with the licence's status, plan, holder, limits and expiry, and
  `waddle_license_refresh()`.
- `waddle_pro()` needs a licence: `kista::License::Get(context, "waddle")`, then `Check()`, which
  throws unless the licence is valid or in grace, and `Limit<T>()` for what the plan allows.
- `kista::Usage::Send` and `SendAsync` report use to the repository the extension was installed
  from, when the extension decides to.

See the SDK's [README](https://github.com/hugr-lab/extension-ci-tools/blob/main/kista/sdk/cpp/README.md).
`make test` checks that without a licence, the status is `missing` and `waddle_pro()` is refused.

## CI and publishing

`.github/workflows/distribution.yml` checks the licence key, then builds every platform of DuckDB's
matrix with hugr-lab's ci-tools on each push and pull request. On a `v*` tag it also publishes the
builds to a kista channel, when the repository has the `KISTA_URL` variable. Configuration is in the
repository's variables and secrets, never in the code:

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

For kista to record the build's licence keys (kista spec 0021), a server administrator also marks
the publisher: `kista admin publisher license-keys <tenant> <publisher> on`. With Enterest, Enterest
builds and publishes instead.

Anyone who may push a `v*` tag, on any commit, publishes. To require more, set `KISTA_ENVIRONMENT` to
a GitHub environment with protection rules (required reviewers, the tags it allows), and bind the
publisher with the same `-environment`; protect `v*` tags with a ruleset.

kista checks each build and signs it with the channel's key: no signing key is needed in CI. wasm
builds are skipped until kista takes them. See kista's
[Publishing](https://hugr-lab.github.io/duckdb-extension-repository/publishing/) and
[Licensing](https://hugr-lab.github.io/duckdb-extension-repository/licensing/) pages.

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
SELECT status, plan, expires_at FROM waddle_license();
```

See kista's [Using kista from DuckDB](https://hugr-lab.github.io/duckdb-extension-repository/duckdb/)
page, including how to get httpfs from kista itself.

## Updating

DuckDB is the `duckdb` submodule's commit, and the kit is hugr-lab/extension-ci-tools' commit in
the `extension-ci-tools` submodule and in `distribution.yml`; see [docs/UPDATING.md](docs/UPDATING.md).

## Licence

The template's example code is DuckDB's (MIT). Choose this extension's licence and add it as
`LICENSE`.

## Specs

`specs/` holds one short spec per feature (`specs/TEMPLATE.md`), written before the code.
