# Reproducing the jq++ Refactoring Results

This document explains how to reproduce the jq++ refactoring results for the
GitHub Actions workflow files in this repository, and how to experiment with
jq++ yourself.

## What is jq++?

[jq++](https://github.com/dakusui/jqplusplus) is a YAML/JSON elaboration engine
that adds inheritance and computed values on top of plain YAML. It lets you
eliminate repetition in YAML files the same way object-oriented languages
eliminate repetition in code — through shared base files, parameterisation, and
reusable function libraries.

## Prerequisites

Install the following tools and make sure they are on your `PATH`:

| Tool | Purpose | Repository |
|---|---|---|
| `jq++` | YAML++ elaboration engine | [dakusui/jqplusplus](https://github.com/dakusui/jqplusplus) |
| `yq` | YAML/JSON converter (`kislyuk/yq` flavour) | [kislyuk/yq](https://github.com/kislyuk/yq) |
| `jq` | JSON processor (dependency of `yq`) | [jqlang/jq](https://github.com/jqlang/jq) |

Verify your installation:

```bash
jq++ --version   # e.g. jq++ version v0.0.30
yq --version
jq  --version
```

> **Note on `yq` flavour**: this repository uses `kislyuk/yq`, whose YAML output
> flag is `-y '.'`. The unrelated `mikefarah/yq` tool uses a different flag (`-P`)
> and will not work here.

## Repository layout

```
workflows/
  deploy-cloudrun/           ← original workflow files
  create-cloud-deploy-release/
  get-gke-credentials/
  .refactoring/
    refactored/              ← jq++ source files (.yaml++, .jq)
      generate.sh            ← build output into sandbox/
      verify.sh              ← compare sandbox/ against generated/
      shared/                ← shared bases and function libraries
        cloudrun-workflow-base.yaml++
        cloudrun.jq
        steps/               ← shared step-level bases
          checkout-step.yaml++
          google-auth-step.yaml++
          docker-auth-step.yaml++
          build-and-push-step.yaml++
          build-and-push-app-step.yaml++
          deploy-cloudrun-step.yaml++
          show-output-step.yaml++
      deploy-cloudrun/       ← leaf .yaml++ files
      create-cloud-deploy-release/
      get-gke-credentials/
    generated/               ← committed baseline (what the sources should produce)
    sandbox/                 ← local build output (git-ignored)
```

## Reproducing the results

```bash
# 1. Build into sandbox/
workflows/.refactoring/refactored/generate.sh

# 2. Verify sandbox/ matches the committed baseline
workflows/.refactoring/refactored/verify.sh
```

A successful run prints `PASS  N/N files match`.

> **Note on verify.sh**: the verification rule uses strict equality on all
> fields except the root `env:` block, where containment applies
> (`refactored ⊇ generated`). This allows the shared base to declare env vars
> that not every leaf workflow uses without failing verification.

## Key jq++ concepts used

### `$extends` at the document level — workflow bases

A `.yaml++` file can inherit from one or more parent files. All five workflow
files share the same trigger, permissions, `runs-on`, and env vars, which are
extracted into `cloudrun-workflow-base.yaml++`. Each leaf extends the base and
overrides only `name` and `jobs.deploy.steps`:

```yaml
# shared/cloudrun-workflow-base.yaml++
$extends:
  - cloudrun.jq
on:
  push:
    branches:
      - $default-branch
env:
  PROJECT_ID: YOUR_PROJECT_ID
  GAR_LOCATION: YOUR_GAR_LOCATION
  ...
jobs:
  deploy:
    permissions:
      contents: 'read'
      id-token: 'write'
    runs-on: ubuntu-latest
    steps: []
```

```yaml
# deploy-cloudrun/cloudrun-docker.yaml++
$extends:
  - cloudrun-workflow-base.yaml++
name: Build and Deploy to Cloud Run
jobs:
  deploy:
    steps:
      - ...
```

Objects are deep-merged; arrays are shallow-replaced (the leaf's `steps` array
fully replaces the base's empty placeholder `steps: []`).

### `$extends` at the array-element level — step-level inheritance

jq++ supports `$extends` inside array elements, not only at the document root.
This allows individual GitHub Actions steps to be backed by named shared bases
while leaf files express only what differs:

```yaml
# shared/steps/deploy-cloudrun-step.yaml++
name: Deploy to Cloud Run
id: deploy
uses: google-github-actions/deploy-cloudrun@v0
with:
  service: ${{ env.SERVICE }}
  region: ${{ env.REGION }}
```

```yaml
# In a leaf workflow's steps array:
steps:
  - $extends:
      - steps/deploy-cloudrun-step.yaml++
    with:
      image: "eval:string:cloudrun::gar_image_with_repo"
```

The leaf inherits `name`, `id`, `uses`, `service`, and `region` from the base
and adds only the variant-specific `with.image` field.

This pattern makes version inconsistencies across workflows immediately visible:
a leaf that overrides `uses:` to a newer version is a direct signal that the
shared base is stale and should be updated.

### `.jq` modules — reusable functions for string construction

A `.jq` file included via `$extends` acts as a function library. The filename
becomes the call-site namespace prefix. `cloudrun.jq` defines the Google
Artifact Registry image string in three variants used across the workflows:

```jq
# shared/cloudrun.jq
def gar_image: "${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.SERVICE }}:${{ github.sha }}";
def gar_image_with_repo: "${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/${{ env.SERVICE }}:${{ github.sha }}";
def gar_image_with_app: "${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.APP }}/${{ env.APP }}:${{ github.sha }}";
def build_and_push: "docker build -t \"\(gar_image)\" ./\ndocker push \"\(gar_image)\"";
def build_and_push_with_repo: "docker build -t \"\(gar_image_with_repo)\" ./\ndocker push \"\(gar_image_with_repo)\"";
def build_and_push_with_app: "docker build -t \"\(gar_image_with_app)\" ./app\ndocker push \"\(gar_image_with_app)\"";
```

Usage in a leaf file:

```yaml
run: 'eval:string:cloudrun::build_and_push_with_repo'
```

> **Why `eval:string:` and not `eval:`?** jq++ cannot interpolate `eval:`
> directives as substrings inside YAML block scalars. The workaround is to
> make the entire value an `eval:string:` expression using jq's `\()`
> interpolation inside the function definition.
> See [dakusui/jqplusplus#59](https://github.com/dakusui/jqplusplus/issues/59).

### `_`-prefixed keys — private parameters

Keys starting with `_` are private configuration values available during
elaboration and stripped from the final output by `generate.sh`. They are
not heavily used in this corpus but are available for parameterising shared
bases. See the [Istio sample README](https://github.com/dakusui/istio/blob/master/samples/README_JSON%2B%2B.md)
for examples of this pattern.

## Experimenting with Claude Code

If you have [Claude Code](https://claude.com/claude-code) installed, this
repository ships with slash commands that let an AI agent do the heavy lifting
for you. Open Claude Code in this repo's root and try:

| Command | What it does |
|---|---|
| `/refactor-yamls workflows/` | Refactors the workflow directory using jq++ |
| `/report-refactored-yamls workflows/` | Writes a `REFACTORING_REPORT.md` for an already-refactored directory |

> **Tip**: you can also describe what you want in plain English —
> *"Reduce repetition in the workflows directory using jq++"* — and
> Claude Code will invoke the right skill automatically.

## Experimenting manually

Two tools are available depending on what you want to do:

- **`yq++`** elaborates a single `.yaml++` file and prints the result to stdout.
  Use this to inspect or debug one file at a time.
- **`yjoin`** elaborates a directory of `.yaml++` files and writes one output
  file per source file into an output directory.
  This is what `generate.sh` uses internally.

To inspect a single file:

```bash
SKILL_BIN="$(git rev-parse --show-toplevel)/.claude/skills/refactor-yamls/bin"
REFACTORED="workflows/.refactoring/refactored"
export JF_PATH="${REFACTORED}/shared"

"${SKILL_BIN}/yq++" "${REFACTORED}/deploy-cloudrun/cloudrun-docker.yaml++"
```

To rebuild all output files (equivalent to `generate.sh`):

```bash
"${SKILL_BIN}/yjoin" --out-dir /tmp/out "${REFACTORED}/deploy-cloudrun"
```

Try editing the `uses:` version in a step base, adding a new env var to
`cloudrun-workflow-base.yaml++`, or writing a new leaf workflow that extends
the base — then re-run `generate.sh` and `verify.sh` to see the effect.
