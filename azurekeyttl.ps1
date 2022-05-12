#!/usr/bin/pwsh

$settings = $PSScriptRoot + "/settings.json"

$SettingsObject = Get-Content -Path $settings | ConvertFrom-Json

$appid = $SettingsObject.appid
$tenantid = $SettingsObject.tenantid
$secret = $SettingsObject.secret

$lldObject = @()
$body =  @{                                                                                                                                
     Grant_Type    = "client_credentials"                                
     Scope         = "https://graph.microsoft.com/.default"
     Client_Id     = $appid                                     
     Client_Secret = $secret
}

$requestType=$args[0]
$keyType = $args[1]
$aadAppObjId = $args[2]
$KeyId = $args[3]

function ConnectAzure {
$connection = Invoke-RestMethod -Uri https://login.microsoftonline.com/$tenantid/oauth2/v2.0/token -Method POST -Body $body
$token = $connection.access_token

$result = Connect-MgGraph -AccessToken $token
if ($result -notmatch "Welcome To Microsoft Graph") {
		Exit
	}
}

function Get-ScriptDirectory {
    Split-Path -Parent $PSCommandPath
}

function appLld {

ConnectAzure
$Apps = Get-MgApplication -All

$Apps | %{
    $aadAppObjId = $_.Id
    $app = Get-MgApplication -ApplicationId $aadAppObjId 
    $app.KeyCredentials | %{
        $lldObject += [PSCustomObject] @{
            "{#CredentialType}" = "KeyCredentials";
            "{#DisplayName}" = $app.DisplayName;
            "{#AppId}" = $app.AppId;
            "{#KeyID}" = $_.KeyId;
	    "{#aadAppObjId}" = $aadAppObjId;
            }
    }

    $app.PasswordCredentials | %{
        $lldObject += [PSCustomObject] @{
            "{#CredentialType}" = "PasswordCredentials";
            "{#DisplayName}" = $app.DisplayName;
            "{#AppId}" = $app.AppId;
            "{#KeyID}" = $_.KeyId;
            "{#aadAppObjId}" = $aadAppObjId;
        }
    }
}

$lldObject | ConvertTo-Json	
}

function AppKeyTtl {
	ConnectAzure
	$today = Get-Date
	$app = Get-MgApplication -ApplicationId $aadAppObjId
	$appKey = $app.PasswordCredentials | Where-Object {$_.KeyId -eq $KeyId}
	$Expired = $appKey.EndDateTime - $today
	$Expired.Days	
	
}

switch ($requestType) {
	'lld'  { appLld }
	'keyTtl' { AppKeyTtl($keyType, $aadAppObjId, $KeyId) }	
}

