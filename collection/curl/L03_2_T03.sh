#!/usr/bin/env bash
# L03_2_T03: Setup For U02_L03_2_T03: Patient Exists, and has one medication record
# Generated from Postman collection

BASE_URL="${FHIR_BASE_URL:-https://hl7int-server.com/server/fhir}"

RESP=$(mktemp)
trap "rm -f $RESP" EXIT
HTTP_CODE=$(curl -s -w %{http_code} -o "$RESP" -X POST -H "Content-Type: application/fhir+json" -H "Accept: application/fhir+json" -d @"L03_2_T03.json" "${BASE_URL}/")
if [[ "$HTTP_CODE" =~ ^2 ]]; then
  echo "[OK] HTTP $HTTP_CODE"
  exit 0
else
  echo "[FAIL] HTTP $HTTP_CODE"
  cat "$RESP" 2>/dev/null | head -20
  exit 1
fi
