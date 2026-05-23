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
. "$(dirname "$0")/lib/forgejo-setup.sh"

HTTP_STATUS=$(curl -s -o /dev/null -w '%{http_code}' \
  --cacert "$CA_CERT_FILE" \
  -H "Authorization: token ${FORGEJO_PUSH_TOKEN}" \
  --upload-file "${GEM_FILE}" \
  "$FORGEJO_URL")

if [ "$HTTP_STATUS" -eq 409 ]; then
  echo "Package ${GEM_FILE} already exists in Forgejo (HTTP 409) — treating as success (idempotent)"
elif [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
  echo "Uploaded ${GEM_FILE} to Forgejo generic packages"
else
  echo "ERROR: Forgejo package upload returned HTTP ${HTTP_STATUS}" >&2
  exit 1
fi
