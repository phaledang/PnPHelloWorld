# SharePoint Permission Management Scripts

This directory contains PowerShell scripts and batch file wrappers for managing SharePoint site permissions for applications via Microsoft Graph API.

## ⚠️ Important Understanding

**Microsoft Graph API only supports SITE-LEVEL permissions for applications.**

- Permissions granted apply to **ALL libraries** in the SharePoint site
- There is no library-specific permission granularity for applications
- Library access control must be implemented in your application logic


## Scripts Overview

| Script | Purpose |
|--------|---------|
| `grant-library-access.ps1` | Grant site-level permissions to an application |
| `grant-access.bat` | Batch wrapper for grant script |
| `check-library-access.ps1` | Check existing site permissions |
| `check-access.bat` | Batch wrapper for check script |
| `revoke-site-access.ps1` | Revoke (delete) site permissions for an application |
| `revoke-access.bat` | Batch wrapper for revoke script |

---

## Step-by-Step Setup Guide

### Step 1: Register an Azure AD Application

#### 1.1 Navigate to Azure Portal
1. Go to [Azure Portal](https://portal.azure.com)
2. Sign in with your organizational account
3. Search for **"Azure Active Directory"** or **"Microsoft Entra ID"**
4. Click **"App registrations"** in the left menu

#### 1.2 Create New Registration
1. Click **"+ New registration"**
2. Fill in the application details:
   - **Name**:  your preferred name
   - **Supported account types**: Select **"Accounts in this organizational directory only (Single tenant)"**
   - **Redirect URI**: Leave blank (not needed for service-to-service)
3. Click **"Register"**

#### 1.3 Save Application Details
After registration, you'll see the **Overview** page. **SAVE THESE VALUES:**

```
Application (client) ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Directory (tenant) ID:   xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

📝 **You'll need these for Step 4 (Running Scripts)**

---

### Step 2: Configure API Permissions

#### 2.1 Add Microsoft Graph Permissions

**Add Application Permissions (for service-to-service scenarios):**

1. In your app registration, click **"API permissions"** in the left menu
2. Click **"+ Add a permission"**
3. Select **"Microsoft Graph"**
4. Select **"Application permissions"**
5. Search and add these permissions:
   - **`Sites.Selected`** - Access selected site collections (⭐ Recommended for granular control)
   

**Add Delegated Permissions (for user-context scenarios):**

6. Click **"+ Add a permission"** again
7. Select **"Microsoft Graph"**
8. Select **"Delegated permissions"**
9. Search and add these permissions:
   - **`email`** - View users' email address
   - **`offline_access`** - Maintain access to data you have given it access to
   - **`openid`** - Sign users in
   - **`profile`** - View users' basic profile

10. Click **"Add permissions"**

#### 2.2 Grant Admin Consent
⚠️ **Critical Step - Permissions won't work without this!**

1. Click **"✓ Grant admin consent for [Your Organization]"**
2. Click **"Yes"** to confirm
3. Verify all permissions show **"✓ Granted for [Your Organization]"** with a green checkmark
![Entra Id App permission](app-api-permissions.png)
**Expected permissions table:**

| Permission | Type | Admin Consent Required | Status |
|------------|------|------------------------|--------|
| email | Delegated | No | ✓ Granted for [Your Org] |
| offline_access | Delegated | No | ✓ Granted for [Your Org] |
| openid | Delegated | No | ✓ Granted for [Your Org] |
| profile | Delegated | No | ✓ Granted for [Your Org] |
| Sites.Selected | Application | Yes | ✓ Granted for [Your Org] |

---

### Step 3: Generate Client Secret

#### 3.1 Create Secret
1. In your app registration, click **"Certificates & secrets"** in the left menu
2. Click **"+ New client secret"**
3. Add description: `SharePoint Access Secret`
4. Set expiration:
   - **Recommended**: 180 days or 1 year (more secure)
   - **Development**: 24 months (for long-term dev environments)
5. Click **"Add"**

#### 3.2 Save Secret Value Immediately
⚠️ **CRITICAL: Copy the secret value NOW - you can't see it again!**

After creation, you'll see:
```
Description                  Secret ID        Value                    Expires
─────────────────────────────────────────────────────────────────────────────
SharePoint Access Secret     xyz123...        abc~xyz789...            MM/DD/YYYY
```

**SAVE THIS IMMEDIATELY:**
```
Client Secret Value: abc~xyz789...
```

📝 **This value is shown ONLY ONCE. Store it securely (e.g., Azure Key Vault, password manager).**

---

### Step 4: Collect Settings for Scripts

You now have all the required information:

| Setting | Where to Find | Example Value |
|---------|---------------|---------------|
| **Tenant ID** | App Overview page → Directory (tenant) ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| **App ID** | App Overview page → Application (client) ID | `yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy` |
| **Client Secret** | Certificates & secrets → Value (copied in Step 3) | `abc~xyz789...` |
| **Site URL** | Your SharePoint site URL | `https://contoso.sharepoint.com/sites/demo` |

#### 4.1 Get Your SharePoint Site URL
1. Go to your SharePoint site in a browser
2. Copy the URL from the address bar
3. Use only the base site URL (without document library paths)

**Examples:**
- ✅ Correct: `https://contoso.sharepoint.com/sites/demo`
- ❌ Wrong: `https://contoso.sharepoint.com/sites/demo/Shared%20Documents`
- ❌ Wrong: `https://contoso.sharepoint.com/sites/demo/`

#### 4.2 Update Environment Variables

Create a `.env` file from sample file and update the settings:



### Step 5: Prerequisites for Running Scripts

#### 5.1 Install Microsoft Graph PowerShell Module

The scripts will auto-install if needed, but you can install manually:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
Install-Module Microsoft.Graph.Sites -Scope CurrentUser -Force
```

#### 5.2 Verify Your User Permissions

Your Azure AD user account needs one of these roles to run the scripts:
- **Global Administrator**
- **SharePoint Administrator**
- **Site Collection Administrator** (for the specific site)

To check your roles:
1. Azure Portal → Azure Active Directory
2. Users → [Your User] → Assigned roles

---

## Step 6: Run the Permission Management Scripts

### Option 1: Using Batch Files (Easiest)

#### 6.1 Edit Configuration
Create the `.bat` files from the sample files and update the variables 

#### 6.2 Run the Batch File

**Grant Permission:**
```cmd
cd scripts
grant-access.bat
```

**Check Permissions:**
```cmd
check-access.bat
```

**Revoke Permission:**
```cmd
revoke-access.bat
```

### Option 2: Using PowerShell Directly

#### 6.3 Grant Site Permission

```powershell
cd scripts
.\grant-library-access.ps1 `
    -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
    -SiteUrl "https://contoso.sharepoint.com/sites/demo" `
    -AppId "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy" `
    -Permission "write"
```

**Parameters:**
- `TenantId` (required) - From Step 4: Directory (tenant) ID
- `SiteUrl` (required) - From Step 4: SharePoint site URL
- `AppId` (required) - From Step 4: Application (client) ID
- `Permission` (optional) - `read` or `write` (default: `write`)

#### 6.4 Check Site Permissions

```powershell
.\check-library-access.ps1 `
    -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
    -SiteUrl "https://contoso.sharepoint.com/sites/demo" `
    -AppId "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
```

**Expected Output:**
```
Site Permissions Found: 1
  Permission ID: aTowaS50...
  Roles:         write
  App ID:        yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
  App Name:      SharePoint Automation App
  *** MATCH: This is your specified app! ***
```

#### 6.5 Revoke Site Permission

```powershell
.\revoke-site-access.ps1 `
    -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" `
    -SiteUrl "https://contoso.sharepoint.com/sites/demo" `
    -AppId "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
```

⚠️ **Warning:** Requires typing "YES" to confirm deletion.

---


**Never store:** Client Secret (this IS a secret - use Key Vault or `.env` files in `.gitignore`)

---


