#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${ROOT_DIR}/logs"

mkdir -p "${LOG_DIR}"

pids=()
names=()

python_bin() {
  local module_dir="$1"
  local venv_python="${ROOT_DIR}/${module_dir}/.venv/bin/python"

  if [[ -x "${venv_python}" ]]; then
    printf '%s\n' "${venv_python}"
  else
    echo "Missing ${module_dir}/.venv." >&2
    echo "Create the virtual environment and install dependencies from the module README first." >&2
    exit 1
  fi
}

start_service() {
  local name="$1"
  local module_dir="$2"
  local log_file="$3"
  shift 3

  echo "Starting ${name}..."
  (
    cd "${ROOT_DIR}/${module_dir}"
    exec "$@"
  ) >"${LOG_DIR}/${log_file}" 2>&1 &

  pids+=("$!")
  names+=("${name}")
  echo "  pid=$! log=logs/${log_file}"
}

stop_all() {
  local pid

  echo
  echo "Stopping services..."
  for pid in "${pids[@]}"; do
    if kill -0 "${pid}" >/dev/null 2>&1; then
      kill "${pid}" >/dev/null 2>&1 || true
    fi
  done

  wait >/dev/null 2>&1 || true
}

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
}

require_path() {
  local path="$1"
  local message="$2"

  if [[ ! -e "${ROOT_DIR}/${path}" ]]; then
    echo "${message}" >&2
    echo "Install the module dependencies first." >&2
    exit 1
  fi
}

trap stop_all INT TERM EXIT

require_command npm
require_path "B1/node_modules" "Missing B1/node_modules."

B2_PYTHON="$(python_bin "B2")"
B3_PYTHON="$(python_bin "B3")"
B4_PYTHON="$(python_bin "B4/autograder_api")"

start_service "B1 frontend" "B1" "B1.log" \
  npm run dev -- --host 0.0.0.0

start_service "B2 service" "B2" "B2.log" \
  "${B2_PYTHON}" -m uvicorn main:app --host 0.0.0.0 --port 8002 --reload

start_service "B3 service" "B3" "B3.log" \
  "${B3_PYTHON}" -m uvicorn app.main:app --host 0.0.0.0 --port 8003

start_service "B4 API" "B4/autograder_api" "B4.log" \
  "${B4_PYTHON}" -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

cat <<'EOF'

Services started:
  B1 frontend: http://127.0.0.1:5173
  B2 service:  http://127.0.0.1:8002/docs
  B3 service:  http://127.0.0.1:8003/docs
  B4 API:      http://127.0.0.1:8000/docs

Press Ctrl-C to stop all services.
EOF

while true; do
  for i in "${!pids[@]}"; do
    pid="${pids[$i]}"
    name="${names[$i]}"

    if ! kill -0 "${pid}" >/dev/null 2>&1; then
      status=0
      wait "${pid}" || status="$?"
      echo "${name} exited with status ${status}. Check logs/ for details." >&2
      exit "${status}"
    fi
  done

  sleep 2
done
