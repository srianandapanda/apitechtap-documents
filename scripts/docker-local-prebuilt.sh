#!/usr/bin/env bash
# Same as: ./docker-local.sh --prebuilt ...
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/docker-local.sh" --prebuilt "$@"
