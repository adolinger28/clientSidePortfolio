<#
.SYNOPSIS
Example onboarding workflow for mailbox provisioning.

.DESCRIPTION
Finds recently created Active Directory users who do not yet have mail
attributes, checks for alias conflicts, enables mailboxes, and produces a
summary report. This is a sanitized sample intended to demonstrate the
workflow pattern.

.PARAMETER SearchBase
OU to search for recently created users.

.PARAMETER DaysBack
How far back to look for new accounts.

.PARAMETER ExchangeConnectionUri
Remote PowerShell endpoint for Exchange.

.PARAMETER NotificationTo
Recipient for the summary message.

.PARAMETER MailFrom
Sender used for summary notifications.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$SearchBase = "OU=Users,DC=example,DC=com",

    [Parameter()]
    [int]$DaysBack = 7,

    [Parameter(Mandatory)]
    [string]$ExchangeConnectionUri,

    [Parameter(Mandatory)]
    [System.Management.Automation.PSCredential]$ExchangeCredential,

    [Parameter()]
    [string]$RoleAssignmentPolicy = "Default Role Assignment Policy",

    [Parameter()]
    [string]$RetentionPolicy = "Default Retention Policy",

    [Parameter()]
    [string]$NotificationTo,

    [Parameter()]
    [string]$MailFrom = "automation@example.com",

    [Parameter()]
    [string]$SmtpServer
)

$newHireCutoff = (Get-Date).AddDays(-$DaysBack)
$domainController = (Get-ADDomain).PDCEmulator

$newUsers = Get-ADUser -SearchBase $SearchBase `
    -Filter {(mail -notlike "*") -and (enabled -eq $true)} `
    -Properties whenCreated, displayName `
    -Server $domainController |
    Where-Object { $_.whenCreated -ge $newHireCutoff }

if (-not $newUsers) {
    Write-Host "No new users found for provisioning."
    return
}

$session = New-PSSession `
    -ConfigurationName Microsoft.Exchange `
    -ConnectionUri $ExchangeConnectionUri `
    -Authentication Kerberos `
    -Credential $ExchangeCredential

if (-not $session) {
    throw "Unable to connect to Exchange endpoint."
}

try {
    Import-PSSession $session -DisableNameChecking | Out-Null

    $results = foreach ($user in $newUsers) {
        $conflict = Get-Recipient -Identity $user.SamAccountName -DomainController $domainController -ErrorAction SilentlyContinue
        if ($conflict) {
            [pscustomobject]@{
                SamAccountName = $user.SamAccountName
                DisplayName    = $user.DisplayName
                Status         = "Conflict"
                Details        = "Alias already exists."
            }
            continue
        }

        Enable-Mailbox -Identity $user.SamAccountName `
            -RoleAssignmentPolicy $RoleAssignmentPolicy `
            -RetentionPolicy $RetentionPolicy `
            -DomainController $domainController | Out-Null

        Enable-Mailbox -Identity $user.SamAccountName -Archive -DomainController $domainController | Out-Null
        Set-Mailbox -Identity $user.SamAccountName -LitigationHoldEnabled $true -DomainController $domainController | Out-Null

        [pscustomobject]@{
            SamAccountName = $user.SamAccountName
            DisplayName    = $user.DisplayName
            Status         = "Provisioned"
            Details        = "Mailbox and archive enabled."
        }
    }

    if ($NotificationTo -and $SmtpServer) {
        $body = $results | Format-Table -AutoSize | Out-String
        Send-MailMessage -To $NotificationTo -From $MailFrom -SmtpServer $SmtpServer -Subject "New Hire Mailbox Provisioning Summary" -Body $body
    }

    $results
}
finally {
    if ($session) {
        Remove-PSSession $session
    }
}
