#!/usr/bin/env sh
# upload-gem-artifact.sh — upload the built gem to the Nexus raw artifact store.
#
# The artifact store is NOT the gem registry (gems.cbp-org.internal). Uploading
# here does not make the gem installable via `gem install`; it just makes the
# file available for verify steps to download and install with `gem install --local`.
# Only promote.yml pushes to the actual gem registries after all platforms pass.
#
# Required env:
#   NEXUS_USER        — Nexus username (secret: nexus_user)
#   NEXUS_PASSWORD    — Nexus password (secret: nexus_password)
#   CBP_ORG_CA_CERT   — Base64-encoded cbp-org CA cert (secret: cbp_org_ca_cert)

set -eu

GEM_FILE=$(ls predictability-engine-*.gem | head -1)
CA_CERT_FILE=/tmp/cbp-ca.crt
printf '%s' "$CBP_ORG_CA_CERT" | base64 -d > "$CA_CERT_FILE"

HTTP_STATUS=$(curl -s -o /dev/null -w '%{http_code}' \
  --cacert "$CA_CERT_FILE" \
  -u "${NEXUS_USER}:${NEXUS_PASSWORD}" \
  --upload-file "${GEM_FILE}" \
  "https://nexus.cbp-org.internal/repository/gem-artifacts/${GEM_FILE}")

[ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ] || \
  { echo "ERROR: nexus artifact upload returned HTTP ${HTTP_STATUS}" >&2; exit 1; }

echo "Uploaded ${GEM_FILE} to nexus raw artifact store"
