#!/usr/bin/env python3
"""
Convert Postman FHIR collection to curl scripts.
- Replaces {{host}} and {{host_ips}} with BASE_URL
- Converts XML bodies to FHIR JSON (proper FHIR structure, not raw xmltodict)
- Replaces all Patient extensions with new_extension.json

For XML->JSON: Uses xmltodict + FHIR-aware post-processing. Alternative: use
https://fhir-formats.github.io/ for manual conversion, or fhir.resources[xml]
(pip install "fhir.resources[xml]") for programmatic conversion (Python 3.10+).
"""

import json
import os
import re
import sys
from pathlib import Path

# XML to JSON: use xmltodict (pip install xmltodict)
try:
    import xmltodict
    XMLTOJSON_AVAILABLE = True
except ImportError:
    XMLTOJSON_AVAILABLE = False

SCRIPT_DIR = Path(__file__).resolve().parent
COLLECTION_DIR = SCRIPT_DIR.parent
COLLECTION_FILE = COLLECTION_DIR / "FHIR-INTERMEDIATE_TESTS_SETUP.postman_collection.json"
NEW_EXTENSION_FILE = COLLECTION_DIR / "new_extension.json"
OUTPUT_DIR = COLLECTION_DIR / "curl"
BASE_URL = os.environ.get("FHIR_BASE_URL", "https://hl7int-server.com/server/fhir")
EXCLUDE_IDS = frozenset({"req_047", "req_044", "req_045"})  # Scripts to skip (not needed)


def slug_from_name(name: str, index: int) -> str:
    """Derive unique ID from Postman request name."""
    # Extract U02_L00_1_T01 style or similar
    m = re.search(r"U02[_\w]*?T\d+[ab]?", name, re.I)
    if m:
        s = m.group(0).replace("U02_", "").replace(":", "_")
        return re.sub(r"[^a-zA-Z0-9_]", "_", s)
    # Fallback
    return f"req_{index:03d}"


def load_new_extensions():
    with open(NEW_EXTENSION_FILE, encoding="utf-8") as f:
        data = json.load(f)
    return data.get("extension", [])


def replace_patient_extensions(resource: dict, new_extensions: list) -> dict:
    """Replace all extensions in a Patient resource with new_extension.json.
    Only applies when the Patient already has extensions."""
    if resource.get("resourceType") != "Patient" or "extension" not in resource:
        return resource
    res = dict(resource)
    res["extension"] = list(new_extensions)
    return res


def replace_patient_extensions_in_bundle(bundle_dict: dict, new_extensions: list) -> dict:
    """Replace Patient extensions in all Bundle entries."""
    entries = bundle_dict.get("entry") or []
    for entry in entries:
        res = entry.get("resource")
        if isinstance(res, dict) and res.get("resourceType") == "Patient":
            entry["resource"] = replace_patient_extensions(res, new_extensions)
    return bundle_dict


# Resource types that do NOT have text (not DomainResource)
_NO_TEXT_RESOURCE_TYPES = frozenset({"Bundle", "Parameters", "Binary"})


def _ensure_narrative(obj):
    """Ensure DomainResources have text (dom-6). Add default narrative if missing."""
    if isinstance(obj, list):
        return [_ensure_narrative(x) for x in obj]
    if not isinstance(obj, dict):
        return obj
    rt = obj.get("resourceType")
    if rt and rt not in _NO_TEXT_RESOURCE_TYPES and "text" not in obj:
        obj = dict(obj)
        obj["text"] = {
            "status": "generated",
            "div": '<div xmlns="http://www.w3.org/1999/xhtml">No narrative</div>',
        }
    out = {}
    for k, v in obj.items():
        if k == "resource" and isinstance(v, dict):
            out[k] = _ensure_narrative(v)
        elif k == "entry" and isinstance(v, list):
            out[k] = [_ensure_narrative(e) for e in v]
        else:
            out[k] = _ensure_narrative(v) if isinstance(v, (dict, list)) else v
    return out


# FHIR elements that must be arrays in JSON
_FHIR_ARRAY_ELEMENTS = {
    "identifier", "name", "address", "telecom", "contact", "photo",
    "communication", "link", "entry", "extension", "modifierExtension",
    "section", "contained", "author", "attester", "custodian", "relatesTo",
    "coding", "component", "dosageInstruction", "profile", "tag",
    "category", "bodySite", "interpretation", "referenceRange",
}

# FHIR primitives/single-value fields that must NOT be arrays
# Note: address.line is string[] in FHIR - do NOT include "line" here
_FHIR_SCALAR_KEYS = frozenset({
    "fullUrl", "resource", "request", "method", "url",
    "use", "system", "value", "family", "code", "display", "text",
    "city", "state", "country", "postalCode", "period",
    "status", "div", "reference",
})

def _unwrap_value(obj):
    """Unwrap {'@value': x} to x. Unwrap [x] to x when single primitive."""
    if isinstance(obj, dict) and len(obj) == 1 and "@value" in obj:
        return obj["@value"]
    if isinstance(obj, list) and len(obj) == 1 and isinstance(obj[0], str):
        return obj[0]
    return obj


def _fhir_xml_elem_to_json(elem, key_hint=None):
    """Convert xmltodict-style dict (from FHIR XML) to FHIR JSON."""
    if elem is None:
        return None
    if isinstance(elem, str):
        return elem
    if isinstance(elem, list):
        return [_fhir_xml_elem_to_json(x, key_hint) for x in elem if x is not None]
    if not isinstance(elem, dict):
        return elem
    # Single @value only -> return the value
    if len(elem) == 1 and "@value" in elem:
        return elem["@value"]
    out = {}
    for k, v in elem.items():
        if k.startswith("@"):
            out[k[1:]] = v
        elif k == "#text":
            out["value"] = v
        else:
            converted = _fhir_xml_elem_to_json(v, k)
            if converted is not None:
                # Unwrap single @value structures
                converted = _unwrap_value(converted) if isinstance(converted, dict) else converted
                if key_hint in _FHIR_ARRAY_ELEMENTS and not isinstance(converted, list):
                    converted = [converted]
                out[k] = converted
    return out


def _resource_type_from_wrapper(obj):
    """If obj is {ResourceType: {...}}, return (ResourceType, content). Else None."""
    if not isinstance(obj, dict) or len(obj) != 1:
        return None
    key = next(iter(obj.keys()))
    if key.startswith("@"):
        return None
    # FHIR resource type names are PascalCase
    if key[0].isupper() and key.isalnum():
        return (key, obj[key])
    return None


def _fix_resource_wrapper(obj):
    """Convert xmltodict {Patient: {...}} to FHIR {resourceType: "Patient", ...}."""
    r = _resource_type_from_wrapper(obj)
    if r:
        rtype, content = r
        if isinstance(content, dict):
            fixed = _fix_fhir_json_primitives(content)
            out = {"resourceType": rtype, **fixed}
            return out
        if isinstance(content, list) and len(content) == 1 and isinstance(content[0], dict):
            fixed = _fix_fhir_json_primitives(content[0])
            out = {"resourceType": rtype, **fixed}
            return out
    return None


def _fix_fhir_json_primitives(obj, parent_key=None):
    """Fix xmltodict output: unwrap scalar arrays, fix resource wrappers."""
    if isinstance(obj, list):
        result = [_fix_fhir_json_primitives(x, parent_key) for x in obj]
        if parent_key and parent_key in _FHIR_SCALAR_KEYS and len(result) == 1:
            one = result[0]
            if parent_key == "resource" and isinstance(one, dict):
                rw = _fix_resource_wrapper(one)
                return rw if rw else one
            if isinstance(one, str):
                return one
            if isinstance(one, dict) and parent_key in ("fullUrl", "request"):
                return one
        return result
    if not isinstance(obj, dict):
        return obj
    rw = _fix_resource_wrapper(obj)
    if rw:
        return _fix_fhir_json_primitives(rw, None)
    out = {}
    for k, v in obj.items():
        if k in ("xmlns", "xmlns:xsi") or k.startswith("xmlns:"):
            continue
        out[k] = _fix_fhir_json_primitives(v, k)
        if k == "given" and isinstance(out[k], str):
            out[k] = [out[k]]
        if k in ("profile", "tag") and isinstance(out[k], str):
            out[k] = [out[k]]
        if k == "coding" and isinstance(out[k], dict):
            out[k] = [out[k]]
        if k in ("category", "component", "interpretation", "referenceRange", "qualification") and isinstance(out[k], dict):
            out[k] = [out[k]]
        if k == "line" and isinstance(out[k], str):
            out[k] = [out[k]]
        # FHIR Narrative.div must be xhtml string (starts with <)
        if k == "div" and isinstance(out[k], dict) and len(out[k]) <= 2:
            val = out[k].get("value") or out[k].get("#text")
            if isinstance(val, str):
                out[k] = f'<div xmlns="http://www.w3.org/1999/xhtml">{val}</div>' if not val.strip().startswith("<") else val
    return out


def _fhir_xml_to_json_dict(raw: str) -> dict:
    """Convert FHIR XML string to FHIR JSON dict using xmltodict."""
    if not XMLTOJSON_AVAILABLE:
        raise RuntimeError("xmltodict required. Run: pip install xmltodict")
    d = xmltodict.parse(raw, force_list=("entry", "identifier", "name", "address", "telecom", "extension", "section"))
    if not d:
        raise ValueError("Empty XML")
    root_key = list(d.keys())[0]
    root = d[root_key]
    resource_type = root_key  # Patient, Bundle, etc.
    result = {"resourceType": resource_type}
    if isinstance(root, dict):
        for k, v in root.items():
            if k.startswith("@"):
                if k == "@xmlns":
                    continue
                result[k[1:]] = v
            else:
                converted = _fhir_xml_elem_to_json(v, k)
                if converted is not None:
                    converted = _unwrap_value(converted) if isinstance(converted, dict) and _unwrap_value(converted) != converted else converted
                    if k in _FHIR_ARRAY_ELEMENTS and not isinstance(converted, list) and isinstance(converted, dict):
                        converted = [converted]
                    result[k] = converted
    return _fix_fhir_json_primitives(result)


def xml_to_json(raw: str, content_type: str) -> str:
    """Convert FHIR XML to JSON. Returns JSON string."""
    if not raw or "xml" not in content_type.lower():
        return raw
    raw = raw.strip()
    try:
        d = _fhir_xml_to_json_dict(raw)
        return json.dumps(d, indent=2, ensure_ascii=False)
    except Exception as e:
        raise RuntimeError(f"XML conversion failed: {e}") from e


def build_url(postman_url: dict, variables: dict) -> str:
    """Build full URL from Postman url object."""
    raw = postman_url.get("raw", "")
    for k, v in variables.items():
        raw = raw.replace(f"{{{{{k}}}}}", v)
    return raw


def get_content_type(headers: list) -> str:
    for h in headers or []:
        if h.get("key", "").lower() == "content-type":
            return h.get("value", "application/fhir+json")
    return "application/fhir+json"


def to_curl(
    method: str,
    url: str,
    headers: list,
    body: str,
    output_file: Path,
    op_id: str,
    description: str,
):
    """Write curl command to shell script file."""
    from urllib.parse import urlparse
    lines = [
        "#!/usr/bin/env bash",
        f"# {op_id}: {description}",
        f"# Generated from Postman collection",
        "",
        f'BASE_URL="${{FHIR_BASE_URL:-{BASE_URL}}}"',
        "",
    ]
    # Extract path+query from full URL for use with BASE_URL
    if url.startswith("http"):
        parsed = urlparse(url)
        path_q = parsed.path.rstrip("/") or ""
        if parsed.query:
            path_q += "?" + parsed.query
        # Path relative to /server/fhir or /fhir
        for prefix in ("/server/fhir", "/fhir"):
            if path_q.startswith(prefix):
                path_q = path_q[len(prefix):].lstrip("/") or ""
                break
    else:
        path_q = url.replace(BASE_URL, "").strip("/") or ""
    # Use trailing slash when path is empty - many servers (e.g. nginx) return 301 without it
    if path_q:
        url_expr = f'"${{BASE_URL}}/{path_q}"'
    else:
        url_expr = '"${BASE_URL}/"'

    curl_parts = ["curl", "-s", "-w", "%{http_code}", "-o", '"$RESP"', "-X", method]
    for h in headers or []:
        key = h.get("key")
        if key and key.lower() not in ("content-type",) and h.get("value"):
            curl_parts.append(f'-H "{key}: {h.get("value")}"')
    if body and method in ("POST", "PUT", "PATCH"):
        ct = get_content_type(headers)
        curl_parts.append(f'-H "Content-Type: {ct}"')
        curl_parts.append('-H "Accept: application/fhir+json"')
        # Write body to companion .json file to avoid shell escaping issues
        body_file = output_file.with_suffix(".json")
        body_file.write_text(body, encoding="utf-8")
        curl_parts.append(f'-d @"{body_file.name}"')
    curl_parts.append(url_expr)
    lines.extend([
        'RESP=$(mktemp)',
        'trap "rm -f $RESP" EXIT',
        'HTTP_CODE=$(' + " ".join(curl_parts) + ')',
    ])
    lines.extend([
        'if [[ "$HTTP_CODE" =~ ^2 ]]; then',
        '  echo "[OK] HTTP $HTTP_CODE"',
        '  exit 0',
        'else',
        '  echo "[FAIL] HTTP $HTTP_CODE"',
        '  cat "$RESP" 2>/dev/null | head -20',
        '  exit 1',
        'fi',
        "",
    ])
    output_file.write_text("\n".join(lines), encoding="utf-8")
    output_file.chmod(0o755)


def main():
    if not COLLECTION_FILE.exists():
        print(f"Collection not found: {COLLECTION_FILE}", file=sys.stderr)
        sys.exit(1)
    if not NEW_EXTENSION_FILE.exists():
        print(f"Extension file not found: {NEW_EXTENSION_FILE}", file=sys.stderr)
        sys.exit(1)

    with open(COLLECTION_FILE, encoding="utf-8") as f:
        collection = json.load(f)

    variables = {
        "host": BASE_URL,
        "host_ips": BASE_URL,
    }
    for v in collection.get("variable", []) or []:
        if isinstance(v, dict) and v.get("key") and v.get("value"):
            variables[v["key"]] = v["value"]
    # Override with our base URL
    variables["host"] = BASE_URL
    variables["host_ips"] = BASE_URL

    new_extensions = load_new_extensions()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    items = collection.get("item", [])
    ids = []
    for i, item in enumerate(items):
        req = item.get("request", {})
        if not req:
            continue
        name = item.get("name", f"Request {i}")
        op_id = slug_from_name(name, i)
        if op_id in EXCLUDE_IDS:
            continue

        method = (req.get("method") or "GET").upper()
        url_obj = req.get("url") or {}
        if isinstance(url_obj, str):
            url = url_obj
        else:
            raw = url_obj.get("raw", "")
            for k, v in variables.items():
                raw = raw.replace(f"{{{{{k}}}}}", v)
            url = raw

        headers = req.get("header") or []
        body_raw = (req.get("body") or {}).get("raw") or ""

        content_type = get_content_type(headers)
        body = body_raw

        if body_raw and "xml" in content_type.lower():
            try:
                body = xml_to_json(body_raw, content_type)
                content_type = "application/fhir+json"
                headers = [h for h in headers if h.get("key", "").lower() != "content-type"]
                headers.append({"key": "Content-Type", "value": "application/fhir+json"})
            except Exception as e:
                print(f"Warning: XML conversion failed for {op_id}: {e}", file=sys.stderr)

        # Replace Patient extensions and ensure narrative (dom-6)
        if body:
            try:
                data = json.loads(body)
                if data.get("resourceType") == "Patient":
                    data = replace_patient_extensions(data, new_extensions)
                elif data.get("resourceType") == "Bundle":
                    data = replace_patient_extensions_in_bundle(data, new_extensions)
                data = _ensure_narrative(data)
                body = json.dumps(data, indent=2, ensure_ascii=False)
            except json.JSONDecodeError:
                pass

        out_file = OUTPUT_DIR / f"{op_id}.sh"
        to_curl(method, url, headers, body, out_file, op_id, name)
        ids.append(op_id)

    # Write run-all.sh and run.sh
    run_all = COLLECTION_DIR / "run-all.sh"
    run_all_content = [
        "#!/usr/bin/env bash",
        "# Run all FHIR setup operations in order",
        f'cd "$(dirname "$0")/curl"',
        "",
    ]
    for op_id in ids:
        run_all_content.append(f'echo ">>> Running {op_id}"')
        run_all_content.append(f'./{op_id}.sh')
        run_all_content.append("")
    run_all.write_text("\n".join(run_all_content), encoding="utf-8")
    run_all.chmod(0o755)

    run_one = COLLECTION_DIR / "run.sh"
    run_one_content = [
        "#!/usr/bin/env bash",
        "# Run a single operation by ID: ./run.sh L00_1_T02",
        f'cd "$(dirname "$0")/curl"',
        'ID="${1:-}"',
        'if [ -z "$ID" ]; then',
        '  echo "Usage: ./run.sh <ID>"',
        '  echo "Available IDs:"',
    ]
    for op_id in ids:
        run_one_content.append(f'  echo "  {op_id}"')
    run_one_content.extend([
        '  exit 1',
        'fi',
        'SCRIPT="${ID}.sh"',
        'if [ ! -f "$SCRIPT" ]; then',
        '  echo "Unknown ID: $ID"',
        '  exit 1',
        'fi',
        './"$SCRIPT"',
    ])
    run_one.write_text("\n".join(run_one_content), encoding="utf-8")
    run_one.chmod(0o755)

    print(f"Generated {len(ids)} curl scripts in {OUTPUT_DIR}")
    print("Run all: ./run-all.sh")
    print("Run one: ./run.sh <ID>")
    print("IDs:", ", ".join(ids[:10]), "..." if len(ids) > 10 else "")


if __name__ == "__main__":
    main()
