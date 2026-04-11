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

# Pre-check: compare code version against the latest published version on geminabox.
# Avoids a wasted gem build and produces a clear, early signal when no bump occurred.
CURRENT_VERSION=$(ruby -e "require_relative 'lib/predictability_engine/version'; puts PredictabilityEngine::VERSION")
PUBLISHED_VERSION=$(curl -sf --cacert "$CA_CERT_FILE" \
  "https://gems.cbp-org.internal/specs.4.8.gz" | \
  zcat | ruby -e "
    specs = Marshal.load(\$stdin.read)
    gem = specs.find { |name, _ver, _plat| name == 'predictability-engine' }
    puts gem ? gem[1].to_s : 'none'
  " 2>/dev/null || echo "unknown")

print_bump_instructions() {
  echo ""
  echo "##############################################################"
  echo "# ERROR: $1"
  echo "#"
  echo "# Bump the version before pushing:"
  echo "#"
  echo "#   bundle exec rake version:bump[patch]   # bug fix"
  echo "#   bundle exec rake version:bump[minor]   # new feature"
  echo "#   bundle exec rake version:bump[major]   # breaking change"
  echo "##############################################################"
  echo ""
}

if [ "$CURRENT_VERSION" = "$PUBLISHED_VERSION" ]; then
  print_bump_instructions "version ${CURRENT_VERSION} is already published."
  exit 1
fi

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
    print_bump_instructions "${GEM_FILE} is already published (HTTP 409)."
    exit 1
    ;;
  *)
    echo "ERROR: gems.cbp-org.internal returned HTTP ${HTTP_STATUS}" >&2
    exit 1
    ;;
esac
