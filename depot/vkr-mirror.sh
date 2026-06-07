#!/usr/bin/env bash

set -Eeuo pipefail

BASE="https://wp-content.vmware.com/v2/latest"

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1"
        exit 1
    }
}

download() {
    local url="$1"
    local out="$2"

    mkdir -p "$(dirname "$out")"

    echo "Downloading $url -> $out"
    curl -fL --retry 3 --retry-delay 5 --continue-at - "$url" -o "$out"
}

# Extract file paths from whatever schema this item uses
extract_paths() {
    local item_json="$1"

    jq -r '
      def emit_entry:
        if . == null then empty
        elif type == "string" then .
        elif type == "object" then
          (.href? // empty),
          (.hrefs[]? // empty)
        else empty
        end;

      .files as $f
      | if $f == null then
          empty
        elif ($f | type) == "array" then
          $f[] | emit_entry
        elif ($f | type) == "object" then
          $f | emit_entry
        else
          empty
        end
    ' <<<"$item_json" | sed '/^null$/d;/^$/d' | sort -u
}

main() {
    need_cmd curl
    need_cmd jq

    echo "Downloading lib.json"
    download "$BASE/lib.json" "lib.json"

    echo "Downloading items.json"
    download "$BASE/items.json" "items.json"

    jq -c '.items[]' items.json | while IFS= read -r item; do
        item_name="$(jq -r '.name // empty' <<<"$item")"

        if [[ -z "$item_name" || "$item_name" == "null" ]]; then
            echo "Skipping item with no valid name"
            continue
        fi

        echo "Processing $item_name"

        # Download item.json in each folder
        item_json_url="$BASE/$item_name/item.json"
        item_json_out="$item_name/item.json"

        if [[ ! -f "$item_json_out" ]]; then
            echo "Downloading $item_json_url -> $item_json_out"
            curl -fL --retry 3 --retry-delay 5 "$item_json_url" -o "$item_json_out"
        fi

        found_any=0

        while IFS= read -r relpath; do
            [[ -n "$relpath" ]] || continue
            found_any=1

            # If relpath already includes directories, mirror it exactly.
            # If it is just a filename, place it under the item folder.
            if [[ "$relpath" == */* ]]; then
                out="$relpath"
            else
                out="$item_name/$relpath"
            fi

            url="$BASE/${relpath#/}"
            download "$url" "$out"
        done < <(extract_paths "$item")

        if [[ "$found_any" -eq 0 ]]; then
            echo "No downloadable paths found for $item_name"
        fi
    done
}

main "$@"