param(
    [Parameter(Mandatory=$true)]
    [string]$TenantId,

    [Parameter(Mandatory=$true)]
    [string]$SiteUrl,

    [Parameter(Mandatory=$false)]
    [string]$AppId
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SharePoint Permission Check Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`n*** UNDERSTANDING PERMISSIONS ***" -ForegroundColor Yellow
Write-Host "• Microsoft Graph API only supports SITE-LEVEL permissions for applications" -ForegroundColor Yellow
Write-Host "• If you see permissions, they apply to ALL libraries in the site" -ForegroundColor Yellow
Write-Host "• Library-granular access control must be implemented in your application logic" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan
Write-Host "Tenant ID:    $TenantId"
Write-Host "Site URL:     $SiteUrl"
if ($AppId) {
    Write-Host "App ID:       $AppId"
}
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
Connect-MgGraph -TenantId $TenantId -Scopes "Sites.Read.All"
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

# Check site-level permissions
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Checking Site-Level Permissions" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

$sitePermissionsUrl = "https://graph.microsoft.com/v1.0/sites/$($site.Id)/permissions"
Write-Host "URL: $sitePermissionsUrl`n" -ForegroundColor Gray

try {
    $sitePermissions = Invoke-MgGraphRequest -Method GET -Uri $sitePermissionsUrl
    
    Write-Host "Raw response:" -ForegroundColor Gray
    Write-Host ($sitePermissions | ConvertTo-Json -Depth 5) -ForegroundColor Gray
    Write-Host ""
    
    if ($sitePermissions.value -and $sitePermissions.value.Count -gt 0) {
        Write-Host "Site Permissions Found: $($sitePermissions.value.Count)" -ForegroundColor Green
        
        foreach ($perm in $sitePermissions.value) {
            Write-Host "`n  Permission ID: $($perm.id)" -ForegroundColor Gray
            Write-Host "  Roles:         $($perm.roles -join ', ')" -ForegroundColor White
            
            if ($perm.grantedToIdentities) {
                foreach ($identity in $perm.grantedToIdentities) {
                    if ($identity.application) {
                        $appInfo = $identity.application
                        Write-Host "  App ID:        $($appInfo.id)" -ForegroundColor Cyan
                        Write-Host "  App Name:      $($appInfo.displayName)" -ForegroundColor Cyan
                        
                        if ($AppId -and $appInfo.id -eq $AppId) {
                            Write-Host "  *** MATCH: This is your specified app! ***" -ForegroundColor Green
                        }
                    }
                    if ($identity.user) {
                        Write-Host "  User:          $($identity.user.displayName)" -ForegroundColor Cyan
                    }
                    if ($identity.group) {
                        Write-Host "  Group:         $($identity.group.displayName)" -ForegroundColor Cyan
                    }
                }
            }
            
            # Also check grantedTo (older format)
            if ($perm.grantedTo) {
                if ($perm.grantedTo.application) {
                    Write-Host "  App (legacy):  $($perm.grantedTo.application.displayName)" -ForegroundColor Cyan
                    Write-Host "  App ID:        $($perm.grantedTo.application.id)" -ForegroundColor Cyan
                }
            }
        }
    } else {
        Write-Host "No site-level permissions found (or permissions array is empty)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`nERROR: Failed to retrieve site permissions" -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
}


Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Permission check completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Disconnect-MgGraph
