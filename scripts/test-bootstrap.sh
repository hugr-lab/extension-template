#!/usr/bin/env bash
# The template's checks of bootstrap.sh and of the licensed kind's scripts/check-license-key.sh, on
# clones of this repository's HEAD (commit first). No build; it fetches hugr-lab/extension-ci-tools
# for the key check. Removed by bootstrap.sh.
#
#   scripts/test-bootstrap.sh [<dir>]     clones into <dir> (a temporary directory by default)
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
out=${1:-$(mktemp -d)}
mkdir -p "$out"
failures=0

fail() {
	echo "FAIL: $*" >&2
	failures=$((failures + 1))
}

copy() { # a fresh clone of HEAD, as "Use this template" makes one
	rm -rf "${out:?}/$1"
	git clone -q "$repo" "$out/$1"
	git -C "$out/$1" config user.email test@example.org
	git -C "$out/$1" config user.name test
}

# names and arguments that bootstrap refuses, leaving the copy as it was
copy refused
# each case is its arguments, separated by |
for case in "" "1abc" "Abc" "a-b" "a b" "_a" "$(printf 'a%.0s' {1..65})" "a|--bogus" "a|b|--licensed"; do
	IFS='|' read -r -a args <<<"$case"
	if (cd "$out/refused" && ./bootstrap.sh ${args[@]+"${args[@]}"} >/dev/null 2>&1); then
		fail "bootstrap accepted '$case'"
	fi
done
[ -z "$(git -C "$out/refused" status --porcelain)" ] || fail "a refused bootstrap changed the copy"
(cd "$out/refused" && touch notes.txt && ! ./bootstrap.sh abc >/dev/null 2>&1) ||
	fail "bootstrap ran with an untracked file"
(cd "$out/refused" && rm notes.txt && echo "# x" >>CMakeLists.txt && ! ./bootstrap.sh abc >/dev/null 2>&1) ||
	fail "bootstrap ran over uncommitted changes"

# what both kinds leave
check_common() { # <dir> <name> <Camel>
	local d=$1 name=$2 camel=$3
	[ ! -e "$d/kinds" ] || fail "$d: kinds/ is still there"
	for f in bootstrap.sh .github/workflows/template.yml .github/workflows/ExtensionTemplate.yml \
		scripts/test-bootstrap.sh scripts/test-kista.sh docs/README.md docs/NEXT_README.md; do
		[ ! -e "$d/$f" ] || fail "$d: $f is still there"
	done
	if git -C "$d" grep -n -I -e waddle -e Waddle -e WADDLE -- . >/dev/null; then
		fail "$d: waddle is still named: $(git -C "$d" grep -l -I -e waddle -e Waddle -e WADDLE -- . | tr '\n' ' ')"
	fi
	[ -z "$(git -C "$d" ls-files | grep waddle)" ] || fail "$d: a file is still named waddle"
	for f in "src/${name}_extension.cpp" "src/include/${name}_extension.hpp" "test/sql/${name}.test" \
		.github/workflows/distribution.yml README.md specs/TEMPLATE.md; do
		[ -f "$d/$f" ] || fail "$d: no $f"
	done
	grep -q "class ${camel}Extension" "$d/src/include/${name}_extension.hpp" || fail "$d: no class ${camel}Extension"
	grep -q "extension_name: ${name}\$" "$d/.github/workflows/distribution.yml" || fail "$d: the workflow does not name $name"
	grep -q "^EXT_NAME=${name}\$" "$d/Makefile" || fail "$d: the Makefile does not name $name"
	[ -z "$(git -C "$d" status --porcelain | grep -v '^[MADR] ')" ] || fail "$d: changes left unstaged"
}

# the open kind
copy open
(cd "$out/open" && ./bootstrap.sh my_ext >/dev/null) || fail "open bootstrap failed"
check_common "$out/open" my_ext MyExt
[ "$(git -C "$out/open" config -f .gitmodules submodule.extension-ci-tools.url)" = https://github.com/duckdb/extension-ci-tools ] ||
	fail "open: extension-ci-tools is not DuckDB's"
[ "$(git -C "$out/open" rev-parse HEAD:extension-ci-tools)" = "$(git -C "$out/open" rev-parse :extension-ci-tools)" ] ||
	fail "open: the extension-ci-tools submodule moved"
[ -f "$out/open/LICENSE" ] || fail "open: no LICENSE"
[ ! -e "$out/open/license-key.pem" ] || fail "open: a license-key.pem"
grep -q 'hugr-lab/extension-ci-tools/.github/workflows/_extension_distribution' "$out/open/.github/workflows/distribution.yml" &&
	fail "open: built with hugr-lab's ci-tools"

# the licensed kind
copy licensed
(cd "$out/licensed" && ./bootstrap.sh x1 --licensed >/dev/null) || fail "licensed bootstrap failed"
d=$out/licensed
check_common "$d" x1 X1
[ "$(git -C "$d" config -f .gitmodules submodule.extension-ci-tools.url)" = https://github.com/hugr-lab/extension-ci-tools ] ||
	fail "licensed: extension-ci-tools is not hugr-lab's"
pins=$(grep -o 'hugr-lab/extension-ci-tools/[^ ]*@[0-9a-f]*\|ci_tools_version: [0-9a-f]*' "$d/.github/workflows/distribution.yml" | grep -o '[0-9a-f]\{40\}' | sort -u)
[ "$(echo "$pins" | wc -l | tr -d ' ')" = 1 ] || fail "licensed: the workflow pins several ci-tools commits: $pins"
[ "$(git -C "$d" rev-parse :extension-ci-tools)" = "$pins" ] || fail "licensed: the submodule is not the workflow's pin $pins"
[ ! -e "$d/LICENSE" ] || fail "licensed: DuckDB's LICENSE is still there"
grep -q 'kista::License::Register(loader, "x1")' "$d/src/x1_extension.cpp" || fail "licensed: no Register"
grep -q '^include extension-ci-tools/makefiles/kista.Makefile' "$d/Makefile" || fail "licensed: no kista.Makefile"
grep -q 'override_ci_tools_repository: hugr-lab/extension-ci-tools' "$d/.github/workflows/distribution.yml" ||
	fail "licensed: the build would take DuckDB's ci-tools"

# the licensed kind's key check, with the fork at its pin
git -C "$d" submodule update -q --init extension-ci-tools
key() { (cd "$d" && scripts/check-license-key.sh "$1" >/dev/null 2>&1); }
key refs/heads/main || fail "key check: the test key failed a branch build"
key refs/tags/v1.0.0 && fail "key check: the test key passed a tag build"
cp "$d/license-key.pem" "$out/test-key.pem"
perl -pe 's/\n/\r\n/' "$out/test-key.pem" >"$d/license-key.pem"
key refs/tags/v1.0.0 && fail "key check: a CRLF copy of the test key passed a tag build"
python3 -c 'import sys
lines = open(sys.argv[1]).read().split()
body = "".join(lines[3:-3])
print("-----BEGIN PUBLIC KEY-----")
for i in range(0, len(body), 76):
    print(body[i:i + 76])
print("-----END PUBLIC KEY-----")' "$out/test-key.pem" >"$d/license-key.pem"
[ "$(head -2 "$d/license-key.pem" | tail -1 | wc -c | tr -d ' ')" = 77 ] || fail "key check: the re-wrapped key is not 76 columns"
key refs/tags/v1.0.0 && fail "key check: the test key wrapped at 76 columns passed a tag build"
cp "$d/extension-ci-tools/kista/sdk/cpp/test/keys/test-only-untrusted-2048.pub.pem" "$d/license-key.pem"
key refs/tags/v1.0.0 && fail "key check: the SDK's other test key passed a tag build"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 2>/dev/null | openssl pkey -pubout >"$d/license-key.pem"
key refs/tags/v1.0.0 || fail "key check: an issuer's key failed a tag build"
echo "not a key" >"$d/license-key.pem"
key refs/heads/main && fail "key check: a file without a key passed"

if [ "$failures" -gt 0 ]; then
	echo "$failures check(s) failed" >&2
	exit 1
fi
echo "bootstrap: all checks passed"
