# Refactoring Report: workflows-3-human-led-lenient

## Metrics

| | Generated (baseline) | Refactored sources | of which: shared | Change |
|---|---|---|---|---|
| Lines | 328 | 259 | 48 | −69 (−21.0%) |
| Words | 975 | 698 | 112 | −277 (−28.4%) |
| DuplicationRatio | 18.7% | 3.1% | — | −15.6 pp |

### Per-subfolder breakdown

Leaf counts exclude `shared/`; the shared row is the cost amortised across all three groups.

| Subfolder | Generated lines | Generated words | Leaf lines | Leaf words | Δ lines | Δ words |
|---|---|---|---|---|---|---|
| deploy-cloudrun | 203 | 571 | 100 | 242 | −103 (−51%) | −329 (−58%) |
| create-cloud-deploy-release | 68 | 240 | 52 | 179 | −16 (−24%) | −61 (−25%) |
| get-gke-credentials | 57 | 164 | 59 | 165 | +2 (+4%) | +1 (+1%) |
| shared/ | — | — | 48 | 112 | — | — |
| **Total** | **328** | **975** | **259** | **698** | **−69 (−21.0%)** | **−277 (−28.4%)** |

## Verification

PASS — 6/6 files match.

Verification rule: strict equality on all fields except root `env:`, where
`sandbox ⊇ generated` (containment) is used to allow the shared base to
declare env vars that not every leaf workflow uses.

## Bugs found

Five pre-existing bugs in the original source files were discovered as a direct
consequence of refactoring. All were invisible in the standalone originals and
became visible only when shared structure was extracted. Two have been fixed;
three are noted below and left for a future pass.

### APP env var used a concrete value instead of a placeholder

`APP: app` in `create-cloud-deploy-release` looked like a valid working value.
Every other env var used a `YOUR_*` placeholder. Users following the example
would silently deploy an app named "app". Fixed to `APP: YOUR_APP_NAME`.

**How refactoring exposed it:** pulling all env vars into a single shared base
placed all values side by side. The single concrete value among seven
placeholders was immediately conspicuous.

### docker/login-action version inconsistent across workflows

`cloudrun-declarative` had been updated to `docker/login-action@v2` while
`cloudrun-docker` and `cloudrun-buildpacks` remained on `@v1`. Fixed by
updating the shared `docker-auth-step.yaml++` base to `@v2` and removing the
now-redundant override.

**How refactoring exposed it:** once all three workflows shared a common step
base, the `@v2` override in `cloudrun-declarative` appeared as an explicit
leaf-level exception — a leaf overriding its base to a *newer* version is a
clear signal that the base is stale.

### *(Not yet fixed)* google-github-actions/auth version inconsistent across workflows

`google-auth-step.yaml++` declares `uses: google-github-actions/auth@v0`.
`create-cloud-deploy-release` overrides it to `@v1`. The four deploy-cloudrun
workflows and the GKE workflow stay on `@v0`. The base should be updated to
`@v1` and the override removed.

### *(Not yet fixed)* actions/checkout version inconsistent across workflows

`checkout-step.yaml++` declares `uses: actions/checkout@v3`.
`cloudrun-docker` and `cloudrun-source` override it to `@v2`. These two are
pinned to an older version; the overrides should either be removed (accepting
`@v3`) or the base should be reconsidered.

### *(Not yet fixed)* google-github-actions/deploy-cloudrun version inconsistent across workflows

`deploy-cloudrun-step.yaml++` declares `uses: google-github-actions/deploy-cloudrun@v0`.
`cloudrun-buildpacks` overrides it to `@v2` — a two-major-version jump — while
the other three deploy-cloudrun workflows stay on `@v0`. The base should be
updated to `@v2` and the override removed.

## Findings

### Shared workflow base (`cloudrun-workflow-base.yaml++`)

All five workflow files share the same trigger, job permissions, `runs-on`,
and — after this session — all env vars. The base now declares every
configurable variable in one place:

```yaml
env:
  PROJECT_ID: YOUR_PROJECT_ID
  GAR_LOCATION: YOUR_GAR_LOCATION
  REPOSITORY: YOUR_REPOSITORY_NAME
  SERVICE: YOUR_SERVICE_NAME
  REGION: YOUR_SERVICE_REGION
  SOURCE_DIRECTORY: YOUR_SOURCE_DIRECTORY
  APP: YOUR_APP_NAME
```

The "lenient" policy means env vars that appear in the majority of workflows
are promoted to the shared base even if not every variant uses all of them.
`REGION` in `create-cloud-deploy-release` remains as the only leaf-level env
override (`YOUR_APP_REGION` vs the base's `YOUR_SERVICE_REGION`), because the
values genuinely differ and cannot be merged.

### GAR image reference functions (`cloudrun.jq`)

Four jq functions cover the three image path patterns used across the
workflows:

| Function | Pattern | Used by |
|---|---|---|
| `gar_image` | `…/SERVICE:sha` | deploy-cloudrun (declarative) |
| `gar_image_with_repo` | `…/REPOSITORY/SERVICE:sha` | deploy-cloudrun (docker, buildpacks) |
| `gar_image_with_app` | `…/APP/APP:sha` | create-cloud-deploy-release |
| `build_and_push[_with_repo\|_with_app]` | full `docker build/push` scripts | step bases |

jq's `\()` interpolation was required for multi-line `run:` scripts because
jq++ cannot interpolate `eval:` directives as substrings inside block scalars
(see [dakusui/jqplusplus#59](https://github.com/dakusui/jqplusplus/issues/59)).

### Step-level node inheritance

Seven step base files under `shared/steps/` cover every repeated GitHub
Actions step. Node-level `$extends` (within array elements) allows leaf files
to inherit the common shape and override only what differs:

| Base file | Fields in base | Variant overrides |
|---|---|---|
| `google-auth-step.yaml++` | name, id, uses @v0, WIF with fields | `token_format`, `name`, `uses @v1`, hardcoded WIF values |
| `docker-auth-step.yaml++` | name, id, uses @v2, username/password/registry | — (was @v1, updated) |
| `checkout-step.yaml++` | name, uses @v3 | `uses @v2` |
| `show-output-step.yaml++` | name, run | — |
| `build-and-push-step.yaml++` | name, run (`build_and_push`) | `run` → `build_and_push_with_repo` |
| `build-and-push-app-step.yaml++` | name, run (`build_and_push_with_app`) | — |
| `deploy-cloudrun-step.yaml++` | name, id, uses @v0, service, region | `uses @v2`, `with.image`, `with.metadata`, `with.source` |

### DuplicationRatio interpretation

The large baseline duplication ratio (18.7%, 4 maximal dup groups, 52 excess
key-value pairs) reflects that the workflows-3 originals carry more structural
repetition than workflows-2 (9.0%). This is consistent with the lenient env-var
strategy: promoting all env vars into the shared base causes the generated
output to include those fields uniformly across all variants, increasing
measured structural overlap in the baseline. The refactored sources reduce this
to 3.1% (−15.6 pp), the strongest improvement across all three approaches.

### Per-subfolder outcomes

**deploy-cloudrun** (−51% lines, −58% words) — the largest gain. Four files
with heavily overlapping structure; every action step is backed by a shared
base. `cloudrun-source` and `cloudrun-declarative` now have no leaf-level env
declarations at all.

**create-cloud-deploy-release** (−24% lines, −25% words) — moderate. The
workflow inherits the common base, uses `build-and-push-app-step` and
`checkout-step`. Remaining bulk (Cloud Deploy pipeline management, release
creation, manifest rendering) is unique and stays inline.

**get-gke-credentials** (≈0%) — neutral by design. Only Checkout and Google
Auth use shared bases; the remaining GKE-specific steps (Docker login,
multi-flag docker build, Kustomize, kubectl) are unique to this workflow.

### Verify rule refinement

The verification rule was relaxed then re-tightened during the session:

1. **Initial**: strict equality (`diff`)
2. **Relaxed**: full containment (`sandbox ⊇ generated`) — needed to allow
   env var consolidation into the shared base
3. **Tightened**: strict equality everywhere *except* root `env:`, where
   containment applies — the minimal relaxation that enables env consolidation
   without masking regressions elsewhere

### Limitations

- **Block scalar interpolation**: `eval:` directives do not interpolate as
  substrings inside YAML block scalars (`|-`). Workaround: make the entire
  value an `eval:string:` expression using jq's `\()`. Reported as
  dakusui/jqplusplus#59.
- **Array merging**: jq++ deep-merges objects but shallow-replaces arrays.
  Base `steps: []` is fully replaced by the leaf sequence.
- **YAML comments stripped**: the jq++ → yq round-trip removes all comments.
  Savings measured against the generated baseline; measuring against originals
  would inflate the apparent reduction.
