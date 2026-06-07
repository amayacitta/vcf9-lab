#!/usr/bin/env bash

base_depot_location="/var/www/html/VKR"
base_tkg_content_library_uri="https://wp-content.vmware.com/v2/latest"
tkg_content_library_lib_url="$base_tkg_content_library_uri/lib.json"
tkg_content_library_items_url="$base_tkg_content_library_uri/items.json"

echo "Downloading lib.json"
curl -L -o $base_depot_location/lib.json $tkg_content_library_lib_url

echo "Downloading items.json"
curl -L -o $base_depot_location/items.json $tkg_content_library_items_url

items=$(cat $base_depot_location/items.json)

while read allitems
do
dirname=$(echo $allitems | jq -r '.name')
downloadurls=$(echo $allitems | jq -r '.files[].hrefs')

newdir=$base_depot_location/$dirname
mkdir $newdir

###The --output-dir option is available since curl 7.73.0: So we are using wget who can compare incompletes and specify a directory.
echo $downloadurls | jq -c '.[]' | xargs -I % wget --no-if-modified-sinc -N -P "$newdir/" "$base_tkg_content_library_uri/%"

wget --no-if-modified-sinc -N -P "$newdir/" "$base_tkg_content_library_uri/$dirname/item.json"

done < <(echo $items | jq -c '.items[]')