# VSAC FHIR Auth Proxy

Forwards FHIR terminology requests to [NLM VSAC](https://cts.nlm.nih.gov/fhir/) and adds **UMLS API key** authentication (Basic auth: empty username, password = API key). Use this so the HAPI server can call VSAC without custom Java client interceptors.

## Usage with HAPI (multi-terminology config)

1. **Get a UMLS API key** from [UTS Profile](https://uts.nlm.nih.gov/uts/profile) (free, requires UMLS license).

2. **Start the stack** (default config is multi-terminology) with the proxy:
   ```bash
   export VSAC_TERMINOLOGY_URL=http://vsac-proxy:8081/
   export VSAC_UMLS_API_KEY=your-umls-api-key
   docker compose up -d
   ```

3. HAPI will send VSAC terminology requests to `vsac-proxy`; the proxy adds the API key and forwards to `https://cts.nlm.nih.gov/fhir/`.

## Env vars

| Variable | Default | Description |
|----------|---------|-------------|
| `VSAC_UMLS_API_KEY` | (none) | UMLS API key; if empty, requests are forwarded without auth (will fail for protected VSAC resources). |
| `VSAC_BACKEND` | `https://cts.nlm.nih.gov/fhir/` | Backend URL. |
| `PORT` | `8081` | Listen port. |

## Run standalone (no Docker)

```bash
cd vsac-proxy
pip install -r requirements.txt
export VSAC_UMLS_API_KEY=your-key
python app.py
```

Then point HAPI’s VSAC terminology URL at `http://localhost:8081/` (when HAPI runs on the host).

## Test the proxy before AWS

Run the proxy locally and hit it with the test script so you can verify auth and connectivity before deploying.

**1. Start the proxy** (with your UMLS API key):

```bash
cd vsac-proxy
pip install -r requirements.txt
export VSAC_UMLS_API_KEY=your-umls-api-key
python app.py
# Leave it running; in another terminal run the test.
```

Or with Docker:

```bash
VSAC_UMLS_API_KEY=your-umls-api-key docker compose up -d vsac-proxy
# Proxy will be at http://localhost:8081
```

**2. Run the test script** (from repo root):

```bash
chmod +x vsac-proxy/test-proxy.sh
./vsac-proxy/test-proxy.sh
```

Optional: use a different URL or key via env:

```bash
PROXY_URL=http://localhost:8081 VSAC_UMLS_API_KEY=your-key ./vsac-proxy/test-proxy.sh
```

**3. What to expect**

- **Proxy not running** → script exits with "Could not reach proxy".
- **Proxy running, no/invalid API key** → HTTP 401 from VSAC (proxy is forwarding; auth is failing).
- **Proxy running + valid API key** → HTTP 200 and "OK" (ready for AWS).

**4. Optional: full stack test**

With the proxy passing the script above:

```bash
export VSAC_TERMINOLOGY_URL=http://vsac-proxy:8081/
export VSAC_UMLS_API_KEY=your-umls-api-key
docker compose up -d
# Default application.yaml is multi-terminology. Then trigger a VSAC value set operation from HAPI (e.g. validate-code or $expand on a VSAC value set).
```
