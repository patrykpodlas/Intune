$conflicts = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurationConflictSummary" -Method GET).Value

$conflicts | ForEach-Object {
    Write-Host "--- Conflict ID: $($_.id)" -ForegroundColor Yellow
    Write-Host "  --- Conflicting setting: " -ForegroundColor Yellow -NoNewline ; Write-Host "$($_.contributingSettings)" -ForegroundColor Red
    Write-Output "      --- From configurations: "
    if ($_.contributingSettings -like "*Windows10CustomConfiguration*") {
        foreach ($item in $($_.conflictingDeviceConfigurations)) {
            $displayName = $($item.displayName)
            Write-Output "          --- $displayName"
        }
    } elseif ($_.contributingSettings -like "*Windows10EndpointProtectionConfiguration*" -or $_.contributingSettings -like "*Windows10GeneralConfiguration*") {
        foreach ($item in $($_.conflictingDeviceConfigurations)) {
            $displayName = $item.displayName.Substring(0, $($item.displayName.LastIndexOf(" - "))).Trim()
            $id = $item.displayName.Substring($($item.displayName.LastIndexOf(" - "))).split("_")[0].TrimStart("-  ")
            Write-Output "          --- $displayName | ID: $id"
        }
    } else {
        foreach ($item in $($_.conflictingDeviceConfigurations)) {
            $displayName = $($item.displayName)
            Write-Output "          --- $displayName"
        }
    }
    Write-Output ""
}