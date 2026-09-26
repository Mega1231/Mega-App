#!/bin/bash
# Reads GOOGLE_MAPS_API_KEY from .env and writes to GoogleMaps.xcconfig
ENV_FILE="${SRCROOT}/../../.env"
OUTPUT="${SRCROOT}/Flutter/GoogleMaps.xcconfig"

if [ -f "$ENV_FILE" ]; then
  KEY=$(grep '^GOOGLE_MAPS_API_KEY=' "$ENV_FILE" | cut -d '=' -f2 | tr -d '[:space:]')
  echo "GOOGLE_MAPS_API_KEY=${KEY}" > "$OUTPUT"
else
  echo "GOOGLE_MAPS_API_KEY=" > "$OUTPUT"
fi
