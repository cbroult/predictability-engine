#!/usr/bin/env sh
# publish-gem.sh — build and push the predictability-engine gem to gems.cbp-org.internal
#
# Usage (called by the publish CI step):
#   sh scripts/publish-gem.sh
#
# Required env:
#   GEM_USER          Geminabox username      (from Woodpecker secret gem_user)
#   GEM_PASSWORD      Geminabox password      (from Woodpecker secret gem_password)
#   CBP_ORG_CA_CERT   Base64-encoded CA cert  (from Woodpecker secret cbp_org_ca_cert)

set -eu

CA_CERT_FILE=/tmp/cbp-ca.crt
printf '%s' "$CBP_ORG_CA_CERT" | base64 -d > "$CA_CERT_FILE"

# The auto-bump step (scripts/auto-bump.sh) guarantees a new version before we
# reach this script. HTTP 409 is kept as a defensive check in case that
# invariant is ever violated (e.g. manual pipeline re-run of the same SHA).

gem build predictability-engine.gemspec
GEM_FILE=$(ls predictability-engine-*.gem | head -1)

HTTP_STATUS=$(curl -s -o /dev/null -w '%{http_code}' \
  --cacert "$CA_CERT_FILE" \
  -u "${GEM_USER}:${GEM_PASSWORD}" \
  --data-binary "@${GEM_FILE}" \
  -H "Content-Type: application/octet-stream" \
  https://gems.cbp-org.internal/api/v1/gems)

case "$HTTP_STATUS" in
  200|201)
    echo "Published ${GEM_FILE} to gems.cbp-org.internal"
    ;;
  409)
    echo "ERROR: ${GEM_FILE} is already published (HTTP 409). auto-bump should have prevented this." >&2
    exit 1
    ;;
  *)
    echo "ERROR: gems.cbp-org.internal returned HTTP ${HTTP_STATUS}" >&2
    exit 1
    ;;
esac
