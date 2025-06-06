#!/usr/bin/pwsh

#Parameters
param(
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateSet('lld', 'keyTtl')]
    [string]$RequestType,

    [Parameter(Position=1)]
    [ValidateSet('PasswordCredentials', 'KeyCredentials')]
    [string]$CredentialType,

    [Parameter(Position=2)]
    [string]$AadAppObjId,

    [Parameter(Position=3)]
    [string]$KeyId
)

#Parameters

#Setup
# Construct the path to the settings file relative to the script's location.
$settingsPath = Join-Path -Path $PSScriptRoot -ChildPath "settings.json"

# Load settings from the JSON file.
try {
    $settings = Get-Content -Path $settingsPath -ErrorAction Stop | ConvertFrom-Json
}
catch {
    Write-Error "Failed to load or parse settings.json. Please ensure the file exists at '$settingsPath' and is valid JSON."
    exit 1
}

# Assign credentials from the settings file.
$appId = $settings.appid
$tenantId = $settings.tenantid
$secret = $settings.secret
#endregion Initial Setup

function Connect-ToGraph {
    param(
        [string]$TenantId,
        [string]$AppId,
        [string]$Secret
    )

    try {
        $secureSecret = ConvertTo-SecureString $Secret -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($AppId, $secureSecret)

        # Connect using the PSCredential object.
        Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $credential -ErrorAction Stop -NoWelcome

        # --- NEW VERIFICATION METHOD ---
        #Write-Host "Initial connection successful. Verifying with a test API call..."
        
        $null = Get-MgServicePrincipal -Filter "appId eq '$AppId'" -ErrorAction Stop
        
        # If the line above did NOT throw an error, the connection is alive and working.
        #Write-Host "Connection verified. Successfully connected as application '$AppId'."

    }
    catch {
        Write-Error "Failed to connect or verify the connection to Microsoft Graph."
        Write-Error "If you saw the 'Welcome' message, the failure is during the verification step."
        Write-Error "Ensure the application has 'Application.Read.All' API permission."
        Write-Error "Underlying Error: $($_.Exception.Message)"
        exit 1
    }
}

function Get-AllAppCredentials {
    try {
        $allApps = Get-MgApplication -All -ErrorAction Stop
        $credentialObjects = foreach ($app in $allApps) {
            # Process key credentials
            foreach ($key in $app.KeyCredentials) {
                [PSCustomObject]@{
                    "{#CREDENTIALTYPE}" = "Key"
                    "{#DISPLAYNAME}"    = $app.DisplayName
                    "{#APPID}"          = $app.AppId
                    "{#KEYID}"          = $key.KeyId
                    "{#AADAPPOBJID}"    = $app.Id
                }
            }
            # Process password credentials (secrets)
            foreach ($password in $app.PasswordCredentials) {
                [PSCustomObject]@{
                    "{#CREDENTIALTYPE}" = "Password"
                    "{#DISPLAYNAME}"    = $app.DisplayName
                    "{#APPID}"          = $app.AppId
                    "{#KEYID}"          = $password.KeyId
                    "{#AADAPPOBJID}"    = $app.Id
                }
            }
        }
        return $credentialObjects | ConvertTo-Json
    }
    catch {
        Write-Error "Failed to get application credentials. Ensure the connected application has 'Application.Read.All' API permissions."
        Write-Error "Underlying Error: $($_.Exception.Message)"
        exit 1
    }
}

function Get-AppKeyTtl {
    param(
        [string]$AppObjectId,
        [string]$CredentialType,
        [string]$AppKeyId
    )

    try {
        $application = Get-MgApplication -ApplicationId $AppObjectId -ErrorAction Stop
        
        # Dynamically select the correct credential collection based on the $CredentialType parameter.
        $credentialCollection = $application.$CredentialType

        if ($null -eq $credentialCollection) {
            throw "Invalid credential type '$CredentialType' or collection not found on the application object."
        }

        $credential = $credentialCollection | Where-Object { $_.KeyId -eq $AppKeyId }

        if ($credential) {
            # Both PasswordCredentials and KeyCredentials have an 'EndDateTime' property.
            $daysUntilExpiration = (New-TimeSpan -Start (Get-Date) -End $credential.EndDateTime).Days
            return $daysUntilExpiration
        }
        else {
            Write-Warning "Could not find a key with KeyId '$AppKeyId' in the '$CredentialType' collection for this application."
            return $null
        }
    }
    catch {
        Write-Error "Failed to retrieve application key TTL for AppObjectId: $AppObjectId"
        Write-Error "Underlying Error: $($_.Exception.Message)"
        exit 1
    }
}
#endregion Functions

#region Main Execution
# --- Argument Validation ---
if ($RequestType -eq 'keyTtl') {
    if ([string]::IsNullOrWhiteSpace($AadAppObjId) -or [string]::IsNullOrWhiteSpace($KeyId)) {
        Write-Error "When RequestType is 'keyTtl', you must provide both the 'AadAppObjId' and 'KeyId' arguments."
        exit 1 # Exit with an error code
    }
}
# --- End Argument Validation ---

# Establish a connection to Microsoft Graph.
Connect-ToGraph -TenantId $tenantId -AppId $appId -Secret $secret

# Execute the appropriate function based on the user's request.
switch ($RequestType) {
    'lld' {
        Get-AllAppCredentials
    }
    'keyTtl' {
        Get-AppKeyTtl -CredentialType $CredentialType -AppObjectId $AadAppObjId -AppKeyId $KeyId
    }
}
#endregion Main Execution