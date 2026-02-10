#!/usr/bin/env bash
# Test the VSAC proxy locally before deploying to AWS.
# Usage:
#   1. Start the proxy (see below), then:
#      ./test-proxy.sh
#   2. Or with custom URL and API key:
#      PROXY_URL=http://localhost:8081 VSAC_UMLS_API_KEY=your-key ./test-proxy.sh
#
# Start proxy (pick one):
#   A) Standalone:  cd vsac-proxy && VSAC_UMLS_API_KEY=your-key python app.py
#   B) Docker:      docker compose up -d vsac-proxy  (set VSAC_UMLS_API_KEY in .env)

set -e

PROXY_URL="${PROXY_URL:-http://localhost:8081}"
# Strip trailing slash for curl
PROXY_URL="${PROXY_URL%/}"

echo "Testing VSAC proxy at ${PROXY_URL}"
echo ""

# 1. Health: proxy responds (no auth needed for our proxy; we're just checking it's up)
echo "1. Proxy reachability (GET ${PROXY_URL}/metadata)..."
HTTP=$(curl -s -o /tmp/vsac_proxy_meta.json -w "%{http_code}" "${PROXY_URL}/metadata" -H "Accept: application/fhir+json" 2>/dev/null || echo "000")
if [[ "$HTTP" == "000" ]]; then
  echo "   FAIL: Could not reach proxy. Is it running? (e.g. cd vsac-proxy && python app.py)"
  exit 1
fi
echo "   Proxy responded with HTTP ${HTTP}"

# 2. VSAC backend response via proxy
#    - 200: auth worked (valid API key)
#    - 401: VSAC rejected auth (missing or invalid key)
#    - 502: proxy could not reach VSAC
if [[ "$HTTP" == "200" ]]; then
  echo "   OK: Proxy and VSAC both responded (auth accepted if you set VSAC_UMLS_API_KEY)."
  echo "   CapabilityStatement length: $(wc -c < /tmp/vsac_proxy_meta.json) bytes"
elif [[ "$HTTP" == "401" ]]; then
  echo "   Expected if VSAC_UMLS_API_KEY is missing or invalid. Set a valid UMLS API key and restart the proxy."
elif [[ "$HTTP" == "502" ]]; then
  echo "   Proxy could not reach VSAC backend. Check network and VSAC_BACKEND."
else
  echo "   Unexpected status ${HTTP}. Check /tmp/vsac_proxy_meta.json"
fi

# 3. Optional: ValueSet request (requires valid API key)
echo ""
echo "2. ValueSet request (sample VSAC OID)..."
VSHTTP=$(curl -s -o /tmp/vsac_proxy_vs.json -w "%{http_code}" \
  "${PROXY_URL}/ValueSet/2.16.840.1.113762.1.4.1018.98" \
  -H "Accept: application/fhir+json" 2>/dev/null || echo "000")
echo "   HTTP ${VSHTTP}"
if [[ "$VSHTTP" == "200" ]]; then
  echo "   OK: ValueSet retrieved."
elif [[ "$VSHTTP" == "401" ]]; then
  echo "   VSAC requires a valid UMLS API key. Set VSAC_UMLS_API_KEY and restart the proxy."
else
  echo "   Response saved to /tmp/vsac_proxy_vs.json"
fi

echo ""
echo "Done. Run the proxy with your UMLS API key to get 200 responses from VSAC."
