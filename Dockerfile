# HAPI FHIR US Core Server
# Based on official HAPI FHIR image with custom config for PostgreSQL + US Core 8.0.1

FROM hapiproject/hapi:latest

# Copy both configs: remote tx (default) and local terminology
COPY config/application.yaml /config/application.yaml
COPY config/application-local-terminology.yaml /config/application-local-terminology.yaml

# ADD our config (overrides datasource/IG; keeps HAPI bean defaults)
ENV SPRING_CONFIG_ADDITIONAL_LOCATION=file:///config/application.yaml

EXPOSE 8080
