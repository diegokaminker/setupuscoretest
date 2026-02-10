#!/usr/bin/env python3
"""
VSAC FHIR auth proxy. Forwards requests to https://cts.nlm.nih.gov/fhir/
and adds Basic auth using the UMLS API key (empty username, password = key).
See: https://nlm.nih.gov/vsac/support/usingvsac/vsacfhirapi.html
"""
import os
import base64
from urllib.parse import urljoin

import requests
from flask import Flask, request, Response

BACKEND = os.environ.get("VSAC_BACKEND", "https://cts.nlm.nih.gov/fhir/")
API_KEY = os.environ.get("VSAC_UMLS_API_KEY", "").strip()

app = Flask(__name__)


def _auth_headers():
    if not API_KEY:
        return {}
    # NLM: Basic auth with empty username, password = API key
    value = f":{API_KEY}"
    encoded = base64.b64encode(value.encode()).decode()
    return {"Authorization": f"Basic {encoded}"}


@app.route("/", defaults={"path": ""}, methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"])
@app.route("/<path:path>", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"])
def proxy(path):
    if request.method == "OPTIONS":
        return Response(status=204, headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, Accept",
        })
    url = urljoin(BACKEND, path)
    if request.query_string:
        url = f"{url}?{request.query_string.decode()}"
    headers = {k: v for k, v in request.headers if k.lower() not in ("host", "connection", "authorization")}
    headers.update(_auth_headers())
    if request.get_data():
        headers["Content-Type"] = request.content_type or "application/fhir+json"
    try:
        resp = requests.request(
            method=request.method,
            url=url,
            headers=headers,
            data=request.get_data(),
            timeout=60,
            stream=False,
        )
    except requests.RequestException as e:
        app.logger.exception("VSAC backend request failed")
        return Response(str(e), status=502, mimetype="text/plain")
    excluded = ("Transfer-Encoding", "Connection", "Content-Encoding")
    response_headers = {k: v for k, v in resp.headers.items() if k not in excluded}
    return Response(resp.content, status=resp.status_code, headers=response_headers)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8081"))
    app.run(host="0.0.0.0", port=port, debug=False)
