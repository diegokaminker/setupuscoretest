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
- **Terminology modes** – Remote (tx.fhir.org) or local (no external dependency)

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
- **Swagger UI**: http://localhost:8023/fhir/swagger-ui/
- **HAPI Tester**: http://localhost:8023/

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
| `SPRING_CONFIG_ADDITIONAL_LOCATION` | `file:///config/application.yaml` | Config file (remote tx vs local terminology)     |

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

### Application Config

Edit `config/application.yaml` (remote tx) or `config/application-local-terminology.yaml` (local) to change:

- Database connection (`POSTGRES_HOST`, `POSTGRES_USER`, etc.)
- US Core IG version or add other IGs
- Remote terminology server URL
- Value set pre-expansion settings

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

6. Optional: put a load balancer (ALB) or reverse proxy (nginx) in front; use HTTPS.

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

## Project Structure

```
.
├── config/
│   ├── application.yaml                    # HAPI/Spring config (default: remote tx)
│   └── application-local-terminology.yaml  # Config for local-only terminology
├── scripts/
│   └── load-terminology.sh                 # Load LOINC/SNOMED locally (no tx.fhir.org)
├── terminology-data/                       # Place Loinc_*.zip and SnomedCT_*.zip here
├── docker-compose.yml
├── Dockerfile
├── requirements.md
└── README.md
```

## References

- [US Core Implementation Guide v8.0.1](https://hl7.org/fhir/us/core/)
- [HAPI FHIR Documentation](https://hapifhir.io/hapi-fhir/docs/)
- [HAPI FHIR JPA Server Starter](https://github.com/hapifhir/hapi-fhir-jpaserver-starter)
