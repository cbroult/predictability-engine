#!/usr/bin/env sh
# download-gem-artifact.sh — download the built gem from Forgejo generic packages.
#
# Called by verify-linux.yml before `gem install --local`. The gem was uploaded
# by publish.yml via upload-gem-artifact.sh and has not yet been published to
# any gem registry.
#
# Required env:
#   FORGEJO_PUSH_TOKEN — Forgejo API token (secret: forgejo_api_token)
#   CBP_ORG_CA_CERT   — Base64-encoded cbp-org CA cert (secret: cbp_org_ca_cert)

set -eu

GEM_VERSION=$(ruby -e "load 'lib/predictability_engine/version.rb'; puts PredictabilityEngine::VERSION")
GEM_FILE="predictability-engine-${GEM_VERSION}.gem"
. "$(dirname "$0")/lib/forgejo-setup.sh"

curl -fsSL -o "${GEM_FILE}" \
  --cacert "$CA_CERT_FILE" \
  -H "Authorization: token ${FORGEJO_PUSH_TOKEN}" \
  "$FORGEJO_URL"

echo "Downloaded ${GEM_FILE} from Forgejo generic packages"
