Function Get-ManagedDeviceConfigurationPolicies {
    [CmdletBinding()]
    param(
        # Must be beta, the v1.0 doesn't provide Android configurations
        $URI = "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppConfigurations?`$expand=assignments",
        $ExportPath = "$env:TEMP\deviceAppManagement\mobileAppConfigurations"
    )

    $exportPath = $exportPath.Replace('"', '')

    try {
        # Get
        $request = (Invoke-MgGraphRequest -Uri $URI -Method GET).Value

        # Sort
        $sortedRequest = foreach ($item in $request) {
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
        foreach ($item in $sortedRequest) {
            Write-Verbose "Item: $($item.displayName)"
            $jsonContent = $item | ConvertTo-Json -Depth 99
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

    }
    catch {
        Write-Error "An error occurred: $($_.Exception.Message)"
        return
    }
}