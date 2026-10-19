#!/usr/bin/env bash
# Makes this copy of hugr-lab/extension-template an extension: run once, in a fresh copy.
#
#   ./bootstrap.sh <name>              an open extension (MIT, Apache, the community's build)
#   ./bootstrap.sh <name> --licensed   a licensed one (the kista SDK, hugr-lab/extension-ci-tools)
#   --no-format                        leave the formatting (make format-fix) to you
#
# It renames the example extension (waddle) to <name> in the sources, tests, CMake and workflows,
# puts the kind's files in place, removes the other kind's and the template's own, formats the
# sources as DuckDB's format check wants them, and removes itself. Everything it changes is staged,
# for a look before the first commit. See README.md and kista's spec 0022
# (hugr-lab/duckdb-extension-repository).
set -Eeuo pipefail

usage() {
	echo "usage: ./bootstrap.sh <name> [--licensed] [--no-format]" >&2
	exit 2
}

name=""
kind=open
format=yes
for arg in "$@"; do
	case "$arg" in
	--licensed) kind=licensed ;;
	--no-format) format=no ;;
	-*) usage ;;
	*) [ -z "$name" ] || usage; name=$arg ;;
	esac
done
[ -n "$name" ] || usage

# a kista extension name ([a-z0-9_]{1,64}) that is also a C++ identifier
if ! [[ "$name" =~ ^[a-z][a-z0-9_]{0,63}$ ]]; then
	echo "bootstrap: the name must be a lower-case letter, then up to 63 of a-z, 0-9 and _: $name" >&2
	exit 2
fi

cd "$(dirname "$0")"
if [ ! -d kinds/open ] || [ ! -d kinds/licensed ] || [ "$(git rev-parse --show-toplevel 2>/dev/null)" != "$(pwd -P)" ]; then
	echo "bootstrap: run it once, at the top of a git copy of the template (kinds/ is gone after a bootstrap)" >&2
	exit 2
fi
# untracked files too: bootstrap stages everything it leaves, and would stage them with it
if [ -n "$(git status --porcelain)" ]; then
	echo "bootstrap: commit, stash or remove your changes and untracked files first" >&2
	exit 2
fi

if [ "$kind" = licensed ]; then
	# the fork's commit the licensed workflow pins (one pin for it and the submodule), fetched before
	# anything changes, so that a failure here leaves the copy as it was
	pin=$(sed -n 's|.*hugr-lab/extension-ci-tools/\.github/workflows/_extension_distribution\.yml@\([0-9a-f]\{40\}\).*|\1|p' \
		kinds/licensed/.github/workflows/distribution.yml | head -1)
	if [ -z "$pin" ]; then
		echo "bootstrap: no hugr-lab/extension-ci-tools commit in kinds/licensed/.github/workflows/distribution.yml" >&2
		exit 1
	fi
	if [ -e extension-ci-tools/.git ]; then
		git -C extension-ci-tools fetch -q https://github.com/hugr-lab/extension-ci-tools "$pin"
	fi
fi

# from here on, a failure leaves a half-made copy: say how to start again
trap 'echo "bootstrap: failed; to start again: git reset -q --hard && git clean -qfd && git submodule sync -q" >&2' ERR

# Waddle in names of types (my_ext: MyExt), WADDLE in macros
camel=$(printf '%s' "$name" | awk -F_ '{for (i = 1; i <= NF; i++) printf "%s%s", toupper(substr($i, 1, 1)), substr($i, 2)}')
upper=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')

# the kind's files over the template's
cp -R "kinds/$kind/." .
git rm -rq kinds

# the template's own files
for f in .github/workflows/template.yml .github/workflows/ExtensionTemplate.yml \
	scripts/bootstrap-template.py scripts/test-bootstrap.sh scripts/test-kista.sh docs/README.md docs/NEXT_README.md; do
	if [ -e "$f" ]; then git rm -q "$f"; fi
done
if [ "$kind" = licensed ]; then
	# DuckDB's MIT licence of the example; a licensed extension has a licence of its own
	git rm -q LICENSE
fi
git add -A

# rename in the files (never in the submodules) and then the files themselves
git ls-files -s | awk '$1 != "160000" {sub(/^[^\t]*\t/, ""); print}' | grep -v '^bootstrap\.sh$' | while IFS= read -r f; do
	if grep -Iq . "$f" 2>/dev/null && grep -q -e waddle -e Waddle -e WADDLE "$f"; then
		NAME="$name" CAMEL="$camel" UPPER="$upper" perl -pi -e 's/waddle/$ENV{NAME}/g; s/Waddle/$ENV{CAMEL}/g; s/WADDLE/$ENV{UPPER}/g' "$f"
	fi
done
git ls-files | grep waddle | while IFS= read -r f; do
	mkdir -p "$(dirname "${f//waddle/$name}")"
	git mv "$f" "${f//waddle/$name}"
done

if [ "$kind" = licensed ]; then
	# the fork as extension-ci-tools, at the pin
	git config -f .gitmodules submodule.extension-ci-tools.url https://github.com/hugr-lab/extension-ci-tools
	git config -f .gitmodules submodule.extension-ci-tools.branch main
	git update-index --cacheinfo "160000,$pin,extension-ci-tools"
	git submodule sync -q extension-ci-tools
	if [ -e extension-ci-tools/.git ]; then
		git -C extension-ci-tools checkout -q "$pin"
	fi
fi

# The renamed lines are longer or shorter: format as the distribution's format check does (DuckDB's
# scripts/format.py, with the tool versions of extension-ci-tools' _extension_code_quality.yml).
formatted=no
if [ "$format" = yes ] && [ -f duckdb/scripts/format.py ]; then
	if ! { clang-format --version 2>/dev/null | grep -q 'version 11\.' && command -v cmake-format >/dev/null && command -v black >/dev/null; }; then
		venv=$(mktemp -d)
		trap 'rm -rf "$venv"' EXIT
		echo "bootstrap: installing DuckDB's formatters into $venv (--no-format skips this)"
		# wheels only: clang_format 11 has none for some platforms (Linux arm64), and its source
		# build is LLVM's
		if python3 -m venv "$venv" && "$venv/bin/pip" install -q --disable-pip-version-check --only-binary=:all: \
			'clang_format==11.0.1' cmake-format 'black==24.*' >/dev/null 2>&1; then
			PATH="$venv/bin:$PATH"
		fi
	fi
	if make format-fix >/dev/null 2>&1; then
		formatted=yes
	fi
fi

git rm -q bootstrap.sh
git add -A

echo "bootstrap: $name, an extension of the $kind kind. The changes are staged: review them, then commit."
if [ "$formatted" = no ]; then
	echo "Not formatted: run make format-fix (clang-format 11, cmake-format, black) before the first push,"
	echo "or DuckDB's format check fails on the renamed lines."
fi
echo "Then: git submodule update --init --recursive && make && make test"
