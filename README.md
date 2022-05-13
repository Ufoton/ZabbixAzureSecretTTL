# ZabbixAzureSecretTTL
Powershell script to audit all Azure AD app registrations and notify secret key or certificate expiration to zabbix using Microsoft Graph. 
Script check all the Azure AD Applications registered in your tenant and check key expiration

## Requirements

Script uses an Azure App Registration. The App Registration is used for authentication in the Microsoft Graph API. 
The minimum required permission is: Application.Read.All

Script need "client secret", "tenant id" and "client id" from Azure App. 

## Zabbix integration

Powershell must be instaled https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux?view=powershell-7.2. 
Powershell module Microsoft.Graph must be instaled 

    Install-Module Microsoft.Graph -Scope AllUsers

Put script into external script directory https://www.zabbix.com/documentation/current/en/manual/config/items/itemtypes/external 
In same directory create settings.json. 

To check:

    sudo -u zabbix ./azurekeyttl.ps1 lld
    
Import template and add to Zabbix server host.
