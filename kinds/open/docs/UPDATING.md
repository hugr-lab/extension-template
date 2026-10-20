# Updating DuckDB

The extension builds against the `duckdb` submodule's commit, with DuckDB's `extension-ci-tools` at
a commit of the branch for the same DuckDB line (`v2.0-cyanoptera` for DuckDB 2.0). To move to
another DuckDB:

1. Check out the new DuckDB commit (a release tag, or a commit of a release branch) in `duckdb`, and a
   commit of the matching branch of [duckdb/extension-ci-tools](https://github.com/duckdb/extension-ci-tools)
   in `extension-ci-tools`; set each submodule's `branch` in `.gitmodules` to that line.
2. In `.github/workflows/distribution.yml`, set every `duckdb/extension-ci-tools/...@<commit>` and
   its `ci_tools_version:` to the new `extension-ci-tools` commit. The `_kista_publish.yml` pin is
   hugr-lab/extension-ci-tools' and does not depend on DuckDB's version; when you move it, move the
   commit in README.md's `kista_publish.py` download with it.
3. `make`, `make test` and `make format-check`: fix what the new DuckDB changed (below).

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
