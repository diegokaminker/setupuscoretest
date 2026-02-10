#!/usr/bin/env bash
# L02_1_T02: Setup For U02_L02_1_T02: Patient Exists, but has no ethnicity extension
# Generated from Postman collection

BASE_URL="${FHIR_BASE_URL:-https://hl7int-server.com/server/fhir}"

RESP=$(mktemp)
trap "rm -f $RESP" EXIT
HTTP_CODE=$(curl -s -w %{http_code} -o "$RESP" -X PUT -H "Content-Type: application/fhir+json" -H "Accept: application/fhir+json" -d @"L02_1_T02.json" "${BASE_URL}/Patient?identifier=L02_1_T02")
if [[ "$HTTP_CODE" =~ ^2 ]]; then
  echo "[OK] HTTP $HTTP_CODE"
  exit 0
else
  echo "[FAIL] HTTP $HTTP_CODE"
  cat "$RESP" 2>/dev/null | head -20
  exit 1
fi
