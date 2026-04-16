# Refactoring Report: workflows-2-human-led-strict

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 316 | 265 | 44 | −51 (−16.1%) |
| Words | 951 | 711 | 104 | −240 (−25.2%) |
| DuplicationRatio | 9.0% | 3.0% | — | −6.0 pp |

### Per-subfolder breakdown

Leaf counts exclude `shared/`; the shared row is the cost amortised across all three groups.

| Subfolder | Generated lines | Generated words | Leaf lines | Leaf words | Δ lines | Δ words |
|---|---|---|---|---|---|---|
| deploy-cloudrun | 193 | 551 | 108 | 259 | −85 (−44%) | −292 (−53%) |
| create-cloud-deploy-release | 66 | 236 | 54 | 183 | −12 (−18%) | −53 (−22%) |
| get-gke-credentials | 57 | 164 | 59 | 165 | +2 (+4%) | +1 (+1%) |
| shared/ | — | — | 44 | 104 | — | — |
| **Total** | **316** | **951** | **265** | **711** | **−51 (−16.1%)** | **−240 (−25.2%)** |

## Verification

PASS — 6/6 files match.

## Findings

### Scope

Three workflow groups were refactored: `deploy-cloudrun` (4 files),
`create-cloud-deploy-release` (1 file), and `get-gke-credentials` (1 file).
Kubernetes/Knative manifests and Cloud Deploy config files that lived in the
same directories were excluded — they are supporting artefacts, not workflow
definitions.

### Shared workflow base (`cloudrun-workflow-base.yaml++`)

All five workflow files share the same `on.push.branches` trigger, job
`permissions`, `runs-on`, and three env vars (`PROJECT_ID`, `SERVICE`,
`REGION`). These were extracted into a single document-level base used by
every leaf via `$extends` at the document root. The "strict" policy means only
env vars truly common to every Cloud Run variant appear in the base;
workflow-specific variables (GAR_LOCATION, REPOSITORY, SOURCE_DIRECTORY, etc.)
remain in each individual leaf file.

### GAR image reference functions (`cloudrun.jq`)

The Google Artifact Registry image string
(`$GAR_LOCATION-docker.pkg.dev/$PROJECT_ID/…:$GITHUB_SHA`) appeared in three
distinct patterns across the workflows:

| Function | Image path pattern | Used by |
|---|---|---|
| `gar_image` | `…/SERVICE:sha` | deploy-cloudrun (declarative) |
| `gar_image_with_repo` | `…/REPOSITORY/SERVICE:sha` | deploy-cloudrun (docker, buildpacks) |
| `gar_image_with_app` | `…/APP/APP:sha` | create-cloud-deploy-release |

Each function is paired with a `build_and_push_*` variant that composes the
full two-line `docker build / docker push` shell script. jq's `\()`
interpolation was required here because jq++ cannot interpolate `eval:`
directives as substrings inside block scalars
(see [dakusui/jqplusplus#59](https://github.com/dakusui/jqplusplus/issues/59)).
Leaf files reference these via `eval:string:cloudrun::…`, keeping the `run:`
values to a single clean line.

### Step-level node inheritance

jq++ supports `$extends` at the array-element level (node-level inheritance),
not only at the document root. This was the primary mechanism for factoring
repeated GitHub Actions steps. Seven shared step bases were extracted:

| Base file | Fields in base | Variant overrides used |
|---|---|---|
| `steps/google-auth-step.yaml++` | name, id, uses @v0, WIF with fields | `token_format`, `name`, `uses @v1`, hardcoded WIF values |
| `steps/docker-auth-step.yaml++` | name, id, uses @v1, username/password/registry | `uses @v2` |
| `steps/checkout-step.yaml++` | name, uses @v3 | `uses @v2` |
| `steps/show-output-step.yaml++` | name, run | — |
| `steps/build-and-push-step.yaml++` | name, run (`build_and_push`) | `run` → `build_and_push_with_repo` |
| `steps/build-and-push-app-step.yaml++` | name, run (`build_and_push_with_app`) | — |
| `steps/deploy-cloudrun-step.yaml++` | name, id, uses @v0, service, region | `uses @v2`, `with.image`, `with.metadata`, `with.source` |

The step files live under `shared/steps/` and are referenced with the
`steps/` path prefix (e.g. `steps/checkout-step.yaml++`), which resolves
through the existing `shared/` JF_PATH entry without any additional
configuration.

### Per-subfolder outcomes

**deploy-cloudrun** (−44% lines, −53% words) — the biggest win. Four files
with heavily overlapping structure: same trigger, same permissions, same five
action steps differing in at most two fields per step. Every action step in
this group is now backed by a shared base; leaf files express only what
differs. `cloudrun-source` shrank to 18 lines (from 33 generated) by inheriting
almost everything.

**create-cloud-deploy-release** (−18% lines, −22% words) — moderate savings.
The workflow inherits the common base and uses the new `build-and-push-app-step`
and `checkout-step` bases. The remaining bulk (gcloud CLI steps for Cloud Deploy
pipeline management, release creation, manifest rendering) is unique to this
workflow and was left inline.

**get-gke-credentials** (≈0%) — effectively neutral. The Google Auth and
Checkout steps were factored, but the majority of the workflow (Docker login,
Build with `--build-arg` flags, Publish, Kustomize setup, kubectl deploy) is
unique to GKE and used only once. Inline is the correct choice for single-use
steps. The small line increase is the overhead of `$extends` directive lines
being slightly more verbose than the inline equivalents they replace.

### Limitations

- **Block scalar interpolation**: `eval:` directives are not interpolated when
  they appear as substrings within YAML block scalars (`|-`). The workaround is
  to promote the entire value to an `eval:string:` expression using jq's `\()`
  interpolation. Reported upstream as dakusui/jqplusplus#59.
- **Array merging**: jq++ deep-merges objects but shallow-replaces arrays. Base
  `steps: []` arrays are fully replaced by the leaf; this is the expected
  behaviour but it means array-level inheritance (inserting a step into a base
  sequence) is not available.
- **YAML comments stripped**: The jq++ → yq round-trip removes all comments.
  The generated baseline therefore reflects comment-free output; savings
  measured against the originals would appear larger due to stripped comments.
