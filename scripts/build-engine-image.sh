#!/usr/bin/env sh
# build-engine-image.sh — build and push the predictability-engine Docker image
# via SSH to nexus.cbp-org.internal. The image pre-installs predictability-engine
# (from gems.cbp-org.internal) plus the cbp-org root CA.
#
# Required env:
#   NEXUS_DEPLOY_KEY     SSH private key for root@nexus.cbp-org.internal
#                        (secret: nexus_deploy_key)
#   CBP_ORG_CA_CERT      Base64-encoded cbp-org root CA certificate
#                        (secret: cbp_org_ca_cert)
#
# Optional env:
#   IMAGE_TAG            Additional tag (default: none — only ":latest" is pushed)
#   GEM_VERSION          Pin predictability-engine to this version
#                        (default: whatever gem install pulls as latest)

set -eu

IMAGE_TAG=${IMAGE_TAG:-}
GEM_VERSION=${GEM_VERSION:-}
REGISTRY=docker-registry.cbp-org.internal/predictability-engine

. scripts/nexus-ssh-init.sh

printf '%s' "${CBP_ORG_CA_CERT}" > /tmp/cbp-ca.b64

$SCP_BASE Dockerfile.predictability-engine /tmp/cbp-ca.b64 "root@nexus.cbp-org.internal:${REMOTE_TMPDIR}/"

$SSH_BASE sh <<REMOTE_SCRIPT
set -eu
cd "${REMOTE_TMPDIR}"

docker build \\
  --build-arg CBP_ORG_CA_CERT_B64="\$(cat cbp-ca.b64)" \\
  ${GEM_VERSION:+--build-arg GEM_VERSION=${GEM_VERSION}} \\
  -f Dockerfile.predictability-engine \\
  -t ${REGISTRY}:latest \\
  ${IMAGE_TAG:+-t ${REGISTRY}:${IMAGE_TAG}} \\
  .

docker push ${REGISTRY}:latest
${IMAGE_TAG:+docker push ${REGISTRY}:${IMAGE_TAG}}
REMOTE_SCRIPT

echo "predictability-engine image pushed: ${REGISTRY}:latest${IMAGE_TAG:+ + ${REGISTRY}:${IMAGE_TAG}}"
