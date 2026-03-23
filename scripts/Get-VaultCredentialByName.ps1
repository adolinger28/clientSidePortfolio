function Get-VaultCredentialByName {
<#
.SYNOPSIS
Retrieves a named secret from a vault API and returns a PSCredential.

.DESCRIPTION
This sample shows a common automation pattern: fetch a secret from a
centralized vault and convert it into a PowerShell credential object that
can be reused by other scripts.

.PARAMETER SecretName
The display name of the secret to retrieve.

.PARAMETER VaultBaseUrl
The base URL of the vault API.

.PARAMETER AccessToken
Bearer token used to authenticate to the vault API.

.EXAMPLE
$cred = Get-VaultCredentialByName -SecretName "svc-automation" `
    -VaultBaseUrl "https://vault.example.com/api" `
    -AccessToken $env:VAULT_TOKEN
#>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCredential])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SecretName,

        [Parameter(Mandatory)]
        [ValidatePattern("^https://")]
        [string]$VaultBaseUrl,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$AccessToken
    )

    $headers = @{
        Authorization = "Bearer $AccessToken"
        Accept        = "application/json"
    }

    $secretSearchUrl = "{0}/secrets?name={1}" -f $VaultBaseUrl.TrimEnd('/'), [uri]::EscapeDataString($SecretName)
    $searchResult = Invoke-RestMethod -Method Get -Uri $secretSearchUrl -Headers $headers -ErrorAction Stop

    if (-not $searchResult.items -or $searchResult.items.Count -eq 0) {
        throw "Secret '$SecretName' was not found."
    }

    $secretId = $searchResult.items[0].id
    $secretDetailsUrl = "{0}/secrets/{1}" -f $VaultBaseUrl.TrimEnd('/'), $secretId
    $secret = Invoke-RestMethod -Method Get -Uri $secretDetailsUrl -Headers $headers -ErrorAction Stop

    if ([string]::IsNullOrWhiteSpace($secret.username) -or [string]::IsNullOrWhiteSpace($secret.password)) {
        throw "Secret '$SecretName' is missing a username or password field."
    }

    $securePassword = ConvertTo-SecureString -String $secret.password -AsPlainText -Force
    New-Object System.Management.Automation.PSCredential ($secret.username, $securePassword)
}
