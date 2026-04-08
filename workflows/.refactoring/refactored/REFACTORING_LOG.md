# Refactoring Log: workflows/

Chronological record of the jq++ refactoring session. Each entry
corresponds to one commit; entries are ordered oldest → newest.

---

## Apply node-level $extends to Google Auth step
`9e3233f`

Extract the common Google Auth step into `shared/google-auth-step.yaml++`
and use `$extends` at the array-element level in all 5 workflow files.

- buildpacks, docker, declarative: extend base + add `token_format`
- source: extend base as-is (no `token_format`)
- cloud-deploy: extend base + override name/uses for `auth@v1`

Also removes the temporary `google_auth_step` jq function that was added
during exploration in favour of this cleaner node-level approach.

---

## Apply node-level $extends to Docker Auth step
`319fdf4`

Extract the common Docker Auth step into `shared/docker-auth-step.yaml++`.

- buildpacks, docker: extend base as-is (`login-action@v1`)
- declarative: extend base + override `uses` to `login-action@v2`

### Discussion

The Docker Auth step repeats the same pattern as the Google Auth step
refactored in the previous commit. Confirmed all three fields (username,
password, registry) are identical across the three files that use it;
only the action version differs (`@v1` vs `@v2` in cloudrun-declarative).
Applied node-level `$extends` with `docker-auth-step.yaml++` as the base,
overriding `uses` in the declarative variant.

---

## Apply node-level $extends to Google Auth step in GKE workflow
`dea8793`

The GKE workflow's auth step shares the same action and WIF fields as the
other workflows, just with different name, id, and hardcoded example values
for `workload_identity_provider` and `service_account`. These are overrides
on top of `google-auth-step.yaml++`, so the base still applies.

### Discussion

After applying node-level `$extends` to the deploy-cloudrun workflows, the
GKE workflow was left fully inline. Overriding only the differing attributes
is sufficient — `$extends` at the node level followed by overrides for name,
id, and the two `with` fields that differ. The action version (`auth@v0`) and
the `with` key structure are inherited unchanged from the base.

---

## Extract Show Output step into shared base
`e05a900`

All four deploy-cloudrun workflows end with an identical Show Output step.
Extracted into `shared/show-output-step.yaml++` and replaced inline in each.

### Discussion

First in a one-by-one pass over repeated step patterns. Show Output was
identified as the clearest win — 100% identical across all four cloudrun
workflows with no variants needed.

---

## Extract Checkout step into shared base
`9d8f36d`

Added `shared/checkout-step.yaml++` pinned to `actions/checkout@v3`.
Applied across all 5 workflows; cloudrun-docker and cloudrun-source
override `uses` to `@v2`.

### Discussion

Second in the one-by-one pass. Checkout appears in all 5 workflow files in
two versions (`@v3` and `@v2`). Base is pinned to `@v3` (majority); the two
`@v2` files override a single field.

---

## Extract Build and Push Container step into shared base
`457d585`

Added `build_and_push` / `build_and_push_with_repo` functions to
`cloudrun.jq` and `shared/build-and-push-step.yaml++` as the base step.

- cloudrun-declarative: extends base as-is (`gar_image`, no REPOSITORY)
- cloudrun-docker: extends base + overrides `run` with `build_and_push_with_repo`

### Discussion

Third in the one-by-one pass. The two occurrences differ in their image path
(with vs without REPOSITORY), so a plain `$extends` + field override is not
enough — the `run:` value is a block scalar that cannot be partially
interpolated by jq++.

To keep leaf files readable, the string construction complexity was pushed
entirely to the shared side: `build_and_push` / `build_and_push_with_repo` in
`cloudrun.jq` use jq's `\()` interpolation to compose the full two-line shell
script. The leaf files reference these by name via `eval:string:`, so they
remain clean. The jq functions also required escaped quotes (`\"`) to preserve
the shell quoting around the image reference that was present in the original
block scalars.

See also: [dakusui/jqplusplus#59](https://github.com/dakusui/jqplusplus/issues/59) —
`eval:` directives are not interpolated inside block scalar strings; workaround
is to make the entire value an `eval:string:` expression using jq's `\()`.

---

## Move shared step files into shared/steps/ subdirectory
`d333129`

Relocated the five step base files from `shared/` into `shared/steps/` to
separate individual step objects from workflow-level bases. `JF_PATH` in
`generate.sh` is extended to include `shared/steps/` so leaf files continue
to reference step bases by bare filename without path changes.

### Discussion

`shared/` was mixing two conceptually different things: workflow/service-level
bases (`cloudrun-workflow-base`, `app-service-base`) and individual step
objects (`checkout`, `google-auth`, `docker-auth`, etc.). Grouping steps under
`shared/steps/` makes the distinction explicit.

---

## Reference step bases with steps/ prefix instead of extending JF_PATH
`6a74619`

Revert the `JF_PATH` expansion from the previous commit and instead prefix
all step `$extends` references with `steps/` (e.g. `steps/checkout-step.yaml++`).
jq++ resolves this path relative to the existing `shared/` JF_PATH entry,
so no path configuration change is needed.

### Discussion

Adding `shared/steps/` to `JF_PATH` was unnecessary: since `shared/` is already
on `JF_PATH`, a `steps/` subdirectory path prefix in each `$extends` reference
resolves correctly without any `JF_PATH` change. This is simpler and makes the
location of each step file self-evident at the call site.

---

## Extract Deploy to Cloud Run step into shared base
`da82b1c`

Create `shared/steps/deploy-cloudrun-step.yaml++` with the common fields
(name, id, `uses @v0`, service, region) shared by all 4 Cloud Run workflow
files. Apply node-level `$extends` in each leaf, overriding only the
variant-specific field:

- cloudrun-docker: adds `with.image` (`gar_image_with_repo`)
- cloudrun-buildpacks: adds `uses @v2` + `with.image` (`gar_image_with_repo`)
- cloudrun-declarative: adds `with.metadata` (`service.yaml`)
- cloudrun-source: adds `with.source` (`./`)

### Discussion

The "Deploy to Cloud Run" step appeared verbatim in all 4 workflow files with
only a single trailing field differing per variant (image, metadata, source).
The shared base captures the `@v0` uses version, service, and region — the
three fields present in every variant. cloudrun-buildpacks additionally
overrides `uses` to `@v2`, demonstrating that node-level `$extends` handles
version differences cleanly without a separate base.

This is the final repeated step in the deploy-cloudrun group; every action
step in that subtree is now backed by a shared base file.

---

## Factor repeated GAR image pattern and inline steps in cloud-deploy workflow
`cd259b8`

Two improvements to `create-cloud-deploy-release/cloud-deploy-to-cloud-run.yaml++`:

1. Apply `$extends` to the inline Checkout step so it uses the shared
   `checkout-step.yaml++` base, consistent with the other workflow files.

2. Add `gar_image_with_app` / `build_and_push_with_app` functions to
   `cloudrun.jq` and create `shared/steps/build-and-push-app-step.yaml++`.
   The cloud-deploy workflow uses `APP/APP` as the image path component
   (distinct from `SERVICE` and `REPOSITORY/SERVICE` used by the Cloud Run
   deploy workflows). The long GAR image string appeared three times in the
   same file: twice in the build+push run block and once in the `images:` field
   of the create-cloud-deploy-release step. All three occurrences are now
   driven by `gar_image_with_app`.

### Discussion

The analysis covered all three workflow groups (deploy-cloudrun,
create-cloud-deploy-release, get-gke-credentials). The deploy-cloudrun group
was already fully factored.

In cloud-deploy, the GAR image pattern appeared verbatim three times — twice
as a shell argument in the build/push step and once as a prefix-qualified value
(`app=...`) in the `images:` field of the release step. The prefix case was
handled with jq string interpolation:

```yaml
images: 'eval:string:"app=\(cloudrun::gar_image_with_app)"'
```

This is the same workaround as dakusui/jqplusplus#59.

In get-gke-credentials, no new extraction was warranted: the Docker login,
Build, Publish, Kustomize, and Deploy steps each have a unique shape used only
once, so inline is the right call there.

---

## Remove redundant id override in gke Google Auth step
`b3f4aca`

The shared `google-auth-step.yaml++` base already declares `id: auth`.
The `gke-build-deploy.yaml++` step was overriding it with the identical
value `'auth'`, which had no effect.

### Discussion

Spotted as a nit: node-level `$extends` merges attributes from the base, so
any attribute in the leaf that duplicates the base value exactly is dead weight.
A full audit of all `$extends` blocks across all three workflow groups found
this as the only redundant override. All other overrides — version pins,
additive `with` fields, and differing names — are intentional.
