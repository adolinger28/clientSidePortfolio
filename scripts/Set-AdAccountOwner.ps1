function Set-AdAccountOwner {
<#
.SYNOPSIS
Sets a custom ownership attribute on an Active Directory account.

.DESCRIPTION
Looks up the owner's employee number and writes it to a custom attribute
on the target account. This pattern is useful for service account
governance, ownership audits, and access reviews.

.PARAMETER Identity
The samAccountName of the account to update.

.PARAMETER OwnerName
The samAccountName of the person who should own the account.

.PARAMETER OwnerAttributeName
The attribute that stores ownership metadata.

.PARAMETER SourceAttributeName
The source attribute to read from the owner account.

.EXAMPLE
Set-AdAccountOwner -Identity svc_sql_app -OwnerName jdoe
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Identity,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$OwnerName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OwnerAttributeName = "extensionAttribute10",

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$SourceAttributeName = "employeeNumber"
    )

    process {
        $targetAccount = Get-ADUser -Identity $Identity -ErrorAction Stop
        $ownerAccount = Get-ADUser -Identity $OwnerName -Properties $SourceAttributeName -ErrorAction Stop
        $ownerValue = $ownerAccount.$SourceAttributeName

        if ([string]::IsNullOrWhiteSpace($ownerValue)) {
            throw "Owner '$OwnerName' does not have a value in '$SourceAttributeName'."
        }

        if ($PSCmdlet.ShouldProcess($targetAccount.SamAccountName, "Set $OwnerAttributeName to '$ownerValue'")) {
            Set-ADUser -Identity $targetAccount -Replace @{ $OwnerAttributeName = $ownerValue }

            [pscustomobject]@{
                Identity           = $targetAccount.SamAccountName
                OwnerName          = $ownerAccount.SamAccountName
                OwnerAttributeName = $OwnerAttributeName
                OwnerValue         = $ownerValue
                Updated            = $true
            }
        }
    }
}
