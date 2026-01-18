#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR=".cache"
API_URL="https://models.dev/api.json"
OUTPUT_FILE="${CACHE_DIR}/models-dev-api.json"
FORCE_DOWNLOAD=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force|-f) FORCE_DOWNLOAD=true; shift ;;
        --help|-h) echo "Usage: $0 [--force]"; exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

mkdir -p "$CACHE_DIR"

if [[ "$FORCE_DOWNLOAD" = true ]] || [[ ! -f "$OUTPUT_FILE" ]]; then
    echo "Downloading models.dev API to $OUTPUT_FILE..."
    curl -s "$API_URL" -o "$OUTPUT_FILE"
    echo "Done."
else
    echo "Cache file exists. Use --force to redownload."
fi

echo "Summary:"
echo "  Providers: $(jq 'keys | length' "$OUTPUT_FILE")"
echo "  File size: $(du -h "$OUTPUT_FILE" | cut -f1)"
