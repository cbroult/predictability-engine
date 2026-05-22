#!/usr/bin/env sh
# download-gem-artifact.sh — download the built gem from the Nexus raw artifact store.
#
# Called by verify-linux.yml before `gem install --local`. The gem was uploaded
# by publish.yml via upload-gem-artifact.sh and has not yet been published to
# any gem registry.
#
# Required env:
#   NEXUS_USER        — Nexus username (secret: nexus_user)
#   NEXUS_PASSWORD    — Nexus password (secret: nexus_password)
#   CBP_ORG_CA_CERT   — Base64-encoded cbp-org CA cert (secret: cbp_org_ca_cert)

set -eu

GEM_VERSION=$(ruby -e "load 'lib/predictability_engine/version.rb'; puts PredictabilityEngine::VERSION")
GEM_FILE="predictability-engine-${GEM_VERSION}.gem"
CA_CERT_FILE=/tmp/cbp-ca.crt
printf '%s' "$CBP_ORG_CA_CERT" | base64 -d > "$CA_CERT_FILE"

curl -fsSL -o "${GEM_FILE}" \
  --cacert "$CA_CERT_FILE" \
  -u "${NEXUS_USER}:${NEXUS_PASSWORD}" \
  "https://nexus.cbp-org.internal/repository/gem-artifacts/${GEM_FILE}"

echo "Downloaded ${GEM_FILE} from nexus raw artifact store"
