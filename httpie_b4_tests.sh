#!/usr/bin/env bash
set -Eeuo pipefail

B4_BASE_URL="${B4_BASE_URL:-http://127.0.0.1:8000}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d%H%M%S)}"
PASSWORD="${PASSWORD:-HttpieTest123}"
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

require_command date
require_command http
require_command jq

teacher_username="t${RUN_ID}"
teacher_email="teacher-${RUN_ID}@example.com"
student_username="s${RUN_ID}"
student_email="student-${RUN_ID}@example.com"
student_id="${RUN_ID}"
course_code="CS-${RUN_ID}"
class_code="C-${RUN_ID}"

echo "B4 base URL: ${B4_BASE_URL}"
echo "Run ID: ${RUN_ID}"

health="$(request_json GET "${B4_BASE_URL}/health")"
assert_jq "${health}" '.status == "healthy"' "B4 health should be healthy"
echo "OK health"

teacher_register="$(request_json POST "${B4_BASE_URL}/api/v1/auth/register" \
  username="${teacher_username}" \
  password="${PASSWORD}" \
  email="${teacher_email}" \
  real_name="HTTPie Teacher ${RUN_ID}" \
  role=teacher \
  teacher_id="T${RUN_ID}" \
  department="Integration")"
assert_jq "${teacher_register}" '.code == 200 and .data.role == "teacher"' "teacher registration should succeed"
echo "OK register teacher"

student_register="$(request_json POST "${B4_BASE_URL}/api/v1/auth/register" \
  username="${student_username}" \
  password="${PASSWORD}" \
  email="${student_email}" \
  real_name="HTTPie Student ${RUN_ID}" \
  role=student \
  student_id="${student_id}")"
assert_jq "${student_register}" '.code == 200 and .data.role == "student"' "student registration should succeed"
student_user_id="$(jq -r '.data.user_id' <<<"${student_register}")"
echo "OK register student user_id=${student_user_id}"

teacher_login="$(request_json POST "${B4_BASE_URL}/api/v1/auth/login" \
  username="${teacher_username}" \
  password="${PASSWORD}")"
teacher_token="$(jq -r '.data.token' <<<"${teacher_login}")"
assert_jq "${teacher_login}" '.code == 200 and .data.role == "teacher"' "teacher login should succeed"
echo "OK login teacher"

student_login="$(request_json POST "${B4_BASE_URL}/api/v1/auth/login" \
  username="${student_id}" \
  password="${PASSWORD}")"
student_token="$(jq -r '.data.token' <<<"${student_login}")"
assert_jq "${student_login}" '.code == 200 and .data.role == "student"' "student login by student_id should succeed"
echo "OK login student"

course="$(request_json POST "${B4_BASE_URL}/api/v1/courses" \
  "Authorization:Bearer ${teacher_token}" \
  courseName="HTTPie Integration ${RUN_ID}" \
  courseCode="${course_code}" \
  semester="2026-S1" \
  description="Created by httpie_b4_tests.sh")"
course_id="$(jq -r '.data.course_id' <<<"${course}")"
assert_jq "${course}" '.code == 200 and (.data.course_id | type == "number")' "course creation should return course_id"
echo "OK create course course_id=${course_id}"

class_resp="$(request_json POST "${B4_BASE_URL}/api/v1/classes" \
  "Authorization:Bearer ${teacher_token}" \
  courseId:="${course_id}" \
  className="HTTPie Class ${RUN_ID}" \
  classCode="${class_code}")"
class_id="$(jq -r '.data.class_id' <<<"${class_resp}")"
assert_jq "${class_resp}" '.code == 200 and (.data.class_id | type == "number")' "class creation should return class_id"
echo "OK create class class_id=${class_id}"

add_student="$(request_json POST "${B4_BASE_URL}/api/v1/classes/${class_id}/students" \
  "Authorization:Bearer ${teacher_token}" \
  studentUserId:="${student_user_id}")"
assert_jq "${add_student}" '.code == 200' "adding student to class should succeed"
echo "OK add student to class"

due_date="$(date -u -d '+7 days' '+%Y-%m-%dT%H:%M:%SZ')"
assignment="$(request_json POST "${B4_BASE_URL}/api/v1/assignments" \
  "Authorization:Bearer ${teacher_token}" \
  title="HTTPie Assignment ${RUN_ID}" \
  description="Created by httpie_b4_tests.sh" \
  classId:="${class_id}" \
  question_id=API_DEMO \
  dueDate="${due_date}" \
  isPublished:=true \
  allowResubmit:=true)"
assignment_id="$(jq -r '.data.assignment_id' <<<"${assignment}")"
assert_jq "${assignment}" '.code == 200 and (.data.assignment_id | type == "number")' "assignment creation should return assignment_id"
echo "OK create published assignment assignment_id=${assignment_id}"

submission="$(request_json POST "${B4_BASE_URL}/api/v1/submissions" \
  "Authorization:Bearer ${student_token}" \
  student_user_id:="${student_user_id}" \
  question_id=API_DEMO \
  assignment_id:="${assignment_id}" \
  code='def add(a, b):
    return a + b
' \
  language=python)"
submission_id="$(jq -r '.data.submission_id' <<<"${submission}")"
assert_jq "${submission}" '.code == 200 and (.data.submission_id | type == "string")' "student submission should return submission_id"
echo "OK create submission submission_id=${submission_id}"

result="$(request_json PATCH "${B4_BASE_URL}/api/v1/submissions/${submission_id}/result" \
  status=COMPLETED \
  overallScore:=100 \
  passedCount:=1 \
  totalCount:=1 \
  overallComment="HTTPie result writeback" \
  staticIssues:='[]' \
  caseResults:='[{"case_id":"case-1","passed":true,"score":100}]')"
assert_jq "${result}" '.code == 200' "B2-style result writeback should succeed"
echo "OK update submission result"

detail="$(request_json GET "${B4_BASE_URL}/api/v1/submissions/${submission_id}" \
  "Authorization:Bearer ${student_token}")"
assert_jq "${detail}" '.code == 200 and .data.status == "COMPLETED" and .data.overall_score == 100' "submission detail should contain updated result"
echo "OK read updated submission detail"

stats="$(request_json GET "${B4_BASE_URL}/api/v1/submissions/statistics/assignment/${assignment_id}" \
  "Authorization:Bearer ${teacher_token}")"
assert_jq "${stats}" '.code == 200 and .data.total_submissions >= 1' "assignment statistics should include submission"
echo "OK assignment statistics"

echo "B4 httpie tests passed"
