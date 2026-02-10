#!/usr/bin/env bash
# req_036: Get IMMS
# Generated from Postman collection

BASE_URL="${FHIR_BASE_URL:-https://hl7int-server.com/server/fhir}"

RESP=$(mktemp)
trap "rm -f $RESP" EXIT
HTTP_CODE=$(curl -s -w %{http_code} -o "$RESP" -X GET "${BASE_URL}/Patient/$summary?identifier=L03_3_T03")
if [[ "$HTTP_CODE" =~ ^2 ]]; then
  echo "[OK] HTTP $HTTP_CODE"
  exit 0
else
  echo "[FAIL] HTTP $HTTP_CODE"
  cat "$RESP" 2>/dev/null | head -20
  exit 1
fi
