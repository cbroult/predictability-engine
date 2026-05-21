#!/usr/bin/env sh
# nexus-ssh-init.sh — shared SSH setup for nexus.cbp-org.internal build scripts.
#
# Source this file (. scripts/nexus-ssh-init.sh) — do not execute directly.
# Requires: NEXUS_DEPLOY_KEY env var.
# Sets:     SSH_BASE, SCP_BASE, REMOTE_TMPDIR; registers EXIT cleanup trap.

mkdir -p ~/.ssh && chmod 700 ~/.ssh
printf '%s\n' "${NEXUS_DEPLOY_KEY}" | sed 's/\\n/\n/g' | tr -d '\r' > ~/.ssh/ci_deploy
chmod 600 ~/.ssh/ci_deploy
echo "[nexus.cbp-org.internal]:32523 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPaRph2p4g/e4VpJHSn6mL5Qe32tPciyNCYsM5iEcuBB" >> ~/.ssh/known_hosts

SSH_BASE="ssh -i ~/.ssh/ci_deploy -p 32523 -o StrictHostKeyChecking=yes -o BatchMode=yes root@nexus.cbp-org.internal"
SCP_BASE="scp -O -i ~/.ssh/ci_deploy -P 32523 -o StrictHostKeyChecking=yes"

# shellcheck disable=SC2086
REMOTE_TMPDIR=$($SSH_BASE 'mktemp -d')
cleanup() { $SSH_BASE "rm -rf ${REMOTE_TMPDIR}" || true; }
trap cleanup EXIT
