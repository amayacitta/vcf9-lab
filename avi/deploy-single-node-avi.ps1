<#
.DESCRIPTION
    This script deploys a single node AVI control plane cluster via SDDC manager for VMware Cloud Foundation.

    For < 9.1 to find the AVI version reference the following table. Please refer to the JSON file in the avi GitHub repository for the latest versions and build numbers:
    https://github.com/avinetworks/devops/blob/master/tools/vcf/pvc.json 
    
    +---------+-------+-----------------------------+------------------+
    | Version | Build | OVA File                    | Product Version  |
    +---------+-------+-----------------------------+------------------+
    | 31.1.1  | 9.0.0 | controller-31.1.1-9122.ova  | 31.1.1-24544104  |
    | 31.1.2  | 9.0.1 | controller-31.1.2-9193.ova  | 31.1.2-24923866  |
    | 31.2.1  | 9.0.2 | controller-31.2.1-9148.ova  | 31.2.1-25015167  |
    +---------+-------+-----------------------------+------------------+

    For 9.1 and above you the pvc.json file on git is no longer updated, instead the OVA is pushed via VCF Operations. Below are the versions.

    +----------+----------+-----------------------------+------------------+
    | Version  | Build    | OVA File                    | Product Version  |
    +----------+----------+-----------------------------+------------------+
    | 32.1.1   | 9.1.0    | controller-32.1.1-9129.ova  | 32.1.1.25377988  |
    +----------+----------+-----------------------------+------------------+

.NOTES
    File Name      : deploy-single-node-avi.ps1
    Author         : Originally William Lam - https://github.com/lamw/vmware-scripts/blob/master/powershell/deploy_one_node_nsx_alb.ps1
                     Updated by Amayacitta Gill - amayacitta@gmail.com
	Date		   : 17/03/2026
.LINK
    https://www.amayacitta.co.uk
.EXAMPLE
    Run the below for VCF 9.1 or above
    .\deploy-single-node-avi.ps1 -vcf91
	Follow the on screen prompts, type !? against each prompt for further information

    Run the below for VCF 9.0.2 or below
    .\deploy-single-node-avi.ps1
	Follow the on screen prompts, type !? against each prompt for further information
#>
param 	(
		# Mandatory Parameters
		[parameter(
            Mandatory=$true,
            HelpMessage="Enter the SDDC Manager FQDN"
            )]
            [string]$sddcmFQDN,

		[parameter(
            Mandatory=$true,
            HelpMessage="Enter the SDDC Manager username"
            )]
            [string]$sddcmUsername,                 

		[parameter(
            Mandatory=$true,
            HelpMessage="Enter the SDDC Manager password"
            )]
            [securestring]$sddcmPassword,     
		
		[parameter(
            Mandatory=$true,
            HelpMessage="Enter the product version of NSX-ALB to deploy in the format of <version>-<build>. Refer to the table in the description"
            )]
            [string]$aviProductVersion,  

		[parameter(
            Mandatory=$true,
            HelpMessage="Enter the AVI cluster name to be deployed"
            )]
            [string]$aviClusterName,  

		[parameter(
            Mandatory=$true,
            HelpMessage="Select an appropriate form factor from the list"
            )]
            [ValidateSet('SMALL','LARGE','XLARGE')]
            [string]$aviFormFactor,
 
		[parameter(
            Mandatory=$true,
            HelpMessage="Enter the AVI cluster name to be deployed"
            )]
            [securestring]$aviAdminPassword,  

		[parameter(
            Mandatory=$true,
            HelpMessage="Enter the AVI cluster name to be deployed"
            )]
            [string]$aviFQDN,  

		[parameter(
            Mandatory=$true,
            HelpMessage="Enter the AVI cluster name to be deployed"
            )]
            [string]$aviNodeIP,
        
		[parameter(
            HelpMessage="Set if deploying VC 9.1 or above, ignore if deploying something earlier"
            )]
            [switch]$vcf91
        )

# cross platform securestring to plain text function
function Convert-SecureStringToPlainText {
    param (
        [Parameter(Mandatory)]
        [System.Security.SecureString]$SecureString
    )

    return (New-Object PSCredential "user", $SecureString).GetNetworkCredential().Password
}

# Convert the secure strings to plain text for use in API calls, these will be removed from memory immediately after use
$plainsddcmPassword    = Convert-SecureStringToPlainText $sddcmPassword
$plainaviAdminPassword = Convert-SecureStringToPlainText $aviAdminPassword

# Create the json payload
$payload = @{
    "username" = $sddcmUsername
    "password" = $plainsddcmPassword
}

$body = $payload | ConvertTo-Json

# Destory the clear text securestring
Remove-Variable plainsddcmPassword -Force

# Login to SDDC Manager and retrieve access token for subsequent API calls
Write-Host -ForegroundColor Cyan "`nLogging into SDDC Manager ..."
$requests = Invoke-WebRequest -Uri "https://${sddcmFQDN}/v1/tokens" -Method POST -Headers @{"Content-Type"="application/json"} -Body $body -SkipCertificateCheck -TimeoutSec 5
if($requests.StatusCode -eq 200) {
    $accessToken = ($requests.Content | ConvertFrom-Json).accessToken
} else {
    Write-Error "Failed to login to SDDC Manager, please verify credentials are correct"
}

# set the headers for subsequent API calls
$headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer ${accessToken}"
}

# retrieve the NSX cluster ID for the VCF management domain
Write-Host -ForegroundColor Cyan "Retrieving information about VCF Management Domain ..."
$requests = Invoke-WebRequest -Uri "https://${sddcmFQDN}/v1/domains?type=MANAGEMENT" -Method GET -Headers $headers -SkipCertificateCheck -TimeoutSec 5
if($requests.StatusCode -eq 200) {
    $nsxClusterId = ($requests.Content | ConvertFrom-Json).elements.nsxtCluster.id
} else {
    Write-Error "Failed to retrieve VCF Management Domain information"
}

# retrieve the bundle ID for the specified NSX-ALB product version
Write-Host -ForegroundColor Cyan "Retrieving NSX ALB Bundle ID  ..."
$requests = Invoke-WebRequest -Uri "https://${sddcmFQDN}/v1/product-version-catalogs" -Method GET -Headers $headers -SkipCertificateCheck -TimeoutSec 5
if($requests.StatusCode -eq 200) {
    $aviBundleId = (($requests.Content | ConvertFrom-Json).patches.NSX_ALB | where {$_.productVersion -eq $aviProductVersion}).artifacts.bundles.id
} else {
    Write-Error "Failed to retrieve VCF Product Version Catalog"
}

# create the json payload for AVI deployment
$payload = [ordered]@{
    "clusterName" = $aviClusterName
    "formFactor" = $aviFormFactor
    "adminPassword" = $plainaviAdminPassword
    "clusterFqdn" = $aviFQDN
    "nodes" = @(@{"ipAddress" = $aviNodeIP})
    "nsxIds" = @($nsxClusterId)
    "bundleId" = $aviBundleId
}

if($vcf91 -eq $true) {
    $payload["vcfopsAdminPassword"] = $aviAdminPassword
}

$body = $payload | ConvertTo-Json

# Destory the clear text securestring
Remove-Variable plainaviAdminPassword -Force

# Initiate the deployment
Write-Host -ForegroundColor Cyan "Initiating deployment of 1-Node NSX-ALB ..."
$requests = Invoke-WebRequest -Uri "https://${sddcmFQDN}/v1/alb-clusters?skipCompatibilityCheck=true" -Method POST -Body $body -Headers $headers -SkipCertificateCheck
if($requests.StatusCode -eq 202) {
    Write-Host -ForegroundColor Green "Deployment started, you can monitor the progress using the SDDC Manager and NSX Manager UI`n"
} else {
    Write-Error "Failed to initiate deployment"
}