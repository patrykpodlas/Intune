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

        # Get payload content
        foreach ($item in $request) {
            $payload = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("$($item.payload)"))
            $item.payload = $payload
        }

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
        }

        return $dataArray

    } catch {
        Write-Error "An error occurred: $($_.Exception.Message)"
        return
    }
}
