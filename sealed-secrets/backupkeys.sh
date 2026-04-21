#!/bin/bash

## convert the variable to something more readable
region=$1

## functions
connect_vks () {
  vcf context use --insecure-skip-tls-verify
}

backup_keys () {
## backup sealed secrets incase of redeployment
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > ../../sealed-secrets-backup/vks-$region-main.key
echo "backup complete"
}

if [[ -n "$region" ]]; 

then
    echo "connect to the correct context for $region...
    "
    connect_vks 
    echo "backing up sealed secret keys for $region..."
    backup_keys
else
    echo 'Please pass the region, for example ./deploysecrets.sh region01'
    exit 1
fi