Function Get-RoleDefinitions {
    param (
        $URI = "https://graph.microsoft.com/Beta/deviceManagement/roleDefinitions",
        $ExportPath = "$env:TEMP\deviceManagement\rbac\roleDefinitions"
    )

    try {
        # Get
        $request = (Invoke-MgGraphRequest -Uri $URI -Method GET).Value

        foreach ($item in $request) {
            # Get assignments
            $assignmentsUri = "$URI('$($item.id)')?`$expand=roleAssignments"
            $itemAssignments = (Invoke-MgGraphRequest -Uri $assignmentsUri -Method GET).roleAssignments
            $item.roleAssignments = $itemAssignments
        }

        # Sort
        $sortedRequest = foreach ($item in $request) {
            Format-HashtableRecursively -Hashtable $item
        }

        # Initialize array
        $dataArray = @()

        # Process
        foreach ($item in $sortedRequest) {
            Write-Verbose "Item: $($item.displayName)"
            $jsonContent = $item | ConvertTo-Json -Depth 99
            $fileName = $item.displayName -replace '[\<\>\:"/\\\|\?\*]', "_"

            # Create a hashtable for each file's data
            $fileData = @{
                FileName   = "$fileName.json"
                Content    = $jsonContent
                ExportPath = $exportPath
            }

            # Add the object to the array
            $dataArray += $fileData
        }
    }

    catch {
        Write-Error "An error occurred: $($_.Exception.Message)"
        return
    }

    return $dataArray

}