#!/usr/bin/env bash

set -euo pipefail

BASE="https://wp-content.vmware.com/v2/latest"
LIB_JSON="$BASE/lib.json"
ITEMS_JSON="$BASE/items.json"

echo "Downloading lib.json"
curl -fL --retry 3 --retry-delay 5 "$LIB_JSON" -o lib.json

echo "Downloading items.json"
curl -fL --retry 3 --retry-delay 5 "$ITEMS_JSON" -o items.json

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required. Install it with:"
    echo "  tdnf install -y jq"
    exit 1
fi

jq -c '.items[]' items.json | while IFS= read -r item; do
    item_name=$(echo "$item" | jq -r '.name // empty')

    if [[ -z "$item_name" || "$item_name" == "null" ]]; then
        continue
    fi

    echo "Processing $item_name"
    mkdir -p "$item_name"

    echo "$item" | jq -r '.files.hrefs[]? // empty' | while IFS= read -r relpath; do
        if [[ -z "$relpath" || "$relpath" == "null" ]]; then
            continue
        fi

        filename="$(basename "$relpath")"
        url="$BASE/$relpath"
        out="$item_name/$filename"

        if [[ -f "$out" ]]; then
            echo "Skipping existing $out"
            continue
        fi

        echo "Downloading $url -> $out"
        curl -fL --retry 3 --retry-delay 5 --continue-at - "$url" -o "$out"
    done
done