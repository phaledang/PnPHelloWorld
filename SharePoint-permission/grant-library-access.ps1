param(
    [Parameter(Mandatory=$true)]
    [string]$TenantId,

    [Parameter(Mandatory=$true)]
    [string]$SiteUrl,

    [Parameter(Mandatory=$true)]
    [string]$AppId,

    [Parameter(Mandatory=$false)]
    [ValidateSet("read", "write")]
    [string]$Permission = "write"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SharePoint Site Permission Grant Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Tenant ID:    $TenantId"
Write-Host "Site URL:     $SiteUrl"
Write-Host "App ID:       $AppId"
Write-Host "Permission:   $Permission"
Write-Host "`n*** IMPORTANT NOTE ***" -ForegroundColor Yellow
Write-Host "Microsoft Graph API does not support library-level permissions for applications." -ForegroundColor Yellow
Write-Host "This script grants SITE-LEVEL permissions, which apply to ALL libraries in the site." -ForegroundColor Yellow
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

# Grant site-level permission
Write-Host "Granting site-level permission..." -ForegroundColor Yellow

# Build Graph API URL - using site permissions endpoint
$graphUrl = "https://graph.microsoft.com/v1.0/sites/$($site.Id)/permissions"

try {
    # Prepare permission request body
    $permissionBody = @{
        roles = @($Permission)
        grantedToIdentities = @(
            @{
                application = @{
                    id = $AppId
                    displayName = "App Registration"
                }
            }
        )
    }
    
    $jsonBody = $permissionBody | ConvertTo-Json -Depth 10
    Write-Host "Request URL: $graphUrl" -ForegroundColor Gray
    Write-Host "Request body: $jsonBody" -ForegroundColor Gray
    Write-Host ""
    
    $result = Invoke-MgGraphRequest -Method POST -Uri $graphUrl -Body $jsonBody -ContentType "application/json"
    Write-Host "SUCCESS: Granted $Permission permission to site" -ForegroundColor Green
    Write-Host "This permission applies to ALL libraries in the site" -ForegroundColor Yellow
}
catch {
    Write-Host "ERROR: Failed to grant site permission" -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    
    # Try to get more details from the error response
    if ($_.Exception.Response) {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $errorBody = $reader.ReadToEnd()
        Write-Host "Error Response: $errorBody" -ForegroundColor Red
    }
    exit 1
}

Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Permission grant process completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Disconnect-MgGraph
