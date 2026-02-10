#!/usr/bin/env python3
"""
Run IPS_1_01 bundle entries one-by-one as single-entry transactions.
Tracks created resource IDs from response Location, replaces urn:uuid references
in subsequent payloads with ResourceType/id so references resolve on the server.
"""

import json
import os
import re
import sys
from copy import deepcopy
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

SCRIPT_DIR = Path(__file__).resolve().parent
CURL_DIR = SCRIPT_DIR.parent / "curl"
BUNDLE_FILE = CURL_DIR / "IPS_1_01.json"
DEFAULT_BASE_URL = "https://hl7int-server.com/server/fhir"


def replace_references_in_obj(obj, uuid_to_ref):
    """Recursively replace reference values 'urn:uuid:...' with 'ResourceType/id'."""
    if isinstance(obj, dict):
        for k, v in list(obj.items()):
            if k == "reference" and isinstance(v, str) and v.startswith("urn:uuid:"):
                obj[k] = uuid_to_ref.get(v, v)
            else:
                replace_references_in_obj(v, uuid_to_ref)
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            replace_references_in_obj(item, uuid_to_ref)


def ref_from_location(location_header, resource_type):
    """
    Get reference string (ResourceType/id) from Location header or response body.
    Location may be full URL (https://host/fhir/Patient/123) or path (Patient/123).
    """
    if not location_header:
        return None
    s = location_header.strip()
    # Take last two path segments (ResourceType/id)
    parts = [p for p in re.split(r"[/?#]", s) if p]
    if len(parts) >= 2:
        # Assume last is id, second-to-last is resource type
        return f"{parts[-2]}/{parts[-1]}"
    if len(parts) == 1 and resource_type:
        return f"{resource_type}/{parts[-1]}"
    return None


def main():
    base_url = os.environ.get("FHIR_BASE_URL", DEFAULT_BASE_URL).rstrip("/")
    with open(BUNDLE_FILE, encoding="utf-8") as f:
        bundle = json.load(f)

    entries = bundle.get("entry", [])
    uuid_to_ref = {}  # fullUrl (urn:uuid:...) -> "ResourceType/id"

    for i, entry in enumerate(entries):
        full_url = entry.get("fullUrl", "")
        resource = entry.get("resource", {})
        request = entry.get("request", {})
        resource_type = resource.get("resourceType", "Resource")

        # Resolve references in a copy so we don't mutate the original
        resource_copy = deepcopy(resource)
        replace_references_in_obj(resource_copy, uuid_to_ref)

        one_entry = {
            "fullUrl": full_url,
            "resource": resource_copy,
            "request": request,
        }
        body = json.dumps(
            {"resourceType": "Bundle", "type": "transaction", "entry": [one_entry]},
            ensure_ascii=False,
        ).encode("utf-8")

        req = Request(
            f"{base_url}/",
            data=body,
            method="POST",
            headers={
                "Content-Type": "application/fhir+json",
                "Accept": "application/fhir+json",
            },
        )

        try:
            with urlopen(req, timeout=30) as resp:
                code = resp.getcode()
                resp_body = resp.read().decode("utf-8")
                location = resp.getheader("Location") or resp.getheader("location")
        except HTTPError as e:
            code = e.code
            resp_body = e.read().decode("utf-8") if e.fp else ""
            location = e.headers.get("Location") or e.headers.get("location")
            print(f"[FAIL] Entry {i + 1} ({resource_type}): HTTP {code}", file=sys.stderr)
            print(resp_body[:1500], file=sys.stderr)
            sys.exit(1)
        except URLError as e:
            print(f"[ERROR] Entry {i + 1}: {e}", file=sys.stderr)
            sys.exit(1)

        if code not in (200, 201):
            print(f"[FAIL] Entry {i + 1} ({resource_type}): HTTP {code}", file=sys.stderr)
            print(resp_body[:1500], file=sys.stderr)
            sys.exit(1)

        # Resolve ref from Location header, then response body entry[].response.location, then entry[].resource.id
        ref = ref_from_location(location, resource_type)
        if not ref and resp_body:
            try:
                r = json.loads(resp_body)
                if r.get("resourceType") == "Bundle" and r.get("entry"):
                    e0 = r["entry"][0]
                    loc = e0.get("response", {}).get("location")
                    ref = ref_from_location(loc, resource_type)
                    if not ref and e0.get("resource"):
                        rid = e0["resource"].get("id")
                        if rid:
                            ref = f"{e0['resource'].get('resourceType', resource_type)}/{rid}"
            except json.JSONDecodeError:
                pass

        if ref:
            uuid_to_ref[full_url] = ref
        print(f"[OK] Entry {i + 1}/{len(entries)}: {resource_type} -> {ref or '(no location)'}")

    print(f"Done. {len(entries)} resources created/updated.")


if __name__ == "__main__":
    main()
