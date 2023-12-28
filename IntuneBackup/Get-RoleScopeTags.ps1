Function Get-RoleScopeTags {
    param
    (
        [Array]$IDs,
        $ExportPath = "$env:TEMP\deviceManagement\deviceAndAppManagementRoleAssignment"
    )

    # Initialize the array
    $dataArray = @()

    # Process
    foreach ($ID in $IDs) {
        try {
            # Get
            $URI = "https://graph.microsoft.com/beta/deviceManagement/roleAssignments('$ID')?`$expand=microsoft.graph.deviceAndAppManagementRoleAssignment/roleScopeTags"
            $request = (Invoke-MgGraphRequest -Uri $URI -Method GET)

            # Sort
            $sortedRequest = foreach ($item in $request) {
                Format-HashtableRecursively -Hashtable $item
            }

            # Convert Date and Time to string to prevent serialisation
            foreach ($item in $sortedRequest) {
                $item.createdDateTime = $item.createdDateTime.ToString('MM/dd/yyyy HH:mm:ss')
                $item.lastModifiedDateTime = $item.lastModifiedDateTime.ToString('MM/dd/yyyy HH:mm:ss')
            }

            # Process each
            foreach ($item in $sortedRequest) {
                Write-Verbose "Item: $($item.description)"
                $jsonContent = $item | ConvertTo-Json -Depth 20
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
        }

    }

    return $dataArray

}
