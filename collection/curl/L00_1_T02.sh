#!/usr/bin/env bash
# L00_1_T02: Setup For U02_L00_1_T02: Patient with full name and 2 addresses
# Generated from Postman collection

BASE_URL="${FHIR_BASE_URL:-https://hl7int-server.com/server/fhir}"

RESP=$(mktemp)
trap "rm -f $RESP" EXIT
HTTP_CODE=$(curl -s -w %{http_code} -o "$RESP" -X POST -H "If-None-Exist: Patient?identifier=L00_1_T02" -H "Content-Type: application/fhir+json" -H "Accept: application/fhir+json" -d @"L00_1_T02.json" "${BASE_URL}/Patient")
if [[ "$HTTP_CODE" =~ ^2 ]]; then
  echo "[OK] HTTP $HTTP_CODE"
  exit 0
else
  echo "[FAIL] HTTP $HTTP_CODE"
  cat "$RESP" 2>/dev/null | head -20
  exit 1
fi
