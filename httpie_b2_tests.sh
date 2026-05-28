#!/usr/bin/env bash
set -Eeuo pipefail

B2_BASE_URL="${B2_BASE_URL:-http://127.0.0.1:8002}"
export NO_PROXY="${NO_PROXY:-127.0.0.1,localhost}"
export no_proxy="${no_proxy:-127.0.0.1,localhost}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

request_json() {
  http --check-status --ignore-stdin --print=b "$@"
}

assert_jq() {
  local json="$1"
  local filter="$2"
  local message="$3"

  if ! jq -e "${filter}" >/dev/null <<<"${json}"; then
    echo "Assertion failed: ${message}" >&2
    echo "${json}" | jq . >&2
    exit 1
  fi
}

require_command http
require_command jq

echo "B2 base URL: ${B2_BASE_URL}"

valid="$(request_json POST "${B2_BASE_URL}/api/v1/submission" \
  question_id=API_DEMO \
  assignment_id=httpie-assignment \
  student_user_id=20260001 \
  language=python \
  code='def add(a, b):
    return a + b
')"
assert_jq "${valid}" '.submission_id and .status and (.message | contains("代码接收成功"))' "valid B2 submission should be accepted"
echo "OK accept valid submission submission_id=$(jq -r '.submission_id' <<<"${valid}")"

set +e
invalid="$(http --check-status --ignore-stdin --print=hb POST "${B2_BASE_URL}/api/v1/submission" \
  question_id=API_DEMO \
  assignment_id=httpie-assignment \
  student_user_id=abc \
  language=python \
  code='print(1)' 2>&1)"
invalid_status="$?"
set -e

if [[ "${invalid_status}" -eq 0 ]]; then
  echo "Assertion failed: invalid student_user_id should not be accepted" >&2
  echo "${invalid}" >&2
  exit 1
fi

if ! grep -q '400 Bad Request' <<<"${invalid}"; then
  echo "Assertion failed: invalid student_user_id should return HTTP 400" >&2
  echo "${invalid}" >&2
  exit 1
fi
echo "OK reject invalid student_user_id"

echo "B2 httpie tests passed"
