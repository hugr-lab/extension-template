#!/usr/bin/env bash
# Refuses a tag build whose license-key.pem is one of the kista SDK's test keys (their private halves
# are public, so anyone could sign a licence for them); warns on any other build.
#
#   scripts/check-license-key.sh <git ref>      e.g. "$GITHUB_REF"; refs/tags/... is a tag build
#
# Keys are compared as DER, so a re-wrapped or CRLF copy of a test key is still a test key. A build
# with KISTA_LICENSE_KEYS (Enterest's) does not read license-key.pem and is not checked here.
set -euo pipefail
cd "$(dirname "$0")/.."

ref=${1:-}
sdk=extension-ci-tools/kista/sdk/cpp
if [ ! -d "$sdk/test/keys" ]; then
	echo "check-license-key: $sdk is not there: git submodule update --init extension-ci-tools" >&2
	exit 1
fi

# the SHA-256 of the DER public key in a PEM file (a public or a private key)
fingerprint() {
	{ openssl pkey -pubin -in "$1" -outform DER 2>/dev/null || openssl pkey -in "$1" -pubout -outform DER 2>/dev/null || true; } |
		openssl dgst -sha256 -r | cut -d' ' -f1
}
none=$(printf '' | openssl dgst -sha256 -r | cut -d' ' -f1)

own=$(fingerprint license-key.pem)
if [ "$own" = "$none" ]; then
	echo "::error file=license-key.pem::license-key.pem holds no public key (openssl pkey -pubout writes one)"
	exit 1
fi

for f in "$sdk"/test/keys/*.pem "$sdk"/test/vectors/*.pem; do
	if [ "$(fingerprint "$f")" = "$own" ]; then
		msg="license-key.pem is the kista SDK's test key ($(basename "$f")): put the public key of the issuer that signs this extension's licences there"
		case "$ref" in
		refs/tags/*)
			echo "::error file=license-key.pem::$msg"
			exit 1
			;;
		esac
		echo "::warning file=license-key.pem::$msg. A tag build fails."
		exit 0
	fi
done
echo "license-key.pem: not a test key"
