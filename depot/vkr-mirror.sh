#!/usr/bin/env bash

set -euo pipefail

base_tkg_content_library_uri="https://wp-content.vmware.com/v2/latest"
tkg_content_library_lib_url="${base_tkg_content_library_uri}/lib.json"
tkg_content_library_items_url="${base_tkg_content_library_uri}/items.json"

echo "Downloading lib.json"
curl -sSfL "$tkg_content_library_lib_url" -o lib.json

echo "Downloading items.json"
curl -sSfL "$tkg_content_library_items_url" -o items.json

# Ensure jq is installed
if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required but not installed. Install it first."
    echo "please run: tdnf install jq -y"
    exit 1
fi

# Iterate over ALL items
jq -c '.items[]' items.json | while read -r item; do
    itemFolderName=$(echo "$item" | jq -r '.name')

    if [ ! -d "$itemFolderName" ]; then
        echo "Downloading ${itemFolderName} ..."
        mkdir -p "$itemFolderName"
        pushd "$itemFolderName" >/dev/null

        # Correct extraction of file URLs
        echo "$item" | jq -r '.files[]?.href // empty' | while read -r file; do
            itemDownloadUrl="${base_tkg_content_library_uri}/${file}"

            echo "Downloading ${file} ..."
            curl -sSfL --retry 3 --retry-delay 5 "$itemDownloadUrl" -o "$(basename "$file")"
        done

        popd >/dev/null
    fi
done