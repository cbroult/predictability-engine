#!/usr/bin/env sh
# auto-bump.sh — bump patch version on every main push that hasn't been bumped.
#
# Runs before gem build inside the publish pipeline. Short-circuits if:
#   1. HEAD commit message contains [skip bump] or [skip ci], or
#   2. the code's current version is already higher than what's published
#      (meaning a human already bumped — respect their decision).
# Otherwise: `gem bump --no-commit` → commit → tag `v<new>` → push back.
#
# The push uses `[skip ci]` in the commit message so the new commit does not
# re-trigger the publish pipeline (Woodpecker honours that convention).
#
# Required env:
#   FORGEJO_PUSH_TOKEN   PAT with write scope on this repo (secret: forgejo_push_token)
#   CBP_ORG_CA_CERT      Base64-encoded cbp-org CA cert    (secret: cbp_org_ca_cert)

set -eu

HEAD_MSG=$(git log -1 --pretty=%B)
case "$HEAD_MSG" in
  *"[skip bump]"*|*"[skip ci]"*)
    echo "auto-bump: HEAD commit opts out (found '[skip bump]' or '[skip ci]') — leaving version alone"
    exit 0
    ;;
esac

CA_CERT_FILE=/tmp/cbp-ca.crt
printf '%s' "$CBP_ORG_CA_CERT" | base64 -d > "$CA_CERT_FILE"

CURRENT_VERSION=$(ruby -e "require_relative 'lib/predictability_engine/version'; puts PredictabilityEngine::VERSION")
PUBLISHED_VERSION=$(curl -sf --cacert "$CA_CERT_FILE" \
  "https://gems.cbp-org.internal/specs.4.8.gz" | \
  zcat | ruby -e "
    specs = Marshal.load(\$stdin.read)
    gem = specs.find { |name, _ver, _plat| name == 'predictability-engine' }
    puts gem ? gem[1].to_s : '0.0.0'
  " 2>/dev/null || echo "0.0.0")

echo "auto-bump: current=${CURRENT_VERSION}  published=${PUBLISHED_VERSION}"

HIGHER=$(ruby -rrubygems -e "
  c = Gem::Version.new(ARGV[0])
  p = Gem::Version.new(ARGV[1])
  puts(c > p ? 'yes' : 'no')
" "$CURRENT_VERSION" "$PUBLISHED_VERSION")

if [ "$HIGHER" = "yes" ]; then
  echo "auto-bump: developer already bumped to ${CURRENT_VERSION} — no action"
  exit 0
fi

bundle install --jobs 4 --retry 3 --quiet

# The preceding test step shares the workspace and may have modified tracked
# files (e.g. Gemfile.lock platform entries, package-lock.json). Reset them
# so gem-release's version:bump dirty-tree check does not abort.
git checkout -- .

echo "auto-bump: bumping patch version"
# Use gem bump directly with an explicit --file so gem-release can locate
# lib/predictability_engine/version.rb regardless of the gem name format.
# --no-commit lets auto-bump.sh handle the commit with [skip ci] itself.
bundle exec gem bump --version patch \
  --file lib/predictability_engine/version.rb \
  --no-commit

NEW_VERSION=$(ruby -e "load 'lib/predictability_engine/version.rb'; puts PredictabilityEngine::VERSION")
echo "auto-bump: bumped to ${NEW_VERSION}"

if [ "${NEW_VERSION}" = "${CURRENT_VERSION}" ]; then
  echo "auto-bump: rake did not change the version — aborting" >&2
  exit 1
fi

REMOTE_URL=$(git remote get-url origin)
AUTH_URL=$(echo "$REMOTE_URL" | sed "s#https://#https://x-access-token:${FORGEJO_PUSH_TOKEN}@#")

GIT_AUTHOR='-c user.email=ci@cbp-org.internal -c user.name=CBP-Org-CI'

# shellcheck disable=SC2086
git $GIT_AUTHOR add lib/predictability_engine/version.rb
# shellcheck disable=SC2086
git $GIT_AUTHOR commit -m "chore: auto-bump version to ${NEW_VERSION} [skip ci]"
git tag "v${NEW_VERSION}"
git push "$AUTH_URL" HEAD:main --tags

echo "auto-bump: pushed v${NEW_VERSION} to origin/main"
