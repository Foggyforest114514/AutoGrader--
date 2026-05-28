#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${ROOT_DIR}/httpie_b3_tests.sh"
"${ROOT_DIR}/httpie_b4_tests.sh"
"${ROOT_DIR}/httpie_b4_extended_tests.sh"
"${ROOT_DIR}/httpie_b2_tests.sh"

echo "All httpie smoke tests passed"
