#!/usr/bin/env sh
# build-ci-image.sh — build and push the predictability-engine-ci Docker image
# via SSH to nexus.cbp-org.internal.
#
# The CI image extends ruby:4.0.3 with pre-installed nodejs/npm/openssh-client
# so CI steps skip apt-get on every run. See Dockerfile.ci.
#
# Required env:
#   NEXUS_DEPLOY_KEY     SSH private key for root@nexus.cbp-org.internal
#                        (secret: nexus_deploy_key)
#
# Usage: sh scripts/build-ci-image.sh

set -eu

REGISTRY=docker-registry.cbp-org.internal/predictability-engine-ci

. scripts/nexus-ssh-init.sh

$SCP_BASE Dockerfile.ci "root@nexus.cbp-org.internal:${REMOTE_TMPDIR}/"

$SSH_BASE sh <<REMOTE_SCRIPT
set -eu
cd "${REMOTE_TMPDIR}"

docker build \\
  -f Dockerfile.ci \\
  -t ${REGISTRY}:latest \\
  .

docker push ${REGISTRY}:latest
REMOTE_SCRIPT

echo "predictability-engine-ci image pushed: ${REGISTRY}:latest"
