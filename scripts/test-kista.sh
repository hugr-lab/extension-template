#!/usr/bin/env bash
# The template's end-to-end check: publishes a built open and a built licensed copy to a kista with
# hugr-lab/extension-ci-tools' kista_publish.py, signed with a publisher key (kista spec 0023), then
# installs and loads both from it with the DuckDB the copies were built with. Removed by bootstrap.sh.
#
#   scripts/test-kista.sh <kista binary> <open copy> <open name> <licensed copy> <licensed name> <work dir>
#
# Each copy is bootstrapped and built (make release). kista runs on 127.0.0.1 with profile dev, a
# signed channel acme/prod and one dual listener: https for the publication API (a CA of its own), and
# plain http for DuckDB, which then needs no httpfs.
set -euo pipefail

if [ $# -ne 6 ]; then
	echo "usage: $0 <kista binary> <open copy> <open name> <licensed copy> <licensed name> <work dir>" >&2
	exit 2
fi
kista=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
open=$(cd "$2" && pwd)
open_name=$3
lic=$(cd "$4" && pwd)
lic_name=$5
work=$6
port=${TEMPLATE_KISTA_PORT:-18443}

# kista refuses a KISTA_* variable that is not one of its settings; this kista takes all from its file
while IFS= read -r v; do unset "$v"; done < <(compgen -e | grep '^KISTA_' || true)

rm -rf "${work:?}"
mkdir -p "$work/keys" "$work/home"
work=$(cd "$work" && pwd)
chmod 700 "$work/keys"

# the channel's signing key, and a CA and a certificate for 127.0.0.1
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$work/keys/prod.pem" 2>/dev/null
chmod 600 "$work/keys/prod.pem"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=template-ca -keyout "$work/ca.key" -out "$work/ca.pem" 2>/dev/null
openssl req -newkey rsa:2048 -nodes -subj /CN=127.0.0.1 -keyout "$work/tls.key" -out "$work/tls.csr" 2>/dev/null
printf 'subjectAltName=IP:127.0.0.1\nbasicConstraints=CA:FALSE\nextendedKeyUsage=serverAuth\n' >"$work/tls.ext"
openssl x509 -req -in "$work/tls.csr" -CA "$work/ca.pem" -CAkey "$work/ca.key" -CAcreateserial -days 1 \
	-extfile "$work/tls.ext" -out "$work/tls.crt" 2>/dev/null
chmod 600 "$work/tls.key"

cat >"$work/kista.yaml" <<EOF
profile: dev
store:
  kind: sqlite
  sqlite:
    path: $work/kista.db
signers:
  file_dir: $work/keys
serve:
  public_url: https://127.0.0.1:$port
  listeners:
    - addr: 127.0.0.1:$port
      scheme: dual
      tls:
        cert_file: $work/tls.crt
        key_file: $work/tls.key
EOF
ka() { "$kista" admin -config "$work/kista.yaml" "$@" 2>>"$work/admin.log"; }
trap 'echo "test-kista: failed; kista said:" >&2; tail -20 "$work/admin.log" "$work/serve.log" >&2 2>/dev/null' ERR

open_ext=$open/build/release/extension/$open_name/$open_name.duckdb_extension
lic_ext=$lic/build/release/extension/$lic_name/$lic_name.duckdb_extension
duckdb_version=$("$kista" ext inspect "$open_ext" | awk '$1 == "duckdb" && $2 == "version:" {print $3}')
if [[ "$duckdb_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then version_kind=release; else version_kind=dev; fi

ka migrate >/dev/null
ka tenant create acme >/dev/null
ka channel create acme/prod -kind signed >/dev/null
ka key add acme/prod -signer file:prod.pem -active >/dev/null
ka version add "$duckdb_version" -kind "$version_kind" >/dev/null
ka channel versions acme/prod -add "$duckdb_version" >/dev/null
ka publisher add acme ci >/dev/null
ka grant add acme -principal publisher:ci -verb publish -channel prod >/dev/null
# the publisher's key, as a developer makes it; the script takes the file's path
mkdir -m 700 "$work/publisher"
ssh-keygen -q -t ed25519 -N '' -C ci -f "$work/publisher/key"
ka publisher key add acme ci "$work/publisher/key.pub" -expires 1d >/dev/null
public_key=$(ka wellknown acme/prod | python3 -c 'import json, sys; print(json.load(sys.stdin)["signature_keys"][0], end="")')

"$kista" serve -config "$work/kista.yaml" >"$work/serve.log" 2>&1 &
serve_pid=$!
trap 'kill $serve_pid 2>/dev/null || true' EXIT
for _ in $(seq 1 60); do
	curl -sf "http://127.0.0.1:$port/readyz" >/dev/null && break
	sleep 1
done
curl -sf "http://127.0.0.1:$port/readyz" >/dev/null || { cat "$work/serve.log" >&2; exit 1; }

# the key and its grants, as _kista_publish.yml checks them first
who=$(SSL_CERT_FILE=$work/ca.pem KISTA_PUBLISHER_KEY=$work/publisher/key python3 "$lic/extension-ci-tools/scripts/kista_publish.py" \
	--url "https://127.0.0.1:$port" --tenant acme --channel prod --check)
[[ $who == *'"publisher":"ci"'* ]] || { echo "test-kista: the key's check did not name the publisher: $who" >&2; exit 1; }

# publish both as _kista_publish.yml does: from the artifacts' directories, one name at a time
for ext in "$open_ext" "$lic_ext"; do
	name=$(basename "$ext" .duckdb_extension)
	platform=$("$kista" ext inspect "$ext" | awk '$1 == "platform:" {print $2}')
	mkdir -p "$work/artifacts/$name-$duckdb_version-extension-$platform"
	cp "$ext" "$work/artifacts/$name-$duckdb_version-extension-$platform/"
	SSL_CERT_FILE=$work/ca.pem KISTA_PUBLISHER_KEY=$work/publisher/key python3 "$lic/extension-ci-tools/scripts/kista_publish.py" \
		--url "https://127.0.0.1:$port" --tenant acme --channel prod --visibility public --name "$name" \
		--postfix="" --summary "$work/summary.md" "$work/artifacts"
done
grep -q "$open_name" "$work/summary.md" && grep -q "$lic_name" "$work/summary.md" ||
	{ echo "test-kista: the job summary does not list both" >&2; exit 1; }

# install and load both from kista with DuckDB at the copies' commit (built, not linked into it)
sql() { HOME=$work/home "$open/build/release/duckdb" -noheader -list -c "SET autoinstall_known_extensions = false;
SET autoload_known_extensions = false;
$1"; }
sql "SET allow_extension_repositories = 'allowed';
CREATE EXTENSION REPOSITORY local WITH PREFIX 'http://127.0.0.1:$port/acme/prod' USING PUBLIC KEY '$public_key';
INSTALL $open_name FROM local;
INSTALL $lic_name FROM local;" >/dev/null
got=$(sql "LOAD $open_name FROM local;
LOAD $lic_name FROM local;
SELECT $open_name('kista');
SELECT status FROM ${lic_name}_license();")
# the shell prints the SDK's warning (the licensed copy trusts the test key) before the results
want=$(printf '%s\n%s' "...........🦆 kista" "missing")
got=$(printf '%s\n' "$got" | perl -pe 's/\e\[[0-9;]*m//g')
if [ "$(printf '%s\n' "$got" | tail -2)" != "$want" ] || ! printf '%s' "$got" | grep -q "built with the kista SDK's test key"; then
	echo "DuckDB answered:" >&2
	echo "$got" >&2
	echo "want the SDK's test-key warning, then:" >&2
	echo "$want" >&2
	exit 1
fi
echo "kista: both kinds published, installed and loaded"
