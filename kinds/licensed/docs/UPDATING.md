# Updating DuckDB and the kit

The extension builds against the `duckdb` submodule's commit, with hugr-lab's
[extension-ci-tools](https://github.com/hugr-lab/extension-ci-tools) (DuckDB's with the kista SDK) at
the commit in the `extension-ci-tools` submodule. The same commit is pinned in
`.github/workflows/distribution.yml`: every `hugr-lab/extension-ci-tools/...@<commit>` and every
`ci_tools_version:`. Move them all together, to a commit of the fork's `main` (its `sdk-v*` tags
mark SDK releases).

**The kit** (a new SDK, or the fork's merge of DuckDB's ci-tools): check out the new commit in
`extension-ci-tools`, set the pins in `distribution.yml` to it, then `make` and `make test`.

**DuckDB:** the SDK is tested against the DuckDB in the fork's `kista/DUCKDB_PIN`. Move `duckdb` to
that commit (or a newer one of the same line, at your risk), together with a fork commit whose
`kista/DUCKDB_PIN` names it; set the `duckdb` submodule's `branch` in `.gitmodules` to the line.
Then `make`, `make test` and `make format-check`, and fix what the new DuckDB changed (below).

A kista channel serves the DuckDB versions its administrator added: a new DuckDB version needs to be
added there before its builds can be published.

# API changes
DuckDB extensions built with this extension template are built against the internal C++ API of DuckDB. This API is not guaranteed to be stable.
What this means for extension development is that when updating your extensions DuckDB target version using the above steps, you may run into the fact that your extension no longer builds properly.

Currently, DuckDB does not (yet) provide a specific change log for these API changes, but it is generally not too hard to figure out what has changed.

For figuring out how and why the C++ API changed, we recommend using the following resources:
- DuckDB's [Release Notes](https://github.com/duckdb/duckdb/releases)
- DuckDB's history of [Core extension patches](https://github.com/duckdb/duckdb/commits/main/.github/patches/extensions)
- The git history of the relevant C++ Header file of the API that has changed
