#!/usr/bin/env bash
#
# load-terminology.sh - Load LOINC, SNOMED CT, and HL7 terminology locally into HAPI FHIR
# For EC2 or any host running the US Core HAPI server via Docker Compose.
# NO dependency on tx.fhir.org - all terminology is stored locally.
#
# Prerequisites:
#   1. Docker and Docker Compose installed
#   2. HAPI FHIR server running (docker compose up -d)
#   3. LOINC and SNOMED CT files downloaded manually (see instructions below)
#
# Usage:
#   ./load-terminology.sh [OPTIONS]
#
# Options:
#   -t, --target-url URL    HAPI FHIR base URL (default: http://localhost:8023/fhir)
#   -d, --data-dir DIR      Directory containing terminology files (default: ./terminology-data)
#   -s, --skip-loinc        Skip LOINC upload
#   -n, --skip-snomed       Skip SNOMED upload
#   -c, --config-dir DIR    Config directory (default: ./config)
#   -h, --help              Show this help
#
# Required manual downloads (place in terminology-data/):
#
#   LOINC (free, registration at https://loinc.org/join/):
#     Loinc_2.xx.zip from https://loinc.org/downloads/
#
#   SNOMED CT International (free license at https://www.snomed.org/):
#     SnomedCT_InternationalRF2_PRODUCTION_YYYYMMDDT120000Z.zip
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TERMINOLOGY_DATA_DIR="${PROJECT_DIR}/terminology-data"
CONFIG_DIR="${PROJECT_DIR}/config"
TARGET_URL="http://localhost:8023/fhir"
SKIP_LOINC=false
SKIP_SNOMED=false
HAPI_CLI_IMAGE="ghcr.io/trifork/hapi-fhir-cli:latest"
LOCAL_CONFIG_FILE="application-local-terminology.yaml"

while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--target-url) TARGET_URL="$2"; shift 2 ;;
    -d|--data-dir) TERMINOLOGY_DATA_DIR="$2"; shift 2 ;;
    -s|--skip-loinc) SKIP_LOINC=true; shift ;;
    -n|--skip-snomed) SKIP_SNOMED=true; shift ;;
    -c|--config-dir) CONFIG_DIR="$2"; shift 2 ;;
    -h|--help)
      head -45 "$0" | tail -40
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

log() { echo "[$(date +%Y-%m-%dT%H:%M:%S)] $*"; }
die() { log "ERROR: $*"; exit 1; }

mkdir -p "$TERMINOLOGY_DATA_DIR"
cd "$PROJECT_DIR"

APPLICATION_YAML="${CONFIG_DIR}/application.yaml"
LOCAL_TERMINOLOGY_YAML="${CONFIG_DIR}/${LOCAL_CONFIG_FILE}"

# -----------------------------------------------------------------------------
# Step 1: Switch to local terminology config (no tx.fhir.org)
# -----------------------------------------------------------------------------
log "Step 1: Switching to local terminology config (no remote tx.fhir.org)..."

if [[ ! -f "$LOCAL_TERMINOLOGY_YAML" ]]; then
  die "Local terminology config not found: $LOCAL_TERMINOLOGY_YAML"
fi

if [[ -f "$APPLICATION_YAML" ]]; then
  cp "$APPLICATION_YAML" "${APPLICATION_YAML}.bak.$(date +%Y%m%d%H%M%S)"
fi

cp "$LOCAL_TERMINOLOGY_YAML" "$APPLICATION_YAML"
log "Config updated: $APPLICATION_YAML"

# -----------------------------------------------------------------------------
# Step 2: Wait for HAPI server
# -----------------------------------------------------------------------------
log "Step 2: Checking HAPI server at $TARGET_URL..."

MAX_RETRIES=60
RETRY=0
FHIR_BASE="${TARGET_URL%/fhir}"
while ! curl -sf "${FHIR_BASE}/fhir/metadata" > /dev/null 2>&1; do
  RETRY=$((RETRY + 1))
  if [[ $RETRY -ge $MAX_RETRIES ]]; then
    die "HAPI server not ready. Run 'docker compose up -d' first."
  fi
  log "Waiting for HAPI... ($RETRY/$MAX_RETRIES)"
  sleep 10
done
log "HAPI server is ready."

# -----------------------------------------------------------------------------
# Step 3: Pull hapi-fhir-cli image
# -----------------------------------------------------------------------------
log "Step 3: Pulling hapi-fhir-cli Docker image..."
docker pull "$HAPI_CLI_IMAGE" || die "Failed to pull $HAPI_CLI_IMAGE"

# -----------------------------------------------------------------------------
# Step 4: Upload LOINC
# -----------------------------------------------------------------------------
if [[ "$SKIP_LOINC" != "true" ]]; then
  log "Step 4: Uploading LOINC terminology..."

  LOINC_FILE=$(find "$TERMINOLOGY_DATA_DIR" -maxdepth 1 \( -name 'Loinc_*.zip' -o -name 'LOINC_*_Text.zip' -o -name 'LOINC_*_MULTI-AXIAL*.zip' \) 2>/dev/null | head -1)

  if [[ -z "$LOINC_FILE" ]]; then
    log "WARNING: No LOINC zip in $TERMINOLOGY_DATA_DIR"
    log "  Download from https://loinc.org/downloads/ (free registration)"
    log "  Place Loinc_2.xx.zip and re-run."
  else
    log "Found LOINC: $LOINC_FILE"

    # HAPI accepts: Loinc_2.xx.zip (single zip) OR LOINC_2.xx_Text.zip + LOINC_2.xx_MULTI-AXIAL_HIERARCHY.zip
    LOINC_BASENAME=$(basename "$LOINC_FILE")
    LOINC_ARGS="-d /terminology/$LOINC_BASENAME"

    HIERARCHY=$(find "$TERMINOLOGY_DATA_DIR" -maxdepth 1 \( -name '*MULTI-AXIAL*' -o -name '*ComponentHierarchy*' \) 2>/dev/null | head -1)
    if [[ -n "$HIERARCHY" && "$(basename "$HIERARCHY")" != "$LOINC_BASENAME" ]]; then
      LOINC_ARGS="$LOINC_ARGS -d /terminology/$(basename "$HIERARCHY")"
    fi

    if docker run --rm --network host \
      -v "$TERMINOLOGY_DATA_DIR:/terminology:ro" \
      "$HAPI_CLI_IMAGE" \
      upload-terminology -v r4 -t "$TARGET_URL" -u "http://loinc.org" \
      $LOINC_ARGS; then
      log "LOINC upload completed."
    else
      log "WARNING: LOINC upload failed. Check HAPI logs and file format."
      log "  HAPI expects Loinc.csv + ComponentHierarchyBySystem.csv (or MultiAxialHierarchy.csv)"
    fi
  fi
else
  log "Step 4: Skipping LOINC (--skip-loinc)"
fi

# -----------------------------------------------------------------------------
# Step 5: Upload SNOMED CT
# -----------------------------------------------------------------------------
if [[ "$SKIP_SNOMED" != "true" ]]; then
  log "Step 5: Uploading SNOMED CT terminology..."

  SNOMED_FILE=$(find "$TERMINOLOGY_DATA_DIR" -maxdepth 1 \( -name 'SnomedCT_*_RF2_*.zip' -o -name 'SnomedCT_*_Snapshot_*.zip' \) 2>/dev/null | head -1)

  if [[ -z "$SNOMED_FILE" ]]; then
    log "WARNING: No SNOMED CT RF2 zip in $TERMINOLOGY_DATA_DIR"
    log "  Download from https://www.snomed.org/ (free license required)"
    log "  Place SnomedCT_InternationalRF2_PRODUCTION_*.zip and re-run."
  else
    log "Found SNOMED: $SNOMED_FILE"

    if docker run --rm --network host \
      -v "$TERMINOLOGY_DATA_DIR:/terminology:ro" \
      "$HAPI_CLI_IMAGE" \
      upload-terminology -v r4 -t "$TARGET_URL" -u "http://snomed.info/sct" \
      -d "/terminology/$(basename "$SNOMED_FILE")"; then
      log "SNOMED CT upload completed."
    else
      log "WARNING: SNOMED upload failed. Check HAPI logs and RF2 format."
    fi
  fi
else
  log "Step 5: Skipping SNOMED (--skip-snomed)"
fi

# -----------------------------------------------------------------------------
# Step 6: Restart HAPI to load hl7.terminology.r4 and apply config
# -----------------------------------------------------------------------------
log "Step 6: Restarting HAPI to load hl7.terminology.r4 (UCUM, HL7 vocab)..."

if docker compose ps 2>/dev/null | grep -q hapi-fhir; then
  docker compose restart hapi-fhir
  log "HAPI restarted. Wait 2-3 minutes for hl7.terminology.r4 to load."
else
  log "Start HAPI with: docker compose up -d"
  log "For local terminology mode, run: SPRING_CONFIG_ADDITIONAL_LOCATION=file:///config/application-local-terminology.yaml docker compose up -d"
fi

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
log "=============================================="
log "Terminology loading complete."
log "=============================================="
log ""
log "Verify LOINC: curl -X POST '${FHIR_BASE}/fhir/CodeSystem/\$validate-code' -H 'Content-Type: application/fhir+json' -d '{\"resourceType\":\"Parameters\",\"parameter\":[{\"name\":\"code\",\"valueCode\":\"15074-8\"},{\"name\":\"system\",\"valueUri\":\"http://loinc.org\"}]}'"
log "Config backup: ${APPLICATION_YAML}.bak.*"
log ""
