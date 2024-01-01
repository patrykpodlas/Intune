function Get-RoleAssignments {
    param (
        $ExportPath = "$env:TEMP\deviceManagement\rbac\roleAssignments",
        [Array]$IDs
    )

    # Initialize the array
    $dataArray = @()

    foreach ($ID in $IDs) {
        try {
            # Get
            $URI = "https://graph.microsoft.com/Beta/deviceManagement/roleDefinitions('$ID')?`$expand=roleassignments"
            $request = (Invoke-MgGraphRequest -Uri $URI -Method GET)

            # Sort
            $sortedRequest = foreach ($item in $request) {
                Format-HashtableRecursively -Hashtable $item
            }

            # Process each
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