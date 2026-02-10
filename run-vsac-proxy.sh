#!/usr/bin/env bash
# Run the VSAC proxy with your UMLS API key.
# Key can be set via:
#   - .env in this directory (VSAC_UMLS_API_KEY=...)
#   - Environment: export VSAC_UMLS_API_KEY=your-key
#   - This script: edit KEY below (not recommended if repo is shared)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load .env if present (so VSAC_UMLS_API_KEY can be set there)
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

# Optional: set key here for local use only (uncomment and replace)
# export VSAC_UMLS_API_KEY=your-umls-api-key

if [[ -z "${VSAC_UMLS_API_KEY:-}" ]]; then
  echo "Error: VSAC_UMLS_API_KEY is not set."
  echo "Set it in .env (VSAC_UMLS_API_KEY=your-key) or run:"
  echo "  export VSAC_UMLS_API_KEY=your-key"
  echo "  ./run-vsac-proxy.sh"
  exit 1
fi

cd vsac-proxy
pip install -q -r requirements.txt
echo "Starting VSAC proxy on port ${PORT:-8081} (backend: ${VSAC_BACKEND:-https://cts.nlm.nih.gov/fhir/})"
exec python -u app.py
