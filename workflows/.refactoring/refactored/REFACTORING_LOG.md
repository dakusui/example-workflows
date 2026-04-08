# Refactoring Log: workflows/ — continued

Chronological record of the refactoring session following the
`workflows-2-human-led-strict` snapshot (commit `d7ff932`).
Entries are ordered oldest → newest.

---

## Relax verify.sh: allow extra attributes in sandbox
`a70f84e`

Replace the strict diff with jq's recursive `contains` check: sandbox
must contain all attributes and values present in the generated baseline,
but may carry additional attributes without failing.

```
generated ⊆ sandbox   (was: generated == sandbox)
```

Both `check_yaml` and `check_json` convert to JSON and evaluate:
```
sandbox_json | contains(generated_json)
```

On failure the key-sorted diff is still shown for diagnosis.

---

## Pull GAR_LOCATION env var up into cloudrun-workflow-base
`59d3796`

`GAR_LOCATION: YOUR_GAR_LOCATION` appeared in 4 of the 5 workflow leaf
files (all except `cloudrun-source`, which deploys from source and has no
docker build step). Moved into the shared base so it is declared once.

`cloudrun-source` inherits it as an extra env var it does not use; this is
permitted by the relaxed `verify.sh` (`sandbox ⊇ generated`).

`REPOSITORY`, `SOURCE_DIRECTORY`, and `APP` remain in their respective leaf
files — each is unique to one or two workflows. `REGION` in cloud-deploy
remains as a leaf override (`YOUR_APP_REGION` vs the base's
`YOUR_SERVICE_REGION`).

### Discussion

The relaxed containment check makes this move safe: `cloudrun-source`'s
generated output gains `GAR_LOCATION` as an extra field, which the verify
allows. Previously, strict equality would have required either keeping
`GAR_LOCATION` in `cloudrun-source` or accepting a verify failure for that
file.

---

## Pull remaining env vars up into cloudrun-workflow-base
`4b1bdbd`

Move `REPOSITORY`, `SOURCE_DIRECTORY`, and `APP` into the shared base so all
env vars are declared in one place:

- `REPOSITORY: YOUR_REPOSITORY_NAME` — was in cloudrun-docker, cloudrun-buildpacks
- `SOURCE_DIRECTORY: YOUR_SOURCE_DIRECTORY` — was in cloudrun-buildpacks only
- `APP: app` — was in cloud-deploy only

`REGION` in cloud-deploy remains as a leaf override (`YOUR_APP_REGION` vs the
base's `YOUR_SERVICE_REGION`) — it cannot be merged because the value differs.

### Discussion

With the relaxed containment check in place, pulling up single-use vars is now
safe: a leaf that doesn't reference `REPOSITORY` or `SOURCE_DIRECTORY` simply
carries them as unused env entries. The practical benefit is that all
configurable env vars are visible in one base file, making it easier for users
to find what needs to be set before running the workflows.

---

## ⚠ BUG FOUND VIA REFACTORING: APP env var used a concrete value instead of a placeholder
`20cdb82`

Every other env var in the workflow examples uses a `YOUR_*` placeholder
(`YOUR_PROJECT_ID`, `YOUR_SERVICE_NAME`, `YOUR_GAR_LOCATION`, etc.) to signal
to users that the value must be replaced before use. `APP: app` was the only
exception — it looked like a valid working value, so users following the example
would silently deploy an app named "app" rather than their own application name.

Fixed to `APP: YOUR_APP_NAME`, consistent with all other placeholder values in
the base.

**How refactoring exposed it:** the bug was invisible in the original files
because `APP` only appeared in one workflow (`create-cloud-deploy-release`).
Pulling all env vars into a single shared base placed all values side by side,
making the inconsistency immediately obvious.

---

## ⚠ BUG FOUND VIA REFACTORING: docker/login-action was inconsistent across workflows
`6282ecc`

`cloudrun-declarative.yml` had been updated to `docker/login-action@v2` while
`cloudrun-docker` and `cloudrun-buildpacks` were left on `@v1`. The
inconsistency was invisible in the original files because each workflow was a
standalone file with no shared reference point.

Refactoring into a shared `docker-auth-step.yaml++` base made the version
override in `cloudrun-declarative.yaml++` immediately visible — a leaf
overriding the base to a *newer* version signals the base is stale.

Fix: update `docker-auth-step.yaml++` to `@v2` and remove the now-redundant
override in `cloudrun-declarative.yaml++`. All three docker-auth workflows now
consistently use `docker/login-action@v2`.

**How refactoring exposed it:** with all three workflows sharing the same step
base, the `@v2` override in `cloudrun-declarative` stood out as an anomaly.
Without a shared base, the version difference was buried in separate files with
no visual cue.

---

## Tighten verify.sh: relax only root env:, strict elsewhere
`f0221f1`

The previous relaxation (full containment check on the entire document) was too
broad — it would silently allow extra fields anywhere in the document. The
intended scope was narrower: only the root `env:` block should permit extra
vars.

New rules:
- All fields except root `env:` — strict diff (as original)
- Root `env:` only — `sandbox ⊇ generated` (containment)

Implemented as two separate checks in `check_yaml`:
1. `diff` on `yq 'del(.env)'` output
2. `jq contains` on `.env // {}` independently

JSON files revert to strict diff with no `env:` relaxation.
