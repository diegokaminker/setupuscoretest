#!/usr/bin/env bash
# Verify which HAPI config the running container is using (application.yaml vs application_default.yaml vs local).
# Run from project root; requires Docker.
#
# Usage: ./scripts/verify-config.sh

set -e

CONTAINER="${HAPI_CONTAINER:-hapi-fhir-uscore}"

echo "Checking config for container: $CONTAINER"
echo ""

# 1. Show SPRING_CONFIG_ADDITIONAL_LOCATION from the running container
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "Container '$CONTAINER' is not running. Start with: docker compose up -d"
  exit 1
fi

LOCATION=$(docker exec "$CONTAINER" env 2>/dev/null | grep '^SPRING_CONFIG_ADDITIONAL_LOCATION=' | cut -d= -f2- || true)
if [[ -z "$LOCATION" ]]; then
  echo "SPRING_CONFIG_ADDITIONAL_LOCATION: (not set – server may use only classpath config)"
else
  echo "SPRING_CONFIG_ADDITIONAL_LOCATION=$LOCATION"
  case "$LOCATION" in
    *application.yaml*)
      echo "  → Default: multi-terminology (tx.fhir.org + VSAC)"
      ;;
    *application_default.yaml*)
      echo "  → Single remote tx (all terminology to tx.fhir.org)"
      ;;
    *application-local-terminology.yaml*)
      echo "  → Local terminology only (no remote tx; run load-terminology.sh first)"
      ;;
    *)
      echo "  → Custom config"
      ;;
  esac
fi

echo ""
echo "To see what Spring loaded at startup, run:"
echo "  docker compose logs hapi-fhir 2>&1 | grep -i 'location\\|config\\|profile' | head -20"
echo ""
echo "To change config: set SPRING_CONFIG_ADDITIONAL_LOCATION in .env or:"
echo "  SPRING_CONFIG_ADDITIONAL_LOCATION=file:///config/application_default.yaml docker compose up -d"
echo "Then restart: docker compose restart hapi-fhir"
