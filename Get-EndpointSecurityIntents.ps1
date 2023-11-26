Function Get-EndpointSecurityIntents {
    <#
    https://learn.microsoft.com/en-us/graph/api/resources/intune-deviceintent-devicemanagementintent?view=graph-rest-beta
    #>
    [CmdletBinding()]
    param(
        $BaseURI = "https://graph.microsoft.com/beta/deviceManagement/intents",
        $ExportPath = "$env:TEMP\deviceManagement\endpointSecurity\intents"
    )

    $exportPath = $exportPath.Replace('"', '')

    try {
        # Get
        $request = (Invoke-MgGraphRequest -Uri $BaseURI -Method GET).Value

        # Get
        foreach ($item in $request) {
            # Get assignments
            $assignmentsUri = "$BaseURI('$($item.id)')/assignments"
            $itemAssignments = (Invoke-MgGraphRequest -Uri $assignmentsUri -Method GET).Value
            $item.assignments = $itemAssignments

            # Get settings
            $settingsUri = "$BaseURI('$($item.id)')/settings"
            $itemSettings = (Invoke-MgGraphRequest -Uri $settingsUri -Method GET).Value
            $item.settings = $itemSettings
        }

        # Sort
        $sortedRequest = foreach ($item in $request) {
            Format-HashtableRecursively -Hashtable $item
        }

        # Initialize the array to hold data for export
        $dataArray = @()

        # Process
        foreach ($intent in $sortedRequest) {
            Write-Verbose "Item: $($intent.displayName)"
            $jsonContent = $intent | ConvertTo-Json -Depth 10
            $fileName = $intent.displayName -replace '[\<\>\:"/\\\|\?\*]', "_"

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