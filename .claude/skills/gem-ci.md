---
description: Audit artifact-first gated gem CI compliance for this project. Reports which of the 8 pattern checkpoints pass or fail.
---

Perform a gem-publisher audit of this project (read-only — no changes).

Check and report ✓/✗ for each checkpoint by reading the actual file content:

1. `.woodpecker/publish.yml` — exists; single main step named `build-artifact`; calls `upload-gem-artifact.sh`; has `CI_PIPELINE_EVENT` guard around auto-bump
2. `.woodpecker/verify-linux.yml` — exists; `depends_on: [publish]` (or `depends_on:\n  - publish`); calls `download-gem-artifact.sh`; installs with `gem install --local`
3. `.woodpecker/verify-windows.yml` — exists; `depends_on: [publish]`; has `CBP_ORG_CA_CERT`, `NEXUS_USER`, `NEXUS_PASSWORD` in environment
4. `.woodpecker/promote.yml` — exists; `depends_on` lists both `verify-linux` and `verify-windows`; pushes to github via SSH deploy key; publishes to rubygems
5. `Dockerfile.ci` — exists; `FROM ruby:`; contains `nodejs` and `npm`
6. `scripts/upload-gem-artifact.sh` — exists; uploads gem to nexus raw artifact store via curl PUT; does NOT push to any gem registry
7. `scripts/nexus-ssh-init.sh` — exists; no other build script inlines the 4-line SSH key setup block
8. Each of publish/verify-linux/verify-windows/promote has ≤ 2 steps (1 main + optional badge)

Finish with a single verdict line:
- All pass → "Artifact-first gated publish pattern: fully compliant ✓"
- Any fail → list each gap and suggest: "Run `gem-publisher migrate` to fix."
