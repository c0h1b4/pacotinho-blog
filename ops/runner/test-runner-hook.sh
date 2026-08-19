#!/usr/bin/env bash
set -euo pipefail

root=$(mktemp -d)
trap 'rm -rf -- "${root}"' EXIT
allowlist=${root}/allow
output=${root}/output
hook=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pacotinho-blog-runner-job-started
sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

write_valid_allowlist() {
  printf '.github/workflows/build-immutable.yml %s\n' "${sha}" >"${allowlist}"
}

run_hook() {
  env -i \
    PATH="${PATH}" \
    PACOTINHO_BLOG_HOOK_TESTING=true \
    PACOTINHO_BLOG_RUNNER_ALLOWLIST="${allowlist}" \
    GITHUB_REPOSITORY=c0h1b4/pacotinho-blog \
    GITHUB_ACTOR=c0h1b4 \
    GITHUB_TRIGGERING_ACTOR=c0h1b4 \
    GITHUB_EVENT_NAME=workflow_dispatch \
    GITHUB_REF=refs/heads/main \
    GITHUB_RUN_ID=123456789 \
    GITHUB_RUN_ATTEMPT=1 \
    GITHUB_WORKFLOW_REF=c0h1b4/pacotinho-blog/.github/workflows/build-immutable.yml@refs/heads/main \
    GITHUB_WORKFLOW_SHA="${sha}" \
    "$@" "${hook}"
}

expect_rejection() {
  local reason=$1
  shift
  if "$@" >"${output}" 2>&1; then
    printf 'expected blog runner hook rejection: %s\n' "${reason}" >&2
    exit 1
  fi
  grep -qx "trusted_blog_runner_job_rejected=${reason}" "${output}"
}

write_valid_allowlist
run_hook env | grep -qx 'trusted_blog_runner_job_accepted=true'
expect_rejection repository run_hook env GITHUB_REPOSITORY=c0h1b4/pacotinho
expect_rejection repository run_hook env GITHUB_REPOSITORY=someone/pacotinho-blog
expect_rejection actor run_hook env GITHUB_ACTOR=someone-else
expect_rejection triggering_actor run_hook env GITHUB_TRIGGERING_ACTOR=someone-else
expect_rejection event run_hook env GITHUB_EVENT_NAME=pull_request
expect_rejection ref run_hook env GITHUB_REF=refs/heads/dev
expect_rejection run_id run_hook env GITHUB_RUN_ID=0
expect_rejection run_attempt run_hook env GITHUB_RUN_ATTEMPT=attempt-1
expect_rejection workflow_sha run_hook env GITHUB_WORKFLOW_SHA=bbbb
expect_rejection workflow_sha_mismatch run_hook env \
  GITHUB_WORKFLOW_SHA=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
expect_rejection workflow_ref run_hook env \
  GITHUB_WORKFLOW_REF=c0h1b4/pacotinho/.github/workflows/build-immutable.yml@refs/heads/main

printf '# no approved workflow\n' >"${allowlist}"
expect_rejection allowlist_incomplete run_hook env

printf '%s\n' \
  ".github/workflows/build-immutable.yml ${sha}" \
  ".github/workflows/build-immutable.yml ${sha}" \
  >"${allowlist}"
expect_rejection allowlist_duplicate run_hook env

printf '.github/workflows/build-immutable.yml %s unexpected\n' "${sha}" >"${allowlist}"
expect_rejection allowlist_format run_hook env
printf '.github/workflows/validate.yml %s\n' "${sha}" >"${allowlist}"
expect_rejection allowlist_path run_hook env
printf '.github/workflows/build-immutable.yml not-a-sha\n' >"${allowlist}"
expect_rejection allowlist_sha run_hook env
printf '.github/workflows/build-immutable.yml %040d\n' 0 >"${allowlist}"
expect_rejection allowlist_sha run_hook env

printf '%s\n' \
  '# Approved privileged blog workflow' \
  '' \
  ".github/workflows/build-immutable.yml ${sha}" \
  >"${allowlist}"
run_hook env | grep -qx 'trusted_blog_runner_job_accepted=true'

printf 'blog_runner_hook_tests_passed=true\n'
