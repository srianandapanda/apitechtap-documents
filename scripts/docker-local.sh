#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CORE_ROOT="$(cd "${DOCS_ROOT}/.." && pwd)"
LOCAL_DIR="${DOCS_ROOT}/local"
ENV_FILE="${LOCAL_DIR}/.env"
ENV_EXAMPLE="${LOCAL_DIR}/.env.example"

PREBUILT=0
if [[ "${1:-}" == "--prebuilt" ]]; then
  PREBUILT=1
  shift
fi

COMPOSE_BASENAME="docker-compose.yml"
if [[ "${PREBUILT}" -eq 1 ]]; then
  COMPOSE_BASENAME="docker-compose.prebuilt.yml"
fi
COMPOSE_FILE="${LOCAL_DIR}/${COMPOSE_BASENAME}"

usage() {
  echo "Usage: $(basename "$0") [--prebuilt] {build|up|down|logs|ps|jars} [extra args...]" >&2
  echo "  (default)          docker-compose.yml — Gradle inside Docker during image build" >&2
  echo "  --prebuilt         docker-compose.prebuilt.yml — host ./gradlew bootJar, image copies JAR" >&2
  echo "" >&2
  echo "  build              docker compose build (--prebuilt: bootJar on host first)" >&2
  echo "  up                 docker compose up -d" >&2
  echo "  down               docker compose down (pass --volumes to drop data)" >&2
  echo "  logs [service]     docker compose logs -f [service]" >&2
  echo "  ps                 docker compose ps" >&2
  if [[ "${PREBUILT}" -eq 1 ]]; then
    echo "  jars               ./gradlew bootJar in each service (extra args → Gradle)" >&2
  else
    echo "  jars               only with --prebuilt" >&2
  fi
  exit 1
}

build_jars() {
  for rel in auth-service user-management aitechtap-assist plan-payment-service; do
    d="${CORE_ROOT}/${rel}"
    if [[ ! -d "${d}" ]]; then
      echo "Service directory not found: ${d}" >&2
      exit 1
    fi
    echo "=== bootJar: ${rel} ===" >&2
    (cd "${d}" && ./gradlew bootJar --no-daemon -x test "$@")
  done
}

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "Compose file not found: ${COMPOSE_FILE}" >&2
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  if [[ -f "${ENV_EXAMPLE}" ]]; then
    cp "${ENV_EXAMPLE}" "${ENV_FILE}"
    echo "Created ${ENV_FILE} from .env.example — review JWT_SECRET and passwords." >&2
  else
    echo "Missing ${ENV_FILE} and ${ENV_EXAMPLE}" >&2
    exit 1
  fi
fi

if [[ "${PREBUILT}" -eq 1 ]]; then
  export DOCKER_BUILDKIT=1
  export COMPOSE_DOCKER_CLI_BUILD=1
fi

cd "${LOCAL_DIR}"

cmd="${1:-}"
shift || true

compose() {
  docker compose --env-file .env -f "${COMPOSE_BASENAME}" "$@"
}

case "${cmd}" in
  build)
    if [[ "${PREBUILT}" -eq 1 ]]; then
      build_jars
    fi
    compose build "$@"
    ;;
  up)
    compose up -d "$@"
    ;;
  down)
    compose down "$@"
    ;;
  logs)
    compose logs -f "$@"
    ;;
  ps)
    compose ps "$@"
    ;;
  jars)
    if [[ "${PREBUILT}" -ne 1 ]]; then
      echo "Command 'jars' requires --prebuilt." >&2
      usage
    fi
    build_jars "$@"
    ;;
  ""|-h|--help|help)
    usage
    ;;
  *)
    echo "Unknown command: ${cmd}" >&2
    usage
    ;;
esac
