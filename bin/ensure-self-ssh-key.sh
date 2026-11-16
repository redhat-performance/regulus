#!/usr/bin/env bash

# Add this host's public key with a Crucible-safe comment.  Crucible removes
# legacy entries carrying a root@hostname comment, so do not preserve the
# comment from id_rsa.pub here.
set -euo pipefail

PUBKEY_FILE="${1:-$HOME/.ssh/id_rsa.pub}"
AUTHORIZED_KEYS="${2:-$HOME/.ssh/authorized_keys}"
KEY_TAG="${3:-run-cpt-tag}"

if [[ ! "$KEY_TAG" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "ERROR: invalid SSH key tag" >&2
    exit 1
fi

if [[ ! -s "$PUBKEY_FILE" ]]; then
    echo "ERROR: public key not found: $PUBKEY_FILE" >&2
    exit 1
fi

mkdir -p "$(dirname "$AUTHORIZED_KEYS")"
touch "$AUTHORIZED_KEYS"
chmod 700 "$(dirname "$AUTHORIZED_KEYS")"
chmod 600 "$AUTHORIZED_KEYS"

read -r key_type key_data _ < "$PUBKEY_FILE"
if [[ -z "$key_type" || -z "$key_data" || -z "$KEY_TAG" ]]; then
    echo "ERROR: invalid public key or empty key tag" >&2
    exit 1
fi

if ! awk -v key_type="$key_type" -v key_data="$key_data" -v key_tag="$KEY_TAG" '
    $1 == key_type && $2 == key_data && $3 == key_tag { found=1 }
    END { exit !found }
' "$AUTHORIZED_KEYS"; then
    printf '%s %s %s\n' "$key_type" "$key_data" "$KEY_TAG" >> "$AUTHORIZED_KEYS"
fi
