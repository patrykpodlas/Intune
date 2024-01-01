# This is the new API as outlined in: https://techcommunity.microsoft.com/t5/intune-customer-success/endpoint-security-policies-migrating-to-the-unified-settings/ba-p/3890989
# https://learn.microsoft.com/en-us/graph/api/resources/intune-deviceconfigv2-devicemanagementconfigurationpolicy?view=graph-rest-beta

Function Get-ConfigurationPolicies {
    [CmdletBinding()]
    param (
        $URI = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies",
        $ExportPath = "$env:TEMP\deviceManagement\ConfigurationPolicies"
    )

    $exportPath = $exportPath.replace('"', '')

    try {
        # Get
        $request = (Invoke-MgGraphRequest -Uri $URI -Method GET | Get-MgGraphAllPages)

        # Get assignments
        foreach ($item in $request) {
            $assignmentsUri = "$URI('$($item.id)')/assignments"
            $itemAssignments = (Invoke-MgGraphRequest -Uri $assignmentsUri -Method GET)
            $item.assignments = $itemAssignments
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
            Write-Verbose "Item: $($item.name)"
            $jsonContent = $item | ConvertTo-Json -Depth 99
            $fileName = $item.name -replace '[\<\>\:"/\\\|\?\*]', "_"

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