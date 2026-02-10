# HAPI FHIR US Core Server
# Based on official HAPI FHIR image with custom config for PostgreSQL + US Core 8.0.1
# Pin version (e.g. v7.6.0) for reproducible builds; use 'latest' for newest.
ARG HAPI_IMAGE_TAG=v7.6.0
FROM hapiproject/hapi:${HAPI_IMAGE_TAG}

# Copy config: example is copied as application.yaml (override by mounting or set SPRING_CONFIG_ADDITIONAL_LOCATION)
COPY config/application-example.yaml /config/application.yaml

# ADD our config (overrides datasource/IG; keeps HAPI bean defaults)
ENV SPRING_CONFIG_ADDITIONAL_LOCATION=file:///config/application.yaml

EXPOSE 8080
