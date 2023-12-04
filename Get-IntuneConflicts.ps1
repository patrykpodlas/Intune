function Get-IntuneConflicts {
    [CmdletBinding()]
    param (

    )
    $conflicts = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurationConflictSummary" -Method GET).Value

    $configurationProfiles = @()
    $compliancePolicies = @()
    $securityIntents = @()

    $conflicts | ForEach-Object {
        Write-Host "--- Conflict ID: $($_.id)" -ForegroundColor Yellow
        Write-Host "  --- Conflicting setting: " -ForegroundColor Yellow -NoNewline ; Write-Host "$($_.contributingSettings)" -ForegroundColor Red
        Write-Host "      --- From configuration(s): " -ForegroundColor Yellow
        if ($_.contributingSettings -like "*Windows10CustomConfiguration*") {
            foreach ($item in $($_.conflictingDeviceConfigurations)) {
                $displayName = $($item.displayName)
                $id = $item.id
                Write-Host "          --- $displayName | ID: $id"
                $object = [PSCustomObject]@{
                    displayName        = $displayName
                    id                 = $id
                    type               = "configurationProfile"
                    conflictingSetting = $($_.contributingSettings)
                }
                $configurationProfiles += $object
            }
        } elseif ($_.contributingSettings -like "*Windows10EndpointProtectionConfiguration*" -or $_.contributingSettings -like "*Windows10GeneralConfiguration*") {
            foreach ($item in $($_.conflictingDeviceConfigurations)) {
                $displayName = $item.displayName.Substring(0, $($item.displayName.LastIndexOf(" - "))).Trim()
                $id = $item.displayName.Substring($($item.displayName.LastIndexOf(" - "))).split("_")[0].TrimStart("-  ")
                Write-Host "          --- $displayName | ID: $id"
                $object = [PSCustomObject]@{
                    displayName        = $displayName
                    id                 = $id
                    type               = "securityIntent"
                    conflictingSetting = $($_.contributingSettings)
                }
                $securityIntents += $object
            }
        } else {
            foreach ($item in $($_.conflictingDeviceConfigurations)) {
                $displayName = $($item.displayName)
                $id = $item.id
                Write-Host "          --- $displayName | ID: $id"
                $object = [PSCustomObject]@{
                    displayName        = $displayName
                    id                 = $id
                    type               = "unknown"
                    conflictingSetting = $($_.contributingSettings)
                }
                $compliancePolicies += $object
            }
        }
        Write-Host ""
    }

    $everything = $configurationProfiles + $compliancePolicies + $securityIntents
    Write-Output $everything | Select-Object displayName, ID, type, conflictingSetting

}