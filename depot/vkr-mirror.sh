#!/usr/bin/env bash

set -euo pipefail

BASE="https://wp-content.vmware.com/v2/latest"

echo "Downloading metadata..."
curl -sSfL "$BASE/lib.json" -o lib.json
curl -sSfL "$BASE/items.json" -o items.json

# check jq
command -v jq >/dev/null || { echo "Install jq: tdnf install jq -y"; exit 1; }

# loop items
jq -c '.items[]' items.json | while read -r item; do
    name=$(echo "$item" | jq -r '.name')
    echo "Processing $name"

    mkdir -p "$name"

    # for each file reference
    echo "$item" | jq -r '.files[].href' | while read -r href; do
        url="$BASE/$href"

        echo "Downloading path: $href"

        # pull entire directory contents
        curl -s "$url" | grep -Eo 'href="[^"]+"' | cut -d'"' -f2 | while read -r file; do
            full_url="$url/$file"

            echo " -> $file"
            curl -sSfL --retry 3 "$full_url" -o "$name/$file"
        done
    done
done