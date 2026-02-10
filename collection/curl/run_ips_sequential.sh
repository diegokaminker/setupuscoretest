#!/usr/bin/env bash
# Run IPS_1_01 bundle entries sequentially; each request uses resolved ResourceType/id
# for references (from previous responses' Location). Use FHIR_BASE_URL to target a server.
# Example: FHIR_BASE_URL=https://fhirserver.hl7fundamentals.org/fhir ./run_ips_sequential.sh

cd "$(dirname "$0")"
exec python3 ../scripts/run_ips_sequential.py
