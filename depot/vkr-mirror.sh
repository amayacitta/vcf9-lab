#!/usr/bin/env bash

set -euo pipefail

base="https://wp-content.vmware.com/v2/latest"

echo "Downloading lib.json"
curl -sSfL "$base/lib.json" -o lib.json

echo "Downloading items.json"
curl -sSfL "$base/items.json" -o items.json

if ! command -v jq >/dev/null 2>&1; then
    echo "Install jq first: tdnf install jq -y"
    exit 1
fi

download_file() {
    local url="$1"
    local file
    file=$(basename "$url")

    if [ -f "$file" ]; then
        return
    fi

    echo "Downloading $file"
    curl -sSfL --retry 3 --retry-delay 5 "$url" -o "$file"

    # If it's JSON, inspect it for more hrefs
    if [[ "$file" == *.json ]]; then
        jq -r '.. | .href? // empty' "$file" | while read -r nested; do
            download_file "$base/$nested"
        done
    fi
}

jq -c '.items[]' items.json | while read -r item; do
    name=$(echo "$item" | jq -r '.name')
    echo "Processing $name"

    mkdir -p "$name"
    pushd "$name" >/dev/null

    echo "$item" | jq -r '.files[]?.href // empty' | while read -r href; do
        download_file "$base/$href"
    done

    popd >/dev/null
done