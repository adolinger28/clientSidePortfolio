function Get-LocalAdministratorsAudit {
<#
.SYNOPSIS
Audits the local Administrators group across one or more Windows servers.

.DESCRIPTION
Connects to target computers, enumerates local Administrators group members,
and returns the results. Optionally filters out approved members so the
output highlights only exceptions.

.PARAMETER ComputerName
One or more computer names to audit.

.PARAMETER ApprovedMember
Names that should be treated as approved and excluded from exception output.

.PARAMETER IncludeApprovedMembers
Include both approved and non-approved members in the results.

.EXAMPLE
Get-LocalAdministratorsAudit -ComputerName FS01, APP01 -ApprovedMember "Domain Admins", "Tier2-Server-Admins"
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName,

        [Parameter()]
        [string[]]$ApprovedMember = @(
            "Administrator",
            "Domain Admins"
        ),

        [Parameter()]
        [switch]$IncludeApprovedMembers
    )

    process {
        foreach ($name in $ComputerName) {
            if (-not (Test-Connection -ComputerName $name -Count 1 -Quiet)) {
                Write-Warning "$name is unreachable."
                continue
            }

            try {
                $group = [ADSI]"WinNT://$name/Administrators,group"
                $members = @($group.psbase.Invoke("Members"))
            }
            catch {
                Write-Warning "Failed to query local Administrators on $name. $($_.Exception.Message)"
                continue
            }

            foreach ($member in $members) {
                $memberName = $member.GetType().InvokeMember("Name", "GetProperty", $null, $member, $null)
                $isApproved = $ApprovedMember -contains $memberName

                if (-not $IncludeApprovedMembers -and $isApproved) {
                    continue
                }

                [pscustomobject]@{
                    ComputerName = $name
                    MemberName   = $memberName
                    IsApproved   = $isApproved
                }
            }
        }
    }
}
