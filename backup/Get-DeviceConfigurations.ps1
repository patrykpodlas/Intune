Function Get-DeviceConfigurations {
    [CmdletBinding()]
    param (
        $URI = "https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations",
        $ExportPath = "$env:TEMP\deviceManagement\deviceConfigurations"
    )

    $exportPath = $exportPath.replace('"', '')

    try {
        # Get
        $request = (Invoke-MgGraphRequest -Uri $URI -Method GET).Value

        # Get assignments
        foreach ($item in $request) {
            $assignmentsUri = "$URI('$($item.id)')/assignments"
            $itemAssignments = (Invoke-MgGraphRequest -Uri $assignmentsUri -Method GET).Value
            $item.assignments = $itemAssignments
        }

        # Sort
        $sortedRequest = foreach ($item in $request) {
            Format-HashtableRecursively -Hashtable $item
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
        }

        return $dataArray

    } catch {
        Write-Error "An error occurred: $($_.Exception.Message)"
        return
    }
}
