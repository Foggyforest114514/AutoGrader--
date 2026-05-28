#!/usr/bin/env bash
set -Eeuo pipefail

B4_BASE_URL="${B4_BASE_URL:-http://127.0.0.1:8000}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d%H%M%S)}"
PASSWORD="${PASSWORD:-HttpieTest123}"
DB_ENV_FILE="${DB_ENV_FILE:-B4/autograder_api/.env}"
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

request_should_fail() {
  local expected_status="$1"
  shift

  local output
  local status
  set +e
  output="$(http --check-status --ignore-stdin --print=hb "$@" 2>&1)"
  status="$?"
  set -e

  if [[ "${status}" -eq 0 ]]; then
    echo "Assertion failed: request should have failed with HTTP ${expected_status}" >&2
    echo "${output}" >&2
    exit 1
  fi

  if ! grep -q "${expected_status}" <<<"${output}"; then
    echo "Assertion failed: expected HTTP ${expected_status}" >&2
    echo "${output}" >&2
    exit 1
  fi
}

assert_jq() {
  local json="$1"
  shift
  local jq_args=("$@")
  local message_index=$((${#jq_args[@]} - 1))
  local message="${jq_args[${message_index}]}"
  unset 'jq_args[message_index]'

  if ! jq -e "${jq_args[@]}" >/dev/null <<<"${json}"; then
    echo "Assertion failed: ${message}" >&2
    echo "${json}" | jq . >&2
    exit 1
  fi
}

database_url() {
  if [[ -n "${DATABASE_URL:-}" ]]; then
    printf '%s\n' "${DATABASE_URL}"
    return
  fi

  if [[ -f "${DB_ENV_FILE}" ]]; then
    sed -n 's/^DATABASE_URL=//p' "${DB_ENV_FILE}" | head -n 1
    return
  fi

  printf '%s\n' "mysql+pymysql://root:password@localhost:3306/autograder"
}

mysql_scalar() {
  local sql="$1"
  local url
  local rest
  local auth
  local hostportdb
  local user
  local pass
  local hostport
  local db
  local host
  local port

  url="$(database_url)"
  rest="${url#mysql+pymysql://}"
  auth="${rest%@*}"
  hostportdb="${rest#*@}"
  user="${auth%%:*}"
  pass="${auth#*:}"
  hostport="${hostportdb%%/*}"
  db="${hostportdb#*/}"
  db="${db%%\?*}"
  host="${hostport%%:*}"
  port="${hostport#*:}"

  MYSQL_PWD="${pass}" mysql \
    --batch --skip-column-names \
    --host="${host}" --port="${port}" --user="${user}" "${db}" \
    --execute="${sql}"
}

require_command date
require_command http
require_command jq
require_command mysql

teacher_username="tb4x${RUN_ID}"
teacher_email="teacher-b4x-${RUN_ID}@example.com"
other_teacher_username="tb4y${RUN_ID}"
other_teacher_email="teacher-b4y-${RUN_ID}@example.com"
student_username="sb4x${RUN_ID}"
student_email="student-b4x-${RUN_ID}@example.com"
other_student_username="sb4y${RUN_ID}"
other_student_email="student-b4y-${RUN_ID}@example.com"
student_id="SID${RUN_ID}"
other_student_id="SIDX${RUN_ID}"
course_code="B4X-${RUN_ID}"
class_code="BX-${RUN_ID}"

echo "B4 extended base URL: ${B4_BASE_URL}"
echo "Run ID: ${RUN_ID}"

health="$(request_json GET "${B4_BASE_URL}/health")"
assert_jq "${health}" '.status == "healthy"' "B4 health should be healthy"
echo "OK health"

teacher_register="$(request_json POST "${B4_BASE_URL}/api/v1/auth/register" \
  username="${teacher_username}" \
  password="${PASSWORD}" \
  email="${teacher_email}" \
  real_name="B4X Teacher ${RUN_ID}" \
  role=teacher \
  teacher_id="TB4X${RUN_ID}" \
  department="Extended Smoke")"
teacher_user_id="$(jq -r '.data.user_id' <<<"${teacher_register}")"
assert_jq "${teacher_register}" '.code == 200 and .data.role == "teacher"' "teacher registration should succeed"
echo "OK register teacher user_id=${teacher_user_id}"

other_teacher_register="$(request_json POST "${B4_BASE_URL}/api/v1/auth/register" \
  username="${other_teacher_username}" \
  password="${PASSWORD}" \
  email="${other_teacher_email}" \
  real_name="B4Y Teacher ${RUN_ID}" \
  role=teacher \
  teacher_id="TB4Y${RUN_ID}" \
  department="Extended Smoke")"
assert_jq "${other_teacher_register}" '.code == 200 and .data.role == "teacher"' "second teacher registration should succeed"
echo "OK register second teacher"

student_register="$(request_json POST "${B4_BASE_URL}/api/v1/auth/register" \
  username="${student_username}" \
  password="${PASSWORD}" \
  email="${student_email}" \
  real_name="B4X Student ${RUN_ID}" \
  role=student \
  student_id="${student_id}")"
student_user_id="$(jq -r '.data.user_id' <<<"${student_register}")"
assert_jq "${student_register}" '.code == 200 and .data.role == "student"' "student registration should succeed"
echo "OK register student user_id=${student_user_id}"

other_student_register="$(request_json POST "${B4_BASE_URL}/api/v1/auth/register" \
  username="${other_student_username}" \
  password="${PASSWORD}" \
  email="${other_student_email}" \
  real_name="B4Y Student ${RUN_ID}" \
  role=student \
  student_id="${other_student_id}")"
assert_jq "${other_student_register}" '.code == 200 and .data.role == "student"' "second student registration should succeed"
echo "OK register second student"

request_should_fail "400 Bad Request" POST "${B4_BASE_URL}/api/v1/auth/register" \
  username="${teacher_username}" \
  password="${PASSWORD}" \
  email="dupe-b4x-${RUN_ID}@example.com" \
  real_name="Duplicate User" \
  role=teacher
echo "OK reject duplicate username"

teacher_login="$(request_json POST "${B4_BASE_URL}/api/v1/auth/login" \
  username="${teacher_email}" \
  password="${PASSWORD}")"
teacher_token="$(jq -r '.data.token' <<<"${teacher_login}")"
teacher_refresh="$(jq -r '.data.refreshToken' <<<"${teacher_login}")"
assert_jq "${teacher_login}" '.code == 200 and .data.role == "teacher"' "teacher login by email should succeed"
echo "OK login teacher by email"

other_teacher_login="$(request_json POST "${B4_BASE_URL}/api/v1/auth/login" \
  username="${other_teacher_username}" \
  password="${PASSWORD}")"
other_teacher_token="$(jq -r '.data.token' <<<"${other_teacher_login}")"
assert_jq "${other_teacher_login}" '.code == 200 and .data.role == "teacher"' "second teacher login should succeed"
echo "OK login second teacher"

student_login="$(request_json POST "${B4_BASE_URL}/api/v1/auth/login" \
  username="${student_id}" \
  password="${PASSWORD}")"
student_token="$(jq -r '.data.token' <<<"${student_login}")"
assert_jq "${student_login}" '.code == 200 and .data.role == "student"' "student login by student_id should succeed"
echo "OK login student by student_id"

other_student_login="$(request_json POST "${B4_BASE_URL}/api/v1/auth/login" \
  username="${other_student_id}" \
  password="${PASSWORD}")"
other_student_token="$(jq -r '.data.token' <<<"${other_student_login}")"
assert_jq "${other_student_login}" '.code == 200 and .data.role == "student"' "second student login should succeed"
echo "OK login second student"

refresh="$(request_json POST "${B4_BASE_URL}/api/v1/auth/refresh" \
  refreshToken="${teacher_refresh}")"
assert_jq "${refresh}" '.code == 200 and .data.role == "teacher" and (.data.token | length > 20)' "refresh token should issue a new access token"
echo "OK refresh token"

me="$(request_json GET "${B4_BASE_URL}/api/v1/users/me" \
  "Authorization:Bearer ${student_token}")"
assert_jq "${me}" --arg sid "${student_id}" '.code == 200 and .data.student_id == $sid' "student /users/me should expose student_id"
echo "OK users/me student profile"

request_should_fail "403 Forbidden" GET "${B4_BASE_URL}/api/v1/users" \
  "Authorization:Bearer ${teacher_token}"
echo "OK reject non-admin user list"

request_should_fail "403 Forbidden" POST "${B4_BASE_URL}/api/v1/courses" \
  "Authorization:Bearer ${student_token}" \
  courseName="Should Fail" \
  courseCode="FAIL-${RUN_ID}" \
  semester="2026-S1"
echo "OK reject student course creation"

course="$(request_json POST "${B4_BASE_URL}/api/v1/courses" \
  "Authorization:Bearer ${teacher_token}" \
  courseName="B4 Extended ${RUN_ID}" \
  courseCode="${course_code}" \
  semester="2026-S1" \
  description="Created by httpie_b4_extended_tests.sh")"
course_id="$(jq -r '.data.course_id' <<<"${course}")"
assert_jq "${course}" '.code == 200 and (.data.course_id | type == "number")' "course creation should return course_id"
echo "OK create course course_id=${course_id}"

request_should_fail "400 Bad Request" POST "${B4_BASE_URL}/api/v1/courses" \
  "Authorization:Bearer ${teacher_token}" \
  courseName="Duplicate B4 Extended ${RUN_ID}" \
  courseCode="${course_code}" \
  semester="2026-S1"
echo "OK reject duplicate course"

course_update="$(request_json PUT "${B4_BASE_URL}/api/v1/courses/${course_id}" \
  "Authorization:Bearer ${teacher_token}" \
  courseName="B4 Extended Updated ${RUN_ID}" \
  description="Updated by extended smoke")"
assert_jq "${course_update}" '.code == 200' "owning teacher should update course"
echo "OK update course"

request_should_fail "403 Forbidden" PUT "${B4_BASE_URL}/api/v1/courses/${course_id}" \
  "Authorization:Bearer ${other_teacher_token}" \
  courseName="Wrong Owner"
echo "OK reject other teacher course update"

class_resp="$(request_json POST "${B4_BASE_URL}/api/v1/classes" \
  "Authorization:Bearer ${teacher_token}" \
  courseId:="${course_id}" \
  className="B4 Extended Class ${RUN_ID}" \
  classCode="${class_code}")"
class_id="$(jq -r '.data.class_id' <<<"${class_resp}")"
assert_jq "${class_resp}" '.code == 200 and (.data.class_id | type == "number")' "class creation should return class_id"
echo "OK create class class_id=${class_id}"

request_should_fail "400 Bad Request" POST "${B4_BASE_URL}/api/v1/classes" \
  "Authorization:Bearer ${teacher_token}" \
  courseId:="${course_id}" \
  className="Duplicate Class" \
  classCode="${class_code}"
echo "OK reject duplicate class code in course"

request_should_fail "403 Forbidden" POST "${B4_BASE_URL}/api/v1/classes/${class_id}/students" \
  "Authorization:Bearer ${other_teacher_token}" \
  studentUserId:="${student_user_id}"
echo "OK reject other teacher adding student"

add_student="$(request_json POST "${B4_BASE_URL}/api/v1/classes/${class_id}/students" \
  "Authorization:Bearer ${teacher_token}" \
  studentUserId:="${student_user_id}")"
assert_jq "${add_student}" '.code == 200' "owning teacher should add student"
echo "OK add student"

request_should_fail "400 Bad Request" POST "${B4_BASE_URL}/api/v1/classes/${class_id}/students" \
  "Authorization:Bearer ${teacher_token}" \
  studentUserId:="${student_user_id}"
echo "OK reject duplicate class membership"

student_courses="$(request_json GET "${B4_BASE_URL}/api/v1/courses" \
  "Authorization:Bearer ${student_token}")"
assert_jq "${student_courses}" --argjson cid "${course_id}" '.code == 200 and ([.data[].course_id] | index($cid) != null)' "student should see enrolled course"
echo "OK student course list is enrollment scoped"

due_date="$(date -u -d '+7 days' '+%Y-%m-%dT%H:%M:%SZ')"
draft_assignment="$(request_json POST "${B4_BASE_URL}/api/v1/assignments" \
  "Authorization:Bearer ${teacher_token}" \
  title="B4 Draft ${RUN_ID}" \
  description="Draft smoke assignment" \
  classId:="${class_id}" \
  question_id=API_DEMO \
  dueDate="${due_date}" \
  isPublished:=false \
  allowResubmit:=true)"
draft_assignment_id="$(jq -r '.data.assignment_id' <<<"${draft_assignment}")"
assert_jq "${draft_assignment}" '.code == 200 and (.data.assignment_id | type == "number")' "draft assignment creation should succeed"
echo "OK create draft assignment assignment_id=${draft_assignment_id}"

request_should_fail "403 Forbidden" GET "${B4_BASE_URL}/api/v1/assignments/${draft_assignment_id}" \
  "Authorization:Bearer ${student_token}"
echo "OK hide draft assignment from student"

publish="$(request_json POST "${B4_BASE_URL}/api/v1/assignments/${draft_assignment_id}/publish" \
  "Authorization:Bearer ${teacher_token}")"
assert_jq "${publish}" '.code == 200' "teacher should publish assignment"
echo "OK publish assignment"

request_should_fail "400 Bad Request" POST "${B4_BASE_URL}/api/v1/assignments/${draft_assignment_id}/publish" \
  "Authorization:Bearer ${teacher_token}"
echo "OK reject duplicate publish"

published_detail="$(request_json GET "${B4_BASE_URL}/api/v1/assignments/${draft_assignment_id}" \
  "Authorization:Bearer ${student_token}")"
assert_jq "${published_detail}" '.code == 200 and .data.is_published == true and .data.published_at != null' "student should read published assignment"
echo "OK student can read published assignment"

request_should_fail "403 Forbidden" POST "${B4_BASE_URL}/api/v1/submissions" \
  "Authorization:Bearer ${teacher_token}" \
  student_user_id:="${student_user_id}" \
  question_id=API_DEMO \
  assignment_id:="${draft_assignment_id}" \
  code='print("teacher cannot submit")' \
  language=python
echo "OK reject teacher submission"

request_should_fail "403 Forbidden" POST "${B4_BASE_URL}/api/v1/submissions" \
  "Authorization:Bearer ${other_student_token}" \
  student_user_id:="${student_user_id}" \
  question_id=API_DEMO \
  assignment_id:="${draft_assignment_id}" \
  code='print("not enrolled")' \
  language=python
echo "OK reject non-enrolled student submission"

submission="$(request_json POST "${B4_BASE_URL}/api/v1/submissions" \
  "Authorization:Bearer ${student_token}" \
  student_user_id:="${student_user_id}" \
  question_id=API_DEMO \
  assignment_id:="${draft_assignment_id}" \
  code='def add(a, b):
    return a + b
' \
  language=python)"
submission_id="$(jq -r '.data.submission_id' <<<"${submission}")"
assert_jq "${submission}" '.code == 200 and (.data.submission_id | type == "string")' "enrolled student submission should succeed"
echo "OK student submission submission_id=${submission_id}"

request_should_fail "403 Forbidden" GET "${B4_BASE_URL}/api/v1/submissions/${submission_id}" \
  "Authorization:Bearer ${other_student_token}"
echo "OK reject other student submission detail"

result="$(request_json PATCH "${B4_BASE_URL}/api/v1/submissions/${submission_id}/result" \
  status=COMPLETED \
  overallScore:=82.5 \
  passedCount:=2 \
  totalCount:=3 \
  overallComment="Extended smoke result" \
  staticIssues:='[{"level":"warning","message":"style"}]' \
  caseResults:='[{"case_id":"case-1","passed":true},{"case_id":"case-2","passed":false}]')"
assert_jq "${result}" '.code == 200' "result writeback should succeed"
echo "OK result writeback"

my_submissions="$(request_json GET "${B4_BASE_URL}/api/v1/submissions/my" \
  "Authorization:Bearer ${student_token}" \
  assignment_id=="${draft_assignment_id}")"
assert_jq "${my_submissions}" --arg sid "${submission_id}" '.code == 200 and ([.data[].submission_id] | index($sid) != null)' "my submissions should include new submission"
echo "OK my submissions filter"

all_submissions="$(request_json GET "${B4_BASE_URL}/api/v1/submissions/assignment/${draft_assignment_id}/all" \
  "Authorization:Bearer ${teacher_token}")"
assert_jq "${all_submissions}" --arg sid "${submission_id}" '.code == 200 and .data.total_submissions >= 1 and ([.data.submissions[].submission_id] | index($sid) != null)' "teacher assignment submissions should include new submission"
echo "OK assignment submissions list"

override="$(request_json PATCH "${B4_BASE_URL}/api/v1/submissions/${submission_id}/override" \
  "Authorization:Bearer ${teacher_token}" \
  override_score==88.5 \
  override_reason=="Manual smoke review")"
assert_jq "${override}" '.code == 200 and .data.override_score == 88.5' "teacher score override should succeed"
echo "OK teacher score override"

request_should_fail "403 Forbidden" PATCH "${B4_BASE_URL}/api/v1/submissions/${submission_id}/override" \
  "Authorization:Bearer ${student_token}" \
  override_score==99 \
  override_reason=="student cannot override"
echo "OK reject student score override"

my_grades="$(request_json GET "${B4_BASE_URL}/api/v1/grades/my" \
  "Authorization:Bearer ${student_token}" \
  assignment_id=="${draft_assignment_id}")"
assert_jq "${my_grades}" '.code == 200 and (.data | length) >= 1 and .data[0].score == 88.5' "student grades should use teacher override"
echo "OK student grade uses override"

class_grades="$(request_json GET "${B4_BASE_URL}/api/v1/grades/class/${class_id}" \
  "Authorization:Bearer ${teacher_token}")"
assert_jq "${class_grades}" --argjson aid "${draft_assignment_id}" '.code == 200 and ([.data[].assignments[] | select(.assignment_id == $aid and .score == 88.5)] | length) >= 1' "class grades should include overridden score"
echo "OK class grades"

export_grades="$(request_json GET "${B4_BASE_URL}/api/v1/grades/export/${draft_assignment_id}" \
  "Authorization:Bearer ${teacher_token}")"
assert_jq "${export_grades}" --arg sid "${student_id}" '.code == 200 and ([.data.grades[] | select(.student_id == $sid and .score == 88.5)] | length) == 1' "grade export should include student score"
echo "OK grade export"

stats="$(request_json GET "${B4_BASE_URL}/api/v1/submissions/statistics/assignment/${draft_assignment_id}" \
  "Authorization:Bearer ${teacher_token}")"
assert_jq "${stats}" '.code == 200 and .data.total_students == 1 and .data.total_submissions >= 1 and .data.average_score == 82.5' "statistics should use evaluator score"
echo "OK submission statistics"

question="$(request_json POST "${B4_BASE_URL}/api/v1/questions" \
  "Authorization:Bearer ${teacher_token}" \
  title="B4 Smoke Question ${RUN_ID}" \
  description="Question created by extended smoke" \
  type=COMMAND_LINE \
  difficulty=EASY \
  language=python \
  time_limit:=3 \
  memory_limit:=128 \
  starter_code='print(input())' \
  solution_code='print(input())' \
  test_cases:='[{"input":"1 2","expected_output":"3","is_public":true,"score_weight":1},{"input":"2 3","expected_output":"5","is_public":false,"score_weight":1}]')"
question_id="$(jq -r '.data.question_id' <<<"${question}")"
assert_jq "${question}" '.code == 200 and (.data.question_id | length) > 0' "question creation should succeed"
echo "OK create question question_id=${question_id}"

question_student="$(request_json GET "${B4_BASE_URL}/api/v1/questions/${question_id}" \
  "Authorization:Bearer ${student_token}")"
assert_jq "${question_student}" '.code == 200 and ([.data.test_cases[] | select(.is_public == false and .expected_output == "***")] | length) == 1 and (.data.solution_code | not)' "student should not see private expected output or solution"
echo "OK question private testcase masking for student"

question_teacher="$(request_json GET "${B4_BASE_URL}/api/v1/questions/${question_id}" \
  "Authorization:Bearer ${teacher_token}" \
  include_solution==true)"
assert_jq "${question_teacher}" '.code == 200 and .data.solution_code == "print(input())" and ([.data.test_cases[] | select(.is_public == false and .expected_output == "5")] | length) == 1' "teacher should see solution and private expected output"
echo "OK question detail for teacher"

add_testcases="$(request_json POST "${B4_BASE_URL}/api/v1/questions/${question_id}/testcases" \
  "Authorization:Bearer ${teacher_token}" \
  --raw='[{"input":"10 20","expected_output":"30","is_public":true,"score_weight":1}]')"
assert_jq "${add_testcases}" '.code == 200 and .data.added_count == 1' "adding testcase should succeed"
echo "OK add testcase"

question_list="$(request_json GET "${B4_BASE_URL}/api/v1/questions" \
  "Authorization:Bearer ${student_token}" \
  keyword=="${RUN_ID}" \
  language==python)"
assert_jq "${question_list}" --arg qid "${question_id}" '.code == 200 and ([.data[].question_id] | index($qid) != null)' "question list filters should find created question"
echo "OK question list filters"

request_should_fail "403 Forbidden" POST "${B4_BASE_URL}/api/v1/questions" \
  "Authorization:Bearer ${student_token}" \
  title="Student Should Fail" \
  type=COMMAND_LINE \
  difficulty=EASY \
  language=python
echo "OK reject student question creation"

announcement="$(request_json POST "${B4_BASE_URL}/api/v1/system/announcements" \
  "Authorization:Bearer ${teacher_token}" \
  course_id:="${course_id}" \
  title="B4 Announcement ${RUN_ID}" \
  content="Extended smoke announcement")"
announcement_id="$(jq -r '.data.announcement_id' <<<"${announcement}")"
assert_jq "${announcement}" '.code == 200 and (.data.announcement_id | type == "number")' "announcement creation should succeed"
echo "OK create announcement announcement_id=${announcement_id}"

announcements="$(request_json GET "${B4_BASE_URL}/api/v1/system/announcements" \
  "Authorization:Bearer ${student_token}" \
  course_id=="${course_id}")"
assert_jq "${announcements}" --argjson aid "${announcement_id}" '.code == 200 and ([.data.announcements[].announcement_id] | index($aid) != null)' "enrolled student should see course announcement"
echo "OK student announcement list"

request_should_fail "403 Forbidden" DELETE "${B4_BASE_URL}/api/v1/system/announcements/${announcement_id}" \
  "Authorization:Bearer ${other_teacher_token}"
echo "OK reject other teacher announcement delete"

db_submission_count="$(mysql_scalar "SELECT COUNT(*) FROM submissions WHERE submission_id='${submission_id}' AND status='COMPLETED' AND ABS(overall_score - 82.5) < 0.001;")"
if [[ "${db_submission_count}" != "1" ]]; then
  echo "Assertion failed: submission result should be persisted in MySQL" >&2
  echo "MySQL count: ${db_submission_count}" >&2
  exit 1
fi
echo "OK MySQL persisted submission result"

db_question_cases="$(mysql_scalar "SELECT COUNT(*) FROM test_cases WHERE question_id='${question_id}';")"
if [[ "${db_question_cases}" -lt 3 ]]; then
  echo "Assertion failed: question test cases should be persisted in MySQL" >&2
  echo "MySQL count: ${db_question_cases}" >&2
  exit 1
fi
echo "OK MySQL persisted question test cases"

echo "B4 extended httpie tests passed"
