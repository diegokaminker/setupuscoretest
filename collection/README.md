# FHIR Intermediate Tests Setup – curl Scripts

Curl scripts for setting up the FHIR Intermediate Unit 2 (Client Development) test data.

## Generated from

- **Postman collection**: `FHIR-INTERMEDIATE_TESTS_SETUP.postman_collection.json`
- **Extensions**: `new_extension.json` (replaces all Patient extensions)
- **Base URL**: `https://hl7int-server.com/server/fhir`

## Usage

### Run all operations

```bash
./run-all.sh
```

### Run a single operation by ID

```bash
./run.sh L00_1_T02
```

### Override base URL

```bash
FHIR_BASE_URL=https://your-server.com/fhir ./run-all.sh
FHIR_BASE_URL=https://your-server.com/fhir ./run.sh L00_1_T04
```

## Regenerating scripts

To regenerate curl scripts from the Postman collection:

```bash
pip install xmltodict
python3 scripts/postman_to_curl.py
```

## Operation IDs

Each operation has a unique ID derived from the Postman request name (e.g. `L00_1_T01`, `L01_2_T02`). List all IDs with:

```bash
./run.sh
```

## Directory structure

```
collection/
├── curl/              # Generated curl scripts (.sh) and bodies (.json)
├── scripts/
│   └── postman_to_curl.py
├── FHIR-INTERMEDIATE_TESTS_SETUP.postman_collection.json
├── new_extension.json
├── run-all.sh         # Run all operations
├── run.sh             # Run single operation by ID
└── README.md          # This file
```
