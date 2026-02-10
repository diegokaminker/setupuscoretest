# HAPI FHIR US Core Server

A Docker-based FHIR HAPI server with PostgreSQL backend, preloaded with [US Core Implementation Guide v8.0.1](https://hl7.org/fhir/us/core/) and terminology support for LOINC, SNOMED CT, UCUM, and HL7 value sets.

## Features

- **HAPI FHIR JPA Server** – FHIR R4 REST API
- **PostgreSQL 14** – Persistent database (PostgreSQL 15/16 have known compatibility issues)
- **US Core 8.0.1** – Implementation guide, profiles, extensions, and value set definitions
- **Terminology** – LOINC, SNOMED CT, UCUM, and US Core value sets via:
  - Remote terminology server ([tx.fhir.org](https://tx.fhir.org)) for LOINC and SNOMED
  - US Core IG package (value set definitions)
  - hl7.terminology.r4 (UCUM, HL7 vocabularies) as transitive dependency
- **AWS-ready** – Docker Compose setup suitable for EC2, ECS, or EKS
- **Port 8023** – Configurable via `FHIR_PORT` (default 8023)
- **IPS (International Patient Summary)** – `Patient/$summary` operation enabled; IPS IG 1.1.0 loaded
- **Terminology modes** – Remote (tx.fhir.org) or local (no external dependency)
- **MCP (Model Context Protocol)** – Optional [FHIR MCP Server](https://github.com/wso2/fhir-mcp-server) for AI/LLM integration (VS Code, Claude Desktop, MCP Inspector)

## Quick Start

### Prerequisites

- Docker and Docker Compose
- 2GB+ RAM recommended
- Internet access for first startup (IG and terminology packages are fetched)

### Local Run

```bash
# Build and start (default: port 8023, remote tx.fhir.org terminology)
docker compose up -d

# Check status (HAPI may take 2–3 minutes on first startup for IG load)
docker compose ps

# View logs
docker compose logs -f hapi-fhir
```

### Verify

- **FHIR Base URL**: http://localhost:8023/fhir
- **CapabilityStatement**: http://localhost:8023/fhir/metadata
- **IPS $summary**: `POST /fhir/Patient/{id}/$summary` (or `GET /fhir/Patient/{id}/$summary`)
- **Swagger UI**: http://localhost:8023/fhir/swagger-ui/
- **HAPI Tester**: http://localhost:8023/
- **MCP Server** (if enabled): http://localhost:8000/mcp

Example:

```bash
curl http://localhost:8023/fhir/metadata
```

## Configuration

### Environment Variables

| Variable                  | Default                               | Description                                      |
|---------------------------|----------------------------------------|--------------------------------------------------|
| `POSTGRES_PASSWORD`       | `admin`                                | PostgreSQL password                              |
| `FHIR_PORT`               | `8023`                                 | Host port for FHIR server                        |
| `MCP_PORT`                | `8000`                                 | Host port for FHIR MCP server (AI/LLM tools)     |
| `SPRING_CONFIG_ADDITIONAL_LOCATION` | `file:///config/application.yaml` | Default: multi-terminology (tx + VSAC). Use `application_default.yaml` for single remote tx, or `application-local-terminology.yaml` for local only. |
| `VSAC_TERMINOLOGY_URL`             | (none)                            | When set (e.g. `http://vsac-proxy:8081/`), HAPI uses this for VSAC (multi-terminology) |
| `VSAC_UMLS_API_KEY`                | (none)                            | UMLS API key for vsac-proxy (multi-terminology + VSAC) |

**Terminology mode** – choose remote (tx.fhir.org) or local:

```bash
# Remote terminology (default) – uses tx.fhir.org for LOINC/SNOMED
docker compose up -d

# Local terminology – after running scripts/load-terminology.sh
SPRING_CONFIG_ADDITIONAL_LOCATION=file:///config/application-local-terminology.yaml docker compose up -d
```

Or add to `.env`:
```bash
# .env
POSTGRES_PASSWORD=your-secure-password
FHIR_PORT=8023

# For local terminology (no tx.fhir.org):
# SPRING_CONFIG_ADDITIONAL_LOCATION=file:///config/application-local-terminology.yaml
```

Copy `.env.example` to `.env` and edit as needed.

**No remote terminology (local only):** To avoid any calls to tx.fhir.org or VSAC, use `application-local-terminology.yaml` (it now sets `remote_terminology_service: {}` so the image’s default remote config is overridden). If you edit `application.yaml` and just delete the `remote_terminology_service` block, the server can still use remote terminology from the base image config (Spring merges configs). You must either use the local config or set `remote_terminology_service: {}` explicitly in your YAML.

**Instance: use only application.yaml** – On the server/instance, use the default config (multi-terminology) and no override:

- In `.env`, **do not set** `SPRING_CONFIG_ADDITIONAL_LOCATION`, so the default `file:///config/application.yaml` is used; or set it explicitly:
  ```bash
  SPRING_CONFIG_ADDITIONAL_LOCATION=file:///config/application.yaml
  ```
- Restart: `docker compose up -d` (or `docker compose restart hapi-fhir`).
- Confirm: `./scripts/verify-config.sh` or `docker exec hapi-fhir-uscore env | grep SPRING_CONFIG`.

**Start HAPI from scratch** (wipe DB and restart with current config):
```bash
# Optional: set config first (e.g. local-only, no remote)
export SPRING_CONFIG_ADDITIONAL_LOCATION=file:///config/application-local-terminology.yaml

./scripts/start-from-scratch.sh
```
Or manually: `docker compose down -v` then `docker compose up -d`. This removes the Postgres volume so all server data (resources, loaded terminology, IG cache) is lost. After a scratch start with local terminology, run `./scripts/load-terminology.sh` again to reload LOINC/SNOMED.

### Application Config

Edit `config/application.yaml` (default: multi-terminology), `config/application_default.yaml` (single remote tx), or `config/application-local-terminology.yaml` (local) to change:

- Database connection (`POSTGRES_HOST`, `POSTGRES_USER`, etc.)
- US Core IG version or add other IGs
- Remote terminology server URL
- Value set pre-expansion settings

**HAPI server version:** The image is pinned to **v7.6.0** in the Dockerfile (`ARG HAPI_IMAGE_TAG=v7.6.0`). To use a different tag (e.g. `latest` or `v8.4.0-2`): `docker compose build --build-arg HAPI_IMAGE_TAG=latest` then `docker compose up -d`. See [hapiproject/hapi tags](https://hub.docker.com/r/hapiproject/hapi/tags).

## AWS Deployment

### Option 1: EC2 with Docker

1. Launch an EC2 instance (t3.medium or larger recommended).
2. Install Docker and Docker Compose.
3. Clone/copy this project onto the instance.
4. Configure security group: allow inbound 8023 (or `FHIR_PORT`).
5. Run:

   ```bash
   docker compose up -d
   ```

6. **Nginx + Let's Encrypt (HTTPS):** See `nginx/README.md` for reverse proxy config. Proxies:
   - `https://your-domain/server/fhir` → HAPI
   - `https://your-domain/mcp` → MCP server

### Option 2: ECS (Fargate)

1. Build and push images to ECR:

   ```bash
   aws ecr create-repository --repository-name hapi-fhir-uscore
   docker build -t hapi-fhir-uscore .
   docker tag hapi-fhir-uscore:latest <account-id>.dkr.ecr.<region>.amazonaws.com/hapi-fhir-uscore:latest
   docker push <account-id>.dkr.ecr.<region>.amazonaws.com/hapi-fhir-uscore:latest
   ```

2. Create ECS task definition: HAPI container + PostgreSQL (or use RDS for PostgreSQL).
3. Update `config/application.yaml` with RDS endpoint and credentials.
4. Run the task definition as a service.

### Option 3: EKS

Use the same images as above. Deploy HAPI and PostgreSQL with Kubernetes manifests or Helm; expose HAPI via Ingress or LoadBalancer.

### Security Notes for Production

- Change default PostgreSQL password.
- Use RDS or managed PostgreSQL instead of a container DB when possible.
- Enable HTTPS (reverse proxy or ALB with SSL).
- Restrict CORS `allowed_origin` in `config/application.yaml`.
- Consider network segmentation and security groups.

## MCP (Model Context Protocol)

The [WSO2 FHIR MCP Server](https://github.com/wso2/fhir-mcp-server) is included and runs alongside HAPI. It exposes FHIR resources as MCP tools for AI assistants (Claude Desktop, VS Code, Cursor, MCP Inspector).

### Endpoints

- **MCP Streamable HTTP**: http://localhost:8000/mcp
- **MCP SSE**: http://localhost:8000/sse

### Connect from Cursor / VS Code

Add to your MCP config (e.g. `.cursor/mcp.json` or VS Code MCP settings):

```json
{
  "mcpServers": {
    "fhir-uscore": {
      "url": "http://localhost:8000/mcp"
    }
  }
}
```

For remote deployment (e.g. hl7int-server.com), use your server URL:

```json
{
  "mcpServers": {
    "fhir-uscore": {
      "url": "https://hl7int-server.com/mcp/mcp"
    }
  }
}
```

*(Ensure nginx or your reverse proxy forwards `/mcp` to the MCP server on port 8000.)*

### MCP Tools

The server provides FHIR tools: `get_capabilities`, `search`, `read`, `create`, `update`, `delete`, and `get_user`. See [fhir-mcp-server documentation](https://github.com/wso2/fhir-mcp-server#tools) for details.

### Disable MCP

To run without the MCP server, use a profile or comment out the `fhir-mcp-server` service in `docker-compose.yml`, or scale it down:

```bash
docker compose up -d --scale fhir-mcp-server=0
```

## Terminology

### Default (Remote tx.fhir.org)

By default, terminology uses the remote [tx.fhir.org](https://tx.fhir.org) for LOINC and SNOMED. No local upload required.

### Local Terminology (No tx.fhir.org Dependency)

For full local terminology with **no remote dependency**, use `scripts/load-terminology.sh`:

1. **Download terminology files** (manual, registration/license required):
   - **LOINC** (free, registration at [loinc.org/join](https://loinc.org/join/)):  
     Download `Loinc_2.xx.zip` from [loinc.org/downloads](https://loinc.org/downloads/)
   - **SNOMED CT International** (free license at [snomed.org](https://www.snomed.org/)):  
     Download `SnomedCT_InternationalRF2_PRODUCTION_YYYYMMDDT120000Z.zip`

2. **Place files** in `terminology-data/`:
   ```bash
   mkdir -p terminology-data
   # Copy Loinc_2.xx.zip and SnomedCT_*_RF2_*.zip into terminology-data/
   ```

3. **Run the script** (after `docker compose up -d`):
   ```bash
   chmod +x scripts/load-terminology.sh
   ./scripts/load-terminology.sh
   ```

4. **Options**:
   ```bash
   ./scripts/load-terminology.sh --help
   ./scripts/load-terminology.sh -t http://localhost:8023/fhir -d ./terminology-data
   ./scripts/load-terminology.sh --skip-snomed   # LOINC only
   ./scripts/load-terminology.sh --skip-loinc   # SNOMED only
   ```

The script will:
- Switch config to `application-local-terminology.yaml` (no remote tx)
- Upload LOINC and SNOMED to HAPI
- Load hl7.terminology.r4 (UCUM, HL7 vocab) at HAPI restart
- Restart HAPI to apply config

**Verify** LOINC after upload:
```bash
curl -X POST 'http://localhost:8023/fhir/CodeSystem/$validate-code' \
  -H 'Content-Type: application/fhir+json' \
  -d '{"resourceType":"Parameters","parameter":[{"name":"code","valueCode":"15074-8"},{"name":"system","valueUri":"http://loinc.org"}]}'
```

### VSAC Terminology (with UMLS API key)

To use **NLM VSAC** (Value Set Authority Center) for value set expansion/validation, use the **multi-terminology** config and the **VSAC auth proxy** so HAPI can call VSAC with your UMLS API key:

1. Default config `config/application.yaml` is already multi-terminology (tx for LOINC/SNOMED, local US Core, VSAC).
2. Run the **vsac-proxy** and point HAPI at it:
   ```bash
   export VSAC_TERMINOLOGY_URL=http://vsac-proxy:8081/
   export VSAC_UMLS_API_KEY=your-umls-api-key
   docker compose up -d
   ```
3. Get a free [UMLS API key](https://uts.nlm.nih.gov/uts/profile) (UMLS license required).

See `vsac-proxy/README.md` for proxy details and standalone run.

**Load VSAC terminology locally (no remote VSAC):** You can load a pre-built FHIR package containing VSAC value sets and code systems so the server does not need to call the VSAC API (no UMLS key or vsac-proxy required for those value sets). In `config/application.yaml`, under `implementationguides`, uncomment the `vsac` block (the one with `packageUrl: https://www.fhir.org/packages/us.nlm.vsac/0.24.0/package.tgz`). On the next startup, HAPI will download and install the [us.nlm.vsac](https://www.fhir.org/packages/us.nlm.vsac/) package (ValueSets and CodeSystems used by US Core/CCDA). Resolution for those value sets will then be local. The package is large so first startup may take longer. You can leave the `remote_terminology_service` vsac entries in place as fallback for value sets not in the package, or remove them to use only what’s in the package.

**If ValueSet/validate-code for VSAC goes to tx.fhir.org:** HAPI routes by **code system**. The default config (application.yaml) maps LOINC and SNOMED to tx only; all other code systems used in US Core/VSAC (CDCREC, CPT, HCPCS, ICD-10-CM, ICD-10-PCS, NUCC, RxNorm, NDC) are mapped to VSAC. Ensure `VSAC_TERMINOLOGY_URL` is set (e.g. `http://vsac-proxy:8081/`) and restart HAPI. To add another code system, add a `vsac_*` entry in `application.yaml` with `system: "urn:oid:..."` and the same `url`.

**Verify all terminology sources** (LOINC, SNOMED, local HL7, VSAC) with one script:
```bash
./scripts/verify-terminology.sh
# Or: FHIR_BASE_URL=http://localhost:8023/fhir ./scripts/verify-terminology.sh
```

**If CodeSystem $lookup returns "not found" for LOINC/SNOMED (while tx.fhir.org works):** Logs show the server trying only local sources (`JpaResourceDaoCodeSystem` then `DefaultProfileValidationSupport` loading classpath valuesets) and never calling the remote server—so for $lookup the remote terminology support is either not in the chain or not reached. (1) **Try the single-remote config** so $lookup goes to tx: set `SPRING_CONFIG_ADDITIONAL_LOCATION=file:///config/application_default.yaml` and restart. If $lookup works with that config, the limitation is with the multi-terminology setup (multiple named remote services) and $lookup. (2) Use `system=http://loinc.org` in the request (no trailing slash).

**Seeing terminology in logs:** HAPI does not log the list of remote terminology services at startup. To see terminology-related activity (including errors when a remote $lookup or $validate-code fails), enable the terminology troubleshooting logger. View logs with `docker-compose logs -f hapi-fhir`. To enable the logger, uncomment the `logging.level.ca.uhn.fhir.log.terminology_troubleshooting` block in `config/application.yaml` (set to `DEBUG`), then restart. You can also set the level via environment: `LOGGING_LEVEL_CA_UHN_FHIR_LOG_TERMINOLOGY_TROUBLESHOOTING=DEBUG` in your compose environment.

## FHIR Intermediate Test Data Setup

Curl scripts to load test data for FHIR Intermediate Unit 2 (Client Development):

```bash
cd collection
./run-all.sh              # Load all test data
./run.sh L00_1_T02        # Run a single operation
```

See `collection/README.md` for details.

## Repository layout (git pull on AWS / other instances)

This project lives inside a larger repo. The **git repository root** is the parent of `HL7_COURSES_MAT` (e.g. `HL7FUN_NEW_MATERIALS`). The US Core server files are under:

```text
HL7_COURSES_MAT/FHIR_INTERMEDIATE/SETUP_US_CORE_SERVER/
```

- **Run `git pull` from the repo root** (the folder that contains `HL7_COURSES_MAT`), not from inside `SETUP_US_CORE_SERVER`. Then the new files (e.g. `vsac-proxy/`, `config/application.yaml` / `application_default.yaml`) will appear under `HL7_COURSES_MAT/FHIR_INTERMEDIATE/SETUP_US_CORE_SERVER/`.
- If your instance only has a clone where `SETUP_US_CORE_SERVER` is the repo root, that clone is not this repo — clone the full repo and use the path above.

```bash
# On the instance (from repo root):
cd /path/to/HL7FUN_NEW_MATERIALS    # or whatever the clone folder is
git pull
ls HL7_COURSES_MAT/FHIR_INTERMEDIATE/SETUP_US_CORE_SERVER/vsac-proxy
# Then cd into the server folder to run docker compose:
cd HL7_COURSES_MAT/FHIR_INTERMEDIATE/SETUP_US_CORE_SERVER
docker compose up -d
```

### If you only have one folder on the instance (e.g. `setupuscoretest`)

If the instance only has a single folder like `setupuscoretest` (no `HL7_COURSES_MAT` parent), that folder is not the full repo, so `git pull` there will not bring in the new files. Use the full repo and the nested path:

```bash
# 1. Backup your current folder (optional; keep .env and any local changes first)
mv setupuscoretest setupuscoretest.bak

# 2. Clone the full repo; you can name the clone folder as you like (e.g. setupuscoretest)
git clone https://github.com/diegokaminker/HL7FUN_NEW_MATERIALS setupuscoretest
cd setupuscoretest

# 3. The server files are inside this path — go there to run Docker
cd HL7_COURSES_MAT/FHIR_INTERMEDIATE/SETUP_US_CORE_SERVER

# 4. Copy .env from backup if you had one
# cp ../../../../setupuscoretest.bak/.env .   # adjust path if needed

docker compose up -d
```

From then on: run **`git pull`** from **`setupuscoretest`** (the repo root), then run **`docker compose`** from **`setupuscoretest/HL7_COURSES_MAT/FHIR_INTERMEDIATE/SETUP_US_CORE_SERVER`**.

## Project Structure

```
.
├── collection/
│   ├── curl/             # Curl scripts for FHIR Intermediate test setup
│   ├── run-all.sh, run.sh
│   └── README.md
├── config/
│   ├── application.yaml                         # Default: multi-terminology (tx + VSAC)
│   ├── application_default.yaml                 # Single remote tx (all to tx.fhir.org)
│   └── application-local-terminology.yaml       # Local-only terminology (no tx)
├── vsac-proxy/                                  # VSAC auth proxy (adds UMLS API key to cts.nlm.nih.gov requests)
├── nginx/
│   ├── hl7int-server.conf                       # Nginx + Let's Encrypt for FHIR + MCP
│   └── README.md                           # Setup instructions
├── scripts/
│   └── load-terminology.sh                 # Load LOINC/SNOMED locally (no tx.fhir.org)
├── terminology-data/                       # Place Loinc_*.zip and SnomedCT_*.zip here
├── docker-compose.yml
├── Dockerfile
├── Dockerfile.mcp                          # MCP server build (amd64)
├── requirements.md
└── README.md
```

## References

- [US Core Implementation Guide v8.0.1](https://hl7.org/fhir/us/core/)
- [HAPI FHIR Documentation](https://hapifhir.io/hapi-fhir/docs/)
- [HAPI FHIR JPA Server Starter](https://github.com/hapifhir/hapi-fhir-jpaserver-starter)
