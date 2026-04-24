#!/bin/bash

## convert the variable to something more readable
region=$1

## functions
connect_vks () {
  vcf context use --insecure-skip-tls-verify
}

create_sealed_secrets () {
    ## avi ako and amko
    echo "creating manifest for ako and amko"
    echo "{{- if .Values.vksclusters.$region.enabled }}" > ../argocd/vks-bootstrap/avi-system/templates/sealedsecret-$region.yaml
    kubectl get secret -n avi-system avi-secret -o yaml | kubeseal -o yaml >> ../argocd/vks-bootstrap/avi-system/templates/sealedsecret-$region.yaml
    echo "---" >> ../argocd/vks-bootstrap/avi-system/templates/sealedsecret-$region.yaml
    kubectl get secret -n avi-system gslb-avi-secret -o yaml | kubeseal -o yaml >> ../argocd/vks-bootstrap/avi-system/templates/sealedsecret-$region.yaml
    echo "{{ end -}}" >> ../argocd/vks-bootstrap/avi-system/templates/sealedsecret-$region.yaml
    echo "manifest created..."

    ## cert-manager
    echo "creating manifest for certificate manager"
    echo "{{- if .Values.vksclusters.$region.enabled }}" > ../argocd/vks-bootstrap/cert-manager/templates/sealedsecret-$region.yaml
    kubectl get secret -n cert-manager tanzu-sub01-tls-secret -o yaml | kubeseal -o yaml >> ../argocd/vks-bootstrap/cert-manager/templates/sealedsecret-$region.yaml
    echo "{{ end -}}" >> ../argocd/vks-bootstrap/cert-manager/templates/sealedsecret-$region.yaml
    echo "manifest created..."

    ## external-dns
    echo "creating manifest for externaldns"
    echo "{{- if .Values.vksclusters.$region.enabled }}" > ../argocd/vks-bootstrap/external-dns/templates/sealedsecret-$region.yaml
    kubectl get secret -n external-dns externaldns-kerberos-password -o yaml | kubeseal -o yaml >> ../argocd/vks-bootstrap/external-dns/templates/sealedsecret-$region.yaml
    echo "{{ end -}}" >> ../argocd/vks-bootstrap/external-dns/templates/sealedsecret-$region.yaml
    echo "manifest created..."
}

if [[ -n "$region" ]]; 

then
    echo "connect to the correct context for $region...
    "
    connect_vks 
    create_sealed_secrets
else
    echo 'Please pass the region, for example ./deploysealedsecrets.sh region01'
    exit 1
fi