<#
.DESCRIPTION
    This script configures active directory zone permissions for a specified group. 
    This is required for the external-dns service account to be able to create and manage DNS records in the specified zone.

.NOTES
    File Name      : set-addnszoneacl.ps1
    Author         : Amayacitta Gill - amayacitta@gmail.com
	Date		   : 13/04/2026
.LINK
    https://www.amayacitta.co.uk
.EXAMPLE
    .\deploy-single-node-avi.ps1
	Follow the on screen prompts, type !? against each prompt for further information

#>
param   (
        # DNS zone name, e.g. aclab.uk
        [Parameter(Mandatory)]
        [string]$ZoneName,

        # Group to grant permissions to
        [Parameter(Mandatory)]
        [string]$GroupName,

        # DNS replication scope
        [Parameter(Mandatory)]
        [ValidateSet('Domain', 'Forest')]
        [string]$Scope
)

# Granting rights to create, read and delete dns records
# Remember external-dns tags records it owns with a TXT record
$rights = `
[System.DirectoryServices.ActiveDirectoryRights]::CreateChild `
-bor [System.DirectoryServices.ActiveDirectoryRights]::DeleteChild `
-bor [System.DirectoryServices.ActiveDirectoryRights]::ReadProperty `
-bor [System.DirectoryServices.ActiveDirectoryRights]::WriteProperty

# Inheritance flag enabled as we are duplicating the entire ACL and then adding in our specific ACE
# We need to retain inheritance as-is
$Inheritance = [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All

# Resolve the group SID
$group = Get-ADGroup $GroupName -ErrorAction Stop
$sid   = [System.Security.Principal.SecurityIdentifier]$group.SID

# Work out the DNS application partition
$domainDN = (Get-ADDomain).DistinguishedName

# Depending on the domain scope of domain or forest, the permission will be stored against a different object in AD
switch ($Scope) {
    'Domain' {
        $partitionDN = "DC=DomainDnsZones,$domainDN"
    }
    'Forest' {
        $partitionDN = "DC=ForestDnsZones,$domainDN"
    }
}

# Craft final zone DN
$zoneDN = "DC=$ZoneName,CN=MicrosoftDNS,$partitionDN"
Write-Host "Zone DN resolved"

# Grab the existing ACL
$de  = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$zoneDN")
$acl = $de.ObjectSecurity

# Build the new ACE
Write-Host "Building the new ACE into memory"
$ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
    $sid,
    $Rights,
    [System.Security.AccessControl.AccessControlType]::Allow,
    $Inheritance
)

# Add the new ACE to the ACL and write it back to the directory
Write-Host "Adding the new ACE to the existing ACL for $zoneDN"
$acl.AddAccessRule($ace)
$de.ObjectSecurity = $acl
$de.CommitChanges()