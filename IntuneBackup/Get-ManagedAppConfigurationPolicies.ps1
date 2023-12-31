Function Get-ManagedAppConfigurationsPolicies {
    [CmdletBinding()]
    param(
        $URI = "https://graph.microsoft.com/v1.0/deviceAppManagement/targetedManagedAppConfigurations?`$expand=assignments",
        $ExportPath = "$env:TEMP\deviceAppManagement\targetedManagedAppConfigurations"
    )

    $exportPath = $exportPath.Replace('"', '')

    try {
        # Get
        $get = (Invoke-MgGraphRequest -Uri $URI -Method GET).Value

        # Sort
        $sortedGet = foreach ($item in $get) {
            Format-HashtableRecursively -Hashtable $item
        }

        # Convert Date and Time to string to prevent serialisation
        foreach ($item in $sortedRequest) {
            $item.createdDateTime = $item.createdDateTime.ToString('MM/dd/yyyy HH:mm:ss')
            $item.lastModifiedDateTime = $item.lastModifiedDateTime.ToString('MM/dd/yyyy HH:mm:ss')
        }

        # Initialize the array
        $dataArray = @()

        # Process
        foreach ($item in $sortedGet) {
            Write-Host "Device Compliance Policy:" $item.displayName -ForegroundColor Yellow
            $jsonContent = $item | ConvertTo-Json -Depth 10
            $fileName = $item.displayName -replace '[\<\>\:"/\\\|\?\*]', "_"

            $fileData = @{
                FileName   = "$fileName.json"
                Content    = $jsonContent
                ExportPath = $exportPath
            }
            # Add the object to the array
            $dataArray += $fileData
            Write-Host
        }

        return $dataArray

    } catch {
        Write-Error "An error occurred: $($_.Exception.Message)"
        return
    }
}