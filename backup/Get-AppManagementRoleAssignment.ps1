Function Get-AppManagementRoleAssignment {
    param
    (
        $ExportPath = "$env:TEMP\deviceManagement\rbac\appManagementRoleAssignments",
        [Array]$IDs
    )

    $dataArray = @()

    foreach ($ID in $IDs) {
        try {
            # Get
            $URI = "https://graph.microsoft.com/beta/deviceManagement/roleAssignments('$id')?`$expand=microsoft.graph.deviceAndAppManagementRoleAssignment/roleScopeTags"
            $request = (Invoke-MgGraphRequest -Uri $URI -Method GET)

            # Sort
            $sortedRequest = foreach ($item in $request) {
                Format-HashtableRecursively -Hashtable $item
            }

            # Process each
            foreach ($item in $sortedRequest) {
                Write-Verbose "Item: $($item.description)"
                $jsonContent = $item | ConvertTo-Json -Depth 99
                $fileName = $item.description -replace '[\<\>\:"/\\\|\?\*]', "_"

                # Create a hashtable for each file's data
                $fileData = @{
                    FileName   = "$fileName.json"
                    Content    = $jsonContent
                    ExportPath = $exportPath
                }

                # Add the hashtable to the array
                $dataArray += $fileData
            }
        }

        catch {
            Write-Error "An error occurred: $($_.Exception.Message)"
            return
        }

    }

    return $dataArray

}