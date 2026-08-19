#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly root
cd "${root}"

fail() {
  printf 'immutable release regression failed: %s\n' "$*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing file: $1"
}

require_fixed() {
  local file=$1
  local expected=$2
  grep -Fq -- "${expected}" "${file}" \
    || fail "${file} is missing: ${expected}"
}

reject_fixed() {
  local file=$1
  local forbidden=$2
  if grep -Fq -- "${forbidden}" "${file}"; then
    fail "${file} contains forbidden text: ${forbidden}"
  fi
}

readonly dockerfile=Dockerfile
readonly build_workflow=.github/workflows/build-immutable.yml
readonly validate_workflow=.github/workflows/validate.yml
readonly validate_image_test=tests/validate-image.sh
readonly frontend='docker/dockerfile:1.7@sha256:a57df69d0ea827fb7266491f2813635de6f17269be881f696fbfdf2d83dda33e'
readonly node_image='node:24.13.0-bookworm-slim@sha256:46feb5752989c05b8606e6323fbbc3db667d14ade1c24f5d0d44d9ca9909d607'
readonly sbom_generator='docker/buildkit-syft-scanner@sha256:79e7b013cbec16bbb436f312819a49a4a57752b2270c1a9332ae1a10fcc82a68'

for file in \
  "${dockerfile}" \
  .dockerignore \
  "${build_workflow}" \
  "${validate_workflow}" \
  next.config.mjs \
  lib/build-time.ts \
  ops/runner/pacotinho-blog-runner-job-started \
  ops/runner/pacotinho-blog-workflows.allow.example \
  ops/runner/test-runner-hook.sh \
  "${validate_image_test}" \
  tests/test-sealed-context.py \
  package.json \
  README.md; do
  require_file "${file}"
done
[[ ! -e .github/workflows/deploy.yml ]] \
  || fail '.github/workflows/deploy.yml must not perform mutable deployment'
[[ ! -e docker-compose.yml ]] \
  || fail 'docker-compose.yml must not provide a same-host deployment shortcut'

IFS= read -r first_line <"${dockerfile}"
[[ "${first_line}" == "# syntax=${frontend}" ]] \
  || fail 'Dockerfile frontend is not digest-pinned'
[[ $(grep -Fxc "FROM ${node_image} AS base" "${dockerfile}") -eq 1 ]] \
  || fail 'Dockerfile build base is not exactly pinned'
[[ $(grep -Fxc "FROM ${node_image} AS runner" "${dockerfile}") -eq 1 ]] \
  || fail 'Dockerfile runtime base is not exactly pinned'
require_fixed "${dockerfile}" 'corepack prepare pnpm@10.11.0 --activate'
require_fixed "${dockerfile}" 'pnpm install --frozen-lockfile --ignore-scripts'
require_fixed "${dockerfile}" 'COPY --from=builder --chown=node:node /app/.next/standalone ./'
require_fixed "${dockerfile}" 'USER node'
require_fixed "${dockerfile}" 'http://127.0.0.1:3002/blog'
require_fixed next.config.mjs 'output: "standalone"'
for label in \
  org.opencontainers.image.source \
  org.opencontainers.image.revision \
  org.opencontainers.image.version \
  org.opencontainers.image.created \
  io.pacotinho.source.tree \
  io.pacotinho.build.identity; do
  require_fixed "${dockerfile}" "${label}="
done
reject_fixed "${dockerfile}" 'io.pacotinho.build.run-id'
reject_fixed "${dockerfile}" 'io.pacotinho.build.run-attempt'
require_fixed "${dockerfile}" 'ARG SOURCE_DATE_EPOCH'
require_fixed "${dockerfile}" 'PACOTINHO_SOURCE_REVISION="${OCI_REVISION}"'
require_fixed "${dockerfile}" 'SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH}"'
require_fixed next.config.mjs 'generateBuildId: async () => sourceRevision ?? "local-development"'
require_fixed lib/build-time.ts 'process.env.SOURCE_DATE_EPOCH'
reject_fixed app/sitemap.ts 'lastModified: new Date()'
reject_fixed app/feed.xml/route.ts '<lastBuildDate>${new Date().toUTCString()}</lastBuildDate>'
reject_fixed components/Footer.tsx 'new Date().getFullYear()'

for ignored in .git .github .next node_modules ops tests; do
  grep -Fxq -- "${ignored}" .dockerignore \
    || fail ".dockerignore does not exclude ${ignored}"
done

require_fixed "${validate_workflow}" 'pull_request:'
require_fixed "${validate_workflow}" 'runs-on: ubuntu-24.04'
require_fixed "${validate_workflow}" 'actionlint -color'
require_fixed "${validate_workflow}" 'bash tests/immutable-release.sh'
require_fixed "${validate_workflow}" 'node-version: 24.13.0'
require_fixed "${validate_workflow}" 'corepack prepare pnpm@10.11.0 --activate'
require_fixed "${validate_workflow}" 'pnpm install --frozen-lockfile'
require_fixed "${validate_workflow}" 'run: pnpm build'
require_fixed "${validate_workflow}" 'run: bash tests/validate-image.sh'
reject_fixed "${validate_workflow}" 'secrets.'
require_fixed "${validate_image_test}" '--platform linux/amd64'
require_fixed "${validate_image_test}" '--no-cache'
[[ $(grep -Fxc '    --no-cache \' "${validate_image_test}") -eq 1 ]] \
  || fail 'the shared validation function must force both builds to bypass layer cache'
require_fixed "${validate_image_test}" 'first_tag=${image_repository}:first'
require_fixed "${validate_image_test}" 'replay_tag=${image_repository}:replay'
require_fixed "${validate_image_test}" 'validation_image_ids first='
require_fixed "${validate_image_test}" 'SOURCE_DATE_EPOCH=${VALIDATION_SOURCE_DATE_EPOCH}'
require_fixed "${validate_image_test}" 'http://127.0.0.1:3002/blog'

require_fixed "${build_workflow}" 'workflow_dispatch:'
if grep -Eq '^[[:space:]]+(push|pull_request|schedule):' "${build_workflow}"; then
  fail 'immutable build workflow has a non-manual trigger'
fi
builder_flag_line=$(grep -nFm1 -- '          builder_created=true' "${build_workflow}" | cut -d: -f1)
builder_create_line=$(grep -nFm1 -- '          docker buildx create \' "${build_workflow}" | cut -d: -f1)
[[ -n "${builder_flag_line}" && -n "${builder_create_line}" && ${builder_flag_line} -lt ${builder_create_line} ]] \
  || fail 'Buildx cleanup flag must be armed before builder creation'
require_fixed "${build_workflow}" "github.repository == 'c0h1b4/pacotinho-blog'"
require_fixed "${build_workflow}" "github.ref == 'refs/heads/main'"
require_fixed "${build_workflow}" 'runs-on: [self-hosted, Linux, X64, pacotinho-blog-builder]'
require_fixed "${build_workflow}" 'readonly expected_workspace=/opt/actions-blog-runner/_work/pacotinho-blog/pacotinho-blog'
reject_fixed "${build_workflow}" 'runs-on: [self-hosted, Linux, X64, pacotinho-builder]'
require_fixed "${build_workflow}" '[[ "${SOURCE_SHA}" == "${GITHUB_SHA}" ]]'
require_fixed "${build_workflow}" 'git merge-base --is-ancestor "${GITHUB_WORKFLOW_SHA}" "${GITHUB_SHA}"'
reject_fixed "${build_workflow}" '[[ "${SOURCE_SHA}" == "${GITHUB_WORKFLOW_SHA}" ]]'
reject_fixed "${build_workflow}" '[[ "${GITHUB_WORKFLOW_SHA}" == "${GITHUB_SHA}" ]]'
require_fixed "${build_workflow}" '[[ "$(uname -m)" == x86_64 ]]'
reject_fixed "${build_workflow}" 'BUILD_CONTEXT_ARCHIVE'
require_fixed "${build_workflow}" 'os.memfd_create('
require_fixed "${build_workflow}" 'os.MFD_ALLOW_SEALING | os.MFD_CLOEXEC'
for seal in F_SEAL_SEAL F_SEAL_SHRINK F_SEAL_GROW F_SEAL_WRITE; do
  require_fixed "${build_workflow}" "fcntl.${seal}"
done
require_fixed "${build_workflow}" 'fcntl.F_ADD_SEALS'
require_fixed "${build_workflow}" 'fcntl.F_GET_SEALS'
require_fixed "${build_workflow}" 'context_stat.st_nlink != 0'
require_fixed "${build_workflow}" '["/usr/bin/git", "get-tar-commit-id"]'
require_fixed "${build_workflow}" 'git_object_id("blob", payload)'
require_fixed "${build_workflow}" 'git_tree_id(source_tree) != arguments.tree_sha'
require_fixed "${build_workflow}" 'immutable source archive tree mismatch'
require_fixed "${build_workflow}" 'subprocess.run('
require_fixed "${build_workflow}" 'stdin=context_fd'
require_fixed "${build_workflow}" 'stdout=sys.stderr'
require_fixed "${build_workflow}" 'BUILD_CONTEXT_SHA256=${build_context_sha256}'
require_fixed "${build_workflow}" '"kind": "git-archive"'
require_fixed "${build_workflow}" '"storage": "sealed-linux-memfd"'
require_fixed "${build_workflow}" '"kernel_seals": ["seal", "shrink", "grow", "write"]'
require_fixed README.md '`sealed-linux-memfd`'
require_fixed README.md 'A proveniência é SLSA v1 em modo máximo.'
require_fixed README.md "\`${sbom_generator}\`"
python3 tests/test-sealed-context.py | grep -qx 'sealed_context_helper_tests_passed=true'
require_fixed "${build_workflow}" '--platform linux/amd64'
require_fixed "${build_workflow}" 'push-by-digest=true'
require_fixed "${build_workflow}" '--provenance=mode=max,version=v1'
reject_fixed "${build_workflow}" '--provenance=mode=max \\'
require_fixed "${build_workflow}" "SBOM_GENERATOR: ${sbom_generator}"
require_fixed "${build_workflow}" '--attest "type=sbom,generator=${SBOM_GENERATOR}"'
require_fixed "${build_workflow}" 'f"type=sbom,generator={arguments.sbom_generator}"'
reject_fixed "${build_workflow}" '--sbom=true'
reject_fixed "${build_workflow}" 'docker/buildkit-syft-scanner:stable-1'
require_fixed "${build_workflow}" '"https://slsa.dev/provenance/v1"'
reject_fixed "${build_workflow}" '"https://slsa.dev/provenance/v0.2"'
require_fixed "${build_workflow}" '"https://spdx.dev/Document"'
require_fixed "${build_workflow}" 'build_definition = slsa.get("buildDefinition", {})'
require_fixed "${build_workflow}" 'internal_parameters.get("buildConfig")'
require_fixed "${build_workflow}" 'slsa.get("runDetails", {}).get("metadata", {})'
require_fixed "${build_workflow}" 'completeness.get("request") is not True'
require_fixed "${build_workflow}" 'build_definition.get("resolvedDependencies")'
require_fixed "${build_workflow}" 'node_digest_qualifier in material.get("uri", "")'
require_fixed "${build_workflow}" 'image_created=${source_committed_at}'
require_fixed "${build_workflow}" 'SOURCE_DATE_EPOCH=%s'
require_fixed "${build_workflow}" 'OCI_BUILD_ID=${BUILD_IDENTITY}'
require_fixed "${build_workflow}" 'SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}'
reject_fixed "${build_workflow}" 'OCI_BUILD_RUN_ID='
reject_fixed "${build_workflow}" 'OCI_BUILD_RUN_ATTEMPT='
require_fixed "${build_workflow}" 'image_digest=${index_digests[0]}'
require_fixed "${build_workflow}" 'release_index_digest='
require_fixed "${build_workflow}" 'image="${IMAGE_REPOSITORY}@${image_digest}"'
require_fixed "${build_workflow}" 'expected_image_id=$(docker image inspect --format'
require_fixed "${build_workflow}" 'smoke_container=$(docker run --detach'
require_fixed "${build_workflow}" '--network none'
require_fixed "${build_workflow}" '--read-only'
require_fixed "${build_workflow}" '--tmpfs /app/.next/cache:rw,noexec,nosuid,nodev,size=64m,mode=1777'
require_fixed "${build_workflow}" '[[ "$(docker container inspect --format '\''{{.Image}}'\'' "${smoke_container}")" == "${expected_image_id}" ]]'
require_fixed "${build_workflow}" 'docker exec "${smoke_container}" id -u'
require_fixed "${build_workflow}" 'smoke_deadline=$((SECONDS + 90))'
require_fixed "${build_workflow}" 'while (( SECONDS < smoke_deadline )); do'
require_fixed "${build_workflow}" '"${image}")'
require_fixed "${build_workflow}" '/usr/bin/timeout 5s docker exec "${smoke_container}"'
require_fixed "${build_workflow}" "fetch('http://127.0.0.1:3002/blog')"
require_fixed "${build_workflow}" '[[ "${health_status}" == healthy && "${endpoint_ok}" == true ]]'
require_fixed "${build_workflow}" 'docker rm --force "${smoke_container}"'
require_fixed "${build_workflow}" 'smoke_container='
smoke_line=$(grep -nF -- 'smoke_container=$(docker run --detach' "${build_workflow}" | cut -d: -f1)
publish_line=$(grep -nF -- '- name: Publish and verify exact source tag locator' "${build_workflow}" | cut -d: -f1)
[[ -n "${smoke_line}" && -n "${publish_line}" && ${smoke_line} -lt ${publish_line} ]] \
  || fail 'exact digest smoke test must complete before tag promotion'
require_fixed "${build_workflow}" 'readonly source_tag="${IMAGE_REPOSITORY}:${release_values[0]}"'
require_fixed "${build_workflow}" 'immutable_tag_conflict='
require_fixed "${build_workflow}" 'tag_action=already-present'
require_fixed "${build_workflow}" 'candidate_digest=$(docker buildx imagetools inspect "${image}"'
require_fixed "${build_workflow}" 'manifest[ _-]unknown'
require_fixed "${build_workflow}" 'grep -Fqx -- "ERROR: ${source_tag}: not found" "${inspect_error}"'
reject_fixed "${build_workflow}" '404([ :]+)not found'
require_fixed "${build_workflow}" '--prefer-index=false'
require_fixed "${build_workflow}" 'if digest != os.environ["IMAGE_DIGEST"]:'
require_fixed "${build_workflow}" 'workflow.get("run_id") != int(os.environ["GITHUB_RUN_ID"])'
require_fixed "${build_workflow}" '"reference": f"{repository}@{image_digest}"'
require_fixed "${build_workflow}" 'release-manifest.pending.json'
require_fixed "${build_workflow}" '"status": "pending"'
require_fixed "${build_workflow}" '"authoritative": False'
require_fixed "${build_workflow}" '"atomic_create_if_absent": False'
require_fixed "${build_workflow}" 'manifest.get("authoritative") is not False'
require_fixed "${build_workflow}" 'manifest["authoritative"] = True'
require_fixed "${build_workflow}" '"status": "verified"'
require_fixed "${build_workflow}" '"observed_digest": os.environ["VERIFIED_TAG_DIGEST"]'
require_fixed "${build_workflow}" 'Upload authoritative release manifest'
require_fixed "${build_workflow}" 'path: release-manifest.json'
publish_line=$(grep -nF -- '- name: Publish and verify exact source tag locator' "${build_workflow}" | cut -d: -f1)
upload_line=$(grep -nF -- '- name: Upload authoritative release manifest' "${build_workflow}" | cut -d: -f1)
[[ -n "${publish_line}" && -n "${upload_line}" && ${upload_line} -gt ${publish_line} ]] \
  || fail 'authoritative manifest upload must occur after successful tag verification'
require_fixed "${build_workflow}" "DOCKERFILE_FRONTEND: ${frontend}"
require_fixed "${build_workflow}" "NODE_IMAGE: ${node_image}"
require_fixed "${build_workflow}" '"generator": os.environ["SBOM_GENERATOR"]'
require_fixed "${build_workflow}" 'sbom.get("generator") != os.environ["SBOM_GENERATOR"]'
reject_fixed "${build_workflow}" ':latest'
reject_fixed "${build_workflow}" 'secrets.'

for forbidden in \
  'ssh ' \
  'scp ' \
  'rsync ' \
  'docker compose' \
  'docker stack' \
  'kubectl ' \
  'systemctl ' \
  'git reset --hard' \
  'git pull' \
  '/home/ubuntu/pacotinho-blog'; do
  reject_fixed "${build_workflow}" "${forbidden}"
done

readonly runner_hook=ops/runner/pacotinho-blog-runner-job-started
require_fixed "${runner_hook}" 'readonly INSTALLED_PATH=/usr/local/sbin/pacotinho-blog-builder-job-started'
require_fixed "${runner_hook}" 'readonly ALLOWLIST=/etc/github-blog-runner/pacotinho-blog-workflows.allow'
require_fixed "${runner_hook}" 'readonly EXPECTED_REPOSITORY=c0h1b4/pacotinho-blog'
require_fixed "${runner_hook}" 'readonly EXPECTED_WORKFLOW=.github/workflows/build-immutable.yml'
require_fixed "${runner_hook}" '[[ "${allowed_sha}" == "${GITHUB_WORKFLOW_SHA}" ]]'
if grep -Fxq 'readonly EXPECTED_REPOSITORY=c0h1b4/pacotinho' "${runner_hook}"; then
  fail 'blog runner hook must not authorize the protected Pacotinho repository'
fi
grep -Fxq '.github/workflows/build-immutable.yml 0000000000000000000000000000000000000000' \
  ops/runner/pacotinho-blog-workflows.allow.example \
  || fail 'blog runner allowlist example must be fail-closed before provisioning'
ops/runner/test-runner-hook.sh | grep -qx 'blog_runner_hook_tests_passed=true'

for runner_contract in \
  'repository-scoped' \
  'c0h1b4/pacotinho-blog' \
  'github-blog-runner' \
  '/opt/actions-blog-runner' \
  'pacotinho-blog-builder' \
  '/usr/local/sbin/pacotinho-blog-builder-job-started' \
  '/etc/github-blog-runner/pacotinho-blog-workflows.allow' \
  'ACTIONS_RUNNER_HOOK_JOB_STARTED=/usr/local/sbin/pacotinho-blog-builder-job-started'; do
  require_fixed README.md "${runner_contract}"
done
require_fixed README.md 'Não altere esse hook, não amplie seu allowlist'
require_fixed README.md 'Antes do dispatch, um administrador do runner deve revisar esse commit'
require_fixed README.md '`.github/workflows/build-immutable.yml <source_sha>`'
require_fixed README.md 'a conta `github-blog-runner` não pode executar essa atualização'
require_fixed README.md 'GHCR, porém, não documenta criação de tag com compare-and-swap'
require_fixed README.md '`image.tag.atomic_create_if_absent: false`'
require_fixed README.md 'qualquer requisito de atomicidade estrita deve bloquear a publicação'

while IFS= read -r action_ref; do
  [[ "${action_ref}" =~ ^[0-9a-f]{40}$ ]] \
    || fail "GitHub Action is not pinned to a full commit: ${action_ref}"
done < <(grep -E '^[[:space:]]+uses:[[:space:]]+' .github/workflows/*.yml \
  | while IFS= read -r line; do
      ref=${line##*@}
      printf '%s\n' "${ref%% *}"
    done)

printf 'immutable release regression tests passed\n'
