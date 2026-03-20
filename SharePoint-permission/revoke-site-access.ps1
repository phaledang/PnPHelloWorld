param(
    [Parameter(Mandatory=$true)]
    [string]$TenantId,

    [Parameter(Mandatory=$true)]
    [string]$SiteUrl,

    [Parameter(Mandatory=$true)]
    [string]$AppId
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SharePoint Site Permission Revoke Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Tenant ID:    $TenantId"
Write-Host "Site URL:     $SiteUrl"
Write-Host "App ID:       $AppId"
Write-Host "`n*** IMPORTANT NOTE ***" -ForegroundColor Yellow
Write-Host "This will revoke ALL site-level permissions for the specified application." -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

# Check and install Microsoft.Graph module
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Sites)) {
    Write-Host "Installing Microsoft.Graph modules..." -ForegroundColor Yellow
    Install-Module Microsoft.Graph.Sites -Scope CurrentUser -Force -AllowClobber
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force -AllowClobber
}

# Import modules
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Sites

# Connect to Microsoft Graph
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
Connect-MgGraph -TenantId $TenantId -Scopes "Sites.FullControl.All"
Write-Host "Successfully connected to tenant.`n" -ForegroundColor Green

# Function to get site ID from URL
function Get-SiteIdFromUrl {
    param([string]$Url)
    
    $uri = [System.Uri]$Url
    $hostname = $uri.Host
    $sitePath = $uri.AbsolutePath.Trim('/')
    
    $siteId = "${hostname}:/$sitePath"
    return Get-MgSite -SiteId $siteId
}

# Resolve site
Write-Host "Resolving SharePoint site..." -ForegroundColor Yellow
$site = Get-SiteIdFromUrl -Url $SiteUrl
Write-Host "Site Name: $($site.DisplayName)" -ForegroundColor Cyan
Write-Host "Site ID:   $($site.Id)`n" -ForegroundColor Cyan

# Get all site permissions
Write-Host "Fetching site permissions..." -ForegroundColor Yellow
$sitePermissionsUrl = "https://graph.microsoft.com/v1.0/sites/$($site.Id)/permissions"

try {
    $sitePermissions = Invoke-MgGraphRequest -Method GET -Uri $sitePermissionsUrl
    
    if (-not $sitePermissions.value -or $sitePermissions.value.Count -eq 0) {
        Write-Host "No site permissions found." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "Found $($sitePermissions.value.Count) permission(s)`n" -ForegroundColor Green
    
    # Find permissions for the specified AppId
    $appPermissions = @()
    
    foreach ($perm in $sitePermissions.value) {
        $isMatch = $false
        
        # Check grantedToIdentitiesV2 (current format)
        if ($perm.grantedToIdentitiesV2) {
            foreach ($identity in $perm.grantedToIdentitiesV2) {
                if ($identity.application -and $identity.application.id -eq $AppId) {
                    $isMatch = $true
                    break
                }
            }
        }
        
        # Check grantedToIdentities (legacy format)
        if (-not $isMatch -and $perm.grantedToIdentities) {
            foreach ($identity in $perm.grantedToIdentities) {
                if ($identity.application -and $identity.application.id -eq $AppId) {
                    $isMatch = $true
                    break
                }
            }
        }
        
        # Check grantedTo (older legacy format)
        if (-not $isMatch -and $perm.grantedTo) {
            if ($perm.grantedTo.application -and $perm.grantedTo.application.id -eq $AppId) {
                $isMatch = $true
            }
        }
        
        if ($isMatch) {
            $appPermissions += $perm
        }
    }
    
    if ($appPermissions.Count -eq 0) {
        Write-Host "No permissions found for App ID: $AppId" -ForegroundColor Yellow
        Write-Host "The application does not have any permissions on this site." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "Found $($appPermissions.Count) permission(s) for App ID: $AppId" -ForegroundColor Green
    Write-Host "`nPermissions to be deleted:" -ForegroundColor Cyan
    foreach ($perm in $appPermissions) {
        Write-Host "  - Permission ID: $($perm.id)" -ForegroundColor Gray
        Write-Host "    Roles: $($perm.roles -join ', ')" -ForegroundColor Gray
    }
    
    # Confirm deletion
    Write-Host "`n*** WARNING ***" -ForegroundColor Red
    Write-Host "You are about to delete $($appPermissions.Count) permission(s) for App ID: $AppId" -ForegroundColor Red
    $confirmation = Read-Host "Type 'YES' to confirm deletion"
    
    if ($confirmation -ne "YES") {
        Write-Host "`nOperation cancelled by user." -ForegroundColor Yellow
        exit 0
    }
    
    # Delete each permission
    Write-Host "`nDeleting permissions..." -ForegroundColor Yellow
    $successCount = 0
    $failCount = 0
    
    foreach ($perm in $appPermissions) {
        $deleteUrl = "https://graph.microsoft.com/v1.0/sites/$($site.Id)/permissions/$($perm.id)"
        
        try {
            Write-Host "  Deleting permission: $($perm.id)..." -ForegroundColor Gray
            Invoke-MgGraphRequest -Method DELETE -Uri $deleteUrl
            Write-Host "    SUCCESS" -ForegroundColor Green
            $successCount++
        }
        catch {
            Write-Host "    ERROR: $($_.Exception.Message)" -ForegroundColor Red
            $failCount++
            
            # Try to get more details from the error response
            if ($_.Exception.Response) {
                $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                $errorBody = $reader.ReadToEnd()
                Write-Host "    Error Response: $errorBody" -ForegroundColor Red
            }
        }
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Revoke operation completed!" -ForegroundColor Green
    Write-Host "Successfully deleted: $successCount" -ForegroundColor Green
    if ($failCount -gt 0) {
        Write-Host "Failed to delete:     $failCount" -ForegroundColor Red
    }
    Write-Host "========================================" -ForegroundColor Cyan
}
catch {
    Write-Host "`nERROR: Failed to retrieve site permissions" -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Response) {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $errorBody = $reader.ReadToEnd()
        Write-Host "Error Response: $errorBody" -ForegroundColor Red
    }
    exit 1
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph | Out-Null
Write-Host "`nDisconnected from Microsoft Graph." -ForegroundColor Gray
