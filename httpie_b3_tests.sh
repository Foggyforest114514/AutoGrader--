#!/usr/bin/env bash
set -Eeuo pipefail

B3_BASE_URL="${B3_BASE_URL:-http://127.0.0.1:8003}"
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

echo "B3 base URL: ${B3_BASE_URL}"

health="$(request_json GET "${B3_BASE_URL}/health")"
assert_jq "${health}" '.status == "ok"' "B3 health should be ok"
echo "OK health"

questions="$(request_json POST "${B3_BASE_URL}/api/v1/b3/questions/import/problem-txt")"
assert_jq "${questions}" 'type == "array" and length > 0' "seed import should return questions"
echo "OK import seed questions"

question_list="$(request_json GET "${B3_BASE_URL}/api/v1/b3/questions")"
assert_jq "${question_list}" 'map(.id) | index("Q10") != null' "question list should include Q10"
assert_jq "${question_list}" 'map(.id) | index("API_DEMO") != null' "question list should include API_DEMO"
echo "OK list questions"

q10="$(request_json GET "${B3_BASE_URL}/api/v1/b3/questions/Q10")"
assert_jq "${q10}" '.id == "Q10" and (.test_cases | length) > 0' "Q10 detail should include test cases"
echo "OK question detail"

q10_answer="$(request_json POST "${B3_BASE_URL}/api/v1/b3/evaluate/answer/Q10")"
assert_jq "${q10_answer}" '.question_id == "Q10" and .overall_score >= 0 and .total_count > 0' "Q10 reference answer should evaluate"
echo "OK reference answer evaluation"

api_demo="$(request_json POST "${B3_BASE_URL}/api/v1/b3/evaluate" \
  question_id=API_DEMO \
  submission_id=api-demo-httpie \
  language=python \
  submitted_code='def add(a, b):
    return a + b
')"
assert_jq "${api_demo}" '.question_id == "API_DEMO" and .overall_score >= 0 and .total_count > 0' "API_DEMO submission should evaluate"
echo "OK API_DEMO evaluation"

unsafe="$(request_json POST "${B3_BASE_URL}/api/v1/b3/evaluate" \
  question_id=Q10 \
  submission_id=unsafe-httpie \
  language=shell \
  submitted_code='rm -rf /tmp/autograder-httpie-test')"
assert_jq "${unsafe}" '.static_issues | length > 0' "unsafe shell should produce static issues"
echo "OK static safety check"

echo "B3 httpie tests passed"
