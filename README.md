# ZabbixAzureSecretTTL
Powershell script to audit all Azure AD app registrations and notify secret key or certificate expiration to zabbix using Microsoft Graph.

Script check all the Azure AD Applications registered in your tenant and check key expiration

# Requirements

Script uses an Azure App Registration. The App Registration is used for authentication in the Microsoft Graph API
The minimum required permission is: Application.Read.All

Script need "client secret", "tenant id" and "client id" from Azure App.
Powershell module must be instaled

Install-Module Microsoft.Graph -Scope AllUsers

To check sudo -u zabbix ./azurekeyttl.ps1 lld
