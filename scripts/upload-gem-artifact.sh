#!/usr/bin/env sh
# upload-gem-artifact.sh — upload the built gem to Forgejo generic packages.
#
# The package store is NOT the gem registry (gems.cbp-org.internal). Uploading
# here does not make the gem installable via `gem install`; it just makes the
# file available for verify steps to download and install with `gem install --local`.
# Only promote.yml pushes to the actual gem registries after all platforms pass.
#
# Required env:
#   FORGEJO_PUSH_TOKEN — Forgejo API token (secret: forgejo_api_token)
#   CBP_ORG_CA_CERT   — Base64-encoded cbp-org CA cert (secret: cbp_org_ca_cert)

set -eu

GEM_FILE=$(ls predictability-engine-*.gem | head -1)
GEM_VERSION=$(echo "$GEM_FILE" | sed 's/predictability-engine-\(.*\)\.gem/\1/')
CA_CERT_FILE=/tmp/cbp-ca.crt
printf '%s' "$CBP_ORG_CA_CERT" | base64 -d > "$CA_CERT_FILE"

FORGEJO_URL="https://git.cbp-org.internal/api/packages/cbp-org/generic/predictability-engine/${GEM_VERSION}/${GEM_FILE}"

HTTP_STATUS=$(curl -s -o /dev/null -w '%{http_code}' \
  --cacert "$CA_CERT_FILE" \
  -H "Authorization: token ${FORGEJO_PUSH_TOKEN}" \
  --upload-file "${GEM_FILE}" \
  "$FORGEJO_URL")

[ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ] || \
  { echo "ERROR: Forgejo package upload returned HTTP ${HTTP_STATUS}" >&2; exit 1; }

echo "Uploaded ${GEM_FILE} to Forgejo generic packages"
