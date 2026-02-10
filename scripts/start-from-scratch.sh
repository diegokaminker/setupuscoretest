#!/usr/bin/env bash
# Stop containers, remove volumes (fresh DB), and start HAPI from scratch.
# All server data (resources, terminology, IG cache) will be lost.
#
# Optional: set config before running, e.g.:
#   export SPRING_CONFIG_ADDITIONAL_LOCATION=file:///config/application-local-terminology.yaml
#   ./scripts/start-from-scratch.sh
#
# Usage: ./scripts/start-from-scratch.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

echo "Stopping containers and removing volumes (fresh start)..."
docker compose down -v

echo "Starting containers..."
docker compose up -d

BASE="${FHIR_BASE_URL:-http://localhost:8023/fhir}"
echo "Waiting for HAPI to be ready ($BASE)..."
for i in $(seq 1 30); do
  if curl -s -o /dev/null -w "%{http_code}" "$BASE/metadata" 2>/dev/null | grep -q 200; then
    echo "HAPI is up."
    exit 0
  fi
  sleep 5
done
echo "HAPI may still be starting. Check: docker compose logs -f hapi-fhir"
