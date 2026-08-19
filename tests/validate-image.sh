#!/usr/bin/env bash
set -euo pipefail

required_environment=(
  BUILDKIT_IMAGE
  VALIDATION_SOURCE_SHA
  VALIDATION_TREE_SHA
  VALIDATION_IMAGE_CREATED
  VALIDATION_SOURCE_COMMITTED_AT
  VALIDATION_SOURCE_DATE_EPOCH
  VALIDATION_BUILD_ID
)
for name in "${required_environment[@]}"; do
  [[ -n "${!name:-}" ]] || {
    printf 'missing validation environment: %s\n' "${name}" >&2
    exit 1
  }
done

[[ "$(uname -m)" == x86_64 ]]
[[ "${BUILDKIT_IMAGE}" =~ ^moby/buildkit@sha256:[0-9a-f]{64}$ ]]
[[ "${VALIDATION_SOURCE_SHA}" =~ ^[0-9a-f]{40}$ ]]
[[ "${VALIDATION_TREE_SHA}" =~ ^[0-9a-f]{40}$ ]]
[[ "${VALIDATION_IMAGE_CREATED}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
[[ "${VALIDATION_SOURCE_COMMITTED_AT}" == "${VALIDATION_IMAGE_CREATED}" ]]
[[ "${VALIDATION_SOURCE_DATE_EPOCH}" =~ ^[0-9]+$ ]]
[[ "${VALIDATION_BUILD_ID}" =~ ^sha256:[0-9a-f]{64}$ ]]

run_id=${GITHUB_RUN_ID:-local}
run_attempt=${GITHUB_RUN_ATTEMPT:-0}
image_repository=${VALIDATION_IMAGE_REPOSITORY:-pacotinho-blog-validation}
first_tag=${image_repository}:first
replay_tag=${image_repository}:replay
builder_prefix="pacotinho-blog-validation-${run_id}-${run_attempt}-$$"
first_builder=${builder_prefix}-first
replay_builder=${builder_prefix}-replay
smoke_name=${builder_prefix}-smoke
first_builder_created=false
replay_builder_created=false
smoke_container=

cleanup() {
  status=$?
  trap - EXIT
  if [[ -n "${smoke_container}" ]]; then
    docker rm --force "${smoke_container}" >/dev/null 2>&1 || true
  fi
  if [[ "${first_builder_created}" == true ]]; then
    docker buildx rm "${first_builder}" >/dev/null 2>&1 || true
  fi
  if [[ "${replay_builder_created}" == true ]]; then
    docker buildx rm "${replay_builder}" >/dev/null 2>&1 || true
  fi
  docker image rm "${first_tag}" "${replay_tag}" >/dev/null 2>&1 || true
  exit "${status}"
}
trap cleanup EXIT

create_builder() {
  local name=$1
  docker buildx create \
    --driver docker-container \
    --driver-opt "image=${BUILDKIT_IMAGE}" \
    --name "${name}" >/dev/null
}

build_validation_image() {
  local builder=$1
  local tag=$2
  docker buildx build \
    --builder "${builder}" \
    --load \
    --no-cache \
    --platform linux/amd64 \
    --provenance=false \
    --sbom=false \
    --tag "${tag}" \
    --build-arg "OCI_REVISION=${VALIDATION_SOURCE_SHA}" \
    --build-arg "OCI_VERSION=${VALIDATION_SOURCE_SHA}" \
    --build-arg "OCI_CREATED=${VALIDATION_IMAGE_CREATED}" \
    --build-arg "OCI_SOURCE_COMMITTED_AT=${VALIDATION_SOURCE_COMMITTED_AT}" \
    --build-arg "OCI_TREE=${VALIDATION_TREE_SHA}" \
    --build-arg "OCI_BUILD_ID=${VALIDATION_BUILD_ID}" \
    --build-arg "SOURCE_DATE_EPOCH=${VALIDATION_SOURCE_DATE_EPOCH}" \
    .
}

create_builder "${first_builder}"
first_builder_created=true
build_validation_image "${first_builder}" "${first_tag}"
docker buildx rm "${first_builder}" >/dev/null
first_builder_created=false
first_image_id=$(docker image inspect --format '{{.Id}}' "${first_tag}")
first_image_fingerprint=$(docker image inspect \
  --format '{{json .Config}}|{{json .RootFS.Layers}}' "${first_tag}" \
  | sha256sum | cut -d' ' -f1)

create_builder "${replay_builder}"
replay_builder_created=true
build_validation_image "${replay_builder}" "${replay_tag}"
docker buildx rm "${replay_builder}" >/dev/null
replay_builder_created=false
replay_image_id=$(docker image inspect --format '{{.Id}}' "${replay_tag}")
replay_image_fingerprint=$(docker image inspect \
  --format '{{json .Config}}|{{json .RootFS.Layers}}' "${replay_tag}" \
  | sha256sum | cut -d' ' -f1)
printf 'validation_image_fingerprints first=%s replay=%s\n' \
  "${first_image_fingerprint}" "${replay_image_fingerprint}"
[[ "${replay_image_fingerprint}" == "${first_image_fingerprint}" ]]

[[ "$(docker image inspect --format '{{.Os}}/{{.Architecture}}' "${first_tag}")" == linux/amd64 ]]
[[ "$(docker image inspect --format '{{.Config.User}}' "${first_tag}")" == node ]]
[[ "$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.source"}}' "${first_tag}")" == 'https://github.com/c0h1b4/pacotinho-blog' ]]
[[ "$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "${first_tag}")" == "${VALIDATION_SOURCE_SHA}" ]]
[[ "$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.version"}}' "${first_tag}")" == "${VALIDATION_SOURCE_SHA}" ]]
[[ "$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.created"}}' "${first_tag}")" == "${VALIDATION_IMAGE_CREATED}" ]]
[[ "$(docker image inspect --format '{{index .Config.Labels "io.pacotinho.source.tree"}}' "${first_tag}")" == "${VALIDATION_TREE_SHA}" ]]
[[ "$(docker image inspect --format '{{index .Config.Labels "io.pacotinho.build.identity"}}' "${first_tag}")" == "${VALIDATION_BUILD_ID}" ]]
[[ "$(docker image inspect --format '{{if index .Config.Labels "io.pacotinho.build.run-id"}}present{{end}}' "${first_tag}")" == '' ]]
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "${first_tag}" \
  | grep -Fxq "SOURCE_DATE_EPOCH=${VALIDATION_SOURCE_DATE_EPOCH}"
[[ "$(docker image inspect --format '{{json .Config.Healthcheck.Test}}' "${first_tag}")" == *'http://127.0.0.1:3002/blog'* ]]
docker run --rm --network none --entrypoint id "${first_tag}" -u \
  | grep -Eq '^[1-9][0-9]*$'

smoke_container=$(docker run --detach \
  --name "${smoke_name}" \
  --network none \
  --read-only \
  --health-interval 2s \
  --health-start-period 1s \
  --health-timeout 5s \
  --health-retries 3 \
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=32m,mode=1777 \
  --tmpfs /app/.next/cache:rw,noexec,nosuid,nodev,size=64m,mode=1777 \
  "${first_tag}")
[[ "$(docker container inspect --format '{{.Image}}' "${smoke_container}")" == "${first_image_id}" ]]
docker exec "${smoke_container}" id -u | grep -Eq '^[1-9][0-9]*$'

smoke_healthy=false
smoke_deadline=$((SECONDS + 90))
while (( SECONDS < smoke_deadline )); do
  health_status=$(docker container inspect \
    --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' \
    "${smoke_container}")
  endpoint_ok=false
  if /usr/bin/timeout 5s docker exec "${smoke_container}" node -e \
      "fetch('http://127.0.0.1:3002/blog').then(response=>process.exit(response.ok?0:1)).catch(()=>process.exit(1))"; then
    endpoint_ok=true
  fi
  if [[ "${health_status}" == healthy && "${endpoint_ok}" == true ]]; then
    smoke_healthy=true
    break
  fi
  [[ "$(docker container inspect --format '{{.State.Running}}' "${smoke_container}")" == true ]] \
    || break
  sleep 1
done
if [[ "${smoke_healthy}" != true ]]; then
  docker container inspect "${smoke_container}" >&2
  docker logs "${smoke_container}" >&2
  exit 1
fi

docker rm --force "${smoke_container}" >/dev/null
smoke_container=
printf 'independent_validation_images_verified=true\n'
