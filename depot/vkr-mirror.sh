#!/usr/bin/env bash

set -euo pipefail

BASE="https://wp-content.vmware.com/v2/latest"

echo "Downloading lib.json"
curl -sSfL "$BASE/lib.json" -o lib.json

echo "Downloading items.json"
curl -sSfL "$BASE/items.json" -o items.json

# Ensure jq is installed
if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required. Run: tdnf install jq -y"
    exit 1
fi

download_file() {
    local url="$1"
    local file
    file=$(basename "$url")

    # Skip if already exists
    if [[ -f "$file" ]]; then
        return
    fi

    echo "Downloading $file"
    curl -sSfL --retry 3 --retry-delay 5 "$url" -o "$file"

    # If it's JSON, follow nested refs (this is the missing piece)
    if [[ "$file" == *.json ]]; then
        while read -r nested; do
            [[ -n "$nested" ]] || continue
            download_file "$BASE/$nested"
        done < <(jq -r '.. | objects | .href? // empty' "$file")
    fi
}

# Main loop (no subshell issues)
while IFS= read -r item; do
    name=$(echo "$item" | jq -r '.name')

    echo "Processing $name"
    mkdir -p "$name"
    cd "$name"

    while read -r href; do
        [[ -n "$href" ]] || continue
        download_file "$BASE/$href"
    done < <(echo "$item" | jq -r '.files[]?.href // empty')

    cd ..
done < <(jq -c '.items[]' items.json)