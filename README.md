# hugr-lab's DuckDB extension template

DuckDB's [extension template](https://github.com/duckdb/extension-template) (C++, built against
DuckDB 2.0) with [kista](https://github.com/hugr-lab/duckdb-extension-repository)'s developer kit:
publication to a kista channel from CI, and for a licensed extension, the kista C++ SDK. The design
is kista's spec 0022 (`specs/0022-developer-kit/spec.md` there).

## Two kinds of extension

| | Open | Licensed |
| --- | --- | --- |
| For | MIT, Apache or similar; also in DuckDB's community repository | sold through Enterest, or licensed by its developer |
| `extension-ci-tools` | DuckDB's, unchanged: the community's build exactly | [hugr-lab/extension-ci-tools](https://github.com/hugr-lab/extension-ci-tools): DuckDB's with the SDK |
| Licences | none | the kista SDK; trusted keys from `license-key.pem` or `KISTA_LICENSE_KEYS` |
| Publication | to kista on a `v*` tag | the same; with Enterest, Enterest builds and publishes |

## Making an extension

1. Click **Use this template** on GitHub, then clone your copy:
   `git clone --recurse-submodules <your repository>`.
2. Run, once:

   ```sh
   ./bootstrap.sh <name>              # an open extension
   ./bootstrap.sh <name> --licensed   # a licensed one
   ```

   The name is a lower-case letter, then up to 63 of `a-z`, `0-9` and `_`. Bootstrap renames the
   example (`waddle`) in the sources, tests, CMake and workflows, puts the kind's files in place,
   removes the other kind's and the template's own, and removes itself. For a licensed extension it
   also points the `extension-ci-tools` submodule at hugr-lab's fork. The changes are staged.
3. Review, commit, and build: `git submodule update --init --recursive && make && make test`.

The extension's `README.md` then says how to build, publish (the GitHub variables and the kista
binding) and, for a licensed one, how to set its licence key before the first release.

## This repository

- `kinds/open/` and `kinds/licensed/`: each kind's files, put over the root by `bootstrap.sh`.
- `.github/workflows/template.yml`: the template's own CI. It runs the bootstrap's checks (with the
  licence-key check on the SDK's test keys), bootstraps both kinds, builds and tests them on Linux,
  publishes them to a kista built from a pinned commit as the publication job does, then installs
  and loads them from it with DuckDB.
- `scripts/test-bootstrap.sh`: the bootstrap's own checks (no build); `scripts/test-kista.sh`: the
  publish, install and load check on two built copies, which `template.yml` runs.
- The rest is DuckDB's template, merged from it when we take a change. The branches follow
  DuckDB's; `main` builds against DuckDB `v2.0-cyanoptera`, the commit kista is tested against.
