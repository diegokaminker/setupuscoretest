#!/usr/bin/env bash
# Test CDC/VSAC ethnicity value set and lookup via the VSAC proxy.
# Requires: proxy running (e.g. ./test-proxy.sh or python app.py with VSAC_UMLS_API_KEY).
# Usage: PROXY_URL=http://localhost:8081 ./test-cdc-ethnicity.sh

set -e

PROXY_URL="${PROXY_URL:-http://localhost:8081}"
PROXY_URL="${PROXY_URL%/}"

# CDC/OMB Ethnicity Categories value set (VSAC)
ETHNICITY_VS_OID="2.16.840.1.113883.4.642.40.2.48.3"
# CDC Race and Ethnicity code system (CDCREC)
CDCREC_SYSTEM="urn:oid:2.16.840.1.113883.6.238"
# Hispanic or Latino
CODE_ETHNICITY="2135-2"

echo "Testing CDC ethnicity via VSAC proxy at ${PROXY_URL}"
echo ""

# 1. Read Ethnicity Categories value set
echo "1. ValueSet read (Ethnicity Categories - OMB standard)..."
HTTP_READ=$(curl -s -o /tmp/vsac_ethnicity_vs.json -w "%{http_code}" \
  "${PROXY_URL}/ValueSet/${ETHNICITY_VS_OID}" \
  -H "Accept: application/fhir+json" 2>/dev/null || echo "000")
echo "   GET ValueSet/${ETHNICITY_VS_OID} → HTTP ${HTTP_READ}"
if [[ "$HTTP_READ" == "200" ]]; then
  TITLE=$(grep -o '"title":"[^"]*"' /tmp/vsac_ethnicity_vs.json | head -1)
  echo "   OK: ${TITLE}"
else
  echo "   Response in /tmp/vsac_ethnicity_vs.json"
fi
echo ""

# 2. Expand value set (list member codes)
echo "2. ValueSet \$expand (Ethnicity Categories)..."
HTTP_EXPAND=$(curl -s -o /tmp/vsac_ethnicity_expand.json -w "%{http_code}" \
  "${PROXY_URL}/ValueSet/${ETHNICITY_VS_OID}/\$expand" \
  -H "Accept: application/fhir+json" 2>/dev/null || echo "000")
echo "   GET ValueSet/${ETHNICITY_VS_OID}/\$expand → HTTP ${HTTP_EXPAND}"
if [[ "$HTTP_EXPAND" == "200" ]]; then
  COUNT=$(grep -o '"code":"[^"]*"' /tmp/vsac_ethnicity_expand.json | wc -l | tr -d ' ')
  echo "   OK: expansion contains codes (count: ${COUNT})"
  echo "   Sample codes:"
  grep -o '"code":"[^"]*","display":"[^"]*"' /tmp/vsac_ethnicity_expand.json | head -5 | sed 's/^/     /'
else
  echo "   Response in /tmp/vsac_ethnicity_expand.json"
fi
echo ""

# 3. CodeSystem $lookup (single code - Hispanic or Latino)
echo "3. CodeSystem \$lookup (CDC Race & Ethnicity code ${CODE_ETHNICITY} - Hispanic or Latino)..."
CDCREC_ENC="urn%3Aoid%3A2.16.840.1.113883.6.238"
HTTP_LOOKUP=$(curl -s -o /tmp/vsac_ethnicity_lookup.json -w "%{http_code}" \
  "${PROXY_URL}/CodeSystem/\$lookup?system=${CDCREC_ENC}&code=${CODE_ETHNICITY}" \
  -H "Accept: application/fhir+json" 2>/dev/null || echo "000")
echo "   GET CodeSystem/\$lookup?system=...&code=${CODE_ETHNICITY} → HTTP ${HTTP_LOOKUP}"
if [[ "$HTTP_LOOKUP" == "200" ]]; then
  DISPLAY=$(grep -o '"valueString":"[^"]*"' /tmp/vsac_ethnicity_lookup.json | head -1)
  echo "   OK: lookup succeeded. ${DISPLAY}"
else
  echo "   Response in /tmp/vsac_ethnicity_lookup.json"
fi

echo ""
echo "Done. All requests went through the VSAC proxy (CDC/OMB ethnicity value set)."
