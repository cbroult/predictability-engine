#!/usr/bin/env sh
# verify-fresh-install.sh — clean-room smoke test for a freshly-installed
# predictability-engine gem.
#
# Run by .woodpecker/publish.yml after `gem install predictability-engine`
# against the gems.cbp-org.internal registry. Confirms that an end user can:
#   1. locate the shipped sample CSVs via the gem
#   2. generate synthetic stress data with the CLI
#   3. run `batch` end-to-end (all formats, incl. Playwright: png/pptx/a3_pdf)
#   4. run `summary` and `forecast` subcommands
# and that every expected artefact lands on disk non-empty.
#
# Preconditions (set by the CI step):
#   - predictability-engine is installed
#   - node + playwright chromium are available
#   - cbp-org root CA is trusted (so Playwright downloads succeed if needed)

set -eu

WORK=/tmp/verify-fresh-install
rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"

# Locate shipped sample CSVs inside the installed gem.
GEM_DATA=$(ruby -rpredictability_engine -e 'puts File.dirname(PredictabilityEngine.sample_data_path)')
echo "verify-fresh-install: using shipped samples from ${GEM_DATA}"

# Copy shipped samples into the workdir so report output lands in /tmp/...
# (the gem install path may not be writable).
cp "${GEM_DATA}/sample_data.csv"       "$WORK/sample_data.csv"
cp "${GEM_DATA}/sample_data_large.csv" "$WORK/sample_data_large.csv"
cp "${GEM_DATA}/wip_data.csv"          "$WORK/wip_data.csv"

# Generate the XL stress dataset using the gem's own CLI.
predictability-engine generate --size=xl "$WORK/xl_data.csv"
[ -s "$WORK/xl_data.csv" ] || { echo "FAIL: xl_data.csv not produced"; exit 1; }

# Batch mode = all formats (html, md, conf, pdf, a3_pdf, png, pptx, terminal).
# Run on every shipped sample plus the XL synthetic dataset.
for csv in sample_data.csv sample_data_large.csv wip_data.csv xl_data.csv; do
  echo "verify-fresh-install: batch $csv"
  predictability-engine batch "$WORK/$csv"
done

# Additional subcommands exercised on the small shipped sample.
predictability-engine summary  "$WORK/sample_data.csv"
predictability-engine forecast "$WORK/wip_data.csv" 10

# Assert every expected artefact exists and is non-empty.
fail=0
for base in sample_data sample_data_large wip_data xl_data; do
  for artefact in \
    dashboard.html \
    dashboard.md \
    dashboard.conf \
    dashboard.pdf \
    dashboard.pptx \
    dashboard.png \
    dashboard_a3.pdf \
    dashboard.csv \
    dashboard.xlsx; do
    path="$WORK/reports/$base/$artefact"
    if [ ! -s "$path" ]; then
      echo "FAIL: missing or empty artefact $path"
      fail=1
    fi
  done
done

if [ "$fail" -ne 0 ]; then
  echo "verify-fresh-install: FAILED"
  exit 1
fi

echo "verify-fresh-install: all artefacts generated successfully"
