---
description: Audit RC-gated gem CI compliance for this project. Reports which of the 8 pattern checkpoints pass or fail.
---

Perform a gem-publisher audit of this project (read-only — no changes).

Check and report ✓/✗ for each checkpoint by reading the actual file content:

1. `.woodpecker/publish.yml` — exists; single main step named `publish-rc`; calls `build-rc-gem`; has `CI_PIPELINE_EVENT` guard around auto-bump
2. `.woodpecker/verify-linux.yml` — exists; `depends_on: [publish]` (or `depends_on:\n  - publish`); installs `.rc1` version from internal registry
3. `.woodpecker/verify-windows.yml` — exists; `depends_on: [publish]`; has `CBP_ORG_CA_CERT` in environment; installs `.rc1` version
4. `.woodpecker/promote.yml` — exists; `depends_on` lists both `verify-linux` and `verify-windows`; pushes to github; publishes to rubygems
5. `Dockerfile.ci` — exists; `FROM ruby:`; contains `nodejs` and `npm`
6. `scripts/build-rc-gem.sh` — exists; patches version.rb to `.rc1`, builds gem, restores
7. `scripts/nexus-ssh-init.sh` — exists; no other build script inlines the 4-line SSH key setup block
8. Each of publish/verify-linux/verify-windows/promote has ≤ 2 steps (1 main + optional badge)

Finish with a single verdict line:
- All pass → "RC-gated publish pattern: fully compliant ✓"
- Any fail → list each gap and suggest: "Run `gem-publisher migrate` to fix."
