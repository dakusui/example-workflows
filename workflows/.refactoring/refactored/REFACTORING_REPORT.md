# Refactoring Report: workflows

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 407 | 379 | 18 | −28 (−7%) |
| Words | 1107 | 1094 | 26 | −13 (−1%) |

## Verification

PASS — 11/11 files match.

## Findings

### What was refactored

The `workflows/` directory contains 11 YAML files across three subdirectories:

- `deploy-cloudrun/` — 4 GitHub Actions workflow `.yml` files and 1 service template
- `create-cloud-deploy-release/` — 1 workflow `.yml` and 4 config templates
- `get-gke-credentials/` — 1 workflow `.yml`

Two shared bases were extracted.

---

### `shared/cloudrun-workflow-base.yaml++` (11 lines)

Four of the five GitHub Actions workflow files (`cloudrun-buildpacks`, `cloudrun-docker`,
`cloudrun-declarative`, `cloudrun-source`) share an identical job-level skeleton:

```yaml
on:
  push:
    branches:
      - $default-branch
jobs:
  deploy:
    permissions:
      contents: 'read'
      id-token: 'write'
    runs-on: ubuntu-latest
    steps: []
```

This block was extracted into `cloudrun-workflow-base.yaml++`. Each variant extends the
base and overrides only `name`, `env`, and `jobs.deploy.steps`. Because jq++ deep-merges
objects but shallow-replaces arrays, the `steps` array is cleanly replaced per-variant
while `permissions` and `runs-on` are inherited.

The `cloud-deploy-to-cloud-run.yml` workflow also inherits from this base. It differs in
one detail — it uses `$default_branch` (underscore, a GitHub template variable) rather
than `$default-branch` (hyphen) — so its leaf file overrides the `on` block to correct
this.

The GKE workflow (`gke-build-deploy.yml`) was not connected to this base because its job
is named `setup-build-publish-deploy` (not `deploy`) and it carries an additional
`environment: production` field, making the inheritance benefit negligible.

---

### `shared/app-service-base.yaml++` (7 lines)

`app-prod.template.yaml` and `app-staging.template.yaml` were structurally identical
except for two fields:

| Field | prod | staging |
|---|---|---|
| `metadata.name` | `app-prod` | `app-staging` |
| `spec.template.spec.containers[0].env[0].value` | `Prod` | `Staging` |

The shared annotation (`autoscaling.knative.dev/maxScale: '1'`) and outer YAML structure
were extracted into `app-service-base.yaml++`. Each variant is now 13 lines vs 30 lines
in the original (including the Apache 2.0 copyright header, which is stripped during
jq++ → yq round-trip).

Because jq++ shallow-replaces arrays, each variant must re-declare the full `containers`
entry (3 lines) rather than just overriding the `env` value. This is a minor array-merge
constraint inherent to jq++.

---

### Files with no structural sharing

- `service.template.yaml` — single unique document, passed through unchanged
- `skaffold.template.yaml` — single unique document, passed through unchanged
- `clouddeploy.template.yaml` — multi-document file; the `staging` and `prod` Target
  documents differ only in `metadata.name` and `description` (2 of 6 lines each), but
  creating a base would not reduce total line count and was omitted
- `gke-build-deploy.yml` — unique workflow with no peer files, passed through unchanged

---

### Comment stripping

All original workflow files carry 40–100 lines of documentation comments (API lists, IAM
permission tables, setup instructions). These are stripped during the jq++ → yq
round-trip. The generated baseline in `.refactoring/generated/` therefore represents
clean, comment-free YAML. The originals in `workflows/` are untouched and retain their
comments.

The apparent reduction against the raw originals (891 lines → 379 source lines, −58%) is
largely driven by comment removal rather than structural deduplication. Against the
comment-stripped baseline (407 lines), the refactored sources are 379 lines — a modest
7% reduction, with the primary benefit being the named shared bases that communicate
intent and enforce consistency.
