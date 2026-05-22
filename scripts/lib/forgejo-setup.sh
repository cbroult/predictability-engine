#!/usr/bin/env sh
# Source this after setting GEM_VERSION and GEM_FILE.
# Requires: CBP_ORG_CA_CERT (base64-encoded CA cert)
# Sets: CA_CERT_FILE, FORGEJO_URL

CA_CERT_FILE=/tmp/cbp-ca.crt
printf '%s' "$CBP_ORG_CA_CERT" | base64 -d > "$CA_CERT_FILE"

FORGEJO_URL="https://git.cbp-org.internal/api/packages/cbp-org/generic/predictability-engine/${GEM_VERSION}/${GEM_FILE}"
