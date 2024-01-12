Function Get-EndpointSecurityTemplates {
    [CmdletBinding()]
    param (
        $URI = "https://graph.microsoft.com/beta/deviceManagement/templates?`$filter=(isof(%27microsoft.graph.securityBaselineTemplate%27))",
        $ExportPath = "$env:TEMP\deviceManagement\endpointSecurity\templates"
    )

    $exportPath = $exportPath.replace('"', '')

    try {
        # Get
        $request = (Invoke-MgGraphRequest -Uri $URI -Method GET).Value

        # Get settings
        foreach ($item in $request) {
            $URI = "https://graph.microsoft.com/beta/deviceManagement/templates/$($item.id)?`$expand=settings"
            $itemSettings = Invoke-MgGraphRequest -Uri $URI -Method GET
            $item.settings = $itemSettings.settings
        }

        # Sort
        $sortedRequest = foreach ($item in $request) {
            Format-HashtableRecursively -Hashtable $item
        }

        # Convert Date and Time to string to prevent serialisation
        foreach ($item in $sortedRequest) {
            $item.publishedDateTime = $item.publishedDateTime.ToString('MM/dd/yyyy HH:mm:ss')
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
