<#
.SYNOPSIS
Evaluates dynamic group configuration for risky patterns.

.DESCRIPTION
This sample accepts group-like objects and performs a few practical checks:
- default or overly broad search bases
- blank membership filters
- unusually large memberships
- default object type selections

The output can be exported to JSON and optionally posted to a generic
workflow endpoint for remediation tracking.

.EXAMPLE
$groups = @(
    [pscustomobject]@{
        Name = "All Sales Users"
        SearchBases = @("DC=example,DC=com")
        Filter = ""
        MemberCount = 950
        ExpectedPopulation = 1000
        ObjectTypes = 7
    }
)

.\Test-DynamicGroupConfiguration.ps1 -InputObject $groups -ExportPath .\reports\group-findings.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [psobject[]]$InputObject,

    [Parameter()]
    [string]$DefaultSearchBase = "DC=example,DC=com",

    [Parameter()]
    [double]$WarningThreshold = 0.75,

    [Parameter()]
    [double]$ErrorThreshold = 0.90,

    [Parameter()]
    [string]$ExportPath,

    [Parameter()]
    [string]$WorkflowUri,

    [Parameter()]
    [string]$WorkflowToken
)

begin {
    $findings = New-Object System.Collections.Generic.List[object]
}

process {
    foreach ($group in $InputObject) {
        $warnings = New-Object System.Collections.Generic.List[string]
        $errors = New-Object System.Collections.Generic.List[string]

        foreach ($searchBase in @($group.SearchBases)) {
            if ($searchBase -eq $DefaultSearchBase) {
                $warnings.Add("Search base is still set to the default root.")
            }
        }

        if ([string]::IsNullOrWhiteSpace([string]$group.Filter)) {
            $errors.Add("Membership filter is blank.")
        }

        $expectedPopulation = [double]$group.ExpectedPopulation
        $memberCount = [double]$group.MemberCount

        if ($expectedPopulation -gt 0) {
            $ratio = $memberCount / $expectedPopulation

            if ($ratio -ge $ErrorThreshold) {
                $errors.Add("Membership count is above the error threshold.")
            }
            elseif ($ratio -ge $WarningThreshold) {
                $warnings.Add("Membership count is above the warning threshold.")
            }
        }

        if ([int]$group.ObjectTypes -eq 7) {
            $warnings.Add("Object types are still set to the default combination.")
        }

        $findings.Add([pscustomobject]@{
            Name        = $group.Name
            Warnings    = @($warnings)
            Errors      = @($errors)
            MemberCount = $memberCount
        })
    }
}

end {
    $result = $findings.ToArray()

    if ($ExportPath) {
        $exportDir = Split-Path -Parent $ExportPath
        if ($exportDir) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        }
        $result | ConvertTo-Json -Depth 5 | Set-Content -Path $ExportPath -Encoding UTF8
    }

    if ($WorkflowUri -and $WorkflowToken) {
        $headers = @{
            Authorization = "Bearer $WorkflowToken"
            Accept        = "application/json"
        }

        $payload = @{
            summary  = "Dynamic group configuration review"
            findings = $result
        }

        Invoke-RestMethod -Method Post -Uri $WorkflowUri -Headers $headers -Body ($payload | ConvertTo-Json -Depth 6) -ContentType "application/json" | Out-Null
    }

    $result
}
