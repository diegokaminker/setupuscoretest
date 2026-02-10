#!/usr/bin/env bash
# Verify each terminology source used by multi-terminology config:
#   1. LOINC   (tx.fhir.org)
#   2. SNOMED  (tx.fhir.org)
#   3. Local   (hl7.terminology.r4 / US Core IG)
#   4. VSAC    (cts.nlm.nih.gov via proxy if configured)
# Calls the HAPI FHIR server; run with multi-terminology config and proxy for VSAC.
#
# Usage: FHIR_BASE_URL=http://localhost:8023/fhir ./scripts/verify-terminology.sh

set -e

BASE="${FHIR_BASE_URL:-http://localhost:8023/fhir}"
BASE="${BASE%/}"

OK=0
FAIL=0

check() {
  local name="$1"
  local method="$2"
  local path="$3"
  local data="$4"
  local expect="$5"   # e.g. "result.*true" or "expansion"
  echo -n "  $name ... "
  tmp=$(mktemp)
  if [[ "$method" == "GET" ]]; then
    http=$(curl -s -o "$tmp" -w "%{http_code}" "$BASE/$path" -H "Accept: application/fhir+json" 2>/dev/null || echo "000")
  else
    http=$(curl -s -o "$tmp" -w "%{http_code}" -X POST "$BASE/$path" \
      -H "Content-Type: application/fhir+json" -H "Accept: application/fhir+json" \
      -d "$data" 2>/dev/null || echo "000")
  fi
  if [[ "$http" != "200" ]]; then
    echo "FAIL (HTTP $http)"
    ((FAIL++)) || true
    rm -f "$tmp"
    return 1
  fi
  if grep -qE "$expect" "$tmp" 2>/dev/null; then
    echo "OK"
    ((OK++)) || true
    rm -f "$tmp"
    return 0
  else
    echo "FAIL (unexpected response)"
    ((FAIL++)) || true
    rm -f "$tmp"
    return 1
  fi
}

echo "Terminology verification (multi-terminology config)"
echo "FHIR server: $BASE"
echo ""

# 1. LOINC (tx.fhir.org)
echo "1. LOINC (tx.fhir.org)"
LOINC_PARAM='{"resourceType":"Parameters","parameter":[{"name":"code","valueCode":"15074-8"},{"name":"system","valueUri":"http://loinc.org"}]}'
check "validate-code 15074-8 (Glucose [Mass/volume])" POST "CodeSystem/\$validate-code" "$LOINC_PARAM" 'valueBoolean":\s*true'
# CodeSystem $lookup (must be delegated to tx.fhir.org; use system=http://loinc.org)
check "lookup 1963-8 (Bicarbonate)" GET "CodeSystem/\$lookup?system=http%3A%2F%2Floinc.org&code=1963-8" "" 'valueString":\s*"Bicarbonate'
echo ""

# 2. SNOMED (tx.fhir.org)
echo "2. SNOMED (tx.fhir.org)"
SNOMED_PARAM='{"resourceType":"Parameters","parameter":[{"name":"code","valueCode":"373270004"},{"name":"system","valueUri":"http://snomed.info/sct"}]}'
check "validate-code 373270004 (Allergy to penicillin)" POST "CodeSystem/\$validate-code" "$SNOMED_PARAM" 'valueBoolean":\s*true'
echo ""

# 3. Local / HL7 (hl7.terminology.r4 or US Core IG)
echo "3. Local terminology (HL7 / US Core IG)"
LOCAL_PARAM='{"resourceType":"Parameters","parameter":[{"name":"code","valueCode":"active"},{"name":"system","valueUri":"http://terminology.hl7.org/CodeSystem/condition-clinical"}]}'
check "validate-code condition-clinical#active" POST "CodeSystem/\$validate-code" "$LOCAL_PARAM" 'valueBoolean":\s*true'
echo ""

# 4. VSAC (cts.nlm.nih.gov; use proxy if VSAC_TERMINOLOGY_URL is set)
echo "4. VSAC (Ethnicity Categories value set)"
# Validate code 2135-2 (Hispanic or Latino) in VSAC value set 2.16.840.1.113883.4.642.40.2.48.3
VSAC_PARAM='{"resourceType":"Parameters","parameter":[{"name":"url","valueUri":"http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.4.642.40.2.48.3"},{"name":"code","valueCode":"2135-2"},{"name":"system","valueUri":"urn:oid:2.16.840.1.113883.6.238"}]}'
check "ValueSet/\$validate-code 2135-2 (Hispanic or Latino)" POST "ValueSet/\$validate-code" "$VSAC_PARAM" 'valueBoolean":\s*true'
echo ""

echo "---"
echo "Result: $OK passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
